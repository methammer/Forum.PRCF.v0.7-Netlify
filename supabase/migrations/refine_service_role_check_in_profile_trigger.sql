/*
  # Refine Service Role Check in Profile Update Trigger

  This migration updates the `public.prevent_profile_id_role_change` trigger function.

  ## Changes:
  1.  **`public.prevent_profile_id_role_change()` function**:
      - Modified to check `session_user = 'service_role'` instead of `current_setting('request.is_service_role', true)` to determine if the operation is performed by the service role.
      - Added `RAISE NOTICE` to log the values of `session_user` and `current_setting('request.is_service_role', true)` for debugging purposes (visible in PostgreSQL logs).
      - If the exception is still raised, the logged values will also be part of the exception message.
      - The prohibition on changing the `id` column remains.
      - The function remains `SECURITY DEFINER`.

  ## Reason:
  The previous check using `current_setting('request.is_service_role', true)` was not effective in allowing the Edge Function (using `service_role_key`) to update profile roles. This change attempts a more direct check of the session user's role.
*/

CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_service_role_setting text;
  current_session_user text;
BEGIN
  -- For debugging: These notices will appear in your PostgreSQL logs.
  is_service_role_setting := COALESCE(current_setting('request.is_service_role', true), 'NOT_SET');
  current_session_user := session_user; -- This is the user of the current SQL session context.
  RAISE NOTICE '[prevent_profile_id_role_change_trigger] Debug: session_user=%, request.is_service_role=%', current_session_user, is_service_role_setting;

  -- Prevent ID change always
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;

  -- Role change logic
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- Allow change IF the session_user is 'service_role'.
    -- This indicates the request is coming from an authenticated service_role JWT.
    IF current_session_user <> 'service_role' THEN
      RAISE EXCEPTION 'Changing the profile role directly by a user is not allowed. Role changes must be performed by an administrative process or service function. (Debug Info: session_user="%", request.is_service_role="%")', current_session_user, is_service_role_setting;
    END IF;
    -- If it IS the service_role, the change is allowed.
  END IF;

  RETURN NEW;
END;
$$;

-- The trigger itself ('before_profile_update_prevent_id_role_change' on public.profiles)
-- does not need to be recreated or altered as it already calls the
-- public.prevent_profile_id_role_change() function, which we have just updated.
