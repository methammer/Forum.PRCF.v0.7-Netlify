import { useState, useEffect, FormEvent } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription, DialogTrigger, DialogClose } from "@/components/ui/dialog"; // Added Dialog components
import { FolderPlus, ListOrdered, Edit3, Trash2, PlusCircle, Loader2, AlertTriangle, CheckCircle, Save } from "lucide-react"; // Added Save icon
import { useToast } from '@/hooks/use-toast';
import { usePermissions } from '@/hooks/usePermissions';

interface ForumCategory {
  id: string;
  name: string;
  description: string | null;
  slug: string;
  created_at: string;
}

interface EditFormState {
  name: string;
  description: string;
}

const SectionManagementPage = () => {
  const { toast } = useToast();
  const { can, currentRole } = usePermissions();

  const [categories, setCategories] = useState<ForumCategory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [newSectionName, setNewSectionName] = useState('');
  const [newSectionDescription, setNewSectionDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // State for editing sections
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<ForumCategory | null>(null);
  const [editFormState, setEditFormState] = useState<EditFormState>({ name: '', description: '' });
  const [isUpdating, setIsUpdating] = useState(false);


  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error: fetchError } = await supabase
        .from('forum_categories')
        .select('*')
        .order('name', { ascending: true });

      if (fetchError) throw fetchError;
      setCategories(data || []);
    } catch (err: any) {
      console.error("Error fetching categories:", err);
      setError(err.message || "Impossible de charger les sections.");
      toast({
        title: "Erreur de chargement",
        description: err.message || "Impossible de charger les sections.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreateSection = async (e: FormEvent) => {
    e.preventDefault();
    if (!newSectionName.trim()) {
      toast({ title: "Erreur", description: "Le titre de la section est requis.", variant: "destructive" });
      return;
    }
    if (!can('create_section')) {
      toast({ title: "Accès refusé", description: "Vous n'avez pas la permission de créer une section.", variant: "destructive" });
      return;
    }

    setIsSubmitting(true);
    try {
      const { data, error: insertError } = await supabase
        .from('forum_categories')
        .insert({ name: newSectionName, description: newSectionDescription || null })
        .select()
        .single();

      if (insertError) throw insertError;

      if (data) {
        fetchCategories(); 
        setNewSectionName('');
        setNewSectionDescription('');
        toast({
          title: "Succès",
          description: `La section "${data.name}" a été créée.`,
          className: "bg-green-500 text-white dark:bg-green-700",
        });
      }
    } catch (err: any) {
      console.error("Error creating section:", err);
      toast({
        title: "Erreur de création",
        description: err.message || "Impossible de créer la section.",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const openEditModal = (category: ForumCategory) => {
    if (!can('edit_section')) {
      toast({ title: "Accès refusé", description: "Vous n'avez pas la permission de modifier cette section.", variant: "destructive" });
      return;
    }
    setEditingCategory(category);
    setEditFormState({ name: category.name, description: category.description || '' });
    setIsEditModalOpen(true);
  };

  const handleUpdateSection = async (e: FormEvent) => {
    e.preventDefault();
    if (!editingCategory) return;

    if (!editFormState.name.trim()) {
      toast({ title: "Erreur", description: "Le titre de la section est requis.", variant: "destructive" });
      return;
    }
    if (!can('edit_section')) {
      toast({ title: "Accès refusé", description: "Vous n'avez pas la permission de modifier cette section.", variant: "destructive" });
      return;
    }

    setIsUpdating(true);
    try {
      const { data, error: updateError } = await supabase
        .from('forum_categories')
        .update({ name: editFormState.name, description: editFormState.description || null })
        .eq('id', editingCategory.id)
        .select()
        .single();

      if (updateError) throw updateError;

      if (data) {
        fetchCategories();
        setIsEditModalOpen(false);
        setEditingCategory(null);
        toast({
          title: "Succès",
          description: `La section "${data.name}" a été mise à jour.`,
          className: "bg-blue-500 text-white dark:bg-blue-700",
        });
      }
    } catch (err: any) {
      console.error("Error updating section:", err);
      toast({
        title: "Erreur de mise à jour",
        description: err.message || "Impossible de mettre à jour la section.",
        variant: "destructive",
      });
    } finally {
      setIsUpdating(false);
    }
  };
  
  const canAdministerSections = can('create_section') || can('edit_section') || can('delete_section');

  if (!canAdministerSections && currentRole) {
    return (
      <div className="container mx-auto py-8 px-4 md:px-6">
        <Card className="bg-yellow-50 border-yellow-500 dark:bg-yellow-900/30 dark:border-yellow-700">
          <CardHeader>
            <div className="flex items-center text-yellow-600 dark:text-yellow-400">
              <AlertTriangle className="h-6 w-6 mr-2" />
              <CardTitle>Accès Restreint</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <p className="text-yellow-700 dark:text-yellow-300">
              Vous n'avez pas les permissions nécessaires pour gérer les sections du forum.
              Contactez un administrateur si vous pensez que c'est une erreur.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }
   if (!canAdministerSections && !currentRole) { 
    return (
      <div className="flex justify-center items-center h-64">
        <Loader2 className="h-8 w-8 animate-spin text-gray-500" />
        <p className="ml-2 text-gray-500">Vérification des permissions...</p>
      </div>
    );
  }

  return (
    <div className="space-y-8 p-4 md:p-6">
      <header className="pb-4 border-b dark:border-gray-700">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white flex items-center">
          <ListOrdered className="mr-3 h-8 w-8 text-purple-500" />
          Gestion des Sections du Forum
        </h1>
        <p className="mt-1 text-gray-600 dark:text-gray-300">
          Créer, modifier, et organiser les sections et catégories du forum.
        </p>
      </header>

      {can('create_section') && (
        <Card className="dark:bg-gray-800 shadow-md">
          <CardHeader>
            <CardTitle className="text-xl text-gray-800 dark:text-white flex items-center">
              <PlusCircle className="mr-2 h-6 w-6 text-green-500" />
              Créer une Nouvelle Section
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreateSection} className="space-y-4">
              <div>
                <label htmlFor="sectionName" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Titre de la Section *</label>
                <Input 
                  id="sectionName" 
                  placeholder="Ex: Annonces Générales" 
                  className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" 
                  value={newSectionName}
                  onChange={(e) => setNewSectionName(e.target.value)}
                  required
                />
              </div>
              <div>
                <label htmlFor="sectionDescription" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Description (Optionnel)</label>
                <Textarea 
                  id="sectionDescription" 
                  placeholder="Courte description de la section..." 
                  className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" 
                  value={newSectionDescription}
                  onChange={(e) => setNewSectionDescription(e.target.value)}
                />
              </div>
              <Button type="submit" className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600 text-white" disabled={isSubmitting}>
                {isSubmitting ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : <FolderPlus className="mr-2 h-5 w-5" />}
                Créer la Section
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Sections Existantes</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Gérer les sections actuelles du forum.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading && (
            <div className="flex justify-center items-center py-8">
              <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
              <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des sections...</p>
            </div>
          )}
          {error && !isLoading && (
            <div className="p-4 bg-red-50 dark:bg-red-900/20 rounded-md text-red-700 dark:text-red-300 flex items-center">
              <AlertTriangle className="h-5 w-5 mr-2" />
              <p>{error}</p>
            </div>
          )}
          {!isLoading && !error && categories.length === 0 && (
            <div className="p-6 bg-gray-50 dark:bg-gray-700/30 rounded-lg text-center">
              <ListOrdered className="h-12 w-12 mx-auto text-gray-400 dark:text-gray-500 mb-3" />
              <p className="text-gray-600 dark:text-gray-300">Aucune section n'a été créée pour le moment.</p>
              {can('create_section') && <p className="text-sm text-gray-500 dark:text-gray-400">Utilisez le formulaire ci-dessus pour en ajouter une.</p>}
            </div>
          )}
          {!isLoading && !error && categories.length > 0 && (
            <ul className="space-y-3">
              {categories.map((category) => (
                <li 
                  key={category.id} 
                  className="flex flex-col sm:flex-row items-start sm:items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/30 rounded-md shadow-sm hover:shadow-lg transition-shadow duration-200"
                >
                  <div className="mb-2 sm:mb-0 flex-grow">
                    <h3 className="font-semibold text-gray-800 dark:text-white">{category.name}</h3>
                    <p className="text-xs text-gray-500 dark:text-gray-400">SLUG: /{category.slug}</p>
                    {category.description && <p className="text-sm text-gray-600 dark:text-gray-300 mt-1">{category.description}</p>}
                  </div>
                  <div className="flex space-x-2 flex-shrink-0">
                    {can('edit_section') && (
                      <Button variant="outline" size="sm" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700" onClick={() => openEditModal(category)}>
                        <Edit3 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Modifier</span>
                      </Button>
                    )}
                    {can('delete_section') && (
                      <Button variant="destructive" size="sm" onClick={() => {/* TODO: Implement Delete */ alert('Fonctionnalité de suppression à implémenter.')}}>
                        <Trash2 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Supprimer</span>
                      </Button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      {/* Edit Section Modal */}
      {editingCategory && (
        <Dialog open={isEditModalOpen} onOpenChange={setIsEditModalOpen}>
          <DialogContent className="sm:max-w-[425px] dark:bg-gray-800">
            <DialogHeader>
              <DialogTitle className="text-gray-800 dark:text-white">Modifier la Section</DialogTitle>
              <DialogDescription className="dark:text-gray-400">
                Mettez à jour le nom et la description de la section "{editingCategory.name}".
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleUpdateSection} className="space-y-4 py-4">
              <div>
                <label htmlFor="editSectionName" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Nouveau Titre *</label>
                <Input 
                  id="editSectionName" 
                  className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" 
                  value={editFormState.name}
                  onChange={(e) => setEditFormState(prev => ({ ...prev, name: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label htmlFor="editSectionDescription" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Nouvelle Description (Optionnel)</label>
                <Textarea 
                  id="editSectionDescription" 
                  className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" 
                  value={editFormState.description}
                  onChange={(e) => setEditFormState(prev => ({ ...prev, description: e.target.value }))}
                />
              </div>
              <DialogFooter>
                <DialogClose asChild>
                  <Button type="button" variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</Button>
                </DialogClose>
                <Button type="submit" className="bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white" disabled={isUpdating}>
                  {isUpdating ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : <Save className="mr-2 h-5 w-5" />}
                  Enregistrer
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
};

export default SectionManagementPage;
