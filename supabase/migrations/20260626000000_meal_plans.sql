-- Weekly Meal Plans
--
-- Adds storage for AI-generated weekly meal plans and the atomic multi-credit
-- RPCs the generate-meal-plan edge function needs. A meal plan costs 1 credit
-- per meal recipe (deducted up front); per-meal images cost 1 credit each and
-- are charged separately via the existing single-credit deduct_credit RPC.

-- ─── 1. Tables ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.meal_plans (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chef          text,
  title         text,
  days_count    integer NOT NULL DEFAULT 7,
  meals_per_day integer NOT NULL DEFAULT 3,
  grocery_list  jsonb   NOT NULL DEFAULT '[]'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  is_deleted    boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.meal_plan_meals (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id uuid NOT NULL REFERENCES public.meal_plans(id) ON DELETE CASCADE,
  day          integer NOT NULL,
  meal_type    text NOT NULL,
  dish_name    text,
  data         jsonb NOT NULL,   -- full meal recipe (components, steps, nutrition, sources…)
  image_path   text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_meal_plans_user        ON public.meal_plans(user_id) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_meal_plan_meals_plan   ON public.meal_plan_meals(meal_plan_id);

-- ─── 2. Row Level Security ──────────────────────────────────────────────────────

ALTER TABLE public.meal_plans      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plan_meals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own meal plans" ON public.meal_plans;
CREATE POLICY "Users manage own meal plans" ON public.meal_plans
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own meal plan meals" ON public.meal_plan_meals;
CREATE POLICY "Users manage own meal plan meals" ON public.meal_plan_meals
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.meal_plans mp
            WHERE mp.id = meal_plan_meals.meal_plan_id AND mp.user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.meal_plans mp
            WHERE mp.id = meal_plan_meals.meal_plan_id AND mp.user_id = auth.uid())
  );

-- ─── 3. Atomic multi-credit RPCs (service-role only) ────────────────────────────
-- Mirrors the single-credit deduct_credit/refund_credit return shape so the
-- edge function and client can treat balances uniformly. Deducts across pools in
-- priority order (purchased → subscription → rollover). In the pure-credits model
-- only purchased_credits is non-zero, but the others are kept for safety.

CREATE OR REPLACE FUNCTION public.deduct_credits(
  p_user_id uuid,
  p_amount  integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_credits integer;
  s_credits integer;
  r_credits integer;
  total     integer;
  remaining integer;
  take      integer;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'p_amount must be positive';
  END IF;

  -- Lock the row for the duration of the transaction.
  SELECT COALESCE(purchased_credits, 0),
         COALESCE(subscription_credits, 0),
         COALESCE(rollover_credits, 0)
  INTO p_credits, s_credits, r_credits
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'reason', 'user_not_found');
  END IF;

  total := p_credits + s_credits + r_credits;
  IF total < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'reason', 'insufficient_credits',
      'purchased_credits', p_credits,
      'subscription_credits', s_credits,
      'rollover_credits', r_credits
    );
  END IF;

  remaining := p_amount;

  take := LEAST(remaining, p_credits);
  p_credits := p_credits - take;
  remaining := remaining - take;

  IF remaining > 0 THEN
    take := LEAST(remaining, s_credits);
    s_credits := s_credits - take;
    remaining := remaining - take;
  END IF;

  IF remaining > 0 THEN
    take := LEAST(remaining, r_credits);
    r_credits := r_credits - take;
    remaining := remaining - take;
  END IF;

  UPDATE public.users
  SET purchased_credits    = p_credits,
      subscription_credits = s_credits,
      rollover_credits     = r_credits
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'pool', 'multi',
    'amount', p_amount,
    'purchased_credits', p_credits,
    'subscription_credits', s_credits,
    'rollover_credits', r_credits
  );
END;
$$;

REVOKE ALL ON FUNCTION public.deduct_credits(uuid, integer) FROM PUBLIC, anon, authenticated;

-- Refund N credits back to the purchased pool (never expires).
CREATE OR REPLACE FUNCTION public.refund_credits(
  p_user_id uuid,
  p_amount  integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_credits integer;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'p_amount must be positive';
  END IF;

  UPDATE public.users
  SET purchased_credits = COALESCE(purchased_credits, 0) + p_amount
  WHERE id = p_user_id
  RETURNING purchased_credits INTO p_credits;

  RETURN json_build_object('success', true, 'purchased_credits', COALESCE(p_credits, 0));
END;
$$;

REVOKE ALL ON FUNCTION public.refund_credits(uuid, integer) FROM PUBLIC, anon, authenticated;
