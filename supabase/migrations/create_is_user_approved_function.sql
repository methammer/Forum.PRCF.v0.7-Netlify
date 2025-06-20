/*
  # Create is_user_approved Helper Function (User Approval Workflow - Part 1b)

  This migration introduces the `public.is_user_approved()` helper function,
  which is essential for RLS policies in the user approval workflow.

  Changes:
  1.  **`public.is_user_approved()` Helper Function**:
      - Drops the function if it already exists to ensure a clean state.
      - Creates a new SQL function `is_user_approved()`.
      - This function returns `true` if the currently authenticated user has a profile
        with `status = 'approved'`, and `false` otherwise.
      - It will be used in RLS policies to restrict access for non-approved users.
  2.  **Permissions**:
      - Grants `EXECUTE` permission on this function to `authenticated` users.
  3.  **Debugging**:
      - Adds `RAISE NOTICE` for tracking.
      - Adds a final `SELECT` statement to confirm script completion.
*/
RAISE NOTICE 'Attempting to create public.is_user_approved function...';
SET search_path = public, auth;

-- Ensure the function is dropped first to handle any problematic existing state
DROP FUNCTION IF EXISTS public.is_user_approved();

CREATE OR REPLACE FUNCTION public.is_user_approved()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER -- Checks the status of the user calling the function
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND status = 'approved'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_user_approved() TO authenticated;
RAISE NOTICE 'public.is_user_approved function created and granted.';
SELECT true AS function_created_successfully; -- Simple select to confirm execution path