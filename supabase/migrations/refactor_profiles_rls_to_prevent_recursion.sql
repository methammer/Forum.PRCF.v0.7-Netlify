<content>/*
  # Refactor RLS Policies for Profiles Table to Prevent Recursion (v2 - SECURITY DEFINER)

  This migration addresses a "stack depth limit exceeded" (infinite recursion) error
  in the RLS policies for the `public.profiles` table. The recursion was caused by
  the `get_current_user_role()` helper function, when used as `SECURITY INVOKER`,
  triggering RLS checks on `profiles` again.

  This version changes `get_current_user_role()` to `SECURITY DEFINER` to break
  the recursion.

  1.  **Dropped Policies**:
      - Drops all potentially conflicting RLS policies on `public.profiles`
        to ensure a clean slate.

  2.  **Updated Helper Function**:
      - `public.get_current_user_role()`:
        - Changed to `SECURITY DEFINER`. This allows the function's internal query
          on `public.profiles` to bypass RLS checks that would otherwise cause recursion.
          The function owner (typically a superuser) must have permissions to read `profiles`.
        - Safely retrieves the `role` of the currently authenticated user (`auth.uid()`)
          from the `public.profiles` table in lowercase.
        - `STABLE` and `SET search_path = public` for correctness and security.

  3.  **New RLS Policies for `public.profiles`**:
      - **Select Policy (`"Profiles: Users can view own, Admins/SuperAdmins can view all"`)**:
        - Allows users to select their own profile (`auth.uid() = id`).
        - Allows users whose role is 'admin' or 'super_admin' (as determined by `get_current_user_role()`)
          to select all profiles.
      - **Insert Policies**:
        - `"Profiles: Users can insert their own profile"`: Allows users to insert their own profile.
        - `"Profiles: Admins/SuperAdmins can insert any profile"`: Allows 'admin' or 'super_admin' to insert.
      - **Update Policy (`"Profiles: Users can update own, Admins/SuperAdmins can update any"`)**:
        - Allows users to update their own profile.
        - Allows 'admin' or 'super_admin' to update any profile.
      - **Delete Policy (`"Profiles: Admins/SuperAdmins can delete"`)**:
        - Allows 'admin' or 'super_admin' to delete profiles.

  4.  **RLS Enablement**:
      - Ensures Row Level Security is enabled on `public.profiles`.

  5.  **Function Grant**:
      - Grants `EXECUTE` permission on `public.get_current_user_role()` to `authenticated` users.
*/

-- Drop existing policies on public.profiles to avoid conflicts and ensure clean application
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
DROP POLICY IF EXISTS "Admins can update any profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can insert new profiles" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can view, Admins can view all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins can insert" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can update own, Admins can update all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins can delete" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
-- The following two were part of 0_create_profiles_table.sql and will be recreated with specific logic
-- DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles; -- Will be recreated
-- DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles; -- Will be recreated
-- Drop the specific policies that will be recreated to ensure a clean state
DROP POLICY IF EXISTS "Profiles: Users can view own, Admins/SuperAdmins can view all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins/SuperAdmins can insert any profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can update own, Admins/SuperAdmins can update any" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins/SuperAdmins can delete" ON public.profiles;


-- Helper function to get the current authenticated user's role (lowercase)
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER -- Changed from INVOKER to DEFINER
SET search_path = public -- Ensures the function can find public.profiles without schema qualification issues
AS $$
  SELECT lower(role) FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute on the helper function to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;


-- RLS Policies for public.profiles using the helper function

-- 1. SELECT Policy
CREATE POLICY "Profiles: Users can view own, Admins/SuperAdmins can view all"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
);

-- 2. INSERT Policies
-- Policy for users to insert their own profile (e.g., if not handled by a trigger or for initial setup)
-- This policy is crucial for the handle_new_user trigger as well if it runs as the user.
-- However, handle_new_user is SECURITY DEFINER, so it might bypass this.
-- But it's good for direct inserts by users.
CREATE POLICY "Profiles: Users can insert their own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = id
);

-- Policy for Admins/SuperAdmins to insert any profile
CREATE POLICY "Profiles: Admins/SuperAdmins can insert any profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
  public.get_current_user_role() IN ('admin', 'super_admin')
);

-- 3. UPDATE Policy
CREATE POLICY "Profiles: Users can update own, Admins/SuperAdmins can update any"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
)
WITH CHECK (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
);

-- 4. DELETE Policy (Restrict to Admins/SuperAdmins)
CREATE POLICY "Profiles: Admins/SuperAdmins can delete"
ON public.profiles
FOR DELETE
TO authenticated
USING (
  public.get_current_user_role() IN ('admin', 'super_admin')
);

-- Ensure RLS is enabled (it should be, but as a safeguard)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
</content>
