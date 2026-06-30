import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const FAL_API_KEY = Deno.env.get("FAL_API_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

// OpenAI flagship image model (GPT Image 2). Medium quality keeps a single meal
// image (~$0.04–0.05) comfortably profitable at 1 credit.
const OPENAI_IMAGE_MODEL = "gpt-image-2";

const PHOTOGRAPHY_SUFFIX =
  " Professional editorial food photography, Michelin star presentation, warm inviting lighting, shallow depth of field, 85mm lens, appetizing and delicious.";

type Provider = "imagen4" | "imagen4fast" | "fluxpro" | "fluxschnell" | "gptimage2";

// Flat cost per image generation (USD estimates)
const IMAGE_COST_USD: Record<Provider, number> = {
  imagen4:     0.040,
  imagen4fast: 0.020,
  fluxpro:     0.050,
  fluxschnell: 0.003,
  gptimage2:   0.053, // GPT Image 2 @ medium quality, 1536x1024
};

interface GenerateImageRequest {
  prompt: string;
  provider: Provider;
  // When true, deduct 1 credit for this image (used by standalone meal-plan
  // images). The normal recipe flow leaves this unset — the image is already
  // covered by the analyze-image credit.
  chargeCredit?: boolean;
}

interface GenerateImageResponse {
  imageData: string; // base64
  mimeType: string;
  costUsd: number;
}

async function generateWithImagen(
  prompt: string,
  model: string,
  costUsd: number
): Promise<GenerateImageResponse> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
    body: JSON.stringify({
      instances: [{ prompt }],
      parameters: {
        sampleCount: 1,
        aspectRatio: "16:9",
        personGeneration: "dont_allow",
      },
    }),
  });

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After");
    throw { isRateLimit: true, retryAfterSeconds: retryAfter ? parseInt(retryAfter, 10) : 30, provider: "imagen" };
  }
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Imagen API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  const prediction = data?.predictions?.[0];
  if (!prediction?.bytesBase64Encoded) {
    throw new Error("No image data in Imagen response");
  }

  return {
    imageData: prediction.bytesBase64Encoded,
    mimeType: prediction.mimeType || "image/png",
    costUsd,
  };
}

