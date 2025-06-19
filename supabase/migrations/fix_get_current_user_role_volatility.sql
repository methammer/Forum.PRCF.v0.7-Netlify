/*
  # Fix get_current_user_role Function Volatility

  This migration corrects the `public.get_current_user_role()` function
  to properly set `search_path` at the function definition level,
  resolving the "SET is not allowed in a non-volatile function" error.

  The function remains STABLE, SECURITY INVOKER, and continues to return
  the user's role in lowercase.
*/

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public -- Correct: search_path set at function definition
AS $$
  SELECT lower(role) FROM public.profiles WHERE id = auth.uid();
$$;

-- Re-grant execute permission just in case, though it should persist
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
