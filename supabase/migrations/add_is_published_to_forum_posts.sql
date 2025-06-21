/*
      # Ajout du statut de publication aux messages du forum

      Cette migration ajoute un champ `is_published` à la table `forum_posts`
      pour contrôler la visibilité des messages (par exemple, brouillons vs contenu publié).

      1. Modifications de la table
         - `public.forum_posts`:
           - Ajout de `is_published` (boolean, not null, default false): Indique si un message est publié.
             `false` signifie qu'il s'agit d'un brouillon, `true` qu'il est publié.

      2. Ajustements initiaux des politiques RLS
         - La politique de base existante "Allow authenticated users to read posts" sur `forum_posts`
           devient trop permissive une fois `is_published` introduit.
         - Cette migration mettra à jour la politique de lecture de base pour n'autoriser que la visualisation
           des messages publiés.
         - Des politiques plus granulaires prenant en compte les rôles et la propriété seront (ou sont)
           définies dans des migrations ultérieures (par exemple, `003_add_deletion_fields_to_content_tables.sql`).

      3. Notes importantes
         - Le fait de définir `is_published` par défaut à `false` signifie que les nouveaux messages sont
           des brouillons par défaut.
         - Les messages existants (s'il y en a) seront également marqués comme `is_published = false` après
           l'exécution de cette migration, à moins d'être mis à jour manuellement ou par un script ultérieur.
           C'est un comportement par défaut sûr. Si vous avez des messages existants qui devraient être publiés,
           une migration de données pourrait être nécessaire. Pour l'instant, nous supposons une nouvelle configuration
           ou que ce comportement est acceptable.
    */

    -- Ajouter la colonne is_published à forum_posts
    ALTER TABLE public.forum_posts
    ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;

    -- Mettre à jour la politique RLS SELECT de base sur forum_posts.
    -- Les politiques plus spécifiques dans 003_add_deletion_fields_to_content_tables.sql
    -- vont supprimer et remplacer celle-ci. Cependant, c'est une bonne pratique de rendre
    -- la politique de base plus sûre en attendant.

    -- L'ancienne politique était : CREATE POLICY "Allow authenticated users to read posts" ON public.forum_posts FOR SELECT TO authenticated USING (true);
    -- Nous la remplaçons par une qui prend en compte is_published.
    DROP POLICY IF EXISTS "Allow authenticated users to read posts" ON public.forum_posts;

    CREATE POLICY "Allow authenticated users to read published posts"
    ON public.forum_posts
    FOR SELECT
    TO authenticated
    USING (is_published = true);

    -- Note: Les politiques pour INSERT, UPDATE, DELETE sur forum_posts de create_forum_tables.sql
    -- (Les utilisateurs peuvent insérer/mettre à jour/supprimer leurs propres messages) ne référencent pas explicitement is_published.
    -- Cela signifie que les utilisateurs peuvent toujours gérer leurs propres messages quel que soit leur état de publication,
    -- ce qui est généralement acceptable. Les politiques plus complexes dans 003_... affineront considérablement l'accès en lecture.
