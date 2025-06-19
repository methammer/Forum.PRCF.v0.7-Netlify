/*
  # Add Role to Profiles and Update RLS (Attempt 13 - Permissive UPDATE Policy Test)

  This migration attempts to diagnose the persistent "missing FROM-clause entry for table 'new'" error
  by applying the most permissive and simple UPDATE policy possible on the `profiles` table.

  1. Table Modifications
     - `public.profiles`
       - Added `"role"` column (TEXT, default 'user', NOT NULL). (Idempotent)

  2. Row Level Security (RLS) Policies on `public.profiles`
     - All existing relevant policies on `profiles` are dropped.
     - RLS Enabled.
     - "Users can view their own profile.": `SELECT` using `auth.uid() = id`.
     - "Users can insert their own profile.": `INSERT` with check `auth.uid() = id`.
     - "Allow any authenticated to update profile (diagnostic).": `UPDATE`
       `TO authenticated` (NO USING CLAUSE)
       `WITH CHECK (true)`.
       This is the core diagnostic policy. If this fails, the issue is very fundamental.

  3. Important Notes
     - This script focuses exclusively on `profiles` RLS to isolate the error.
     - Policies for `forum_categories`, `forum_posts`, and admin-level `profiles` access are EXCLUDED.
     - The UPDATE policy is intentionally insecure for diagnostic purposes ONLY.
     - If this script succeeds, the `USING (auth.uid() = id)` clause in UPDATE policies is implicated.
     - If it fails with the same error, the problem lies with `FOR UPDATE ... WITH CHECK (true)` on `profiles`.
*/

-- 0. Drop ALL potentially relevant RLS policies on public.profiles for a clean slate
DROP POLICY IF EXISTS "Users can update own profile (simplest check)." ON public.profiles; -- From attempt 12
DROP POLICY IF EXISTS "Users can update own profile (test with true)" ON public.profiles; -- A possible name from thought process
DROP POLICY IF EXISTS "Allow any authenticated to update profile (diagnostic)" ON public.profiles; -- For idempotency of this script
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles; -- From 0_create_profiles_table.sql
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- From 0_create_profiles_table.sql & attempt 12
DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles; -- From attempt 12
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles; -- From 0_create_profiles_table.sql
-- Drop any admin policies if they were somehow created
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
DROP POLICY IF EXISTS "Admins can update status and role of any profile." ON public.profiles;


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

-- 3. RLS Policies for public.profiles - FOCUSED DIAGNOSTIC SET

-- Users can view their own profile
CREATE POLICY "Users can view their own profile."
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Diagnostic UPDATE Policy: Allow any authenticated user to update, simplest check, NO USING clause.
CREATE POLICY "Allow any authenticated to update profile (diagnostic)"
  ON public.profiles FOR UPDATE
  TO authenticated -- Applies to all authenticated users
  WITH CHECK (true); -- Simplest possible check, no conditions on columns.

/*
  Policies for forum_categories and forum_posts are intentionally omitted in this script
  to isolate the issue to the 'profiles' table.
  Admin policies for 'profiles' are also omitted.
*/
