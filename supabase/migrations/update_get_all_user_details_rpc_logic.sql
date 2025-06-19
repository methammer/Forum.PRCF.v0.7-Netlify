<content>/*
  # Update get_all_user_details RPC Logic

  This migration updates the `public.get_all_user_details()` PL/pgSQL function
  to correctly determine the calling user's role for its internal permission check.

  1.  **Function Modification `public.get_all_user_details()`**:
      - The function previously tried to directly query `public.profiles` to get the
        caller's role. This could lead to issues with RLS context within a
        `SECURITY DEFINER` function.
      - **Change**: It now uses the `public.get_current_user_role()` helper function
        (which is `SECURITY INVOKER` and RLS-aware) to determine the `caller_role`.
        This ensures the role check is consistent with the RLS policies applied
        to the `profiles` table.
      - The function remains `SECURITY DEFINER` to allow it to read from `auth.users`
        and join with `public.profiles` effectively, after the admin check passes.

  2.  **Grant**:
      - Ensures `EXECUTE` permission on the function is granted to `authenticated` users.
        The function itself performs the role-based authorization.
*/

-- Function to get all user details by joining auth.users and profiles
CREATE OR REPLACE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text, -- Assuming status is stored as text, matching 'pending_approval', 'approved', 'rejected'
  role text -- Assuming role is stored as text, matching 'user', 'admin', 'moderator'
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Important to ensure function can find other objects like get_current_user_role
AS $$
DECLARE
  caller_role text;
BEGIN
  -- Use the RLS-aware helper function to get the role of the currently authenticated user
  caller_role := public.get_current_user_role();

  -- Check if the caller has admin privileges
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied. User does not have admin privileges.';
  END IF;

  -- Return query joining auth.users and profiles
  -- This part runs with definer privileges, bypassing RLS if necessary (e.g., for auth.users)
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

-- Grant execute permission on the function to authenticated users
-- The function itself performs the role check.
GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;
</content>
