-- ============================================================================
-- Baseline recovery of previously-untracked, security-critical objects
-- ============================================================================
-- The rate-limiting and credit-control objects below existed ONLY in the live
-- database (created via the dashboard / ad-hoc), so the controls that gate every
-- paid AI call could not be reviewed or reproduced from version control. This
-- migration captures their exact current definitions so they are auditable, and
-- adds a previously-missing explicit `search_path` to each SECURITY DEFINER
-- function (silences the Supabase security advisor; behaviour is unchanged
-- because every object reference is already schema-qualified).
--
-- All statements are idempotent — safe to run against the existing production
-- database and against a fresh branch.
--
-- NOTE: This is a PARTIAL baseline limited to the security controls flagged in
-- the audit. A full `supabase db pull` baseline of the remaining tables
-- (users, recipes, remote_config, chef_prompts, etc.) is recommended as a
-- follow-up for complete from-zero reproducibility.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- rate_limits — backing table for check_rate_limit (1-minute sliding window)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rate_limits (
  user_id       uuid        NOT NULL,
  function_name text        NOT NULL,
  window_start  timestamptz NOT NULL,
  request_count integer     NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, function_name, window_start)
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
-- Intentionally no policies: only SECURITY DEFINER functions (which run as the
-- table owner) and the service role touch this table. Clients have no access.

-- ---------------------------------------------------------------------------
-- check_rate_limit — per (user_id, function_name) counter within the minute
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id uuid,
  p_function_name text,
  p_window_minutes integer DEFAULT 1,
  p_max_requests integer DEFAULT 10
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  current_count integer;
  window_start_time timestamptz;
BEGIN
  -- Truncate to minute boundary for windowing
  window_start_time := date_trunc('minute', now());

  -- Cleanup old entries (older than 5 minutes) to prevent table bloat
  DELETE FROM public.rate_limits
  WHERE window_start < now() - interval '5 minutes';

  -- Upsert: insert or increment counter
  INSERT INTO public.rate_limits (user_id, function_name, window_start, request_count)
  VALUES (p_user_id, p_function_name, window_start_time, 1)
  ON CONFLICT (user_id, function_name, window_start)
  DO UPDATE SET request_count = public.rate_limits.request_count + 1
  RETURNING request_count INTO current_count;

  RETURN current_count <= p_max_requests;
END;
$function$;

