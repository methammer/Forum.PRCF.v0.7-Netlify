    /*
      # RPC: Permanently Delete Content

      This migration creates a new RPC function `permanently_delete_content`
      that allows moderators to physically delete a soft-deleted post or reply.
      This action is irreversible.

      1. New Function
        - `permanently_delete_content(p_content_type TEXT, p_content_id UUID)`:
          - Takes content type ('post' or 'reply') and content ID as input.
          - Performs a `DELETE FROM` operation on the respective table.
          - Logs the action using `RAISE NOTICE`.
          - IMPORTANT: This function also needs to handle deletion of related records
            if there are foreign key constraints with ON DELETE CASCADE. For example,
            if deleting a post should delete its replies, or if deleting content
            should delete related reports. For now, it will focus on the content itself.
            Associated reports for the deleted content will also be deleted.

      2. Security
        - The function is `SECURITY DEFINER`. This allows it to delete records
          regardless of the direct RLS permissions of the calling user, provided the
          application logic correctly authorizes the call (e.g., checks if the user is a moderator).
          The `auth.uid()` of the caller is recorded in the log.

      3. Considerations
        - **Irreversibility**: This action cannot be undone.
        - **Orphaned Records**: Ensure related data (e.g., reports specifically for this content)
          is handled. This version will delete reports associated with the permanently deleted content.
          Replies to a permanently deleted post will also be deleted due to cascading constraints
          if `forum_replies.post_id` has `ON DELETE CASCADE`.
          (Assuming `forum_replies.post_id` has `ON DELETE CASCADE` for posts,
           and `forum_reports.reported_post_id` / `forum_reports.reported_reply_id` might need explicit handling or rely on CASCADE if set up).
    */

    CREATE OR REPLACE FUNCTION public.permanently_delete_content(
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
      RAISE NOTICE '[permanently_delete_content] Called by: %, Type: %, ID: %', v_caller_id, p_content_type, p_content_id;

      IF p_content_type = 'post' THEN
        -- First, delete reports associated with this post
        DELETE FROM public.forum_reports WHERE reported_post_id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[permanently_delete_content] Deleted % reports associated with post ID: %', v_affected_rows, p_content_id;

        -- Then, delete the post itself. Assuming replies are handled by ON DELETE CASCADE on forum_replies.post_id
        DELETE FROM public.forum_posts WHERE id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[permanently_delete_content] Deleted post. Affected rows: %', v_affected_rows;

      ELSIF p_content_type = 'reply' THEN
        -- First, delete reports associated with this reply
        DELETE FROM public.forum_reports WHERE reported_reply_id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[permanently_delete_content] Deleted % reports associated with reply ID: %', v_affected_rows, p_content_id;

        -- Then, delete the reply itself
        DELETE FROM public.forum_replies WHERE id = p_content_id;
        GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
        RAISE NOTICE '[permanently_delete_content] Deleted reply. Affected rows: %', v_affected_rows;
      ELSE
        RAISE EXCEPTION 'Invalid content type. Must be "post" or "reply". Received: %', p_content_type;
      END IF;

      IF v_affected_rows > 0 THEN
        RAISE NOTICE '[permanently_delete_content] Successfully permanently deleted content. Type: %, ID: %', p_content_type, p_content_id;
      ELSE
        RAISE NOTICE '[permanently_delete_content] No rows affected by permanent deletion. Type: %, ID: %. Content might have already been deleted or ID is incorrect.', p_content_type, p_content_id;
      END IF;
    END;
    $$;

    COMMENT ON FUNCTION public.permanently_delete_content(TEXT, UUID) IS 'Permanently deletes a post or reply and its associated reports. SECURITY DEFINER. This action is irreversible.';
