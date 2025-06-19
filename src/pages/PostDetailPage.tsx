import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Loader2, AlertTriangle, ArrowLeft, MessageSquare, CalendarDays, UserCircle, Tag } from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
// import ReactMarkdown from 'react-markdown'; // Future: for markdown rendering

interface PostDetails {
  post_id: string;
  post_title: string;
  post_content: string;
  post_created_at: string;
  post_updated_at: string;
  post_user_id: string;
  author_username: string | null;
  author_avatar_url: string | null;
  category_id: string;
  category_name: string;
  category_slug: string;
}

const PostDetailPage = () => {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const [post, setPost] = useState<PostDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!postId) {
      setError("ID du sujet manquant.");
      setLoading(false);
      return;
    }

    const fetchPostDetails = async () => {
      setLoading(true);
      setError(null);
      try {
        const { data, error: rpcError } = await supabase
          .rpc('get_post_details_with_author', { p_post_id: postId })
          .single(); // Expecting a single object or null

        if (rpcError) throw rpcError;
        if (!data) throw new Error("Sujet non trouvé ou vous n'avez pas la permission de le voir.");
        
        setPost(data as PostDetails);
      } catch (err: any) {
        console.error('Error fetching post details:', err);
        setError(err.message || 'Impossible de charger les détails du sujet.');
      } finally {
        setLoading(false);
      }
    };

    fetchPostDetails();
  }, [postId]);

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 flex justify-center items-center min-h-[calc(100vh-200px)]">
        <Loader2 className="h-12 w-12 animate-spin text-blue-600" />
        <p className="ml-4 text-lg text-gray-600 dark:text-gray-300">Chargement du sujet...</p>
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

  if (!post) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 text-center">
        <AlertTriangle className="mx-auto h-16 w-16 text-yellow-500 mb-4" />
        <p className="text-xl text-gray-700 dark:text-gray-200">Sujet non trouvé.</p>
        <Button variant="link" onClick={() => navigate('/forum')} className="mt-4">
          Retour au Forum
        </Button>
      </div>
    );
  }

  const getInitials = (name: string | null | undefined) => {
    if (!name) return '??';
    return name.split(' ').map(n => n[0]).join('').toUpperCase();
  };

  return (
    <div className="container mx-auto py-8 px-4 md:px-6 max-w-4xl">
      <Button 
        variant="outline" 
        onClick={() => navigate(`/forum/categorie/${post.category_slug}`)} 
        className="mb-6 text-sm"
      >
        <ArrowLeft className="mr-2 h-4 w-4" /> Retour à la catégorie : {post.category_name}
      </Button>

      <Card className="dark:bg-gray-800 shadow-xl">
        <CardHeader className="border-b dark:border-gray-700 p-6">
          <Link to={`/forum/categorie/${post.category_slug}`} className="text-sm text-blue-600 hover:underline dark:text-blue-400 flex items-center mb-2">
            <Tag className="h-4 w-4 mr-1" /> {post.category_name}
          </Link>
          <CardTitle className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white">
            {post.post_title}
          </CardTitle>
          <div className="flex items-center space-x-4 mt-3 text-sm text-gray-500 dark:text-gray-400">
            <Link to={`/profil/${post.post_user_id}`} className="flex items-center hover:underline">
              <Avatar className="h-8 w-8 mr-2">
                <AvatarImage src={post.author_avatar_url || undefined} alt={post.author_username || 'Auteur'} />
                <AvatarFallback>{getInitials(post.author_username)}</AvatarFallback>
              </Avatar>
              <span>{post.author_username || 'Utilisateur inconnu'}</span>
            </Link>
            <div className="flex items-center">
              <CalendarDays className="h-4 w-4 mr-1" />
              <span>Créé le {format(new Date(post.post_created_at), 'PPP p', { locale: fr })}</span>
            </div>
            {post.post_updated_at && new Date(post.post_updated_at).getTime() !== new Date(post.post_created_at).getTime() && (
              <div className="flex items-center text-xs italic">
                (Modifié le {format(new Date(post.post_updated_at), 'PPP p', { locale: fr })})
              </div>
            )}
          </div>
        </CardHeader>
        <CardContent className="p-6 prose dark:prose-invert max-w-none">
          {/* Replace with ReactMarkdown or similar for rich text rendering */}
          <div className="whitespace-pre-wrap">{post.post_content}</div>
        </CardContent>
      </Card>

      {/* Future: Replies section */}
      <div className="mt-8">
        <h2 className="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">Réponses</h2>
        <div className="p-6 bg-gray-50 dark:bg-gray-700/50 rounded-lg text-center">
          <MessageSquare className="h-12 w-12 mx-auto text-gray-400 dark:text-gray-500 mb-3" />
          <p className="text-gray-600 dark:text-gray-300">Les réponses ne sont pas encore implémentées.</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">Revenez bientôt !</p>
        </div>
      </div>
    </div>
  );
};

export default PostDetailPage;