import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Authenticate the requesting user via their JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return Response.json({ error: "Missing authorization" }, { status: 401 });
  }

  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return Response.json({ error: "Invalid token" }, { status: 401 });
  }

  const userId = user.id;

  try {
    // Disassociate recipes from the user (keep recipe data for analytics/content)
    const { error: recipesError } = await supabase
      .from("recipes")
      .update({ user_id: null })
      .eq("user_id", userId);
    if (recipesError) console.error("Failed to disassociate recipes:", recipesError);

    const { error: profileError } = await supabase
      .from("users")
      .delete()
      .eq("id", userId);
    if (profileError) console.error("Failed to delete profile:", profileError);

    // Delete the auth user (requires service_role — cannot be done client-side)
    const { error: deleteError } =
      await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error("Failed to delete auth user:", deleteError);
      return Response.json(
        { error: "Failed to delete account" },
        { status: 500 }
      );
    }

    console.log(`Account deleted: ${userId}`);
    return Response.json({ ok: true });
  } catch (error) {
    console.error("delete-account error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
