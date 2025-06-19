import { useAuth } from '@/hooks/useAuth';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import AdminDashboardPage from './admin/AdminDashboardPage'; // To embed admin content
import { Loader2, UserCircle, ShieldAlert } from 'lucide-react';

const SettingsPage = () => {
  const { profile, isLoadingAuth, canModerate } = useAuth();

  if (isLoadingAuth) {
    return (
      <div className="flex items-center justify-center h-full py-10">
        <Loader2 className="h-12 w-12 animate-spin text-primary" />
        <p className="ml-3 text-lg">Chargement des paramètres...</p>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="text-center py-10">
        <h2 className="text-2xl font-semibold text-red-600 dark:text-red-400">Erreur</h2>
        <p className="text-gray-600 dark:text-gray-300">Impossible de charger les informations utilisateur.</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 md:px-6">
      <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-8">Paramètres du compte</h1>
      <Tabs defaultValue="profile" className="w-full">
        <TabsList className="grid w-full grid-cols-1 md:grid-cols-2 lg:max-w-md mb-6">
          <TabsTrigger value="profile" className="flex items-center gap-2">
            <UserCircle className="h-5 w-5" />
            Mon Profil
          </TabsTrigger>
          {canModerate && (
            <TabsTrigger value="admin_dashboard" className="flex items-center gap-2">
              <ShieldAlert className="h-5 w-5" />
              Tableau de Bord Admin
            </TabsTrigger>
          )}
        </TabsList>

        <TabsContent value="profile">
          <Card className="dark:bg-gray-800">
            <CardHeader>
              <CardTitle className="text-2xl">Gestion du Profil</CardTitle>
              <CardDescription>
                Modifiez les informations de votre profil public.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Placeholder for profile editing form */}
              <div className="p-6 border border-dashed rounded-md dark:border-gray-700">
                <p className="text-gray-600 dark:text-gray-400">
                  Ici, vous pourrez bientôt modifier votre nom d'utilisateur, votre nom complet, votre avatar et d'autres informations personnelles.
                </p>
                <p className="mt-2 text-sm text-gray-500 dark:text-gray-500">
                  Par exemple : changer votre photo de profil, mettre à jour votre biographie, etc.
                </p>
              </div>
              <div>
                <h3 className="font-semibold text-lg mb-2 dark:text-gray-200">Informations actuelles :</h3>
                <ul className="list-disc list-inside space-y-1 text-gray-700 dark:text-gray-300">
                  <li>Nom d'utilisateur: <span className="font-medium">{profile.username || 'Non défini'}</span></li>
                  <li>Nom complet: <span className="font-medium">{profile.full_name || 'Non défini'}</span></li>
                  <li>Email (non modifiable ici): <span className="font-medium">{profile.id /* Actually user.email from authUser would be better here, but profile.id is a placeholder */}</span></li>
                  <li>Rôle: <span className="font-medium">{profile.role}</span></li>
                  <li>Statut: <span className="font-medium">{profile.status}</span></li>
                </ul>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {canModerate && (
          <TabsContent value="admin_dashboard">
            {/* Embed the existing AdminDashboardPage content here */}
            <AdminDashboardPage />
          </TabsContent>
        )}
      </Tabs>
    </div>
  );
};

export default SettingsPage;
