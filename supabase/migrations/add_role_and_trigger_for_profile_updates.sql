/*
  # Add Role to Profiles, Update RLS, and Add Trigger for Immutability (Attempt 18)

  This migration addresses persistent issues with using NEW/OLD in RLS `WITH CHECK`
  clauses for UPDATE operations on the `profiles` table when a `USING` clause is present.

  Strategy:
  1. RLS Policies:
     - SELECT: Users can view their own profile.
     - INSERT: Users can insert their own profile.
     - UPDATE: Users can update their own profile (checked by `USING`), with a
       permissive `WITH CHECK (true)`.
  2. Trigger: A `BEFORE UPDATE` trigger will prevent changes to `id` and `role` fields.

  Changes:
  1. Table Modifications:
     - `public.profiles`: Ensures "role" column (TEXT, default 'user', NOT NULL) exists.

  2. Helper Function (Cleanup):
     - Drops `public.can_update_profile_check` if it exists (from Attempt 17).

  3. New Trigger Function:
     - `public.prevent_profile_id_role_change()`: Raises an exception if an update
       attempts to modify `id` or `role`.

  4. New Trigger:
     - `before_profile_update_prevent_id_role_change`: Executes the trigger function
       before each row update on `public.profiles`.

  5. Row Level Security (RLS) Policies on `public.profiles`:
     - All existing relevant policies on `profiles` are dropped for a clean setup.
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` TO authenticated USING `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` TO authenticated WITH CHECK `auth.uid() = id`.
     - "Users can update own profile (row access).": `UPDATE`
       `TO authenticated`
       `USING (auth.uid() = id)`
       `WITH CHECK (true)`. The actual field change restriction is handled by the trigger.
*/

-- 0. Drop previous helper function and ALL RLS policies on public.profiles for a clean slate
DROP FUNCTION IF EXISTS public.can_update_profile_check(uuid, uuid, text, text);

DROP POLICY IF EXISTS "Users can update own profile (via func check)" ON public.profiles; -- From Attempt 17
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
DROP POLICY IF EXISTS "Users can update own profile (row access)." ON public.profiles;


-- 1. Ensure 'role' column exists in profiles table (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN "role" TEXT NOT NULL DEFAULT 'user';
    COMMENT ON COLUMN public.profiles."role" IS 'User role, e.g., ''user'', ''moderator'', ''admin''';
  ELSE
    -- Ensure the column is NOT NULL and has a default, even if it exists
    ALTER TABLE public.profiles ALTER COLUMN "role" SET NOT NULL;
    ALTER TABLE public.profiles ALTER COLUMN "role" SET DEFAULT 'user';
  END IF;
END $$;

-- 2. Create the trigger function to prevent id/role changes
CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- Executes with the privileges of the function definer.
AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Changing the profile role directly is not allowed. Role changes must be performed by an administrator.';
  END IF;
  RETURN NEW; -- Allow the update if checks pass
END;
$$;

-- 3. Drop existing trigger if it exists, then create the trigger
DROP TRIGGER IF EXISTS before_profile_update_prevent_id_role_change ON public.profiles;
CREATE TRIGGER before_profile_update_prevent_id_role_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_profile_id_role_change();

-- 4. Ensure RLS is enabled on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for public.profiles

-- Users can view their own profile
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id AND NEW.role = 'user'); -- New users default to 'user' role, cannot set it otherwise on insert

-- Users can update their own profile (row access determined by USING, field changes by trigger)
CREATE POLICY "Users can update own profile (row access)."
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id) -- Qualifies which rows can be updated
  WITH CHECK (true); -- Allows any change to proceed to the trigger level if USING condition is met

/*
  Note on INSERT policy:
  The `WITH CHECK (auth.uid() = id AND NEW.role = 'user')` ensures that when a user
  inserts their own profile (typically handled by the `handle_new_user` trigger,
  but this RLS provides an additional layer), they cannot assign themselves a role
  other than 'user'. The `handle_new_user` function should also be reviewed to ensure
  it doesn't attempt to set a role based on metadata if we want this restriction.
  For now, the `profiles.role` column has `DEFAULT 'user'`, which is good.
  The `handle_new_user` function in `0_create_profiles_table.sql` does not set role,
  so the default 'user' will apply, which is consistent.
*/

/*
  Admin policies and policies for other tables (forum_categories, forum_posts)
  are deferred until this core user update policy for profiles is confirmed stable.
*/
