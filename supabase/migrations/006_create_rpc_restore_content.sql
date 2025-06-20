    /*
      # RPC: Restore Content

      This migration creates a new RPC function `restore_content`
      that allows moderators to undo a soft-deletion for a post or reply.

      1. New Function
        - `restore_content(p_content_type TEXT, p_content_id UUID)`:
          - Takes content type ('post' or 'reply') and content ID as input.
          - Sets `is_deleted` to `FALSE`.
          - Clears `deleted_at`, `deleted_by_user_id`, and `deleted_reason` fields.
          - Logs the action using `RAISE NOTICE`.

      2. Security
        - The function is `SECURITY DEFINER`. This allows it to update records
          regardless of the direct RLS permissions of the calling user, provided the
          application logic correctly authorizes the call (e.g., checks if the user is a moderator).
          The `auth.uid()` of the caller is recorded as the user who initiated the restoration action
          in the log, but not directly on the restored record's fields.

      3. Reports
        - This function does NOT automatically change the status of related `forum_reports`
          (e.g., those with status `RESOLVED_ACTION_TAKEN`). If a report needs to be reopened
          or its status updated after content restoration, it must be handled separately
          by a moderator.
    */

    CREATE OR REPLACE FUNCTION public.restore_content(
      p_content_type TEXT, -- 'post' or 'reply'
      p_content_id UUID
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
      RAISE NOTICE '[restore_content] Called by: %, Type: %, ID: %', v_caller_id, p_content_type, p_content_id;

      IF p_content_type = 'post' THEN
        UPDATE public.forum_posts
        SET
          is_deleted = FALSE,
          deleted_at = NULL,
          deleted_by_user_id = NULL, -- Or consider setting to v_caller_id if you want to track who restored it
          deleted_reason = NULL -- Or set to 'Restored by moderator'
        WHERE id = p_content_id AND is_deleted = TRUE;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[restore_content] Updated forum_posts. Affected rows: %', v_affected_rows;

      ELSIF p_content_type = 'reply' THEN
        UPDATE public.forum_replies
        SET
          is_deleted = FALSE,
          deleted_at = NULL,
          deleted_by_user_id = NULL,
          deleted_reason = NULL
        WHERE id = p_content_id AND is_deleted = TRUE;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[restore_content] Updated forum_replies. Affected rows: %', v_affected_rows;
      ELSE
        RAISE EXCEPTION 'Invalid content type. Must be "post" or "reply". Received: %', p_content_type;
      END IF;

      IF v_affected_rows > 0 THEN
        RAISE NOTICE '[restore_content] Successfully marked content as restored. Type: %, ID: %', p_content_type, p_content_id;
      ELSE
        RAISE NOTICE '[restore_content] No rows updated for content restoration. Type: %, ID: %. Check if ID exists and is_deleted=TRUE.', p_content_type, p_content_id;
      END IF;
    END;
    $$;

    COMMENT ON FUNCTION public.restore_content(TEXT, UUID) IS 'Restores a soft-deleted post or reply. SECURITY DEFINER.';