REVOKE ALL ON FUNCTION public.check_rate_limit(uuid, text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(uuid, text, integer, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- check_ip_rate_limit — guest-path rate limiting (audit finding H1)
-- Guests have no user id, so previously they bypassed rate limiting entirely.
-- This derives a stable surrogate uuid from the client IP and reuses the same
-- rate_limits machinery, namespacing the function_name so guest and user
-- counters never collide.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_ip_rate_limit(
  p_ip text,
  p_function_name text,
  p_window_minutes integer DEFAULT 1,
  p_max_requests integer DEFAULT 10
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT public.check_rate_limit(
    (md5('ip:' || COALESCE(p_ip, 'unknown')))::uuid,
    'ip:' || p_function_name,
    p_window_minutes,
    p_max_requests
  );
$function$;

REVOKE ALL ON FUNCTION public.check_ip_rate_limit(text, text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_ip_rate_limit(text, text, integer, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- deduct_credit — atomic per-generation credit deduction (rollover ->
-- subscription -> purchased, or free monthly counter -> purchased)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deduct_credit(p_user_id uuid, p_free_limit integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_row public.users%ROWTYPE;
  v_pool text;
  v_is_subscriber boolean;
BEGIN
  -- Lock the user row to prevent concurrent deductions
  SELECT * INTO v_row FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_not_found');
  END IF;

  v_is_subscriber := COALESCE(v_row.subscription_tier, 'free') IN ('chefsTable', 'atelier');

  IF v_is_subscriber THEN
    -- Subscriber: deduct rollover -> subscription -> purchased
    IF COALESCE(v_row.rollover_credits, 0) > 0 THEN
      UPDATE public.users SET rollover_credits = rollover_credits - 1 WHERE id = p_user_id;
      v_pool := 'rollover';
    ELSIF COALESCE(v_row.subscription_credits, 0) > 0 THEN
      UPDATE public.users SET subscription_credits = subscription_credits - 1 WHERE id = p_user_id;
      v_pool := 'subscription';
    ELSIF COALESCE(v_row.purchased_credits, 0) > 0 THEN
      UPDATE public.users SET purchased_credits = purchased_credits - 1 WHERE id = p_user_id;
      v_pool := 'purchased';
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error', 'insufficient_credits',
        'purchased_credits', COALESCE(v_row.purchased_credits, 0),
        'subscription_credits', COALESCE(v_row.subscription_credits, 0),
        'rollover_credits', COALESCE(v_row.rollover_credits, 0)
      );
    END IF;
  ELSE
    -- Free tier: reset monthly counter if past reset date
    IF now() >= COALESCE(v_row.usage_reset_date, now()) THEN
      UPDATE public.users
        SET usage_count_month = 0,
            usage_reset_date = date_trunc('month', now() + interval '1 month')
        WHERE id = p_user_id;
      v_row.usage_count_month := 0;
    END IF;

    IF COALESCE(v_row.usage_count_month, 0) < p_free_limit THEN
      UPDATE public.users SET usage_count_month = COALESCE(usage_count_month, 0) + 1 WHERE id = p_user_id;
      v_pool := 'free';
    ELSIF COALESCE(v_row.purchased_credits, 0) > 0 THEN
      UPDATE public.users SET purchased_credits = purchased_credits - 1 WHERE id = p_user_id;
      v_pool := 'purchased';
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error', 'insufficient_credits',
        'free_usage_count', COALESCE(v_row.usage_count_month, 0),
        'free_limit', p_free_limit,
        'purchased_credits', COALESCE(v_row.purchased_credits, 0)
      );
    END IF;
  END IF;

  -- Re-read updated row for the response
  SELECT * INTO v_row FROM public.users WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'pool', v_pool,
    'purchased_credits', COALESCE(v_row.purchased_credits, 0),
    'subscription_credits', COALESCE(v_row.subscription_credits, 0),
    'rollover_credits', COALESCE(v_row.rollover_credits, 0),
    'free_usage_count', COALESCE(v_row.usage_count_month, 0)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.deduct_credit(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.deduct_credit(uuid, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- refund_credit — return one credit to the pool it was taken from (on failure)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refund_credit(p_user_id uuid, p_pool text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  CASE p_pool
    WHEN 'rollover' THEN
      UPDATE public.users SET rollover_credits = COALESCE(rollover_credits, 0) + 1 WHERE id = p_user_id;
    WHEN 'subscription' THEN
      UPDATE public.users SET subscription_credits = COALESCE(subscription_credits, 0) + 1 WHERE id = p_user_id;
    WHEN 'purchased' THEN
      UPDATE public.users SET purchased_credits = COALESCE(purchased_credits, 0) + 1 WHERE id = p_user_id;
    WHEN 'free' THEN
      UPDATE public.users SET usage_count_month = greatest(COALESCE(usage_count_month, 0) - 1, 0) WHERE id = p_user_id;
  END CASE;
END;
$function$;

-- NOTE: refund_credit's grants are intentionally left untouched. The iOS client
-- calls it directly as the `authenticated` role (ImageAnalysisPipeline refund-on-
-- failure path), so locking it to service_role only would break that flow.
-- (CREATE OR REPLACE above preserves the existing grants.) Tightening this safely
-- requires moving the client refund into the edge function first — tracked separately.

-- ---------------------------------------------------------------------------
-- Storage buckets for recipe imagery (private; access governed by RLS policies)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('inspiration-images', 'inspiration-images', false, 5242880, ARRAY['image/jpeg', 'image/png']),
  ('dish-images',        'dish-images',        false, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO NOTHING;
