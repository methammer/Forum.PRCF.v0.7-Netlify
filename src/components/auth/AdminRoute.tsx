import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth'; 
import { useUser } from '@/contexts/UserContext'; // Import useUser for direct check
import { Loader2 } from 'lucide-react';

console.log('[AdminRoute.tsx MODULE] Evaluating');

const AdminRoute = () => {
  // 1. Call useUser() directly for comparison
  const directUserHookOutput = useUser();
  console.log('[AdminRoute] Output from direct call to useUser():', 
    { 
      session: directUserHookOutput.session ? 'exists' : 'null', 
      user: directUserHookOutput.user ? 'exists' : 'null',
      profile: directUserHookOutput.profile ? `status: ${directUserHookOutput.profile.status}, role: ${directUserHookOutput.profile.role}` : 'null',
      isLoadingAuth: directUserHookOutput.isLoadingAuth 
    }
  );

  // 2. Call useAuth()
  const authHookOutput = useAuth();
  // Destructure the values AdminRoute actually uses for its logic
  const { session, profile, isLoadingAuth, role } = authHookOutput; 

  // 3. Log the raw internal values from useAuth (which come from its own useUser call)
  console.log('[AdminRoute] Raw context values as seen by useAuth() internally:', {
    _rawContextUser: authHookOutput._rawContextUser ? 'exists' : 'null',
    _rawContextProfile: authHookOutput._rawContextProfile ? `status: ${authHookOutput._rawContextProfile.status}, role: ${authHookOutput._rawContextProfile.role}` : 'null',
    _rawContextIsLoadingAuth: authHookOutput._rawContextIsLoadingAuth,
    _rawContextSession: authHookOutput._rawContextSession ? 'exists' : 'null',
    _rawPermissionsLoading: authHookOutput._rawPermissionsLoading,
  });
  
  const location = useLocation();
  // This log uses the destructured session, profile, isLoadingAuth, role from useAuth()
  console.log(`[AdminRoute] Values used for logic (from useAuth output): isLoadingAuth: ${isLoadingAuth}, session: ${session ? 'exists' : 'null'}, profile status: ${profile?.status}, profile role: ${role}`);

  if (isLoadingAuth) {
    console.log('[AdminRoute] Rendering: Loader (isLoadingAuth from useAuth is true or undefined causing true branch)');
    return (
      <div className="flex items-center justify-center h-screen bg-background text-foreground">
        <Loader2 className="h-12 w-12 animate-spin text-primary" />
        <p className="ml-4 text-lg">Vérification de l'accès administrateur/modérateur...</p>
      </div>
    );
  }

  if (!session) {
    console.log('[AdminRoute] Rendering: Navigate to /connexion (session from useAuth is null)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Accès administrateur/modérateur refusé. Veuillez vous connecter." }} />;
  }

  if (!profile) {
    // This check might be redundant if !session already covers it, but good for safety.
    console.log('[AdminRoute] Rendering: Navigate to /connexion (profile from useAuth is null after load)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Profil introuvable ou non chargé." }} />;
  }

  if (profile.status !== 'approved') {
    console.log(`[AdminRoute] Rendering: Navigate to / (profile status from useAuth not approved: ${profile.status})`);
    return <Navigate to="/" replace state={{ from: location, message: "Votre compte n'est pas approuvé pour l'accès à cette section." }} />;
  }

  // Check if role (from useAuth) is MODERATOR, ADMIN, or SUPER_ADMIN
  if (!role || !['MODERATOR', 'ADMIN', 'SUPER_ADMIN'].includes(role)) {
    console.log(`[AdminRoute] Rendering: Navigate to / (profile role from useAuth not MODERATOR, ADMIN, or SUPER_ADMIN: ${role})`);
    return <Navigate to="/" replace state={{ from: location, message: "Accès refusé. Vous n'avez pas les droits de modération ou d'administration." }} />;
  }

  console.log('[AdminRoute] Rendering: Outlet (admin/moderator access granted based on useAuth values)');
  return <Outlet />;
};

export default AdminRoute;
