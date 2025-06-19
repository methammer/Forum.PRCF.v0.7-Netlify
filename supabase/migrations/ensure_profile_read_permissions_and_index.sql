/*
      # Ensure Profile Read Permissions and Index

      This migration ensures that the `authenticated` role has SELECT permissions
      on the `public.profiles` table and that an index exists on the `id` column.
      It also re-asserts all RLS policies for the profiles table.

      1. Security
         - Grants `SELECT` permission on `public.profiles` to the `authenticated` role.
           This is often default but explicitly stated here for robustness.
           RLS policies will still apply on top of this grant.
         - Drops the old "Allow authenticated users to read profiles" policy if it exists.
         - Re-creates the "Users can read their own profile" SELECT policy.
         - Re-creates INSERT and UPDATE policies for consistency.

      2. Performance
         - Attempts to create an index on `public.profiles(id)` using `IF NOT EXISTS`.
           Primary keys automatically get an index, so this is a safeguard. A custom
           name `idx_profiles_id_explicit` is used to avoid conflict with default PK index names.

      3. Changes
         - Explicitly grants SELECT on `public.profiles` to `authenticated`.
         - Ensures `id` column in `public.profiles` is indexed.
         - Cleans up and re-asserts all RLS policies on `public.profiles`.

      4. Important Notes
         - This migration aims to rule out underlying permission or indexing issues
           that could lead to query timeouts when fetching a user's own profile.
    */

    -- Grant SELECT on profiles table to authenticated role
    GRANT SELECT ON TABLE public.profiles TO authenticated;

    -- Create an index on profiles.id if it doesn't exist (PK should create one, but for safety)
    -- Using a different name for the index to avoid conflict if default PK index name is idx_profiles_id
    CREATE INDEX IF NOT EXISTS idx_profiles_id_explicit ON public.profiles(id);

    -- Ensure RLS is enabled (idempotent check)
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles' AND rowsecurity = 't'
      ) THEN
        ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
      END IF;
    END $$;

    -- Drop potentially conflicting or old SELECT policies
    DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
    DROP POLICY IF EXISTS "Users can read their own profile" ON public.profiles;

    -- Create the correct SELECT policy
    CREATE POLICY "Users can read their own profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

    -- Re-assert INSERT policy
    DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
    CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

    -- Re-assert UPDATE policy
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
