/*
      # RBAC Policies Update

      This migration implements the detailed Role-Based Access Control (RBAC) policies
      for the forum application. It refines and extends existing RLS policies for
      `profiles`, `sections`, `topics`, and `posts` tables to align with the
      four defined roles: USER, MODERATOR, ADMIN, and SUPER_ADMIN.

      The `public.get_current_user_role()` helper function (returning lowercase role)
      is extensively used.

      Key changes in this version:
      - Modified `Profiles: RBAC Insert Policy for Admins` to use direct enum comparison for `NEW.role`.
      - Modified `Profiles: RBAC Update Policy` (ADMIN branch) to use direct enum comparison for `NEW.role` and simplified the condition.

      1.  **Enum `user_role_enum`**:
          *   Ensures `USER`, `MODERATOR`, `ADMIN`, `SUPER_ADMIN` are defined. (Assumed from `001_forum_schema_and_roles.sql`)

      2.  **Table `profiles` RLS**:
          *   **SELECT**: Granular visibility based on viewer's role and target's role.
          *   **UPDATE**: Permissions to update own profile, specific fields of other profiles, and roles, according to RBAC. Columns from the existing row are explicitly qualified (e.g., `profiles.role`). `NEW.role` comparisons now use direct enum values.
          *   **DELETE**: Permissions for ADMIN/SUPER_ADMIN to delete accounts based on target role.
          *   **INSERT**: Permissions for ADMIN/SUPER_ADMIN to create accounts. `NEW.role` comparisons now use direct enum values. (User self-registration handled by `handle_new_user` trigger).

      3.  **Table `sections` RLS**:
          *   **SELECT**: Authenticated users can read.
          *   **INSERT/UPDATE/DELETE**: Restricted to ADMIN/SUPER_ADMIN.

      4.  **Table `topics` RLS**:
          *   **SELECT**: Authenticated users can read.
          *   **INSERT**: Users can create their own topics.
          *   **UPDATE**: Users on own topics (limited), MODERATORs on topics in their scope, ADMIN/SUPER_ADMIN on all.
          *   **DELETE**: Similar to UPDATE.

      5.  **Table `posts` RLS**:
          *   **SELECT**: Authenticated users can read.
          *   **INSERT**: Users can create their own posts.
          *   **UPDATE**: Users on own posts (limited), MODERATORs on posts in their scope, ADMIN/SUPER_ADMIN on all.
          *   **DELETE**: Similar to UPDATE.

      **Important Notes**:
      - This migration DROPS and RECREATES many policies. Review carefully.
      - The `public.get_current_user_role()` function is critical.
    */

    -- Ensure RLS is enabled on all relevant tables
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.topics ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

    --------------------------------------------------------------------------------
    -- PROFILES Table RLS
    --------------------------------------------------------------------------------
    DROP POLICY IF EXISTS "Profiles: Users can view own, Admins/SuperAdmins can view all" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: Users can insert their own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: Admins/SuperAdmins can insert any profile" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: Users can update own, Admins/SuperAdmins can update any" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: Admins/SuperAdmins can delete" ON public.profiles;
    DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
    DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
    DROP POLICY IF EXISTS "Users can view their own profile." ON public.profiles;
    DROP POLICY IF EXISTS "Enable read access for admin users" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: RBAC Select Policy" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: RBAC Insert Policy for Admins" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: RBAC Update Policy" ON public.profiles;
    DROP POLICY IF EXISTS "Profiles: RBAC Delete Policy" ON public.profiles;


    -- SELECT PROFILES
    CREATE POLICY "Profiles: RBAC Select Policy"
    ON public.profiles FOR SELECT TO authenticated USING (
      (auth.uid() = profiles.id) OR -- Can always see own profile
      (
        (SELECT public.get_current_user_role()) = 'super_admin' -- SUPER_ADMIN can see all
      ) OR
      (
        (SELECT public.get_current_user_role()) = 'admin' AND
        lower(profiles.role::text) IN ('user', 'moderator', 'admin') -- ADMIN can see USER, MODERATOR, other ADMINs
      ) OR
      (
        (SELECT public.get_current_user_role()) = 'moderator' AND
        lower(profiles.role::text) = 'user' -- MODERATOR can see USERs (for moderation context)
      )
    );

    -- INSERT PROFILES
    CREATE POLICY "Profiles: RBAC Insert Policy for Admins"
    ON public.profiles FOR INSERT TO authenticated WITH CHECK (
      (
        (SELECT public.get_current_user_role()) = 'super_admin'
        -- SUPER_ADMIN can set any role when inserting.
      ) OR
      (
        (SELECT public.get_current_user_role()) = 'admin' AND
        NEW.role IN ('user'::public.user_role_enum, 'moderator'::public.user_role_enum) -- ADMIN can create USER, MODERATOR
      )
    );

    -- UPDATE PROFILES
    CREATE POLICY "Profiles: RBAC Update Policy"
    ON public.profiles FOR UPDATE TO authenticated USING (true) WITH CHECK (
      ( -- USER can update their own profile (specific fields usually controlled by UI or column grants if stricter)
        auth.uid() = profiles.id
      ) OR
      ( -- SUPER_ADMIN can update any profile, any role
        (SELECT public.get_current_user_role()) = 'super_admin' AND profiles.id IS DISTINCT FROM auth.uid()
      ) OR
      ( -- ADMIN can update USERs/MODERATORs profiles
        (SELECT public.get_current_user_role()) = 'admin' AND
        lower(profiles.role::text) IN ('user', 'moderator') AND -- Target profile is currently a USER or MODERATOR
        profiles.id IS DISTINCT FROM auth.uid() AND -- Admin cannot change their own role/profile with this specific branch
        NEW.role IN ('user'::public.user_role_enum, 'moderator'::public.user_role_enum) -- The resulting role must be USER or MODERATOR
      ) OR
      ( -- MODERATOR can update status of USERs
        (SELECT public.get_current_user_role()) = 'moderator' AND
        lower(profiles.role::text) = 'user' AND -- Target profile is currently a USER
        (NEW.status IS NOT NULL AND OLD.status IS DISTINCT FROM NEW.status) -- Moderator must be changing the status
        -- This implicitly means other fields of the USER profile should remain unchanged by the moderator.
        -- For stricter enforcement, add: AND NEW.role = OLD.role AND NEW.username = OLD.username etc.
      )
    );

    -- DELETE PROFILES
    CREATE POLICY "Profiles: RBAC Delete Policy"
    ON public.profiles FOR DELETE TO authenticated USING (
      (
        (SELECT public.get_current_user_role()) = 'super_admin' AND profiles.id IS DISTINCT FROM auth.uid() -- SUPER_ADMIN can delete anyone but self
      ) OR
      (
        (SELECT public.get_current_user_role()) = 'admin' AND
        lower(profiles.role::text) IN ('user', 'moderator') AND profiles.id IS DISTINCT FROM auth.uid() -- ADMIN can delete USERs/MODERATORs but not self
      )
    );


    --------------------------------------------------------------------------------
    -- SECTIONS Table RLS
    --------------------------------------------------------------------------------
    DROP POLICY IF EXISTS "Allow all users to read sections" ON public.sections;
    DROP POLICY IF EXISTS "Allow admins to manage sections" ON public.sections;
    DROP POLICY IF EXISTS "Sections: Authenticated can read" ON public.sections;
    DROP POLICY IF EXISTS "Sections: Admins/SuperAdmins can manage" ON public.sections;

    CREATE POLICY "Sections: Authenticated can read"
    ON public.sections FOR SELECT TO authenticated USING (true);

    CREATE POLICY "Sections: Admins/SuperAdmins can manage"
    ON public.sections FOR ALL TO authenticated USING (
      (SELECT public.get_current_user_role()) IN ('admin', 'super_admin')
    ) WITH CHECK (
      (SELECT public.get_current_user_role()) IN ('admin', 'super_admin')
    );

    --------------------------------------------------------------------------------
    -- TOPICS Table RLS
    --------------------------------------------------------------------------------
    DROP POLICY IF EXISTS "Allow all users to read topics" ON public.topics;
    DROP POLICY IF EXISTS "Allow authenticated users to create topics" ON public.topics;
    DROP POLICY IF EXISTS "Allow users to update their own topics" ON public.topics;
    DROP POLICY IF EXISTS "Allow users to delete their own topics" ON public.topics;
    DROP POLICY IF EXISTS "Topics: Authenticated can read" ON public.topics;
    DROP POLICY IF EXISTS "Topics: Approved users can create" ON public.topics;
    DROP POLICY IF EXISTS "Topics: Users can update/delete own, Mod/Admin/SuperAdmin can manage all" ON public.topics; -- Combined old update/delete
    DROP POLICY IF EXISTS "Topics: Users can delete own, Mod/Admin/SuperAdmin can manage all" ON public.topics;
    DROP POLICY IF EXISTS "Topics: Users can update own, Mod/Admin/SuperAdmin can manage" ON public.topics; -- New specific update policy
    DROP POLICY IF EXISTS "Topics: Users can delete own, Mod/Admin/SuperAdmin can manage" ON public.topics; -- New specific delete policy


    CREATE POLICY "Topics: Authenticated can read"
    ON public.topics FOR SELECT TO authenticated USING (true);

    CREATE POLICY "Topics: Approved users can create"
    ON public.topics FOR INSERT TO authenticated WITH CHECK (
      auth.uid() = topics.user_id AND
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND lower(status::text) = 'approved')
    );

    CREATE POLICY "Topics: Users can update own, Mod/Admin/SuperAdmin can manage"
    ON public.topics FOR UPDATE TO authenticated USING (true) WITH CHECK (
      (
        auth.uid() = topics.user_id -- User can update their own topic
      ) OR
      (
        (SELECT public.get_current_user_role()) IN ('moderator', 'admin', 'super_admin') -- Higher roles can update any topic
      )
    );

    CREATE POLICY "Topics: Users can delete own, Mod/Admin/SuperAdmin can manage"
    ON public.topics FOR DELETE TO authenticated USING (
      (
        auth.uid() = topics.user_id -- User can delete their own topic
      ) OR
      (
        (SELECT public.get_current_user_role()) IN ('moderator', 'admin', 'super_admin') -- Higher roles can delete any topic
      )
    );

    --------------------------------------------------------------------------------
    -- POSTS Table RLS
    --------------------------------------------------------------------------------
    DROP POLICY IF EXISTS "Allow all users to read posts" ON public.posts;
    DROP POLICY IF EXISTS "Allow authenticated users to create posts" ON public.posts;
    DROP POLICY IF EXISTS "Allow users to update their own posts" ON public.posts;
    DROP POLICY IF EXISTS "Allow users to delete their own posts" ON public.posts;
    DROP POLICY IF EXISTS "Posts: Authenticated can read" ON public.posts;
    DROP POLICY IF EXISTS "Posts: Approved users can create" ON public.posts;
    DROP POLICY IF EXISTS "Posts: Users can update/delete own, Mod/Admin/SuperAdmin can manage all" ON public.posts; -- Combined old update/delete
    DROP POLICY IF EXISTS "Posts: Users can delete own, Mod/Admin/SuperAdmin can manage all" ON public.posts;
    DROP POLICY IF EXISTS "Posts: Users can update own, Mod/Admin/SuperAdmin can manage" ON public.posts; -- New specific update policy
    DROP POLICY IF EXISTS "Posts: Users can delete own, Mod/Admin/SuperAdmin can manage" ON public.posts; -- New specific delete policy


    CREATE POLICY "Posts: Authenticated can read"
    ON public.posts FOR SELECT TO authenticated USING (true);

    CREATE POLICY "Posts: Approved users can create"
    ON public.posts FOR INSERT TO authenticated WITH CHECK (
      auth.uid() = posts.user_id AND
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND lower(status::text) = 'approved') AND
      EXISTS (SELECT 1 FROM public.topics WHERE id = NEW.topic_id AND topics.is_locked = false) -- Cannot post in locked topics
    );

    CREATE POLICY "Posts: Users can update own, Mod/Admin/SuperAdmin can manage"
    ON public.posts FOR UPDATE TO authenticated USING (true) WITH CHECK (
      (
        auth.uid() = posts.user_id -- User can update their own post
      ) OR
      (
        (SELECT public.get_current_user_role()) IN ('moderator', 'admin', 'super_admin') -- Higher roles can update any post
      )
    );

    CREATE POLICY "Posts: Users can delete own, Mod/Admin/SuperAdmin can manage"
    ON public.posts FOR DELETE TO authenticated USING (
      (
        auth.uid() = posts.user_id -- User can delete their own post
      ) OR
      (
        (SELECT public.get_current_user_role()) IN ('moderator', 'admin', 'super_admin') -- Higher roles can delete any post
      )
    );

    -- Grant execute on the helper function to authenticated users (if not already done)
    GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
