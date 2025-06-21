/*
      # Ajout de la colonne visibility à forum_categories

      Cette migration ajoute une colonne `visibility` à la table `forum_categories`.
      Cette colonne déterminera qui peut voir les posts au sein d'une catégorie (par exemple, 'public' ou 'private').

      1. Nouveau Type Enum: `public.category_visibility_type`
         - Valeurs: 'public', 'private'

      2. Modification de Table: `public.forum_categories`
         - Ajout de la colonne `visibility` (type `public.category_visibility_type`, NOT NULL, DEFAULT 'public').

      3. Important
         - Cette colonne est essentielle pour les politiques RLS sur `forum_posts` et `forum_replies`
           afin de contrôler l'accès en fonction de la visibilité de la catégorie.
    */

    -- Create the ENUM type for category visibility if it doesn't exist
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_visibility_type') THEN
        CREATE TYPE public.category_visibility_type AS ENUM ('public', 'private');
      END IF;
    END$$;

    -- Add the visibility column to the forum_categories table
    ALTER TABLE public.forum_categories
    ADD COLUMN IF NOT EXISTS visibility public.category_visibility_type NOT NULL DEFAULT 'public';

    -- Note: Existing RLS policies on forum_categories itself might need review
    -- if category visibility should restrict who can see the categories themselves,
    -- but for now, this column is primarily for RLS on posts/replies within these categories.
    -- The existing policy "Allow authenticated users to read categories" remains,
    -- meaning all authenticated users can see all categories, but the content within
    -- will be filtered by the RLS on posts/replies using this new visibility column.
