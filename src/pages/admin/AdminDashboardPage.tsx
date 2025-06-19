import { useEffect, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useUser } from "@/contexts/UserContext";
import { supabase } from "@/lib/supabaseClient";
import { BarChart, Users, MessageSquareText, FolderKanban, UserCheck, Loader2 } from "lucide-react";

interface DashboardStats {
  totalUsers: number;
  pendingApprovalUsers: number;
  forumTopics: number;
  activeCategories: number;
}

const AdminDashboardPage = () => {
  const { profile: adminProfile } = useUser();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDashboardStats = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const { count: totalUsersCount, error: totalUsersError } = await supabase
          .from('profiles')
          .select('*', { count: 'exact', head: true });

        if (totalUsersError) throw totalUsersError;

        const { count: pendingUsersCount, error: pendingUsersError } = await supabase
          .from('profiles')
          .select('*', { count: 'exact', head: true })
          .eq('status', 'pending_approval');

        if (pendingUsersError) throw pendingUsersError;

        // Placeholder values for forum topics and active categories
        const forumTopicsCount = 0; 
        const activeCategoriesCount = 0;

        setStats({
          totalUsers: totalUsersCount || 0,
          pendingApprovalUsers: pendingUsersCount || 0,
          forumTopics: forumTopicsCount,
          activeCategories: activeCategoriesCount,
        });
      } catch (err: any) {
        console.error("Error fetching dashboard stats:", err);
        setError("Erreur lors de la récupération des statistiques du tableau de bord.");
      } finally {
        setIsLoading(false);
      }
    };

    fetchDashboardStats();
  }, []);

  const renderStatCardContent = (value: number | undefined, loading: boolean, description: string) => {
    if (loading) {
      return <Loader2 className="h-6 w-6 animate-spin text-gray-500 dark:text-gray-400" />;
    }
    if (typeof value === 'undefined') {
      return <span className="text-sm text-red-500">Erreur</span>;
    }
    return (
      <>
        <div className="text-2xl font-bold text-gray-900 dark:text-white">{value}</div>
        <p className="text-xs text-gray-500 dark:text-gray-400">{description}</p>
      </>
    );
  };

  return (
    <div className="space-y-8 p-4 md:p-6">
      <header className="mb-6">
        <h1 className="text-3xl md:text-4xl font-bold text-gray-800 dark:text-white">
          Tableau de Bord Administrateur
        </h1>
        {adminProfile && (
          <p className="mt-1 text-lg text-gray-600 dark:text-gray-300">
            Bienvenue, {adminProfile.username || adminProfile.full_name || "Admin"} !
          </p>
        )}
      </header>

      {error && <p className="text-red-500 dark:text-red-400 bg-red-100 dark:bg-red-900/30 p-3 rounded-md">{error}</p>}

      <div className="grid gap-4 md:gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card className="dark:bg-gray-800 shadow-md hover:shadow-lg transition-shadow duration-300">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-700 dark:text-gray-300">
              Utilisateurs Enregistrés
            </CardTitle>
            <Users className="h-5 w-5 text-blue-500 dark:text-blue-400" />
          </CardHeader>
          <CardContent>
            {renderStatCardContent(stats?.totalUsers, isLoading, stats && stats.totalUsers > 0 ? "+X% depuis le mois dernier" : "Aucun utilisateur")}
          </CardContent>
        </Card>
        <Card className="dark:bg-gray-800 shadow-md hover:shadow-lg transition-shadow duration-300">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-700 dark:text-gray-300">
              Sujets du Forum
            </CardTitle>
            <MessageSquareText className="h-5 w-5 text-green-500 dark:text-green-400" />
          </CardHeader>
          <CardContent>
            {renderStatCardContent(stats?.forumTopics, isLoading, stats && stats.forumTopics > 0 ? "+Y nouveaux aujourd'hui" : "Aucun sujet (à implémenter)")}
          </CardContent>
        </Card>
        <Card className="dark:bg-gray-800 shadow-md hover:shadow-lg transition-shadow duration-300">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-700 dark:text-gray-300">
              Catégories Actives
            </CardTitle>
            <FolderKanban className="h-5 w-5 text-yellow-500 dark:text-yellow-400" />
          </CardHeader>
          <CardContent>
            {renderStatCardContent(stats?.activeCategories, isLoading, "Actuellement gérées (à implémenter)")}
          </CardContent>
        </Card>
        <Card className="dark:bg-gray-800 shadow-md hover:shadow-lg transition-shadow duration-300">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-700 dark:text-gray-300">
              Approbations en Attente
            </CardTitle>
            <UserCheck className="h-5 w-5 text-red-500 dark:text-red-400" />
          </CardHeader>
          <CardContent>
            {renderStatCardContent(stats?.pendingApprovalUsers, isLoading, stats?.pendingApprovalUsers === 1 ? "Utilisateur à vérifier" : "Utilisateurs à vérifier")}
          </CardContent>
        </Card>
      </div>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Activité Récente du Site</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Aperçu de l'engagement des utilisateurs (données fictives).
          </CardDescription>
        </CardHeader>
        <CardContent className="h-64 flex items-center justify-center bg-gray-50 dark:bg-gray-700/50 rounded-md">
          {isLoading ? (
            <Loader2 className="h-12 w-12 md:h-16 md:w-16 animate-spin text-gray-400 dark:text-gray-500" />
          ) : (
            <div className="text-center">
              <BarChart className="h-24 w-24 md:h-32 md:w-32 text-gray-400 dark:text-gray-500 mx-auto" />
              <p className="mt-4 text-gray-500 dark:text-gray-400">Données graphiques à venir...</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default AdminDashboardPage;
