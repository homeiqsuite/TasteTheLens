import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const FAL_API_KEY = Deno.env.get("FAL_API_KEY")!;

const PHOTOGRAPHY_SUFFIX =
  " Professional editorial food photography, Michelin star presentation, warm inviting lighting, shallow depth of field, 85mm lens, appetizing and delicious.";

type Provider = "imagen4" | "imagen4fast" | "fluxpro" | "fluxschnell";

interface GenerateImageRequest {
  prompt: string;
  provider: Provider;
}

interface GenerateImageResponse {
  imageData: string; // base64
  mimeType: string;
}

async function generateWithImagen(
  prompt: string,
  model: string
): Promise<GenerateImageResponse> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict?key=${GEMINI_API_KEY}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
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
  };
}

async function generateWithFlux(
  prompt: string,
  variant: "pro" | "schnell"
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
  };
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
      p_function_name: "generate-image",
      p_window_minutes: 1,
      p_max_requests: 10,
    });
    if (allowed === false) {
      return Response.json(
        { error: "rate_limited", message: "Too many requests. Please wait a moment." },
        { status: 429 }
      );
    }
  }

  try {
    const { prompt, provider }: GenerateImageRequest = await req.json();

    if (!prompt) {
      return Response.json({ error: "prompt is required" }, { status: 400 });
    }

    const validProviders: Provider[] = [
      "imagen4",
      "imagen4fast",
      "fluxpro",
      "fluxschnell",
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
          "imagen-4.0-generate-001"
        );
        break;
      case "imagen4fast":
        result = await generateWithImagen(
          enhancedPrompt,
          "imagen-4.0-fast-generate-001"
        );
        break;
      case "fluxpro":
        result = await generateWithFlux(enhancedPrompt, "pro");
        break;
      case "fluxschnell":
        result = await generateWithFlux(enhancedPrompt, "schnell");
        break;
    }

    // Response size limit: 5MB for base64 image data
    const responseBody = JSON.stringify(result);
    if (responseBody.length > 5_000_000) {
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
    console.error("generate-image error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
