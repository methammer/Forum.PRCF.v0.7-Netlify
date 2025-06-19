import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { FolderPlus, ListOrdered, Edit3, Trash2, PlusCircle } from "lucide-react";
// import { useAuth } from "@/hooks/useAuth"; // To check for ADMIN/SUPER_ADMIN specifically if needed

const SectionManagementPage = () => {
  // const { canAdminister } = useAuth();
  // if (!canAdminister) { return <p>Accès refusé. Seuls les administrateurs peuvent gérer les sections.</p>; }

  // TODO: Fetch existing sections, implement CRUD operations via Edge Functions or RLS.
  // For now, it's a placeholder with UI elements.

  return (
    <div className="space-y-8">
      <header className="pb-4 border-b dark:border-gray-700">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white flex items-center">
          <ListOrdered className="mr-3 h-8 w-8 text-purple-500" />
          Gestion des Sections du Forum
        </h1>
        <p className="mt-1 text-gray-600 dark:text-gray-300">
          Créer, modifier, et organiser les sections et catégories du forum.
        </p>
      </header>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white flex items-center">
            <PlusCircle className="mr-2 h-6 w-6 text-green-500" />
            Créer une Nouvelle Section
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label htmlFor="sectionTitle" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Titre de la Section</label>
            <Input id="sectionTitle" placeholder="Ex: Annonces Générales" className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
          </div>
          <div>
            <label htmlFor="sectionSlug" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Slug (pour l'URL, ex: annonces-generales)</label>
            <Input id="sectionSlug" placeholder="Ex: annonces-generales" className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
          </div>
          <div>
            <label htmlFor="sectionDescription" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Description</label>
            <Textarea id="sectionDescription" placeholder="Courte description de la section..." className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
          </div>
          <Button className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600 text-white">
            <FolderPlus className="mr-2 h-5 w-5" />
            Créer la Section
          </Button>
        </CardContent>
      </Card>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Sections Existantes</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Gérer les sections actuelles du forum. (Liste fictive pour démonstration)
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ul className="space-y-3">
            {/* Placeholder list item 1 */}
            <li className="flex flex-col sm:flex-row items-start sm:items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/30 rounded-md shadow-sm hover:shadow-lg transition-shadow duration-200">
              <div className="mb-2 sm:mb-0">
                <h3 className="font-semibold text-gray-800 dark:text-white">Discussions Générales</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">/discussions-generales - Pour parler de tout et de rien.</p>
              </div>
              <div className="flex space-x-2 flex-shrink-0">
                <Button variant="outline" size="sm" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
                  <Edit3 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Modifier</span>
                </Button>
                <Button variant="destructive" size="sm">
                  <Trash2 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Supprimer</span>
                </Button>
              </div>
            </li>
            {/* Placeholder list item 2 */}
            <li className="flex flex-col sm:flex-row items-start sm:items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/30 rounded-md shadow-sm hover:shadow-lg transition-shadow duration-200">
              <div className="mb-2 sm:mb-0">
                <h3 className="font-semibold text-gray-800 dark:text-white">Support Technique</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">/support-technique - Aide et questions techniques.</p>
              </div>
              <div className="flex space-x-2 flex-shrink-0">
                <Button variant="outline" size="sm" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
                  <Edit3 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Modifier</span>
                </Button>
                <Button variant="destructive" size="sm">
                  <Trash2 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Supprimer</span>
                </Button>
              </div>
            </li>
             {/* Placeholder list item 3 */}
            <li className="flex flex-col sm:flex-row items-start sm:items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/30 rounded-md shadow-sm hover:shadow-lg transition-shadow duration-200">
              <div className="mb-2 sm:mb-0">
                <h3 className="font-semibold text-gray-800 dark:text-white">Annonces du PRCF</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">/annonces-prcf - Informations importantes et communiqués.</p>
              </div>
              <div className="flex space-x-2 flex-shrink-0">
                <Button variant="outline" size="sm" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
                  <Edit3 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Modifier</span>
                </Button>
                <Button variant="destructive" size="sm">
                  <Trash2 className="h-4 w-4 sm:mr-1" /> <span className="hidden sm:inline">Supprimer</span>
                </Button>
              </div>
            </li>
          </ul>
           <div className="text-center mt-6">
             <p className="text-sm text-gray-500 dark:text-gray-400">Plus de fonctionnalités de gestion à venir.</p>
           </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default SectionManagementPage;
