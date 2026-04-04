import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const userToken =
    req.headers.get("x-user-token") ||
    req.headers.get("Authorization")?.replace("Bearer ", "") ||
    null;
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
    const { menuId }: { menuId: string } = await req.json();

    if (!menuId) {
      return Response.json({ error: "menuId is required" }, { status: 400 });
    }

    // Verify the caller is the creator
    const { data: menu, error: menuError } = await supabase
      .from("tasting_menus")
      .select("id, creator_id, status, course_count")
      .eq("id", menuId)
      .single();

    if (menuError || !menu) {
      return Response.json({ error: "Menu not found" }, { status: 404 });
    }

    if (menu.creator_id !== user.id) {
      return Response.json(
        { error: "Only the creator can publish a menu" },
        { status: 403 }
      );
    }

    if (menu.status === "published") {
      return Response.json({ error: "Menu is already published" }, { status: 400 });
    }

    // Verify ALL courses have recipes assigned
    const { data: courses, error: coursesError } = await supabase
      .from("menu_courses")
      .select("id, recipe_id, course_order")
      .eq("menu_id", menuId);

    if (coursesError) {
      console.error("Failed to fetch courses:", coursesError);
      return Response.json(
        { error: "Failed to verify courses" },
        { status: 500 }
      );
    }

    if (!courses || courses.length === 0) {
      return Response.json(
        { error: "Menu has no courses" },
        { status: 400 }
      );
    }

    const emptyCourses = courses.filter((c) => !c.recipe_id);
    if (emptyCourses.length > 0) {
      return Response.json(
        {
          error: `${emptyCourses.length} course(s) still need recipes before publishing`,
          emptyCourseOrders: emptyCourses.map((c) => c.course_order),
        },
        { status: 400 }
      );
    }

    // All courses filled — publish
    const { error: updateError } = await supabase
      .from("tasting_menus")
      .update({ status: "published", updated_at: new Date().toISOString() })
      .eq("id", menuId);

    if (updateError) {
      console.error("Failed to publish menu:", updateError);
      return Response.json(
        { error: "Failed to publish menu" },
        { status: 500 }
      );
    }

    console.log(`Published tasting menu ${menuId} by user ${user.id}`);
    return Response.json({ success: true });
  } catch (error) {
    console.error("publish-tasting-menu error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
