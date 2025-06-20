/*
      # Add email and role columns to profiles table (Idempotent)

      This migration ensures that the `public.profiles` table has the necessary `email`
      and `role` columns, which are required by the `handle_new_user` trigger function.

      1. New Columns (if they don't exist)
         - `public.profiles`
           - `email` (text, nullable): Stores the user's email, populated from `auth.users`.
           - `role` (text, default 'USER', not null): Stores the user's role.

      2. Changes
         - Adds `email` column to `profiles` table if it's missing.
         - Adds `role` column to `profiles` table if it's missing, with a default value.

      3. Important Notes
         - This migration is idempotent and safe to run multiple times.
         - The `handle_new_user` trigger relies on these columns being present.
    */

    -- Add the email column to the profiles table if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'profiles' AND column_name = 'email' AND table_schema = 'public'
      ) THEN
        ALTER TABLE public.profiles ADD COLUMN email TEXT;
        RAISE NOTICE 'Column email added to public.profiles';
      ELSE
        RAISE NOTICE 'Column email already exists in public.profiles';
      END IF;
    END $$;

    -- Add the role column to the profiles table if it doesn't exist
    -- The handle_new_user trigger attempts to insert 'USER' into this column.
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'profiles' AND column_name = 'role' AND table_schema = 'public'
      ) THEN
        ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'USER' NOT NULL;
        RAISE NOTICE 'Column role added to public.profiles';
      ELSE
        RAISE NOTICE 'Column role already exists in public.profiles';
        -- Ensure the default is set if the column exists but default is missing (optional, but good for consistency)
        ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'USER';
      END IF;
    END $$;