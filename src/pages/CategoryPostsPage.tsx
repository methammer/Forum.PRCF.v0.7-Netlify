import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { MessageSquarePlus, ArrowLeft, Loader2, AlertTriangle, FileText, UserCircle, CalendarDays } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { fr } from 'date-fns/locale';

interface ForumCategory {
  id: string;
  name: string;
  description: string | null;
  slug: string;
}

interface ForumPostEntry { // Renamed from ForumPost to avoid confusion with detailed post type
  id: string;
  title: string;
  created_at: string;
  user_id: string;
  profiles: { 
    username: string | null;
  } | null;
}

interface RpcPostData {
  post_id: string;
  post_title: string;
  post_created_at: string;
  post_user_id: string;
  author_username: string | null;
}

const CategoryPostsPage = () => {
  const { categorySlug } = useParams<{ categorySlug: string }>();
  const navigate = useNavigate();
  const [category, setCategory] = useState<ForumCategory | null>(null);
  const [posts, setPosts] = useState<ForumPostEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!categorySlug) {
      setError("Slug de catégorie manquant.");
      setLoading(false);
      return;
    }

    const fetchCategoryAndPosts = async () => {
      setLoading(true);
      setError(null);
      try {
        const { data: categoryData, error: categoryError } = await supabase
          .from('forum_categories')
          .select('*')
          .eq('slug', categorySlug)
          .single();

        if (categoryError) throw categoryError;
        if (!categoryData) throw new Error("Catégorie non trouvée.");
        setCategory(categoryData);

        const { data: rpcData, error: rpcError } = await supabase
          .rpc('get_category_posts_with_author', { p_category_slug: categorySlug });

        if (rpcError) {
          console.error('Supabase RPC error details:', rpcError);
          throw rpcError;
        }
        
        const transformedPosts: ForumPostEntry[] = (rpcData as RpcPostData[] || []).map(p => ({
          id: p.post_id,
          title: p.post_title,
          created_at: p.post_created_at,
          user_id: p.post_user_id,
          profiles: { username: p.author_username }
        }));
        setPosts(transformedPosts);

      } catch (err: any) {
        console.error('Error fetching category or posts:', err);
        setError(err.message || 'Impossible de charger les données de la catégorie. Veuillez réessayer plus tard.');
      } finally {
        setLoading(false);
      }
    };

    fetchCategoryAndPosts();
  }, [categorySlug]);

  const handleCreatePost = () => {
    if (categorySlug) {
      navigate(`/forum/nouveau-sujet/${categorySlug}`);
    }
  };

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 flex justify-center items-center min-h-[calc(100vh-200px)]">
        <Loader2 className="h-12 w-12 animate-spin text-blue-600" />
        <p className="ml-4 text-lg text-gray-600 dark:text-gray-300">Chargement des sujets...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6">
        <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700">
          <CardHeader>
            <div className="flex items-center text-red-600 dark:text-red-400">
              <AlertTriangle className="h-6 w-6 mr-2" />
              <CardTitle>Erreur</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-red-700 dark:text-red-300">{error}</p>
            <Button variant="outline" onClick={() => navigate('/forum')} className="mt-4">
              <ArrowLeft className="mr-2 h-4 w-4" /> Retour au Forum
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (!category) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 text-center">
        <AlertTriangle className="mx-auto h-16 w-16 text-yellow-500 mb-4" />
        <p className="text-xl text-gray-700 dark:text-gray-200">Catégorie non trouvée.</p>
        <Button variant="link" onClick={() => navigate('/forum')} className="mt-4">
          Retour au Forum
        </Button>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 md:px-6">
      <header className="mb-8">
        <Button variant="outline" onClick={() => navigate('/forum')} className="mb-6 text-sm">
          <ArrowLeft className="mr-2 h-4 w-4" /> Retour à la liste des catégories
        </Button>
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 className="text-3xl md:text-4xl font-extrabold text-gray-800 dark:text-white">
              {category.name}
            </h1>
            {category.description && (
              <p className="mt-2 text-md text-gray-600 dark:text-gray-300">
                {category.description}
              </p>
            )}
          </div>
          <Button 
            onClick={handleCreatePost}
            className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600"
          >
            <MessageSquarePlus className="mr-2 h-5 w-5" />
            Nouveau Sujet
          </Button>
        </div>
      </header>

      {posts.length === 0 ? (
        <div className="text-center py-10 border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-lg">
          <FileText className="mx-auto h-16 w-16 text-gray-400 dark:text-gray-500 mb-4" />
          <p className="text-xl text-gray-600 dark:text-gray-300">Aucun sujet dans cette catégorie pour le moment.</p>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Soyez le premier à en créer un !</p>
        </div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => (
            <Card key={post.id} className="hover:shadow-lg transition-shadow duration-200 ease-in-out dark:bg-gray-800">
              <CardContent className="p-4 md:p-6">
                <Link 
                  to={`/forum/sujet/${post.id}`} // Updated link to post detail page
                  className="block mb-1"
                >
                  <h3 className="text-xl font-semibold text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-500 transition-colors">
                    {post.title}
                  </h3>
                </Link>
                <div className="flex items-center text-xs text-gray-500 dark:text-gray-400 space-x-3">
                  <div className="flex items-center">
                    <UserCircle className="h-4 w-4 mr-1" />
                    {/* Consider linking to profile: <Link to={`/profil/${post.user_id}`}>{post.profiles?.username || 'Utilisateur inconnu'}</Link> */}
                    <span>{post.profiles?.username || 'Utilisateur inconnu'}</span>
                  </div>
                  <div className="flex items-center">
                    <CalendarDays className="h-4 w-4 mr-1" />
                    <span>
                      {formatDistanceToNow(new Date(post.created_at), { addSuffix: true, locale: fr })}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
};

export default CategoryPostsPage;