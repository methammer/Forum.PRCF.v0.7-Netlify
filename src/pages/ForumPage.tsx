import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Link } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { FolderKanban, MessageSquarePlus, Loader2, AlertTriangle } from 'lucide-react'; // Added Loader2 and AlertTriangle

interface ForumCategory {
  id: string;
  name: string;
  description: string | null;
  slug: string;
  created_at: string;
}

const ForumPage = () => {
  const [categories, setCategories] = useState<ForumCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCategories = async () => {
      setLoading(true);
      setError(null);
      try {
        const { data, error: categoriesError } = await supabase
          .from('forum_categories')
          .select('*')
          .order('name', { ascending: true });

        if (categoriesError) {
          throw categoriesError;
        }
        setCategories(data || []);
      } catch (err: any) {
        console.error('Error fetching categories:', err);
        setError('Impossible de charger les catégories du forum. Veuillez réessayer plus tard.');
      } finally {
        setLoading(false);
      }
    };

    fetchCategories();
  }, []);

  return (
    <div className="container mx-auto py-8 px-4 md:px-6">
      <header className="mb-10">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 className="text-4xl font-extrabold text-gray-800 dark:text-white">
              Forum PRCF
            </h1>
            <p className="mt-2 text-lg text-gray-600 dark:text-gray-300">
              Parcourez les catégories et participez aux discussions.
            </p>
          </div>
          <Button /* onClick={() => navigate('/forum/nouveau-sujet')} // TODO: Implement create post page */
            className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600"
            disabled // Temporarily disabled until functionality is ready
          >
            <MessageSquarePlus className="mr-2 h-5 w-5" />
            Nouveau Sujet
          </Button>
        </div>
      </header>

      {loading && (
        <div className="flex justify-center items-center py-10">
          <Loader2 className="h-12 w-12 animate-spin text-blue-600" />
          <p className="ml-4 text-lg text-gray-600 dark:text-gray-300">Chargement des catégories...</p>
        </div>
      )}

      {error && (
        <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700">
          <CardHeader>
            <div className="flex items-center text-red-600 dark:text-red-400">
              <AlertTriangle className="h-6 w-6 mr-2" />
              <CardTitle>Erreur</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-red-700 dark:text-red-300">{error}</p>
          </CardContent>
        </Card>
      )}

      {!loading && !error && categories.length === 0 && (
        <div className="text-center py-10">
          <FolderKanban className="mx-auto h-16 w-16 text-gray-400 dark:text-gray-500 mb-4" />
          <p className="text-xl text-gray-600 dark:text-gray-300">Aucune catégorie de forum disponible pour le moment.</p>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Revenez plus tard ou contactez un administrateur.</p>
        </div>
      )}

      {!loading && !error && categories.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {categories.map((category) => (
            <Card key={category.id} className="hover:shadow-xl transition-shadow duration-300 ease-in-out dark:bg-gray-800 flex flex-col">
              <CardHeader>
                <div className="flex items-center text-blue-600 dark:text-blue-400 mb-2">
                  <FolderKanban className="h-7 w-7 mr-3 flex-shrink-0" />
                  <CardTitle className="text-2xl font-semibold leading-tight">{category.name}</CardTitle>
                </div>
                {category.description && (
                  <CardDescription className="text-gray-600 dark:text-gray-400 line-clamp-2">
                    {category.description}
                  </CardDescription>
                )}
              </CardHeader>
              <CardContent className="flex-grow flex flex-col justify-end">
                {/* Placeholder for post count or last activity - to be implemented later */}
                {/* <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">X Sujets • Y Messages</p> */}
                <Button asChild variant="outline" className="w-full mt-auto border-blue-500 text-blue-500 hover:bg-blue-500 hover:text-white dark:border-blue-400 dark:text-blue-400 dark:hover:bg-blue-500 dark:hover:text-white">
                  <Link to={`/forum/categorie/${category.slug}`}>
                    Explorer {category.name}
                  </Link>
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
};

export default ForumPage;
