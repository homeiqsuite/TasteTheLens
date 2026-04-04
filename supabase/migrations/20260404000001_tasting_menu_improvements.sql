-- Tasting Menu Feature Improvements
-- #6: Invite code expiry column
ALTER TABLE tasting_menus ADD COLUMN IF NOT EXISTS invite_expires_at TIMESTAMPTZ;

-- #14: Event date column
ALTER TABLE tasting_menus ADD COLUMN IF NOT EXISTS event_date TIMESTAMPTZ;

-- #22: Leave menu RPC (participants only, not creator)
CREATE OR REPLACE FUNCTION leave_menu(p_menu_id UUID, p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM tasting_menus WHERE id = p_menu_id AND creator_id = p_user_id) THEN
    RAISE EXCEPTION 'Creator cannot leave menu — use delete instead';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM menu_participants WHERE menu_id = p_menu_id AND user_id = p_user_id) THEN
    RAISE EXCEPTION 'User is not a participant in this menu';
  END IF;
  DELETE FROM menu_participants WHERE menu_id = p_menu_id AND user_id = p_user_id;
END;
$$;

-- #6: Regenerate invite code RPC (creator only)
-- Sets a 7-day expiry and returns the new code
CREATE OR REPLACE FUNCTION regenerate_invite_code(p_menu_id UUID, p_user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_code TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tasting_menus WHERE id = p_menu_id AND creator_id = p_user_id) THEN
    RAISE EXCEPTION 'Only the creator can regenerate the invite code';
  END IF;
  v_new_code := encode(gen_random_bytes(6), 'hex');
  UPDATE tasting_menus
    SET invite_code = v_new_code,
        invite_expires_at = NOW() + INTERVAL '7 days',
        updated_at = NOW()
  WHERE id = p_menu_id;
  RETURN v_new_code;
END;
$$;

-- #23: Update course type RPC (creator only, non-published menu, course must be empty)
CREATE OR REPLACE FUNCTION update_course_type(
  p_menu_id UUID,
  p_course_order INT,
  p_course_type TEXT,
  p_user_id UUID
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM tasting_menus
    WHERE id = p_menu_id AND creator_id = p_user_id AND status != 'published'
  ) THEN
    RAISE EXCEPTION 'Only the creator can edit course types on non-published menus';
  END IF;
  UPDATE menu_courses
    SET course_type = p_course_type
  WHERE menu_id = p_menu_id
    AND course_order = p_course_order
    AND recipe_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Course not found or already has a recipe assigned';
  END IF;
END;
$$;

-- Update join_menu_by_invite_code to check expiry if set
CREATE OR REPLACE FUNCTION join_menu_by_invite_code(p_invite_code TEXT)
RETURNS SETOF tasting_menus LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_menu tasting_menus;
  v_user_id UUID;
BEGIN
  -- Get the calling user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Find the menu by invite code
  SELECT * INTO v_menu
  FROM tasting_menus
  WHERE invite_code = p_invite_code
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- Check if invite has expired
  IF v_menu.invite_expires_at IS NOT NULL AND v_menu.invite_expires_at < NOW() THEN
    RAISE EXCEPTION 'This invite link has expired';
  END IF;

  -- Check if menu is published (cannot join published menus)
  IF v_menu.status = 'published' THEN
    RAISE EXCEPTION 'Cannot join a published menu';
  END IF;

  -- Add participant if not already in the menu
  INSERT INTO menu_participants (menu_id, user_id, role, joined_at)
  VALUES (v_menu.id, v_user_id, 'participant', NOW())
  ON CONFLICT (menu_id, user_id) DO NOTHING;

  RETURN NEXT v_menu;
END;
$$;
