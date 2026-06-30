-- Meal Plan Sharing
--
-- Enables deep-link sharing of meal plans and individual meals, mirroring how
-- recipes are shared: a public-read policy lets any app user open a plan/meal by
-- its UUID, and a public storage bucket holds the meal images.

-- ─── 1. Public-read RLS (additive to existing owner-only policies) ───────────────

DROP POLICY IF EXISTS "Anyone can read non-deleted meal plans for sharing" ON public.meal_plans;
CREATE POLICY "Anyone can read non-deleted meal plans for sharing"
  ON public.meal_plans
  FOR SELECT
  USING (is_deleted = false);

DROP POLICY IF EXISTS "Anyone can read shared meal plan meals" ON public.meal_plan_meals;
CREATE POLICY "Anyone can read shared meal plan meals"
  ON public.meal_plan_meals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = meal_plan_meals.meal_plan_id
        AND mp.is_deleted = false
    )
  );

-- ─── 2. Public storage bucket for meal images ───────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('meal-images', 'meal-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Public read (bucket is public; explicit policy for the storage API path too).
DROP POLICY IF EXISTS "Public read meal images" ON storage.objects;
CREATE POLICY "Public read meal images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'meal-images');

-- Authenticated users may write only under their own {uid}/... prefix.
DROP POLICY IF EXISTS "Users upload own meal images" ON storage.objects;
CREATE POLICY "Users upload own meal images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users update own meal images" ON storage.objects;
CREATE POLICY "Users update own meal images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
