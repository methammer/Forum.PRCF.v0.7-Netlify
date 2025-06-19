import { useEffect, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { useToast } from "@/hooks/use-toast"; // Corrected import path
import { Loader2, ArrowLeft, Send, AlertTriangle } from 'lucide-react';

interface ForumCategory {
  id: string;
  name: string;
  slug: string;
}

const CreatePostPage = () => {
  const { categorySlug } = useParams<{ categorySlug: string }>();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [category, setCategory] = useState<ForumCategory | null>(null);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [loadingCategory, setLoadingCategory] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentUser, setCurrentUser] = useState<any>(null);

  useEffect(() => {
    const fetchUserAndCategory = async () => {
      setLoadingCategory(true);
      setError(null);

      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        setError("Vous devez être connecté pour créer un sujet.");
        toast({
          title: "Accès refusé",
          description: "Veuillez vous connecter pour créer un nouveau sujet.",
          variant: "destructive",
        });
        setLoadingCategory(false);
        navigate('/connexion');
        return;
      }
      setCurrentUser(user);

      if (!categorySlug) {
        setError("Slug de catégorie manquant.");
        setLoadingCategory(false);
        return;
      }

      try {
        const { data: categoryData, error: categoryError } = await supabase
          .from('forum_categories')
          .select('id, name, slug')
          .eq('slug', categorySlug)
          .single();

        if (categoryError) throw categoryError;
        if (!categoryData) throw new Error("Catégorie non trouvée.");
        setCategory(categoryData);
      } catch (err: any) {
        console.error("Error fetching category:", err);
        setError(err.message || "Impossible de charger les informations de la catégorie.");
        toast({
          title: "Erreur",
          description: "Impossible de charger les informations de la catégorie.",
          variant: "destructive",
        });
      } finally {
        setLoadingCategory(false);
      }
    };

    fetchUserAndCategory();
  }, [categorySlug, navigate, toast]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) {
      toast({
        title: "Champs requis",
        description: "Le titre et le contenu ne peuvent pas être vides.",
        variant: "destructive",
      });
      return;
    }
    if (!category || !currentUser) {
      toast({
        title: "Erreur",
        description: "Impossible de créer le sujet. Données manquantes.",
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
          user_id: currentUser.id,
          title: title.trim(),
          content: content.trim(),
        })
        .select('id')
        .single();

      if (postError) throw postError;

      toast({
        title: "Succès !",
        description: "Votre sujet a été créé.",
        className: "bg-green-500 text-white dark:bg-green-700",
      });
      // TODO: Navigate to the new post detail page: `/forum/sujet/${postData.id}`
      // For now, navigate back to the category page
      navigate(`/forum/categorie/${category.slug}`);
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

  if (loadingCategory) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6 flex justify-center items-center min-h-[calc(100vh-200px)]">
        <Loader2 className="h-12 w-12 animate-spin text-blue-600" />
        <p className="ml-4 text-lg text-gray-600 dark:text-gray-300">Chargement...</p>
      </div>
    );
  }

  if (error && !category) { // Show full page error if category loading failed critically
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
  
  if (!category) { // Should be caught by above, but as a fallback
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
          {error && ( // Display non-critical errors here, e.g. submission errors
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