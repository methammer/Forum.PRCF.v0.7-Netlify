<![CDATA[
/*
  # Add biography and signature to profiles

  This migration adds `biography` and `signature` columns to the `public.profiles` table.

  1. New Columns in `public.profiles`
     - `biography` (text, nullable): User's biography.
     - `signature` (text, nullable): User's forum signature.

  2. Security
     - Existing RLS policies for `UPDATE` on `profiles` should cover these new columns,
       allowing users to update their own biography and signature.

  3. Changes
     - Adds `biography` column to `profiles` if it doesn't exist.
     - Adds `signature` column to `profiles` if it doesn't exist.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'biography'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN biography text;
    RAISE NOTICE 'Column biography added to public.profiles';
  ELSE
    RAISE NOTICE 'Column biography already exists in public.profiles';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'signature'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN signature text;
    RAISE NOTICE 'Column signature added to public.profiles';
  ELSE
    RAISE NOTICE 'Column signature already exists in public.profiles';
  END IF;
END $$;
      ]]>