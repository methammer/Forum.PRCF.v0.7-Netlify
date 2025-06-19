/*
  # Add Role to Profiles and Update RLS (Attempt 14 - Targeted User UPDATE Policy)

  This migration defines an UPDATE policy for users on their own profiles,
  preventing them from changing their ID, email, or role, while allowing other modifications.
  It tests the `NEW.column = column` syntax in `WITH CHECK` (where `column` refers to the old value)
  in conjunction with a `USING` clause.

  1. Table Modifications
     - `public.profiles`
       - Ensures `"role"` column (TEXT, default 'user', NOT NULL) exists. (Idempotent)

  2. Row Level Security (RLS) Policies on `public.profiles`
     - All existing relevant policies on `profiles` are dropped.
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` TO authenticated USING `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` TO authenticated WITH CHECK `auth.uid() = id`.
     - "Users can update own profile (no id/email/role change).": `UPDATE`
       `TO authenticated`
       `USING (auth.uid() = id)`
       `WITH CHECK (NEW.id = id AND NEW.email = email AND NEW.role = "role")`.

  3. Important Notes
     - This script focuses on establishing a secure and functional update policy for users.
     - If this works, it confirms that `NEW.column = column` (implicit old value) is the correct
       syntax to use in `WITH CHECK` when a `USING` clause is present, instead of `NEW.column = OLD.column`.
*/

-- 0. Drop ALL RLS policies on public.profiles for a clean slate
-- Policies from Attempt 13
DROP POLICY IF EXISTS "Allow any authenticated to update profile (diagnostic)" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- Will be recreated
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles; -- Will be recreated
-- Policy from Attempt 12
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles;
-- Idempotency for this script's new policy
DROP POLICY IF EXISTS "Users can update own profile (no id/email/role change)" ON public.profiles;
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

-- Users can update their own profile, but not change their id, email, or role
CREATE POLICY "Users can update own profile (no id/email/role change)"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    NEW.id = id AND         -- Cannot change their own ID
    NEW.email = email AND   -- Cannot change their own email (assuming 'email' column exists and should be protected)
    NEW.role = "role"       -- Cannot change their own role
    -- Other fields like username, full_name, avatar_url, website can be changed by the user.
  );

/*
  Admin policies and policies for other tables (forum_categories, forum_posts)
  are deferred until this core user update policy for profiles is confirmed stable.
*/
