-- ─── Analytics Events ────────────────────────────────────────────────────────
-- General behavioral event stream (app_opened, recipe_saved, challenge_created, etc.)

CREATE TABLE analytics_events (
    id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
    event_name  TEXT        NOT NULL,
    properties  JSONB       DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analytics_events_user_id    ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_event_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Only service role (edge functions) may read/write
CREATE POLICY "service_role_all" ON analytics_events
    FOR ALL TO service_role USING (true);


-- ─── Generation Costs ────────────────────────────────────────────────────────
-- Per-recipe AI cost breakdown (analysis tokens + image generation)

CREATE TABLE generation_costs (
    id                      UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id                 UUID        REFERENCES auth.users(id) ON DELETE SET NULL,

    -- Recipe analysis (Gemini or Claude)
    analysis_provider       TEXT,       -- 'gemini' | 'claude'
    analysis_model          TEXT,       -- e.g. 'gemini-2.5-flash', 'claude-sonnet-4-20250514'
    analysis_input_tokens   INTEGER,
    analysis_output_tokens  INTEGER,
    analysis_cost_usd       NUMERIC(10, 6),

    -- Image generation
    image_provider          TEXT,       -- 'imagen4' | 'imagen4fast' | 'fluxpro' | 'fluxschnell'
    image_cost_usd          NUMERIC(10, 6),

    -- Roll-up
    total_cost_usd          NUMERIC(10, 6),

    -- Generation context
    capture_mode            TEXT,       -- 'single' | 'fusion'
    image_count             INTEGER     DEFAULT 1,
    chef_personality        TEXT,

    created_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_generation_costs_user_id    ON generation_costs(user_id);
CREATE INDEX idx_generation_costs_created_at ON generation_costs(created_at DESC);

ALTER TABLE generation_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON generation_costs
    FOR ALL TO service_role USING (true);
