<![CDATA[
/*
  # Create forum_replies table and RLS policies

  This migration creates the `forum_replies` table to store replies to forum posts.
  It links replies to posts and users, and sets up RLS policies.

  1. New Table: `public.forum_replies`
     - `id` (uuid, primary key): Unique identifier for the reply, auto-generated.
     - `post_id` (uuid, foreign key): References `forum_posts.id`. Indicates the post this reply belongs to.
     - `user_id` (uuid, foreign key): References `auth.users.id`. Indicates the author of the reply.
     - `parent_reply_id` (uuid, foreign key, nullable): References `forum_replies.id`. For threaded replies (optional).
     - `content` (text, not null): The main content of the reply.
     - `created_at` (timestamptz, default `now()`): Timestamp of when the reply was created.
     - `updated_at` (timestamptz, default `now()`): Timestamp of when the reply was last updated.

  2. Indexes
     - Index on `post_id` for faster querying of replies for a post.
     - Index on `user_id` for faster querying of replies by a user.
     - Index on `parent_reply_id` if threaded replies are heavily used.

  3. Row Level Security (RLS)
     - Enabled RLS for `public.forum_replies`.
     - Policy: "Allow authenticated users to read all replies"
       - Grants `SELECT` access to all authenticated users.
     - Policy: "Allow users to insert their own replies"
       - Grants `INSERT` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow users to update their own replies"
       - Grants `UPDATE` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow users to delete their own replies"
       - Grants `DELETE` access if `user_id` matches `auth.uid()`.
     - Policy: "Allow admins/moderators to manage all replies"
       - Grants `UPDATE`, `DELETE` access to users with 'ADMIN', 'SUPER_ADMIN', or 'MODERATOR' role.

  4. Functions & Triggers
     - Uses the existing `public.handle_updated_at()` trigger function to automatically update the `updated_at` timestamp.
     - Trigger `on_forum_replies_update_set_timestamp`: Before UPDATE on `forum_replies`, calls `handle_updated_at`.

  5. Important Notes
     - The `user_id` references `auth.users.id`. User profile information (like username) should be joined from the `profiles` table.
     - `parent_reply_id` is for future support of threaded comments. For now, it can be NULL.
*/

-- Create the forum_replies table
CREATE TABLE IF NOT EXISTS public.forum_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  parent_reply_id uuid REFERENCES public.forum_replies(id) ON DELETE CASCADE, -- For threaded replies
  content text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for foreign keys for performance
CREATE INDEX IF NOT EXISTS idx_forum_replies_post_id ON public.forum_replies(post_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_user_id ON public.forum_replies(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_parent_reply_id ON public.forum_replies(parent_reply_id);

-- Trigger to automatically update 'updated_at' on update
-- Ensure the function handle_updated_at() exists (created in forum_posts migration)
DROP TRIGGER IF EXISTS on_forum_replies_update_set_timestamp ON public.forum_replies;
CREATE TRIGGER on_forum_replies_update_set_timestamp
  BEFORE UPDATE ON public.forum_replies
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security for the forum_replies table
ALTER TABLE public.forum_replies ENABLE ROW LEVEL SECURITY;

-- RLS Policies for forum_replies

-- Allow authenticated users to read all replies
DROP POLICY IF EXISTS "Allow authenticated users to read all replies" ON public.forum_replies;
CREATE POLICY "Allow authenticated users to read all replies"
  ON public.forum_replies
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow users to insert their own replies
DROP POLICY IF EXISTS "Allow users to insert their own replies" ON public.forum_replies;
CREATE POLICY "Allow users to insert their own replies"
  ON public.forum_replies
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own replies
DROP POLICY IF EXISTS "Allow users to update their own replies" ON public.forum_replies;
CREATE POLICY "Allow users to update their own replies"
  ON public.forum_replies
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own replies
DROP POLICY IF EXISTS "Allow users to delete their own replies" ON public.forum_replies;
CREATE POLICY "Allow users to delete their own replies"
  ON public.forum_replies
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow admins and moderators to update any reply
DROP POLICY IF EXISTS "Allow admins and moderators to update any reply" ON public.forum_replies;
CREATE POLICY "Allow admins and moderators to update any reply"
  ON public.forum_replies
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

-- Allow admins and moderators to delete any reply
DROP POLICY IF EXISTS "Allow admins and moderators to delete any reply" ON public.forum_replies;
CREATE POLICY "Allow admins and moderators to delete any reply"
  ON public.forum_replies
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
