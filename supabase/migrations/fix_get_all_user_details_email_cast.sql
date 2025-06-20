```sql
/*
  # Fix Email Type Cast in get_all_user_details Function

  This migration addresses an error in the `public.get_all_user_details` function
  where the `auth.users.email` column (likely `character varying(255)`) was being
  returned for a column defined as `TEXT` in the function's `RETURNS TABLE`
  definition.

  This migration will:
  1.  **Drop the existing `public.get_all_user_details` function.**
  2.  **Recreate the `public.get_all_user_details` function:**
      - The `SELECT` statement within the function will now cast `u.email` to `TEXT`
        (i.e., `u.email::text`).
  3.  **Re-grant execute permissions** on the function.

  The `RETURNS TABLE` definition remains the same, expecting `email TEXT`.
  The internal query now explicitly provides `TEXT`.
*/

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS public.get_all_user_details();

-- Step 2: Recreate get_all_user_details with the email cast
CREATE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text, -- Expected type
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text,
  role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  caller_role := public.get_current_user_role();

  IF caller_role IS NULL OR caller_role NOT IN ('ADMIN', 'SUPER_ADMIN') THEN
    RAISE EXCEPTION 'Permission denied. User requires ADMIN or SUPER_ADMIN role. Found: %', COALESCE(caller_role, 'NULL');
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::text, -- Explicitly cast auth.users.email to TEXT
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

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;

```