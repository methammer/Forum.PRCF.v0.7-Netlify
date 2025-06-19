<content>/*
  # Fix get_all_user_details RPC Case Sensitivity and Enhance Debugging

  This migration updates the `public.get_all_user_details()` PL/pgSQL function:

  1.  **Case-Insensitive Role Check**:
      - Modifies the internal role check to be case-insensitive by converting the fetched `caller_role` to lowercase before comparing it against 'admin' or 'super_admin'.
      - This addresses the issue where a role like 'SUPER_ADMIN' (uppercase) would not match 'super_admin' (lowercase) in a case-sensitive comparison.

  2.  **Enhanced Error Message**:
      - Updates the `RAISE EXCEPTION` message to include the actual role fetched from the database and its lowercase version if the permission check fails. This provides more context for debugging if issues persist.

  The function continues to use `public.get_current_user_role()` to determine the caller's role, which is `SECURITY INVOKER` and RLS-aware. The `get_all_user_details` function itself remains `SECURITY DEFINER`.
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
  status text, -- Assuming status is stored as text
  role text -- Assuming role is stored as text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
  lowercase_caller_role text;
BEGIN
  -- Use the RLS-aware helper function to get the role of the currently authenticated user
  caller_role := public.get_current_user_role();
  
  IF caller_role IS NOT NULL THEN
    lowercase_caller_role := lower(caller_role);
  ELSE
    lowercase_caller_role := NULL;
  END IF;

  -- Check if the caller has admin privileges (case-insensitive)
  IF lowercase_caller_role IS NULL OR lowercase_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied. Role check failed. Role from DB: "%", Lowercase Role: "%". Expected one of (admin, super_admin).',
                    COALESCE(caller_role, 'NULL'),
                    COALESCE(lowercase_caller_role, 'NULL');
  END IF;

  -- Return query joining auth.users and profiles
  -- This part runs with definer privileges
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
