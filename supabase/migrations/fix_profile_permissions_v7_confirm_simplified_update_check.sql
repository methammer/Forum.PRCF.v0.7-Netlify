/*
      # Fix Profile Permissions, Defaults, RLS (v7 - Confirm Simplified Update Policy Check)

      This migration re-attempts to resolve the "missing FROM-clause entry for table new" error
      by ensuring the `WITH CHECK` clause of the `UPDATE` RLS policy on `public.profiles`
      is simplified to its most common and basic form for preventing `id` changes.

      The logs from the previous attempt indicated that a more complex `WITH CHECK` clause
      (including checks on `NEW.role` and `NEW.status`) was still being executed. This version
      explicitly uses: `CHECK (auth.uid() = id AND NEW.id = OLD.id)`.

      1. Table Modifications (`public.profiles`):
         - Ensure `role` and `status` columns exist with defaults (idempotent).
      2. Trigger Modifications (`public.handle_new_user`):
         - Uses local variables for `NEW.id` and `NEW.raw_user_meta_data`. (No change from v5/v6)
      3. Row Level Security (RLS) for `public.profiles`:
         - **Confirmed Simplified `WITH CHECK` for the UPDATE policy**:
           - `CHECK (auth.uid() = id AND NEW.id = OLD.id)`
         - Other policies re-asserted for clarity and correctness.
      4. Permissions:
         - Granted to `authenticated` role.
    */

    -- Ensure RLS is enabled on the profiles table
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    -- Grant basic schema and table permissions
    GRANT USAGE ON SCHEMA public TO authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;

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
    SECURITY DEFINER SET search_path = public
    AS $$
    DECLARE
      v_user_id uuid := NEW.id;
      v_raw_meta jsonb := NEW.raw_user_meta_data;
      v_username text;
      v_full_name text;
      v_avatar_url text;
    BEGIN
      -- Safely extract values from raw_user_meta_data
      v_username := v_raw_meta->>'username';
      v_full_name := v_raw_meta->>'full_name';
      v_avatar_url := v_raw_meta->>'avatar_url';

      INSERT INTO public.profiles (id, username, full_name, avatar_url, role, status, updated_at, created_at)
      VALUES (
        v_user_id,
        v_username,
        v_full_name,
        v_avatar_url,
        'USER',       -- Default role
        'approved',   -- Default status
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        username = COALESCE(EXCLUDED.username, public.profiles.username),
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
        role = CASE WHEN public.profiles.role IS NULL THEN EXCLUDED.role ELSE public.profiles.role END,
        status = CASE WHEN public.profiles.status IS NULL THEN EXCLUDED.status ELSE public.profiles.status END,
        updated_at = now();
      RETURN NULL; -- For AFTER triggers, the return value is ignored.
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
    USING (auth.uid() = id) -- This determines WHICH rows can be targeted for update
    WITH CHECK (
      auth.uid() = id AND -- Ensures the user making the change is the owner
      NEW.id = OLD.id     -- Ensures the 'id' field itself is not being changed. THIS IS THE KEY SIMPLIFICATION.
    );

    RAISE NOTICE 'Applied RLS policies to public.profiles. Confirmed simplified UPDATE policy check.';
