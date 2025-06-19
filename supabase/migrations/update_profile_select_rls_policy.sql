/*
      # Update SELECT RLS Policy for Profiles Table

      This migration updates the Row Level Security (RLS) policy for SELECT
      operations on the `public.profiles` table.

      1. New Tables
         - None

      2. Security
         - `public.profiles`:
           - The existing policy "Allow authenticated users to read profiles" which used `USING (auth.role() = 'authenticated')` is DROPPED.
           - A new policy "Users can read their own profile" is CREATED. This policy restricts SELECT access so that authenticated users can only read their own profile row, identified by `auth.uid() = id`.

      3. Changes
         - Modifies the RLS SELECT policy on `public.profiles` to be more restrictive and specific.
         - This is a security best practice and may improve query performance for fetching a user's own profile.

      4. Important Notes
         - INSERT and UPDATE policies remain unchanged as they already correctly use `auth.uid() = id`.
         - This change ensures that users cannot accidentally (or intentionally, if other layers of security were bypassed) read other users' profile data via direct database queries if they are authenticated.
    */

    -- Drop the existing broad SELECT policy
    DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;

    -- Create a new, more specific SELECT policy
    CREATE POLICY "Users can read their own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

    -- The following policies for INSERT and UPDATE remain suitable and are re-stated for clarity
    -- but are not strictly changed by this migration if they already exist as defined.

    -- Ensure RLS is enabled (idempotent check)
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles' AND rowsecurity = 't'
      ) THEN
        ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
      END IF;
    END $$;

    -- Re-apply INSERT policy (if it was somehow dropped or to ensure it's correct)
    -- This policy should already be in place from previous migrations.
    DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
    CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

    -- Re-apply UPDATE policy (if it was somehow dropped or to ensure it's correct)
    -- This policy should already be in place from previous migrations.
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
