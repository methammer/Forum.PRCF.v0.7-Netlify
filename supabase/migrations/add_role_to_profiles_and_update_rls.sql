/*
  # Add Role to Profiles and Update RLS (Attempt 5 for 42P01 OLD error - Decouple role check from OLD record)

  This migration introduces an admin role and updates Row Level Security (RLS)
  policies to support an administration panel.

  Key change in this version:
  - In the "Users can update their own profile (non-restricted fields)" policy:
    - The `WITH CHECK` clause for `"role"` now compares `NEW."role"` against the authenticated user's
      current role fetched via `(SELECT p_check."role" FROM public.profiles p_check WHERE p_check.id = auth.uid())`.
    - This avoids using `OLD.id` or `OLD."role"` in the subquery for the role check, aiming to bypass
      the "missing FROM-clause entry for table 'old'" error related to that specific comparison.
    - An additional check `auth.uid() = NEW.id` is included to ensure the profile ID itself isn't illicitly changed.
    - The check for `status` still uses `OLD.status`.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL): Stores user role (e.g., 'user', 'admin', 'moderator').

  2. New/Updated Row Level Security (RLS) Policies
     - `public.profiles`:
       - NEW: "Admins can read all profiles."
       - NEW: "Admins can update status and role of any profile."
       - EXISTING (modified): "Users can update their own profile (non-restricted fields)."
     - `public.forum_categories`:
       - NEW: "Admins can manage all categories."
     - `public.forum_posts`:
       - NEW: "Admins can manage all posts."

  3. Important Notes
     - The `"role"` column defaults to 'user' and is NOT NULL.
     - It's assumed that `updated_at` column in `profiles` table is auto-updated by a trigger.
*/

-- 1. Add role column to profiles table
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

-- 2. RLS Policies for public.profiles

-- Ensure users can still read their own profile
DROP POLICY IF EXISTS "Users can read their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Ensure users can update their own profile (non-restricted fields)
DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile (non-restricted fields)." ON public.profiles;
CREATE POLICY "Users can update their own profile (non-restricted fields)."
  ON public.profiles FOR UPDATE
  USING ( auth.uid() = OLD.id ) -- Policy applies when a user updates their own row.
  WITH CHECK (
    auth.uid() = NEW.id AND -- The ID of the row must remain the user's ID.
    NEW."role" = (
      SELECT p_check."role"
      FROM public.profiles p_check
      WHERE p_check.id = auth.uid() -- Compare NEW."role" against the current role of the authenticated user.
    ) AND
    (NEW.status IS NOT DISTINCT FROM OLD.status) -- Status cannot be changed by the user via this policy.
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
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK (
    (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' AND
    (NEW.username IS NOT DISTINCT FROM OLD.username) AND
    (NEW.full_name IS NOT DISTINCT FROM OLD.full_name) AND
    (NEW.avatar_url IS NOT DISTINCT FROM OLD.avatar_url) AND
    (NEW.website IS NOT DISTINCT FROM OLD.website)
  );

-- 3. RLS Policies for public.forum_categories

DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;
CREATE POLICY "Admins can manage all categories."
  ON public.forum_categories FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );

-- 4. RLS Policies for public.forum_posts

DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;
CREATE POLICY "Admins can manage all posts."
  ON public.forum_posts FOR ALL
  TO authenticated
  USING ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' )
  WITH CHECK ( (SELECT pro."role" FROM public.profiles pro WHERE pro.id = auth.uid()) = 'admin' );
