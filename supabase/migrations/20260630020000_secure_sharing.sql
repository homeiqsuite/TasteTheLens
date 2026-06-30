-- ============================================================================
-- Fix broken access control on sharing (audit finding C1) + lock down images
-- ============================================================================
-- Previously, sharing was implemented with blanket SELECT policies:
--     "Anyone can read non-deleted meal plans for sharing" USING (is_deleted = false)
--     "Anyone can read non-deleted recipes for sharing"    USING (is_deleted = false)
-- Because the policies have no owner/secret predicate, ANY holder of the public
-- anon key could read EVERY user's meal plans and recipes in bulk
-- (e.g. `GET /rest/v1/recipes?select=*`). The matching storage policies leaked
-- the inspiration/dish images of every non-deleted recipe the same way.
--
-- This migration replaces "public by id" with "public by secret share token":
--   * Direct table SELECT is owner-only (no bulk-enumerable path remains).
--   * A non-owner can read a single item ONLY by presenting its random
--     share_token to a SECURITY DEFINER function — there is no way to list.
--   * Shared-image storage access is scoped to recipes that actually have a token.
-- Sharing model chosen: unguessable links (no signed URLs).
-- ============================================================================

-- 1) Share-token columns -----------------------------------------------------
ALTER TABLE public.meal_plans ADD COLUMN IF NOT EXISTS share_token uuid;
ALTER TABLE public.recipes    ADD COLUMN IF NOT EXISTS share_token uuid;

CREATE INDEX IF NOT EXISTS meal_plans_share_token_idx
  ON public.meal_plans (share_token) WHERE share_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS recipes_share_token_idx
  ON public.recipes (share_token) WHERE share_token IS NOT NULL;

-- 2) Remove the over-broad public SELECT policies ----------------------------
-- Owner policies ("Users manage own meal plans", "Users can select own recipes")
-- and the tasting-menu participant policies are intentionally left untouched.
DROP POLICY IF EXISTS "Anyone can read non-deleted meal plans for sharing" ON public.meal_plans;
DROP POLICY IF EXISTS "Anyone can read shared meal plan meals"             ON public.meal_plan_meals;
DROP POLICY IF EXISTS "Anyone can read non-deleted recipes for sharing"    ON public.recipes;

-- 3) Token-scoped read RPCs (sole non-owner read path; not enumerable) -------
-- RETURNS SETOF <table> so the existing client DTOs decode unchanged.
CREATE OR REPLACE FUNCTION public.get_shared_meal_plan(p_token uuid)
RETURNS SETOF public.meal_plans
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT * FROM public.meal_plans
  WHERE share_token = p_token AND is_deleted = false;
$$;

CREATE OR REPLACE FUNCTION public.get_shared_meal_plan_meals(p_token uuid)
RETURNS SETOF public.meal_plan_meals
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT m.* FROM public.meal_plan_meals m
  JOIN public.meal_plans p ON p.id = m.meal_plan_id
  WHERE p.share_token = p_token AND p.is_deleted = false;
$$;

CREATE OR REPLACE FUNCTION public.get_shared_recipe(p_token uuid)
RETURNS SETOF public.recipes
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT * FROM public.recipes
  WHERE share_token = p_token AND COALESCE(is_deleted, false) = false;
$$;

