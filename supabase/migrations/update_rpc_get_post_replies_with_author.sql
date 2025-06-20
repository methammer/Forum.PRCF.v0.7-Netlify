<![CDATA[
/*
  # Update RPC function get_post_replies_with_author

  This migration updates the PostgreSQL function `get_post_replies_with_author`
  to correctly handle visibility of soft-deleted replies.

  1. Function: `public.get_post_replies_with_author(p_post_id uuid)`
     - **Dropped and Recreated**: The function is dropped first to allow changing its return type.
     - Modified `RETURNS TABLE` to include:
       - `is_deleted` (boolean)
       - `deleted_at` (timestamptz)
     - Modified the main `SELECT` query to include these fields from the `forum_replies` table.
     - Since this function is `SECURITY DEFINER`, it bypasses caller's RLS on `forum_replies`.
       Therefore, filtering logic mirroring the RLS policy for `forum_replies` (SELECT)
       has been added directly into the function's `WHERE` clause. This ensures that
       the function only returns replies that the calling user is permitted to see,
       respecting the `is_deleted` status and user roles.

  2. Important Notes
     - This change is critical for `SECURITY DEFINER` functions to prevent data leakage
       of soft-deleted content to users who should not see it.
     - The internal filtering logic ensures non-moderators only see non-deleted replies,
       while moderators can see all replies (including deleted ones).
*/

-- Drop the function first to allow changing the return type
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
  v_caller_is_moderator BOOLEAN := EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_caller_id AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
  );
BEGIN
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
    )
  ORDER BY
    fr.created_at ASC;
END;
$$;

COMMENT ON FUNCTION public.get_post_replies_with_author(uuid) IS 'Fetches replies for a post, including author details and soft deletion status. Visibility for soft-deleted replies is handled internally due to SECURITY DEFINER, ensuring non-moderators only see non-deleted replies, while moderators see all.';
]]>
