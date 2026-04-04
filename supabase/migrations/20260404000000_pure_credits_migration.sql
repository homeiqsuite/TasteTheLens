-- Pure Credits Migration
--
-- Converts TasteTheLens from a hybrid (credits + subscription) model to a pure
-- pay-as-you-go credits model. Subscription and rollover credits are merged into
-- purchased_credits (which never expire). Feature gating switches from tier-based
-- to purchase-based: any credit purchase unlocks all premium features.
--
-- This migration is backward-compatible: old app versions that call existing RPCs
-- continue to work because subscription/rollover pools are zeroed and the RPCs
-- naturally fall through to purchased_credits.

-- ─── 1. Schema additions ────────────────────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS has_ever_purchased      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS welcome_credits_granted  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS credits_migrated         boolean NOT NULL DEFAULT false;

-- ─── 2. One-time data migration ─────────────────────────────────────────────────

-- 2a. Convert subscription + rollover credits into purchased credits for all users.
--     After this, subscription_credits and rollover_credits are 0 everywhere.
UPDATE public.users
SET
  purchased_credits  = COALESCE(purchased_credits, 0)
                     + COALESCE(subscription_credits, 0)
                     + COALESCE(rollover_credits, 0),
  subscription_credits = 0,
  rollover_credits     = 0,
  subscription_credit_reset_date = NULL,
  credits_migrated     = true
WHERE credits_migrated = false;

-- 2b. Set has_ever_purchased for anyone who has purchased credits (including
--     those just converted from subscription pools).
UPDATE public.users
SET has_ever_purchased = true
WHERE purchased_credits > 0
  AND has_ever_purchased = false;

-- 2c. Grant 5 welcome credits to existing free users who never purchased and
--     never received the signup bonus. This replaces the old monthly free tier.
UPDATE public.users
SET
  purchased_credits      = COALESCE(purchased_credits, 0) + 5,
  welcome_credits_granted = true
WHERE welcome_credits_granted = false
  AND COALESCE(signup_bonus_granted, false) = false
  AND purchased_credits = 0
  AND subscription_tier = 'free';

-- ─── 3. Updated RPCs (backward-compatible) ──────────────────────────────────────

-- 3a. update_subscription_tier: stop zeroing credits on downgrade.
--     Credits are now all purchased and must not be cleared.
CREATE OR REPLACE FUNCTION public.update_subscription_tier(tier_value text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: authentication required';
  END IF;

  IF tier_value NOT IN ('free', 'chefsTable', 'atelier') THEN
    RAISE EXCEPTION 'Invalid tier value: %', tier_value;
  END IF;

  UPDATE public.users
  SET subscription_tier = tier_value
  WHERE id = auth.uid();
END;
$$;

-- 3b. update_subscription_tier_for_user: same change — update tier column only,
--     do not zero credit pools.
CREATE OR REPLACE FUNCTION public.update_subscription_tier_for_user(
  p_user_id uuid,
  p_tier    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_tier NOT IN ('free', 'chefsTable', 'atelier') THEN
    RAISE EXCEPTION 'Invalid tier value: %', p_tier;
  END IF;

  UPDATE public.users
  SET subscription_tier = p_tier
  WHERE id = p_user_id;
END;
$$;

-- Keep service-role-only access
REVOKE ALL ON FUNCTION public.update_subscription_tier_for_user(uuid, text) FROM PUBLIC, anon, authenticated;

-- 3c. get_credits: add has_ever_purchased to the response.
CREATE OR REPLACE FUNCTION public.get_credits(user_id_param text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  p_credits   integer;
  s_credits   integer;
  r_credits   integer;
  sub_tier    text;
  ever_purchased boolean;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != user_id_param::uuid THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  SELECT
    COALESCE(purchased_credits, 0),
    COALESCE(subscription_credits, 0),
    COALESCE(rollover_credits, 0),
    COALESCE(subscription_tier, 'free'),
    COALESCE(has_ever_purchased, false)
  INTO p_credits, s_credits, r_credits, sub_tier, ever_purchased
  FROM public.users
  WHERE id = user_id_param::uuid;

  RETURN json_build_object(
    'purchased_credits',    COALESCE(p_credits, 0),
    'subscription_credits', COALESCE(s_credits, 0),
    'rollover_credits',     COALESCE(r_credits, 0),
    'subscription_tier',    COALESCE(sub_tier, 'free'),
    'has_ever_purchased',   COALESCE(ever_purchased, false)
  );
END;
$$;

-- 3d. add_purchased_credits: also set has_ever_purchased = true.
CREATE OR REPLACE FUNCTION public.add_purchased_credits(
  user_id_param text,
  credit_count  integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != user_id_param::uuid THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  IF credit_count <= 0 THEN
    RAISE EXCEPTION 'credit_count must be positive';
  END IF;

  UPDATE public.users
  SET
    purchased_credits  = COALESCE(purchased_credits, 0) + credit_count,
    has_ever_purchased = true
  WHERE id = user_id_param::uuid;
END;
$$;

-- ─── 4. New RPCs ────────────────────────────────────────────────────────────────

-- 4a. convert_renewal_to_credits: called by the App Store webhook when an
--     existing subscription renews. Adds credits as purchased (never expire).
--     Service-role only — not callable by clients.
CREATE OR REPLACE FUNCTION public.convert_renewal_to_credits(
  p_user_id uuid,
  p_credits integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_credits <= 0 THEN
    RAISE EXCEPTION 'p_credits must be positive';
  END IF;

  UPDATE public.users
  SET
    purchased_credits  = COALESCE(purchased_credits, 0) + p_credits,
    has_ever_purchased = true
  WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.convert_renewal_to_credits(uuid, integer) FROM PUBLIC, anon, authenticated;

-- 4b. grant_welcome_credits: idempotent welcome credit grant for new users.
--     Returns whether credits were actually granted.
CREATE OR REPLACE FUNCTION public.grant_welcome_credits(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  already_granted boolean;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  SELECT COALESCE(welcome_credits_granted, false)
  INTO already_granted
  FROM public.users
  WHERE id = p_user_id;

  IF already_granted THEN
    RETURN json_build_object('granted', false, 'credits_added', 0);
  END IF;

  UPDATE public.users
  SET
    purchased_credits      = COALESCE(purchased_credits, 0) + 5,
    welcome_credits_granted = true
  WHERE id = p_user_id;

  RETURN json_build_object('granted', true, 'credits_added', 5);
END;
$$;
