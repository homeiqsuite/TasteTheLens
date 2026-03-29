import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    // Find expired challenges with 24h grace period, no winner declared
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { data: expiredChallenges, error } = await supabase
      .from("challenges")
      .select("id, title")
      .eq("status", "active")
      .lt("ends_at", cutoff)
      .is("winner_submission_id", null);

    if (error) throw error;
    if (!expiredChallenges || expiredChallenges.length === 0) {
      return Response.json({ status: "ok", resolved: 0 });
    }

    const notifyUrl = `${SUPABASE_URL}/functions/v1/notify-challenge-complete`;
    const headers = {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    };

    let resolved = 0;

    for (const challenge of expiredChallenges) {
      // Get submission with highest upvote count (tie-break: earliest created_at)
      const { data: topSubmission } = await supabase
        .from("challenge_submissions")
        .select("id, user_id")
        .eq("challenge_id", challenge.id)
        .order("upvote_count", { ascending: false })
        .order("created_at", { ascending: true })
        .limit(1)
        .single();

      if (!topSubmission) {
        // No submissions — mark completed with no winner
        await supabase
          .from("challenges")
          .update({ status: "completed" })
          .eq("id", challenge.id);
        resolved++;
        continue;
      }

      // Update challenge with winner
      await supabase
        .from("challenges")
        .update({
          winner_submission_id: topSubmission.id,
          status: "completed",
        })
        .eq("id", challenge.id);

      // Notify via the notify-challenge-complete function
      await fetch(notifyUrl, {
        method: "POST",
        headers,
        body: JSON.stringify({
          challenge_id: challenge.id,
          winner_submission_id: topSubmission.id,
          challenge_title: challenge.title,
        }),
      });

      resolved++;
    }

    return Response.json({ status: "ok", resolved });
  } catch (error) {
    console.error("auto-resolve error:", error);
    return Response.json(
      { status: "error", message: String(error) },
      { status: 500 }
    );
  }
});
