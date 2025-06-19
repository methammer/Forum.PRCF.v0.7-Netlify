<![CDATA[
/*
  # Create forum_posts table and RLS policies

  This migration creates the `forum_posts` table to store forum topics/posts.
  It links posts to categories and users, and sets up RLS policies.

  1. New Table: `public.forum_posts`
     - `id` (uuid, primary key): Unique identifier for the post, auto-generated.
     - `category_id` (uuid, foreign key): References `forum_categories.id`. Indicates the category this post belongs to.
     - `user_id` (uuid, foreign key): References `auth.users.id`. Indicates the author of the post.
     - `title` (text, not null): The title of the post/topic.
     - `content` (text, not null): The main content of the post.
     - `created_at` (timestamptz, default `now()`): Timestamp of when the post was created.
     - `updated_at` (timestamptz, default `now()`): Timestamp of when the post was last updated.

  2. Indexes
     - Index on `category_id` for faster querying of posts within a category.
     - Index on `user_id` for faster querying of posts by a user.

  3. Row Level Security (RLS)
     - Enabled RLS for `public.forum_posts`.
     - Policy: "Allow authenticated users to read all posts"
       - Grants `SELECT` access to all authenticated users.
     - Policy: "Allow users to insert their own posts"
       - Grants `INSERT` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow users to update their own posts"
       - Grants `UPDATE` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow users to delete their own posts"
       - Grants `DELETE` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow admins/moderators to manage all posts"
       - Grants `UPDATE`, `DELETE` access to users with 'ADMIN', 'SUPER_ADMIN', or 'MODERATOR' role.

  4. Functions & Triggers
     - `public.handle_updated_at()`: A trigger function to automatically update the `updated_at` timestamp.
     - Trigger `on_forum_posts_update_set_timestamp`: Before UPDATE on `forum_posts`, calls `handle_updated_at`.

  5. Important Notes
     - The `user_id` references `auth.users.id`. User profile information (like username) should be joined from the `profiles` table.
     - The policies ensure users can manage their own content, while admins/moderators have broader permissions.
*/

-- Function to update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the forum_posts table
CREATE TABLE IF NOT EXISTS public.forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES public.forum_categories(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(title) > 0 AND char_length(title) <= 255),
  content text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for foreign keys for performance
CREATE INDEX IF NOT EXISTS idx_forum_posts_category_id ON public.forum_posts(category_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_user_id ON public.forum_posts(user_id);

-- Trigger to automatically update 'updated_at' on update
DROP TRIGGER IF EXISTS on_forum_posts_update_set_timestamp ON public.forum_posts;
CREATE TRIGGER on_forum_posts_update_set_timestamp
  BEFORE UPDATE ON public.forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security for the forum_posts table
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for forum_posts

-- Allow authenticated users to read all posts
DROP POLICY IF EXISTS "Allow authenticated users to read all posts" ON public.forum_posts;
CREATE POLICY "Allow authenticated users to read all posts"
  ON public.forum_posts
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow users to insert their own posts
DROP POLICY IF EXISTS "Allow users to insert their own posts" ON public.forum_posts;
CREATE POLICY "Allow users to insert their own posts"
  ON public.forum_posts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own posts
DROP POLICY IF EXISTS "Allow users to update their own posts" ON public.forum_posts;
CREATE POLICY "Allow users to update their own posts"
  ON public.forum_posts
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own posts
DROP POLICY IF EXISTS "Allow users to delete their own posts" ON public.forum_posts;
CREATE POLICY "Allow users to delete their own posts"
  ON public.forum_posts
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow admins and moderators to update any post
DROP POLICY IF EXISTS "Allow admins and moderators to update any post" ON public.forum_posts;
CREATE POLICY "Allow admins and moderators to update any post"
  ON public.forum_posts
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'))
    )
  );

-- Allow admins and moderators to delete any post
DROP POLICY IF EXISTS "Allow admins and moderators to delete any post" ON public.forum_posts;
CREATE POLICY "Allow admins and moderators to delete any post"
  ON public.forum_posts
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'))
    )
  );
]]>
