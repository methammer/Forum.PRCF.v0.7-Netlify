/*
      # Création des Fonctions RPC pour la Modération (v3) with logging

      1. Modifications
        - `soft_delete_content(p_content_type TEXT, p_content_id UUID, p_delete_reason TEXT)`:
          - Added `RAISE NOTICE` to log parameters and affected rows.
          - Remains `SECURITY DEFINER`.

      2. Fonctions RPC Existantes (inchangées)
        - `get_pending_reports_with_details()`
        - `update_report_status()`

      3. Sécurité
        - `soft_delete_content` s'exécute avec les permissions du propriétaire.
    */

    -- Drop the function first to allow changing its definition and security context
    DROP FUNCTION IF EXISTS public.soft_delete_content(TEXT, UUID, TEXT);

    CREATE OR REPLACE FUNCTION public.soft_delete_content(
      p_content_type TEXT, -- 'post' or 'reply'
      p_content_id UUID,
      p_delete_reason TEXT DEFAULT NULL
    )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
      v_caller_id UUID := auth.uid();
      v_affected_rows INT;
    BEGIN
      RAISE NOTICE '[soft_delete_content] Called by: %, Type: %, ID: %, Reason: %', v_caller_id, p_content_type, p_content_id, p_delete_reason;

      IF p_content_type = 'post' THEN
        UPDATE public.forum_posts
        SET
          is_deleted = TRUE,
          deleted_at = now(),
          deleted_by_user_id = v_caller_id,
          deleted_reason = p_delete_reason
        WHERE id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[soft_delete_content] Updated forum_posts. Affected rows: %', v_affected_rows;

      ELSIF p_content_type = 'reply' THEN
        UPDATE public.forum_replies
        SET
          is_deleted = TRUE,
          deleted_at = now(),
          deleted_by_user_id = v_caller_id,
          deleted_reason = p_delete_reason
        WHERE id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[soft_delete_content] Updated forum_replies. Affected rows: %', v_affected_rows;
      ELSE
        RAISE EXCEPTION 'Invalid content type. Must be "post" or "reply". Received: %', p_content_type;
      END IF;

      IF v_affected_rows > 0 THEN
        RAISE NOTICE '[soft_delete_content] Successfully marked content as deleted. Type: %, ID: %', p_content_type, p_content_id;
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
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT; -- Re-check for this update
        RAISE NOTICE '[soft_delete_content] Updated forum_reports. Affected rows for reports: %', v_affected_rows;
      ELSE
        RAISE NOTICE '[soft_delete_content] No rows updated for content deletion. Type: %, ID: %. Check if ID exists.', p_content_type, p_content_id;
      END IF;
    END;
    $$;
    COMMENT ON FUNCTION public.soft_delete_content(TEXT, UUID, TEXT) IS 'Marks a post or reply as deleted and updates related reports. SECURITY DEFINER. Includes debug logging (v3). Records auth.uid() as deleted_by_user_id.';


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
    SECURITY INVOKER -- Remains SECURITY INVOKER
    AS $$
    BEGIN
      -- RLS on forum_reports table (SELECT policy for moderators) will handle access control.
      RETURN QUERY
      SELECT
        fr.id AS report_id,
        fr.created_at AS report_created_at,
        fr.reporter_user_id AS reporter_id,
        reporter_profile.username AS reporter_username,
        CASE
          WHEN fr.reported_post_id IS NOT NULL THEN 'post'
          WHEN fr.reported_reply_id IS NOT NULL THEN 'reply'
          ELSE 'unknown'
        END AS reported_content_type,
        COALESCE(fr.reported_post_id, fr.reported_reply_id) AS reported_content_id,
        fp.title AS content_title,
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
    COMMENT ON FUNCTION public.get_pending_reports_with_details IS 'Fetches pending reports with details. Access controlled by RLS on forum_reports. SECURITY INVOKER.';


    CREATE OR REPLACE FUNCTION public.update_report_status(
      p_report_id UUID,
      p_new_status public.report_status_type,
      p_moderator_notes TEXT DEFAULT NULL
    )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY INVOKER -- Remains SECURITY INVOKER
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
    COMMENT ON FUNCTION public.update_report_status(UUID, public.report_status_type, TEXT) IS 'Updates the status of a report. Caller must have RLS update permission on forum_reports. SECURITY INVOKER.';