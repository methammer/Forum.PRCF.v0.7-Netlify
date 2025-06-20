/*
  # Refine Profile Update Permissions and RLS

  This migration ensures that the database schema correctly handles profile updates,
  specifically concerning role and status modifications.

  ## Key Changes:

  1.  **Trigger Modification (`public.prevent_profile_id_role_change`)**:
      - The trigger function `public.prevent_profile_id_role_change` is explicitly defined
        to ONLY prevent changes to the `id` column of a profile.
      - Any restrictions that previously prevented direct changes to the `role` column
        within this trigger are REMOVED.
      - This is critical to allow the `update-user-details-admin` Edge Function (which uses
        a service role key) to modify user roles as intended. The Edge Function itself
        contains the necessary role-based access control (RBAC) for such operations.

  2.  **RLS Policy Update (`Profiles: Users can update their own profile`)**:
      - The Row Level Security (RLS) policy named `"Profiles: Users can update their own profile"`
        on the `public.profiles` table is updated (or created if it doesn't exist).
      - A `WITH CHECK` condition is enforced: `(new.role = old.role AND new.status = old.status)`.
      - This ensures that authenticated users, while able to update other parts of their own profile
        (like `full_name` or `username`), CANNOT change their own `role` or `status` directly
        via SQL. Changes to `role` and `status` for any user must go through administrative
        Edge Functions or controlled processes.

  ## Rationale:
  These changes work together to:
  - Empower administrators (via Edge Functions using the service role) to manage user roles and statuses without being blocked by an overly restrictive trigger.
  - Prevent regular users from illicitly modifying their own `role` or `status` through direct profile updates, by enforcing this at the RLS level.
  - Maintain the integrity of the profile `id` by continuing to prevent its modification via the trigger.

  This setup centralizes the control of sensitive fields like `role` and `status` to administrative functions, while allowing users appropriate control over less sensitive parts of their own profiles.
*/

-- 1. Modify the trigger function to only prevent id changes
CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;
  -- Explicitly ensure no role change prevention is in this trigger.
  -- Role changes are managed by application logic (Edge Functions) and RLS.
  RETURN NEW;
END;
$$;

-- Ensure the trigger is on the table and uses the updated function.
-- Dropping and recreating is safer if the function signature or trigger definition changed.
DROP TRIGGER IF EXISTS before_profile_update_prevent_id_role_change ON public.profiles;
CREATE TRIGGER before_profile_update_prevent_id_role_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_profile_id_role_change();

-- 2. Update RLS policy for self-updates to prevent role/status changes by user

-- Ensure RLS is enabled on the table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop the existing policy to recreate it with the precise check conditions
DROP POLICY IF EXISTS "Profiles: Users can update their own profile" ON public.profiles;

-- Recreate the policy with the added check for role and status
CREATE POLICY "Profiles: Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated USING (
  auth.uid() = profiles.id -- User can only attempt to update their own row
) WITH CHECK (
  auth.uid() = profiles.id AND -- Re-affirm for the check
  NEW.role = OLD.role AND -- Prevent user from changing their own role
  NEW.status = OLD.status -- Prevent user from changing their own status
);

/*
  Verification Notes:
  - After this migration, the `update-user-details-admin` Edge Function (using service_role_key)
    should be able to successfully update user roles and statuses.
  - Authenticated users attempting to update their own `role` or `status` via a direct SQL
    update (e.g., through a compromised client or if they had direct DB access with their user role)
    should be blocked by the updated RLS policy's `WITH CHECK` clause.
  - Changes to `full_name`, `username`, `avatar_url` etc., by users on their own profiles should still be allowed
    (assuming no other RLS policies or triggers prevent them for those specific fields).
*/
