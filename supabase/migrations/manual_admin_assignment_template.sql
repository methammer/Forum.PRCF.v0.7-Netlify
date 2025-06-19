<content>/*
  # Modèle d'Assignation Manuelle du Rôle Administrateur

  Ce script fournit un modèle pour assigner manuellement le rôle 'ADMIN'
  à un utilisateur spécifique dans la table `profiles`.

  **IMPORTANT :**
  - Vous DEVEZ remplacer `'USER_ID_PLACEHOLDER'` par l' `id` réel de l'utilisateur (son `auth.uid()`)
    avant d'exécuter ce script.
  - Ceci est destiné à l'administration directe de la base de données. Une interface utilisateur pour la gestion
    des rôles sera développée dans le cadre du panneau d'administration.
  - Ce script désactive temporairement le trigger qui empêche les modifications directes du rôle,
    effectue la mise à jour, puis réactive le trigger.

  1.  **Opérations**
      1.  Désactive le trigger `before_profile_update_prevent_id_role_change` sur `public.profiles`.
      2.  Met à jour la colonne `role` pour un *utilisateur spécifique* à 'ADMIN'.
      3.  Réactive le trigger `before_profile_update_prevent_id_role_change` sur `public.profiles`.

  2.  **Sécurité (RLS)**
      *   Aucun changement aux politiques RLS. Les politiques existantes pour les administrateurs s'appliqueront
        une fois le rôle modifié.

  3.  **Utilisation**
      1.  Identifiez l'`id` de l'utilisateur auquel vous souhaitez accorder les droits d'administrateur.
          C'est son UID d'authentification.
      2.  Remplacez `'USER_ID_PLACEHOLDER'` dans l'instruction `UPDATE` ci-dessous par cet ID.
      3.  Exécutez l'intégralité du bloc SQL (par exemple, dans l'éditeur SQL de Supabase).
*/

-- Début de la transaction (optionnel, mais bon pour l'atomicité si votre client le supporte bien)
-- BEGIN;

-- Étape 1: Désactiver temporairement le trigger
ALTER TABLE public.profiles DISABLE TRIGGER before_profile_update_prevent_id_role_change;

-- Étape 2: Assigner le rôle ADMIN
-- Assurez-vous de remplacer 'USER_ID_PLACEHOLDER' par l'ID réel de l'utilisateur.
UPDATE public.profiles
SET role = 'ADMIN'
WHERE id = 'USER_ID_PLACEHOLDER'; -- <<< IMPORTANT : Remplacez ce placeholder !

-- Exemple :
-- UPDATE public.profiles
-- SET role = 'ADMIN'
-- WHERE id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';

-- Étape 3: Réactiver le trigger
ALTER TABLE public.profiles ENABLE TRIGGER before_profile_update_prevent_id_role_change;

-- Fin de la transaction (si BEGIN a été utilisé)
-- COMMIT;

/*
  Vérification (optionnel):
  SELECT id, email, role FROM public.profiles WHERE id = 'USER_ID_PLACEHOLDER';
*/
    </content>
