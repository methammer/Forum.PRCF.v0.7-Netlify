/*
  # Fix Forum Posts RLS, Defaults, Visibility using Comprehensive Trigger-Based Validation

  This migration addresses issues with forum post visibility and creation permissions.
  It moves ALL insert-time validation logic (authorship and category lock)
  into a BEFORE INSERT trigger. This is to resolve the persistent
  "ERROR: 42P01: missing FROM-clause entry for table 'new'" encountered when
  using NEW.column (explicitly or implicitly via column names) in RLS WITH CHECK
  conditions, especially those involving subqueries.

  1. Table Modifications: `public.forum_posts`
     - `is_published` column:
       - Changed default value from `false` to `true`. New posts will now be published and visible by default.

  2. Data Updates:
     - Sets `is_published = true` for all existing posts in `public.forum_posts` that were previously `false`. This ensures all current posts become visible.

  3. New Trigger Function: `public.check_forum_post_insert_permissions()`
     - Runs BEFORE INSERT on `forum_posts`.
     - Validates authorship: `auth.uid()` must match `NEW.user_id`.
     - Validates category lock: If `NEW.category_id` refers to a locked category,
       checks if `auth.uid()` has 'ADMIN', 'SUPER_ADMIN', or 'MODERATOR' role.
     - If any validation fails, raises an exception to prevent insertion.

  4. New Trigger: `validate_forum_post_on_insert`
     - Executes `public.check_forum_post_insert_permissions()` for each row before insert.

  5. RLS Policy Updates for `public.forum_posts`:
     - **SELECT Policy**: (Unchanged)
       - Allows authenticated users to read any post where `is_published = true`.
       - Allows users to read their own posts regardless of `is_published` status.
       - Allows users with 'ADMIN', 'SUPER_ADMIN', 'MODERATOR' roles to read all posts.
     - **INSERT Policy**: (Simplified to defer all checks to trigger)
       - New Policy: `"Users can insert posts (validation via trigger)"`
         - `WITH CHECK (true)`. All actual validation is now handled by the trigger.

  6. Cleanup:
     - Drops the function `public.is_category_unlocked_for_posting(uuid)` if it exists.
     - Drops older versions of trigger functions/triggers if they exist.

  ## Reason:
  - Persistent "ERROR: 42P01: missing FROM-clause entry for table 'new'" when using NEW.column
    in RLS WITH CHECK conditions during DDL execution.
  - Moving all validation to a trigger is a robust workaround for such DDL parsing limitations.
*/

-- 0. Cleanup: Drop older helper functions or trigger functions if they exist
DROP FUNCTION IF EXISTS public.is_category_unlocked_for_posting(uuid);
DROP FUNCTION IF EXISTS public.check_forum_category_lock_before_insert(); -- From previous attempt
-- Ensure the new trigger function name is used for dropping if it changes
DROP FUNCTION IF EXISTS public.check_forum_post_insert_permissions();


-- 1. Change the default for is_published to TRUE in public.forum_posts
ALTER TABLE public.forum_posts
  ALTER COLUMN is_published SET DEFAULT true;

-- 2. Update existing posts to be published
UPDATE public.forum_posts
SET is_published = true
WHERE is_published = false;

-- 3. New Trigger Function for ALL insert-time validation
CREATE OR REPLACE FUNCTION public.check_forum_post_insert_permissions()
RETURNS TRIGGER AS $$
DECLARE
  category_is_locked BOOLEAN;
  user_is_privileged BOOLEAN;
BEGIN
  -- Check 1: Authorship - User must be inserting as themselves
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Anonymous users cannot create posts.' USING ERRCODE = 'P0002', HINT = 'Please log in to create a post.';
    RETURN NULL; -- Should not be reached if exception is raised
  END IF;

  IF NEW.user_id IS NULL THEN
     RAISE EXCEPTION 'Post user_id cannot be null.' USING ERRCODE = '23502'; -- not_null_violation
     RETURN NULL;
  END IF;

  IF auth.uid() <> NEW.user_id THEN
    RAISE EXCEPTION 'User ID mismatch: You can only insert posts as yourself (%). Attempted to insert for user %.', auth.uid(), NEW.user_id
      USING ERRCODE = 'P0003',
            DETAIL = 'Authenticated user: ' || auth.uid() || ', Post user_id: ' || NEW.user_id,
            HINT = 'Ensure the user_id in your post data matches your authenticated user ID.';
    RETURN NULL; -- Abort insert
  END IF;

  -- Check 2: Category Lock (category_id is NOT NULL on forum_posts table)
  IF NEW.category_id IS NULL THEN
    -- This should ideally be caught by the NOT NULL constraint on forum_posts.category_id
    RAISE EXCEPTION 'Post category_id cannot be null.' USING ERRCODE = '23502', HINT = 'A category must be selected for the post.';
    RETURN NULL;
  END IF;

  -- Check if category exists and if it's locked
  SELECT fc.is_locked_for_users INTO category_is_locked
  FROM public.forum_categories fc
  WHERE fc.id = NEW.category_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target category with ID % does not exist.', NEW.category_id
      USING ERRCODE = 'foreign_key_violation', HINT = 'The selected category is invalid.';
    RETURN NULL;
  END IF;

  IF category_is_locked THEN
    -- Category is locked, check if user is privileged
    SELECT EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    ) INTO user_is_privileged;

    IF NOT user_is_privileged THEN
      RAISE EXCEPTION 'Cannot post in locked category (%). This category is reserved for privileged users (Admins, Moderators).', NEW.category_id
        USING ERRCODE = 'P0001', -- Custom error code for insufficient privilege
              DETAIL = 'Category ID: ' || NEW.category_id,
              HINT = 'This category is locked for posting by regular users.';
      RETURN NULL; -- Abort insert
    END IF;
  END IF;

  RETURN NEW; -- Proceed with insert
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- 4. Create the Trigger
DROP TRIGGER IF EXISTS check_category_lock_on_forum_posts_insert ON public.forum_posts; -- From previous attempt
DROP TRIGGER IF EXISTS validate_forum_post_on_insert ON public.forum_posts;

CREATE TRIGGER validate_forum_post_on_insert
  BEFORE INSERT ON public.forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.check_forum_post_insert_permissions();

-- 5. RLS Policy Updates for public.forum_posts

-- SELECT Policy (same as before):
DROP POLICY IF EXISTS "Allow authenticated users to read published posts" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow users to read their own posts and all published posts" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow users to read posts" ON public.forum_posts; -- For idempotency

CREATE POLICY "Allow users to read posts"
  ON public.forum_posts
  FOR SELECT
  TO authenticated
  USING (
    is_published = true OR
    (auth.uid() = user_id) OR -- user_id here refers to the column of the existing row
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('ADMIN', 'SUPER_ADMIN', 'MODERATOR')
    )
  );

-- INSERT Policy (simplified, all validation deferred to trigger):
DROP POLICY IF EXISTS "Users can insert their own posts" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow users to insert their own posts in unlocked categories" ON public.forum_posts;
DROP POLICY IF EXISTS "Allow users to insert their own posts in appropriate categories" ON public.forum_posts;
DROP POLICY IF EXISTS "Users can insert their own posts (validation via trigger)" ON public.forum_posts; -- For idempotency

CREATE POLICY "Users can insert posts (validation via trigger)"
  ON public.forum_posts
  FOR INSERT
  TO authenticated
  WITH CHECK (true); -- All substantive checks are now handled by the BEFORE INSERT trigger.
