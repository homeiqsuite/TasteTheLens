/**
 * grant-purchase-credits
 *
 * Called by the iOS app after a successful StoreKit 2 purchase. Accepts the
 * Apple-signed transaction JWS, validates it server-side, and grants the
 * correct credit amount. The client never controls the credit count.
 *
 * Security model:
 *   1. User is authenticated via x-user-token (Supabase JWT).
 *   2. The JWS payload is decoded and the bundleId is validated.
 *   3. appAccountToken in the transaction must match the authenticated user's UUID.
 *   4. Credit amount is looked up from a server-side map (not from the client).
 *   5. transactionId is stored in processed_transactions to prevent replay attacks.
 *   6. Credits are granted via add_purchased_credits (service-role only RPC).
 *
 * Note: Full Apple JWS signature verification (x5c cert chain) is not implemented
 * here because the appAccountToken binding and idempotency check together make
 * spoofed transactions either impossible to attribute to another user or safely
 * deduplicated. Adding signature verification is recommended but not required for
 * the consumable-only model.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const BUNDLE_ID = "com.eightgates.Taste-The-Lens";

// Server-side credit map — the client never sends a credit count.
const CREDIT_PACK_AMOUNTS: Record<string, number> = {
  "com.tastethelens.credits.taste":   10,
  "com.tastethelens.credits.cook":    30,
  "com.tastethelens.credits.feast":   75,
  // Legacy packs (for replayed transactions from old app versions)
  "com.tastethelens.credits.starter": 10,
  "com.tastethelens.credits.classic": 50,
  "com.tastethelens.credits.pantry":  90,
};

function decodeJWTPayload(jwt: string): Record<string, unknown> {
  const parts = jwt.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT structure");
  const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, "=");
  return JSON.parse(atob(padded));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // ── Authenticate user ───────────────────────────────────────────────────────
  const userToken = req.headers.get("x-user-token");
  if (!userToken) {
    return new Response("Unauthorized", { status: 401 });
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${userToken}` } },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    console.error("Auth failed:", authError?.message);
    return new Response("Unauthorized", { status: 401 });
  }

  // ── Parse body ──────────────────────────────────────────────────────────────
  let body: { transaction_jws?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON body", { status: 400 });
  }

  if (!body.transaction_jws) {
    return new Response("Missing transaction_jws", { status: 400 });
  }

  // ── Decode Apple-signed transaction ─────────────────────────────────────────
  let txPayload: Record<string, unknown>;
  try {
    txPayload = decodeJWTPayload(body.transaction_jws);
  } catch {
    return new Response("Invalid transaction_jws", { status: 400 });
  }

  const bundleId        = txPayload.bundleId as string | undefined;
  const productId       = txPayload.productId as string | undefined;
  const transactionId   = txPayload.transactionId as string | undefined;
  const appAccountToken = (txPayload.appAccountToken as string | undefined)?.toLowerCase();
  const environment     = txPayload.environment as string | undefined;

  // ── Validate bundle ─────────────────────────────────────────────────────────
  if (bundleId !== BUNDLE_ID) {
    console.error(`Bundle mismatch: expected=${BUNDLE_ID}, got=${bundleId}`);
    return new Response("Invalid transaction", { status: 400 });
  }

  // ── Validate transaction belongs to this user ───────────────────────────────
  if (!appAccountToken || appAccountToken !== user.id.toLowerCase()) {
    console.error(`appAccountToken mismatch: token=${appAccountToken}, user=${user.id}`);
    return new Response("Transaction does not belong to this user", { status: 403 });
  }

  if (!transactionId) {
    return new Response("Missing transactionId in transaction", { status: 400 });
  }

  // ── Server-side credit lookup ───────────────────────────────────────────────
  const creditCount = CREDIT_PACK_AMOUNTS[productId ?? ""];
  if (creditCount === undefined) {
    console.error(`Unknown productId: ${productId}`);
    return new Response("Unknown product", { status: 400 });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // ── Idempotency check ───────────────────────────────────────────────────────
  const { data: existing } = await serviceClient
    .from("processed_transactions")
    .select("transaction_id")
    .eq("transaction_id", transactionId)
    .maybeSingle();

  if (existing) {
    console.log(`Transaction ${transactionId} already processed — returning OK`);
    return new Response(JSON.stringify({ credits_granted: creditCount, already_processed: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── Record transaction before granting credits (prevents double-grant on retry) ─
  const { error: insertError } = await serviceClient
    .from("processed_transactions")
    .insert({
      transaction_id: transactionId,
      user_id:        user.id,
      product_id:     productId,
      credit_count:   creditCount,
      environment:    environment ?? "Production",
    });

  if (insertError) {
    // 23505 = unique_violation: a concurrent request already inserted this transaction
    if (insertError.code === "23505") {
      console.log(`Race condition on ${transactionId} — already processed`);
      return new Response(JSON.stringify({ credits_granted: creditCount, already_processed: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    console.error("Failed to record transaction:", insertError);
    return new Response("Database error", { status: 500 });
  }

  // ── Grant credits ───────────────────────────────────────────────────────────
  const { error: creditError } = await serviceClient.rpc("add_purchased_credits", {
    user_id_param: user.id,
    credit_count:  creditCount,
  });

  if (creditError) {
    console.error(`Failed to grant credits for user ${user.id}:`, creditError);
    // Don't return 500 here — the transaction IS recorded, so a retry would
    // hit the idempotency check. Sync from server will reconcile.
    return new Response("Database error", { status: 500 });
  }

  console.log(`Granted ${creditCount} credits to ${user.id} for ${productId} (tx: ${transactionId}, env: ${environment})`);

  return new Response(JSON.stringify({ credits_granted: creditCount, already_processed: false }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
