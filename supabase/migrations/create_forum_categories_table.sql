<![CDATA[
/*
  # Create forum_categories table and RLS policies

  This migration creates the `forum_categories` table to store forum categories.
  It also enables Row Level Security (RLS) and sets up policies for managing categories.

  1. New Table: `public.forum_categories`
     - `id` (uuid, primary key): Unique identifier for the category, auto-generated.
     - `name` (text, not null, unique): The name of the category.
     - `description` (text, nullable): A short description of the category.
     - `created_at` (timestamptz, default `now()`): Timestamp of when the category was created.
     - `slug` (text, not null, unique): A URL-friendly slug for the category.

  2. Row Level Security (RLS)
     - Enabled RLS for `public.forum_categories`.
     - Policy: "Allow authenticated users to read categories"
       - Grants `SELECT` access to all authenticated users.
     - Policy: "Allow admins to manage categories"
       - Grants `INSERT`, `UPDATE`, `DELETE` access to users with 'ADMIN' or 'SUPER_ADMIN' role in their profile.

  3. Functions & Triggers
     - `public.slugify(text)`: A function to generate URL-friendly slugs.
     - `public.set_slug_from_name_categories()`: A trigger function to automatically generate/update the slug from the name.
     - Trigger `handle_category_slug_generation`: Before INSERT or UPDATE on `forum_categories`, calls `set_slug_from_name_categories`.

  4. Important Notes
     - The `slug` column is crucial for creating user-friendly URLs for categories.
     - Admin roles are checked against the `profiles` table.
*/

-- Function to generate a slug from a text string
CREATE OR REPLACE FUNCTION public.slugify(value TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Remove accents
  value := unaccent(value);
  -- Replace non-alphanumeric characters with a hyphen
  value := lower(regexp_replace(value, '[^a-z0-9\-_]+', '-', 'gi'));
  -- Remove leading and trailing hyphens
  value := regexp_replace(value, '^-+|-+$', '', 'g');
  RETURN value;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create the forum_categories table
CREATE TABLE IF NOT EXISTS public.forum_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  slug text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security for the forum_categories table
ALTER TABLE public.forum_categories ENABLE ROW LEVEL SECURITY;

-- Function to set slug from name for forum_categories
CREATE OR REPLACE FUNCTION public.set_slug_from_name_categories()
RETURNS TRIGGER AS $$
BEGIN
  NEW.slug := public.slugify(NEW.name);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically generate slug on insert or update of name
DROP TRIGGER IF EXISTS handle_category_slug_generation ON public.forum_categories;
CREATE TRIGGER handle_category_slug_generation
  BEFORE INSERT OR UPDATE OF name ON public.forum_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.set_slug_from_name_categories();

-- RLS Policies for forum_categories
DROP POLICY IF EXISTS "Allow authenticated users to read categories" ON public.forum_categories;
CREATE POLICY "Allow authenticated users to read categories"
  ON public.forum_categories
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow admins to insert categories" ON public.forum_categories;
CREATE POLICY "Allow admins to insert categories"
  ON public.forum_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role = 'ADMIN' OR profiles.role = 'SUPER_ADMIN')
    )
  );

DROP POLICY IF EXISTS "Allow admins to update categories" ON public.forum_categories;
CREATE POLICY "Allow admins to update categories"
  ON public.forum_categories
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role = 'ADMIN' OR profiles.role = 'SUPER_ADMIN')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role = 'ADMIN' OR profiles.role = 'SUPER_ADMIN')
    )
  );

DROP POLICY IF EXISTS "Allow admins to delete categories" ON public.forum_categories;
CREATE POLICY "Allow admins to delete categories"
  ON public.forum_categories
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid() AND (profiles.role = 'ADMIN' OR profiles.role = 'SUPER_ADMIN')
    )
  );
      ]]>
