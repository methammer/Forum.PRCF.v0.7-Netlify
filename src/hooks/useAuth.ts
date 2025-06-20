import { User as SupabaseUser } from '@supabase/supabase-js';
import { useNavigate } from 'react-router-dom';
import { useToast } from '@/hooks/use-toast';
import { Profile, useUser } from '@/contexts/UserContext';
// Session from @supabase/supabase-js is implicitly used via UserContext's session state
import { usePermissions } from './usePermissions';
import { supabase } from '@/lib/supabaseClient';
import { Permission }  from '@/constants/permissions';

export interface AuthUser extends SupabaseUser {
  profile?: Profile | null;
}

export const useAuth = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  
  const { 
    user: contextUser, 
    profile: contextProfile, 
    isLoadingAuth: contextIsLoadingAuth,
    session: contextSession // Full Session object from UserContext
  } = useUser();

  // Log received context values
  console.log('[useAuth] Received from UserContext:', {
    contextUserExists: !!contextUser,
    contextUserId: contextUser?.id,
    contextProfileExists: !!contextProfile,
    contextProfileUsername: contextProfile?.username,
    contextSessionExists: !!contextSession,
    contextSessionUserId: contextSession?.user?.id,
    contextIsLoadingAuth
  });
  
  const { can, isLoading: permissionsLoading, currentRole } = usePermissions();

  const isLoading = contextIsLoadingAuth || permissionsLoading;

  // Changed: Construct authUser directly from contextSession.user
  // This makes authUser dependent on the user object within the session state from UserContext
  const authUser: AuthUser | null = contextSession?.user 
    ? { ...contextSession.user, profile: contextProfile } 
    : null;
  
  console.log('[useAuth] Constructed authUser:', {
    authUserExists: !!authUser,
    authUserId: authUser?.id,
    authUserProfileUsername: authUser?.profile?.username,
    derivedFrom: contextSession?.user ? 'contextSession.user' : 'null'
  });

  const signIn = async (email?: string, password?: string) => {
    if (!email || !password) {
      toast({ title: "Erreur", description: "Email et mot de passe requis.", variant: "destructive" });
      return;
    }
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      toast({ title: "Succès", description: "Connexion réussie !", className: "bg-green-500 text-white" });
      navigate('/');
    } catch (error: any) {
      toast({ title: "Erreur de connexion", description: error.message || "Identifiants incorrects.", variant: "destructive" });
    }
  };

  const signUp = async (email?: string, password?: string, username?: string) => {
    if (!email || !password || !username) {
      toast({ title: "Erreur", description: "Email, mot de passe et nom d'utilisateur requis.", variant: "destructive" });
      return;
    }
    try {
      const { data: authData, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            username: username,
          },
        },
      });

      if (signUpError) throw signUpError;
      if (!authData.user) throw new Error("Aucun utilisateur retourné après l'inscription.");

      toast({
        title: "Inscription réussie !",
        description: "Votre profil est en cours de création. Redirection...",
        className: "bg-green-500 text-white",
      });
    } catch (error: any) {
      toast({ title: "Erreur d'inscription", description: error.message || "Impossible de créer le compte.", variant: "destructive" });
    }
  };

  const signOut = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      toast({ title: "Déconnexion", description: "Vous avez été déconnecté." });
      navigate('/connexion');
    } catch (error: any) {
      toast({ title: "Erreur de déconnexion", description: error.message, variant: "destructive" });
    }
  };

  const canModerate = !isLoading && !!contextProfile && can(Permission.ACCESS_MODERATION_TOOLS);
  
  const canAdminister = !isLoading && !!contextProfile && 
    (
      can(Permission.MANAGE_USERS) || 
      can(Permission.MANAGE_SECTIONS) ||
      currentRole === 'SUPER_ADMIN'
    );
  
  return {
    session: authUser, // PostDetailPage receives this as `authUser`
    profile: contextProfile, // PostDetailPage receives this as `profile`
    isLoadingAuth: isLoading, 
    role: contextProfile?.role, 
    signIn,
    signUp,
    signOut,
    canModerate,
    canAdminister,
    _rawContextUser: contextUser,
    _rawContextProfile: contextProfile,
    _rawContextIsLoadingAuth: contextIsLoadingAuth,
    _rawContextSession: contextSession,
    _rawPermissionsLoading: permissionsLoading,
  };
};
