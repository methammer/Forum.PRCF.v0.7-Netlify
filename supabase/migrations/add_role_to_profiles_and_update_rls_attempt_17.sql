/*
  # Add Role to Profiles and Update RLS (Attempt 17 - Function for WITH CHECK)

  This migration attempts to fix the "missing FROM-clause entry for table 'new'"
  error by using a helper SQL function within the `WITH CHECK` clause of the
  UPDATE policy for users on their own profiles.

  The policy aims to:
  - Allow users to update rows where `auth.uid()` matches `profiles.id` (USING clause).
  - Prevent users from changing their `id` or `role` by calling a function
    that compares `NEW.id` with `OLD.id` and `NEW.role` with `OLD.role`.

  1. New Helper Function
     - `public.can_update_profile_check(new_id uuid, old_id uuid, new_role text, old_role text)`
       - Returns `TRUE` if `new_id = old_id` AND `new_role = old_role`.
       - `STABLE`, `SECURITY DEFINER`.

  2. Table Modifications
     - `public.profiles`
       - Ensures `"role"` column (TEXT, default 'user', NOT NULL) exists. (Idempotent)

  3. Row Level Security (RLS) Policies on `public.profiles`
     - All existing relevant policies on `profiles` are dropped for a clean setup.
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` TO authenticated USING `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` TO authenticated WITH CHECK `auth.uid() = id`.
     - "Users can update own profile (via func check).": `UPDATE`
       `TO authenticated`
       `USING (auth.uid() = id)`
       `WITH CHECK (public.can_update_profile_check(NEW.id, OLD.id, NEW.role, OLD.role))`.

  4. Important Notes
     - This script tests if moving the `NEW.field = OLD.field` logic into a function
       resolves the parsing issue.
*/

-- 0. Drop ALL RLS policies on public.profiles for a clean slate
DROP POLICY IF EXISTS "Users can update own profile (no id/role change)" ON public.profiles; -- From Attempt 16
DROP POLICY IF EXISTS "Users can update own profile (no id/email/role change)" ON public.profiles; -- From Attempt 14
DROP POLICY IF EXISTS "Allow any authenticated to update profile (diagnostic)" ON public.profiles; -- From Attempt 13
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles; -- From Attempt 12
-- Older policies that might exist
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
DROP POLICY IF EXISTS "Admins can update status and role of any profile." ON public.profiles;
-- Policy from this attempt if it needs to be re-run
DROP POLICY IF EXISTS "Users can update own profile (via func check)" ON public.profiles;


-- 1. Ensure 'role' column exists in profiles table (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN "role" TEXT NOT NULL DEFAULT 'user';
    COMMENT ON COLUMN public.profiles."role" IS 'User role, e.g., ''user'', ''moderator'', ''admin''';
  END IF;
END $$;

-- 2. Create or Replace the helper function for the WITH CHECK clause
CREATE OR REPLACE FUNCTION public.can_update_profile_check(
  new_id uuid,
  old_id uuid,
  new_role text,
  old_role text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE -- Function result depends only on input arguments, safe for RLS.
SECURITY DEFINER -- Executes with the privileges of the user that defines it.
AS $$
BEGIN
  RETURN new_id = old_id AND new_role = old_role;
END;
$$;

-- 3. Ensure RLS is enabled on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for public.profiles

-- Users can view their own profile
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile, but not change their id or role, using a helper function
CREATE POLICY "Users can update own profile (via func check)"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id) -- Qualifies which rows can be updated
  WITH CHECK (
    public.can_update_profile_check(NEW.id, OLD.id, NEW.role, OLD.role)
  );

/*
  Admin policies and policies for other tables (forum_categories, forum_posts)
  are deferred until this core user update policy for profiles is confirmed stable.
*/
