/*
      # Update `soft_delete_content` RPC for Audit Logging (v2 - with DROP FUNCTION)

      This migration modifies the existing `soft_delete_content` Remote Procedure Call (RPC)
      to integrate with the new `moderation_actions_log` table.

      1. Modified Function
         - `public.soft_delete_content(p_content_type TEXT, p_content_id UUID, p_delete_reason TEXT)`
           - Drops the existing function with signature (TEXT, UUID, TEXT) first to avoid conflicts.
           - Now calls `public.create_moderation_log_entry` to record the soft deletion action.
           - The `p_delete_reason` is used as the `justification` for the log. If empty, a default justification is used.
           - The core functionality of marking content as deleted (updating `deleted_at`, `deleted_by_user_id`, `deletion_reason`
             in `forum_posts` or `forum_replies`) is preserved.

      2. Important Notes
         - This ensures that soft-deletions performed by moderators are properly audited.
         - Assumes `forum_posts` and `forum_replies` tables have `deleted_at` (TIMESTAMPTZ),
           `deleted_by_user_id` (UUID), and `deletion_reason` (TEXT) columns.
         - The `p_delete_reason` from the frontend is passed as justification. If it's an empty string,
           it's treated as NULL by `NULLIF`, and then `COALESCE` provides a default justification.
    */

    -- Drop the existing function with the specific signature that might be causing a conflict
    DROP FUNCTION IF EXISTS public.soft_delete_content(text, uuid, text);

    CREATE OR REPLACE FUNCTION public.soft_delete_content(
        p_content_type TEXT, -- 'post' or 'reply'
        p_content_id UUID,
        p_delete_reason TEXT -- Optional reason from moderator
    )
    RETURNS VOID
    LANGUAGE plpgsql
    SECURITY DEFINER -- To update tables and call the logging function
    SET search_path = public
    AS $$
    DECLARE
        v_moderator_id UUID := auth.uid();
        v_table_name TEXT;
        v_justification TEXT;
        v_target_post_id UUID := NULL;
        v_target_reply_id UUID := NULL;
    BEGIN
        IF p_content_type = 'post' THEN
            v_table_name := 'forum_posts';
            v_target_post_id := p_content_id;
        ELSIF p_content_type = 'reply' THEN
            v_table_name := 'forum_replies';
            v_target_reply_id := p_content_id;
        ELSE
            RAISE EXCEPTION 'Invalid content type: %. Must be ''post'' or ''reply''.', p_content_type;
        END IF;

        -- Update the respective table to mark as deleted
        EXECUTE format(
            'UPDATE %I SET deleted_at = now(), deleted_by_user_id = %L, deletion_reason = %L WHERE id = %L',
            v_table_name, v_moderator_id, p_delete_reason, p_content_id
        );

        -- Prepare justification for audit log
        v_justification := COALESCE(NULLIF(TRIM(p_delete_reason), ''), 'Content soft-deleted by moderator via moderation panel.');

        -- Log the action
        PERFORM public.create_moderation_log_entry(
            p_action_type    := 'CONTENT_SOFT_DELETE',
            p_justification  := v_justification,
            p_target_post_id := v_target_post_id,
            p_target_reply_id:= v_target_reply_id,
            p_details        := jsonb_build_object('content_type', p_content_type, 'content_id', p_content_id, 'original_reason_param', p_delete_reason)
        );

    END;
    $$;

    COMMENT ON FUNCTION public.soft_delete_content(TEXT, UUID, TEXT) IS 'Soft deletes a post or reply and logs the action. Moderator ID is auth.uid().';