import { useEffect, useState, useCallback } from 'react';
    import { Link } from 'react-router-dom';
    import { supabase } from '@/lib/supabaseClient';
    import { useAuth } from '@/hooks/useAuth';
    import { useToast } from '@/hooks/use-toast';
    import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
    import { Button } from "@/components/ui/button";
    import { Input } from "@/components/ui/input";
    import { Textarea } from "@/components/ui/textarea";
    import { Badge } from "@/components/ui/badge";
    import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
    import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
    import { ShieldAlert, Search, Filter, Loader2, AlertTriangle, Eye, CheckCircle, XCircle, Trash2, MoreHorizontal, RotateCcw, ArchiveRestore, AlertOctagon } from "lucide-react";
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

    interface SoftDeletedItem {
      content_id: string;
      content_type: 'post' | 'reply';
      content_title: string | null; // For posts
      content_excerpt: string | null;
      content_author_username: string | null;
      deleted_at: string | null;
      deleter_username: string | null;
      deletion_reason: string | null;
      original_post_id: string | null; // For replies, to construct link
    }

    const ModerationPage = () => {
      const { canModerate, isLoading: authLoading } = useAuth();
      const { toast } = useToast();
      
      const [reportedItems, setReportedItems] = useState<ReportedItem[]>([]);
      const [isLoadingReports, setIsLoadingReports] = useState(true);
      const [reportsError, setReportsError] = useState<string | null>(null);
      
      const [softDeletedItems, setSoftDeletedItems] = useState<SoftDeletedItem[]>([]);
      const [isLoadingSoftDeleted, setIsLoadingSoftDeleted] = useState(true);
      const [softDeletedError, setSoftDeletedError] = useState<string | null>(null);

      const [searchTerm, setSearchTerm] = useState('');

      const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState(false);
      const [deleteContentInfo, setDeleteContentInfo] = useState<{type: 'post' | 'reply', id: string, reportIdToResolve?: string} | null>(null);
      const [deleteReason, setDeleteReason] = useState('');

      const [isRestoreConfirmOpen, setIsRestoreConfirmOpen] = useState(false);
      const [restoreContentInfo, setRestoreContentInfo] = useState<{type: 'post' | 'reply', id: string} | null>(null);

      const [isPermanentDeleteConfirmOpen, setIsPermanentDeleteConfirmOpen] = useState(false);
      const [permanentDeleteContentInfo, setPermanentDeleteContentInfo] = useState<{type: 'post' | 'reply', id: string} | null>(null);


      const fetchReportedItems = useCallback(async () => {
        setIsLoadingReports(true);
        setReportsError(null);
        try {
          const { data, error: rpcError } = await supabase.rpc('get_pending_reports_with_details');
          if (rpcError) throw rpcError;
          setReportedItems(data || []);
        } catch (err: any) {
          console.error("Error fetching reported items:", err);
          setReportsError(err.message || "Impossible de charger les signalements.");
          toast({ title: "Erreur de chargement des signalements", description: err.message || "Impossible de charger les signalements.", variant: "destructive" });
        } finally {
          setIsLoadingReports(false);
        }
      }, [toast]);

      const fetchSoftDeletedItems = useCallback(async () => {
        setIsLoadingSoftDeleted(true);
        setSoftDeletedError(null);
        try {
          const { data, error: rpcError } = await supabase.rpc('get_soft_deleted_content');
          if (rpcError) throw rpcError;
          setSoftDeletedItems(data || []);
        } catch (err: any) {
          console.error("Error fetching soft-deleted items:", err);
          setSoftDeletedError(err.message || "Impossible de charger les contenus supprimés.");
          toast({ title: "Erreur de chargement des contenus supprimés", description: err.message || "Impossible de charger les contenus supprimés.", variant: "destructive" });
        } finally {
          setIsLoadingSoftDeleted(false);
        }
      }, [toast]);

      useEffect(() => {
        if (!authLoading) {
          if (canModerate) {
            fetchReportedItems();
            fetchSoftDeletedItems();
          } else {
            setIsLoadingReports(false);
            setIsLoadingSoftDeleted(false);
            setReportsError("Accès non autorisé à cette page.");
          }
        }
      }, [canModerate, authLoading, fetchReportedItems, fetchSoftDeletedItems]);

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
          if (error) throw error;
          toast({ title: "Contenu supprimé (soft)", description: "Le contenu a été marqué comme supprimé et le signalement résolu.", className: "bg-orange-500 text-white" });
          fetchReportedItems(); 
          fetchSoftDeletedItems(); 
        } catch (err: any) {
          toast({ title: "Erreur de suppression (soft)", description: err.message || "Impossible de supprimer le contenu.", variant: "destructive" });
        } finally {
          setIsDeleteConfirmOpen(false);
          setDeleteContentInfo(null);
        }
      };

      const openRestoreConfirmation = (type: 'post' | 'reply', id: string) => {
        setRestoreContentInfo({ type, id });
        setIsRestoreConfirmOpen(true);
      };

      const confirmRestoreContent = async () => {
        if (!restoreContentInfo) return;
        try {
          const { error } = await supabase.rpc('restore_content', {
            p_content_type: restoreContentInfo.type,
            p_content_id: restoreContentInfo.id,
          });
          if (error) throw error;
          toast({ title: "Contenu restauré", description: "Le contenu a été restauré avec succès.", className: "bg-green-500 text-white" });
          fetchSoftDeletedItems(); 
          fetchReportedItems(); 
        } catch (err: any) {
          toast({ title: "Erreur de restauration", description: err.message || "Impossible de restaurer le contenu.", variant: "destructive" });
        } finally {
          setIsRestoreConfirmOpen(false);
          setRestoreContentInfo(null);
        }
      };

      const openPermanentDeleteConfirmation = (type: 'post' | 'reply', id: string) => {
        setPermanentDeleteContentInfo({ type, id });
        setIsPermanentDeleteConfirmOpen(true);
      };

      const confirmPermanentDeleteContent = async () => {
        if (!permanentDeleteContentInfo) return;
        try {
          const { error } = await supabase.rpc('permanently_delete_content', {
            p_content_type: permanentDeleteContentInfo.type,
            p_content_id: permanentDeleteContentInfo.id,
          });
          if (error) throw error;
          toast({ title: "Contenu supprimé définitivement", description: "Le contenu a été supprimé de manière permanente.", className: "bg-red-600 text-white" });
          fetchSoftDeletedItems(); // Refresh this list
          // Potentially refresh reported items too, if any reports were tied to this now non-existent content
          fetchReportedItems(); 
        } catch (err: any) {
          toast({ title: "Erreur de suppression définitive", description: err.message || "Impossible de supprimer définitivement le contenu.", variant: "destructive" });
        } finally {
          setIsPermanentDeleteConfirmOpen(false);
          setPermanentDeleteContentInfo(null);
        }
      };


      const getReportedContentLink = (item: ReportedItem) => {
        if (item.reported_content_type === 'post') {
            return `/forum/sujet/${item.reported_content_id}`;
        }
        // For replies, we need parent post_id. The current RPC for reports doesn't provide it directly.
        // This is a known limitation for reported replies.
        return null; 
      };

      const getSoftDeletedContentLink = (item: SoftDeletedItem) => {
        if (item.content_type === 'post') {
          return `/forum/sujet/${item.content_id}`;
        }
        if (item.content_type === 'reply' && item.original_post_id) {
          return `/forum/sujet/${item.original_post_id}#reply-${item.content_id}`;
        }
        return null;
      };


      if (authLoading) {
        return (
          <div className="flex justify-center items-center h-screen">
            <Loader2 className="h-12 w-12 animate-spin text-blue-500" />
          </div>
        );
      }

      if (!canModerate && !isLoadingReports && !isLoadingSoftDeleted) {
        return (
          <div className="space-y-6 p-4 md:p-6">
            <Card className="bg-red-50 border-red-500 dark:bg-red-900/30 dark:border-red-700">
              <CardHeader><CardTitle>Accès Refusé</CardTitle></CardHeader>
              <CardContent><p>{reportsError || "Vous n'avez pas les permissions nécessaires pour accéder à cette page."}</p></CardContent>
            </Card>
          </div>
        );
      }
      
      return (
        <div className="space-y-8 p-4 md:p-6">
          <header className="pb-4 border-b dark:border-gray-700">
            <h1 className="text-3xl font-bold text-gray-800 dark:text-white flex items-center">
              <ShieldAlert className="mr-3 h-8 w-8 text-orange-500" />
              Modération de Contenu
            </h1>
            <p className="mt-1 text-gray-600 dark:text-gray-300">
              Gérer les contenus signalés, restaurer les éléments supprimés et maintenir l'ordre sur le forum.
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

          {/* Reported Content Section */}
          <Card className="dark:bg-gray-800 shadow-md">
            <CardHeader>
              <CardTitle className="text-xl text-gray-800 dark:text-white">Contenus Signalés en Attente</CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">
                Liste des messages et sujets nécessitant une attention. Actuellement: {reportedItems.length} signalement(s).
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingReports && (
                <div className="flex justify-center items-center py-10">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
                  <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des signalements...</p>
                </div>
              )}
              {reportsError && !isLoadingReports && (
                <div className="text-red-600 dark:text-red-400 p-4 bg-red-50 dark:bg-red-900/30 rounded-md">
                  <AlertTriangle className="inline h-5 w-5 mr-2" /> Erreur: {reportsError}
                </div>
              )}
              {!isLoadingReports && !reportsError && reportedItems.length === 0 && (
                <div className="text-center text-gray-500 dark:text-gray-400 py-10">
                  <CheckCircle className="mx-auto h-12 w-12 mb-2 text-green-500" />
                  <p>Aucun contenu signalé en attente pour le moment.</p>
                </div>
              )}
              {!isLoadingReports && !reportsError && reportedItems.length > 0 && (
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
                          <span title={item.reason_details || ''}>{item.reason_category.replace(/_/g, ' ').toLowerCase().replace(/\b\w/g, l => l.toUpperCase())}</span>
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
                                <Trash2 className="mr-2 h-4 w-4" /> Supprimer Contenu Signalé (Soft)
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

          {/* Soft-Deleted Content Section */}
          <Card className="dark:bg-gray-800 shadow-md">
            <CardHeader>
              <CardTitle className="text-xl text-gray-800 dark:text-white flex items-center">
                <ArchiveRestore className="mr-2 h-6 w-6 text-blue-400" />
                Contenus Supprimés (Restaurables)
              </CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">
                Liste des sujets et messages marqués comme supprimés. Actuellement: {softDeletedItems.length} élément(s).
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingSoftDeleted && (
                <div className="flex justify-center items-center py-10">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-500" />
                  <p className="ml-3 text-gray-500 dark:text-gray-400">Chargement des contenus supprimés...</p>
                </div>
              )}
              {softDeletedError && !isLoadingSoftDeleted && (
                <div className="text-red-600 dark:text-red-400 p-4 bg-red-50 dark:bg-red-900/30 rounded-md">
                  <AlertTriangle className="inline h-5 w-5 mr-2" /> Erreur: {softDeletedError}
                </div>
              )}
              {!isLoadingSoftDeleted && !softDeletedError && softDeletedItems.length === 0 && (
                <div className="text-center text-gray-500 dark:text-gray-400 py-10">
                  <CheckCircle className="mx-auto h-12 w-12 mb-2 text-green-500" />
                  <p>Aucun contenu supprimé à afficher.</p>
                </div>
              )}
              {!isLoadingSoftDeleted && !softDeletedError && softDeletedItems.length > 0 && (
                <Table>
                  <TableHeader>
                    <TableRow className="dark:border-gray-700">
                      <TableHead className="dark:text-gray-300">Supprimé le</TableHead>
                      <TableHead className="dark:text-gray-300">Type</TableHead>
                      <TableHead className="dark:text-gray-300">Contenu (Extrait/Titre)</TableHead>
                      <TableHead className="dark:text-gray-300">Auteur Original</TableHead>
                      <TableHead className="dark:text-gray-300">Supprimé par</TableHead>
                      <TableHead className="dark:text-gray-300">Raison Suppression</TableHead>
                      <TableHead className="dark:text-gray-300 text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {softDeletedItems.map((item) => {
                      const contentLink = getSoftDeletedContentLink(item);
                      return (
                      <TableRow key={item.content_id} className="dark:border-gray-700">
                        <TableCell className="dark:text-gray-400 text-xs">
                          {item.deleted_at ? format(new Date(item.deleted_at), 'dd/MM/yy HH:mm', { locale: fr }) : 'N/A'}
                        </TableCell>
                        <TableCell>
                          <Badge variant={item.content_type === 'post' ? 'default' : 'secondary'} className="capitalize dark:text-white bg-gray-500 dark:bg-gray-600">
                            {item.content_type === 'post' ? 'Sujet' : 'Message'}
                          </Badge>
                        </TableCell>
                        <TableCell className="dark:text-gray-300 max-w-xs truncate">
                          {contentLink ? (
                            <Link to={contentLink} target="_blank" rel="noopener noreferrer" className="hover:underline" title={item.content_title || item.content_excerpt || ''}>
                              {item.content_title ? <strong>{item.content_title}</strong> : (item.content_excerpt || 'N/A')}
                            </Link>
                          ) : (
                            <span title={item.content_title || item.content_excerpt || ''}>
                               {item.content_title ? <strong>{item.content_title}</strong> : (item.content_excerpt || 'N/A')}
                               {item.content_type === 'reply' && !item.original_post_id && " (Lien non dispo)"}
                            </span>
                          )}
                        </TableCell>
                        <TableCell className="dark:text-gray-400">{item.content_author_username || 'Inconnu'}</TableCell>
                        <TableCell className="dark:text-gray-400">{item.deleter_username || 'N/A'}</TableCell>
                        <TableCell className="dark:text-gray-300 text-xs" title={item.deletion_reason || ''}>
                          {item.deletion_reason ? (item.deletion_reason.substring(0,50) + (item.deletion_reason.length > 50 ? '...' : '')) : 'N/A'}
                        </TableCell>
                        <TableCell className="text-right space-x-2">
                           <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => openRestoreConfirmation(item.content_type, item.content_id)}
                            className="dark:text-green-400 dark:border-green-600 dark:hover:bg-green-700 dark:hover:text-green-300"
                          >
                            <RotateCcw className="mr-2 h-4 w-4" /> Restaurer
                          </Button>
                          <Button 
                            variant="destructive" 
                            size="sm"
                            onClick={() => openPermanentDeleteConfirmation(item.content_type, item.content_id)}
                            className="dark:bg-red-700 dark:hover:bg-red-800"
                          >
                            <AlertOctagon className="mr-2 h-4 w-4" /> Supp. Déf.
                          </Button>
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
                <AlertDialogTitle className="dark:text-white">Confirmer la suppression (soft) du contenu</AlertDialogTitle>
                <AlertDialogDescription className="dark:text-gray-300">
                  Êtes-vous sûr de vouloir masquer ce contenu ? Cela le rendra invisible pour les utilisateurs et résoudra les signalements associés.
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
                  className="bg-orange-600 hover:bg-orange-700 text-white"
                >
                  Confirmer la suppression (soft)
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>

          <AlertDialog open={isRestoreConfirmOpen} onOpenChange={setIsRestoreConfirmOpen}>
            <AlertDialogContent className="dark:bg-gray-800">
              <AlertDialogHeader>
                <AlertDialogTitle className="dark:text-white">Confirmer la restauration du contenu</AlertDialogTitle>
                <AlertDialogDescription className="dark:text-gray-300">
                  Êtes-vous sûr de vouloir restaurer ce contenu ? Il sera de nouveau visible par les utilisateurs.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</AlertDialogCancel>
                <AlertDialogAction
                  onClick={confirmRestoreContent}
                  className="bg-green-600 hover:bg-green-700 text-white"
                >
                  Confirmer la restauration
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>

          <AlertDialog open={isPermanentDeleteConfirmOpen} onOpenChange={setIsPermanentDeleteConfirmOpen}>
            <AlertDialogContent className="dark:bg-gray-800">
              <AlertDialogHeader>
                <AlertDialogTitle className="dark:text-white flex items-center">
                  <AlertOctagon className="mr-2 h-6 w-6 text-red-500" />
                  Confirmer la suppression DÉFINITIVE
                </AlertDialogTitle>
                <AlertDialogDescription className="dark:text-gray-300">
                  <p className="font-semibold text-red-400">ATTENTION : Cette action est IRRÉVERSIBLE.</p>
                  <p>Le contenu sera physiquement supprimé de la base de données, ainsi que tous les signalements associés. Il ne pourra pas être récupéré.</p>
                  <p className="mt-2">Êtes-vous absolument sûr de vouloir continuer ?</p>
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">Annuler</AlertDialogCancel>
                <AlertDialogAction
                  onClick={confirmPermanentDeleteContent}
                  className="bg-red-700 hover:bg-red-800 text-white"
                >
                  Oui, supprimer définitivement
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>

        </div>
      );
    };

    export default ModerationPage;
