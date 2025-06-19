/*
  # Create profiles table and RLS policies (Idempotent)

  This migration creates the `profiles` table to store user-specific data,
  linked to the `auth.users` table. It also enables Row Level Security (RLS)
  and sets up initial policies. This version is idempotent and will drop
  existing policies and triggers before recreating them.

  1. New Tables
     - `public.profiles`
       - `id` (uuid, primary key): References `auth.users.id`. Deletes cascade.
       - `username` (text, unique, nullable): User's chosen username.
       - `full_name` (text, nullable): User's full name.
       - `avatar_url` (text, nullable): URL to the user's avatar image.
       - `updated_at` (timestamptz, default `now()`): Timestamp of the last update.
       - `created_at` (timestamptz, default `now()`): Timestamp of creation.

  2. Row Level Security (RLS)
     - Enabled RLS for `public.profiles`.
     - Policy: "Allow authenticated users to read profiles"
       - Grants `SELECT` access to all authenticated users on the `profiles` table.
     - Policy: "Users can insert their own profile"
        - Allows users to insert their own profile. The `id` must match `auth.uid()`.
     - Policy: "Users can update own profile"
        - Allows users to update their own profile. The `id` must match `auth.uid()`.

  3. Changes
     - Policies and triggers will be dropped if they exist and then recreated.

  4. Important Notes
     - The `profiles` table is designed for a one-to-one relationship with `auth.users`.
*/

-- Create the profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE,
  full_name text,
  avatar_url text,
  updated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security for the profiles table if not already enabled
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles' AND rowsecurity = 't'
  ) THEN
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;


-- Drop existing policies if they exist, then create them
DROP POLICY IF EXISTS "Allow authenticated users to read profiles" ON public.profiles;
CREATE POLICY "Allow authenticated users to read profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Function to create a profile when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'username', -- Attempt to get username from metadata
    NEW.raw_user_meta_data->>'full_name', -- Attempt to get full_name from metadata
    NEW.raw_user_meta_data->>'avatar_url' -- Attempt to get avatar_url from metadata
  )
  ON CONFLICT (id) DO NOTHING; -- Avoid error if profile already exists for some reason
  RETURN NEW;
END;
$$;

-- Trigger to call handle_new_user on new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
