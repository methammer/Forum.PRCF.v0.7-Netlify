import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth'; 
import { Loader2 } from 'lucide-react';

console.log('[AdminRoute.tsx MODULE] Evaluating');

const AdminRoute = () => {
  const { session, profile, isLoadingAuth, role } = useAuth(); 
  const location = useLocation();
  console.log(`[AdminRoute] Rendering. isLoadingAuth: ${isLoadingAuth}, session: ${session ? 'exists' : 'null'}, profile status: ${profile?.status}, profile role: ${role}`);

  if (isLoadingAuth) {
    console.log('[AdminRoute] Rendering: Loader (isLoadingAuth is true)');
    return (
      <div className="flex items-center justify-center h-screen bg-background text-foreground">
        <Loader2 className="h-12 w-12 animate-spin text-primary" />
        <p className="ml-4 text-lg">Vérification de l'accès administrateur/modérateur...</p>
      </div>
    );
  }

  if (!session) {
    console.log('[AdminRoute] Rendering: Navigate to /connexion (no session)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Accès administrateur/modérateur refusé. Veuillez vous connecter." }} />;
  }

  if (!profile) {
    console.log('[AdminRoute] Rendering: Navigate to /connexion (no profile after load)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Profil introuvable ou non chargé." }} />;
  }

  if (profile.status !== 'approved') {
    console.log(`[AdminRoute] Rendering: Navigate to / (profile status not approved: ${profile.status})`);
    return <Navigate to="/" replace state={{ from: location, message: "Votre compte n'est pas approuvé pour l'accès à cette section." }} />;
  }

  // Check if role is MODERATOR, ADMIN, or SUPER_ADMIN (already correctly uppercase)
  if (!role || !['MODERATOR', 'ADMIN', 'SUPER_ADMIN'].includes(role)) {
    console.log(`[AdminRoute] Rendering: Navigate to / (profile role not MODERATOR, ADMIN, or SUPER_ADMIN: ${role})`);
    return <Navigate to="/" replace state={{ from: location, message: "Accès refusé. Vous n'avez pas les droits de modération ou d'administration." }} />;
  }

  console.log('[AdminRoute] Rendering: Outlet (admin/moderator access granted)');
  return <Outlet />;
};

export default AdminRoute;
