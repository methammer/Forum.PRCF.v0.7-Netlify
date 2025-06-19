<![CDATA[
/*
  # Create RPC function get_post_replies_with_author

  This migration creates a PostgreSQL function `get_post_replies_with_author`
  to fetch replies for a specific forum post, along with author details.

  1. Function: `public.get_post_replies_with_author(p_post_id uuid)`
     - Accepts `p_post_id` (uuid) as the ID of the forum post.
     - Returns a table with the following columns:
       - `reply_id` (uuid): ID of the reply.
       - `reply_content` (text): Content of the reply.
       - `reply_created_at` (timestamptz): Creation timestamp of the reply.
       - `reply_updated_at` (timestamptz): Last update timestamp of the reply.
       - `reply_user_id` (uuid): ID of the user who authored the reply.
       - `author_username` (text): Username of the reply author.
       - `author_avatar_url` (text): Avatar URL of the reply author.
       - `parent_reply_id` (uuid): ID of the parent reply (for threaded comments, nullable).
     - Joins `forum_replies` with `profiles` to get author information.
     - Orders replies by `created_at` in ascending order (oldest first).
     - The function is `SECURITY DEFINER` to ensure it can access `profiles` data consistently,
       though RLS policies on `forum_replies` and `profiles` should allow access for authenticated users.

  2. Important Notes
     - This function assumes that `forum_replies` and `profiles` tables exist.
     - It's designed to be called by authenticated users.
*/

CREATE OR REPLACE FUNCTION public.get_post_replies_with_author(p_post_id uuid)
RETURNS TABLE (
  reply_id uuid,
  reply_content text,
  reply_created_at timestamptz,
  reply_updated_at timestamptz,
  reply_user_id uuid,
  author_username text,
  author_avatar_url text,
  parent_reply_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER -- Uses the permissions of the function owner
SET search_path = public -- Ensures 'public' schema is in search path
AS $$
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
    fr.parent_reply_id
  FROM
    public.forum_replies fr
  JOIN
    public.profiles p ON fr.user_id = p.id
  WHERE
    fr.post_id = p_post_id
  ORDER BY
    fr.created_at ASC; -- Show oldest replies first
END;
$$;
]]>