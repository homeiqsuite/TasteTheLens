import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface CreateTastingMenuRequest {
  theme: string;
  courseCount: number;
  courseTypes: string[];
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Prefer x-user-token (bypasses gateway JWT validation for expired tokens).
  // Fall back to Authorization for SDK-based callers.
  const userToken = req.headers.get("x-user-token")
    || req.headers.get("Authorization")?.replace("Bearer ", "") || null;
  if (!userToken) {
    return Response.json({ error: "Missing authorization" }, { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(userToken);

  if (authError || !user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const { theme, courseCount, courseTypes }: CreateTastingMenuRequest =
      await req.json();

    // Validate inputs
    if (!theme || typeof theme !== "string") {
      return Response.json({ error: "theme is required" }, { status: 400 });
    }

    if (!courseCount || courseCount < 2 || courseCount > 6) {
      return Response.json(
        { error: "courseCount must be between 2 and 6" },
        { status: 400 }
      );
    }

    if (
      !courseTypes ||
      !Array.isArray(courseTypes) ||
      courseTypes.length !== courseCount
    ) {
      return Response.json(
        { error: "courseTypes length must match courseCount" },
        { status: 400 }
      );
    }

    // Call the atomic Postgres function
    const { data, error } = await supabase.rpc("create_tasting_menu_atomic", {
      p_creator_id: user.id,
      p_theme: theme,
      p_course_count: courseCount,
      p_course_types: courseTypes,
    });

    if (error) {
      console.error("create_tasting_menu_atomic error:", error);
      return Response.json(
        { error: "Failed to create tasting menu" },
        { status: 500 }
      );
    }

    return Response.json(data);
  } catch (error) {
    console.error("create-tasting-menu error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
