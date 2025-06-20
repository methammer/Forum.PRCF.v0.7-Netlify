/*
  # Update Role Functions to Use TEXT Type

  This migration addresses the "return type mismatch" error for `get_all_user_details`
  and `get_current_user_role` functions. This error occurred after the
  `public.profiles.role` column was converted from an enum type to TEXT.

  PostgreSQL's `CREATE OR REPLACE FUNCTION` cannot change a function's return type
  if the change is fundamental (e.g., from an enum to TEXT). Therefore, the functions
  must be dropped and then recreated with the correct TEXT return types.

  Changes:
  1.  **Drop Existing Functions**:
      - `public.get_all_user_details()` is dropped (if it exists). This function depends
        on `get_current_user_role`, so it's dropped first.
      - `public.get_current_user_role()` is dropped (if it exists).

  2.  **Recreate `public.get_current_user_role()`**:
      - Defined to `RETURNS TEXT`.
      - Selects `role` directly from `public.profiles`. Since `profiles.role` is now
        stored as uppercase TEXT (e.g., 'ADMIN', 'USER'), this function will return
        the role in that format.
      - Remains `STABLE` and `SECURITY INVOKER`.

  3.  **Recreate `public.get_all_user_details()`**:
      - The `RETURNS TABLE` definition is updated to specify `role TEXT`.
      - The internal variable `caller_role` is declared as `TEXT`.
      - The role check now compares `caller_role` (which will be uppercase TEXT from
        `get_current_user_role`) with `'ADMIN'` and `'SUPER_ADMIN'`.
      - Selects `p.role` (which is TEXT) from `public.profiles`.
      - Remains `SECURITY DEFINER`.

  4.  **Grant Permissions**:
      - `EXECUTE` permissions are re-granted to the `authenticated` role for both functions.
*/

-- Drop dependent function first if they exist
DROP FUNCTION IF EXISTS public.get_all_user_details();
DROP FUNCTION IF EXISTS public.get_current_user_role();

-- Recreate get_current_user_role to return TEXT
CREATE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public -- Ensures the function can find public.profiles
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

-- Recreate get_all_user_details ensuring its role column and internal logic use TEXT
CREATE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text,
  role text -- Explicitly TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Ensures the function can find public.profiles and public.get_current_user_role
AS $$
DECLARE
  caller_role text; -- Variable to store the role, typed as TEXT
BEGIN
  -- Get the role of the currently authenticated user.
  -- public.get_current_user_role() now returns TEXT.
  caller_role := public.get_current_user_role();

  -- Check if the caller has admin privileges.
  -- Roles in profiles.role are stored as uppercase TEXT (e.g., 'ADMIN', 'SUPER_ADMIN').
  IF caller_role IS NULL OR caller_role NOT IN ('ADMIN', 'SUPER_ADMIN') THEN
    RAISE EXCEPTION 'Permission denied. User requires ADMIN or SUPER_ADMIN role. Found: %', COALESCE(caller_role, 'NULL');
  END IF;

  -- Return query joining auth.users and public.profiles
  -- All selected columns from profiles are already TEXT or compatible.
  RETURN QUERY
  SELECT
    u.id,
    u.email,
    u.created_at,
    p.username,
    p.full_name,
    p.avatar_url,
    p.status,
    p.role
  FROM
    auth.users u
  LEFT JOIN
    public.profiles p ON u.id = p.id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;
