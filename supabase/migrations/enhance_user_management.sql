<content>/*
  # Enhance User Management

  This migration introduces a PL/pgSQL function to fetch comprehensive user details
  and updates RLS policies on the `profiles` table to grant administrators
  appropriate permissions for managing users.

  1.  **New Database Function**
      - `get_all_user_details()`:
        - Fetches `id`, `email`, `created_at` (from `auth.users`) and `username`,
          `full_name`, `avatar_url`, `status`, `role` (from `public.profiles`).
        - `SECURITY DEFINER` allows it to bypass RLS for internal table access.
        - Includes a role check to ensure only users with 'admin' or 'super_admin'
          role (as defined in their `profiles` entry) can execute this function.
        - Returns a table of user details.

  2.  **RLS Policy Updates for `public.profiles`**
      - **Admin Select All**: Modifies the existing select policy to allow users
        with 'admin' or 'super_admin' role to select all profiles. Users can
        still select their own profile.
      - **Admin Update**: Adds a new policy to allow users with 'admin' or
        'super_admin' role to update any profile. Users can still update their
        own profile (as per existing policy).
      - **Admin Insert**: Adds a new policy to allow users with 'admin' or
        'super_admin' role to insert new profiles.

  3.  **Important Notes**
      - The 'super_admin' role is included for future-proofing, assuming it might
        be introduced. The current `profiles.role` enum might need to be updated
        if 'super_admin' is a distinct, new role. For now, policies check for 'admin'.
      - The `get_all_user_details` function assumes `profiles.role` contains 'admin'.
        Adjust role names if they differ in your `profiles` table.
*/

-- Drop existing select policy to recreate it with admin access
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Enable read access for own user" ON public.profiles; -- Common alternative name
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles; -- if it was public
DROP POLICY IF EXISTS "Allow authenticated users to read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by users who created them." ON public.profiles;


-- Drop existing update policy to recreate it or ensure no conflict
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to update their own profile" ON public.profiles;

-- Drop existing insert policy if any restrictive one exists
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow authenticated users to insert their own profile" ON public.profiles;


-- Function to get all user details by joining auth.users and profiles
CREATE OR REPLACE FUNCTION get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text, -- Assuming status is stored as text, matching 'pending_approval', 'approved', 'rejected'
  role text -- Assuming role is stored as text, matching 'user', 'admin', 'moderator'
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  -- Get the role of the currently authenticated user from the profiles table
  SELECT p.role INTO caller_role FROM public.profiles p WHERE p.id = auth.uid();

  -- Check if the caller has admin privileges
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied. User does not have admin privileges.';
  END IF;

  -- Return query joining auth.users and profiles
  RETURN QUERY
  SELECT
    u.id,
    u.email,
    u.created_at,
    p.username,
    p.full_name,
    p.avatar_url,
    p.status,
    p.role
  FROM
    auth.users u
  LEFT JOIN
    public.profiles p ON u.id = p.id;
END;
$$;

-- RLS Policies for public.profiles

-- 1. Admin Select All / User Select Own
CREATE POLICY "Users can view profiles"
ON public.profiles
FOR SELECT
USING (
  (auth.uid() = id) OR
  ((SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin'))
);

-- 2. Admin Update Any / User Update Own
CREATE POLICY "Users can update profiles"
ON public.profiles
FOR UPDATE
USING (
  (auth.uid() = id) OR
  ((SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin'))
)
WITH CHECK (
  (auth.uid() = id) OR
  ((SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin'))
);

-- 3. Admin Insert Any
CREATE POLICY "Admins can insert new profiles"
ON public.profiles
FOR INSERT
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')
);

-- Ensure RLS is enabled (if not already)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Grant execute permission on the function to authenticated users
-- The function itself performs the role check.
GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;
</content>
