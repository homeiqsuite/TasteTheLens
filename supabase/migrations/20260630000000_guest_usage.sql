-- Server-side enforcement of the guest (unauthenticated) free-tier limit.
--
-- Previously, the 5-generations/month guest limit lived ONLY in the client
-- (UserDefaults in UsageTracker). The analyze-image edge function did no
-- enforcement for guests, so clearing app data — or calling the endpoint
-- directly — granted unlimited free AI generations (each ~$0.045 cost, $0 revenue).
--
-- This migration adds a server-tracked counter keyed by a stable per-install
-- guest id (a UUID the client stores in the Keychain and sends as the
-- `x-guest-id` header). The deduct/refund RPCs mirror the free-tier branch of
-- the existing `deduct_credit`/`refund_credit` functions for authenticated users.

-- ─── 1. Table ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.guest_usage (
  guest_id          uuid PRIMARY KEY,
  usage_count_month integer NOT NULL DEFAULT 0,
  usage_reset_date  timestamptz NOT NULL DEFAULT date_trunc('month', now() + interval '1 month'),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- RLS on, no policies: only the service role (edge functions) may touch it.
ALTER TABLE public.guest_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.guest_usage FROM PUBLIC, anon, authenticated;

-- ─── 2. Deduct one guest generation ──────────────────────────────────────────
-- Mirrors deduct_credit's free-tier branch (monthly reset + cap). Returns the
-- same `free_usage_count` / `pool` shape so the client's CreditBalance decoder
-- and existing 402 handling work unchanged.

CREATE OR REPLACE FUNCTION public.deduct_guest_generation(
  p_guest_id uuid,
  p_free_limit integer DEFAULT 5
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_row public.guest_usage%ROWTYPE;
BEGIN
  -- Upsert-then-lock: ensure a row exists, then lock it for the read/modify.
  INSERT INTO public.guest_usage (guest_id)
    VALUES (p_guest_id)
    ON CONFLICT (guest_id) DO NOTHING;

  SELECT * INTO v_row FROM public.guest_usage WHERE guest_id = p_guest_id FOR UPDATE;

  -- Reset the monthly counter if we're past the reset date.
  IF now() >= v_row.usage_reset_date THEN
    v_row.usage_count_month := 0;
    UPDATE public.guest_usage
      SET usage_count_month = 0,
          usage_reset_date  = date_trunc('month', now() + interval '1 month'),
          updated_at        = now()
      WHERE guest_id = p_guest_id;
  END IF;

  IF v_row.usage_count_month < p_free_limit THEN
    UPDATE public.guest_usage
      SET usage_count_month = usage_count_month + 1,
          updated_at        = now()
      WHERE guest_id = p_guest_id
      RETURNING usage_count_month INTO v_row.usage_count_month;

    RETURN jsonb_build_object(
      'success', true,
      'pool', 'free',
      'purchased_credits', 0,
      'subscription_credits', 0,
      'rollover_credits', 0,
      'free_usage_count', v_row.usage_count_month
    );
  END IF;

  -- Over the free limit. Guests have no purchased pool (only authenticated
  -- users can buy credits), so this is a hard stop.
  RETURN jsonb_build_object(
    'success', false,
    'error', 'insufficient_credits',
    'free_usage_count', v_row.usage_count_month,
    'free_limit', p_free_limit,
    'purchased_credits', 0
  );
END;
$function$;

-- ─── 3. Refund one guest generation ──────────────────────────────────────────
-- Called when a generation fails after deduction (screening error, content
-- rejection, AI failure), so the guest isn't charged for nothing.

CREATE OR REPLACE FUNCTION public.refund_guest_generation(p_guest_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  UPDATE public.guest_usage
    SET usage_count_month = greatest(usage_count_month - 1, 0),
        updated_at        = now()
    WHERE guest_id = p_guest_id;
END;
$function$;

-- Only the service role may call these (edge functions use the service key).
REVOKE ALL ON FUNCTION public.deduct_guest_generation(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refund_guest_generation(uuid) FROM PUBLIC, anon, authenticated;
