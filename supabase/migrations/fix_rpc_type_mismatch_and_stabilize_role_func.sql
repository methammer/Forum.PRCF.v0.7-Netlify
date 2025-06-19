<content>/*
  # Fix RPC Type Mismatch and Stabilize Helper Function

  This migration addresses two issues:

  1.  **`get_all_user_details` RPC Type Mismatch (Error 42804)**:
      - The error "Returned type character varying(255) does not match expected type text in column 2 (email)"
        indicates a type mismatch for the `email` field (and potentially others) returned by the query
        inside `get_all_user_details` compared to its `RETURNS TABLE` definition.
      - This change explicitly casts `u.email` from `auth.users` to `text`.
      - Proactively, it also casts `p.username`, `p.full_name`, `p.avatar_url`, `p.status`, and `p.role`
        from `public.profiles` to `text` to prevent similar issues with those columns.

  2.  **Stabilize `get_current_user_role()`**:
      - While `SECURITY INVOKER` functions use the caller's search path, explicitly setting
        `SET search_path = public` within the function definition for `get_current_user_role()`
        can make its behavior more predictable regarding table resolution. This is a precautionary
        measure that might help with stability if schema resolution issues were contributing to
        intermittent errors (like the 500s observed on `/rest/v1/profiles`).
*/

-- Part 1: Update get_all_user_details to cast types
CREATE OR REPLACE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text,
  role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Defines search_path for the function body itself
AS $$
DECLARE
  caller_role text;
  lowercase_caller_role text;
BEGIN
  caller_role := public.get_current_user_role(); -- This helper is SECURITY INVOKER

  IF caller_role IS NOT NULL THEN
    lowercase_caller_role := lower(caller_role);
  ELSE
    lowercase_caller_role := NULL;
  END IF;

  IF lowercase_caller_role IS NULL OR lowercase_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied. Role check failed. Role from DB: "%", Lowercase Role: "%". Expected one of (admin, super_admin).',
                    COALESCE(caller_role, 'NULL'),
                    COALESCE(lowercase_caller_role, 'NULL');
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::text, -- Explicit cast for email
    u.created_at,
    p.username::text, -- Explicit cast
    p.full_name::text, -- Explicit cast
    p.avatar_url::text, -- Explicit cast
    p.status::text, -- Explicit cast
    p.role::text -- Explicit cast
  FROM
    auth.users u
  LEFT JOIN
    public.profiles p ON u.id = p.id;
END;
$$;

-- Grant execute permission (should already exist, but reaffirming)
GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;


-- Part 2: Update get_current_user_role to be more robust
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public -- Explicitly set search_path
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute permission (should already exist, but reaffirming)
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
</content>
