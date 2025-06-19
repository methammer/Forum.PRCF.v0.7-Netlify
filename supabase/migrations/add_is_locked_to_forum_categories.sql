<![CDATA[
/*
  # Add is_locked_for_users to forum_categories and update RLS for forum_posts

  This migration introduces a locking mechanism for forum categories and updates
  Row Level Security (RLS) policies on the `forum_posts` table to enforce this lock.

  1. Table Modification: `public.forum_categories`
     - Adds a new column `is_locked_for_users` (BOOLEAN, NOT NULL, DEFAULT FALSE).
     - When `is_locked_for_users` is TRUE, only users with roles 'MODERATOR', 'ADMIN', or 'SUPER_ADMIN'
       can create new posts in that category. Regular 'USER' role will be restricted.
     - All users can still read posts and create replies in locked categories.

  2. RLS Policy Update: `public.forum_posts`
     - Modifies the policy "Allow users to insert their own posts".
     - The updated policy checks the `is_locked_for_users` flag of the target category.
     - If the category is locked, only users with roles 'MODERATOR', 'ADMIN', or 'SUPER_ADMIN'
       can insert new posts. If not locked, any authenticated user can insert posts (provided they are the author).

  3. Important Notes
     - This change enhances content control by allowing administrators to designate certain
       sections (e.g., "Announcements") where only privileged users can initiate topics.
*/

-- Add the is_locked_for_users column to forum_categories
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'forum_categories' AND column_name = 'is_locked_for_users'
  ) THEN
    ALTER TABLE public.forum_categories
    ADD COLUMN is_locked_for_users BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

-- Update RLS policy on forum_posts for inserting new posts
DROP POLICY IF EXISTS "Allow users to insert their own posts" ON public.forum_posts;
CREATE POLICY "Allow users to insert their own posts"
  ON public.forum_posts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id AND -- User must be the author
    (
      -- Either the category is NOT locked
      NOT (
        SELECT fc.is_locked_for_users
        FROM public.forum_categories fc
        WHERE fc.id = category_id
      ) OR
      -- OR the category IS locked, but the user has a privileged role
      EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN')
      )
    )
  );

-- Ensure other policies on forum_posts remain, especially for admins/mods if they bypass the above for other reasons
-- (though the above policy should cover their insertion rights correctly even if locked).
-- For example, the "Allow admins and moderators to update any post" and "delete any post" policies
-- are not directly related to insertion but are important for overall management.
-- The existing policies for read, update, delete on forum_posts are assumed to be sufficient.
-- The RLS for reading categories and posts should allow all authenticated users regardless of lock status.
]]>
