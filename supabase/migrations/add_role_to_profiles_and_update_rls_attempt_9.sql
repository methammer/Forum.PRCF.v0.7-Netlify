/*
  # Add Role to Profiles and Update RLS (Attempt 9 - Rework IS NOT DISTINCT FROM)

  This migration introduces an admin role and updates Row Level Security (RLS) policies.
  It continues to use inlined RLS logic (no helper function).
  The primary change in this attempt is replacing `IS NOT DISTINCT FROM` with its
  equivalent `(X = Y OR (X IS NULL AND Y IS NULL))` form in `WITH CHECK` clauses
  to troubleshoot persistent "missing FROM-clause entry for table 'new'" errors.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL): Stores user role. (Idempotent)

  2. Helper Function
     - `public.can_user_update_own_profile` (Remains REMOVED)

  3. New/Updated Row Level Security (RLS) Policies
     - `public.profiles`:
       - "Users can update their own profile (non-restricted fields).":
         - `USING` clause: `(auth.uid() = id)`.
         - `WITH CHECK` clause now uses explicit null checks instead of `IS NOT DISTINCT FROM`
           for `role` and `status` fields:
           `NEW.id = OLD.id AND`
           `(NEW."role" = OLD."role" OR (NEW."role" IS NULL AND OLD."role" IS NULL)) AND`
           `(NEW.status = OLD.status OR (NEW.status IS NULL AND OLD.status IS NULL))`
       - "Admins can update status and role of any profile.":
         - `WITH CHECK` clause similarly updated for `username`, `full_name`, `avatar_url`, `website`.
         - `id` check remains `NEW.id = OLD.id` as it's a PK.
     - `public.forum_categories` & `public.forum_posts`: Admin RLS policies remain unchanged.

  4. Important Notes
     - The `"role"` column defaults to 'user'.
     - This attempt focuses on altering the expression of null-safe comparisons.
*/

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

-- 2. Ensure the helper function is removed (if it exists from previous attempts)
DROP FUNCTION IF EXISTS public.can_user_update_own_profile(public.profiles, public.profiles);

-- 3. RLS Policies for public.profiles

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can read their own profile." ON public.profiles; -- old name
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile (non-restricted fields)
DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles; -- old name
DROP POLICY IF EXISTS "Users can update their own profile (non-restricted fields)." ON public.profiles;
CREATE POLICY "Users can update their own profile (non-restricted fields)."
  ON public.profiles FOR UPDATE
  USING ( auth.uid() = id ) -- The user must own the row
  WITH CHECK (
    -- User cannot change their own ID, role, or status
    NEW.id = OLD.id AND -- ID is PK, cannot be NULL, direct comparison is fine
    (NEW."role" = OLD."role" OR (NEW."role" IS NULL AND OLD."role" IS NULL)) AND
    (NEW.status = OLD.status OR (NEW.status IS NULL AND OLD.status IS NULL))
  );

-- Admins RLS for profiles
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
CREATE POLICY "Admins can read all profiles."
  ON public.profiles FOR SELECT
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

DROP POLICY IF EXISTS "Admins can update status and role of any profile." ON public.profiles;
CREATE POLICY "Admins can update status and role of any profile."
  ON public.profiles FOR UPDATE
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' ) -- Updater must be an admin
  WITH CHECK (
    (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' AND -- Double check updater is admin
    -- Admin cannot change these specific fields for other users (or themselves via this policy)
    (NEW.username = OLD.username OR (NEW.username IS NULL AND OLD.username IS NULL)) AND
    (NEW.full_name = OLD.full_name OR (NEW.full_name IS NULL AND OLD.full_name IS NULL)) AND
    (NEW.avatar_url = OLD.avatar_url OR (NEW.avatar_url IS NULL AND OLD.avatar_url IS NULL)) AND
    (NEW.website = OLD.website OR (NEW.website IS NULL AND OLD.website IS NULL)) AND
    NEW.id = OLD.id -- Admin cannot change a user's ID (PK, not NULL)
    -- Admin *can* change NEW."role" and NEW.status via this policy.
  );

-- 4. RLS Policies for public.forum_categories (Unchanged from previous attempt)

DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;
CREATE POLICY "Admins can manage all categories."
  ON public.forum_categories FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

-- 5. RLS Policies for public.forum_posts (Unchanged from previous attempt)

DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;
CREATE POLICY "Admins can manage all posts."
  ON public.forum_posts FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );
