/*
  # Add Role to Profiles and Update RLS (Attempt 16 - Explicit OLD in WITH CHECK)

  This migration attempts to fix the "missing FROM-clause entry for table 'new'"
  error by explicitly using `OLD.column_name` in the `WITH CHECK` clause of the
  UPDATE policy for users on their own profiles.

  The policy aims to:
  - Allow users to update rows where `auth.uid()` matches `profiles.id` (USING clause).
  - Prevent users from changing their `id` or `role` (WITH CHECK clause).

  1. Table Modifications
     - `public.profiles`
       - Ensures `"role"` column (TEXT, default 'user', NOT NULL) exists. (Idempotent)

  2. Row Level Security (RLS) Policies on `public.profiles`
     - All existing relevant policies on `profiles` are dropped for a clean setup.
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` TO authenticated USING `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` TO authenticated WITH CHECK `auth.uid() = id`.
     - "Users can update own profile (no id/role change).": `UPDATE`
       `TO authenticated`
       `USING (auth.uid() = id)`
       `WITH CHECK (NEW.id = OLD.id AND NEW.role = OLD.role)`.

  3. Important Notes
     - This script tests if using `OLD.column_name` resolves the parsing issue with `NEW`
       in the `WITH CHECK` clause when a `USING` clause is also present.
*/

-- 0. Drop ALL RLS policies on public.profiles for a clean slate
DROP POLICY IF EXISTS "Users can update own profile (no id/role change)" ON public.profiles; -- From Attempt 15
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

-- 2. Ensure RLS is enabled on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for public.profiles

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

-- Users can update their own profile, but not change their id or role
CREATE POLICY "Users can update own profile (no id/role change)"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id) -- Qualifies which rows can be updated
  WITH CHECK (
    NEW.id = OLD.id AND         -- Prevent changing the id
    NEW.role = OLD.role         -- Prevent changing the role
    -- Other fields like username, full_name, avatar_url can be changed by the user.
  );

/*
  Admin policies and policies for other tables (forum_categories, forum_posts)
  are deferred until this core user update policy for profiles is confirmed stable.
*/
