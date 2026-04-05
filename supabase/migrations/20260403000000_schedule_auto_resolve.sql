-- Schedule auto-resolve-challenges to run every hour
-- Requires pg_cron (available on Supabase, not yet enabled) and pg_net (already enabled)

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Grant usage so cron jobs can use pg_net
GRANT USAGE ON SCHEMA cron TO postgres;

-- Schedule hourly job: resolve expired challenges by picking the winner
-- with the best average rating (tie-break: most ratings).
-- Uses the service_role_key from Supabase Vault for auth.
SELECT cron.schedule(
  'auto-resolve-challenges',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://marimaxtqnzmsynsvhrc.supabase.co/functions/v1/auto-resolve-challenges',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    ),
    body := '{}'::jsonb
  );
  $$
);
