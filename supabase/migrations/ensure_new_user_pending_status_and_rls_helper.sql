/*
  # Ensure New User Pending Status and Create RLS Helper (User Approval Workflow - Part 1)

  This migration ensures that all new user profiles are created with a 'pending_approval'
  status and introduces a helper function `is_user_approved()` for RLS policies.

  Changes:
  1.  **`public.handle_new_user()` Function Update**:
      - Modifies the trigger function `handle_new_user` that runs after a new user is
        created in `auth.users`.
      - Explicitly sets the `status` column in the `public.profiles` table to
        `'pending_approval'` for the newly created profile.
      - Uses `COALESCE` for `username` to handle different metadata keys from various
        auth providers or direct signup.
      - Uses `ON CONFLICT (id) DO NOTHING` to prevent errors if a profile record
        somehow already exists for the new user ID.

  2.  **`public.is_user_approved()` Helper Function**:
      - Creates a new SQL function `is_user_approved()`.
      - This function returns `true` if the currently authenticated user has a profile
        with `status = 'approved'`, and `false` otherwise.
      - It will be used in RLS policies to restrict access for non-approved users.
      - Granted `EXECUTE` permission to `authenticated` users.
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

-- Ensure the trigger is correctly associated with auth.users table
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
    -- This typically requires DROP and CREATE, but for now, we assume it's correct or will be updated if function definition changes.
    RAISE NOTICE 'Trigger on_auth_user_created already exists on auth.users. Ensure it uses the updated public.handle_new_user function.';
  END IF;
END $$;


-- Step 2: Create helper function to check if user is approved
CREATE OR REPLACE FUNCTION public.is_user_approved()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER -- Checks the status of the user calling the function
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND status = 'approved'
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_user_approved() TO authenticated;