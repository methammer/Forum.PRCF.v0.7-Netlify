/*
      # Update handle_new_user Function and Trigger (User Approval Workflow - Part 1a)

      This migration updates the `handle_new_user` function to ensure that all new user
      profiles are created with a 'pending_approval' status. It also ensures the
      trigger on `auth.users` is correctly set up to use this function.

      Changes:
      1.  **`public.handle_new_user()` Function Update**:
          - Modifies the trigger function `handle_new_user` that runs after a new user is
            created in `auth.users`.
          - Explicitly sets the `status` column in the `public.profiles` table to
            `'pending_approval'` for the newly created profile.
          - Sets a default `role` of 'USER'.
          - Uses `COALESCE` for `username` to handle different metadata keys from various
            auth providers or direct signup, falling back to user ID if no username metadata is found.
          - Uses `ON CONFLICT (id) DO NOTHING` to prevent errors if a profile record
            somehow already exists for the new user ID.
      2.  **Trigger `on_auth_user_created`**:
          - Ensures this trigger exists on `auth.users` and executes `public.handle_new_user()`.
          - The `DO $$ ... END $$;` block checks if the trigger exists and creates it if not,
            otherwise, it confirms its existence.
    */

    SET search_path = public, auth;

    -- Step 1: Update the handle_new_user function to set default status to 'pending_approval'
    CREATE OR REPLACE FUNCTION public.handle_new_user()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER -- Crucial for accessing auth.users and inserting into public.profiles
    SET search_path = public -- Inner search_path for function execution
    AS $$
    BEGIN
      INSERT INTO public.profiles (id, email, username, full_name, avatar_url, role, status)
      VALUES (
        new.id,
        new.email, -- Direct from auth.users
        COALESCE(new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'user_name', new.id::text), -- Prioritize 'username', fallback to 'user_name', then user_id
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'avatar_url',
        'USER',             -- Default role is TEXT 'USER'
        'pending_approval'  -- Explicitly set status to 'pending_approval'
      )
      ON CONFLICT (id) DO NOTHING;
      RETURN new;
    END;
    $$;

    -- Step 2: Ensure the trigger is correctly associated with auth.users table
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'on_auth_user_created' AND tgrelid = 'auth.users'::regclass
      ) THEN
        CREATE TRIGGER on_auth_user_created
          AFTER INSERT ON auth.users
          FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
        RAISE NOTICE 'Trigger on_auth_user_created created on auth.users.';
      ELSE
        -- If trigger exists, ensure it's using the latest version of the function.
        -- The CREATE OR REPLACE FUNCTION above handles updating the function itself.
        RAISE NOTICE 'Trigger on_auth_user_created already exists on auth.users. The public.handle_new_user function has been updated/reaffirmed by this script.';
      END IF;
    END $$;
