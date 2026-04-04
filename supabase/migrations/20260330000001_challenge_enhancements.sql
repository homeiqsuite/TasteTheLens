-- Challenge enhancements: keywords + ratings

-- ─── Keywords on challenges ───────────────────────────────────────────────────

ALTER TABLE challenges ADD COLUMN IF NOT EXISTS keywords TEXT[] DEFAULT '{}';

-- ─── Star ratings on challenge submissions ────────────────────────────────────

-- Per-user rating records
CREATE TABLE IF NOT EXISTS challenge_submission_ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  submission_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(submission_id, user_id)
);

-- Denormalized average + count on submissions for fast display
ALTER TABLE challenge_submissions
  ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;

-- Function to keep denormalized fields in sync
CREATE OR REPLACE FUNCTION update_submission_rating()
RETURNS TRIGGER AS $$
DECLARE
  target_id TEXT;
BEGIN
  target_id := COALESCE(NEW.submission_id, OLD.submission_id);
  UPDATE challenge_submissions
  SET
    average_rating = (
      SELECT COALESCE(ROUND(AVG(stars::numeric), 2), 0)
      FROM challenge_submission_ratings
      WHERE submission_id = target_id
    ),
    rating_count = (
      SELECT COUNT(*)
      FROM challenge_submission_ratings
      WHERE submission_id = target_id
    )
  WHERE id = target_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_submission_rating ON challenge_submission_ratings;
CREATE TRIGGER trg_update_submission_rating
AFTER INSERT OR UPDATE OR DELETE ON challenge_submission_ratings
FOR EACH ROW EXECUTE FUNCTION update_submission_rating();

-- RLS
ALTER TABLE challenge_submission_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read all ratings" ON challenge_submission_ratings;
CREATE POLICY "Users can read all ratings" ON challenge_submission_ratings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can rate submissions" ON challenge_submission_ratings;
CREATE POLICY "Users can rate submissions" ON challenge_submission_ratings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own rating" ON challenge_submission_ratings;
CREATE POLICY "Users can update own rating" ON challenge_submission_ratings
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own rating" ON challenge_submission_ratings;
CREATE POLICY "Users can delete own rating" ON challenge_submission_ratings
  FOR DELETE USING (auth.uid() = user_id);
