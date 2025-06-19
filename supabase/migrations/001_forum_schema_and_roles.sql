/*
      # Forum Core Schema and Basic Roles Setup

      This migration establishes the core tables for the forum functionality (topics, posts, sections)
      and sets up initial Row Level Security (RLS) policies primarily for the 'USER' role,
      along with foundational RLS for admin/moderator access to sections.
      It also ensures the `user_role_enum` type and the `role` and `status` columns in the `profiles` table are correctly defined.

      1.  **Types**
          *   Creates `user_role_enum` ('USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN') if it doesn't exist.

      2.  **Table Modifications**
          *   `profiles`:
              *   Ensures `role` column of type `user_role_enum` exists, defaulting to 'USER'.
              *   Ensures `status` column of type `text` exists, defaulting to 'pending_approval'.

      3.  **New Tables**
          *   `sections`: For forum categories/sections.
              *   `id` (uuid, pk)
              *   `title` (text, unique, not null)
              *   `description` (text)
              *   `slug` (text, unique, not null)
              *   `created_at` (timestamptz, default now())
          *   `topics`: For forum discussion threads.
              *   `id` (uuid, pk)
              *   `user_id` (uuid, fk to auth.users, not null)
              *   `section_id` (uuid, fk to sections, not null)
              *   `title` (text, not null)
              *   `created_at` (timestamptz, default now())
              *   `updated_at` (timestamptz, default now())
              *   `is_pinned` (boolean, default false)
              *   `is_locked` (boolean, default false)
          *   `posts`: For individual messages within topics.
              *   `id` (uuid, pk)
              *   `user_id` (uuid, fk to auth.users, not null)
              *   `topic_id` (uuid, fk to topics, not null)
              *   `content` (text, not null)
              *   `created_at` (timestamptz, default now())
              *   `updated_at` (timestamptz, default now())

      4.  **Security (RLS)**
          *   Enables RLS on `sections`, `topics`, and `posts`.
          *   `profiles`: (RLS policies for profiles are assumed to exist from previous migrations and are critical for role checks).
          *   `sections`:
              *   Authenticated users can read.
              *   ADMIN and SUPER_ADMIN can perform all operations (create, read, update, delete).
          *   `topics`:
              *   Authenticated users can read.
              *   Authenticated users can create their own topics.
              *   Authenticated users can update their own topics.
              *   Authenticated users can delete their own topics.
          *   `posts`:
              *   Authenticated users can read.
              *   Authenticated users can create their own posts.
              *   Authenticated users can update their own posts.
              *   Authenticated users can delete their own posts.

      5.  **Important Notes**
          *   This migration lays the groundwork. More specific RLS policies for MODERATOR, ADMIN, and SUPER_ADMIN roles, especially for modifying/deleting others' content, will often be handled by Edge Functions as per the cahier des charges for enhanced security and complexity management.
          *   The `slug` column in `sections` should be generated (e.g., from the title) upon creation, typically by application logic or a database trigger (trigger not included in this migration).
    */

    -- 0. Create ENUM for user roles if it doesn't exist
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_enum') THEN
            CREATE TYPE user_role_enum AS ENUM ('USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN');
        END IF;
    END $$;

    -- 1. Ensure 'profiles' table has 'role' and 'status' columns
    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
        ) THEN
            ALTER TABLE public.profiles ADD COLUMN role user_role_enum DEFAULT 'USER';
        ELSE
            -- If column exists but type is different, this might be more complex.
            -- For now, assume if it exists, it's of a compatible or correct type.
            -- A more robust script might drop and recreate or alter type if necessary and safe.
            ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'USER';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'status'
        ) THEN
            ALTER TABLE public.profiles ADD COLUMN status TEXT DEFAULT 'pending_approval';
        ELSE
            ALTER TABLE public.profiles ALTER COLUMN status SET DEFAULT 'pending_approval';
        END IF;
    END $$;

    -- 2. Create 'sections' table
    CREATE TABLE IF NOT EXISTS public.sections (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL UNIQUE,
        description TEXT,
        slug TEXT NOT NULL UNIQUE,
        created_at TIMESTAMPTZ DEFAULT now()
    );
    COMMENT ON TABLE public.sections IS 'Forum sections or categories.';

    -- 3. Create 'topics' table
    CREATE TABLE IF NOT EXISTS public.topics (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        section_id uuid NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ DEFAULT now(),
        is_pinned BOOLEAN DEFAULT false,
        is_locked BOOLEAN DEFAULT false
    );
    COMMENT ON TABLE public.topics IS 'Discussion threads within sections.';
    CREATE INDEX IF NOT EXISTS idx_topics_user_id ON public.topics(user_id);
    CREATE INDEX IF NOT EXISTS idx_topics_section_id ON public.topics(section_id);

    -- 4. Create 'posts' table
    CREATE TABLE IF NOT EXISTS public.posts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        topic_id uuid NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ DEFAULT now()
    );
    COMMENT ON TABLE public.posts IS 'Individual messages within topics.';
    CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
    CREATE INDEX IF NOT EXISTS idx_posts_topic_id ON public.posts(topic_id);

    -- 5. Enable RLS for new tables
    ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.topics ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

    -- 6. RLS Policies for 'sections'
    DROP POLICY IF EXISTS "Allow all users to read sections" ON public.sections;
    CREATE POLICY "Allow all users to read sections"
    ON public.sections FOR SELECT
    TO authenticated
    USING (true);

    DROP POLICY IF EXISTS "Allow admins to manage sections" ON public.sections;
    CREATE POLICY "Allow admins to manage sections"
    ON public.sections FOR ALL
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('ADMIN', 'SUPER_ADMIN')
    )
    WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('ADMIN', 'SUPER_ADMIN')
    );

    -- 7. RLS Policies for 'topics'
    DROP POLICY IF EXISTS "Allow all users to read topics" ON public.topics;
    CREATE POLICY "Allow all users to read topics"
    ON public.topics FOR SELECT
    TO authenticated
    USING (true);

    DROP POLICY IF EXISTS "Allow authenticated users to create topics" ON public.topics;
    CREATE POLICY "Allow authenticated users to create topics"
    ON public.topics FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Allow users to update their own topics" ON public.topics;
    CREATE POLICY "Allow users to update their own topics"
    ON public.topics FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Allow users to delete their own topics" ON public.topics;
    CREATE POLICY "Allow users to delete their own topics"
    ON public.topics FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

    -- 8. RLS Policies for 'posts'
    DROP POLICY IF EXISTS "Allow all users to read posts" ON public.posts;
    CREATE POLICY "Allow all users to read posts"
    ON public.posts FOR SELECT
    TO authenticated
    USING (true);

    DROP POLICY IF EXISTS "Allow authenticated users to create posts" ON public.posts;
    CREATE POLICY "Allow authenticated users to create posts"
    ON public.posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Allow users to update their own posts" ON public.posts;
    CREATE POLICY "Allow users to update their own posts"
    ON public.posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

    DROP POLICY IF EXISTS "Allow users to delete their own posts" ON public.posts;
    CREATE POLICY "Allow users to delete their own posts"
    ON public.posts FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
