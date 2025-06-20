/*
  # Mise à Jour des RLS pour Visibilité et Modération du Contenu

  Cette migration affine les politiques de sécurité (RLS) pour les tables `forum_posts` et `forum_replies`
  afin de gérer correctement la visibilité du contenu supprimé (soft-deleted) et d'assurer
  que les modérateurs disposent des permissions de mise à jour nécessaires pour la suppression douce.

  1. Modifications des Politiques RLS pour `public.forum_posts`:
     - **SELECT ("Allow users to read posts")**:
       - Modifiée pour que les utilisateurs standards ne voient que les posts `is_published = true` ET `is_deleted = false`.
       - Les utilisateurs peuvent voir leurs propres posts non supprimés (même non publiés).
       - Les modérateurs (`ADMIN`, `SUPER_ADMIN`, `MODERATOR`) peuvent voir tous les posts, y compris ceux supprimés.
     - **UPDATE ("Moderators can soft-delete posts")**:
       - Nouvelle politique permettant aux modérateurs de mettre à jour n'importe quel post.
       - Ceci est crucial pour que la fonction `soft_delete_content` (qui s'exécute avec les droits du modérateur) puisse marquer les posts comme supprimés.
       - La politique existante "Users can update their own posts" reste inchangée pour les modifications par l'auteur.

  2. Modifications des Politiques RLS pour `public.forum_replies`:
     - **SELECT ("Allow users to read replies")**:
       - Modifiée (ou créée si absente après la politique initiale "USING (true)") pour que les utilisateurs standards ne voient que les réponses `is_deleted = false`.
       - Les utilisateurs peuvent voir leurs propres réponses non supprimées.
       - Les modérateurs peuvent voir toutes les réponses, y compris celles supprimées.
     - **UPDATE ("Moderators can soft-delete replies")**:
       - Nouvelle politique permettant aux modérateurs de mettre à jour n'importe quelle réponse.
       - Nécessaire pour `soft_delete_content` pour les réponses.
       - La politique existante "Users can update their own replies" reste inchangée.

  Ces changements garantissent que la suppression douce fonctionne comme prévu : le contenu disparaît pour les utilisateurs normaux mais reste accessible (et marqué) pour les modérateurs, et que les modérateurs peuvent effectivement effectuer ces suppressions.
*/

-- RLS for public.forum_posts

-- 1. SELECT policy for forum_posts
DROP POLICY IF EXISTS "Allow users to read posts" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow authenticated users to read published posts" ON public.forum_posts; -- Older name
DROP POLICY IF EXISTS "Allow users to read their own posts and all published posts" ON public.forum_posts; -- Older name
DROP POLICY IF EXISTS "Allow all authenticated users to read posts" ON public.forum_posts; -- Initial basic policy

CREATE POLICY "Allow users to read posts"
  ON public.forum_posts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS ( -- Moderators can see everything
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    ) OR (
      -- Regular users: published and not deleted
      is_published = true AND is_deleted = false
    ) OR (
      -- Authors: their own non-deleted posts (even if not published, e.g. drafts)
      auth.uid() = user_id AND is_deleted = false
    )
  );

-- 2. UPDATE policy for forum_posts (for moderators)
-- The existing "Users can update their own posts" policy handles author updates.
-- This new policy is specifically for moderators.
DROP POLICY IF EXISTS "Moderators can soft-delete posts" ON public.forum_posts;
CREATE POLICY "Moderators can soft-delete posts"
  ON public.forum_posts
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  );

-- RLS for public.forum_replies

-- 1. SELECT policy for forum_replies
DROP POLICY IF EXISTS "Allow users to read replies" ON public.forum_replies;
DROP POLICY IF EXISTS "Allow all authenticated users to read replies" ON public.forum_replies; -- Initial basic policy

CREATE POLICY "Allow users to read replies"
  ON public.forum_replies
  FOR SELECT
  TO authenticated
  USING (
    EXISTS ( -- Moderators can see everything
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    ) OR (
      -- Regular users: not deleted
      is_deleted = false
    ) OR (
      -- Authors: their own non-deleted replies
      auth.uid() = user_id AND is_deleted = false
    )
  );

-- 2. UPDATE policy for forum_replies (for moderators)
-- The existing "Users can update their own replies" policy handles author updates.
DROP POLICY IF EXISTS "Moderators can soft-delete replies" ON public.forum_replies;
CREATE POLICY "Moderators can soft-delete replies"
  ON public.forum_replies
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  );