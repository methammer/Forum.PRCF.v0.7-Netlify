/*
      # Seed SEND_PASSWORD_RESET_EMAIL Permission for Admin Roles

      This migration grants the 'SEND_PASSWORD_RESET_EMAIL' permission to 'ADMIN'
      and 'SUPER_ADMIN' roles. It also ensures the 'SEND_PASSWORD_RESET_EMAIL'
      value exists in the `public.app_permissions` enum as a safeguard.

      1. Assumptions:
         - `public.app_permissions` enum exists (created/updated by `create_permissions_infrastructure.sql`).
         - `public.user_role` enum exists (created by a prior migration).
         - `public.role_permissions` table exists (created by `create_permissions_infrastructure.sql`).

      2. Actions:
         - Ensures 'SEND_PASSWORD_RESET_EMAIL' value is present in `public.app_permissions` enum.
         - Inserts the ('ADMIN', 'SEND_PASSWORD_RESET_EMAIL') mapping into `public.role_permissions`.
         - Inserts the ('SUPER_ADMIN', 'SEND_PASSWORD_RESET_EMAIL') mapping into `public.role_permissions`.
         - Uses ON CONFLICT DO NOTHING to avoid errors if mappings already exist.
    */

    DO $$
    BEGIN
      -- Ensure the SEND_PASSWORD_RESET_EMAIL permission value exists in the enum.
      -- A preceding migration (create_permissions_infrastructure.sql) should have created the enum
      -- comprehensively. This is an additional safeguard.
      BEGIN
        ALTER TYPE public.app_permissions ADD VALUE IF NOT EXISTS 'SEND_PASSWORD_RESET_EMAIL';
        RAISE NOTICE 'Ensured SEND_PASSWORD_RESET_EMAIL value exists in public.app_permissions enum.';
      EXCEPTION
        WHEN OTHERS THEN
          RAISE WARNING 'Could not ensure SEND_PASSWORD_RESET_EMAIL value in enum public.app_permissions: %. This might indicate an issue if the enum was not created or updated by a preceding migration.', SQLERRM;
          -- The INSERT below might fail if the enum or this specific value is missing.
      END;

      -- Grant the SEND_PASSWORD_RESET_EMAIL permission to ADMIN and SUPER_ADMIN roles
      -- Explicitly cast to the enum types for clarity and safety.
      INSERT INTO public.role_permissions (role, permission)
      VALUES
          ('ADMIN'::public.user_role, 'SEND_PASSWORD_RESET_EMAIL'::public.app_permissions),
          ('SUPER_ADMIN'::public.user_role, 'SEND_PASSWORD_RESET_EMAIL'::public.app_permissions)
      ON CONFLICT (role, permission) DO NOTHING;

      RAISE NOTICE 'Attempted to grant SEND_PASSWORD_RESET_EMAIL permission to ADMIN and SUPER_ADMIN roles in role_permissions. If no rows were affected, the permissions may have already existed.';
    END $$;