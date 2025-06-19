import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth'; 
import { Button } from '@/components/ui/button';
import { LogOut, Home, Users, Settings, MessageSquare, LayoutGrid, ShieldCheck } from 'lucide-react';

const MainLayout = () => {
  const navigate = useNavigate();
  const { signOut, canModerate, profile } = useAuth(); // Get signOut, canModerate and profile

  const handleSignOut = async () => {
    await signOut();
    navigate('/connexion'); 
  };

  return (
    <div className="flex h-screen bg-gray-100 dark:bg-gray-900">
      {/* Sidebar */}
      <aside className="w-64 bg-white dark:bg-gray-800 shadow-md flex flex-col">
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <h1 className="text-2xl font-bold text-gray-800 dark:text-white flex items-center">
            <MessageSquare className="mr-2 h-7 w-7 text-blue-600 dark:text-blue-400" />
            PRCF Forum
          </h1>
        </div>
        <nav className="flex-grow p-4 space-y-2">
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            onClick={() => navigate('/')}
          >
            <Home className="mr-3 h-5 w-5" />
            Accueil
          </Button>
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            onClick={() => navigate('/forum')}
          >
            <LayoutGrid className="mr-3 h-5 w-5" />
            Forum
          </Button>
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            onClick={() => profile && navigate(`/profil/${profile.id}`)} // Navigate to own profile
            disabled={!profile}
            title={profile ? "Mon Profil" : "Chargement..."}
          >
            <Users className="mr-3 h-5 w-5" /> 
            Mon Profil 
          </Button>
          <Button
            variant="ghost"
            className="w-full justify-start text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
            onClick={() => navigate('/parametre')} // Navigate to settings page
          >
            <Settings className="mr-3 h-5 w-5" />
            Paramètres
          </Button>

          {/* Admin Panel Link - Conditionally Rendered if user can moderate */}
          {canModerate && (
            <>
              <hr className="my-2 border-gray-200 dark:border-gray-700" />
              <Button
                variant="ghost"
                className="w-full justify-start text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-gray-700 font-semibold"
                onClick={() => navigate('/admin')}
              >
                <ShieldCheck className="mr-3 h-5 w-5" />
                Panneau Admin
              </Button>
            </>
          )}
        </nav>
        <div className="p-4 border-t border-gray-200 dark:border-gray-700">
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

      {/* Main Content Area */}
      <main className="flex-1 p-6 overflow-auto">
        <Outlet /> {/* Content of nested routes will be rendered here */}
      </main>
    </div>
  );
};

export default MainLayout;
