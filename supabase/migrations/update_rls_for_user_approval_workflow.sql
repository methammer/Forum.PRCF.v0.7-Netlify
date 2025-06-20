/*
      # Update RLS Policies for User Approval Workflow (User Approval Workflow - Part 2)

      This migration updates various Row Level Security (RLS) policies to incorporate
      the `public.is_user_approved()` helper function. This ensures that users whose
      accounts are 'pending_approval' or 'rejected' cannot access resources or perform
      actions that are reserved for 'approved' users.

      Summary of Changes:
      - RLS policies for tables `profiles`, `forum_categories`, `forum_posts`,
        `forum_replies`, `forum_reports`, `forum_category_members`, and `sections`
        are updated.
      - Policies that previously granted access to `authenticated` users now also
        check `public.is_user_approved()`.
      - Policies for specific roles (Admin, Moderator) or for users accessing their
        own data are generally not changed unless they broadly allowed access based
        only on authentication.
      - Corrected `reporter_id` to `reporter_user_id` in `forum_reports` policy.
      - Modified the policy for users requesting to join categories to check against
        `forum_categories.visibility = 'public'` instead of a non-existent
        `can_request_membership` column.

      Helper functions used:
      - `public.is_user_approved()`: Returns true if the current user's profile status is 'approved'.
      - `public.is_category_member_or_public(uuid)`: Returns true if the category is public or the user is a member.

      Affected Tables and Policies:

      1.  **`public.profiles`**:
          - "Allow authenticated users to read all profiles": Now requires user to be approved.
          - "Users can update their own profile": Now requires user to be approved.

      2.  **`public.forum_categories`**:
          - "Allow authenticated users to read categories.": Now requires user to be approved.

      3.  **`public.forum_posts`**:
          - "Allow users to insert posts...": Now requires user to be approved AND satisfy category membership/public criteria.
          - "Allow users to read posts": Public posts are now only readable by approved users (or by owner/admin/mod).
          - "Users can update their own posts.": Now requires user to be approved.
          - "Users can delete their own posts (soft delete).": Now requires user to be approved.

      4.  **`public.forum_replies`**:
          - "Allow authenticated users to insert replies...": Now requires user to be approved AND be able to view the post.
          - "Allow users to read replies...": Now requires user to be able to view the post (which itself has approval checks).
          - "Users can update their own replies.": Now requires user to be approved.
          - "Users can delete their own replies (soft delete).": Now requires user to be approved.

      5.  **`public.forum_reports`**:
          - "Users can report content": Now requires user to be approved. (Corrected column name to `reporter_user_id`)

      6.  **`public.forum_category_members`**:
          - "Users can request to join public categories": New policy allowing approved users to request joining categories where `visibility = 'public'`.
          - "Users can leave categories": Now requires user to be approved.

      7.  **`public.sections`**:
          - "Allow authenticated users to read sections.": Now requires user to be approved.
    */

    SET search_path = public, auth;

    -- On public.profiles
    DROP POLICY IF EXISTS "Allow authenticated users to read all profiles" ON public.profiles;
    CREATE POLICY "Allow authenticated users to read all profiles"
      ON public.profiles
      FOR SELECT
      TO authenticated
      USING (public.is_user_approved());

    DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
    CREATE POLICY "Users can update their own profile"
      ON public.profiles
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = id AND public.is_user_approved())
      WITH CHECK (auth.uid() = id AND public.is_user_approved());

    -- On public.forum_categories
    DROP POLICY IF EXISTS "Allow authenticated users to read categories." ON public.forum_categories;
    CREATE POLICY "Allow authenticated users to read categories."
      ON public.forum_categories
      FOR SELECT
      TO authenticated
      USING (public.is_user_approved());

    -- On public.forum_posts
    DROP POLICY IF EXISTS "Allow users to insert posts if they are approved members of the category or category is public" ON public.forum_posts;
    CREATE POLICY "Allow users to insert posts if they are approved members of the category or category is public"
      ON public.forum_posts
      FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_user_approved() AND
        user_id = auth.uid() AND
        public.is_category_member_or_public(category_id)
      );

    DROP POLICY IF EXISTS "Allow users to read posts" ON public.forum_posts;
    CREATE POLICY "Allow users to read posts"
      ON public.forum_posts
      FOR SELECT
      TO authenticated
      USING (
        (is_published = true AND public.is_user_approved()) OR
        (auth.uid() = user_id) OR
        EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.id = auth.uid()
            AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
        )
      );

    DROP POLICY IF EXISTS "Users can update their own posts." ON public.forum_posts;
    CREATE POLICY "Users can update their own posts."
      ON public.forum_posts
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id AND public.is_user_approved())
      WITH CHECK (auth.uid() = user_id AND public.is_user_approved());

    DROP POLICY IF EXISTS "Users can soft delete their own posts" ON public.forum_posts;
    CREATE POLICY "Users can soft delete their own posts"
      ON public.forum_posts
      FOR UPDATE -- For soft-deletion
      TO authenticated
      USING (auth.uid() = user_id AND public.is_user_approved())
      WITH CHECK (auth.uid() = user_id AND public.is_user_approved());

    -- On public.forum_replies
    DROP POLICY IF EXISTS "Allow authenticated users to insert replies if they can view the post" ON public.forum_replies;
    CREATE POLICY "Allow authenticated users to insert replies if they can view the post"
      ON public.forum_replies
      FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_user_approved() AND
        user_id = auth.uid() AND
        EXISTS (
          SELECT 1
          FROM public.forum_posts fp
          WHERE fp.id = post_id AND (
            (fp.is_published = true AND public.is_user_approved()) OR
            (fp.user_id = auth.uid()) OR
            EXISTS (
              SELECT 1
              FROM public.profiles p
              WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
            )
          )
        )
      );

    DROP POLICY IF EXISTS "Allow users to read replies if they can view the post" ON public.forum_replies;
    CREATE POLICY "Allow users to read replies if they can view the post"
      ON public.forum_replies
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.forum_posts fp
          WHERE fp.id = post_id AND (
            (fp.is_published = true AND public.is_user_approved()) OR
            (fp.user_id = auth.uid()) OR
            EXISTS (
              SELECT 1
              FROM public.profiles p
              WHERE p.id = auth.uid() AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
            )
          )
        )
      );

    DROP POLICY IF EXISTS "Users can update their own replies." ON public.forum_replies;
    CREATE POLICY "Users can update their own replies."
      ON public.forum_replies
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id AND public.is_user_approved())
      WITH CHECK (auth.uid() = user_id AND public.is_user_approved());

    DROP POLICY IF EXISTS "Users can soft delete their own replies" ON public.forum_replies;
    CREATE POLICY "Users can soft delete their own replies"
      ON public.forum_replies
      FOR UPDATE -- For soft-deletion
      TO authenticated
      USING (auth.uid() = user_id AND public.is_user_approved())
      WITH CHECK (auth.uid() = user_id AND public.is_user_approved());

    -- On public.forum_reports
    DROP POLICY IF EXISTS "Users can report content" ON public.forum_reports;
    CREATE POLICY "Users can report content"
      ON public.forum_reports
      FOR INSERT
      TO authenticated
      WITH CHECK (public.is_user_approved() AND reporter_user_id = auth.uid());

    -- On public.forum_category_members
    DROP POLICY IF EXISTS "Users can request to join categories (if category allows)" ON public.forum_category_members; -- old name
    DROP POLICY IF EXISTS "Users can request to join public categories" ON public.forum_category_members; -- new name
    CREATE POLICY "Users can request to join public categories"
      ON public.forum_category_members
      FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_user_approved() AND
        user_id = auth.uid() AND
        EXISTS (
          SELECT 1
          FROM public.forum_categories fc
          WHERE fc.id = category_id AND fc.visibility = 'public'::public.category_visibility_type
        )
      );

    DROP POLICY IF EXISTS "Users can leave categories" ON public.forum_category_members;
    CREATE POLICY "Users can leave categories"
      ON public.forum_category_members
      FOR DELETE
      TO authenticated
      USING (user_id = auth.uid() AND public.is_user_approved());

    -- On public.sections
    DROP POLICY IF EXISTS "Allow authenticated users to read sections." ON public.sections;
    CREATE POLICY "Allow authenticated users to read sections."
      ON public.sections
      FOR SELECT
      TO authenticated
      USING (public.is_user_approved());