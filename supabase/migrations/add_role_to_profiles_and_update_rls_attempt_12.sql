/*
  # Add Role to Profiles and Update RLS (Attempt 12 - Simplest `WITH CHECK` for UPDATE)

  This migration attempts to further isolate the "missing FROM-clause entry for table 'new'" error
  by using the absolute simplest `WITH CHECK (true)` clause for the UPDATE policy on `profiles`.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL). (Idempotent)

  2. Row Level Security (RLS) Policies on `public.profiles`
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` using `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` with check `auth.uid() = id`.
     - "Users can update own profile (simplest check).": `UPDATE` using `auth.uid() = id`
       AND `WITH CHECK (true)`.
       This is the key policy being tested. If this fails, the issue is very deep.
     - ALL Admin-specific policies for `profiles` are COMMENTED OUT.
     - The generic `Allow authenticated users to read profiles` from the initial migration is dropped.
     - The original `Users can update own profile` policy from the initial migration is dropped.

  3. Important Notes
     - This is a critical diagnostic step.
     - If this passes, the problem is specifically with referencing `NEW.column` or `OLD.column`
       in the `WITH CHECK` of an UPDATE policy.
     - If this fails with the same error, the issue is more fundamental to UPDATE policies
       on this table or the interpretation of `NEW`/`OLD` in this environment.
*/

-- 0. Drop potentially conflicting old policies
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile (non-restricted fields)." ON public.profiles; -- from previous attempts
DROP POLICY IF EXISTS "Users can update own profile (basic check)." ON public.profiles; -- from attempt 11
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles; -- for idempotency of this script

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

-- Users can update their own profile (simplest check) - THIS IS THE CORE TEST
CREATE POLICY "Users can update own profile (simplest check)."
  ON public.profiles FOR UPDATE
  USING ( auth.uid() = id )
  WITH CHECK ( true ); -- Simplest possible check.

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
