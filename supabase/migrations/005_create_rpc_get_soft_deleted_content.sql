    /*
      # RPC: Get Soft-Deleted Content

      This migration creates a new RPC function `get_soft_deleted_content`
      that retrieves all posts and replies currently marked as soft-deleted.

      1. New Function
        - `get_soft_deleted_content()`:
          - Returns a table with details for soft-deleted posts and replies.
          - Includes `content_id`, `content_type` ('post' or 'reply'), `content_title` (for posts),
            `content_excerpt`, `content_author_username`, `deleted_at`, `deleter_username`,
            `deletion_reason`, and `original_post_id` (for replies, to construct links).
          - Uses `UNION ALL` to combine results from `forum_posts` and `forum_replies`.
          - Orders results by `deleted_at` descending.

      2. Security
        - The function is `SECURITY INVOKER`. Access is controlled by RLS policies on the
          `forum_posts` and `forum_replies` tables, which should allow moderators/admins
          to view deleted content.
    */

    CREATE OR REPLACE FUNCTION public.get_soft_deleted_content()
    RETURNS TABLE (
      content_id UUID,
      content_type TEXT,
      content_title TEXT,
      content_excerpt TEXT,
      content_author_username TEXT,
      deleted_at TIMESTAMPTZ,
      deleter_username TEXT,
      deletion_reason TEXT,
      original_post_id UUID -- For replies, this is the parent forum_posts.id
    )
    LANGUAGE plpgsql
    SECURITY INVOKER
    AS $$
    BEGIN
      RETURN QUERY
      SELECT
        fp.id AS content_id,
        'post' AS content_type,
        fp.title AS content_title,
        LEFT(fp.content, 100) AS content_excerpt,
        author_profile.username AS content_author_username,
        fp.deleted_at,
        deleter_profile.username AS deleter_username,
        fp.deleted_reason,
        NULL::UUID AS original_post_id
      FROM public.forum_posts fp
      JOIN public.profiles author_profile ON fp.user_id = author_profile.id
      LEFT JOIN public.profiles deleter_profile ON fp.deleted_by_user_id = deleter_profile.id
      WHERE fp.is_deleted = TRUE

      UNION ALL

      SELECT
        fr.id AS content_id,
        'reply' AS content_type,
        NULL::TEXT AS content_title, -- Replies don't have their own title
        LEFT(fr.content, 100) AS content_excerpt,
        author_profile.username AS content_author_username,
        fr.deleted_at,
        deleter_profile.username AS deleter_username,
        fr.deleted_reason,
        fr.post_id AS original_post_id
      FROM public.forum_replies fr
      JOIN public.profiles author_profile ON fr.user_id = author_profile.id
      LEFT JOIN public.profiles deleter_profile ON fr.deleted_by_user_id = deleter_profile.id
      WHERE fr.is_deleted = TRUE

      ORDER BY deleted_at DESC;
    END;
    $$;

    COMMENT ON FUNCTION public.get_soft_deleted_content() IS 'Retrieves all soft-deleted posts and replies with relevant details. SECURITY INVOKER.';
