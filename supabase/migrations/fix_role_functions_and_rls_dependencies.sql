/*
  # Fix Role Functions and RLS Dependencies for TEXT Roles (v2 - Add email cast)

  This migration addresses issues arising from changing `public.profiles.role` to TEXT
  and a type mismatch for the email column in `get_all_user_details`.

  The `get_current_user_role()` and `get_all_user_details()` functions need to be
  updated to return/handle TEXT roles and ensure all returned columns match their
  defined types. This was previously blocked because numerous
  RLS policies depended on `get_current_user_role()`.

  Version 2: Explicitly casts `u.email` to `TEXT` in `get_all_user_details`
  to resolve "42804: structure of query does not match function result type" error.

  This migration will:
  1.  **Drop Dependent RLS Policies**: All RLS policies that depend on the
      `get_current_user_role()` function are dropped.
  2.  **Drop Existing Functions**:
      - `public.get_all_user_details()` is dropped.
      - `public.get_current_user_role()` is dropped.
  3.  **Recreate `public.get_current_user_role()`**:
      - Defined to `RETURNS TEXT`.
      - Selects `role` (which is TEXT) from `public.profiles`.
      - Roles are assumed to be stored in uppercase (e.g., 'ADMIN', 'MEMBER').
  4.  **Recreate `public.get_all_user_details()`**:
      - The `RETURNS TABLE` definition is updated to specify `role TEXT`.
      - **`u.email` is cast to `TEXT`**.
      - Internal logic uses TEXT for role comparisons.
  5.  **Recreate RLS Policies**: All previously dropped RLS policies are recreated.
      They will now use the new `get_current_user_role()` which returns TEXT.
      Comparisons like `get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN')`
      will correctly compare TEXT against an array of TEXT.
  6.  **Grant Permissions**: Execute permissions are re-granted for the functions.

  Affected RLS Policies (Dropped and Recreated):
  - On `public.sections`: "Allow admins to manage sections"
  - On `public.forum_reports`: "Moderators and admins can view all reports", "Moderators and admins can update reports"
  - On `public.forum_categories`: "Allow admins to insert categories", "Allow admins to update categories", "Allow admins to delete categories"
  - On `public.forum_posts`: "Allow admins and moderators to update any post", "Allow admins and moderators to delete any post"
  - On `public.forum_replies`: "Allow admins and moderators to update any reply", "Allow admins and moderators to delete any reply"
  - On `public.profiles`: "Admins can update any profile (including roles)"
  - On `public.forum_category_members`: "Admins/Mods can view all category memberships", "Admins/Mods can add category members", "Admins/Mods can remove category members"
*/

-- Step 1: Drop all RLS policies that depend on get_current_user_role()
-- On public.sections
DROP POLICY IF EXISTS "Allow admins to manage sections" ON public.sections;

-- On public.forum_reports
DROP POLICY IF EXISTS "Moderators and admins can view all reports" ON public.forum_reports;
DROP POLICY IF EXISTS "Moderators and admins can update reports" ON public.forum_reports;

-- On public.forum_categories
DROP POLICY IF EXISTS "Allow admins to insert categories" ON public.forum_categories;
DROP POLICY IF EXISTS "Allow admins to update categories" ON public.forum_categories;
DROP POLICY IF EXISTS "Allow admins to delete categories" ON public.forum_categories;
DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;


-- On public.forum_posts
DROP POLICY IF EXISTS "Allow admins and moderators to update any post" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow admins and moderators to delete any post" ON public.forum_posts;
DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;


-- On public.forum_replies
DROP POLICY IF EXISTS "Allow admins and moderators to update any reply" ON public.forum_replies;
DROP POLICY IF EXISTS "Allow admins and moderators to delete any reply" ON public.forum_replies;

-- On public.profiles
DROP POLICY IF EXISTS "Admins can update any profile (including roles)" ON public.profiles;

-- On public.forum_category_members
DROP POLICY IF EXISTS "Admins/Mods can view all category memberships" ON public.forum_category_members;
DROP POLICY IF EXISTS "Admins/Mods can add category members" ON public.forum_category_members;
DROP POLICY IF EXISTS "Admins/Mods can remove category members" ON public.forum_category_members;

-- Step 2: Drop existing functions
DROP FUNCTION IF EXISTS public.get_all_user_details();
DROP FUNCTION IF EXISTS public.get_current_user_role();

-- Step 3: Recreate get_current_user_role to return TEXT
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

-- Step 4: Recreate get_all_user_details ensuring its role column and internal logic use TEXT
CREATE OR REPLACE FUNCTION public.get_all_user_details()
RETURNS TABLE (
  id uuid,
  email text, -- Expected type
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  status text,
  role text -- Explicitly TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text; -- Variable to store the role, typed as TEXT
BEGIN
  caller_role := public.get_current_user_role();

  IF caller_role IS NULL OR caller_role NOT IN ('ADMIN', 'SUPER_ADMIN') THEN
    RAISE EXCEPTION 'Permission denied. User requires ADMIN or SUPER_ADMIN role. Found: %', COALESCE(caller_role, 'NULL');
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::text, -- Cast auth.users.email (varchar) to TEXT
    u.created_at,
    p.username,
    p.full_name,
    p.avatar_url,
    p.status,
    p.role -- This is TEXT from profiles.role
  FROM
    auth.users u
  LEFT JOIN
    public.profiles p ON u.id = p.id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_user_details() TO authenticated;

-- Step 5: Recreate RLS Policies using the new TEXT-returning get_current_user_role()

-- On public.sections
CREATE POLICY "Allow admins to manage sections"
  ON public.sections FOR ALL
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'))
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

-- On public.forum_reports
CREATE POLICY "Moderators and admins can view all reports"
  ON public.forum_reports
  FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));

CREATE POLICY "Moderators and admins can update reports"
  ON public.forum_reports
  FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'))
  WITH CHECK (public.get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));

-- On public.forum_categories
CREATE POLICY "Allow admins to insert categories"
  ON public.forum_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

CREATE POLICY "Allow admins to update categories"
  ON public.forum_categories
  FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'))
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

CREATE POLICY "Allow admins to delete categories"
  ON public.forum_categories
  FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

-- On public.forum_posts
CREATE POLICY "Allow admins and moderators to update any post"
  ON public.forum_posts
  FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'))
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

CREATE POLICY "Allow admins and moderators to delete any post"
  ON public.forum_posts
  FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

-- On public.forum_replies
CREATE POLICY "Allow admins and moderators to update any reply"
  ON public.forum_replies
  FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'))
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

CREATE POLICY "Allow admins and moderators to delete any reply"
  ON public.forum_replies
  FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

-- On public.profiles
CREATE POLICY "Admins can update any profile (including roles)"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'))
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

-- On public.forum_category_members
CREATE POLICY "Admins/Mods can view all category memberships"
  ON public.forum_category_members
  FOR SELECT
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

CREATE POLICY "Admins/Mods can add category members"
  ON public.forum_category_members
  FOR INSERT
  TO authenticated
  WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

CREATE POLICY "Admins/Mods can remove category members"
  ON public.forum_category_members
  FOR DELETE
  TO authenticated
  USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));
