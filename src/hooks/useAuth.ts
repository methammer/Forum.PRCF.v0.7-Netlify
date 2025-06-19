import { useUser, Profile } from '@/contexts/UserContext';
import { User as SupabaseUser, Session } from '@supabase/supabase-js';

interface AuthInfo {
  authUser: SupabaseUser | null;
  profile: Profile | null;
  session: Session | null;
  isLoadingAuth: boolean;
  role: Profile['role'] | null;
  isUser: boolean;
  isModerator: boolean;
  isAdmin: boolean;
  isSuperAdmin: boolean;
  canModerate: boolean; // MODERATOR, ADMIN, SUPER_ADMIN
  canAdminister: boolean; // ADMIN, SUPER_ADMIN
  signOut: () => Promise<void>;
}

export const useAuth = (): AuthInfo => {
  const context = useUser(); // context already handles the uninitialized sentinel

  const role = context.profile?.role ?? null;

  // All role checks should use uppercase as per the Profile type and database enum
  const isUser = role === 'USER';
  const isModerator = role === 'MODERATOR';
  const isAdmin = role === 'ADMIN';
  const isSuperAdmin = role === 'SUPER_ADMIN';

  const canModerate = role === 'MODERATOR' || role === 'ADMIN' || role === 'SUPER_ADMIN';
  const canAdminister = role === 'ADMIN' || role === 'SUPER_ADMIN';

  return {
    authUser: context.user,
    profile: context.profile,
    session: context.session,
    isLoadingAuth: context.isLoadingAuth,
    role,
    isUser,
    isModerator,
    isAdmin,
    isSuperAdmin,
    canModerate,
    canAdminister,
    signOut: context.signOut,
  };
};
