/*
  # Add Role to Profiles and Update RLS (Attempt 7 - RLS Helper Function with Simplified USING Clause)

  This migration continues the effort to introduce an admin role and update Row Level Security (RLS)
  policies. It retains the PL/pgSQL helper function `public.can_user_update_own_profile`
  and modifies the `USING` clause of the user's own profile update policy to use `id`
  instead of `OLD.id`, aiming to resolve persistent "missing FROM-clause entry for table 'old'" errors.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL): Stores user role. (Idempotent)

  2. Helper Function (Unchanged from Attempt 6)
     - `public.can_user_update_own_profile(new_profile_state public.profiles, old_profile_state public.profiles)`
       - Checks if a user is allowed to update their own profile based on restricted fields (id, role, status).

  3. New/Updated Row Level Security (RLS) Policies
     - `public.profiles`:
       - "Users can update their own profile (non-restricted fields).":
         - `USING` clause changed from `(auth.uid() = OLD.id)` to `(auth.uid() = id)`.
         - `WITH CHECK` clause still uses the helper function `public.can_user_update_own_profile(NEW, OLD)`.
       - Other policies (Admin RLS, user view RLS) remain as in Attempt 6.
     - `public.forum_categories` & `public.forum_posts`: Admin RLS policies remain as in Attempt 6.

  4. Important Notes
     - The `"role"` column defaults to 'user'.
     - The helper function is `SECURITY INVOKER`.
     - The primary change is the simplification of the `USING` clause in one policy.
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

-- 2. Create helper function for user profile updates (Unchanged from Attempt 6)
CREATE OR REPLACE FUNCTION public.can_user_update_own_profile(
    new_profile_state public.profiles,
    old_profile_state public.profiles
)
RETURNS boolean AS $$
BEGIN
    -- Ensure the operation is on the authenticated user's own profile.
    IF old_profile_state.id != auth.uid() THEN
        RAISE WARNING '[RLS Check Func] Denied: Operation on profile % attempted by non-owner (auth_id: %).', old_profile_state.id, auth.uid();
        RETURN false;
    END IF;

    -- Ensure the profile ID itself is not being changed to something else.
    IF new_profile_state.id != old_profile_state.id THEN
        RAISE WARNING '[RLS Check Func] Denied: Attempt to change profile ID from % to % by user %.', old_profile_state.id, new_profile_state.id, auth.uid();
        RETURN false;
    END IF;

    -- Ensure the profile ID, even if not changed from old_profile_state.id, still matches auth.uid().
    IF new_profile_state.id != auth.uid() THEN
        RAISE WARNING '[RLS Check Func] Denied: Attempt to set profile ID to % which is not the authenticated user ID %.', new_profile_state.id, auth.uid();
        RETURN false;
    END IF;

    -- Ensure 'role' is not changed by the user.
    IF new_profile_state."role" IS DISTINCT FROM old_profile_state."role" THEN
        RAISE WARNING '[RLS Check Func] Denied: User % attempt to change own role from "%" to "%" for profile %.', auth.uid(), old_profile_state."role", new_profile_state."role", old_profile_state.id;
        RETURN false;
    END IF;

    -- Ensure 'status' is not changed by the user.
    IF new_profile_state.status IS DISTINCT FROM old_profile_state.status THEN
        RAISE WARNING '[RLS Check Func] Denied: User % attempt to change own status from "%" to "%" for profile %.', auth.uid(), old_profile_state.status, new_profile_state.status, old_profile_state.id;
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER;

COMMENT ON FUNCTION public.can_user_update_own_profile(public.profiles, public.profiles) IS 'Checks if a user is permitted to make the proposed changes to their own profile, verifying restrictions on id, role, and status fields.';

-- 3. RLS Policies for public.profiles

-- Users can view their own profile
DROP POLICY IF EXISTS "Users can read their own profile." ON public.profiles; -- old name
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile (non-restricted fields), using the helper function
DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles; -- old name
DROP POLICY IF EXISTS "Users can update their own profile (non-restricted fields)." ON public.profiles;
CREATE POLICY "Users can update their own profile (non-restricted fields)."
  ON public.profiles FOR UPDATE
  USING ( auth.uid() = id ) -- MODIFIED: OLD.id changed to id
  WITH CHECK (
    public.can_user_update_own_profile(NEW, OLD) -- Call the helper function
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
    (NEW.website IS NOT DISTINCT FROM OLD.website) AND
    (NEW.id IS NOT DISTINCT FROM OLD.id)
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
