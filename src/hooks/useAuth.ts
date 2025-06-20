import { User as SupabaseUser } from '@supabase/supabase-js';
import { useNavigate } from 'react-router-dom';
import { useToast } from '@/hooks/use-toast';
import { Profile, useUser } from '@/contexts/UserContext';
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
    session: contextSession
  } = useUser();
  
  const { can, isLoading: permissionsLoading, currentRole } = usePermissions();

  const isLoading = contextIsLoadingAuth || permissionsLoading;

  const authUser: AuthUser | null = contextUser 
    ? { ...contextUser, profile: contextProfile } 
    : null;
  const profile: Profile | null = contextProfile;

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

  // Flag to show moderation tools link
  const canModerate = !isLoading && !!profile && can(Permission.ACCESS_MODERATION_TOOLS);
  
  // Flag to show User and Section management links in AdminLayout
  // An ADMIN should have MANAGE_USERS or MANAGE_SECTIONS. SUPER_ADMIN has all.
  const canAdminister = !isLoading && !!profile && 
    (
      can(Permission.MANAGE_USERS) || 
      can(Permission.MANAGE_SECTIONS) ||
      currentRole === 'SUPER_ADMIN' // SUPER_ADMIN can always administer
    );
  
  const sessionForAdminRoute = authUser; 
  const profileForAdminRoute = profile;
  const isLoadingAuthForAdminRoute = isLoading; 
  const roleForAdminRoute = profile?.role;

  return {
    session: sessionForAdminRoute, 
    profile: profileForAdminRoute,
    isLoadingAuth: isLoadingAuthForAdminRoute, 
    role: roleForAdminRoute, 
    signIn,
    signUp,
    signOut,
    canModerate,
    canAdminister, // Corrected name
    // Raw values for debugging (can be removed later):
    _rawContextUser: contextUser,
    _rawContextProfile: contextProfile,
    _rawContextIsLoadingAuth: contextIsLoadingAuth,
    _rawContextSession: contextSession,
    _rawPermissionsLoading: permissionsLoading,
  };
};
