import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface DeclareWinnerRequest {
  challengeId: string;
  winnerSubmissionId: string;
  challengeTitle: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return Response.json({ error: "Missing authorization" }, { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const { challengeId, winnerSubmissionId, challengeTitle }: DeclareWinnerRequest =
      await req.json();

    if (!challengeId || !winnerSubmissionId || !challengeTitle) {
      return Response.json(
        { error: "challengeId, winnerSubmissionId, and challengeTitle are required" },
        { status: 400 }
      );
    }

    // Verify the requesting user is the challenge creator
    const { data: challenge, error: fetchError } = await supabase
      .from("challenges")
      .select("creator_id, status")
      .eq("id", challengeId)
      .single();

    if (fetchError || !challenge) {
      return Response.json({ error: "Challenge not found" }, { status: 404 });
    }

    if (challenge.creator_id !== user.id) {
      return Response.json(
        { error: "Only the challenge creator can declare a winner" },
        { status: 403 }
      );
    }

    if (challenge.status === "completed") {
      return Response.json(
        { error: "Challenge is already completed" },
        { status: 400 }
      );
    }

    // Atomically update challenge status and winner
    const { error: updateError } = await supabase
      .from("challenges")
      .update({
        winner_submission_id: winnerSubmissionId,
        status: "completed",
      })
      .eq("id", challengeId)
      .eq("creator_id", user.id);

    if (updateError) {
      console.error("Failed to update challenge:", updateError);
      return Response.json(
        { error: "Failed to declare winner" },
        { status: 500 }
      );
    }

    // Call notify-challenge-complete edge function to handle all notifications
    try {
      await fetch(`${SUPABASE_URL}/functions/v1/notify-challenge-complete`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          challenge_id: challengeId,
          winner_submission_id: winnerSubmissionId,
          challenge_title: challengeTitle,
        }),
      });
    } catch (notifyError) {
      // Notifications are best-effort — don't fail the whole operation
      console.error("Failed to send notifications:", notifyError);
    }

    return Response.json({
      success: true,
      challengeId,
      winnerSubmissionId,
    });
  } catch (error) {
    console.error("challenge-declare-winner error:", error);
    return Response.json({ error: String(error) }, { status: 500 });
  }
});
