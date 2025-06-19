<![CDATA[
/*
  # Enable unaccent extension

  This migration enables the `unaccent` PostgreSQL extension.
  The `unaccent` extension provides a text search dictionary that removes accents
  (diacritical marks) from lexemes. This is used by our `slugify` function.

  1. Extensions
     - Enable `unaccent`

  2. Important Notes
     - This is necessary for the `slugify` function to work correctly, which is used
       by the `forum_categories` table to generate slugs.
     - Failure to enable this extension results in "function unaccent(text) does not exist" errors.
*/

CREATE EXTENSION IF NOT EXISTS unaccent;
]]>