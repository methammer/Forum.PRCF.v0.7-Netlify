/*
  # Refine Profile Update Trigger and RLS Policy

  This migration addresses issues with preventing users from changing their own
  roles/statuses while allowing admin functions (using service_role_key) to do so.
  The previous attempt to use NEW/OLD in RLS WITH CHECK clause was incorrect.

  Changes:
  1.  **Trigger `before_profile_update_prevent_id_role_change` (Dropped)**:
      - This trigger, which depended on `public.prevent_profile_id_role_change`, is dropped first.
  2.  **Trigger Function `public.prevent_profile_id_role_change` (Dropped)**:
      - This old trigger function is dropped.
  3.  **Trigger Function `public.handle_profile_update_restrictions` (New)**:
      - Replaces `public.prevent_profile_id_role_change`.
      - Always prevents changes to the `id` column.
      - Checks `current_user`:
        - If `current_user` is NOT the service role (e.g., `supabase_admin`, `postgres`),
          it prevents changes to `role` and `status` columns by the user.
        - If `current_user` IS the service role, changes to `role` and `status` are permitted
          (allowing Edge Functions like `update-user-details-admin` to work).
  4.  **Trigger `before_profile_update_handle_restrictions` (New)**:
      - Uses the new `public.handle_profile_update_restrictions` function.
  5.  **RLS Policy Update (`"Users can update own profile (row access)."` -> `"Profiles: Users can update their own profile"`)**:
      - The RLS policy allowing users to update their own profiles is clarified.
      - `USING (auth.uid() = profiles.id)`: Ensures users can only target their own profile row.
      - `WITH CHECK (auth.uid() = profiles.id)`: A simple check, as the trigger now handles
        complex field-level restrictions (role/status changes).

  This approach ensures:
  - Admins (via Edge Functions) can manage user roles and statuses.
  - Users cannot illicitly modify their own `role` or `status`.
  - Profile `id` modification remains prohibited.
*/

-- 1. Drop the old trigger and then its function
DROP TRIGGER IF EXISTS before_profile_update_prevent_id_role_change ON public.profiles;
DROP TRIGGER IF EXISTS before_profile_update_prevent_modifications ON public.profiles; -- old name from previous attempt if any
DROP TRIGGER IF EXISTS before_profile_update_handle_restrictions ON public.profiles; -- ensure clean slate for new trigger

DROP FUNCTION IF EXISTS public.prevent_profile_id_role_change(); -- From add_role_and_trigger_for_profile_updates_v20.sql

-- 2. Create the new trigger function
CREATE OR REPLACE FUNCTION public.handle_profile_update_restrictions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- Essential for consistent behavior and access to current_user
AS $$
DECLARE
  is_service_role_user BOOLEAN;
BEGIN
  -- Rule 1: Profile ID can NEVER be changed by anyone.
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Profile ID cannot be changed.';
  END IF;

  -- Determine if the current operation is performed by a service role.
  -- In Supabase, the service role typically operates as 'supabase_admin' or 'postgres'.
  is_service_role_user := (current_user = 'supabase_admin' OR current_user = 'postgres');

  -- Rule 2: Prevent self-service role or status changes unless by service role.
  IF NOT is_service_role_user THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'Your role cannot be changed directly. Please contact an administrator.';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'Your status cannot be changed directly. Please contact an administrator.';
    END IF;
  END IF;
  -- If is_service_role_user is true, the above IF block is skipped, allowing the service role
  -- (used by Edge Functions like update-user-details-admin) to change role and status.

  RETURN NEW;
END;
$$;

-- 3. Create the new trigger that uses the new function
CREATE TRIGGER before_profile_update_handle_restrictions
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_profile_update_restrictions();

-- 4. Update RLS policy for users updating their own profiles

-- Drop existing policies that might conflict or are being replaced.
-- The one from `add_role_and_trigger_for_profile_updates_v20.sql` was "Users can update own profile (row access)."
-- The one from `modify_prevent_profile_changes_trigger.sql` (which failed) was "Profiles: Users can update their own profile"
DROP POLICY IF EXISTS "Users can update own profile (row access)." ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can update their own profile" ON public.profiles;


-- Recreate the policy for authenticated users to update their own profiles.
-- The trigger now handles the detailed field-level restrictions.
CREATE POLICY "Profiles: Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated USING (
  auth.uid() = profiles.id -- User can only attempt to update their own row
) WITH CHECK (
  auth.uid() = profiles.id -- The new data must still pertain to their own row.
);

/*
  Verification Note:
  - After this migration, the `update-user-details-admin` Edge Function (using service_role_key)
    should be able to update user roles and statuses.
  - Authenticated users attempting to update their own `role` or `status` via a direct SQL
    command (or through a UI that allows arbitrary profile field updates) should be
    blocked by the `handle_profile_update_restrictions` trigger.
  - Authenticated users should still be able to update other fields like `full_name` or `username`
    on their own profile.
*/