async function generateWithFlux(
  prompt: string,
  variant: "pro" | "schnell",
  costUsd: number
): Promise<GenerateImageResponse> {
  const endpoint =
    variant === "pro"
      ? "https://fal.run/fal-ai/flux-pro/v1.1"
      : "https://fal.run/fal-ai/flux/schnell";

  const body: Record<string, unknown> = {
    prompt,
    image_size: "landscape_16_9",
    num_images: 1,
    enable_safety_checker: true,
    output_format: "jpeg",
  };

  if (variant === "pro") {
    body.num_inference_steps = 28;
    body.guidance_scale = 3.5;
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${FAL_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After");
    throw { isRateLimit: true, retryAfterSeconds: retryAfter ? parseInt(retryAfter, 10) : 30, provider: "fal" };
  }
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Fal.ai API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  const imageUrl = data?.images?.[0]?.url;
  if (!imageUrl) {
    throw new Error("No image URL in Fal.ai response");
  }

  // Download the image and convert to base64
  const imageResponse = await fetch(imageUrl);
  if (!imageResponse.ok) {
    throw new Error(`Failed to download generated image: ${imageResponse.status}`);
  }

  const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
  const imageData = btoa(
    imageBytes.reduce((data, byte) => data + String.fromCharCode(byte), "")
  );

  return {
    imageData,
    mimeType: "image/jpeg",
    costUsd,
  };
}

async function generateWithOpenAI(
  prompt: string,
  costUsd: number
): Promise<GenerateImageResponse> {
  const response = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_IMAGE_MODEL,
      prompt,
      size: "1536x1024", // landscape, closest to 16:9
      quality: "medium",
      n: 1,
    }),
  });

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After");
    throw { isRateLimit: true, retryAfterSeconds: retryAfter ? parseInt(retryAfter, 10) : 30, provider: "openai" };
  }
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI image API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  // gpt-image-* models always return base64 (b64_json), never a URL.
  const b64 = data?.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error("No image data in OpenAI response");
  }

  return {
    imageData: b64,
    mimeType: "image/png",
    costUsd,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Authenticate user (optional for guests).
  // Prefer x-user-token (bypasses gateway JWT validation for expired tokens).
  // Fall back to Authorization for SDK-based callers.
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let userId: string | null = null;

  const userToken = req.headers.get("x-user-token")
    || req.headers.get("Authorization")?.replace("Bearer ", "") || null;
  if (userToken) {
    const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);
    if (!authError && user) {
      userId = user.id;
    }
  }

  // Rate limiting — authenticated users by id, guests by client IP.
  // (Guests previously skipped rate limiting entirely — audit finding H1; an
  // unauthenticated caller could run up unbounded paid image-generation spend.)
  {
    const clientIp = req.headers.get("cf-connecting-ip")
      || req.headers.get("x-forwarded-for")?.split(",")[0].trim()
      || "unknown";
    const { data: allowed } = userId
      ? await supabase.rpc("check_rate_limit", {
          p_user_id: userId,
          p_function_name: "generate-image",
          p_window_minutes: 1,
          p_max_requests: 10,
        })
      : await supabase.rpc("check_ip_rate_limit", {
          p_ip: clientIp,
          p_function_name: "generate-image",
          p_window_minutes: 1,
          p_max_requests: 5,
        });
    if (allowed === false) {
      return Response.json(
        { error: "rate_limited", message: "Too many requests. Please wait a moment." },
        { status: 429 }
      );
    }
  }

  let body: GenerateImageRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
  const { prompt, provider, chargeCredit } = body;

  if (!prompt) {
    return Response.json({ error: "prompt is required" }, { status: 400 });
  }
  // Cap prompt length to bound provider cost / prevent request amplification.
  if (typeof prompt !== "string" || prompt.length > 8000) {
    return Response.json({ error: "prompt is invalid or too long" }, { status: 400 });
  }

  // Optional per-image credit charge (standalone meal-plan images).
  // Refunded if generation fails. Requires an authenticated user.
  let creditPool: string | null = null;
  if (chargeCredit) {
    if (!userId) {
      return Response.json({ error: "Missing authorization" }, { status: 401 });
    }
    const { data: deductResult, error: deductError } = await supabase.rpc("deduct_credit", {
      p_user_id: userId,
      p_free_limit: 0, // images are a paid action — no free allotment
    });
    if (deductError) {
      console.error("deduct_credit RPC error:", deductError);
      return Response.json({ error: "Credit check failed" }, { status: 500 });
    }
    if (!deductResult?.success) {
      return Response.json(
        { error: "insufficient_credits", message: "You've run out of credits." },
        { status: 402 }
      );
    }
    creditPool = deductResult.pool;
  }

  try {
    const validProviders: Provider[] = [
      "imagen4",
      "imagen4fast",
      "fluxpro",
      "fluxschnell",
      "gptimage2",
    ];
    const selectedProvider = validProviders.includes(provider)
      ? provider
      : "imagen4";

    // Enhance prompt with photography context
    const enhancedPrompt = prompt + PHOTOGRAPHY_SUFFIX;

    let result: GenerateImageResponse;

    switch (selectedProvider) {
      case "imagen4":
        result = await generateWithImagen(
          enhancedPrompt,
          "imagen-4.0-generate-001",
          IMAGE_COST_USD.imagen4
        );
        break;
      case "imagen4fast":
        result = await generateWithImagen(
          enhancedPrompt,
          "imagen-4.0-fast-generate-001",
          IMAGE_COST_USD.imagen4fast
        );
        break;
      case "fluxpro":
        result = await generateWithFlux(enhancedPrompt, "pro", IMAGE_COST_USD.fluxpro);
        break;
      case "fluxschnell":
        result = await generateWithFlux(enhancedPrompt, "schnell", IMAGE_COST_USD.fluxschnell);
        break;
      case "gptimage2":
        result = await generateWithOpenAI(enhancedPrompt, IMAGE_COST_USD.gptimage2);
        break;
    }

    // Response size limit: 5MB for base64 image data
    const responseBody = JSON.stringify(result);
    if (responseBody.length > 5_000_000) {
      console.error("Response too large:", responseBody.length);
      if (userId && creditPool) {
        try { await supabase.rpc("refund_credit", { p_user_id: userId, p_pool: creditPool }); } catch (_) {}
      }
      return Response.json({ error: "Response exceeded size limit" }, { status: 502 });
    }
    return new Response(responseBody, { headers: { "Content-Type": "application/json" } });
  } catch (error: unknown) {
    // Refund the per-image credit if we charged one and generation failed.
    if (userId && creditPool) {
      try { await supabase.rpc("refund_credit", { p_user_id: userId, p_pool: creditPool }); }
      catch (e) { console.error("refund_credit failed:", e); }
    }

    if (error && typeof error === "object" && "isRateLimit" in error) {
      const rl = error as { retryAfterSeconds: number; provider: string };
      return Response.json(
        { error: "rate_limited", retryAfterSeconds: rl.retryAfterSeconds, provider: rl.provider },
        { status: 429 }
      );
    }
    console.error("generate-image error:", error);
    return Response.json(
      { error: "image_generation_failed", message: "Image generation failed. Please try again." },
      { status: 500 }
    );
  }
});
