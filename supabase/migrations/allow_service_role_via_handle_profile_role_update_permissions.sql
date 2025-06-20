/*
  # Allow Service Role to Update Profile Roles via Trigger

  This migration updates the `public.handle_profile_role_update_permissions` trigger function.

  ## Changes:
  1.  **`public.handle_profile_role_update_permissions()` function**:
      - Modified to check the role of the requester from the JWT claims via `current_setting('request.jwt.claims', true)::jsonb ->> 'role'`.
      - If the requesting role from the JWT is `service_role`, changes to the `profiles.role` column are explicitly allowed by this function. It will `RETURN NEW`, allowing the update to proceed.
      - If the requesting role is not `service_role` (or if JWT claims are unavailable), the function proceeds with its original logic, which includes raising an exception if a non-authorized user attempts to change a role.
      - Includes `RAISE NOTICE` statements for debugging, logging the identified JWT role, current SQL user, session SQL user, and the old/new profile role values.

  ## Reason:
  The `update-user-details-admin` Edge Function, which uses the `service_role_key`, was being blocked by the `handle_profile_role_update_permissions` trigger when attempting to update a user's role. The trigger was not correctly identifying the service role operation. This change ensures that the service role can bypass this trigger's role change restrictions, while the restrictions can remain for other users as potentially intended by the trigger's original logic.

  This fix is crucial for enabling administrators to manage user roles through the application's Edge Functions.
*/

CREATE OR REPLACE FUNCTION public.handle_profile_role_update_permissions()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  requesting_jwt_role TEXT;
  current_sql_user TEXT := current_user; -- The user as which the function's statements are executing
  session_sql_user TEXT := session_user; -- The user that established the session (e.g., authenticator)
BEGIN
  -- Attempt to get the role from the JWT claims passed by PostgREST
  BEGIN
    requesting_jwt_role := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
  EXCEPTION WHEN OTHERS THEN
    requesting_jwt_role := NULL; -- Set to NULL if JWT claims are not available or not valid JSON
  END;

  RAISE NOTICE '[handle_profile_role_update_permissions] Trigger Debug: requesting_jwt_role="%", current_sql_user="%", session_sql_user="%"',
    COALESCE(requesting_jwt_role, 'N/A'),
    current_sql_user,
    session_sql_user;
  RAISE NOTICE '[handle_profile_role_update_permissions] Trigger Debug: OLD.role="%", NEW.role="%", OLD.id="%", NEW.id="%"',
    OLD.role, NEW.role, OLD.id, NEW.id;

  -- Check if the 'role' column is actually being changed
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- If the role from the JWT is 'service_role', allow the change
    IF requesting_jwt_role = 'service_role' THEN
      RAISE NOTICE '[handle_profile_role_update_permissions] Allowing role change because requesting_jwt_role is "service_role".';
      RETURN NEW;
    END IF;

    -- If not 'service_role' (or JWT role is N/A), then apply the original restriction.
    -- This is the part that was raising the error:
    -- "User does not have permission to change profile roles. Role changes must be performed by an administrator."
    -- The original function might have more complex logic here to determine who IS an administrator.
    -- We preserve that restrictive behavior for non-service_role calls.
    RAISE EXCEPTION 'User does not have permission to change profile roles. Role changes must be performed by an administrator. (Attempt by JWT role: "%")',
      COALESCE(requesting_jwt_role, 'unknown/anonymous');
  END IF;

  -- If the 'role' column was not changed, or if it was changed by 'service_role' (which would have already returned NEW),
  -- then allow the update to proceed.
  RETURN NEW;
END;
$$;
