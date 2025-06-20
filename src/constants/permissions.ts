export enum Permission {
  // General
  LOGIN = 'login',
  VIEW_PUBLIC_FORUM = 'view_public_forum',
  CREATE_PROFILE = 'create_profile',
  EDIT_OWN_PROFILE = 'edit_own_profile',
  VIEW_ANY_PROFILE = 'view_any_profile',

  // Forum Content (User)
  CREATE_POST_IN_OPEN_CATEGORY = 'create_post_in_open_category',
  CREATE_POST_IN_ANY_CATEGORY = 'create_post_in_any_category', // For mods/admins if categories are locked
  EDIT_OWN_POST = 'edit_own_post',
  DELETE_OWN_POST = 'delete_own_post',
  CREATE_COMMENT = 'create_comment',
  EDIT_OWN_COMMENT = 'edit_own_comment',
  DELETE_OWN_COMMENT = 'delete_own_comment',
  REPORT_CONTENT = 'report_content',

  // Moderation
  ACCESS_MODERATION_TOOLS = 'access_moderation_tools',
  VIEW_REPORTED_CONTENT = 'view_reported_content',
  APPROVE_CONTENT = 'approve_content',
  REJECT_CONTENT = 'reject_content', // e.g., hide or mark as spam
  EDIT_ANY_POST = 'edit_any_post',
  DELETE_ANY_POST = 'delete_any_post',
  EDIT_ANY_COMMENT = 'edit_any_comment',
  DELETE_ANY_COMMENT = 'delete_any_comment',
  WARN_USER = 'warn_user',
  SUSPEND_USER = 'suspend_user', // Soft ban
  LOCK_THREAD = 'lock_thread',
  UNLOCK_THREAD = 'unlock_thread',
  PIN_THREAD = 'pin_thread',
  UNPIN_THREAD = 'unpin_thread',

  // Admin
  ACCESS_ADMIN_DASHBOARD = 'access_admin_dashboard',
  MANAGE_USERS = 'manage_users', // General permission for user management section
  VIEW_USER_LIST = 'view_user_list',
  CREATE_USER = 'create_user',
  EDIT_USER_PROFILE = 'edit_user_profile', // Admin editing any user
  CHANGE_USER_ROLE = 'change_user_role',
  APPROVE_USER_REGISTRATION = 'approve_user_registration',
  REJECT_USER_REGISTRATION = 'reject_user_registration',
  DELETE_USER = 'delete_user', // Hard delete user

  MANAGE_SECTIONS = 'manage_sections', // General permission for section management
  CREATE_SECTION = 'create_section', // Forum category/section
  EDIT_SECTION = 'edit_section',
  DELETE_SECTION = 'delete_section',
  REORDER_SECTIONS = 'reorder_sections',
  LOCK_SECTION_FOR_USERS = 'lock_section_for_users', // Only mods/admins can post

  MANAGE_SITE_SETTINGS = 'manage_site_settings',
  VIEW_AUDIT_LOGS = 'view_audit_logs',

  // Super Admin - Has all permissions implicitly
  SUPER_ADMIN_FULL_ACCESS = 'super_admin_full_access', 
}

export type Role = 'USER' | 'MODERATOR' | 'ADMIN' | 'SUPER_ADMIN';

export const RolePermissions: Record<Role, Permission[]> = {
  USER: [
    Permission.LOGIN,
    Permission.VIEW_PUBLIC_FORUM,
    Permission.CREATE_PROFILE,
    Permission.EDIT_OWN_PROFILE,
    Permission.VIEW_ANY_PROFILE,
    Permission.CREATE_POST_IN_OPEN_CATEGORY,
    Permission.EDIT_OWN_POST,
    Permission.DELETE_OWN_POST,
    Permission.CREATE_COMMENT,
    Permission.EDIT_OWN_COMMENT,
    Permission.DELETE_OWN_COMMENT,
    Permission.REPORT_CONTENT,
  ],
  MODERATOR: [
    // Inherits USER permissions implicitly if needed, or list them explicitly
    // For clarity, let's list some key ones and add moderation specific ones
    Permission.LOGIN,
    Permission.VIEW_PUBLIC_FORUM,
    Permission.EDIT_OWN_PROFILE,
    Permission.VIEW_ANY_PROFILE,
    Permission.CREATE_POST_IN_ANY_CATEGORY, // Can post even if locked for users
    Permission.EDIT_OWN_POST,
    Permission.DELETE_OWN_POST,
    Permission.CREATE_COMMENT,
    Permission.EDIT_OWN_COMMENT,
    Permission.DELETE_OWN_COMMENT,
    Permission.REPORT_CONTENT,

    Permission.ACCESS_MODERATION_TOOLS,
    Permission.VIEW_REPORTED_CONTENT,
    Permission.APPROVE_CONTENT,
    Permission.REJECT_CONTENT,
    Permission.EDIT_ANY_POST,
    Permission.DELETE_ANY_POST,
    Permission.EDIT_ANY_COMMENT,
    Permission.DELETE_ANY_COMMENT,
    Permission.WARN_USER,
    Permission.LOCK_THREAD,
    Permission.UNLOCK_THREAD,
    Permission.PIN_THREAD,
    Permission.UNPIN_THREAD,
  ],
  ADMIN: [
    // Inherits MODERATOR permissions implicitly or list explicitly
    // For clarity, listing key ones and adding admin specific ones
    Permission.LOGIN,
    Permission.VIEW_PUBLIC_FORUM,
    Permission.EDIT_OWN_PROFILE,
    Permission.VIEW_ANY_PROFILE,
    Permission.CREATE_POST_IN_ANY_CATEGORY,
    Permission.EDIT_OWN_POST,
    Permission.DELETE_OWN_POST,
    Permission.CREATE_COMMENT,
    Permission.EDIT_OWN_COMMENT,
    Permission.DELETE_OWN_COMMENT,
    Permission.REPORT_CONTENT,

    Permission.ACCESS_MODERATION_TOOLS,
    Permission.VIEW_REPORTED_CONTENT,
    Permission.APPROVE_CONTENT,
    Permission.REJECT_CONTENT,
    Permission.EDIT_ANY_POST,
    Permission.DELETE_ANY_POST,
    Permission.EDIT_ANY_COMMENT,
    Permission.DELETE_ANY_COMMENT,
    Permission.WARN_USER,
    Permission.LOCK_THREAD,
    Permission.UNLOCK_THREAD,
    Permission.PIN_THREAD,
    Permission.UNPIN_THREAD,

    Permission.ACCESS_ADMIN_DASHBOARD,
    Permission.MANAGE_USERS,
    Permission.VIEW_USER_LIST,
    Permission.CREATE_USER,
    Permission.EDIT_USER_PROFILE,
    Permission.CHANGE_USER_ROLE,
    Permission.APPROVE_USER_REGISTRATION,
    Permission.REJECT_USER_REGISTRATION,
    Permission.DELETE_USER,
    
    Permission.MANAGE_SECTIONS,
    Permission.CREATE_SECTION,
    Permission.EDIT_SECTION,
    Permission.DELETE_SECTION,
    Permission.REORDER_SECTIONS,
    Permission.LOCK_SECTION_FOR_USERS,

    Permission.MANAGE_SITE_SETTINGS,
    Permission.VIEW_AUDIT_LOGS,
    Permission.SUSPEND_USER, // Admins can suspend
  ],
  SUPER_ADMIN: [
    Permission.SUPER_ADMIN_FULL_ACCESS, // This single permission grants all access in usePermissions hook
    // No need to list others if SUPER_ADMIN_FULL_ACCESS is handled as granting all
  ],
};
