import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ShieldAlert, Search, Filter } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const ModerationPage = () => {
  // TODO: Fetch reported content or other moderation tasks
  // For now, it's a placeholder.

  return (
    <div className="space-y-6">
      <header className="pb-4 border-b dark:border-gray-700">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white flex items-center">
          <ShieldAlert className="mr-3 h-8 w-8 text-orange-500" />
          Modération de Contenu
        </h1>
        <p className="mt-1 text-gray-600 dark:text-gray-300">
          Gérer les contenus signalés et maintenir l'ordre sur le forum.
        </p>
      </header>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Filtres et Recherche</CardTitle>
          <div className="flex space-x-2 pt-2">
            <Input placeholder="Rechercher par utilisateur ou mot-clé..." className="max-w-xs dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
            <Button variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
              <Filter className="mr-2 h-4 w-4" /> Filtrer par type
            </Button>
             <Button className="bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white">
              <Search className="mr-2 h-4 w-4" /> Rechercher
            </Button>
          </div>
        </CardHeader>
      </Card>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Contenus Signalés</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Liste des messages et sujets nécessitant une attention. (Fonctionnalité à venir)
          </CardDescription>
        </CardHeader>
        <CardContent className="min-h-[200px] flex items-center justify-center bg-gray-50 dark:bg-gray-700/30 rounded-b-md">
          {/* Placeholder for reported items list */}
          <div className="text-center text-gray-500 dark:text-gray-400">
            <ShieldAlert className="mx-auto h-12 w-12 mb-2" />
            <p>Aucun contenu signalé pour le moment.</p>
            <p className="text-sm">Tout est en ordre !</p>
          </div>
        </CardContent>
      </Card>

      {/* Example of a reported item card - to be dynamic later */}
      {/*
      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader className="flex flex-row items-start justify-between">
          <div>
            <CardTitle className="text-lg text-red-600 dark:text-red-400">Sujet: "Problème urgent!"</CardTitle>
            <CardDescription className="text-xs text-gray-500 dark:text-gray-400">Signalé par: UtilisateurTest il y a 1h</CardDescription>
          </div>
          <span className="text-xs px-2 py-1 bg-yellow-200 text-yellow-800 rounded-full dark:bg-yellow-700 dark:text-yellow-200">En attente</span>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-gray-700 dark:text-gray-300 mb-3">"Ce sujet contient des propos inappropriés..."</p>
          <div className="flex space-x-2">
            <Button size="sm" variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Voir le Sujet</Button>
            <Button size="sm" className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600 text-white">Marquer comme résolu</Button>
            <Button size="sm" variant="destructive">Supprimer le Sujet</Button>
          </div>
        </CardContent>
      </Card>
      */}
    </div>
  );
};

export default ModerationPage;
