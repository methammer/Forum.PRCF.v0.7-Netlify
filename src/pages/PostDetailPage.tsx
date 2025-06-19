import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Loader2, AlertTriangle, ArrowLeft, MessageSquare, CalendarDays, UserCircle, Tag, Send } from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
import { useToast } from '@/hooks/use-toast';

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

interface Reply {
  reply_id: string;
  reply_content: string;
  reply_created_at: string;
  reply_updated_at: string;
  reply_user_id: string;
  author_username: string | null;
  author_avatar_url: string | null;
  parent_reply_id: string | null;
}

const PostDetailPage = () => {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [post, setPost] = useState<PostDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [replies, setReplies] = useState<Reply[]>([]);
  const [repliesLoading, setRepliesLoading] = useState(true);
  const [repliesError, setRepliesError] = useState<string | null>(null);
  const [newReplyContent, setNewReplyContent] = useState('');
  const [isSubmittingReply, setIsSubmittingReply] = useState(false);
  const [currentUser, setCurrentUser] = useState<any | null>(null);

  useEffect(() => {
    const fetchCurrentUser = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        setCurrentUser(session.user);
      }
    };
    fetchCurrentUser();

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      setCurrentUser(session?.user ?? null);
    });

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!postId) {
      setError("ID du sujet manquant.");
      setLoading(false);
      setRepliesLoading(false);
      return;
    }

    const fetchPostDetails = async () => {
      setLoading(true);
      setError(null);
      try {
        const { data, error: rpcError } = await supabase
          .rpc('get_post_details_with_author', { p_post_id: postId })
          .single();

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

    const fetchReplies = async () => {
      setRepliesLoading(true);
      setRepliesError(null);
      try {
        const { data, error: rpcError } = await supabase
          .rpc('get_post_replies_with_author', { p_post_id: postId });

        if (rpcError) throw rpcError;
        setReplies(data as Reply[]);
      } catch (err: any) {
        console.error('Error fetching replies:', err);
        setRepliesError(err.message || 'Impossible de charger les réponses.');
      } finally {
        setRepliesLoading(false);
      }
    };

    fetchPostDetails();
    fetchReplies();
  }, [postId]);

  const getInitials = (name: string | null | undefined) => {
    if (!name) return '??';
    return name.split(' ').map(n => n[0]).join('').toUpperCase();
  };

  const handleAddReply = async () => {
    if (!newReplyContent.trim()) {
      toast({
        title: "Erreur",
        description: "Le contenu de la réponse ne peut pas être vide.",
        variant: "destructive",
      });
      return;
    }
    if (!currentUser) {
      toast({
        title: "Authentification requise",
        description: "Vous devez être connecté pour répondre.",
        variant: "destructive",
      });
      navigate('/connexion');
      return;
    }
    if (!post) return;

    setIsSubmittingReply(true);
    try {
      const { data, error } = await supabase
        .from('forum_replies')
        .insert({
          post_id: post.post_id,
          user_id: currentUser.id,
          content: newReplyContent,
        })
        .select(`
          *,
          author:profiles (username, avatar_url)
        `)
        .single();

      if (error) throw error;

      const newReplyData: Reply = {
        reply_id: data.id,
        reply_content: data.content,
        reply_created_at: data.created_at,
        reply_updated_at: data.updated_at,
        reply_user_id: data.user_id,
        author_username: data.author?.username || null,
        author_avatar_url: data.author?.avatar_url || null,
        parent_reply_id: data.parent_reply_id || null,
      };
      
      setReplies(prevReplies => [...prevReplies, newReplyData]);
      setNewReplyContent('');
      toast({
        title: "Succès",
        description: "Votre réponse a été ajoutée.",
        className: "bg-green-500 text-white dark:bg-green-700",
      });
    } catch (err: any) {
      console.error('Error adding reply:', err);
      toast({
        title: "Erreur",
        description: err.message || "Impossible d'ajouter la réponse.",
        variant: "destructive",
      });
    } finally {
      setIsSubmittingReply(false);
    }
  };

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

  return (
    <div className="container mx-auto py-8 px-4 md:px-6 max-w-4xl">
      <Button 
        variant="outline" 
        onClick={() => navigate(`/forum/categorie/${post.category_slug}`)} 
        className="mb-6 text-sm"
      >
        <ArrowLeft className="mr-2 h-4 w-4" /> Retour à : {post.category_name}
      </Button>

      <Card className="dark:bg-gray-800 shadow-xl mb-8">
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
          <div className="whitespace-pre-wrap">{post.post_content}</div>
        </CardContent>
      </Card>

      {/* Replies Section */}
      <div className="mt-8">
        <h2 className="text-2xl font-semibold mb-6 text-gray-800 dark:text-white">Réponses ({replies.length})</h2>
        
        {/* Display Replies */}
        {repliesLoading && (
          <div className="flex justify-center items-center py-8">
            <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
            <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des réponses...</p>
          </div>
        )}
        {repliesError && (
          <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700 mb-6">
            <CardHeader>
              <div className="flex items-center text-red-600 dark:text-red-400">
                <AlertTriangle className="h-5 w-5 mr-2" />
                <CardTitle className="text-base">Erreur de chargement des réponses</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-red-700 dark:text-red-300">{repliesError}</p>
            </CardContent>
          </Card>
        )}
        {!repliesLoading && !repliesError && replies.length === 0 && (
          <div className="p-6 bg-gray-50 dark:bg-gray-700/50 rounded-lg text-center mb-6">
            <MessageSquare className="h-12 w-12 mx-auto text-gray-400 dark:text-gray-500 mb-3" />
            <p className="text-gray-600 dark:text-gray-300">Aucune réponse pour le moment.</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Soyez le premier à répondre !</p>
          </div>
        )}
        {!repliesLoading && !repliesError && replies.length > 0 && (
          <div className="space-y-6 mb-8"> {/* Added mb-8 here for spacing before add reply form */}
            {replies.map((reply) => (
              <Card key={reply.reply_id} className="dark:bg-gray-800/70">
                <CardHeader className="flex flex-row items-start space-x-4 p-4 border-b dark:border-gray-700">
                  <Link to={`/profil/${reply.reply_user_id}`}>
                    <Avatar className="h-10 w-10">
                      <AvatarImage src={reply.author_avatar_url || undefined} alt={reply.author_username || 'Auteur'} />
                      <AvatarFallback>{getInitials(reply.author_username)}</AvatarFallback>
                    </Avatar>
                  </Link>
                  <div>
                    <Link to={`/profil/${reply.reply_user_id}`} className="font-semibold text-gray-800 dark:text-white hover:underline">
                      {reply.author_username || 'Utilisateur inconnu'}
                    </Link>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      {format(new Date(reply.reply_created_at), 'PPP p', { locale: fr })}
                      {reply.reply_updated_at && new Date(reply.reply_updated_at).getTime() !== new Date(reply.reply_created_at).getTime() && (
                        <span className="italic"> (modifié le {format(new Date(reply.reply_updated_at), 'PPP p', { locale: fr })})</span>
                      )}
                    </p>
                  </div>
                </CardHeader>
                <CardContent className="p-4">
                  <div className="whitespace-pre-wrap text-gray-700 dark:text-gray-300">{reply.reply_content}</div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}

        {/* Add Reply Form - MOVED HERE */}
        {currentUser && (
          <Card className="dark:bg-gray-800/70">
            <CardHeader>
              <CardTitle className="text-lg">Ajouter une réponse</CardTitle>
            </CardHeader>
            <CardContent>
              <Textarea
                value={newReplyContent}
                onChange={(e) => setNewReplyContent(e.target.value)}
                placeholder="Écrivez votre réponse ici..."
                className="min-h-[100px] dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                disabled={isSubmittingReply}
              />
              <Button 
                onClick={handleAddReply} 
                disabled={isSubmittingReply || !newReplyContent.trim()}
                className="mt-4 w-full sm:w-auto"
              >
                {isSubmittingReply ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                Envoyer la réponse
              </Button>
            </CardContent>
          </Card>
        )}
        {!currentUser && (
           <Card className="bg-yellow-50 border-yellow-400 dark:bg-yellow-900/30 dark:border-yellow-700">
            <CardContent className="p-6 text-center">
              <p className="text-yellow-700 dark:text-yellow-300">
                <Link to="/connexion" className="font-semibold underline hover:text-yellow-800 dark:hover:text-yellow-200">Connectez-vous</Link> ou <Link to="/inscription" className="font-semibold underline hover:text-yellow-800 dark:hover:text-yellow-200">inscrivez-vous</Link> pour ajouter une réponse.
              </p>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
};

export default PostDetailPage;
