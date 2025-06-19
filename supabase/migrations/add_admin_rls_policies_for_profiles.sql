<content>/*
  # Add Admin RLS Policies for Profiles Table

  This migration adds Row Level Security (RLS) policies to the `public.profiles`
  table to grant administrators ('admin' or 'SUPER_ADMIN' roles) appropriate
  permissions for managing user profiles.

  ## New Policies:
  1.  **"Admins can read all profiles."**
      -   **Operation**: `SELECT`
      -   **Applies to**: Authenticated users.
      -   **Condition (`USING`)**: Allows access if the current user's role (fetched from their own profile in `public.profiles` via `auth.uid()`) is 'admin' or 'SUPER_ADMIN'.
      -   **Purpose**: Enables admins to view all user profiles in the system, necessary for user management interfaces.

  2.  **"Admins can update any profile."**
      -   **Operation**: `UPDATE`
      -   **Applies to**: Authenticated users.
      -   **Condition (`USING`)**: Allows the update operation on any row if the current user's role is 'admin' or 'SUPER_ADMIN'.
      -   **Check (`WITH CHECK`)**: Ensures that the user performing the update is indeed an 'admin' or 'SUPER_ADMIN'. This is somewhat redundant given the `USING` clause for updates but reinforces the intent.
      -   **Purpose**: Enables admins to modify user profiles (e.g., change roles, status, full name). Specific field restrictions (like preventing `id` changes or non-admin role changes) are handled by the `prevent_profile_id_role_change` trigger.

  ## Important Notes:
  - These policies are additive to existing user-specific policies (e.g., "Users can view their own profile.", "Users can update own profile (row access).").
  - RLS is permissive: if any policy grants access for an operation, it is allowed.
  - The `public.get_all_user_details()` RPC function is `SECURITY DEFINER`, so it bypasses RLS for its internal queries when fetching the user list. These RLS policies primarily affect direct table access (e.g., updates from the client).
*/

-- Ensure RLS is enabled (idempotent)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can read all profiles
-- Drop if exists to ensure the latest version is applied
DROP POLICY IF EXISTS "Admins can read all profiles." ON public.profiles;
CREATE POLICY "Admins can read all profiles."
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'SUPER_ADMIN')
  );

-- Policy: Admins can update any profile
-- Drop if exists to ensure the latest version is applied
DROP POLICY IF EXISTS "Admins can update any profile." ON public.profiles;
CREATE POLICY "Admins can update any profile."
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'SUPER_ADMIN')
  )
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'SUPER_ADMIN')
  );</content>
