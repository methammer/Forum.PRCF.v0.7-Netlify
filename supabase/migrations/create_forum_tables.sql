/*
  # Create Forum Tables and RLS Policies

  This migration creates the `forum_categories` and `forum_posts` tables
  to store forum data, along with their respective Row Level Security (RLS) policies.

  1. New Tables
     - `public.forum_categories`
       - `id` (uuid, primary key): Unique identifier for the category.
       - `name` (text, not null, unique): Display name of the category.
       - `description` (text, nullable): A brief description of the category.
       - `slug` (text, not null, unique): URL-friendly slug for the category.
       - `created_at` (timestamptz, default `now()`): Timestamp of creation.
     - `public.forum_posts`
       - `id` (uuid, primary key): Unique identifier for the post.
       - `user_id` (uuid, foreign key): References `auth.users.id`. The author of the post.
       - `category_id` (uuid, foreign key): References `forum_categories.id`. The category this post belongs to.
       - `title` (text, not null): The title of the post.
       - `content` (text, not null): The main content of the post.
       - `created_at` (timestamptz, default `now()`): Timestamp of creation.
       - `updated_at` (timestamptz, default `now()`): Timestamp of the last update.

  2. Row Level Security (RLS)
     - Enabled RLS for `forum_categories`.
       - Policy: "Allow authenticated users to read categories"
         - Grants `SELECT` access to all authenticated users.
     - Enabled RLS for `forum_posts`.
       - Policy: "Allow authenticated users to read posts"
         - Grants `SELECT` access to all authenticated users.
       - Policy: "Users can insert their own posts"
         - Allows authenticated users to insert posts where `user_id` matches `auth.uid()`.
       - Policy: "Users can update their own posts"
         - Allows authenticated users to update their own posts.
       - Policy: "Users can delete their own posts"
         - Allows authenticated users to delete their own posts.

  3. Indexes
     - Index on `forum_posts(user_id)`
     - Index on `forum_posts(category_id)`

  4. Important Notes
     - The `slug` for categories should be unique and can be generated from the name.
     - `user_id` in `forum_posts` links directly to `auth.users` for easy association with authenticated users.
*/

-- Create forum_categories table
CREATE TABLE IF NOT EXISTS public.forum_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  slug text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS for forum_categories
ALTER TABLE public.forum_categories ENABLE ROW LEVEL SECURITY;

-- Policies for forum_categories
DROP POLICY IF EXISTS "Allow authenticated users to read categories" ON public.forum_categories;
CREATE POLICY "Allow authenticated users to read categories"
ON public.forum_categories
FOR SELECT
TO authenticated
USING (true);

-- For now, only allow read. Admin/specific roles might create/update categories later.
-- Example: To allow authenticated users to create categories (if desired)
-- DROP POLICY IF EXISTS "Allow authenticated users to create categories" ON public.forum_categories;
-- CREATE POLICY "Allow authenticated users to create categories"
-- ON public.forum_categories
-- FOR INSERT
-- TO authenticated
-- WITH CHECK (true);


-- Create forum_posts table
CREATE TABLE IF NOT EXISTS public.forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.forum_categories(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add indexes for foreign keys on forum_posts
CREATE INDEX IF NOT EXISTS idx_forum_posts_user_id ON public.forum_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_forum_posts_category_id ON public.forum_posts(category_id);

-- Enable RLS for forum_posts
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;

-- Policies for forum_posts
DROP POLICY IF EXISTS "Allow authenticated users to read posts" ON public.forum_posts;
CREATE POLICY "Allow authenticated users to read posts"
ON public.forum_posts
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Users can insert their own posts" ON public.forum_posts;
CREATE POLICY "Users can insert their own posts"
ON public.forum_posts
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own posts" ON public.forum_posts;
CREATE POLICY "Users can update their own posts"
ON public.forum_posts
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own posts" ON public.forum_posts;
CREATE POLICY "Users can delete their own posts"
ON public.forum_posts
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for forum_posts updated_at
DROP TRIGGER IF EXISTS handle_updated_at ON public.forum_posts;
CREATE TRIGGER handle_updated_at
  BEFORE UPDATE ON public.forum_posts
  FOR EACH ROW
  EXECUTE PROCEDURE public.update_updated_at_column();

-- Seed some initial categories (optional, can be done via UI later)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.forum_categories WHERE slug = 'discussions-generales') THEN
    INSERT INTO public.forum_categories (name, description, slug)
    VALUES ('Discussions Générales', 'Pour toutes les discussions générales.', 'discussions-generales');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.forum_categories WHERE slug = 'annonces-internes') THEN
    INSERT INTO public.forum_categories (name, description, slug)
    VALUES ('Annonces Internes', 'Annonces importantes pour les membres du PRCF.', 'annonces-internes');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.forum_categories WHERE slug = 'projets-en-cours') THEN
    INSERT INTO public.forum_categories (name, description, slug)
    VALUES ('Projets en Cours', 'Discussions autour des projets actifs.', 'projets-en-cours');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.forum_categories WHERE slug = 'support-technique') THEN
    INSERT INTO public.forum_categories (name, description, slug)
    VALUES ('Support Technique', 'Aide et support technique pour les outils du PRCF.', 'support-technique');
  END IF;
END $$;