-- 4) Owner-only share / unshare (token generation + revocation) --------------
-- auth.uid() is read from the request JWT even inside SECURITY DEFINER, so the
-- owner check below is the authorization boundary.
CREATE OR REPLACE FUNCTION public.share_meal_plan(p_id uuid)
RETURNS TABLE(token uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_token uuid;
BEGIN
  UPDATE public.meal_plans
    SET share_token = COALESCE(share_token, gen_random_uuid())
    WHERE id = p_id AND user_id = auth.uid() AND is_deleted = false
    RETURNING share_token INTO v_token;
  IF v_token IS NULL THEN
    RAISE EXCEPTION 'not_authorized_or_not_found';
  END IF;
  RETURN QUERY SELECT v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.unshare_meal_plan(p_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.meal_plans SET share_token = NULL
  WHERE id = p_id AND user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.share_recipe(p_id uuid)
RETURNS TABLE(token uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_token uuid;
BEGIN
  UPDATE public.recipes
    SET share_token = COALESCE(share_token, gen_random_uuid())
    WHERE id = p_id AND user_id = auth.uid() AND COALESCE(is_deleted, false) = false
    RETURNING share_token INTO v_token;
  IF v_token IS NULL THEN
    RAISE EXCEPTION 'not_authorized_or_not_found';
  END IF;
  RETURN QUERY SELECT v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.unshare_recipe(p_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.recipes SET share_token = NULL
  WHERE id = p_id AND user_id = auth.uid();
$$;

-- 5) Grants: read RPCs callable by guests + users; mutators by users only -----
REVOKE ALL ON FUNCTION public.get_shared_meal_plan(uuid)       FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_shared_meal_plan_meals(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_shared_recipe(uuid)          FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shared_meal_plan(uuid)       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_shared_meal_plan_meals(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_shared_recipe(uuid)          TO anon, authenticated;

REVOKE ALL ON FUNCTION public.share_meal_plan(uuid)   FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unshare_meal_plan(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.share_recipe(uuid)      FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unshare_recipe(uuid)    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.share_meal_plan(uuid)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.unshare_meal_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.share_recipe(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.unshare_recipe(uuid)    TO authenticated;

-- 6) Tighten shared-image storage policies to token-shared recipes only -------
-- (Owner-read, menu-participant-read, and upload/delete policies are unchanged.)
DROP POLICY IF EXISTS "Anyone can read dish images for shared recipes" ON storage.objects;
CREATE POLICY "Anyone can read dish images for shared recipes"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'dish-images'
    AND name IN (
      SELECT dish_image_path FROM public.recipes
      WHERE dish_image_path IS NOT NULL
        AND share_token IS NOT NULL
        AND COALESCE(is_deleted, false) = false
    )
  );

DROP POLICY IF EXISTS "Anyone can read inspiration images for shared recipes" ON storage.objects;
CREATE POLICY "Anyone can read inspiration images for shared recipes"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'inspiration-images'
    AND name IN (
      SELECT inspiration_image_path FROM public.recipes
      WHERE inspiration_image_path IS NOT NULL
        AND share_token IS NOT NULL
        AND COALESCE(is_deleted, false) = false
    )
  );

-- 7) Lock down the meal-images bucket to match the recipe buckets ------------
-- This bucket was previously public (URL-readable by anyone and NOT revocable):
-- a meal image kept serving even after the plan was unshared or deleted, which
-- contradicts the "deleting revokes the link" guarantee. Make it private and
-- gate reads on owner OR token-shared, non-deleted plan, mirroring the recipe
-- image buckets. The iOS client downloads via the authenticated Storage API
-- (SyncManager), which works against a private bucket.
UPDATE storage.buckets SET public = false WHERE id = 'meal-images';

DROP POLICY IF EXISTS "Public read meal images" ON storage.objects;

-- Owner can always read their own meal images (the dropped public policy used
-- to cover this implicitly).
CREATE POLICY "Users can read own meal images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'meal-images'
    AND (storage.foldername(name))[1] = (auth.uid())::text
  );

-- Anyone with a share link (incl. guests) can read images of token-shared plans.
CREATE POLICY "Anyone can read meal images for shared plans"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'meal-images'
    AND name IN (
      SELECT mpm.image_path FROM public.meal_plan_meals mpm
      JOIN public.meal_plans mp ON mp.id = mpm.meal_plan_id
      WHERE mpm.image_path IS NOT NULL
        AND mp.share_token IS NOT NULL
        AND mp.is_deleted = false
    )
  );
