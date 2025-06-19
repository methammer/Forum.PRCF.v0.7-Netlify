<content>/*
  # Fix RLS Recursion on Profiles Table

  This migration addresses an "infinite recursion" error in the RLS policies
  for the `public.profiles` table. The recursion was caused by policies
  directly subquerying the `profiles` table to determine the current user's role.

  1.  **Dropped Policies**:
      - Drops all existing RLS policies on `public.profiles` to ensure a clean slate
        and prevent conflicts with the new policies. This includes:
        - `"Users can view profiles"`
        - `"Users can update profiles"`
        - `"Admins can insert new profiles"`
        - Any other policies that might have been created previously (e.g., "Public profiles are viewable by everyone.", "Users can insert their own profile").

  2.  **New Helper Function**:
      - `public.get_current_user_role()`:
        - Safely retrieves the `role` of the currently authenticated user (`auth.uid()`)
          from the `public.profiles` table.
        - `SECURITY INVOKER` is used as it only needs to read the calling user's own profile data.
        - Returns the role as `text`.

  3.  **New RLS Policies for `public.profiles`**:
      - **Select Policy (`"Profiles: Users can view, Admins can view all"`)**:
        - Allows users to select their own profile (`auth.uid() = id`).
        - Allows users whose role is 'admin' (as determined by `get_current_user_role()`)
          to select all profiles.
      - **Insert Policy (`"Profiles: Admins can insert"`)**:
        - Allows users whose role is 'admin' to insert new profiles.
        - (Note: Standard user profile creation upon signup is typically handled by a trigger
          on `auth.users` or a dedicated signup function, not direct RLS-gated inserts by the user themselves,
          unless a specific policy for `auth.uid() = id` on insert is added.)
      - **Update Policy (`"Profiles: Users can update own, Admins can update all"`)**:
        - Allows users to update their own profile.
        - Allows users whose role is 'admin' to update any profile.
      - **Delete Policy (`"Profiles: Admins can delete"`)**:
        - Allows users whose role is 'admin' to delete profiles.
        - (Note: Deleting users should also handle their `auth.users` entry, typically via an Edge Function).

  4.  **RLS Enablement**:
      - Ensures Row Level Security is enabled on `public.profiles`.

  5.  **Function Grant**:
      - Grants `EXECUTE` permission on `public.get_current_user_role()` to `authenticated` users.
*/

-- Drop existing policies on public.profiles to avoid conflicts and ensure clean application
-- It's safer to drop specific known policies first, then any others if necessary.
DROP POLICY IF EXISTS "Users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can insert new profiles" ON public.profiles;
-- Drop policies from previous attempts or common names if they might exist
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Enable read access for own user" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by users who created them." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles; -- If a delete policy existed


-- Helper function to get the current authenticated user's role
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute on the helper function to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;


-- RLS Policies for public.profiles using the helper function

-- 1. SELECT Policy
CREATE POLICY "Profiles: Users can view, Admins can view all"
ON public.profiles
FOR SELECT
USING (
  (auth.uid() = id) OR (public.get_current_user_role() = 'admin')
);

-- 2. INSERT Policy (Primarily for Admins, user self-creation often via trigger/function)
CREATE POLICY "Profiles: Admins can insert"
ON public.profiles
FOR INSERT
WITH CHECK (
  public.get_current_user_role() = 'admin'
);

-- Add a policy for users to insert their own profile if not handled by a trigger
-- This assumes a user's profile is created after their auth.users entry.
-- If a trigger on auth.users handles profile creation, this might not be strictly necessary
-- or could be more restrictive (e.g., only if no profile exists yet).
CREATE POLICY "Profiles: Users can insert their own profile"
ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);


-- 3. UPDATE Policy
CREATE POLICY "Profiles: Users can update own, Admins can update all"
ON public.profiles
FOR UPDATE
USING (
  (auth.uid() = id) OR (public.get_current_user_role() = 'admin')
)
WITH CHECK (
  (auth.uid() = id) OR (public.get_current_user_role() = 'admin')
);

-- 4. DELETE Policy (Restrict to Admins)
-- Be cautious with delete. Consider soft deletes or ensuring auth.users is also handled.
CREATE POLICY "Profiles: Admins can delete"
ON public.profiles
FOR DELETE
USING (
  public.get_current_user_role() = 'admin'
);

-- Ensure RLS is enabled (it should be, but as a safeguard)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
</content>
