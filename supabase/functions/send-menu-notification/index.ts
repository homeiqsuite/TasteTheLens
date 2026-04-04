import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

interface SendMenuNotificationRequest {
  menuId: string;
  menuTheme: string;
  addedByUserId: string;
  courseType: string;
}

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
    const { menuId, menuTheme, addedByUserId, courseType }: SendMenuNotificationRequest =
      await req.json();

    if (!menuId || !menuTheme || !addedByUserId || !courseType) {
      return Response.json({ error: "Missing required fields" }, { status: 400 });
    }

    // Get all participants excluding the one who added the course
    const { data: participants, error: participantsError } = await supabase
      .from("menu_participants")
      .select("user_id")
      .eq("menu_id", menuId)
      .neq("user_id", addedByUserId);

    if (participantsError || !participants || participants.length === 0) {
      return Response.json({ notified: 0 });
    }

    const recipientUserIds = participants.map((p) => p.user_id);

    // Fetch FCM tokens for those users (stored in users.fcm_token)
    const { data: usersWithTokens, error: usersError } = await supabase
      .from("users")
      .select("id, fcm_token, notification_preferences")
      .in("id", recipientUserIds)
      .not("fcm_token", "is", null);

    if (usersError || !usersWithTokens || usersWithTokens.length === 0) {
      return Response.json({ notified: 0 });
    }

    // Filter to users who have tasting menu notifications enabled
    const eligibleUsers = usersWithTokens.filter((u) => {
      const prefs = u.notification_preferences as Record<string, boolean> | null;
      // Default to enabled if preference not explicitly set to false
      return prefs?.tastingMenuUpdates !== false;
    });

    if (eligibleUsers.length === 0) {
      return Response.json({ notified: 0 });
    }

    if (!FCM_SERVER_KEY) {
      console.warn("FCM_SERVER_KEY not configured — skipping push delivery");
      return Response.json({ notified: 0, warning: "FCM not configured" });
    }

    // Send FCM notifications
    let notified = 0;
    for (const u of eligibleUsers) {
      try {
        const fcmPayload = {
          to: u.fcm_token,
          notification: {
            title: menuTheme,
            body: `A new ${courseType} has been added to the menu`,
          },
          data: {
            type: "menu_course_added",
            menuId,
          },
        };

        const fcmResponse = await fetch(
          "https://fcm.googleapis.com/fcm/send",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `key=${FCM_SERVER_KEY}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        if (fcmResponse.ok) {
          notified++;
        } else {
          console.warn(`FCM send failed for user ${u.id}: ${fcmResponse.status}`);
        }
      } catch (err) {
        console.warn(`Failed to send notification to user ${u.id}:`, err);
      }
    }

    console.log(`Sent menu notifications for menu ${menuId}: ${notified} delivered`);
    return Response.json({ notified });
  } catch (error) {
    console.error("send-menu-notification error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
