/*
      # Setup Moderation Audit Log

      This migration introduces the infrastructure for an exhaustive audit trail of moderator actions.

      1. New Enum
         - `moderation_action_type`: Defines the types of actions a moderator can perform.
           Includes types for content management, user sanctions, report handling, and account management.

      2. New Table
         - `moderation_actions_log`: Stores a record for each moderation action.
           - `id` (uuid, pk): Unique identifier for the log entry.
           - `action_timestamp` (timestamptz): When the action occurred (defaults to `now()`).
           - `moderator_id` (uuid, fk->profiles): The moderator who performed the action.
           - `action_type` (moderation_action_type): The type of action performed.
           - `target_user_id` (uuid, fk->profiles, nullable): The user account targeted by the action.
           - `target_post_id` (uuid, fk->forum_posts, nullable): The forum post targeted by the action.
           - `target_reply_id` (uuid, fk->forum_replies, nullable): The forum reply targeted by the action.
           - `target_report_id` (uuid, fk->forum_reports, nullable): The forum report related to the action.
           - `justification` (text, not null): A mandatory textual reason for the action.
           - `details` (jsonb, nullable): Additional structured details about the action (e.g., old/new values).

      3. New Function
         - `create_moderation_log_entry`: An internal helper function to insert records into `moderation_actions_log`.
           It captures `auth.uid()` as the `moderator_id`.

      4. Security
         - Enables RLS on `moderation_actions_log`.
         - Policy: "Admins and Super Admins can read moderation logs."
         - Policy: "Deny all direct modification of logs." (Logs are append-only via the helper function).

      5. Important Notes
         - The `justification` field is mandatory as per specifications.
         - The `moderation_action_type` enum will be expanded as more logged actions are implemented.
    */

    -- 1. Create ENUM for moderation action types
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moderation_action_type') THEN
            CREATE TYPE public.moderation_action_type AS ENUM (
                'CONTENT_SOFT_DELETE',
                'CONTENT_RESTORE',
                'CONTENT_PERMANENT_DELETE',
                'CONTENT_EDIT_MODERATOR',
                'USER_WARN',
                'USER_SUSPEND_TEMP',
                'USER_BAN_PERMA',
                'USER_ROLE_CHANGE',
                'USER_PROFILE_EDIT_ADMIN',
                'USER_ACCOUNT_APPROVE',
                'USER_ACCOUNT_REJECT',
                'USER_ACCOUNT_CREATE_ADMIN',
                'USER_ACCOUNT_DELETE_ADMIN',
                'REPORT_STATUS_CHANGE_APPROVE', -- Report valid, content action taken or to be taken
                'REPORT_STATUS_CHANGE_REJECT',  -- Report invalid/abusive
                'REPORT_STATUS_CHANGE_RESOLVED' -- Generic resolved, e.g. content deleted via report
            );
        END IF;
    END $$;

    -- 2. Create 'moderation_actions_log' table
    CREATE TABLE IF NOT EXISTS public.moderation_actions_log (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        action_timestamp timestamptz NOT NULL DEFAULT now(),
        moderator_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL, -- Moderator who performed the action
        action_type public.moderation_action_type NOT NULL,
        target_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL, -- User affected by the action
        target_post_id uuid REFERENCES public.forum_posts(id) ON DELETE CASCADE, -- Post affected
        target_reply_id uuid REFERENCES public.forum_replies(id) ON DELETE CASCADE, -- Reply affected
        target_report_id uuid REFERENCES public.forum_reports(id) ON DELETE SET NULL, -- Report related to this action
        justification text NOT NULL, -- Mandatory justification for the action
        details jsonb -- Optional additional details (e.g., old_value, new_value for an edit)
    );

    COMMENT ON TABLE public.moderation_actions_log IS 'Logs all actions performed by moderators.';
    COMMENT ON COLUMN public.moderation_actions_log.moderator_id IS 'The moderator performing the action (from auth.uid() at time of action).';
    COMMENT ON COLUMN public.moderation_actions_log.justification IS 'Mandatory textual justification provided by the moderator for the action.';
    COMMENT ON COLUMN public.moderation_actions_log.details IS 'Optional JSONB field for structured data, like old/new values for edits, suspension duration, etc.';

    -- 3. Enable RLS for the new table
    ALTER TABLE public.moderation_actions_log ENABLE ROW LEVEL SECURITY;

    -- 4. RLS Policies for 'moderation_actions_log'
    DROP POLICY IF EXISTS "Allow admins and super admins to read moderation logs" ON public.moderation_actions_log;
    CREATE POLICY "Allow admins and super admins to read moderation logs"
    ON public.moderation_actions_log FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('ADMIN', 'SUPER_ADMIN')
    );

    DROP POLICY IF EXISTS "Deny all direct modification of logs" ON public.moderation_actions_log;
    CREATE POLICY "Deny all direct modification of logs"
    ON public.moderation_actions_log FOR ALL -- Covers INSERT, UPDATE, DELETE
    TO public -- Apply to all roles, including postgres admin if not careful, but RLS applies to table owners too
    USING (false); -- No one can directly write. Entries are made via SECURITY DEFINER functions.


    -- 5. Create helper function to log moderation actions
    CREATE OR REPLACE FUNCTION public.create_moderation_log_entry(
        p_action_type public.moderation_action_type,
        p_justification text,
        p_target_user_id uuid DEFAULT NULL,
        p_target_post_id uuid DEFAULT NULL,
        p_target_reply_id uuid DEFAULT NULL,
        p_target_report_id uuid DEFAULT NULL,
        p_details jsonb DEFAULT NULL
    )
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_moderator_id uuid := auth.uid();
    BEGIN
        IF p_justification IS NULL OR trim(p_justification) = '' THEN
            RAISE EXCEPTION 'Justification cannot be empty for moderation actions.';
        END IF;

        INSERT INTO public.moderation_actions_log (
            moderator_id,
            action_type,
            target_user_id,
            target_post_id,
            target_reply_id,
            target_report_id,
            justification,
            details
        )
        VALUES (
            v_moderator_id,
            p_action_type,
            p_target_user_id,
            p_target_post_id,
            p_target_reply_id,
            p_target_report_id,
            p_justification,
            p_details
        );
    END;
    $$;

    COMMENT ON FUNCTION public.create_moderation_log_entry IS 'Internal helper to create entries in moderation_actions_log. Captures auth.uid() as moderator_id.';