-- ─── Secure purchase credit granting ──────────────────────────────────────────
--
-- Problem: add_purchased_credits was callable by any authenticated user with an
-- arbitrary credit_count, allowing free credit generation via the Supabase REST API.
--
-- Fix:
--   1. Create processed_transactions table for idempotency (replay attack prevention).
--   2. Restrict add_purchased_credits to service role only (REVOKE from clients).
--      Credit count is now determined server-side in the grant-purchase-credits
--      edge function, not supplied by the client.

-- ─── 1. Processed transactions (idempotency) ──────────────────────────────────

CREATE TABLE IF NOT EXISTS public.processed_transactions (
    transaction_id TEXT        PRIMARY KEY,
    user_id        UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    product_id     TEXT        NOT NULL,
    credit_count   INTEGER     NOT NULL,
    environment    TEXT        NOT NULL DEFAULT 'Production',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.processed_transactions ENABLE ROW LEVEL SECURITY;

-- No client access — only the service role (edge functions) can read/write this table.
REVOKE ALL ON TABLE public.processed_transactions FROM PUBLIC, anon, authenticated;

-- ─── 2. Restrict add_purchased_credits to service role ────────────────────────
--
-- Remove the auth.uid() check (service role has no auth.uid()) and rely solely
-- on REVOKE to prevent client access. The grant-purchase-credits edge function
-- calls this via the service role key after validating the StoreKit transaction.

CREATE OR REPLACE FUNCTION public.add_purchased_credits(
    user_id_param TEXT,
    credit_count  INTEGER
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
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

-- Revoke client access — service role bypasses these grants.
REVOKE ALL ON FUNCTION public.add_purchased_credits(text, integer) FROM PUBLIC, anon, authenticated;
