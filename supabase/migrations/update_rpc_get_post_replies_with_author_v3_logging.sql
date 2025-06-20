<![CDATA[
/*
  # Update RPC function get_post_replies_with_author (v3 - with logging)

  This migration updates the PostgreSQL function `get_post_replies_with_author`
  to include `RAISE NOTICE` statements for debugging purposes, specifically to
  track how soft-deleted replies are handled and what data is being returned.

  1. Function: `public.get_post_replies_with_author(p_post_id uuid)`
     - **Dropped and Recreated**: The function is dropped first.
     - Added `RAISE NOTICE` to log:
       - Function call with post ID.
       - Caller ID and moderator status.
       - Number of replies fetched before visibility filtering.
       - Number of replies after visibility filtering.
     - The core logic for fetching replies and handling visibility for soft-deleted
       content (moderators see all, non-moderators see non-deleted) remains the same.

  2. Important Notes
     - This logging will help diagnose issues with reply soft deletion visibility.
*/

-- Drop the function first to allow changing the definition
DROP FUNCTION IF EXISTS public.get_post_replies_with_author(uuid);

CREATE OR REPLACE FUNCTION public.get_post_replies_with_author(p_post_id uuid)
RETURNS TABLE (
  reply_id uuid,
  reply_content text,
  reply_created_at timestamptz,
  reply_updated_at timestamptz,
  reply_user_id uuid,
  author_username text,
  author_avatar_url text,
  parent_reply_id uuid,
  is_deleted boolean,
  deleted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_is_moderator BOOLEAN;
  v_replies_count_before_filter INT;
  v_replies_count_after_filter INT;
BEGIN
  RAISE NOTICE '[get_post_replies_with_author] Called for post_id: %', p_post_id;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_caller_id AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
  ) INTO v_caller_is_moderator;

  RAISE NOTICE '[get_post_replies_with_author] Caller ID: %, Is Moderator: %', v_caller_id, v_caller_is_moderator;

  -- Log count before filtering (for debugging)
  SELECT COUNT(*)
  INTO v_replies_count_before_filter
  FROM public.forum_replies fr
  WHERE fr.post_id = p_post_id;
  RAISE NOTICE '[get_post_replies_with_author] Total replies for post before visibility filter: %', v_replies_count_before_filter;

  RETURN QUERY
  SELECT
    fr.id AS reply_id,
    fr.content AS reply_content,
    fr.created_at AS reply_created_at,
    fr.updated_at AS reply_updated_at,
    fr.user_id AS reply_user_id,
    p.username AS author_username,
    p.avatar_url AS author_avatar_url,
    fr.parent_reply_id,
    fr.is_deleted,
    fr.deleted_at
  FROM
    public.forum_replies fr
  JOIN
    public.profiles p ON fr.user_id = p.id
  WHERE
    fr.post_id = p_post_id
    AND (
      v_caller_is_moderator -- Moderators can see everything (including deleted)
      OR fr.is_deleted = false -- Non-moderators only see non-deleted replies
    );

  -- Log count after filtering (for debugging)
  GET DIAGNOSTICS v_replies_count_after_filter = ROW_COUNT;
  RAISE NOTICE '[get_post_replies_with_author] Replies returned after visibility filter: %', v_replies_count_after_filter;

END;
$$;

COMMENT ON FUNCTION public.get_post_replies_with_author(uuid) IS 'Fetches replies for a post, including author details and soft deletion status. Visibility for soft-deleted replies is handled internally. Includes debug logging (v3). SECURITY DEFINER.';
]]>
