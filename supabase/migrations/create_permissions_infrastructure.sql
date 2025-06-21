/*
      # Create Permissions Infrastructure

      This migration sets up the foundational schema for role-based permissions.
      It creates the `app_permissions` enum and the `role_permissions` table.
      Corrected RLS policy for "Admins can manage role_permissions" to cast `profiles.role` to `public.user_role`.

      1. New Enum: `public.app_permissions`
         - Defines all known application permissions. This list should be kept
           in sync with `src/constants/permissions.ts` or a central permissions definition.
         - Includes 'SEND_PASSWORD_RESET_EMAIL' among other permissions.

      2. New Table: `public.role_permissions`
         - Links roles (`public.user_role`) to permissions (`public.app_permissions`).
         - Columns:
           - `id`: BIGSERIAL, Primary Key
           - `role`: `public.user_role`, NOT NULL
           - `permission`: `public.app_permissions`, NOT NULL
           - `created_at`: TIMESTAMPTZ, Default now()
         - Unique constraint on (`role`, `permission`).
         - Assumes `public.user_role` enum already exists (created in a prior migration like `setup_roles_and_category_memberships.sql`).

      3. RLS for `public.role_permissions`
         - Enables RLS.
         - Policy: Authenticated users can read all role-permission assignments.
         - Policy: Admins (`ADMIN`, `SUPER_ADMIN`) can manage (insert, update, delete) role-permission assignments.
           (Corrected to cast `profiles.role` to `public.user_role` for comparison).
    */

    DO $$
    DECLARE
      -- Define all known permissions, ensuring this list is comprehensive
      all_permissions TEXT[] := ARRAY[
        'VIEW_USER_LIST', 'CREATE_USER', 'EDIT_USER_PROFILE', 'CHANGE_USER_ROLE',
        'APPROVE_USER_REGISTRATION', 'DELETE_USER', 'SEND_PASSWORD_RESET_EMAIL',
        'VIEW_MODERATION_PANEL', 'SOFT_DELETE_CONTENT', 'RESTORE_CONTENT',
        'PERMANENTLY_DELETE_CONTENT', 'VIEW_REPORTS', 'MANAGE_REPORTS',
        'EDIT_ANY_POST', 'EDIT_ANY_REPLY', 'VIEW_AUDIT_LOGS', 'MANAGE_CATEGORIES',
        'MANAGE_TAGS', 'VIEW_FORUM_SETTINGS', 'EDIT_FORUM_SETTINGS', 'WARN_USER',
        'SUSPEND_USER', 'BAN_USER', 'VIEW_USER_SANCTIONS', 'MANAGE_USER_SANCTIONS'
      ];
      permission_value TEXT;
      create_enum_sql TEXT;
      enum_exists BOOLEAN;
    BEGIN
      -- Step 1: Create or Update public.app_permissions enum
      SELECT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'app_permissions' AND n.nspname = 'public'
      ) INTO enum_exists;

      IF NOT enum_exists THEN
        RAISE NOTICE 'Enum public.app_permissions does not exist. Creating it...';
        create_enum_sql := 'CREATE TYPE public.app_permissions AS ENUM (';
        FOREACH permission_value IN ARRAY all_permissions
        LOOP
          create_enum_sql := create_enum_sql || '''' || permission_value || ''', ';
        END LOOP;
        create_enum_sql := LEFT(create_enum_sql, LENGTH(create_enum_sql) - 2) || ');';
        EXECUTE create_enum_sql;
        RAISE NOTICE 'Enum public.app_permissions created successfully with all defined permissions.';
      ELSE
        RAISE NOTICE 'Enum public.app_permissions already exists. Checking for and adding missing values...';
        FOREACH permission_value IN ARRAY all_permissions
        LOOP
          IF NOT EXISTS (
            SELECT 1
            FROM pg_enum
            WHERE enumlabel = permission_value AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'app_permissions' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
          ) THEN
            EXECUTE 'ALTER TYPE public.app_permissions ADD VALUE IF NOT EXISTS ''' || permission_value || '''';
            RAISE NOTICE 'Added value % to enum public.app_permissions.', permission_value;
          END IF;
        END LOOP;
        RAISE NOTICE 'Finished checking/adding values to public.app_permissions.';
      END IF;

      -- Step 2: Create public.role_permissions table
      -- Assumes public.user_role enum already exists from a previous migration.
      CREATE TABLE IF NOT EXISTS public.role_permissions (
        id BIGSERIAL PRIMARY KEY,
        role public.user_role NOT NULL,
        permission public.app_permissions NOT NULL,
        created_at TIMESTAMPTZ DEFAULT now(),
        CONSTRAINT uq_role_permission UNIQUE (role, permission)
      );

      RAISE NOTICE 'Table public.role_permissions created or already exists.';

      -- Step 3: RLS for public.role_permissions
      ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS "Authenticated users can read role_permissions" ON public.role_permissions;
      CREATE POLICY "Authenticated users can read role_permissions"
        ON public.role_permissions
        FOR SELECT
        TO authenticated
        USING (true);

      DROP POLICY IF EXISTS "Admins can manage role_permissions" ON public.role_permissions;
      CREATE POLICY "Admins can manage role_permissions"
        ON public.role_permissions
        FOR ALL
        TO authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM public.profiles
            WHERE id = auth.uid() AND profiles.role::public.user_role IN ('ADMIN'::public.user_role, 'SUPER_ADMIN'::public.user_role)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM public.profiles
            WHERE id = auth.uid() AND profiles.role::public.user_role IN ('ADMIN'::public.user_role, 'SUPER_ADMIN'::public.user_role)
          )
        );

      RAISE NOTICE 'RLS policies for public.role_permissions applied.';

    END $$;