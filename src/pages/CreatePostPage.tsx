import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { useToast } from "@/hooks/use-toast";
import { useUser } from '@/contexts/UserContext'; // Import useUser
import { Loader2, ArrowLeft, Send, AlertTriangle, LockIcon } from 'lucide-react';

interface ForumCategory {
  id: string;
  name: string;
  slug: string;
  is_locked_for_users: boolean; // Added new field
}

const CreatePostPage = () => {
  const { categorySlug } = useParams<{ categorySlug: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const { profile: currentUserProfile, isLoadingAuth: isLoadingUserContext } = useUser(); // Use UserContext

  const [category, setCategory] = useState<ForumCategory | null>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [loadingPageData, setLoadingPageData] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCategoryData = async () => {
      if (isLoadingUserContext) return; // Wait for user context to load

      setLoadingPageData(true);
      setError(null);

      if (!currentUserProfile?.id) { // Check if user is logged in via profile
        setError("Vous devez être connecté pour créer un sujet.");
        toast({
          title: "Accès refusé",
          description: "Veuillez vous connecter pour créer un nouveau sujet.",
          variant: "destructive",
        });
        setLoadingPageData(false);
        navigate('/connexion');
        return;
      }

      if (!categorySlug) {
        setError("Slug de catégorie manquant.");
        setLoadingPageData(false);
        return;
      }

      try {
        const { data: categoryData, error: categoryError } = await supabase
          .from('forum_categories')
          .select('id, name, slug, is_locked_for_users') // Fetch the new field
          .eq('slug', categorySlug)
          .single();

        if (categoryError) throw categoryError;
        if (!categoryData) throw new Error("Catégorie non trouvée.");
        
        setCategory(categoryData);

        // Check lock status after category is fetched
        if (categoryData.is_locked_for_users && currentUserProfile.role === 'USER') {
          toast({
            title: "Section Verrouillée",
            description: "Vous ne pouvez pas créer de nouveaux sujets dans cette section car elle est verrouillée pour les utilisateurs.",
            variant: "destructive",
            duration: 7000,
          });
          // Navigate back or to category page, as user cannot create post here
          navigate(`/forum/categorie/${categorySlug}`); 
        }

      } catch (err: any) {
        console.error("Error fetching category:", err);
        setError(err.message || "Impossible de charger les informations de la catégorie.");
        toast({
          title: "Erreur",
          description: "Impossible de charger les informations de la catégorie.",
          variant: "destructive",
        });
      } finally {
        setLoadingPageData(false);
      }
    };

    fetchCategoryData();
  }, [categorySlug, navigate, toast, currentUserProfile, isLoadingUserContext]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!currentUserProfile?.id) {
      toast({ title: "Erreur", description: "Utilisateur non authentifié.", variant: "destructive" });
      return;
    }

    if (!title.trim() || !content.trim()) {
      toast({
        title: "Champs requis",
        description: "Le titre et le contenu ne peuvent pas être vides.",
        variant: "destructive",
      });
      return;
    }
    if (!category) {
      toast({
        title: "Erreur",
        description: "Impossible de créer le sujet. Données de catégorie manquantes.",
        variant: "destructive",
      });
      return;
    }

    // Double-check lock status before submission, RLS will be the final guard
    if (category.is_locked_for_users && currentUserProfile.role === 'USER') {
      toast({
        title: "Section Verrouillée",
        description: "Action non autorisée. Vous ne pouvez pas créer de sujets dans cette section.",
        variant: "destructive",
      });
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      const { data: postData, error: postError } = await supabase
        .from('forum_posts')
        .insert({
          category_id: category.id,
          user_id: currentUserProfile.id, // Use ID from profile
          title: title.trim(),
          content: content.trim(),
        })
        .select('id')
        .single();

      if (postError) throw postError;
      if (!postData || !postData.id) throw new Error("La création du sujet a échoué, ID manquant.");

      toast({
        title: "Succès !",
        description: "Votre sujet a été créé.",
        className: "bg-green-500 text-white dark:bg-green-700",
      });
      navigate(`/forum/sujet/${postData.id}`);
    } catch (err: any) {
      console.error("Error creating post:", err);
      setError(err.message || "Une erreur est survenue lors de la création du sujet.");
      toast({
        title: "Erreur de création",
        description: err.message || "Une erreur est survenue. Veuillez réessayer.",
        variant: "destructive",
      });
    } finally {
      setSubmitting(false);
    }
  };

  if (loadingPageData || isLoadingUserContext) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 flex justify-center items-center min-h-[calc(100vh-200px)]">
        <Loader2 className="h-12 w-12 animate-spin text-blue-600" />
        <p className="ml-4 text-lg text-gray-600 dark:text-gray-300">Chargement...</p>
      </div>
    );
  }

  // If category is locked for USER role and user is USER, they should have been redirected.
  // This is a fallback or if redirection hasn't completed.
  if (category?.is_locked_for_users && currentUserProfile?.role === 'USER') {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6">
        <Card className="bg-yellow-50 border-yellow-500 dark:bg-yellow-900/30 dark:border-yellow-700">
          <CardHeader>
            <div className="flex items-center text-yellow-600 dark:text-yellow-400">
              <LockIcon className="h-6 w-6 mr-2" />
              <CardTitle>Section Verrouillée</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-yellow-700 dark:text-yellow-300">
              Vous n'avez pas la permission de créer des sujets dans cette section.
              Seuls les modérateurs et administrateurs peuvent publier ici.
            </p>
            <Button variant="outline" onClick={() => navigate(`/forum/categorie/${categorySlug}`)} className="mt-4">
              <ArrowLeft className="mr-2 h-4 w-4" /> Retour à la catégorie
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }
  
  if (error && !category) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6">
        <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700">
          <CardHeader>
            <div className="flex items-center text-red-600 dark:text-red-400">
              <AlertTriangle className="h-6 w-6 mr-2" />
              <CardTitle>Erreur de chargement</CardTitle>
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
        <p className="text-xl text-gray-700 dark:text-gray-200">Catégorie non trouvée ou erreur de chargement.</p>
        <Button variant="link" onClick={() => navigate('/forum')} className="mt-4">
          Retour au Forum
        </Button>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 md:px-6 max-w-3xl">
      <Button 
        variant="outline" 
        onClick={() => navigate(`/forum/categorie/${categorySlug}`)} 
        className="mb-6 text-sm"
        disabled={submitting}
      >
        <ArrowLeft className="mr-2 h-4 w-4" /> Retour à la catégorie : {category?.name || '...'}
      </Button>

      <Card className="dark:bg-gray-800">
        <CardHeader>
          <CardTitle className="text-2xl md:text-3xl font-bold text-gray-800 dark:text-white">
            Créer un nouveau sujet dans "{category?.name}"
          </CardTitle>
          <CardDescription className="dark:text-gray-300">
            Partagez vos idées ou posez vos questions à la communauté.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error && ( 
            <div className="mb-4 p-3 bg-red-100 dark:bg-red-900/40 border border-red-400 dark:border-red-700 rounded-md text-red-700 dark:text-red-300">
              <p>{error}</p>
            </div>
          )}
          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <Label htmlFor="title" className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
                Titre du sujet
              </Label>
              <Input
                id="title"
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Un titre clair et concis"
                required
                className="dark:bg-gray-700 dark:text-white dark:border-gray-600"
                disabled={submitting}
              />
            </div>
            <div>
              <Label htmlFor="content" className="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">
                Contenu du sujet
              </Label>
              <Textarea
                id="content"
                value={content}
                onChange={(e) => setContent(e.target.value)}
                placeholder="Développez votre pensée ici..."
                required
                rows={10}
                className="dark:bg-gray-700 dark:text-white dark:border-gray-600"
                disabled={submitting}
              />
              <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                Vous pouvez utiliser du texte simple. Le formatage Markdown sera bientôt disponible.
              </p>
            </div>
            <div className="flex justify-end">
              <Button 
                type="submit" 
                className="bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600"
                disabled={submitting || !title.trim() || !content.trim()}
              >
                {submitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Publication...
                  </>
                ) : (
                  <>
                    <Send className="mr-2 h-4 w-4" />
                    Publier le sujet
                  </>
                )}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
};

export default CreatePostPage;
