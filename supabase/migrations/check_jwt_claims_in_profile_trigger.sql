/*
  # Check JWT Claims in Profile Update Trigger

  This migration updates the `public.prevent_profile_id_role_change` trigger function.

  ## Changes:
  1.  **`public.prevent_profile_id_role_change()` function**:
      - Modified to inspect `current_setting('request.jwt.claims', true)` to determine if the operation is performed by the `service_role`.
      - It parses the JWT claims and checks if `claims->>'role'` is `'service_role'`.
      - Enhanced `RAISE NOTICE` and exception messages to include:
        - `session_user` (initial connection role, e.g., 'authenticator')
        - `current_setting('request.is_service_role', true)` (PostgREST GUC, often 'NOT_SET' in trigger)
        - `claimed_role_from_jwt` (role extracted from `request.jwt.claims`)
        - `current_user` (owner of the SECURITY DEFINER function, e.g., 'postgres' or 'supabase_admin')
        - `pg_catalog.current_setting('role', true)` (active PostgreSQL role for the session)
      - The prohibition on changing the `id` column remains.
      - The function remains `SECURITY DEFINER`.

  ## Reason:
  Previous checks using `current_setting('request.is_service_role', true)` or `session_user` were not effective because within a `SECURITY DEFINER` trigger, `session_user` is often 'authenticator' and `request.is_service_role` can be 'NOT_SET'. Directly checking the JWT claims provides a more reliable way to identify service role operations.
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
  claimed_role text;
  active_pg_role text;
  func_owner text;
BEGIN
  -- Debugging information
  current_session_user := session_user; -- Initial role used by PostgREST to connect (e.g., 'authenticator')
  func_owner := current_user; -- Role that owns this function (e.g., 'postgres', 'supabase_admin')
  active_pg_role := pg_catalog.current_setting('role', true); -- Active role for the current session (e.g., 'authenticated', 'postgres')
  is_service_role_setting := COALESCE(current_setting('request.is_service_role', true), 'NOT_SET'); -- GUC set by PostgREST
  jwt_claims_text := current_setting('request.jwt.claims', true); -- Raw JWT claims from PostgREST

  IF jwt_claims_text IS NOT NULL THEN
    BEGIN
      jwt_claims := jwt_claims_text::jsonb;
      claimed_role := jwt_claims->>'role'; -- Extract 'role' from JWT
    EXCEPTION WHEN OTHERS THEN
      claimed_role := 'ERROR_PARSING_JWT';
      RAISE NOTICE '[prevent_profile_id_role_change_trigger] Warning: Could not parse JWT claims. Text: %', jwt_claims_text;
    END;
  ELSE
    claimed_role := 'JWT_CLAIMS_NOT_SET';
  END IF;

  RAISE NOTICE '[prevent_profile_id_role_change_trigger] Debug Context: session_user="%", func_owner="%", active_pg_role="%", request.is_service_role="%", claimed_jwt_role="%"',
    current_session_user,
    func_owner,
    COALESCE(active_pg_role, 'NULL'),
    is_service_role_setting,
    COALESCE(claimed_role, 'NULL');

  -- Prevent ID change always
  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;

  -- Role change logic
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    -- Allow change IF the role in JWT claims is 'service_role'.
    IF claimed_role <> 'service_role' THEN
      RAISE EXCEPTION 'Changing the profile role directly is not allowed unless performed by service_role. (Debug Context: session_user="%", func_owner="%", active_pg_role="%", request.is_service_role="%", claimed_jwt_role="%")',
        current_session_user,
        func_owner,
        COALESCE(active_pg_role, 'NULL'),
        is_service_role_setting,
        COALESCE(claimed_role, 'NULL_OR_NOT_FOUND');
    END IF;
    -- If claimed_role IS 'service_role', the change is allowed.
  END IF;

  RETURN NEW;
END;
$$;
