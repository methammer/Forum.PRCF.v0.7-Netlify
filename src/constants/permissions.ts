export enum Permission {
      // User Management
      VIEW_USER_LIST = "VIEW_USER_LIST",
      CREATE_USER = "CREATE_USER",
      EDIT_USER_PROFILE = "EDIT_USER_PROFILE",
      CHANGE_USER_ROLE = "CHANGE_USER_ROLE",
      APPROVE_USER_REGISTRATION = "APPROVE_USER_REGISTRATION",
      DELETE_USER = "DELETE_USER",
      SEND_PASSWORD_RESET_EMAIL = "SEND_PASSWORD_RESET_EMAIL", // New permission

      // Content Moderation
      VIEW_MODERATION_PANEL = "VIEW_MODERATION_PANEL",
      SOFT_DELETE_CONTENT = "SOFT_DELETE_CONTENT",
      RESTORE_CONTENT = "RESTORE_CONTENT",
      PERMANENTLY_DELETE_CONTENT = "PERMANENTLY_DELETE_CONTENT",
      VIEW_REPORTS = "VIEW_REPORTS",
      MANAGE_REPORTS = "MANAGE_REPORTS",
      EDIT_ANY_POST = "EDIT_ANY_POST",
      EDIT_ANY_REPLY = "EDIT_ANY_REPLY",

      // Audit Log
      VIEW_AUDIT_LOGS = "VIEW_AUDIT_LOGS",

      // Forum Management
      MANAGE_CATEGORIES = "MANAGE_CATEGORIES",
      MANAGE_TAGS = "MANAGE_TAGS",
      VIEW_FORUM_SETTINGS = "VIEW_FORUM_SETTINGS",
      EDIT_FORUM_SETTINGS = "EDIT_FORUM_SETTINGS",

      // User Actions (related to sanctions)
      WARN_USER = "WARN_USER",
      SUSPEND_USER = "SUSPEND_USER",
      BAN_USER = "BAN_USER",
      VIEW_USER_SANCTIONS = "VIEW_USER_SANCTIONS", // View a user's sanction history
      MANAGE_USER_SANCTIONS = "MANAGE_USER_SANCTIONS", // Lift sanctions, etc.
    }

    export type Role = "USER" | "MODERATOR" | "ADMIN" | "SUPER_ADMIN";

    export const ROLES: Role[] = ["USER", "MODERATOR", "ADMIN", "SUPER_ADMIN"];

    // Define permissions for each role
    // SUPER_ADMIN gets all permissions by default in usePermissions hook if not explicitly listed
    export const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
      USER: [],
      MODERATOR: [
        Permission.VIEW_MODERATION_PANEL,
        Permission.SOFT_DELETE_CONTENT,
        Permission.RESTORE_CONTENT,
        Permission.VIEW_REPORTS,
        Permission.MANAGE_REPORTS, // Typically includes changing status
        Permission.EDIT_ANY_POST, // If moderators can edit content
        Permission.EDIT_ANY_REPLY, // If moderators can edit content
        Permission.WARN_USER,
        Permission.VIEW_USER_SANCTIONS,
      ],
      ADMIN: [
        Permission.VIEW_USER_LIST,
        Permission.CREATE_USER,
        Permission.EDIT_USER_PROFILE,
        Permission.CHANGE_USER_ROLE,
        Permission.APPROVE_USER_REGISTRATION,
        Permission.DELETE_USER,
        Permission.SEND_PASSWORD_RESET_EMAIL, // Grant to ADMIN

        Permission.VIEW_MODERATION_PANEL,
        Permission.SOFT_DELETE_CONTENT,
        Permission.RESTORE_CONTENT,
        Permission.PERMANENTLY_DELETE_CONTENT,
        Permission.VIEW_REPORTS,
        Permission.MANAGE_REPORTS,
        Permission.EDIT_ANY_POST,
        Permission.EDIT_ANY_REPLY,
        
        Permission.VIEW_AUDIT_LOGS,

        Permission.MANAGE_CATEGORIES,
        Permission.MANAGE_TAGS,
        Permission.VIEW_FORUM_SETTINGS,
        Permission.EDIT_FORUM_SETTINGS,

        Permission.WARN_USER,
        Permission.SUSPEND_USER,
        Permission.BAN_USER,
        Permission.VIEW_USER_SANCTIONS,
        Permission.MANAGE_USER_SANCTIONS,
      ],
      SUPER_ADMIN: Object.values(Permission), // Super admin has all permissions
    };
