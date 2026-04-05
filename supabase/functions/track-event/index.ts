import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ─── Request Types ────────────────────────────────────────────────────────────

interface CostEntry {
  analysisProvider?: string;
  analysisModel?: string;
  analysisInputTokens?: number;
  analysisOutputTokens?: number;
  analysisCostUsd?: number;
  imageProvider?: string;
  imageCostUsd?: number;
  totalCostUsd?: number;
  captureMode?: string;
  imageCount?: number;
  chefPersonality?: string;
}

interface TrackEventRequest {
  event: string;
  properties?: Record<string, unknown>;
  costEntry?: CostEntry;
}

// ─── Handler ──────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Resolve user (optional — guests send events without a token)
  let userId: string | null = null;
  const userToken =
    req.headers.get("x-user-token") ||
    req.headers.get("Authorization")?.replace("Bearer ", "") ||
    null;
  if (userToken) {
    const {
      data: { user },
    } = await supabase.auth.getUser(userToken);
    if (user) userId = user.id;
  }

  try {
    const { event, properties, costEntry }: TrackEventRequest = await req.json();

    if (!event || typeof event !== "string") {
      return Response.json({ error: "event is required" }, { status: 400 });
    }

    // Run both inserts concurrently; swallow individual errors so a DB hiccup
    // never propagates back to the iOS client.
    const inserts: Promise<void>[] = [
      supabase
        .from("analytics_events")
        .insert({
          user_id: userId,
          event_name: event,
          properties: properties ?? {},
        })
        .then(({ error }) => {
          if (error) console.error("analytics_events insert error:", error);
        }),
    ];

    if (costEntry) {
      inserts.push(
        supabase
          .from("generation_costs")
          .insert({
            user_id: userId,
            analysis_provider: costEntry.analysisProvider ?? null,
            analysis_model: costEntry.analysisModel ?? null,
            analysis_input_tokens: costEntry.analysisInputTokens ?? null,
            analysis_output_tokens: costEntry.analysisOutputTokens ?? null,
            analysis_cost_usd: costEntry.analysisCostUsd ?? null,
            image_provider: costEntry.imageProvider ?? null,
            image_cost_usd: costEntry.imageCostUsd ?? null,
            total_cost_usd: costEntry.totalCostUsd ?? null,
            capture_mode: costEntry.captureMode ?? null,
            image_count: costEntry.imageCount ?? 1,
            chef_personality: costEntry.chefPersonality ?? null,
          })
          .then(({ error }) => {
            if (error) console.error("generation_costs insert error:", error);
          })
      );
    }

    await Promise.all(inserts);
    return Response.json({ ok: true });
  } catch (error) {
    console.error("track-event error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
