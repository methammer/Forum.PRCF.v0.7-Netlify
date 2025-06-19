<![CDATA[
/*
  # Create RPC function get_category_posts_with_author

  This migration creates a PostgreSQL function that retrieves forum posts
  for a given category slug, along with the author's username.

  1. New Function: `public.get_category_posts_with_author(p_category_slug TEXT)`
     - Takes `p_category_slug` (text) as input.
     - Returns a table with columns:
       - `post_id` (uuid): The ID of the post.
       - `post_title` (text): The title of the post.
       - `post_created_at` (timestamptz): Creation timestamp of the post.
       - `post_user_id` (uuid): The user ID of the post's author.
       - `author_username` (text): The username of the post's author.
     - The function performs a JOIN between `forum_posts`, `forum_categories`,
       and `profiles` to gather the required data.
     - It orders posts by creation date in descending order.

  2. Security
     - The function uses the default `SECURITY INVOKER` context, meaning
       it runs with the permissions of the calling user. RLS policies
       on the underlying tables (`forum_posts`, `profiles`) will be respected.

  3. Important Notes
     - This function is designed to be called via Supabase RPC from the client-side
       to efficiently fetch posts and their author details for a category page.
     - The join `LEFT JOIN public.profiles p ON fp.user_id = p.id` works because
       both `fp.user_id` (from `forum_posts`) and `p.id` (from `profiles`)
       are UUIDs that correspond to `auth.users.id`.
*/

CREATE OR REPLACE FUNCTION public.get_category_posts_with_author(p_category_slug TEXT)
RETURNS TABLE (
  post_id uuid,
  post_title TEXT,
  post_created_at TIMESTAMPTZ,
  post_user_id uuid,
  author_username TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    fp.id AS post_id,
    fp.title AS post_title,
    fp.created_at AS post_created_at,
    fp.user_id AS post_user_id,
    p.username AS author_username
  FROM
    public.forum_posts fp
  JOIN
    public.forum_categories fc ON fp.category_id = fc.id
  LEFT JOIN
    public.profiles p ON fp.user_id = p.id -- p.id is the profile's primary key, which is also the auth.users.id
  WHERE
    fc.slug = p_category_slug
  ORDER BY
    fp.created_at DESC;
END;
$$;
]]>