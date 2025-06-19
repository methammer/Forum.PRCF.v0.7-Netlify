/*
  # Add Role to Profiles and Update RLS (Attempt 11 - Ultra-Minimal UPDATE Policy)

  This migration attempts to isolate the "missing FROM-clause entry for table 'new'" error
  by drastically simplifying the RLS policies on the `profiles` table, focusing on
  a very basic UPDATE policy that uses NEW and OLD.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL). (Idempotent)

  2. Row Level Security (RLS) Policies on `public.profiles`
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` using `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` with check `auth.uid() = id`.
     - "Users can update own profile (basic check).": `UPDATE` using `auth.uid() = id`
       AND `WITH CHECK (NEW.id = OLD.id AND NEW.role = OLD.role)`.
       This is the key policy being tested.
     - ALL Admin-specific policies for `profiles` are COMMENTED OUT for this test.
     - The generic `Allow authenticated users to read profiles` from the initial migration is dropped.
     - The original `Users can update own profile` policy from the initial migration is dropped.


  3. Important Notes
     - This is a diagnostic step. If this fails, the issue with NEW/OLD in WITH CHECK
       is very fundamental in this environment for the profiles table.
     - If this passes, we can incrementally add back complexity.
*/

-- 0. Drop potentially conflicting old policies from 0_create_profiles_table.sql
-- The original "Users can update own profile" did not use NEW/OLD in its check.
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;

-- 1. Add role column to profiles table (idempotent)
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
-- Note: ALTER TABLE ... ENABLE ROW LEVEL SECURITY is idempotent.
-- If RLS is already enabled, this command does nothing.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for public.profiles - MINIMAL SET FOR TESTING

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can insert their own profile
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile (basic check) - THIS IS THE CORE TEST
DROP POLICY IF EXISTS "Users can update their own profile (non-restricted fields)." ON public.profiles; -- from previous attempts
DROP POLICY IF EXISTS "Users can update own profile (basic check)." ON public.profiles;
CREATE POLICY "Users can update own profile (basic check)."
  ON public.profiles FOR UPDATE
  USING ( auth.uid() = id )
  WITH CHECK (
    NEW.id = OLD.id AND
    NEW.role = OLD.role -- Prevent user from changing their own role
    -- Other fields like username, full_name, avatar_url, website can be changed by the user via this policy.
  );

/* -- ADMIN POLICIES FOR PROFILES - TEMPORARILY COMMENTED OUT
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
CREATE POLICY "Admins can read all profiles."
  ON public.profiles FOR SELECT
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

DROP POLICY IF EXISTS "Admins can update status and role of any profile." ON public.profiles;
CREATE POLICY "Admins can update status and role of any profile."
  ON public.profiles FOR UPDATE
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK (
    (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' AND
    (NEW.username = OLD.username OR (NEW.username IS NULL AND OLD.username IS NULL)) AND
    (NEW.full_name = OLD.full_name OR (NEW.full_name IS NULL AND OLD.full_name IS NULL)) AND
    (NEW.avatar_url = OLD.avatar_url OR (NEW.avatar_url IS NULL AND OLD.avatar_url IS NULL)) AND
    (NEW.website = OLD.website OR (NEW.website IS NULL AND OLD.website IS NULL)) AND
    NEW.id = OLD.id -- Admin cannot change a user's ID
    -- Admin *can* change NEW."role" and NEW.status (if status column existed) via this policy.
  );
*/

-- 4. RLS Policies for public.forum_categories (Unchanged from previous attempt, assumed not problematic)
-- Ensure these are idempotent by dropping if they exist.
DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;
CREATE POLICY "Admins can manage all categories."
  ON public.forum_categories FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

-- 5. RLS Policies for public.forum_posts (Unchanged from previous attempt, assumed not problematic)
-- Ensure these are idempotent by dropping if they exist.
DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;
CREATE POLICY "Admins can manage all posts."
  ON public.forum_posts FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );
