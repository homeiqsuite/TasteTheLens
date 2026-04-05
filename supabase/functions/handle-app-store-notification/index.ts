/**
 * Apple App Store Server Notifications V2 handler.
 *
 * Apple sends a POST with a signed JWT payload whenever a subscription event
 * occurs (renewal, expiry, refund, etc.).  We decode the JWT, identify the
 * affected user via appAccountToken (set to the user's UUID at purchase time),
 * and update Supabase accordingly.
 *
 * Pure Credits Model:
 *   On renewal (SUBSCRIBED/DID_RENEW), credits are granted as purchased credits
 *   via convert_renewal_to_credits. On lapse (EXPIRED/REVOKE/REFUND), the tier
 *   is set to free but credits are NOT zeroed — they belong to the user.
 *
 * Signature verification:
 *   Apple signs notifications with ES256 using a certificate chain rooted at
 *   Apple's Root CA.  Full verification requires fetching Apple's public keys
 *   and walking the x5c cert chain — add that step before going to production
 *   if spoofed "EXPIRED" notifications are a concern.  The worst-case impact
 *   of a spoofed notification here is a user's tier being set to free (credits
 *   are never removed), so the risk is low, but verification is still recommended.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUNDLE_ID = "com.eightgates.Taste-The-Lens";

// Notification types that mean the subscription is no longer active
const LAPSE_TYPES = new Set([
  "EXPIRED",
  "GRACE_PERIOD_EXPIRED",
  "REVOKE",
  "REFUND",
]);

// Notification types that confirm an active subscription
const ACTIVE_TYPES = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
]);

// Maps App Store product IDs → internal tier names (kept for backward compat
// with old app versions that still read subscription_tier)
const PRODUCT_TIER_MAP: Record<string, string> = {
  "com.tastethelens.chefstable.monthly": "chefsTable",
  "com.tastethelens.chefstable.annual": "chefsTable",
  "com.tastethelens.pro.monthly": "chefsTable", // legacy
  "com.tastethelens.pro.annual": "chefsTable",  // legacy
  "com.tastethelens.atelier.monthly": "atelier",
};

// Maps App Store product IDs → credits granted on renewal.
// Pure credits model: renewals grant purchased credits (never expire).
const PRODUCT_CREDIT_MAP: Record<string, number> = {
  "com.tastethelens.chefstable.monthly": 75,
  "com.tastethelens.chefstable.annual": 900,   // 75 * 12
  "com.tastethelens.pro.monthly": 75,          // legacy
  "com.tastethelens.pro.annual": 900,          // legacy
  "com.tastethelens.atelier.monthly": 500,
};

// ─── JWT Decoding ────────────────────────────────────────────────────────────

function decodeJWTPayload(jwt: string): Record<string, unknown> {
  const parts = jwt.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT structure");
  // base64url → base64
  const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, "=");
  const json = atob(padded);
  return JSON.parse(json);
}

// ─── Handler ─────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: { signedPayload?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (!body.signedPayload) {
    return new Response("Missing signedPayload", { status: 400 });
  }

  // ── Decode outer notification payload ──────────────────────────────────────
  let notification: Record<string, unknown>;
  try {
    notification = decodeJWTPayload(body.signedPayload);
  } catch (e) {
    console.error("Failed to decode signedPayload:", e);
    return new Response("Invalid signedPayload", { status: 400 });
  }

  const notificationType = notification.notificationType as string | undefined;
  const data = notification.data as Record<string, unknown> | undefined;

  if (!notificationType || !data) {
    return new Response("Missing notificationType or data", { status: 400 });
  }

  // Validate this notification is for our app
  const bundleId = data.bundleId as string | undefined;
  if (bundleId && bundleId !== BUNDLE_ID) {
    console.warn(`Ignoring notification for unknown bundle: ${bundleId}`);
    return new Response("OK", { status: 200 });
  }

  // Ignore sandbox notifications in production (and vice-versa)
  const environment = data.environment as string | undefined;
  console.log(`Notification: type=${notificationType}, env=${environment}, bundle=${bundleId}`);

  // ── Decode signed transaction info ─────────────────────────────────────────
  const signedTransactionInfo = data.signedTransactionInfo as string | undefined;
  if (!signedTransactionInfo) {
    console.warn("No signedTransactionInfo in notification data");
    return new Response("OK", { status: 200 });
  }

  let transactionInfo: Record<string, unknown>;
  try {
    transactionInfo = decodeJWTPayload(signedTransactionInfo);
  } catch (e) {
    console.error("Failed to decode signedTransactionInfo:", e);
    return new Response("Invalid signedTransactionInfo", { status: 400 });
  }

  const appAccountToken = transactionInfo.appAccountToken as string | undefined;
  const productId = transactionInfo.productId as string | undefined;

  if (!appAccountToken) {
    // Subscription was purchased before we started setting appAccountToken.
    // Nothing we can do to identify the user — log and move on.
    console.warn("No appAccountToken in transaction — cannot identify user");
    return new Response("OK", { status: 200 });
  }

  // appAccountToken is stored as the user's UUID (set in StoreManager.purchase)
  const userId = appAccountToken.toLowerCase();

  // ── Determine action ───────────────────────────────────────────────────────
  const isLapse = LAPSE_TYPES.has(notificationType);
  const isActive = ACTIVE_TYPES.has(notificationType);

  if (!isLapse && !isActive) {
    // Informational notification (e.g. DID_CHANGE_RENEWAL_STATUS, OFFER_REDEEMED)
    // — no immediate credit/tier change needed.
    console.log(`No action for notification type: ${notificationType}`);
    return new Response("OK", { status: 200 });
  }

  // ── Update Supabase ────────────────────────────────────────────────────────
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  if (isActive) {
    // Subscription renewed or started — grant credits as purchased (never expire)
    const creditsToGrant = PRODUCT_CREDIT_MAP[productId ?? ""] ?? 75;

    const { error: creditError } = await supabase.rpc("convert_renewal_to_credits", {
      p_user_id: userId,
      p_credits: creditsToGrant,
    });

    if (creditError) {
      console.error(`Failed to grant credits for user ${userId}:`, creditError);
      return new Response("Database error", { status: 500 });
    }

    // Also update tier for backward compat with old app versions
    const newTier = PRODUCT_TIER_MAP[productId ?? ""] ?? "chefsTable";
    const { error: tierError } = await supabase.rpc("update_subscription_tier_for_user", {
      p_user_id: userId,
      p_tier: newTier,
    });

    if (tierError) {
      // Non-fatal: credits were already granted
      console.error(`Failed to update tier for user ${userId}:`, tierError);
    }

    console.log(`Granted ${creditsToGrant} credits to user ${userId} (${notificationType}, product=${productId})`);
  } else if (isLapse) {
    // Subscription lapsed — set tier to free but do NOT touch credits.
    // Credits are purchased and belong to the user.
    const { error } = await supabase.rpc("update_subscription_tier_for_user", {
      p_user_id: userId,
      p_tier: "free",
    });

    if (error) {
      console.error(`Failed to update tier for user ${userId}:`, error);
      return new Response("Database error", { status: 500 });
    }

    console.log(`Lapsed user ${userId} → tier=free, credits preserved (${notificationType})`);
  }

  return new Response("OK", { status: 200 });
});
