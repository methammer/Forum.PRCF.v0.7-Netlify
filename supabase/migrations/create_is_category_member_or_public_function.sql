/*
      # Create Helper Function: is_category_member_or_public

      This migration creates a new SQL helper function `public.is_category_member_or_public(p_category_id uuid)`.

      This function is used in RLS policies, particularly for `forum_posts`, to determine
      if a user can interact with content within a category. It returns `true` if:
      1. The category specified by `p_category_id` has its `visibility` set to 'public'.
      OR
      2. The currently authenticated user (identified by `auth.uid()`) is a member of the
         category, as determined by the `public.is_category_member()` function.

      Dependencies:
      - `public.forum_categories` table with a `visibility` column of type `public.category_visibility_type`.
      - `public.category_visibility_type` ENUM ('public', 'private').
      - `public.is_category_member(uuid, uuid)` function.

      The function is `STABLE` and `SECURITY INVOKER`.
    */

    SET search_path = public, auth;

    DROP FUNCTION IF EXISTS public.is_category_member_or_public(uuid);

    CREATE OR REPLACE FUNCTION public.is_category_member_or_public(p_category_id uuid)
    RETURNS boolean
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $$
      SELECT
        EXISTS (
          SELECT 1
          FROM public.forum_categories fc
          WHERE fc.id = p_category_id AND fc.visibility = 'public'::public.category_visibility_type
        ) OR
        public.is_category_member(p_category_id, auth.uid());
    $$;

    GRANT EXECUTE ON FUNCTION public.is_category_member_or_public(uuid) TO authenticated;

    COMMENT ON FUNCTION public.is_category_member_or_public(uuid) IS 'Checks if a category is public or if the current user is a member.';
