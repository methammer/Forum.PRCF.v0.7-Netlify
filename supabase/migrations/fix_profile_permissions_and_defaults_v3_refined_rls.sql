/*
      # Fix Profile Permissions, Defaults, and RLS (v3 - Refined RLS)

      This migration addresses potential issues with fetching user profiles by:
      1. Ensuring `role` and `status` columns exist in `public.profiles` with sane defaults.
      2. Updating the `handle_new_user` trigger to populate these fields, using EXCLUDED syntax in ON CONFLICT for clarity (to fix 42P01 errors).
      3. Simplifying and re-asserting RLS policies for `public.profiles` to ensure users can read and update their own profiles, with refined conditions for updates.
      4. Explicitly granting necessary permissions to the `authenticated` role.

      1. Table Modifications (`public.profiles`):
         - Add `role` TEXT column, DEFAULT 'USER', if not exists.
         - Add `status` TEXT column, DEFAULT 'approved', if not exists.

      2. Trigger Modifications (`public.handle_new_user`):
         - Updated to insert default values for `role` ('USER') and `status` ('approved').
         - Uses `EXCLUDED.column` and `profiles.column` in the `ON CONFLICT DO UPDATE` clause.

      3. Row Level Security (RLS) for `public.profiles`:
         - All existing RLS policies on `public.profiles` are DROPPED.
         - New, simplified policies are created.
         - The "update own profile" policy is refined to use `IS NOT DISTINCT FROM` for role/status checks and explicitly prevents ID changes.
         - RLS is ENABLED on `public.profiles`.

      4. Permissions:
         - Granted to `authenticated` role.
    */

    -- Ensure RLS is enabled on the profiles table (idempotent)
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    -- Grant basic schema and table permissions
    GRANT USAGE ON SCHEMA public TO authenticated;
    GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;

    -- Add 'role' column if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
      ) THEN
        ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'USER';
        RAISE NOTICE 'Column "role" added to "profiles" table with default ''USER''.';
      ELSE
        RAISE NOTICE 'Column "role" already exists in "profiles" table.';
      END IF;
    END $$;

    -- Add 'status' column if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'status'
      ) THEN
        ALTER TABLE public.profiles ADD COLUMN status TEXT DEFAULT 'approved';
        RAISE NOTICE 'Column "status" added to "profiles" table with default ''approved''.';
      ELSE
        RAISE NOTICE 'Column "status" already exists in "profiles" table.';
      END IF;
    END $$;

    -- Update existing NULL roles and statuses to defaults
    UPDATE public.profiles SET role = 'USER' WHERE role IS NULL OR lower(role) = 'user';
    UPDATE public.profiles SET status = 'approved' WHERE status IS NULL OR lower(status) = 'approved';

    -- Function to create/update a profile when a new user signs up or metadata changes
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER SET search_path = public
    AS $$
    BEGIN
      INSERT INTO public.profiles (id, username, full_name, avatar_url, role, status, updated_at, created_at)
      VALUES (
        NEW.id, -- This NEW is from auth.users trigger
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url',
        'USER',       -- Default role for new profiles
        'approved',   -- Default status for new profiles
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        username = COALESCE(EXCLUDED.username, profiles.username), -- EXCLUDED refers to the value proposed for insertion
        full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        role = CASE WHEN profiles.role IS NULL THEN EXCLUDED.role ELSE profiles.role END,
        status = CASE WHEN profiles.status IS NULL THEN EXCLUDED.status ELSE profiles.status END,
        updated_at = now();
      RETURN NEW; -- This NEW is from auth.users trigger; return value is ignored for AFTER trigger
    END;
    $$;

    -- Re-create the trigger to ensure it uses the updated function
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

    -- Drop ALL existing RLS policies on profiles to avoid conflicts
    DO $$
    DECLARE
      policy_record RECORD;
    BEGIN
      FOR policy_record IN
        SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles'
      LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.profiles;';
        RAISE NOTICE 'Dropped policy % on public.profiles', policy_record.policyname;
      END LOOP;
    END $$;

    -- Simplified RLS Policies for public.profiles
    CREATE POLICY "Profiles: Users can read their own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

    CREATE POLICY "Profiles: Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

    CREATE POLICY "Profiles: Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id) -- For an UPDATE, 'id' here refers to the existing row's id (OLD.id)
    WITH CHECK (
      auth.uid() = id AND -- For an UPDATE, 'id' here refers to the new row's id (NEW.id)
      NEW.id = OLD.id AND -- Explicitly ensure the primary key does not change
      NEW.role IS NOT DISTINCT FROM OLD.role AND -- Role must not change (handles NULLs correctly)
      NEW.status IS NOT DISTINCT FROM OLD.status -- Status must not change (handles NULLs correctly)
    );

    RAISE NOTICE 'Applied simplified RLS policies to public.profiles.';
