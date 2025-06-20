import { useEffect, useState, useCallback } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Loader2, AlertTriangle, ArrowLeft, MessageSquare, CalendarDays, UserCircle, Tag, Send, Flag, Trash2, EyeOff } from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/hooks/useAuth';
import ReportModal from '@/components/modals/ReportModal';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";


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
  is_deleted: boolean;
  deleted_at: string | null;
  is_published: boolean; // Added for completeness, though main logic here is about deletion
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
  is_deleted: boolean;
  deleted_at: string | null;
}

const PostDetailPage = () => {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const { authUser, canModerate, isLoading: authLoading } = useAuth();
  const [post, setPost] = useState<PostDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [replies, setReplies] = useState<Reply[]>([]);
  const [repliesLoading, setRepliesLoading] = useState(true);
  const [repliesError, setRepliesError] = useState<string | null>(null);
  const [newReplyContent, setNewReplyContent] = useState('');
  const [isSubmittingReply, setIsSubmittingReply] = useState(false);
  
  const [isReportModalOpen, setIsReportModalOpen] = useState(false);
  const [reportContentType, setReportContentType] = useState<'post' | 'reply'>('post'); // Default to post
  const [reportContentId, setReportContentId] = useState('');

  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
  const [deleteContentType, setDeleteContentType] = useState<'post' | 'reply' | null>(null);
  const [deleteContentId, setDeleteContentId] = useState<string | null>(null);
  const [deleteReason, setDeleteReason] = useState('');

  const fetchPostAndReplies = useCallback(async () => {
    if (!postId) {
      setError("ID du sujet manquant.");
      setLoading(false);
      setRepliesLoading(false);
      return;
    }

    setLoading(true);
    setRepliesLoading(true);
    setError(null);
    setRepliesError(null);

    try {
      // Fetch post details
      const { data: postData, error: postRpcError } = await supabase
        .rpc('get_post_details_with_author', { p_post_id: postId })
        .single();

      if (postRpcError) throw postRpcError;
      if (!postData) throw new Error("Sujet non trouvé ou vous n'avez pas la permission de le voir.");
      setPost(postData as PostDetails);

      // Fetch replies
      const { data: repliesData, error: repliesRpcError } = await supabase
        .rpc('get_post_replies_with_author', { p_post_id: postId });

      if (repliesRpcError) throw repliesRpcError;
      setReplies(repliesData as Reply[]);

    } catch (err: any) {
      console.error('Error fetching post details or replies:', err);
      const errorMessage = err.message || 'Impossible de charger les données du sujet.';
      setError(errorMessage);
      setRepliesError(errorMessage); // Can show a combined error or separate
    } finally {
      setLoading(false);
      setRepliesLoading(false);
    }
  }, [postId]);

  useEffect(() => {
    fetchPostAndReplies();
  }, [fetchPostAndReplies]);

  const getInitials = (name: string | null | undefined) => {
    if (!name) return '??';
    return name.split(' ').map(n => n[0]).join('').toUpperCase();
  };

  const handleAddReply = async () => {
    if (!newReplyContent.trim()) {
      toast({ title: "Erreur", description: "Le contenu de la réponse ne peut pas être vide.", variant: "destructive" });
      return;
    }
    if (!authUser) {
      toast({ title: "Authentification requise", description: "Vous devez être connecté pour répondre.", variant: "destructive" });
      navigate('/connexion');
      return;
    }
    if (!post || post.is_deleted && !canModerate) {
        toast({ title: "Action impossible", description: "Vous ne pouvez pas répondre à un sujet supprimé.", variant: "destructive" });
        return;
    }

    setIsSubmittingReply(true);
    try {
      const { data, error } = await supabase
        .from('forum_replies')
        .insert({
          post_id: post.post_id,
          user_id: authUser.id,
          content: newReplyContent,
        })
        .select(`
          *,
          author:profiles (username, avatar_url)
        `)
        .single();

      if (error) throw error;

      const newReplyData: Reply = {
        reply_id: data.id, // Supabase returns 'id' for the new record
        reply_content: data.content,
        reply_created_at: data.created_at,
        reply_updated_at: data.updated_at,
        reply_user_id: data.user_id,
        author_username: data.author?.username || null,
        author_avatar_url: data.author?.avatar_url || null,
        parent_reply_id: data.parent_reply_id || null,
        is_deleted: data.is_deleted || false,
        deleted_at: data.deleted_at || null,
      };
      
      setReplies(prevReplies => [...prevReplies, newReplyData]);
      setNewReplyContent('');
      toast({ title: "Succès", description: "Votre réponse a été ajoutée.", className: "bg-green-500 text-white dark:bg-green-700" });
    } catch (err: any) {
      console.error('Error adding reply:', err);
      toast({ title: "Erreur", description: err.message || "Impossible d'ajouter la réponse.", variant: "destructive" });
    } finally {
      setIsSubmittingReply(false);
    }
  };

  const openReportModalHandler = (type: 'post' | 'reply', id: string) => {
    if (!authUser) {
      toast({ title: "Authentification requise", description: "Vous devez être connecté pour signaler.", variant: "destructive" });
      navigate('/connexion');
      return;
    }
    setReportContentType(type);
    setReportContentId(id);
    setIsReportModalOpen(true);
  };

  const openDeleteConfirmHandler = (type: 'post' | 'reply', id: string) => {
    setDeleteContentType(type);
    setDeleteContentId(id);
    setIsDeleteConfirmOpen(true);
    setDeleteReason('');
  };

  const confirmDeleteContent = async () => {
    if (!canModerate || !deleteContentType || !deleteContentId) return;

    setIsSubmittingReply(true); // Reuse for loading state
    try {
      const { error } = await supabase.rpc('soft_delete_content', {
        p_content_type: deleteContentType,
        p_content_id: deleteContentId,
        p_delete_reason: deleteReason || null,
      });

      if (error) throw error;

      toast({
        title: "Contenu supprimé",
        description: `Le ${deleteContentType === 'post' ? 'sujet' : 'message'} a été marqué comme supprimé.`,
        className: "bg-orange-500 text-white dark:bg-orange-700",
      });

      // Refresh data to get updated states
      fetchPostAndReplies(); 

    } catch (err: any) {
      console.error('Error deleting content:', err);
      toast({ title: "Erreur de suppression", description: err.message || "Impossible de supprimer le contenu.", variant: "destructive" });
    } finally {
      setIsSubmittingReply(false);
      setIsDeleteConfirmOpen(false);
      setDeleteContentId(null);
      setDeleteContentType(null);
    }
  };

  if (authLoading || loading) {
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

  if (post.is_deleted && !canModerate) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 text-center">
        <EyeOff className="mx-auto h-16 w-16 text-gray-500 mb-4" />
        <p className="text-xl text-gray-700 dark:text-gray-200">Ce sujet a été supprimé.</p>
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

      <Card className={`dark:bg-gray-800 shadow-xl mb-8 ${post.is_deleted && canModerate ? 'border-2 border-orange-500 opacity-70' : ''}`}>
        <CardHeader className="border-b dark:border-gray-700 p-6">
          {post.is_deleted && canModerate && (
            <div className="p-2 mb-2 bg-orange-100 dark:bg-orange-900/50 border border-orange-500 rounded-md text-orange-700 dark:text-orange-300 text-sm">
              <EyeOff className="inline h-4 w-4 mr-1" /> Ce sujet a été supprimé le {format(new Date(post.deleted_at!), 'PPP p', { locale: fr })}. Visible uniquement par les modérateurs.
            </div>
          )}
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
            {post.post_updated_at && new Date(post.post_updated_at).getTime() !== new Date(post.post_created_at).getTime() && !post.is_deleted && (
              <div className="flex items-center text-xs italic">
                (Modifié le {format(new Date(post.post_updated_at), 'PPP p', { locale: fr })})
              </div>
            )}
          </div>
           <div className="mt-2 flex space-x-2">
            {authUser && authUser.id !== post.post_user_id && !post.is_deleted && (
              <Button variant="ghost" size="sm" onClick={() => openReportModalHandler('post', post.post_id)} className="text-xs text-gray-500 hover:text-red-600">
                <Flag className="mr-1 h-3 w-3" /> Signaler le sujet
              </Button>
            )}
            {canModerate && !post.is_deleted && (
              <Button variant="destructive" size="sm" onClick={() => openDeleteConfirmHandler('post', post.post_id)} className="text-xs">
                <Trash2 className="mr-1 h-3 w-3" /> Supprimer le sujet
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent className="p-6 prose dark:prose-invert max-w-none">
          {post.is_deleted && !canModerate ? (
            <p className="italic text-gray-500 dark:text-gray-400">Contenu supprimé.</p>
          ) : (
            <div className="whitespace-pre-wrap">{post.post_content}</div>
          )}
        </CardContent>
      </Card>

      <div className="mt-8">
        <h2 className="text-2xl font-semibold mb-6 text-gray-800 dark:text-white">Réponses ({replies.filter(r => !(r.is_deleted && !canModerate)).length})</h2>
        
        {repliesLoading && (
            <div className="flex justify-center items-center py-10">
                <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
                <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des réponses...</p>
            </div>
        )}
        {repliesError && !repliesLoading && (
            <div className="text-red-600 dark:text-red-400 p-4 bg-red-50 dark:bg-red-900/30 rounded-md">
                <AlertTriangle className="inline h-5 w-5 mr-2" /> Erreur: {repliesError}
            </div>
        )}
        {!repliesLoading && !repliesError && replies.filter(r => !(r.is_deleted && !canModerate)).length === 0 && (
            <div className="text-center text-gray-500 dark:text-gray-400 py-10">
                <MessageSquare className="mx-auto h-12 w-12 mb-2" />
                <p>Aucune réponse pour le moment.</p>
                {!post.is_deleted && authUser && <p className="text-sm">Soyez le premier à répondre !</p>}
            </div>
        )}
        
        {!repliesLoading && !repliesError && replies.length > 0 && (
          <div className="space-y-6 mb-8">
            {replies.map((reply) => {
              if (reply.is_deleted && !canModerate) return null;

              return (
                <Card key={reply.reply_id} className={`dark:bg-gray-800/70 ${reply.is_deleted && canModerate ? 'border-2 border-orange-500 opacity-70' : ''}`}>
                  {reply.is_deleted && canModerate && (
                    <div className="p-2 text-xs bg-orange-100 dark:bg-orange-900/50 border-b border-orange-500 text-orange-700 dark:text-orange-300">
                      <EyeOff className="inline h-3 w-3 mr-1" /> Ce message a été supprimé le {format(new Date(reply.deleted_at!), 'Pp', { locale: fr })}. Visible uniquement par les modérateurs.
                    </div>
                  )}
                  <CardHeader className="flex flex-row items-start space-x-4 p-4 border-b dark:border-gray-700">
                    <Link to={`/profil/${reply.reply_user_id}`}>
                      <Avatar className="h-10 w-10">
                        <AvatarImage src={reply.author_avatar_url || undefined} alt={reply.author_username || 'Auteur'} />
                        <AvatarFallback>{getInitials(reply.author_username)}</AvatarFallback>
                      </Avatar>
                    </Link>
                    <div className="flex-grow">
                      <Link to={`/profil/${reply.reply_user_id}`} className="font-semibold text-gray-800 dark:text-white hover:underline">
                        {reply.author_username || 'Utilisateur inconnu'}
                      </Link>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        {format(new Date(reply.reply_created_at), 'PPP p', { locale: fr })}
                        {reply.reply_updated_at && new Date(reply.reply_updated_at).getTime() !== new Date(reply.reply_created_at).getTime() && !reply.is_deleted && (
                          <span className="italic"> (modifié le {format(new Date(reply.reply_updated_at), 'PPP p', { locale: fr })})</span>
                        )}
                      </p>
                    </div>
                    <div className="flex flex-col sm:flex-row space-y-1 sm:space-y-0 sm:space-x-2 items-end">
                      {authUser && authUser.id !== reply.reply_user_id && !reply.is_deleted && (
                        <Button variant="ghost" size="sm" onClick={() => openReportModalHandler('reply', reply.reply_id)} className="text-xs text-gray-500 hover:text-red-600 p-1">
                          <Flag className="mr-1 h-3 w-3" /> Signaler
                        </Button>
                      )}
                      {canModerate && !reply.is_deleted && (
                        <Button variant="destructive" size="sm" onClick={() => openDeleteConfirmHandler('reply', reply.reply_id)} className="text-xs p-1">
                          <Trash2 className="mr-1 h-3 w-3" /> Supprimer
                        </Button>
                      )}
                    </div>
                  </CardHeader>
                  <CardContent className="p-4">
                    {reply.is_deleted && !canModerate ? (
                       <p className="italic text-gray-500 dark:text-gray-400">Contenu supprimé.</p>
                    ) : (
                      <div className="whitespace-pre-wrap text-gray-700 dark:text-gray-300">{reply.reply_content}</div>
                    )}
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}

        {(!post.is_deleted || canModerate) && authUser && (
          <Card className="dark:bg-gray-800/70">
            <CardHeader>
              <CardTitle className="text-lg dark:text-white">Ajouter une réponse</CardTitle>
            </CardHeader>
            <CardContent>
              <Textarea
                value={newReplyContent}
                onChange={(e) => setNewReplyContent(e.target.value)}
                placeholder="Écrivez votre réponse ici..."
                className="min-h-[100px] dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                disabled={isSubmittingReply || (post.is_deleted && !canModerate)}
              />
              <Button 
                onClick={handleAddReply} 
                disabled={isSubmittingReply || !newReplyContent.trim() || (post.is_deleted && !canModerate)}
                className="mt-4 w-full sm:w-auto"
              >
                {isSubmittingReply ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                Envoyer la réponse
              </Button>
              {post.is_deleted && !canModerate && <p className="text-sm text-orange-600 dark:text-orange-400 mt-2">Vous ne pouvez pas répondre à un sujet supprimé.</p>}
            </CardContent>
          </Card>
        )}
        {(!post.is_deleted || canModerate) && !authUser && !authLoading && (
            <Card className="dark:bg-gray-800/70">
                <CardHeader>
                    <CardTitle className="text-lg dark:text-white">Participer à la discussion</CardTitle>
                </CardHeader>
                <CardContent>
                    <p className="text-gray-600 dark:text-gray-300">
                        <Link to="/connexion" className="text-blue-600 hover:underline dark:text-blue-400">Connectez-vous</Link> ou <Link to="/inscription" className="text-blue-600 hover:underline dark:text-blue-400">inscrivez-vous</Link> pour ajouter une réponse.
                    </p>
                </CardContent>
            </Card>
        )}
      </div>

      <ReportModal
        isOpen={isReportModalOpen}
        onClose={() => setIsReportModalOpen(false)}
        contentType={reportContentType}
        contentId={reportContentId}
      />

      <AlertDialog open={isDeleteConfirmOpen} onOpenChange={setIsDeleteConfirmOpen}>
        <AlertDialogContent className="dark:bg-gray-800">
          <AlertDialogHeader>
            <AlertDialogTitle className="dark:text-white">Confirmer la suppression</AlertDialogTitle>
            <AlertDialogDescription className="dark:text-gray-300">
              Êtes-vous sûr de vouloir supprimer ce {deleteContentType === 'post' ? 'sujet' : 'message'} ? Cette action le masquera pour les utilisateurs standards.
              <Textarea
                value={deleteReason}
                onChange={(e) => setDeleteReason(e.target.value)}
                placeholder="Raison de la suppression (optionnel, pour les logs)"
                className="mt-3 min-h-[80px] dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
              />
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmDeleteContent}
              className="bg-red-600 hover:bg-red-700 text-white"
              disabled={isSubmittingReply} // Reusing this state for loading
            >
              {isSubmittingReply ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
              Confirmer la suppression
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default PostDetailPage;
