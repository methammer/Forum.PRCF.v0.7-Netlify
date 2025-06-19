/*
  # Update Profile Role Default to Uppercase (Attempt 20)

  This migration updates the default value for the `role` column in the `public.profiles`
  table from 'user' (lowercase) to 'USER' (uppercase). This change is necessary to
  align with the frontend's expectation for role values, as seen in `UserContext.tsx`,
  which validates against uppercase roles ('USER', 'ADMIN', etc.).

  Changes:
  1. Table Modifications:
     - `public.profiles`: The `role` column's default value is changed from 'user' to 'USER'.
       This applies if the column is being newly added or if its default is being altered.
  2. Comments:
     - Updated the note at the end of the script to reflect that the default role is now 'USER'.

  Previous Logic (Retained):
  - Ensures "role" column (TEXT, NOT NULL) exists.
  - Drops and recreates the `prevent_profile_id_role_change` trigger function and trigger.
  - Ensures RLS is enabled and recreates RLS policies for `SELECT`, `INSERT`, and `UPDATE`
    on `public.profiles`.
    - The `INSERT` policy's `WITH CHECK` clause remains `(auth.uid() = id)`, relying on the
      column default for the initial role.
*/

-- 0. Drop previous helper function and ALL RLS policies on public.profiles for a clean slate
DROP FUNCTION IF EXISTS public.can_update_profile_check(uuid, uuid, text, text);

DROP POLICY IF EXISTS "Users can update own profile (via func check)" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile (no id/role change)" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile (no id/email/role change)" ON public.profiles;
DROP POLICY IF EXISTS "Allow any authenticated to update profile (diagnostic)" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
DROP POLICY IF EXISTS "Admins can update status and role of any profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile (row access)." ON public.profiles;


-- 1. Ensure 'role' column exists in profiles table with 'USER' as default (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN "role" TEXT NOT NULL DEFAULT 'USER'; -- Changed to 'USER'
    COMMENT ON COLUMN public.profiles."role" IS 'User role, e.g., ''USER'', ''MODERATOR'', ''ADMIN''';
  ELSE
    -- Ensure NOT NULL constraint is present
    ALTER TABLE public.profiles ALTER COLUMN "role" SET NOT NULL;
    -- Ensure default is 'USER'
    ALTER TABLE public.profiles ALTER COLUMN "role" SET DEFAULT 'USER'; -- Changed to 'USER'
  END IF;
END $$;

-- 2. Create the trigger function to prevent id/role changes
CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Changing the profile role directly is not allowed. Role changes must be performed by an administrator.';
  END IF;
  RETURN NEW;
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
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile (row access determined by USING, field changes by trigger)
CREATE POLICY "Users can update own profile (row access)."
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (true);

/*
  Note on INSERT policy and role default:
  The `profiles.role` column now has `DEFAULT 'USER'`. The `handle_new_user`
  trigger (from `0_create_profiles_table.sql`) does not explicitly set the role,
  so new profiles will correctly default to 'USER' (uppercase), aligning with
  frontend expectations.
*/
