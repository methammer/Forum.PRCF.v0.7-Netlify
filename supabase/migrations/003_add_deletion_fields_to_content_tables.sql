/*
      # Ajout des champs de suppression et mise à jour RLS pour forum_posts et forum_replies

      1. Modifications des Tables
        - `forum_posts`:
          - Ajout `is_deleted` (boolean, default false)
          - Ajout `deleted_at` (timestamptz, nullable)
          - Ajout `deleted_by_user_id` (uuid, fk->profiles, nullable)
          - Ajout `deleted_reason` (text, nullable)
        - `forum_replies`:
          - Ajout `is_deleted` (boolean, default false)
          - Ajout `deleted_at` (timestamptz, nullable)
          - Ajout `deleted_by_user_id` (uuid, fk->profiles, nullable)
          - Ajout `deleted_reason` (text, nullable)

      2. Sécurité (RLS)
        - Mise à jour des politiques SELECT pour `forum_posts` et `forum_replies`:
          - Les utilisateurs normaux ne voient pas le contenu marqué `is_deleted = true`.
          - Les modérateurs/administrateurs voient tout le contenu, y compris celui marqué `is_deleted = true` (selon la visibilité de la catégorie pour les posts publiés).
        - Nouvelles politiques UPDATE pour `forum_posts` et `forum_replies`:
          - Autorisent les modérateurs/administrateurs à modifier les champs (nécessaire pour marquer comme supprimé via RPC).
          - Note: Les politiques existantes permettant aux auteurs de modifier leur propre contenu (non supprimé) et aux modérateurs de tout modifier restent en place et sont complétées par ces politiques plus spécifiques au contexte de la suppression.
    */

    -- Add deletion fields to forum_posts
    ALTER TABLE public.forum_posts
    ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
    ADD COLUMN IF NOT EXISTS deleted_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS deleted_reason text;

    -- Add deletion fields to forum_replies
    ALTER TABLE public.forum_replies
    ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
    ADD COLUMN IF NOT EXISTS deleted_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS deleted_reason text;


    -- RLS Policies for forum_posts (SELECT)
    -- Drop existing broad SELECT policies or potentially conflicting ones before creating new, more specific ones.
    DROP POLICY IF EXISTS "Allow authenticated users to read all posts" ON public.forum_posts;
    DROP POLICY IF EXISTS "Users can view published posts in public or member-only private categories" ON public.forum_posts; -- Old name if existed
    DROP POLICY IF EXISTS "Admins can view all posts" ON public.forum_posts; -- Old name if existed
    DROP POLICY IF EXISTS "Authors can view their own unpublished posts" ON public.forum_posts; -- Old name if existed
    DROP POLICY IF EXISTS "Enable read access for all users" ON public.forum_posts; -- Generic policy if exists
    DROP POLICY IF EXISTS "Allow authenticated users to read published posts" ON public.forum_posts; -- From previous step


    CREATE POLICY "Users can view non-deleted, published posts based on category visibility"
      ON public.forum_posts
      FOR SELECT
      TO authenticated
      USING (
        is_published = true AND is_deleted = false AND
        (
          (SELECT visibility FROM public.forum_categories WHERE id = forum_posts.category_id) = 'public' OR
          (
            (SELECT visibility FROM public.forum_categories WHERE id = forum_posts.category_id) = 'private' AND
            is_category_member(forum_posts.category_id, auth.uid())
          )
        )
      );

    CREATE POLICY "Authors can view their own non-deleted, unpublished posts"
      ON public.forum_posts
      FOR SELECT
      TO authenticated
      USING (
        user_id = auth.uid() AND is_published = false AND is_deleted = false
      );
      
    CREATE POLICY "Moderators and admins can view all posts (including deleted/unpublished) based on category visibility"
      ON public.forum_posts
      FOR SELECT
      TO authenticated
      USING (
        get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN') AND
        ( -- For published posts, respect category visibility even for mods
          is_published = true AND
          (
            (SELECT visibility FROM public.forum_categories WHERE id = forum_posts.category_id) = 'public' OR
            (
              (SELECT visibility FROM public.forum_categories WHERE id = forum_posts.category_id) = 'private' AND
              is_category_member(forum_posts.category_id, auth.uid()) -- Mods still need to be member of private categories
            )
          )
        OR -- For unpublished posts, mods/admins can see them directly regardless of category membership
          is_published = false 
        )
        -- No 'is_deleted' check here for mods, so they see deleted posts too.
      );

    -- RLS Policies for forum_posts (UPDATE for deletion by mods)
    -- This policy allows moderators to update fields. The soft_delete_content RPC will use this permission.
    -- It complements the existing "Allow admins and moderators to update any post" policy.
    DROP POLICY IF EXISTS "Moderators and admins can mark posts as deleted" ON public.forum_posts;
    CREATE POLICY "Moderators and admins can mark posts as deleted"
      ON public.forum_posts
      FOR UPDATE
      TO authenticated
      USING (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'))
      WITH CHECK (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));


    -- RLS Policies for forum_replies (SELECT)
    DROP POLICY IF EXISTS "Allow authenticated users to read all replies" ON public.forum_replies;
    DROP POLICY IF EXISTS "Users can view replies to posts they can access" ON public.forum_replies; -- Old name if existed
    DROP POLICY IF EXISTS "Admins can view all replies" ON public.forum_replies; -- Old name if existed
    DROP POLICY IF EXISTS "Enable read access for all replies" ON public.forum_replies; -- Generic policy if exists

    CREATE POLICY "Users can view non-deleted replies to posts they can access"
      ON public.forum_replies
      FOR SELECT
      TO authenticated
      USING (
        is_deleted = false AND
        EXISTS (
          SELECT 1
          FROM public.forum_posts fp
          WHERE fp.id = forum_replies.post_id AND
          fp.is_published = true AND fp.is_deleted = false AND -- Parent post must be visible and not deleted
          (
            (SELECT visibility FROM public.forum_categories WHERE id = fp.category_id) = 'public' OR
            (
              (SELECT visibility FROM public.forum_categories WHERE id = fp.category_id) = 'private' AND
              is_category_member(fp.category_id, auth.uid())
            )
          )
        )
      );

    CREATE POLICY "Moderators and admins can view all replies (including deleted)"
      ON public.forum_replies
      FOR SELECT
      TO authenticated
      USING (
        get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN') AND
         EXISTS ( -- Still ensure parent post exists and respect its category visibility for mods too
          SELECT 1
          FROM public.forum_posts fp
          WHERE fp.id = forum_replies.post_id AND
           ( -- For published posts, respect category visibility
            fp.is_published = true AND
            (
              (SELECT visibility FROM public.forum_categories WHERE id = fp.category_id) = 'public' OR
              (
                (SELECT visibility FROM public.forum_categories WHERE id = fp.category_id) = 'private' AND
                is_category_member(fp.category_id, auth.uid()) -- Mods still need to be member of private categories
              )
            )
            OR -- For unpublished posts (parent), mods/admins can see them directly
            fp.is_published = false 
            -- No 'fp.is_deleted' check here for parent post for mods, allowing them to see replies to deleted posts.
            -- No 'forum_replies.is_deleted' check here for mods, so they see deleted replies too.
          )
        )
      );

    -- RLS Policies for forum_replies (UPDATE for deletion by mods)
    -- This policy allows moderators to update fields. The soft_delete_content RPC will use this permission.
    -- It complements the existing "Allow admins and moderators to update any reply" policy.
    DROP POLICY IF EXISTS "Moderators and admins can mark replies as deleted" ON public.forum_replies;
    CREATE POLICY "Moderators and admins can mark replies as deleted"
      ON public.forum_replies
      FOR UPDATE
      TO authenticated
      USING (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'))
      WITH CHECK (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));