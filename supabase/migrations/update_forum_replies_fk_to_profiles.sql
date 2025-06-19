<![CDATA[
/*
  # Update forum_replies.user_id foreign key to profiles

  This migration updates the foreign key constraint on the `user_id` column
  in the `public.forum_replies` table. It changes the reference from
  `auth.users(id)` to `public.profiles(id)`.

  This change is made to allow PostgREST to correctly infer the relationship
  between `forum_replies` and `profiles` for embedded selects, such as
  `author:profiles(username, avatar_url)`.

  1. Changes
     - Drop the existing foreign key constraint on `forum_replies.user_id`
       that references `auth.users(id)`. The original constraint was likely auto-named
       by PostgreSQL (e.g., `forum_replies_user_id_fkey`). This migration attempts
       to drop it using this common pattern.
     - Add a new foreign key constraint named `forum_replies_user_id_profiles_fkey`
       on `forum_replies.user_id` that references `public.profiles(id)`.
       The `ON DELETE CASCADE` behavior is maintained, ensuring that if a profile
       is deleted (which happens if the `auth.users` entry is deleted),
       the user's replies are also deleted.

  2. Important Notes
     - This change assumes that every `user_id` in `forum_replies` has a
       corresponding entry in `public.profiles`. This should be true due to
       the `handle_new_user` trigger that creates a profile for each new auth user.
     - After this migration, Supabase's schema cache for PostgREST might need
       a moment to refresh. If the error persists immediately after applying this,
       a brief delay or a manual schema refresh in the Supabase dashboard
       (Project Settings > API > "Reload Schema" under "PostgREST" section) might be necessary.
*/

-- Step 1: Drop the existing foreign key constraint.
-- The name 'forum_replies_user_id_fkey' is a common convention for a FK on user_id.
-- If PostgreSQL auto-named it differently (e.g., based on the target table 'auth.users'),
-- this specific DROP might not find it. If this step fails, the actual constraint
-- name must be identified from your database schema (e.g., via Supabase Studio SQL editor
-- or by inspecting the table structure) and used in the DROP CONSTRAINT command.
ALTER TABLE public.forum_replies DROP CONSTRAINT IF EXISTS forum_replies_user_id_fkey;

-- Step 2: Add the new foreign key constraint referencing public.profiles(id)
-- We use a new, descriptive name for this constraint.
ALTER TABLE public.forum_replies
  ADD CONSTRAINT forum_replies_user_id_profiles_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id)
  ON DELETE CASCADE;

-- Verification Note:
-- The RLS policies on `forum_replies` typically use `auth.uid()`, which corresponds to `auth.users.id`.
-- This change is compatible because `profiles.id` (now referenced by `forum_replies.user_id`)
-- is itself a foreign key to `auth.users.id` and holds the same UUID value.
-- Thus, comparisons like `forum_replies.user_id = auth.uid()` will continue to work correctly.
]]>