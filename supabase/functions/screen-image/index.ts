import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

const SCREENING_PROMPT = `Content safety screener for a food/recipe app. Check if the image is appropriate for culinary inspiration.

REJECT (safe: false) if:
- Real, identifiable people (selfies, portraits, group photos)
- Children as primary subject
- Live animals as primary subject (packaged meat/seafood is fine)

ALLOW (safe: true) if:
- Food, ingredients, drinks, kitchens, restaurants, menus
- Objects, products, art, landscapes, architecture, nature, abstract
- Fictional characters, cartoons, illustrations, statues, sculptures
- Stylized/drawn people (not real photos of identifiable people)
- People incidental/background (e.g., street market focused on food stalls)
- Packaged products with people on labels
- Hands only (no face visible)

CRITICAL: Output ONLY raw JSON, no markdown, no explanation, no code fences.`;

interface ScreenImageRequest {
  images: string[]; // base64-encoded JPEG strings
}

interface ScreeningResult {
  safe: boolean;
  reason: string;
}

async function screenImage(base64Image: string): Promise<ScreeningResult> {
  const requestBody = {
    system_instruction: {
      parts: [{ text: SCREENING_PROMPT }],
    },
    contents: [
      {
        parts: [
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: base64Image,
            },
          },
          {
            text: 'Is this image appropriate for a food/recipe app? Return JSON: {"safe": true/false, "reason": "brief explanation"}',
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 256,
      responseMimeType: "application/json",
    },
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const response = await fetch(GEMINI_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (response.status === 429) {
      const retryAfter = response.headers.get("Retry-After");
      throw { isRateLimit: true, retryAfterSeconds: retryAfter ? parseInt(retryAfter, 10) : 30, provider: "gemini" };
    }
    if (!response.ok) {
      const errorText = await response.text();
      console.error("Gemini screening API error:", errorText);
      // Fail-open: allow image through if API errors
      return { safe: true, reason: "Screening unavailable" };
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return { safe: true, reason: "Screening unavailable" };
    }

    const result: ScreeningResult = JSON.parse(text);
    return result;
  } catch (error) {
    console.error("Screening error:", error);
    // Fail-open on any error
    return { safe: true, reason: "Screening unavailable" };
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Authenticate user (optional for guests)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let userId: string | null = null;

  const authHeader = req.headers.get("Authorization");
  if (authHeader) {
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (!authError && user) {
      userId = user.id;
    }
  }

  // Per-user rate limiting (authenticated users only)
  if (userId) {
    const { data: allowed } = await supabase.rpc("check_rate_limit", {
      p_user_id: userId,
      p_function_name: "screen-image",
      p_window_minutes: 1,
      p_max_requests: 15,
    });
    if (allowed === false) {
      return Response.json(
        { error: "rate_limited", message: "Too many requests. Please wait a moment." },
        { status: 429 }
      );
    }
  }

  try {
    const { images }: ScreenImageRequest = await req.json();

    if (!images || !Array.isArray(images) || images.length === 0) {
      return Response.json(
        { error: "images array is required" },
        { status: 400 }
      );
    }

    if (images.length > 3) {
      return Response.json(
        { error: "Maximum 3 images allowed" },
        { status: 400 }
      );
    }

    // Screen all images concurrently
    const results = await Promise.all(images.map(screenImage));

    // If any image is rejected, return the first rejection
    for (const result of results) {
      if (!result.safe) {
        return Response.json({ safe: false, reason: result.reason });
      }
    }

    const responseObj = { safe: true, reason: "All images passed screening" };
    const responseBody = JSON.stringify(responseObj);
    if (responseBody.length > 10_000) {
      console.error("Response too large:", responseBody.length);
      return Response.json({ error: "Response exceeded size limit" }, { status: 502 });
    }
    return new Response(responseBody, { headers: { "Content-Type": "application/json" } });
  } catch (error: unknown) {
    if (error && typeof error === "object" && "isRateLimit" in error) {
      const rl = error as { retryAfterSeconds: number; provider: string };
      return Response.json(
        { error: "rate_limited", retryAfterSeconds: rl.retryAfterSeconds, provider: rl.provider },
        { status: 429 }
      );
    }
    console.error("screen-image error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
