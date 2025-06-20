    /*
      # Création des types énumérés pour la modération

      1. Nouveaux Types Énumérés
        - `report_status_type`: Définit les statuts possibles pour un signalement (PENDING, RESOLVED_APPROVED, RESOLVED_ACTION_TAKEN, RESOLVED_REJECTED).
        - `report_reason_category_type`: Définit les catégories de raisons pour un signalement (SPAM, HARASSMENT, OFFENSIVE_CONTENT, RULES_VIOLATION, OTHER).
      2. Sécurité
        - Ces types seront utilisés par la table `forum_reports` et les fonctions RPC associées.
    */

    -- Supprime les types s'ils existent pour garantir une création propre.
    DROP TYPE IF EXISTS public.report_status_type;
    DROP TYPE IF EXISTS public.report_reason_category_type;

    CREATE TYPE public.report_status_type AS ENUM (
      'PENDING',
      'RESOLVED_APPROVED', -- Signalement examiné, contenu jugé OK
      'RESOLVED_ACTION_TAKEN', -- Signalement examiné, action prise sur le contenu (ex: suppression)
      'RESOLVED_REJECTED' -- Signalement examiné, jugé non pertinent/abusif
    );

    CREATE TYPE public.report_reason_category_type AS ENUM (
      'SPAM',
      'HARASSMENT',
      'OFFENSIVE_CONTENT',
      'RULES_VIOLATION',
      'OTHER'
    );
