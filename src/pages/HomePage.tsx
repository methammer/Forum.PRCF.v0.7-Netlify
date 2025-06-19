import { supabase } from '@/lib/supabaseClient';
import { Button } from "@/components/ui/button";
import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { MessageSquareText, Users, Settings, Newspaper, LogOut } from 'lucide-react';

const HomePage = () => {
  const navigate = useNavigate();
  const user = supabase.auth.getUser(); // Example: get user info

  const handleSignOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error('Error signing out:', error);
    } else {
      navigate('/connexion');
    }
  };

  return (
    <div className="container mx-auto py-8 px-4 md:px-6">
      <header className="mb-10 text-center">
        <h1 className="text-4xl md:text-5xl font-extrabold text-gray-800 dark:text-white">
          Bienvenue sur le Forum Privé du PRCF
        </h1>
        <p className="mt-3 text-lg text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
          Votre espace centralisé pour les discussions, annonces et collaborations.
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
        {/* Forum Sections Card */}
        <Card className="hover:shadow-lg transition-shadow duration-300 dark:bg-gray-800">
          <CardHeader>
            <div className="flex items-center text-blue-600 dark:text-blue-400 mb-2">
              <MessageSquareText className="h-8 w-8 mr-3" />
              <CardTitle className="text-2xl font-semibold">Sections du Forum</CardTitle>
            </div>
            <CardDescription className="dark:text-gray-400">
              Accédez aux différentes catégories de discussion.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2">
              {['Discussions Générales', 'Annonces Internes', 'Projets en Cours'].map((section) => (
                <li key={section} className="flex items-center text-gray-700 dark:text-gray-300">
                  <Newspaper className="h-5 w-5 mr-2 text-gray-500 dark:text-gray-400" />
                  {section}
                </li>
              ))}
            </ul>
            <Button className="mt-6 w-full bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600" onClick={() => navigate('/forum')}>
              Explorer le Forum
            </Button>
          </CardContent>
        </Card>

        {/* Members Card */}
        <Card className="hover:shadow-lg transition-shadow duration-300 dark:bg-gray-800">
          <CardHeader>
            <div className="flex items-center text-green-600 dark:text-green-400 mb-2">
              <Users className="h-8 w-8 mr-3" />
              <CardTitle className="text-2xl font-semibold">Annuaire des Membres</CardTitle>
            </div>
            <CardDescription className="dark:text-gray-400">
              Consultez la liste des membres et leurs profils.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-gray-700 dark:text-gray-300 mb-4">
              Connectez-vous avec d'autres membres du PRCF.
            </p>
            <Button className="w-full bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600" onClick={() => navigate('/membres')}>
              Voir les Membres
            </Button>
          </CardContent>
        </Card>
        
        {/* Settings/Profile Card */}
        <Card className="hover:shadow-lg transition-shadow duration-300 dark:bg-gray-800">
          <CardHeader>
            <div className="flex items-center text-purple-600 dark:text-purple-400 mb-2">
              <Settings className="h-8 w-8 mr-3" />
              <CardTitle className="text-2xl font-semibold">Mon Compte</CardTitle>
            </div>
            <CardDescription className="dark:text-gray-400">
              Gérez votre profil et vos préférences.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-gray-700 dark:text-gray-300 mb-4">
              Mettez à jour vos informations personnelles et paramètres.
            </p>
            <Button className="w-full bg-purple-600 hover:bg-purple-700 dark:bg-purple-500 dark:hover:bg-purple-600" onClick={() => navigate('/profil')}>
              Accéder à Mon Profil
            </Button>
          </CardContent>
        </Card>
      </div>

      <div className="text-center mt-12">
        <Button 
          variant="outline" 
          onClick={handleSignOut} 
          className="border-red-500 text-red-500 hover:bg-red-500 hover:text-white dark:border-red-400 dark:text-red-400 dark:hover:bg-red-500 dark:hover:text-white"
        >
          <LogOut className="mr-2 h-5 w-5" />
          Déconnexion
        </Button>
      </div>
      
      {user && (
        <footer className="mt-16 pt-8 border-t border-gray-200 dark:border-gray-700 text-center">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Connecté en tant que : {user.email /* This is an example, adjust based on actual user object structure */}
          </p>
          <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">
            © {new Date().getFullYear()} PRCF. Tous droits réservés.
          </p>
        </footer>
      )}
    </div>
  );
};

export default HomePage;
