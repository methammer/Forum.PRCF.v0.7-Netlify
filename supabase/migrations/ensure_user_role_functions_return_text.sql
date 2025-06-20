```sql
/*
  # Ensure User Role Functions Return TEXT

  This migration ensures that both `public.get_current_user_role()` and
  `public.get_all_user_details()` correctly handle and return role information
  as TEXT, following the conversion of `public.profiles.role` to TEXT.

  1.  **Function `public.get_current_user_role()`**:
      - Re-defined to explicitly return `TEXT`.
      - This resolves a potential mismatch if the function was previously
        declared to return the old `user_role` enum while its body now
        selects from the TEXT-based `profiles.role` column.
      - Remains STABLE, SECURITY INVOKER, and sets `search_path`.

  2.  **Function `public.get_all_user_details()`**:
      - Re-defined to ensure its `RETURNS TABLE` clause specifies `role TEXT`.
      - The internal logic using `public.get_current_user_role()` and selecting
        `p.role` from `public.profiles` is consistent with TEXT types.
      - Remains SECURITY DEFINER and sets `search_path`.

  This addresses errors like "return type mismatch in function declared to return user_role"
  that can occur if function definitions are stale after underlying column type changes.
*/

-- Ensure get_current_user_role returns TEXT
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public -- Correct: search_path set at function definition
AS $$
  SELECT lower(role) FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute permission on the function to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;


-- Ensure get_all_user_details returns role as TEXT and uses TEXT internally
CREATE OR REPLACE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text, -- Assuming status is stored as text
  role text    -- Ensure this is TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Important to ensure function can find other objects like get_current_user_role
AS $$
DECLARE
  caller_role text; -- Variable to store role from get_current_user_role
BEGIN
  -- Use the RLS-aware helper function to get the role of the currently authenticated user
  caller_role := public.get_current_user_role(); -- This now correctly assigns text to text

  -- Check if the caller has admin privileges
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Permission denied. User does not have admin privileges.';
  END IF;

  -- Return query joining auth.users and profiles
  RETURN QUERY
  SELECT
    u.id,
    u.email,
    u.created_at,
    p.username,
    p.full_name,
    p.avatar_url,
    p.status,
    p.role -- p.role from public.profiles is TEXT
  FROM
    auth.users u
  LEFT JOIN
    public.profiles p ON u.id = p.id;
END;
$$;

-- Grant execute permission on the function to authenticated users
-- The function itself performs the role check.
GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;
    ```