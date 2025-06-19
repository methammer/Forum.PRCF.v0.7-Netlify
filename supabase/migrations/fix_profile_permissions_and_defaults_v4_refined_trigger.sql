/*
      # Fix Profile Permissions, Defaults, RLS (v4 - Refined Trigger)

      This migration further refines the `handle_new_user` trigger function to prevent parsing errors.
      1. Table Modifications (`public.profiles`):
         - Ensure `role` and `status` columns exist with defaults.
      2. Trigger Modifications (`public.handle_new_user`):
         - Uses `EXCLUDED.column` for proposed values in `ON CONFLICT`.
         - **Crucially, fully qualifies column references to `public.profiles` in the `DO UPDATE SET` clause (e.g., `public.profiles.username`) to remove ambiguity.**
         - Changed to `RETURN NULL` as it's an `AFTER` trigger.
      3. Row Level Security (RLS) for `public.profiles`:
         - Policies re-asserted for clarity and correctness.
      4. Permissions:
         - Granted to `authenticated` role.
    */

    -- Ensure RLS is enabled on the profiles table
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    -- Grant basic schema and table permissions
    GRANT USAGE ON SCHEMA public TO authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated; -- Added DELETE for completeness if needed by app logic, can be removed.

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

    -- Function to create/update a profile when a new user signs up
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER SET search_path = public -- Defines schema resolution order within the function
    AS $$
    BEGIN
      INSERT INTO public.profiles (id, username, full_name, avatar_url, role, status, updated_at, created_at)
      VALUES (
        NEW.id, -- NEW here refers to the new row in auth.users
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url',
        'USER',       -- Default role
        'approved',   -- Default status
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        username = COALESCE(EXCLUDED.username, public.profiles.username), -- Fully qualified
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name), -- Fully qualified
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url), -- Fully qualified
        -- If existing profile had NULL role/status, update with EXCLUDED (which are the defaults from INSERT). Otherwise, keep existing.
        role = CASE WHEN public.profiles.role IS NULL THEN EXCLUDED.role ELSE public.profiles.role END, -- Fully qualified
        status = CASE WHEN public.profiles.status IS NULL THEN EXCLUDED.status ELSE public.profiles.status END, -- Fully qualified
        updated_at = now();
      RETURN NULL; -- For AFTER triggers, the return value is ignored. NULL is conventional.
    END;
    $$;

    -- Re-create the trigger on auth.users to use the updated function
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

    -- Drop ALL existing RLS policies on profiles to avoid conflicts before recreating
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

    -- RLS Policies for public.profiles
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
    USING (auth.uid() = id) -- OLD.id is implied here for the row being checked
    WITH CHECK (
      auth.uid() = id AND -- NEW.id is implied for the proposed update
      NEW.id = OLD.id AND -- Ensure primary key cannot be changed
      NEW.role IS NOT DISTINCT FROM OLD.role AND -- Role must not change
      NEW.status IS NOT DISTINCT FROM OLD.status -- Status must not change
    );
    
    -- Optional: Policy for users to delete their own profile if needed
    -- CREATE POLICY "Profiles: Users can delete their own profile"
    -- ON public.profiles
    -- FOR DELETE
    -- TO authenticated
    -- USING (auth.uid() = id);

    RAISE NOTICE 'Applied RLS policies to public.profiles.';
