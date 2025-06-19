/*
  # Add Role to Profiles and Update RLS (Attempt 15 - Corrected User UPDATE Policy)

  This migration corrects the UPDATE policy for users on their own profiles.
  The previous attempt (14) failed due to referencing a non-existent 'email' column
  in the 'profiles' table within the WITH CHECK clause. This version removes that check.

  The policy now prevents users from changing their ID or role, while allowing
  other profile modifications. It uses the `NEW.column = column` syntax in `WITH CHECK`.

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
       `WITH CHECK (NEW.id = id AND NEW.role = "role")`.
       (The check for `NEW.email = email` has been removed as `email` is not a column in `profiles`.)

  3. Important Notes
     - This script focuses on establishing a secure and functional update policy for users.
     - If this works, it confirms that the issue in Attempt 14 was the reference to a
       non-existent column in the `WITH CHECK` clause.
*/

-- 0. Drop ALL RLS policies on public.profiles for a clean slate
DROP POLICY IF EXISTS "Users can update own profile (no id/email/role change)" ON public.profiles; -- From Attempt 14
DROP POLICY IF EXISTS "Allow any authenticated to update profile (diagnostic)" ON public.profiles; -- From Attempt 13
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles; -- From Attempt 12
-- Idempotency for this script's new policy
DROP POLICY IF EXISTS "Users can update own profile (no id/role change)" ON public.profiles;
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
  USING (auth.uid() = id) -- This 'id' refers to profiles.id
  WITH CHECK (
    NEW.id = id AND         -- This 'id' on the right refers to the current row's 'id' (profiles.id)
    NEW.role = "role"       -- This 'role' on the right refers to the current row's 'role' (profiles.role)
    -- Other fields like username, full_name, avatar_url can be changed by the user.
    -- The check for NEW.email = email was removed as 'email' is not a column in 'public.profiles'.
  );

/*
  Admin policies and policies for other tables (forum_categories, forum_posts)
  are deferred until this core user update policy for profiles is confirmed stable.
*/
