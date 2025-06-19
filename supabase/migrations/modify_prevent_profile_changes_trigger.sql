/*
  # Modify Profile Changes Trigger and RLS Policy

  This migration makes two key changes:

  1.  **Trigger Modification (`prevent_profile_id_role_change`)**:
      - The trigger function `public.prevent_profile_id_role_change` is updated.
      - It will now ONLY prevent changes to the `id` column of a profile.
      - The restriction that prevented direct changes to the `role` column has been REMOVED.
      - This allows the `update-user-details-admin` Edge Function (which uses a service role)
        to modify user roles as intended, as its RBAC is the primary control for such operations.

  2.  **RLS Policy Update (`Profiles: Users can update their own profile`)**:
      - The RLS policy named `"Profiles: Users can update their own profile"` on the `public.profiles` table is updated.
      - A `WITH CHECK` condition is added: `(new.role = old.role AND new.status = old.status)`.
      - This ensures that authenticated users, while able to update other parts of their own profile
        (like `full_name` or `username`), CANNOT change their own `role` or `status` directly via SQL.
      - Changes to `role` and `status` must go through administrative Edge Functions.

  These changes work together to:
  - Enable administrators (via Edge Functions) to manage user roles and statuses.
  - Prevent users from illicitly modifying their own `role` or `status`.
  - Continue to prevent any modification of a profile's `id`.
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
  -- The following lines that prevented role changes have been removed:
  -- IF NEW.role IS DISTINCT FROM OLD.role THEN
  --   RAISE EXCEPTION 'Changing the profile role directly is not allowed. Role changes must be performed by an administrator.';
  -- END IF;
  RETURN NEW;
END;
$$;

-- The trigger itself (before_profile_update_prevent_id_role_change) does not need to be recreated
-- as it already calls the updated function.

-- 2. Update RLS policy for self-updates to prevent role/status changes by user

-- Drop the existing policy to recreate it with the new check
DROP POLICY IF EXISTS "Profiles: Users can update their own profile" ON public.profiles;

-- Recreate the policy with the added check for role and status
CREATE POLICY "Profiles: Users can update their own profile"
ON public.profiles FOR UPDATE TO authenticated USING (
  auth.uid() = profiles.id
) WITH CHECK (
  auth.uid() = profiles.id AND
  NEW.role = OLD.role AND -- Prevent user from changing their own role
  NEW.status = OLD.status -- Prevent user from changing their own status
);

/*
  Verification Note:
  - After this migration, the `update-user-details-admin` Edge Function should be able to
    successfully update user roles.
  - Authenticated users attempting to update their own `role` or `status` via a direct SQL
    command (if they could issue one) should be blocked by the updated RLS policy.
*/
