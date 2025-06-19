/*
  # Add Role to Profiles and Update RLS (Attempt 8 - Inline RLS Logic)

  This migration introduces an admin role and updates Row Level Security (RLS) policies.
  It removes the PL/pgSQL helper function `public.can_user_update_own_profile` due to
  errors with `NEW`/`OLD` record passing. The logic for users updating their own profiles
  is now directly inlined into the `WITH CHECK` clause of the relevant policy.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL): Stores user role. (Idempotent)

  2. Helper Function
     - `public.can_user_update_own_profile` (REMOVED)

  3. New/Updated Row Level Security (RLS) Policies
     - `public.profiles`:
       - "Users can update their own profile (non-restricted fields).":
         - `USING` clause remains `(auth.uid() = id)`.
         - `WITH CHECK` clause now directly checks that `id`, `role`, and `status` fields are not changed by the user:
           `(NEW.id = OLD.id AND NEW."role" IS NOT DISTINCT FROM OLD."role" AND NEW.status IS NOT DISTINCT FROM OLD.status)`
       - Other policies (Admin RLS, user view RLS) remain similar to previous attempts.
     - `public.forum_categories` & `public.forum_posts`: Admin RLS policies remain.

  4. Important Notes
     - The `"role"` column defaults to 'user'.
     - The RLS logic for users updating their own profiles is now self-contained in the policy definition.
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

-- 2. Remove the helper function (if it exists from previous attempts)
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
    NEW.id = OLD.id AND
    NEW."role" IS NOT DISTINCT FROM OLD."role" AND
    NEW.status IS NOT DISTINCT FROM OLD.status
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
    (NEW.username IS NOT DISTINCT FROM OLD.username) AND
    (NEW.full_name IS NOT DISTINCT FROM OLD.full_name) AND
    (NEW.avatar_url IS NOT DISTINCT FROM OLD.avatar_url) AND
    (NEW.website IS NOT DISTINCT FROM OLD.website) AND
    (NEW.id IS NOT DISTINCT FROM OLD.id) -- Admin cannot change a user's ID
    -- Admin *can* change NEW."role" and NEW.status via this policy.
  );

-- 4. RLS Policies for public.forum_categories

DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;
CREATE POLICY "Admins can manage all categories."
  ON public.forum_categories FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

-- 5. RLS Policies for public.forum_posts

DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;
CREATE POLICY "Admins can manage all posts."
  ON public.forum_posts FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );
