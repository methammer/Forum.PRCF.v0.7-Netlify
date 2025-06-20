/*
      # Setup User Roles, Category Memberships, and Role Type Correction (v15)

      This migration introduces user roles, a system for category memberships,
      helper functions, and a trigger-based mechanism for controlling profile role changes.

      Key changes in this version:
      - Addresses "ERROR: 0A000: cannot alter type of a column used in a policy definition"
        by comprehensively dropping ALL RLS policies on `forum_posts` (including user-specific
        ones like "Allow users to insert their own posts") BEFORE altering `profiles.role` type.
        These policies are then recreated.
      - Drops RLS policies on `sections`, `forum_categories`, `forum_reports`,
        and `forum_replies` that depend on `profiles.role` (TEXT) or `get_current_user_role()` (TEXT version)
        BEFORE altering `profiles.role` type.
      - Drops `get_current_user_role()` (TEXT version) BEFORE altering `profiles.role`.
      - Explicitly DROPS the DEFAULT constraint on `public.profiles.role` before altering its type.
      - Corrects the `public.profiles.role` column type from `TEXT` to the `public.user_role` ENUM.
      - Migrates existing 'USER' (text) roles to 'MEMBER' (text) before type conversion.
      - Sets the default for `profiles.role` to 'MEMBER' (enum).
      - Recreates `get_current_user_role()` to return the ENUM type.
      - Recreates RLS policies on `sections`, `forum_reports`, `forum_categories`, `forum_posts`,
        and `forum_replies` using the new `get_current_user_role()` function where applicable.

      1. Data Migration:
         - Updates `public.profiles` to change `role = 'USER'` to `role = 'MEMBER'` (while `role` is TEXT).

      2. New Enum Type: `public.user_role`
         - Values: 'MEMBER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN'

      3. RLS Policy & Function Management (Pre-change):
         - Drops admin-related RLS policies on `public.sections`.
         - Drops admin-related RLS policies on `public.forum_categories`.
         - Drops ALL RLS policies on `public.forum_posts`.
         - Drops RLS policies on `public.forum_reports`.
         - Drops admin/moderator RLS policies on `public.forum_replies`.
         - Drops `public.get_current_user_role()` (TEXT version).

      4. Table Modification: `public.profiles`
         - Drops existing DEFAULT on `role` column.
         - Alters `role` column type from `TEXT` to `public.user_role`.
         - Sets `role` column `DEFAULT` to `'MEMBER'::public.user_role`.
         - Ensures `role` column is `NOT NULL`.

      5. Function & RLS Policy Management (Post-change):
         - Recreates `public.get_current_user_role()` to return `public.user_role` (ENUM).
         - Recreates RLS policies on `sections`.
         - Recreates RLS policies on `forum_reports`.
         - Recreates RLS policies on `forum_categories`.
         - Recreates ALL RLS policies on `forum_posts`.
         - Recreates RLS policies on `forum_replies`.

      6. New Trigger Function: `public.handle_profile_role_update_permissions()`
         - Prevents non-admins from changing roles.

      7. RLS Policy Updates for `public.profiles`.

      8. New Table: `public.forum_category_members`
         - Manages user memberships in categories.

      9. New Function: `public.is_category_member(p_category_id uuid, p_user_id uuid)`
          - Checks category membership.
    */

    -- Step 0: Data Migration - Convert 'USER' (text) to 'MEMBER' (text)
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role' AND data_type = 'text'
      ) THEN
        UPDATE public.profiles SET role = 'MEMBER' WHERE role = 'USER';
      END IF;
    END$$;

    -- Step 1: Create ENUM type for user roles if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('MEMBER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN');
      END IF;
    END$$;

    -- Step 1.4: Drop RLS policies on sections that depend on profiles.role (TEXT version)
    DROP POLICY IF EXISTS "Allow admins to manage sections" ON public.sections;

    -- Step 1.5: Drop RLS policies on forum_categories that depend on profiles.role (TEXT version)
    DROP POLICY IF EXISTS "Allow admins to insert categories" ON public.forum_categories;
    DROP POLICY IF EXISTS "Allow admins to update categories" ON public.forum_categories;
    DROP POLICY IF EXISTS "Allow admins to delete categories" ON public.forum_categories;
    DROP POLICY IF EXISTS "Admins can manage all categories." ON public.forum_categories;

    -- Step 1.6: Drop ALL RLS policies on forum_posts
    DROP POLICY IF EXISTS "Allow authenticated users to read published posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Allow authenticated users to read all posts" ON public.forum_posts; -- Original name
    DROP POLICY IF EXISTS "Allow users to insert their own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Allow users to update their own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Allow users to delete their own posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Allow admins and moderators to update any post" ON public.forum_posts;
    DROP POLICY IF EXISTS "Allow admins and moderators to delete any post" ON public.forum_posts;
    DROP POLICY IF EXISTS "Admins can manage all posts." ON public.forum_posts;

    -- Step 1.7: Drop RLS policies on forum_reports that depend on the OLD get_current_user_role() (TEXT version)
    DROP POLICY IF EXISTS "Moderators and admins can view all reports" ON public.forum_reports;
    DROP POLICY IF EXISTS "Moderators and admins can update reports" ON public.forum_reports;

    -- Step 1.7.5: Drop RLS policies on forum_replies that depend on profiles.role (TEXT version)
    DROP POLICY IF EXISTS "Allow admins and moderators to update any reply" ON public.forum_replies;
    DROP POLICY IF EXISTS "Allow admins and moderators to delete any reply" ON public.forum_replies;

    -- Step 1.8: Drop the OLD get_current_user_role() function (TEXT version)
    DROP FUNCTION IF EXISTS public.get_current_user_role();

    -- Step 2: Alter the existing 'role' column in 'profiles' table.
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role' AND (data_type = 'text' OR udt_name != 'user_role')
      ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role' AND column_default IS NOT NULL AND data_type = 'text'
        ) THEN
            ALTER TABLE public.profiles ALTER COLUMN role DROP DEFAULT;
        END IF;

        ALTER TABLE public.profiles
          ALTER COLUMN role TYPE public.user_role
          USING role::text::public.user_role;

        ALTER TABLE public.profiles
          ALTER COLUMN role SET DEFAULT 'MEMBER'::public.user_role;

        ALTER TABLE public.profiles
          ALTER COLUMN role SET NOT NULL;

      ELSIF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
      ) THEN
        ALTER TABLE public.profiles
          ADD COLUMN role public.user_role NOT NULL DEFAULT 'MEMBER'::public.user_role;
      ELSE -- Column exists and is already user_role, ensure default and not null are set
        ALTER TABLE public.profiles
          ALTER COLUMN role SET DEFAULT 'MEMBER'::public.user_role;
        ALTER TABLE public.profiles
          ALTER COLUMN role SET NOT NULL;
      END IF;
    END$$;

    -- Step 5: Recreate Function to get current user's role (now returns ENUM)
    CREATE OR REPLACE FUNCTION public.get_current_user_role()
    RETURNS public.user_role
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $$
      SELECT role
      FROM public.profiles
      WHERE id = auth.uid();
    $$;
    GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

    -- Step 5.5: Recreate RLS policies for sections using the new get_current_user_role()
    CREATE POLICY "Allow admins to manage sections"
      ON public.sections FOR ALL
      TO authenticated
      USING (
          public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN')
      )
      WITH CHECK (
          public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN')
      );

    -- Step 6: Recreate RLS policies for forum_reports using the new get_current_user_role()
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

    -- Step 6.5: Recreate RLS policies for forum_categories using the new get_current_user_role()
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

    -- Step 6.6: Recreate RLS policies for forum_posts
    -- Policy for reading published posts (from add_is_published_to_forum_posts.sql)
    CREATE POLICY "Allow authenticated users to read published posts"
      ON public.forum_posts
      FOR SELECT
      TO authenticated
      USING (is_published = true);

    -- Policies for users managing their own posts (from create_forum_posts_table.sql)
    CREATE POLICY "Allow users to insert their own posts"
      ON public.forum_posts
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Allow users to update their own posts"
      ON public.forum_posts
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Allow users to delete their own posts"
      ON public.forum_posts
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);

    -- Policies for admins/moderators (now using get_current_user_role())
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

    -- Step 6.7: Recreate RLS policies for forum_replies using the new get_current_user_role()
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


    -- Step 7: Trigger function to handle role change permissions
    CREATE OR REPLACE FUNCTION public.handle_profile_role_update_permissions()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY INVOKER
    AS $$
    DECLARE
      requesting_user_role public.user_role;
    BEGIN
      IF NEW.role IS DISTINCT FROM OLD.role THEN
        SELECT p.role INTO requesting_user_role FROM public.profiles p WHERE p.id = auth.uid();
        IF requesting_user_role IS NULL OR requesting_user_role NOT IN ('ADMIN', 'SUPER_ADMIN') THEN
          RAISE EXCEPTION 'User does not have permission to change profile roles. Role changes must be performed by an administrator.';
        END IF;
      END IF;
      RETURN NEW;
    END;
    $$;
    GRANT EXECUTE ON FUNCTION public.handle_profile_role_update_permissions() TO authenticated;

    -- Step 8: Drop existing triggers that might conflict, then create the new one
    DROP TRIGGER IF EXISTS before_profile_update_prevent_id_role_change ON public.profiles;
    DROP TRIGGER IF EXISTS before_profile_update_handle_role_permissions ON public.profiles;

    CREATE TRIGGER before_profile_update_handle_role_permissions
      BEFORE UPDATE ON public.profiles
      FOR EACH ROW
      EXECUTE FUNCTION public.handle_profile_role_update_permissions();

    -- Step 9: RLS Policies for profiles
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can update their own profile (excluding role)" ON public.profiles;
    DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
    DROP POLICY IF EXISTS "Admins can update any profile (including roles)" ON public.profiles;
    DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
    DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can update own profile (row access)." ON public.profiles;
    DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;

    CREATE POLICY "Allow authenticated users to read profiles"
      ON public.profiles FOR SELECT TO authenticated USING (true);

    CREATE POLICY "Users can insert their own profile"
      ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

    CREATE POLICY "Users can update their own profile (excluding role changes by non-admins)"
      ON public.profiles
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);

    CREATE POLICY "Admins can update any profile (including roles)"
      ON public.profiles
      FOR UPDATE
      TO authenticated
      USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'))
      WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN'));

    -- Step 10: Create forum_category_members table
    CREATE TABLE IF NOT EXISTS public.forum_category_members (
      category_id uuid NOT NULL REFERENCES public.forum_categories(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      created_at timestamptz DEFAULT now(),
      PRIMARY KEY (category_id, user_id)
    );

    ALTER TABLE public.forum_category_members ENABLE ROW LEVEL SECURITY;

    -- Step 11: RLS Policies for forum_category_members
    DROP POLICY IF EXISTS "Users can view their own category memberships" ON public.forum_category_members;
    CREATE POLICY "Users can view their own category memberships"
      ON public.forum_category_members
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Admins/Mods can view all category memberships" ON public.forum_category_members;
    CREATE POLICY "Admins/Mods can view all category memberships"
      ON public.forum_category_members
      FOR SELECT
      TO authenticated
      USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

    DROP POLICY IF EXISTS "Admins/Mods can add category members" ON public.forum_category_members;
    CREATE POLICY "Admins/Mods can add category members"
      ON public.forum_category_members
      FOR INSERT
      TO authenticated
      WITH CHECK (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

    DROP POLICY IF EXISTS "Users can remove their own category memberships" ON public.forum_category_members;
    CREATE POLICY "Users can remove their own category memberships"
      ON public.forum_category_members
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Admins/Mods can remove category members" ON public.forum_category_members;
    CREATE POLICY "Admins/Mods can remove category members"
      ON public.forum_category_members
      FOR DELETE
      TO authenticated
      USING (public.get_current_user_role() IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR'));

    -- Step 12: Function to check category membership
    CREATE OR REPLACE FUNCTION public.is_category_member(p_category_id uuid, p_user_id uuid)
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $$
      SELECT EXISTS (
        SELECT 1
        FROM public.forum_category_members fcm
        WHERE fcm.category_id = p_category_id AND fcm.user_id = p_user_id
      );
    $$;
    GRANT EXECUTE ON FUNCTION public.is_category_member(uuid, uuid) TO authenticated;