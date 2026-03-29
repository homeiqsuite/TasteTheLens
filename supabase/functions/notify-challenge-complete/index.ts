import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface NotifyRequest {
  challenge_id: string;
  winner_submission_id: string;
  challenge_title: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const {
      challenge_id,
      winner_submission_id,
      challenge_title,
    }: NotifyRequest = await req.json();

    // 1. Get winner's user_id
    const { data: winnerSub } = await supabase
      .from("challenge_submissions")
      .select("user_id")
      .eq("id", winner_submission_id)
      .single();

    if (!winnerSub) {
      return Response.json(
        { status: "error", message: "Winner submission not found" },
        { status: 404 }
      );
    }

    const pushUrl = `${SUPABASE_URL}/functions/v1/send-push-notification`;
    const headers = {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    };

    // 2. Notify winner
    await fetch(pushUrl, {
      method: "POST",
      headers,
      body: JSON.stringify({
        recipient_user_id: winnerSub.user_id,
        notification_type: "challenge_winner",
        title: "You won!",
        body: `Your submission won the "${challenge_title}" challenge!`,
        deep_link: `tastethelens://challenge/${challenge_id}`,
      }),
    });

    // 3. Get all unique participants (excluding winner)
    const { data: submissions } = await supabase
      .from("challenge_submissions")
      .select("user_id")
      .eq("challenge_id", challenge_id);

    const allUserIds = (submissions || []).map(
      (s: { user_id: string }) => s.user_id
    );
    const uniqueUserIds = [...new Set(allUserIds)];

    // 4. Notify each participant (except winner)
    let notified = 0;
    for (const userId of uniqueUserIds) {
      if (userId === winnerSub.user_id) continue;
      await fetch(pushUrl, {
        method: "POST",
        headers,
        body: JSON.stringify({
          recipient_user_id: userId,
          notification_type: "challenge_completed",
          title: "Challenge Complete",
          body: `The "${challenge_title}" challenge has ended. See the results!`,
          deep_link: `tastethelens://challenge/${challenge_id}`,
        }),
      });
      notified++;
    }

    return Response.json({
      status: "ok",
      winner_notified: winnerSub.user_id,
      participants_notified: notified,
    });
  } catch (error) {
    console.error("notify-challenge-complete error:", error);
    return Response.json(
      { status: "error", message: String(error) },
      { status: 500 }
    );
  }
});
