-- Fix 1: update_subscription_tier now zeros subscription credits when downgrading to free.
-- This makes the function the single authoritative place for tier + credit clearing,
-- so both webhook-triggered lapses and client-initiated lapses stay consistent.

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
  SET
    subscription_tier = tier_value,
    -- Zero subscription credits when downgrading to free
    subscription_credits = CASE WHEN tier_value = 'free' THEN 0 ELSE subscription_credits END,
    rollover_credits    = CASE WHEN tier_value = 'free' THEN 0 ELSE rollover_credits END,
    subscription_credit_reset_date = CASE WHEN tier_value = 'free' THEN NULL ELSE subscription_credit_reset_date END
  WHERE id = auth.uid();
END;
$$;

-- Fix 2: get_credits now also returns subscription_tier so the client can detect
-- a server-confirmed lapse in a single RPC call rather than a separate query.

CREATE OR REPLACE FUNCTION public.get_credits(user_id_param text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  p_credits integer;
  s_credits integer;
  r_credits integer;
  sub_tier  text;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() != user_id_param::uuid THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  SELECT
    COALESCE(purchased_credits, 0),
    COALESCE(subscription_credits, 0),
    COALESCE(rollover_credits, 0),
    COALESCE(subscription_tier, 'free')
  INTO p_credits, s_credits, r_credits, sub_tier
  FROM public.users
  WHERE id = user_id_param::uuid;

  RETURN json_build_object(
    'purchased_credits',   COALESCE(p_credits, 0),
    'subscription_credits', COALESCE(s_credits, 0),
    'rollover_credits',    COALESCE(r_credits, 0),
    'subscription_tier',   COALESCE(sub_tier, 'free')
  );
END;
$$;

-- Fix 3: Service-role version of tier update used by the App Store Server
-- Notifications webhook (runs outside user auth context).
-- Only callable with the service role key — not exposed to clients.

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
  SET
    subscription_tier = p_tier,
    subscription_credits = CASE WHEN p_tier = 'free' THEN 0 ELSE subscription_credits END,
    rollover_credits    = CASE WHEN p_tier = 'free' THEN 0 ELSE rollover_credits END,
    subscription_credit_reset_date = CASE WHEN p_tier = 'free' THEN NULL ELSE subscription_credit_reset_date END
  WHERE id = p_user_id;
END;
$$;

-- Revoke public/anon access to the service-role function
REVOKE ALL ON FUNCTION public.update_subscription_tier_for_user(uuid, text) FROM PUBLIC, anon, authenticated;
