/*
      # Add status column to profiles and update RLS policies

      This migration introduces an approval system for user profiles.

      1. New Columns
         - `public.profiles`
           - `status` (text, default 'pending_approval'): Stores the approval status of the user's profile.
             Possible values: 'pending_approval', 'approved', 'rejected'.

      2. Row Level Security (RLS)
         - `public.profiles`:
           - The policy "Allow authenticated users to read profiles" remains, as access control will primarily be handled at the application layer (login and protected routes). Authenticated users (even pending approval) can read their own profile to check status.
           - The policies "Users can insert their own profile" and "Users can update own profile" remain unchanged. The `status` column will default to 'pending_approval' on insert. Admins will be responsible for changing this status.

      3. Changes
         - Adds `status` column to `profiles` table with a default value and a check constraint.

      4. Important Notes
         - The `handle_new_user` trigger does not need to be modified; it will continue to populate `username` and `full_name` if provided during sign-up, and the `status` column will automatically get its default value.
         - Admin interface/logic for approving users is not part of this migration and will need to be implemented separately.
    */

    -- Add the status column to the profiles table if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'profiles' AND column_name = 'status' AND table_schema = 'public'
      ) THEN
        ALTER TABLE public.profiles
        ADD COLUMN status TEXT DEFAULT 'pending_approval' NOT NULL CHECK (status IN ('pending_approval', 'approved', 'rejected'));
      END IF;
    END $$;

    -- Ensure RLS is enabled (idempotent check)
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles' AND rowsecurity = 't'
      ) THEN
        ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
      END IF;
    END $$;

    -- Re-apply policies to ensure they are up-to-date, though their core logic for user self-management doesn't change regarding status.
    -- The control for "approved" users accessing the app is primarily at the application layer.

    DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
    CREATE POLICY "Allow authenticated users to read profiles"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.role() = 'authenticated'); -- Users can read profiles, app logic will gate access based on status.

    DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
    CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id); -- Status will default to 'pending_approval'

    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id); -- Users can update their details, status change is an admin action.
