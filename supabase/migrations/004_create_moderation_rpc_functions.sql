/*
      # Création des Fonctions RPC pour la Modération

      1. Nouvelles Fonctions RPC
        - `soft_delete_content(p_content_type TEXT, p_content_id UUID, p_delete_reason TEXT)`:
          Marque un post ou une réponse comme supprimé. Met à jour les champs `is_deleted`, `deleted_at`, etc.
          Met également à jour le statut des signalements associés à 'RESOLVED_ACTION_TAKEN'.
          Sécurité: SECURITY INVOKER, RLS sur les tables sous-jacentes doit permettre l'action.

        - `get_pending_reports_with_details()`:
          Récupère une liste des signalements en attente avec les détails du contenu signalé et du rapporteur.
          Destinée à la page de modération.
          Sécurité: SECURITY INVOKER, RLS sur `forum_reports` doit permettre la lecture aux modérateurs.

        - `update_report_status(p_report_id UUID, p_new_status report_status_type, p_moderator_notes TEXT)`:
          Permet aux modérateurs de changer le statut d'un signalement (ex: PENDING -> RESOLVED_APPROVED).
          Met à jour `resolved_at`, `resolved_by_user_id`, `moderator_notes`.
          Sécurité: SECURITY INVOKER, RLS sur `forum_reports` doit permettre la mise à jour par les modérateurs.
      2. Sécurité
        - Toutes les fonctions sont `SECURITY INVOKER`, ce qui signifie qu'elles s'exécutent avec les permissions de l'utilisateur appelant.
        - Les politiques RLS sur les tables (`forum_posts`, `forum_replies`, `forum_reports`) sont cruciales pour la sécurité.
    */

    CREATE OR REPLACE FUNCTION public.soft_delete_content(
      p_content_type TEXT, -- 'post' or 'reply'
      p_content_id UUID,
      p_delete_reason TEXT DEFAULT NULL
    )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY INVOKER
    AS $$
    DECLARE
      v_caller_id UUID := auth.uid();
    BEGIN
      IF p_content_type = 'post' THEN
        UPDATE public.forum_posts
        SET
          is_deleted = TRUE,
          deleted_at = now(),
          deleted_by_user_id = v_caller_id,
          deleted_reason = p_delete_reason
        WHERE id = p_content_id;
      ELSIF p_content_type = 'reply' THEN
        UPDATE public.forum_replies
        SET
          is_deleted = TRUE,
          deleted_at = now(),
          deleted_by_user_id = v_caller_id,
          deleted_reason = p_delete_reason
        WHERE id = p_content_id;
      ELSE
        RAISE EXCEPTION 'Invalid content type. Must be "post" or "reply". Received: %', p_content_type;
      END IF;

      -- Update related pending reports to RESOLVED_ACTION_TAKEN
      UPDATE public.forum_reports
      SET
        status = 'RESOLVED_ACTION_TAKEN',
        resolved_at = now(),
        resolved_by_user_id = v_caller_id
      WHERE status = 'PENDING' AND
            (
              (reported_post_id = p_content_id AND p_content_type = 'post') OR
              (reported_reply_id = p_content_id AND p_content_type = 'reply')
            );
    END;
    $$;
    COMMENT ON FUNCTION public.soft_delete_content IS 'Marks a post or reply as deleted and updates related reports. Caller must have RLS update permission on target tables.';


    CREATE OR REPLACE FUNCTION public.get_pending_reports_with_details()
    RETURNS TABLE (
      report_id UUID,
      report_created_at TIMESTAMPTZ,
      reporter_id UUID,
      reporter_username TEXT,
      reported_content_type TEXT, -- 'post' or 'reply'
      reported_content_id UUID,
      content_title TEXT, -- For posts/topics
      content_excerpt TEXT, -- First N chars of post/reply
      content_author_id UUID,
      content_author_username TEXT,
      reason_category public.report_reason_category_type,
      reason_details TEXT,
      report_status public.report_status_type
    )
    LANGUAGE plpgsql
    SECURITY INVOKER
    AS $$
    BEGIN
      -- RLS on forum_reports table (SELECT policy for moderators) will handle access control.
      -- If no policy matches, or if the user is not a moderator, this will return 0 rows or error based on RLS.
      RETURN QUERY
      SELECT
        fr.id AS report_id,
        fr.created_at AS report_created_at,
        fr.reporter_user_id AS reporter_id,
        reporter_profile.username AS reporter_username,
        CASE
          WHEN fr.reported_post_id IS NOT NULL THEN 'post'
          WHEN fr.reported_reply_id IS NOT NULL THEN 'reply'
          ELSE 'unknown' -- Should not happen due to table constraint
        END AS reported_content_type,
        COALESCE(fr.reported_post_id, fr.reported_reply_id) AS reported_content_id,
        fp.title AS content_title, -- Title for posts
        COALESCE(LEFT(fp.content, 100), LEFT(f_reply.content, 100)) AS content_excerpt,
        COALESCE(fp.user_id, f_reply.user_id) AS content_author_id,
        COALESCE(post_author_profile.username, reply_author_profile.username) AS content_author_username,
        fr.reason_category,
        fr.reason_details,
        fr.status AS report_status
      FROM public.forum_reports fr
      LEFT JOIN public.profiles reporter_profile ON fr.reporter_user_id = reporter_profile.id
      LEFT JOIN public.forum_posts fp ON fr.reported_post_id = fp.id
      LEFT JOIN public.profiles post_author_profile ON fp.user_id = post_author_profile.id
      LEFT JOIN public.forum_replies f_reply ON fr.reported_reply_id = f_reply.id
      LEFT JOIN public.profiles reply_author_profile ON f_reply.user_id = reply_author_profile.id
      WHERE fr.status = 'PENDING'
      ORDER BY fr.created_at ASC;
    END;
    $$;
    COMMENT ON FUNCTION public.get_pending_reports_with_details IS 'Fetches pending reports with details. Access controlled by RLS on forum_reports.';


    CREATE OR REPLACE FUNCTION public.update_report_status(
      p_report_id UUID,
      p_new_status public.report_status_type,
      p_moderator_notes TEXT DEFAULT NULL
    )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY INVOKER
    AS $$
    DECLARE
      v_caller_id UUID := auth.uid();
    BEGIN
      -- RLS on forum_reports table (UPDATE policy for moderators) will handle access control.
      UPDATE public.forum_reports
      SET
        status = p_new_status,
        resolved_at = CASE WHEN p_new_status <> 'PENDING' THEN now() ELSE resolved_at END,
        resolved_by_user_id = CASE WHEN p_new_status <> 'PENDING' THEN v_caller_id ELSE resolved_by_user_id END,
        moderator_notes = COALESCE(p_moderator_notes, forum_reports.moderator_notes)
      WHERE id = p_report_id;
    END;
    $$;
    COMMENT ON FUNCTION public.update_report_status IS 'Updates the status of a report. Caller must have RLS update permission on forum_reports.';