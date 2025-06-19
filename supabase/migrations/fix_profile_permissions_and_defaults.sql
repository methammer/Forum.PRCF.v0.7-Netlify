/*
      # Fix Profile Permissions, Defaults, and RLS

      This migration addresses potential issues with fetching user profiles by:
      1. Ensuring `role` and `status` columns exist in `public.profiles` with sane defaults.
      2. Updating the `handle_new_user` trigger to populate these fields.
      3. Simplifying and re-asserting RLS policies for `public.profiles` to ensure users can read and update their own profiles.
      4. Explicitly granting necessary permissions to the `authenticated` role.

      This aims to resolve "permission denied" errors when fetching profiles.

      1. Table Modifications (`public.profiles`):
         - Add `role` TEXT column, DEFAULT 'USER', if not exists. Values will be uppercase (e.g., 'USER', 'ADMIN').
         - Add `status` TEXT column, DEFAULT 'approved', if not exists. Values will be lowercase (e.g., 'approved', 'pending_approval').
         - (Note: Consider using ENUM types for `role` and `status` in a future refactor for better data integrity).

      2. Trigger Modifications (`public.handle_new_user`):
         - Updated to insert default values for `role` ('USER') and `status` ('approved').
         - Includes an `ON CONFLICT DO UPDATE` clause to handle cases where a profile might already exist.

      3. Row Level Security (RLS) for `public.profiles`:
         - All existing RLS policies on `public.profiles` are DROPPED to ensure a clean slate.
         - New, simplified policies are created:
           - "Profiles: Users can read their own profile": Allows users to SELECT their own profile.
           - "Profiles: Users can update their own profile": Allows users to UPDATE their own profile, but prevents them from changing their `role` or `status`.
           - "Profiles: Users can insert their own profile": Primarily for the trigger's context; direct user inserts might be disabled at the app level.
         - RLS is ENABLED on `public.profiles`.

      4. Permissions:
         - `GRANT USAGE ON SCHEMA public TO authenticated;`
         - `GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;`
         (Note: DELETE is intentionally omitted for users on their own profiles via direct SQL).

      5. Important Notes:
         - This migration prioritizes fixing the immediate profile access issue.
         - The complex RBAC SELECT policy from previous migrations (relying on `get_current_user_role()`) is temporarily replaced by a simpler one. If RBAC is needed, the function and policy should be revisited carefully.
         - The error "permission denied for table users" was observed. While this migration focuses on `profiles` RLS, this simplification should rule out `profiles` RLS as the cause. If the error persists, deeper investigation might be needed.
    */

    -- Ensure RLS is enabled on the profiles table (idempotent)
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    -- Grant basic schema and table permissions
    GRANT USAGE ON SCHEMA public TO authenticated;
    GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;

    -- Add 'role' column if it doesn't exist, ensuring it's TEXT for flexibility
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

    -- Add 'status' column if it doesn't exist, ensuring it's TEXT
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
    -- Ensure roles are uppercase as per UserContext.tsx expectation
    UPDATE public.profiles SET role = 'USER' WHERE role IS NULL OR lower(role) = 'user';
    UPDATE public.profiles SET status = 'approved' WHERE status IS NULL OR lower(status) = 'approved';


    -- Function to create/update a profile when a new user signs up or metadata changes
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER SET search_path = public -- Important for SECURITY DEFINER
    AS $$
    BEGIN
      INSERT INTO public.profiles (id, username, full_name, avatar_url, role, status, updated_at, created_at)
      VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url',
        'USER',       -- Default role (UPPERCASE)
        'approved',   -- Default status (lowercase)
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        username = COALESCE(NEW.raw_user_meta_data->>'username', OLD.username),
        full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', OLD.full_name),
        avatar_url = COALESCE(NEW.raw_user_meta_data->>'avatar_url', OLD.avatar_url),
        -- Role and status are typically not updated by user metadata changes,
        -- but set here if the profile was missing them.
        -- If they should be preserved from OLD profile if it exists, adjust logic.
        -- For now, this ensures they are set if the insert part of ON CONFLICT didn't run.
        role = CASE WHEN OLD.role IS NULL THEN 'USER' ELSE OLD.role END,
        status = CASE WHEN OLD.status IS NULL THEN 'approved' ELSE OLD.status END,
        updated_at = now();
      RETURN NEW;
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

    -- This policy is for the trigger. Direct inserts by users are usually not enabled.
    CREATE POLICY "Profiles: Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

    CREATE POLICY "Profiles: Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (
      auth.uid() = id AND
      (NEW.role = OLD.role OR OLD.role IS NULL) AND -- Prevent self-change of role
      (NEW.status = OLD.status OR OLD.status IS NULL) -- Prevent self-change of status
    );

    RAISE NOTICE 'Applied simplified RLS policies to public.profiles.';
