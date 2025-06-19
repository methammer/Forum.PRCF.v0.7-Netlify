import { Outlet, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { LogOut, Home, Users, Settings, ShieldCheck, MessageSquareText, FolderKanban, ListOrdered, ShieldAlert } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';

const AdminLayout = () => {
  const navigate = useNavigate();
  const { signOut, profile, canAdminister, canModerate } = useAuth();

  const handleSignOut = async () => {
    await signOut();
    navigate('/connexion');
  };

  return (
    <div className="flex h-screen bg-gray-100 dark:bg-gray-900">
      <aside className="w-72 bg-white dark:bg-gray-800 shadow-md flex flex-col">
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <h1 className="text-2xl font-bold text-gray-800 dark:text-white flex items-center">
            <ShieldCheck className="mr-2 h-7 w-7 text-red-600 dark:text-red-400" />
            Panneau Admin
          </h1>
          {profile && (
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
              Rôle : <span className="font-semibold">{profile.role}</span>
            </p>
          )}
        </div>
        <nav className="flex-grow p-4 space-y-2">
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            onClick={() => navigate('/admin')}
          >
            <Home className="mr-3 h-5 w-5" />
            Tableau de Bord
          </Button>

          {/* User and Section Management for ADMIN/SUPER_ADMIN */}
          {canAdminister && (
            <>
              <Button
                variant="ghost"
                className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
                onClick={() => navigate('/admin/users')}
              >
                <Users className="mr-3 h-5 w-5" />
                Gestion des Utilisateurs
              </Button>
              <Button
                variant="ghost"
                className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
                onClick={() => navigate('/admin/sections')}
              >
                <ListOrdered className="mr-3 h-5 w-5" />
                Gestion des Sections
              </Button>
            </>
          )}
          
          {/* Moderation for MODERATOR, ADMIN, SUPER_ADMIN */}
          {canModerate && ( // This check is a bit redundant if AdminRoute already protects /admin for canModerate, but good for clarity
            <Button
              variant="ghost"
              className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              onClick={() => navigate('/admin/moderation')}
            >
              <ShieldAlert className="mr-3 h-5 w-5" />
              Modération Contenu
            </Button>
          )}

          {/* Example: Placeholder for other admin features */}
          <Button
            variant="ghost"
            disabled
            title="Prochainement"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            <MessageSquareText className="mr-3 h-5 w-5" />
            Gestion des Sujets
          </Button>
          <Button
            variant="ghost"
            disabled
            title="Prochainement"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            <FolderKanban className="mr-3 h-5 w-5" />
            Gestion des Catégories
          </Button>
           <Button
            variant="ghost"
            disabled
            title="Prochainement"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            <Settings className="mr-3 h-5 w-5" />
            Paramètres du Site
          </Button>
        </nav>
        <div className="p-4 space-y-2 border-t border-gray-200 dark:border-gray-700">
          <Button
            variant="outline"
            className="w-full dark:text-gray-300 dark:border-gray-500 dark:hover:bg-gray-700"
            onClick={() => navigate('/')}
          >
            <Home className="mr-2 h-5 w-5" />
            Retour au Site
          </Button>
          <Button
            variant="destructive"
            className="w-full"
            onClick={handleSignOut}
          >
            <LogOut className="mr-2 h-5 w-5" />
            Déconnexion
          </Button>
        </div>
      </aside>
      <main className="flex-1 p-6 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
