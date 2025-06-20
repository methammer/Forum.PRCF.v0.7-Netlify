import { useEffect, useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/hooks/useAuth';
import { useToast } from '@/hooks/use-toast';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea"; // Added Textarea
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { ShieldAlert, Search, Filter, Loader2, AlertTriangle, Eye, CheckCircle, XCircle, Trash2, MoreHorizontal } from "lucide-react";
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
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

interface ReportedItem {
  report_id: string;
  report_created_at: string;
  reporter_id: string | null;
  reporter_username: string | null;
  reported_content_type: 'post' | 'reply';
  reported_content_id: string;
  content_title: string | null;
  content_excerpt: string | null;
  content_author_id: string | null;
  content_author_username: string | null;
  reason_category: string;
  reason_details: string | null;
  report_status: string;
}

const ModerationPage = () => {
  const { canModerate, isLoading: authLoading } = useAuth();
  const { toast } = useToast();
  const [reportedItems, setReportedItems] = useState<ReportedItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
  const [deleteContentInfo, setDeleteContentInfo] = useState<{type: 'post' | 'reply', id: string, reportIdToResolve?: string} | null>(null);
  const [deleteReason, setDeleteReason] = useState('');

  const fetchReportedItems = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error: rpcError } = await supabase.rpc('get_pending_reports_with_details');
      if (rpcError) throw rpcError;
      setReportedItems(data || []);
    } catch (err: any) {
      console.error("Error fetching reported items:", err);
      setError(err.message || "Impossible de charger les signalements.");
      toast({ title: "Erreur de chargement", description: err.message || "Impossible de charger les signalements.", variant: "destructive" });
    } finally {
      setIsLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    if (!authLoading) {
      if (canModerate) {
        fetchReportedItems();
      } else {
        setIsLoading(false);
        setError("Accès non autorisé à cette page.");
      }
    }
  }, [canModerate, authLoading, fetchReportedItems]);

  const handleUpdateReportStatus = async (reportId: string, newStatus: 'RESOLVED_APPROVED' | 'RESOLVED_REJECTED', notes?: string) => {
    try {
      const { error } = await supabase.rpc('update_report_status', {
        p_report_id: reportId,
        p_new_status: newStatus,
        p_moderator_notes: notes || null,
      });
      if (error) throw error;
      toast({ title: "Succès", description: `Signalement marqué comme ${newStatus === 'RESOLVED_APPROVED' ? 'approuvé' : 'rejeté'}.`, className: "bg-green-500 text-white" });
      fetchReportedItems(); 
    } catch (err: any) {
      toast({ title: "Erreur", description: err.message || "Impossible de mettre à jour le statut du signalement.", variant: "destructive" });
    }
  };

  const openDeleteConfirmation = (type: 'post' | 'reply', id: string, reportIdToResolve?: string) => {
    setDeleteContentInfo({ type, id, reportIdToResolve });
    setIsDeleteConfirmOpen(true);
    setDeleteReason('');
  };
  
  const confirmDeleteContent = async () => {
    if (!deleteContentInfo) return;
    try {
      const { error } = await supabase.rpc('soft_delete_content', {
        p_content_type: deleteContentInfo.type,
        p_content_id: deleteContentInfo.id,
        p_delete_reason: deleteReason || null,
      });
      // soft_delete_content RPC automatically sets related reports to RESOLVED_ACTION_TAKEN
      if (error) throw error;
      toast({ title: "Contenu supprimé", description: "Le contenu a été marqué comme supprimé et le signalement résolu.", className: "bg-orange-500 text-white" });
      fetchReportedItems(); 
    } catch (err: any) {
      toast({ title: "Erreur de suppression", description: err.message || "Impossible de supprimer le contenu.", variant: "destructive" });
    } finally {
      setIsDeleteConfirmOpen(false);
      setDeleteContentInfo(null);
    }
  };

  const getReportedContentLink = (item: ReportedItem) => {
    // For replies, the RPC get_pending_reports_with_details does not directly provide the parent post_id.
    // Linking to the post containing the reply is the current approach.
    // A future enhancement could be to modify the RPC to include parent_post_id for replies.
    if (item.reported_content_type === 'post') {
      return `/forum/sujet/${item.reported_content_id}`;
    }
    // If it's a reply, we need to find its post. For now, this is a limitation.
    // The current RPC returns reported_content_id as reply_id.
    // We can't directly link to the reply without its post_id.
    // A placeholder or a link to a search might be better if post_id is unknown.
    // For now, we assume the moderator might need to search or the content_title (if post) helps.
    // This is a known area for improvement.
    // Let's try to link to the post if it's a reply, assuming reported_content_id is the post_id for now,
    // which is incorrect for replies. This needs a proper fix in the RPC or client-side lookup.
    // For MVP, if it's a reply, the link might be non-functional or point to the reply ID directly, which isn't a route.
    // The best we can do without parent_post_id is to link to the forum and moderator has to find it.
    // Or, if content_title is available (meaning it's a post), use that.
    // The RPC provides content_title (post title) and content_excerpt (post or reply excerpt).
    // If item.content_title is populated, it's likely a post.
    // If item.reported_content_type === 'reply', we don't have a direct link to the reply's page.
    // We can link to the post if we had the post_id.
    // The current RPC `get_pending_reports_with_details` joins `forum_posts` on `fr.reported_post_id = fp.id`
    // and `forum_replies` on `fr.reported_reply_id = f_reply.id`.
    // It returns `fp.title` as `content_title`.
    // If `reported_content_type` is 'reply', `fp.title` will be NULL unless the reply itself has a title (which it doesn't).
    // The `reported_content_id` is the ID of the reply.
    // To make a link like `/forum/sujet/:postId#reply-:replyId`, we need postId.
    // This is a known limitation. For now, link to the post ID if it's a post, otherwise it's tricky.
    // The current code in context links to `/forum/sujet/${item.reported_content_id}`. This is only correct for posts.
    // For replies, this would try to load a post with the reply's ID, which will fail.
    // A better temporary solution for replies: don't make it a link, or link to a generic search/moderation area.
    // Given the RPC structure, if it's a reply, `item.content_title` (from `fp.title`) would be null.
    // If `item.reported_content_type === 'post'`, then `item.reported_content_id` is the post ID.
    if (item.reported_content_type === 'post') {
        return `/forum/sujet/${item.reported_content_id}`;
    }
    // For replies, we cannot form a direct link without the parent post_id.
    // The moderator will have to use the information (author, excerpt) to find it.
    // Returning '#' or null for the link for replies to prevent broken links.
    return null; 
  };


  if (authLoading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <Loader2 className="h-12 w-12 animate-spin text-blue-500" />
      </div>
    );
  }

  if (!canModerate && !isLoading) {
    return (
      <div className="space-y-6 p-4 md:p-6">
        <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700">
          <CardHeader><CardTitle>Accès Refusé</CardTitle></CardHeader>
          <CardContent><p>{error || "Vous n'avez pas les permissions nécessaires pour accéder à cette page."}</p></CardContent>
        </Card>
      </div>
    );
  }
  
  return (
    <div className="space-y-6 p-4 md:p-6">
      <header className="pb-4 border-b dark:border-gray-700">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white flex items-center">
          <ShieldAlert className="mr-3 h-8 w-8 text-orange-500" />
          Modération de Contenu
        </h1>
        <p className="mt-1 text-gray-600 dark:text-gray-300">
          Gérer les contenus signalés et maintenir l'ordre sur le forum. (Signalements en attente)
        </p>
      </header>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Filtres et Recherche (À venir)</CardTitle>
          <div className="flex space-x-2 pt-2">
            <Input 
              placeholder="Rechercher par utilisateur ou mot-clé..." 
              className="max-w-xs dark:bg-gray-700 dark:border-gray-600 dark:text-white" 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              disabled // Disabled for now
            />
            <Button variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700" disabled>
              <Filter className="mr-2 h-4 w-4" /> Filtrer par type
            </Button>
            <Button className="bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white" disabled>
              <Search className="mr-2 h-4 w-4" /> Rechercher
            </Button>
          </div>
        </CardHeader>
      </Card>

      <Card className="dark:bg-gray-800 shadow-md">
        <CardHeader>
          <CardTitle className="text-xl text-gray-800 dark:text-white">Contenus Signalés en Attente</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            Liste des messages et sujets nécessitant une attention. Actuellement: {reportedItems.length} signalement(s).
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading && (
            <div className="flex justify-center items-center py-10">
              <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
              <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des signalements...</p>
            </div>
          )}
          {error && !isLoading && (
            <div className="text-red-600 dark:text-red-400 p-4 bg-red-50 dark:bg-red-900/30 rounded-md">
              <AlertTriangle className="inline h-5 w-5 mr-2" /> Erreur: {error}
            </div>
          )}
          {!isLoading && !error && reportedItems.length === 0 && (
            <div className="text-center text-gray-500 dark:text-gray-400 py-10">
              <CheckCircle className="mx-auto h-12 w-12 mb-2 text-green-500" />
              <p>Aucun contenu signalé en attente pour le moment.</p>
              <p className="text-sm">Tout est en ordre !</p>
            </div>
          )}
          {!isLoading && !error && reportedItems.length > 0 && (
            <Table>
              <TableHeader>
                <TableRow className="dark:border-gray-700">
                  <TableHead className="dark:text-gray-300">Date</TableHead>
                  <TableHead className="dark:text-gray-300">Type</TableHead>
                  <TableHead className="dark:text-gray-300">Contenu (Extrait)</TableHead>
                  <TableHead className="dark:text-gray-300">Signalé par</TableHead>
                  <TableHead className="dark:text-gray-300">Raison</TableHead>
                  <TableHead className="dark:text-gray-300 text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {reportedItems.map((item) => {
                  const contentLink = getReportedContentLink(item);
                  return (
                  <TableRow key={item.report_id} className="dark:border-gray-700">
                    <TableCell className="dark:text-gray-400 text-xs">
                      {format(new Date(item.report_created_at), 'dd/MM/yy HH:mm', { locale: fr })}
                    </TableCell>
                    <TableCell>
                      <Badge variant={item.reported_content_type === 'post' ? 'default' : 'secondary'} className="capitalize dark:text-white bg-blue-500 dark:bg-blue-600">
                        {item.reported_content_type === 'post' ? 'Sujet' : 'Message'}
                      </Badge>
                    </TableCell>
                    <TableCell className="dark:text-gray-300 max-w-xs truncate">
                      {contentLink ? (
                        <Link to={contentLink} target="_blank" rel="noopener noreferrer" className="hover:underline" title={item.content_title || item.content_excerpt || ''}>
                          {item.content_title ? <strong>{item.content_title}</strong> : (item.content_excerpt || 'N/A')}
                        </Link>
                      ) : (
                        <span title={item.content_title || item.content_excerpt || ''}>
                           {item.content_title ? <strong>{item.content_title}</strong> : (item.content_excerpt || 'N/A')} (Lien direct non disponible pour réponse)
                        </span>
                      )}
                      <p className="text-xs text-gray-500 dark:text-gray-400">Par: {item.content_author_username || 'Inconnu'}</p>
                    </TableCell>
                    <TableCell className="dark:text-gray-400">{item.reporter_username || 'Système'}</TableCell>
                    <TableCell className="dark:text-gray-300">
                      <span title={item.reason_details || ''}>{item.reason_category.replace('_', ' ').toLowerCase().replace(/\b\w/g, l => l.toUpperCase())}</span>
                    </TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" className="h-8 w-8 p-0 dark:text-gray-300 dark:hover:bg-gray-700">
                            <span className="sr-only">Ouvrir menu</span>
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="dark:bg-gray-800 dark:border-gray-700">
                          <DropdownMenuLabel className="dark:text-gray-200">Actions Modération</DropdownMenuLabel>
                          {contentLink && (
                            <DropdownMenuItem 
                              onClick={() => window.open(contentLink, '_blank')}
                              className="dark:text-gray-300 dark:hover:bg-gray-700"
                            >
                              <Eye className="mr-2 h-4 w-4" /> Voir Contenu
                            </DropdownMenuItem>
                          )}
                          {!contentLink && (
                             <DropdownMenuItem disabled className="dark:text-gray-500">
                              <Eye className="mr-2 h-4 w-4" /> Voir Contenu (lien non dispo)
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuSeparator className="dark:bg-gray-700" />
                          <DropdownMenuItem 
                            onClick={() => handleUpdateReportStatus(item.report_id, 'RESOLVED_APPROVED')}
                            className="dark:text-green-400 dark:hover:bg-gray-700 focus:bg-green-100 dark:focus:bg-green-800"
                          >
                            <CheckCircle className="mr-2 h-4 w-4" /> Approuver (ignorer signalement)
                          </DropdownMenuItem>
                          <DropdownMenuItem 
                            onClick={() => openDeleteConfirmation(item.reported_content_type, item.reported_content_id, item.report_id)}
                            className="dark:text-orange-400 dark:hover:bg-gray-700 focus:bg-orange-100 dark:focus:bg-orange-800"
                          >
                            <Trash2 className="mr-2 h-4 w-4" /> Supprimer Contenu Signalé
                          </DropdownMenuItem>
                           <DropdownMenuItem 
                            onClick={() => handleUpdateReportStatus(item.report_id, 'RESOLVED_REJECTED')}
                            className="dark:text-red-400 dark:hover:bg-gray-700 focus:bg-red-100 dark:focus:bg-red-800"
                          >
                            <XCircle className="mr-2 h-4 w-4" /> Rejeter Signalement (abusif)
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                )})}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
      
      <AlertDialog open={isDeleteConfirmOpen} onOpenChange={setIsDeleteConfirmOpen}>
        <AlertDialogContent className="dark:bg-gray-800">
          <AlertDialogHeader>
            <AlertDialogTitle className="dark:text-white">Confirmer la suppression du contenu</AlertDialogTitle>
            <AlertDialogDescription className="dark:text-gray-300">
              Êtes-vous sûr de vouloir supprimer ce contenu ? Cela le masquera pour les utilisateurs et résoudra les signalements associés.
              <Textarea
                value={deleteReason}
                onChange={(e) => setDeleteReason(e.target.value)}
                placeholder="Raison de la suppression (optionnel, pour les logs de modération)"
                className="mt-3 min-h-[80px] dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
              />
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmDeleteContent}
              className="bg-red-600 hover:bg-red-700 text-white"
            >
              Confirmer la suppression
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

    </div>
  );
};

export default ModerationPage;
