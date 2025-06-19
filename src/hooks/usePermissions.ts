import { useUser, Profile } from '@/contexts/UserContext';

    // Define more specific actions based on the RBAC document
    export type PermissionAction =
      // User Account Actions
      | 'view_own_profile' | 'edit_own_profile'
      | 'view_any_user_profile_basic' // For mods viewing user profiles
      | 'view_any_user_profile_full'  // For admins viewing user/mod profiles
      | 'view_all_profiles'           // For super_admins
      | 'edit_user_status'            // Mod changing user status, Admin changing user/mod status
      | 'edit_user_role'              // Admin changing user/mod roles, SuperAdmin changing any role
      | 'create_user_account'         // Admin creating user/mod, SuperAdmin creating any
      | 'delete_user_account'         // Admin deleting user/mod, SuperAdmin deleting any
      | 'suspend_user_account'

      // Content Actions - Posts
      | 'create_post'
      | 'read_posts'
      | 'edit_own_post' | 'delete_own_post'
      | 'edit_any_post' | 'delete_any_post' // Mod/Admin/SuperAdmin
      | 'approve_post' | 'move_post' | 'pin_post_in_topic'

      // Content Actions - Topics
      | 'create_topic'
      | 'read_topics'
      | 'edit_own_topic' | 'delete_own_topic'
      | 'edit_any_topic' | 'delete_any_topic' // Mod/Admin/SuperAdmin
      | 'approve_topic' | 'move_topic' | 'pin_topic_in_section' | 'lock_topic'

      // Content Actions - Sections (Categories)
      | 'create_section' | 'read_sections' | 'edit_section' | 'delete_section' | 'reorder_sections'

      // Admin Area Access
      | 'access_moderation_tools'
      | 'access_user_management'
      | 'access_admin_dashboard'
      | 'access_site_configuration'
      | 'view_audit_logs';

    // Define resource types for context
    export type PermissionResource =
      | { type: 'profile'; profileId?: string; targetRole?: Profile['role'] } // profileId for specific user, targetRole for role-based checks
      | { type: 'post'; authorId?: string; sectionId?: string; } // sectionId if mods are section-specific
      | { type: 'topic'; authorId?: string; sectionId?: string; }
      | { type: 'section'; sectionId?: string; }
      | { type: 'admin_area'; areaName: 'moderation' | 'user_management' | 'site_config' | 'audit_logs' }
      | { type: 'general'; }; // For actions not tied to a specific resource instance

    export const usePermissions = () => {
      const { profile: currentUserProfile, user: currentUser, isLoadingAuth } = useUser();

      const can = (action: PermissionAction, resource?: PermissionResource): boolean => {
        if (isLoadingAuth || !currentUserProfile || !currentUser) {
          // If auth is loading or no user/profile, default to no permission
          // This prevents flicker or premature access denial/grant
          return false;
        }

        const role = currentUserProfile.role;
        const userId = currentUser.id;
        const userStatus = currentUserProfile.status;

        // Global rule: Non-approved users have very limited permissions (e.g., view own profile, read public content)
        if (userStatus !== 'approved') {
          if (action === 'view_own_profile' && resource?.type === 'profile' && resource.profileId === userId) return true;
          if (action === 'read_posts' || action === 'read_topics' || action === 'read_sections') return true; // Basic read might be allowed
          // For most other actions, non-approved users are denied
          return false;
        }

        // SUPER_ADMIN can do almost anything (exceptions might be self-destructive actions not coded here)
        if (role === 'SUPER_ADMIN') { // Corrected to uppercase
            // Example: SUPER_ADMIN cannot directly delete their own account via 'delete_user_account' action if resource targets self
            if (action === 'delete_user_account' && resource?.type === 'profile' && resource.profileId === userId) {
                return false; // Prevent self-delete through this generic check
            }
            return true;
        }

        switch (action) {
          // Profile Actions
          case 'view_own_profile':
            return resource?.type === 'profile' && resource.profileId === userId;
          case 'edit_own_profile':
            return resource?.type === 'profile' && resource.profileId === userId;

          case 'view_any_user_profile_basic': // Mod view
            return role === 'MODERATOR' && resource?.type === 'profile' && resource.targetRole === 'USER'; // Corrected to uppercase
          case 'view_any_user_profile_full': // Admin view
            return role === 'ADMIN' && resource?.type === 'profile' && (resource.targetRole === 'USER' || resource.targetRole === 'MODERATOR'); // Corrected to uppercase

          case 'edit_user_status': // Mod can edit USER status, Admin can edit USER/MODERATOR status
            if (resource?.type === 'profile' && resource.targetRole) {
              if (role === 'ADMIN' && (resource.targetRole === 'USER' || resource.targetRole === 'MODERATOR')) return true; // Corrected to uppercase
              if (role === 'MODERATOR' && resource.targetRole === 'USER') return true; // Corrected to uppercase
            }
            return false;

          case 'edit_user_role': // Admin can edit USER/MODERATOR roles
            return role === 'ADMIN' && resource?.type === 'profile' && // Corrected to uppercase
                   resource.targetRole !== 'ADMIN' && resource.targetRole !== 'SUPER_ADMIN';

          case 'create_user_account':
            return role === 'ADMIN'; // Corrected to uppercase (SUPER_ADMIN handled by global true)

          case 'delete_user_account':
            if (role === 'ADMIN' && resource?.type === 'profile' && resource.profileId !== userId && // Corrected to uppercase
                (resource.targetRole === 'USER' || resource.targetRole === 'MODERATOR')) {
              return true;
            }
            return false; // SUPER_ADMIN handled by global true, USER self-delete needs specific logic

          // Content Creation
          case 'create_post':
          case 'create_topic':
            return ['USER', 'MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase, SUPER_ADMIN is true

          // Own Content Management
          case 'edit_own_post':
          case 'delete_own_post':
            return resource?.type === 'post' && resource.authorId === userId && ['USER', 'MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase
          case 'edit_own_topic':
          case 'delete_own_topic':
            return resource?.type === 'topic' && resource.authorId === userId && ['USER', 'MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase

          // Any Content Management (Mod/Admin)
          case 'edit_any_post':
          case 'delete_any_post':
          case 'approve_post':
          case 'move_post':
          case 'pin_post_in_topic':
            return ['MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase, SUPER_ADMIN is true

          case 'edit_any_topic':
          case 'delete_any_topic':
          case 'approve_topic':
          case 'move_topic':
          case 'pin_topic_in_section':
          case 'lock_topic':
            return ['MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase, SUPER_ADMIN is true

          // Section Management
          case 'create_section':
          case 'edit_section':
          case 'delete_section':
          case 'reorder_sections':
            return role === 'ADMIN'; // Corrected to uppercase, SUPER_ADMIN is true

          case 'read_sections':
          case 'read_topics':
          case 'read_posts':
            return true; // All approved users can read

          // Admin Area Access
          case 'access_moderation_tools':
            return ['MODERATOR', 'ADMIN'].includes(role || ''); // Corrected to uppercase
          case 'access_user_management':
          case 'access_admin_dashboard':
            return role === 'ADMIN'; // Corrected to uppercase
          case 'access_site_configuration':
          case 'view_audit_logs':
            return role === 'ADMIN'; // Corrected to uppercase, SUPER_ADMIN is true

          default:
            return false;
        }
      };

      return { can, currentRole: currentUserProfile?.role, currentUserId: currentUser?.id, currentUserProfile, isLoadingAuth };
    };
