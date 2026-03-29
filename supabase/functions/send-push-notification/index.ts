import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON"
)!;

// Parse service account once at module level
const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
const FCM_PROJECT_ID = serviceAccount.project_id;

// Cache the OAuth2 access token (valid for ~1 hour)
let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

interface PushRequest {
  recipient_user_id: string;
  notification_type: string;
  title: string;
  body: string;
  deep_link?: string;
  payload?: Record<string, unknown>;
}

// Preference category mapping
const NOTIFICATION_TYPE_TO_PREFERENCE: Record<string, string> = {
  challenge_submission: "challenge_activity",
  challenge_upvote: "challenge_activity",
  challenge_winner: "challenge_activity",
  challenge_completed: "challenge_activity",
  menu_invite: "tasting_menu_updates",
  menu_course_added: "tasting_menu_updates",
  weekly_inspiration: "weekly_inspiration",
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body: PushRequest = await req.json();

    // ── Input validation ──────────────────────────────────────────────
    const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const VALID_NOTIFICATION_TYPES = Object.keys(NOTIFICATION_TYPE_TO_PREFERENCE);

    if (!body.recipient_user_id || typeof body.recipient_user_id !== "string" || !UUID_RE.test(body.recipient_user_id)) {
      return Response.json({ error: "Invalid or missing recipient_user_id (must be UUID)" }, { status: 400 });
    }
    if (!body.notification_type || typeof body.notification_type !== "string" || body.notification_type.length > 50) {
      return Response.json({ error: "Invalid or missing notification_type" }, { status: 400 });
    }
    if (!VALID_NOTIFICATION_TYPES.includes(body.notification_type)) {
      return Response.json({ error: `Unknown notification_type: ${body.notification_type}` }, { status: 400 });
    }
    if (!body.title || typeof body.title !== "string" || body.title.length > 200) {
      return Response.json({ error: "title is required and must be ≤ 200 characters" }, { status: 400 });
    }
    if (!body.body || typeof body.body !== "string" || body.body.length > 1000) {
      return Response.json({ error: "body is required and must be ≤ 1000 characters" }, { status: 400 });
    }
    if (body.deep_link !== undefined) {
      if (typeof body.deep_link !== "string" || body.deep_link.length > 500 || !body.deep_link.startsWith("tastethelens://")) {
        return Response.json({ error: "deep_link must be a tastethelens:// URL ≤ 500 characters" }, { status: 400 });
      }
    }
    if (body.payload !== undefined) {
      if (typeof body.payload !== "object" || body.payload === null || Array.isArray(body.payload)) {
        return Response.json({ error: "payload must be a JSON object" }, { status: 400 });
      }
      if (JSON.stringify(body.payload).length > 4096) {
        return Response.json({ error: "payload must be < 4KB" }, { status: 400 });
      }
    }

    const {
      recipient_user_id,
      notification_type,
      title,
      body: messageBody,
      deep_link,
      payload,
    } = body;

    // 1. Check notification preferences
    const prefKey = NOTIFICATION_TYPE_TO_PREFERENCE[notification_type];
    if (prefKey) {
      const { data: userData } = await supabase
        .from("users")
        .select("notification_preferences")
        .eq("id", recipient_user_id)
        .single();

      if (userData?.notification_preferences?.[prefKey] === false) {
        // Log as skipped
        await supabase.from("notification_log").insert({
          recipient_user_id,
          notification_type,
          title,
          body: messageBody,
          deep_link,
          payload: payload ?? {},
          status: "skipped",
          error_message: `User opted out of ${prefKey}`,
        });
        return Response.json({ status: "skipped", reason: "opted_out" });
      }
    }

    // 2. Look up FCM tokens
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("id, fcm_token")
      .eq("user_id", recipient_user_id);

    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      await supabase.from("notification_log").insert({
        recipient_user_id,
        notification_type,
        title,
        body: messageBody,
        deep_link,
        payload: payload ?? {},
        status: "skipped",
        error_message: "No device tokens found",
      });
      return Response.json({ status: "skipped", reason: "no_tokens" });
    }

    // 3. Get FCM access token
    const accessToken = await getFCMAccessToken();

    // 4. Send to each device
    const results = [];
    const staleTokenIds: string[] = [];

    for (const { id, fcm_token } of tokens) {
      const fcmPayload = {
        message: {
          token: fcm_token,
          notification: { title, body: messageBody },
          data: {
            ...(deep_link ? { deep_link } : {}),
            notification_type,
          },
          apns: {
            payload: {
              aps: { sound: "default" },
            },
          },
        },
      };

      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(fcmPayload),
        }
      );

      if (response.status === 429) {
        console.error("FCM rate limited — stopping further sends");
        results.push({ token: fcm_token, status: "failed", error: "rate_limited" });
        break; // Stop sending to remaining tokens
      }

      if (response.ok) {
        results.push({ token: fcm_token, status: "sent" });
      } else {
        const errorBody = await response.json();
        const errorCode = errorBody?.error?.details?.[0]?.errorCode;

        // Clean up invalid/unregistered tokens
        if (
          errorCode === "UNREGISTERED" ||
          errorCode === "INVALID_ARGUMENT" ||
          response.status === 404
        ) {
          staleTokenIds.push(id);
        }

        results.push({
          token: fcm_token,
          status: "failed",
          error: errorCode ?? response.statusText,
        });
      }
    }

    // 5. Delete stale tokens
    if (staleTokenIds.length > 0) {
      await supabase
        .from("device_tokens")
        .delete()
        .in("id", staleTokenIds);
    }

    // 6. Log the notification
    const sentCount = results.filter((r) => r.status === "sent").length;
    await supabase.from("notification_log").insert({
      recipient_user_id,
      notification_type,
      title,
      body: messageBody,
      deep_link,
      payload: payload ?? {},
      status: sentCount > 0 ? "sent" : "failed",
      error_message:
        sentCount === 0
          ? results.map((r) => r.error).join(", ")
          : null,
      sent_at: sentCount > 0 ? new Date().toISOString() : null,
    });

    return Response.json({ status: "ok", results });
  } catch (error) {
    console.error("Push notification error:", error);
    return Response.json(
      { status: "error", message: String(error) },
      { status: 500 }
    );
  }
});

// --- FCM OAuth2 Token ---

async function getFCMAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && now < tokenExpiresAt - 60) {
    return cachedAccessToken;
  }

  // Build JWT for Google OAuth2
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = base64url(JSON.stringify(header));
  const encodedClaim = base64url(JSON.stringify(claim));
  const signatureInput = `${encodedHeader}.${encodedClaim}`;

  // Import the private key and sign
  const privateKey = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signatureInput)
  );

  const jwt = `${signatureInput}.${base64url(signature)}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(
      `Failed to get FCM access token: ${await tokenResponse.text()}`
    );
  }

  const tokenData = await tokenResponse.json();
  cachedAccessToken = tokenData.access_token;
  tokenExpiresAt = now + tokenData.expires_in;
  return cachedAccessToken!;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

function base64url(input: string | ArrayBuffer): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);

  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
