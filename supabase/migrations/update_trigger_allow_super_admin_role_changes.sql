<content>/*
  # Update Trigger to Allow SUPER_ADMIN Role Changes

  This migration updates the `public.prevent_profile_id_role_change` trigger function.

  ## Changes:
  1.  **`public.prevent_profile_id_role_change()` function**:
      - Continues to allow `service_role` (identified via JWT claims) to change profile roles.
      - **MODIFIED**: Now allows users who have the 'admin' OR 'SUPER_ADMIN' role in their `public.profiles` record to change other users' roles.
        - It fetches the role of the acting user ( `auth.uid()` ) from `public.profiles`.
        - If this role is 'admin' or 'SUPER_ADMIN', the role change is permitted.
      - The prohibition on changing the `id` column remains.
      - Enhanced `RAISE NOTICE` and exception messages to include `actor_profile_role`.

  ## Reason:
  The previous version of the trigger only allowed 'admin' (besides service_role) to change roles. This prevented client-side SUPER_ADMIN users from directly managing user roles. This change enables that functionality.
*/

CREATE OR REPLACE FUNCTION public.prevent_profile_id_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_service_role_setting text;
  current_session_user text;
  jwt_claims_text text;
  jwt_claims jsonb;
  claimed_role_from_jwt text;
  active_pg_role text;
  func_owner text;
  actor_profile_role text; -- Role of the user performing the action, from their profile
BEGIN
  -- Debugging information
  current_session_user := session_user;
  func_owner := current_user;
  active_pg_role := pg_catalog.current_setting('role', true);
  is_service_role_setting := COALESCE(current_setting('request.is_service_role', true), 'NOT_SET');
  jwt_claims_text := current_setting('request.jwt.claims', true);

  IF jwt_claims_text IS NOT NULL THEN
    BEGIN
      jwt_claims := jwt_claims_text::jsonb;
      claimed_role_from_jwt := jwt_claims->>'role';
    EXCEPTION WHEN OTHERS THEN
      claimed_role_from_jwt := 'ERROR_PARSING_JWT';
      RAISE NOTICE '[prevent_profile_id_role_change_trigger] Warning: Could not parse JWT claims. Text: %', jwt_claims_text;
    END;
  ELSE
    claimed_role_from_jwt := 'JWT_CLAIMS_NOT_SET';
  END IF;

  -- Get the profile role of the user performing theaction (auth.uid())
  BEGIN
    SELECT "role" INTO actor_profile_role FROM public.profiles WHERE id = auth.uid();
  EXCEPTION WHEN NO_DATA_FOUND THEN
    actor_profile_role := 'NO_PROFILE_FOR_UID';
  END;

  RAISE NOTICE '[prevent_profile_id_role_change_trigger] Debug Context: session_user="%", func_owner="%", active_pg_role="%", request.is_service_role="%", claimed_jwt_role="%", actor_profile_role="%"',
    current_session_user,
    func_owner,
    COALESCE(active_pg_role, 'NULL'),
    is_service_role_setting,
    COALESCE(claimed_role_from_jwt, 'NULL'),
    COALESCE(actor_profile_role, 'NULL');

  -- Prevent ID change always
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;

  -- Role change logic
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- Allow if JWT indicates service_role
    IF claimed_role_from_jwt = 'service_role' THEN
      RAISE NOTICE '[prevent_profile_id_role_change_trigger] Role change allowed for service_role.';
      RETURN NEW;
    END IF;

    -- Allow if the acting user (auth.uid()) has 'admin' or 'SUPER_ADMIN' role in their profile
    IF actor_profile_role IN ('admin', 'SUPER_ADMIN') THEN
      RAISE NOTICE '[prevent_profile_id_role_change_trigger] Role change allowed for actor_profile_role: %', actor_profile_role;
      RETURN NEW;
    END IF;

    -- If none of the above conditions are met, disallow the role change
    RAISE EXCEPTION 'Changing the profile role is only allowed for administrators (admin, SUPER_ADMIN) or service roles. Your role: %.',
      COALESCE(actor_profile_role, 'NOT_FOUND_OR_NOT_ADMIN');
  END IF;

  RETURN NEW;
END;
$$;</content>
