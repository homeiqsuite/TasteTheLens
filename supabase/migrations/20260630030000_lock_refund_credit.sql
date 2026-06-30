-- ============================================================================
-- Lock refund_credit to the backend (service_role) only
-- ============================================================================
-- refund_credit(p_user_id, p_pool) adds a credit to a user's balance with NO
-- validation. It was executable by the `authenticated` role because the iOS
-- client called it directly to refund the recipe credit when image generation
-- failed or the user cancelled. That made it a credit-farming vector: any
-- logged-in user could call it repeatedly to mint unlimited credits.
--
-- The client-side refund has been removed (ImageAnalysisPipeline). The recipe is
-- the paid deliverable; the edge functions still refund their OWN server-side
-- failures via service_role (so a user is never charged when the analysis itself
-- fails). Refunds are now exclusively server-authoritative.
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.refund_credit(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_credit(uuid, text) TO service_role;
