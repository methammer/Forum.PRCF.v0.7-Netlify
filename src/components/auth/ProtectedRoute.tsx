import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useUser } from '@/contexts/UserContext'; // Correct import
import { Loader2 } from 'lucide-react';

console.log('[ProtectedRoute.tsx MODULE] Evaluating (v9.0 - UserContext)');

const ProtectedRoute = () => {
  // The error stack trace points to this call to useUser()
  const { session, profile, isLoadingAuth } = useUser(); 
  const location = useLocation();
  console.log(`[ProtectedRoute v9.0] Rendering. isLoadingAuth: ${isLoadingAuth}, session: ${session ? 'exists' : 'null'}, profile status: ${profile?.status}`);

  if (isLoadingAuth) {
    console.log('[ProtectedRoute v9.0] Rendering: Loader (isLoadingAuth is true)');
    return (
      <div className="flex items-center justify-center h-screen bg-background text-foreground">
        <Loader2 className="h-12 w-12 animate-spin text-primary" />
        <p className="ml-4 text-lg">Vérification de l'accès...</p>
      </div>
    );
  }

  if (!session) {
    console.log('[ProtectedRoute v9.0] Rendering: Navigate to /connexion (no session)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Vous devez être connecté pour accéder à cette page." }} />;
  }

  if (!profile) {
    console.log('[ProtectedRoute v9.0] Rendering: Navigate to /connexion (session exists, but no profile found/loaded)');
    return <Navigate to="/connexion" replace state={{ from: location, message: "Votre profil est introuvable. Veuillez vous reconnecter ou contacter un administrateur." }} />;
  }
  
  if (profile.status !== 'approved') {
    let message = "Votre compte n'est pas encore approuvé ou son statut est indéterminé.";
    if (profile.status === 'pending_approval') {
      message = "Votre compte est en attente d'approbation.";
    } else if (profile.status === 'rejected') {
      message = "L'accès à votre compte a été refusé.";
    }
    console.log(`[ProtectedRoute v9.0] Rendering: Navigate to /connexion (profile status: ${profile.status})`);
    return <Navigate to="/connexion" replace state={{ from: location, message }} />;
  }

  console.log('[ProtectedRoute v9.0] Rendering: Outlet (session and approved profile exist)');
  return <Outlet />;
};

export default ProtectedRoute;
