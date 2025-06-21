/*
      # Création de la table forum_reports

      Cette table stocke les signalements faits par les utilisateurs sur les contenus du forum.
      Elle dépend des types `report_status_type` et `report_reason_category_type` qui doivent être créés au préalable.

      1. Nouvelle Table
        - `forum_reports`
          - `id` (uuid, pk): Identifiant unique du signalement.
          - `created_at` (timestamptz): Date de création du signalement.
          - `reporter_user_id` (uuid, fk->profiles): Utilisateur ayant fait le signalement.
          - `reported_post_id` (uuid, fk->forum_posts, nullable): Sujet/Post signalé.
          - `reported_reply_id` (uuid, fk->forum_replies, nullable): Réponse signalée.
          - `reason_category` (report_reason_category_type): Catégorie de la raison du signalement.
          - `reason_details` (text, nullable): Détails supplémentaires sur la raison.
          - `status` (report_status_type): Statut actuel du signalement.
          - `resolved_at` (timestamptz, nullable): Date de résolution du signalement.
          - `resolved_by_user_id` (uuid, fk->profiles, nullable): Modérateur ayant résolu le signalement.
          - `moderator_notes` (text, nullable): Notes internes pour les modérateurs.
          - `CHECK constraint`: S'assure qu'un signalement concerne soit un post, soit une réponse, mais pas les deux ni aucun.

      2. Sécurité
        - Activation de RLS sur `forum_reports`.
        - Politiques RLS :
          - Les utilisateurs authentifiés peuvent créer des signalements pour eux-mêmes.
          - Les modérateurs/administrateurs peuvent lire tous les signalements.
          - Les modérateurs/administrateurs peuvent mettre à jour les signalements (statut, résolution, notes).
    */

    CREATE TABLE IF NOT EXISTS public.forum_reports (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      created_at timestamptz NOT NULL DEFAULT now(),
      reporter_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
      reported_post_id uuid REFERENCES public.forum_posts(id) ON DELETE CASCADE,
      reported_reply_id uuid REFERENCES public.forum_replies(id) ON DELETE CASCADE,
      reason_category public.report_reason_category_type NOT NULL,
      reason_details text,
      status public.report_status_type NOT NULL DEFAULT 'PENDING',
      resolved_at timestamptz,
      resolved_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
      moderator_notes text,
      CONSTRAINT check_reported_content_exclusive CHECK (
        (reported_post_id IS NOT NULL AND reported_reply_id IS NULL) OR
        (reported_post_id IS NULL AND reported_reply_id IS NOT NULL)
      )
    );

    COMMENT ON TABLE public.forum_reports IS 'Stores user-generated reports for forum content.';
    COMMENT ON COLUMN public.forum_reports.reason_category IS 'Predefined category for the report reason.';
    COMMENT ON COLUMN public.forum_reports.status IS 'Current status of the report (e.g., PENDING, RESOLVED).';

    ALTER TABLE public.forum_reports ENABLE ROW LEVEL SECURITY;

    CREATE POLICY "Authenticated users can create reports"
      ON public.forum_reports
      FOR INSERT
      TO authenticated
      WITH CHECK (reporter_user_id = auth.uid());

    CREATE POLICY "Moderators and admins can view all reports"
      ON public.forum_reports
      FOR SELECT
      TO authenticated
      USING (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));

    CREATE POLICY "Moderators and admins can update reports"
      ON public.forum_reports
      FOR UPDATE
      TO authenticated
      USING (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'))
      WITH CHECK (get_current_user_role() IN ('MODERATOR', 'ADMIN', 'SUPER_ADMIN'));

    CREATE POLICY "Users can view their own submitted reports"
      ON public.forum_reports
      FOR SELECT
      TO authenticated
      USING (reporter_user_id = auth.uid());
