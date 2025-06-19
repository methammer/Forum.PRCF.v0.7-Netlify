/*
  # Uppercase Existing Profile Roles

  This migration updates any existing roles in the `public.profiles` table
  to their uppercase equivalents. This ensures consistency with frontend
  expectations (e.g., 'USER', 'ADMIN') and fixes issues where lowercase
  roles (e.g., 'user') might cause validation or permission errors.

  Changes:
  1. Data Modification:
     - All non-null `role` values in `public.profiles` that are not already
       in uppercase will be converted to uppercase.
       Example: 'user' becomes 'USER', 'admin' becomes 'ADMIN'.
*/

UPDATE public.profiles
SET role = UPPER(role)
WHERE role IS NOT NULL AND role != UPPER(role);
