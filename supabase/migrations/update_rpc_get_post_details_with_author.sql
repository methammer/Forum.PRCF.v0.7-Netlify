<![CDATA[
/*
  # Update RPC function get_post_details_with_author to SECURITY DEFINER (v4) with logging

  This migration updates the PostgreSQL function `get_post_details_with_author`
  to add `RAISE NOTICE` statements for debugging purposes.
  It helps verify the values of `v_caller_id` and `v_caller_is_moderator`
  during function execution.

  1. Function: `public.get_post_details_with_author(p_post_id uuid)`
     - Added `RAISE NOTICE` for `v_caller_id`.
     - Added `RAISE NOTICE` for `v_caller_is_moderator` after it's determined.

  2. Important Notes
     - These logs will appear in your Supabase Dashboard -> Database -> Logs.
     - This is for debugging and should ideally be removed or conditionalized in production.
*/

-- Drop the function first to allow changing its definition
DROP FUNCTION IF EXISTS public.get_post_details_with_author(uuid);

CREATE OR REPLACE FUNCTION public.get_post_details_with_author(p_post_id uuid)
RETURNS TABLE (
  post_id uuid,
  post_title text,
  post_content text,
  post_created_at timestamptz,
  post_updated_at timestamptz,
  post_user_id uuid,
  author_username text,
  author_avatar_url text,
  category_id uuid,
  category_name text,
  category_slug text,
  is_published boolean,
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
BEGIN
  RAISE NOTICE '[get_post_details_with_author] Called for post_id: %, by caller_id: %', p_post_id, v_caller_id;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles prof
    WHERE prof.id = v_caller_id AND prof.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
  ) INTO v_caller_is_moderator;

  RAISE NOTICE '[get_post_details_with_author] Caller ID: %, Is Moderator: %', v_caller_id, v_caller_is_moderator;

  RETURN QUERY
  SELECT
    fp.id AS post_id,
    fp.title AS post_title,
    fp.content AS post_content,
    fp.created_at AS post_created_at,
    fp.updated_at AS post_updated_at,
    fp.user_id AS post_user_id,
    author_profile.username AS author_username,
    author_profile.avatar_url AS author_avatar_url,
    cat.id AS category_id,
    cat.name AS category_name,
    cat.slug AS category_slug,
    fp.is_published,
    fp.is_deleted, -- This is the crucial field
    fp.deleted_at
  FROM
    public.forum_posts fp
  JOIN
    public.profiles author_profile ON fp.user_id = author_profile.id
  JOIN
    public.forum_categories cat ON fp.category_id = cat.id
  WHERE
    fp.id = p_post_id
    AND (
      v_caller_is_moderator
      OR (
        fp.is_deleted = false AND
        (fp.is_published = true OR fp.user_id = v_caller_id)
      )
    );
END;
$$;

COMMENT ON FUNCTION public.get_post_details_with_author(uuid) IS 'Fetches details for a specific post. SECURITY DEFINER. Visibility logic handled internally. Includes debug logging (v4).';
]]>