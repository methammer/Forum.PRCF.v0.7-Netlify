/*
  # Fix Admin Role Logic for Updates and Case Sensitivity

  This migration addresses issues where role changes by admins might not persist
  due to strict role string matching (e.g., 'admin' vs 'SUPER_ADMIN') and
  potential case sensitivity issues.

  ## Changes:

  1.  **`public.get_current_user_role()` function**:
      - Modified to always return the user's role in lowercase.
      - This standardizes the role string for comparisons in RLS policies.

  2.  **`public.prevent_profile_id_role_change()` trigger function**:
      - Modified to fetch the acting user's profile role in lowercase (`actor_profile_role`).
      - The condition allowing role changes is updated to check if `actor_profile_role`
        is IN `('admin', 'super_admin')`. This allows users with either role
        to modify other users' roles.

  3.  **RLS Policies on `public.profiles`**:
      - **Select Policy (`"Profiles: Users can view, Admins can view all"`)**:
        - Updated `USING` clause: `public.get_current_user_role() IN ('admin', 'super_admin')`.
      - **Insert Policy (`"Profiles: Admins can insert"`)**:
        - Updated `WITH CHECK` clause: `public.get_current_user_role() IN ('admin', 'super_admin')`.
      - **Update Policy (`"Profiles: Users can update own, Admins can update all"`)**:
        - Updated `USING` and `WITH CHECK` clauses: `public.get_current_user_role() IN ('admin', 'super_admin')`.
      - **Delete Policy (`"Profiles: Admins can delete"`)**:
        - Updated `USING` clause: `public.get_current_user_role() IN ('admin', 'super_admin')`.

  ## Reason:
  The previous logic strictly checked for the role 'admin'. If an administrator
  had a role like 'SUPER_ADMIN' or 'Admin' (case difference), their attempts
  to modify other users' roles via the UI might be silently prevented by RLS
  or the trigger, even if the UI showed a success message (due to the client-side
  update call returning without an immediate error). This change makes the role
  checking more flexible and robust.
*/

-- 1. Modify public.get_current_user_role()
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  -- Ensure the function can see the profiles table correctly and return lowercase role
  SET search_path = public;
  SELECT lower(role) FROM public.profiles WHERE id = auth.uid();
$$;

-- Grant execute on the updated helper function
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;


-- 2. Modify public.prevent_profile_id_role_change() trigger function
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
  actor_profile_role text; -- Role of the user performing the action, from their profile (now lowercase)
BEGIN
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

  -- Get the lowercase profile role of the user performing the action (auth.uid())
  BEGIN
    SELECT lower("role") INTO actor_profile_role FROM public.profiles WHERE id = auth.uid();
  EXCEPTION WHEN NO_DATA_FOUND THEN
    actor_profile_role := 'no_profile_for_uid'; -- lowercase for consistency
  END;

  RAISE NOTICE '[prevent_profile_id_role_change_trigger] Debug Context: session_user="%", func_owner="%", active_pg_role="%", request.is_service_role="%", claimed_jwt_role="%", actor_profile_role="%"',
    current_session_user,
    func_owner,
    COALESCE(active_pg_role, 'NULL'),
    is_service_role_setting,
    COALESCE(claimed_role_from_jwt, 'NULL'),
    COALESCE(actor_profile_role, 'NULL');

  IF NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Changing the profile ID is not allowed.';
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF claimed_role_from_jwt = 'service_role' THEN
      RETURN NEW;
    END IF;

    -- Allow if the acting user has 'admin' or 'super_admin' role in their profile
    IF actor_profile_role IN ('admin', 'super_admin') THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Changing the profile role is only allowed for administrators (admin, super_admin) or service roles. (Context: session_user="%", jwt_role="%", actor_profile_role="%")',
      current_session_user,
      COALESCE(claimed_role_from_jwt, 'NOT_SET'),
      COALESCE(actor_profile_role, 'NOT_FOUND_OR_NOT_ADMIN');
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Update RLS Policies on public.profiles

-- Drop existing policies to re-apply with new logic
DROP POLICY IF EXISTS "Profiles: Users can view, Admins can view all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins can insert" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Users can update own, Admins can update all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: Admins can delete" ON public.profiles;

-- Recreate policies with updated admin role check

CREATE POLICY "Profiles: Users can view, Admins can view all"
ON public.profiles
FOR SELECT
USING (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
);

CREATE POLICY "Profiles: Admins can insert"
ON public.profiles
FOR INSERT
WITH CHECK (
  public.get_current_user_role() IN ('admin', 'super_admin')
);

CREATE POLICY "Profiles: Users can insert their own profile"
ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);


CREATE POLICY "Profiles: Users can update own, Admins can update all"
ON public.profiles
FOR UPDATE
USING (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
)
WITH CHECK (
  (auth.uid() = id) OR (public.get_current_user_role() IN ('admin', 'super_admin'))
);

CREATE POLICY "Profiles: Admins can delete"
ON public.profiles
FOR DELETE
USING (
  public.get_current_user_role() IN ('admin', 'super_admin')
);

-- Ensure RLS is enabled (it should be, but as a safeguard)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
