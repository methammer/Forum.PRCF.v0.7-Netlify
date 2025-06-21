/*
  # Create and Verify is_user_approved Helper Function

  This migration introduces the `public.is_user_approved()` helper function
  and includes a verification step to confirm its creation by querying pg_catalog.

  Changes:
  1.  **`public.is_user_approved()` Helper Function**:
      - Drops the function if it already exists to ensure a clean state.
      - Creates a new SQL function `is_user_approved()`.
      - This function returns `true` if the currently authenticated user has a profile
        with `status = 'approved'`, and `false` otherwise.
  2.  **Permissions**:
      - Grants `EXECUTE` permission on this function to `authenticated` users.
  3.  **Verification**:
      - Queries `pg_catalog.pg_proc` to check for the existence and details of
        the `public.is_user_approved` function.
*/
RAISE NOTICE 'Attempting to create public.is_user_approved function...';
SET search_path = public, auth;

-- Ensure the function is dropped first to handle any problematic existing state
DROP FUNCTION IF EXISTS public.is_user_approved();

CREATE OR REPLACE FUNCTION public.is_user_approved()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER -- Checks the status of the user calling the function
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND status = 'approved'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_user_approved() TO authenticated;
RAISE NOTICE 'public.is_user_approved function creation attempted and permissions granted.';

-- Verification Step: Check pg_catalog.pg_proc for the function
RAISE NOTICE 'Verifying function creation by querying pg_catalog.pg_proc...';
SELECT
  p.proname AS function_name,
  n.nspname AS schema_name,
  pg_catalog.pg_get_function_result(p.oid) AS result_type,
  pg_catalog.pg_get_function_arguments(p.oid) AS arguments,
  CASE p.prosecdef
    WHEN true THEN 'SECURITY DEFINER'
    ELSE 'SECURITY INVOKER'
  END AS security_type,
  u.usename AS owner_name
FROM
  pg_catalog.pg_proc p
JOIN
  pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN
  pg_catalog.pg_user u ON u.usesysid = p.proowner  -- Using pg_user for owner name
WHERE
  n.nspname = 'public' AND p.proname = 'is_user_approved';

RAISE NOTICE 'Function verification query executed.';
