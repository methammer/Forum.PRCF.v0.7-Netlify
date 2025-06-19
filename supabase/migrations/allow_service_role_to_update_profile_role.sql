/*
  # Modify Profile Update Trigger to Allow Service Role

  This migration updates the `public.prevent_profile_id_role_change` trigger function.

  ## Changes:
  1.  **`public.prevent_profile_id_role_change()` function**:
      - Modified to allow changes to the `role` column if the current request is identified as a service role call (`current_setting('request.is_service_role', true) = 'true'`).
      - If the call is not from a service role, attempts to change the `role` will still be blocked with an exception.
      - The prohibition on changing the `id` column remains.
      - The function remains `SECURITY DEFINER`.

  ## Reason:
  The `create-user-admin` Edge Function, which uses the `service_role_key`, was being blocked by this trigger when attempting to set the initial role for a newly created user's profile. This change allows the Edge Function (and other service role operations) to manage profile roles while still preventing direct role manipulation by regular users.
*/

CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- Stays as SECURITY DEFINER, as it needs to operate consistently.
AS $$
BEGIN
  -- Prevent ID change always
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;

  -- Role change logic
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- Allow change IF it's the service_role making the change.
    -- Otherwise, raise an exception.
    -- COALESCE is used to default to 'false' if the setting is somehow not available,
    -- ensuring restrictive behavior by default.
    IF COALESCE(current_setting('request.is_service_role', true), 'false') <> 'true' THEN
      RAISE EXCEPTION 'Changing the profile role directly by a user is not allowed. Role changes must be performed by an administrative process or service function.';
    END IF;
    -- If it IS the service_role, the change is allowed, and the function will proceed to RETURN NEW.
  END IF;

  RETURN NEW;
END;
$$;

-- The trigger itself ('before_profile_update_prevent_id_role_change' on public.profiles)
-- does not need to be recreated or altered as it already calls the
-- public.prevent_profile_id_role_change() function, which we have just updated.
