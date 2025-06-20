/*
  # Convert Profile Role to TEXT and Enforce Uppercase Values (v8)

  This migration addresses the "invalid input value for enum user_role" error
  and subsequent "check constraint violated" errors. It changes `public.profiles.role`
  to TEXT, ensures uppercase values, and adds a CHECK constraint.

  Version 8 temporarily disables user-defined triggers on `public.profiles`
  during data manipulation steps to prevent interference from triggers like
  `handle_profile_role_update_permissions` or `prevent_profile_id_role_change`.

  Changes:
  1.  RLS Policy Management:
      - Temporarily drops "Allow users to read posts" policy on `public.forum_posts`.
  2.  Trigger Management (`public.profiles`):
      - Temporarily disables ALL user-defined triggers.
  3.  Type Conversion (`public.profiles.role`):
      - Column type changed to `TEXT`.
      - If the column doesn't exist, it's added as TEXT.
      - Explicitly checks for and drops existing default constraint on `role`
        before type conversion (within a DO block).
  4.  Data Handling & Constraints (`public.profiles.role`):
      - Updates existing `NULL` roles to 'USER'.
      - Sets default value to `'USER'` (uppercase).
      - Column set to `NOT NULL`.
  5.  Data Migration (`public.profiles.role`):
      - Existing role values converted to uppercase.
  6.  Data Sanitization & Validation (`public.profiles.role`):
      - Updates any roles not in ('USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN') to 'USER'.
      - `CHECK` constraint `check_profile_role_values` added.
  7.  Trigger Management (`public.profiles`):
      - Re-enables ALL user-defined triggers.
  8.  RLS Policy Management (Recreation):
      - Recreates "Allow users to read posts" policy on `public.forum_posts`.
*/

-- Step 1: Temporarily drop the dependent RLS policy on forum_posts
DROP POLICY IF EXISTS "Allow users to read posts" ON public.forum_posts;

-- Step 2: Temporarily disable user-defined triggers on public.profiles
-- This will disable triggers like 'handle_profile_role_update_permissions'
-- and 'before_profile_update_prevent_id_role_change' during the data updates.
ALTER TABLE public.profiles DISABLE TRIGGER USER;

-- Step 3: Ensure 'role' column exists in profiles, convert its type to TEXT, and handle default constraint
DO $$
DECLARE
  column_default_exists BOOLEAN;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role' AND (data_type = 'text' OR udt_name = 'text')
    ) THEN
      RAISE NOTICE 'profiles.role exists but is not TEXT. Attempting conversion...';
      SELECT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attrdef ad
        JOIN pg_catalog.pg_attribute a ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
        JOIN pg_catalog.pg_class c ON c.oid = ad.adrelid
        WHERE c.relname = 'profiles'
          AND a.attname = 'role'
          AND c.relnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = 'public')
      ) INTO column_default_exists;

      IF column_default_exists THEN
        RAISE NOTICE 'Default constraint exists for profiles.role. Dropping it.';
        ALTER TABLE public.profiles ALTER COLUMN role DROP DEFAULT;
      ELSE
        RAISE NOTICE 'No default constraint found for profiles.role.';
      END IF;

      ALTER TABLE public.profiles ALTER COLUMN role TYPE TEXT USING role::text;
      RAISE NOTICE 'Successfully converted profiles.role to TEXT.';
    ELSE
      RAISE NOTICE 'profiles.role is already TEXT.';
    END IF;
  ELSE
    RAISE NOTICE 'profiles.role does not exist. Adding as TEXT.';
    ALTER TABLE public.profiles ADD COLUMN role TEXT;
  END IF;
END $$;

-- Step 4: Handle NULLs, set DEFAULT 'USER', and set NOT NULL for profiles.role
-- These UPDATEs will now run without interference from the disabled triggers.
UPDATE public.profiles SET role = 'USER' WHERE role IS NULL;
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'USER';
ALTER TABLE public.profiles ALTER COLUMN role SET NOT NULL;

-- Step 5: Uppercase all existing role values in profiles.role
UPDATE public.profiles
SET role = UPPER(role)
WHERE role IS NOT NULL;

-- Step 6: Sanitize non-standard roles and add CHECK constraint
UPDATE public.profiles
SET role = 'USER'
WHERE role NOT IN ('USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN');

DO $$
DECLARE
  constraint_name_var TEXT;
BEGIN
  RAISE NOTICE 'Dropping existing check_profile_role_values constraint if it exists...';
  SELECT conname INTO constraint_name_var
  FROM pg_constraint
  WHERE conrelid = 'public.profiles'::regclass
    AND conname LIKE 'check_profile_role_values%'
    AND pg_get_constraintdef(oid) LIKE '%role%IN%USER%';

  IF constraint_name_var IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name_var);
    RAISE NOTICE 'Dropped existing role check constraint: %', constraint_name_var;
  ELSE
    RAISE NOTICE 'No existing check_profile_role_values constraint found to drop.';
  END IF;
END $$;

ALTER TABLE public.profiles
  ADD CONSTRAINT check_profile_role_values
  CHECK (role IN ('USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN'));

-- Step 7: Re-enable user-defined triggers on public.profiles
ALTER TABLE public.profiles ENABLE TRIGGER USER;

-- Step 8: Recreate the RLS policy on forum_posts
CREATE POLICY "Allow users to read posts"
  ON public.forum_posts
  FOR SELECT
  TO authenticated
  USING (
    is_published = true OR
    (auth.uid() = user_id) OR
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  );

/*
  The `handle_new_user` trigger (from `0_create_profiles_table.sql`) inserts new profiles
  without specifying a role. After this migration, they will correctly receive the default 'USER' (TEXT).

  Administrative changes to roles are done via the `update-user-details-admin` Edge Function.
  With `profiles.role` as TEXT and triggers re-enabled, this should function correctly.
*/
