<![CDATA[
/*
  # Create RPC function get_post_details_with_author

  This migration creates a PostgreSQL function `get_post_details_with_author`
  to fetch a single forum post along with its author's username.

  1. New Function: `public.get_post_details_with_author(p_post_id uuid)`
     - Takes `p_post_id` (uuid) as input.
     - Returns a single row containing:
       - `post_id` (uuid): The ID of the post.
       - `post_title` (text): The title of the post.
       - `post_content` (text): The content of the post.
       - `post_created_at` (timestamptz): Creation timestamp of the post.
       - `post_updated_at` (timestamptz): Last update timestamp of the post.
       - `post_user_id` (uuid): The ID of the user who created the post.
       - `author_username` (text): The username of the post's author.
       - `author_avatar_url` (text): The avatar URL of the post's author.
       - `category_id` (uuid): The ID of the category the post belongs to.
       - `category_name` (text): The name of the category.
       - `category_slug` (text): The slug of the category.

  2. Security
     - The function is defined with `SECURITY DEFINER` to execute with the permissions of the user who defined it (typically an admin role), allowing it to bypass RLS for joining tables if necessary, while still respecting RLS on the initial query if `SECURITY INVOKER` was used. For simplicity and to ensure data is fetched correctly across `forum_posts` and `profiles`, `SECURITY DEFINER` is often used for read operations that join across tables with different RLS. However, it's crucial that the function itself doesn't allow any unauthorized data modification.
     - Grants `EXECUTE` permission to `authenticated` users.

  3. Important Notes
     - This function is designed to be called from the client-side to fetch all necessary details for displaying a single post.
     - It joins `forum_posts` with `profiles` (to get username and avatar) and `forum_categories` (to get category info).
*/

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
  category_slug text
)
LANGUAGE plpgsql
SECURITY DEFINER -- Or SECURITY INVOKER if RLS on profiles and categories should strictly apply
AS $$
BEGIN
  RETURN QUERY
  SELECT
    fp.id AS post_id,
    fp.title AS post_title,
    fp.content AS post_content,
    fp.created_at AS post_created_at,
    fp.updated_at AS post_updated_at,
    fp.user_id AS post_user_id,
    p.username AS author_username,
    p.avatar_url AS author_avatar_url,
    fc.id AS category_id,
    fc.name AS category_name,
    fc.slug AS category_slug
  FROM
    public.forum_posts fp
  JOIN
    public.profiles p ON fp.user_id = p.id
  JOIN
    public.forum_categories fc ON fp.category_id = fc.id
  WHERE
    fp.id = p_post_id;
END;
$$;

-- Grant execution rights to authenticated users
GRANT EXECUTE ON FUNCTION public.get_post_details_with_author(uuid) TO authenticated;
]]>