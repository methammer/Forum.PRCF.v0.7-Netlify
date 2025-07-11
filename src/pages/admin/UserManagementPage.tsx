import { useEffect, useState, useCallback } from "react";
    import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
    import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
    import { Button } from "@/components/ui/button";
    import { Badge } from "@/components/ui/badge";
    import { supabase } from "@/lib/supabaseClient";
    import { Users, Loader2, ShieldCheck, ShieldAlert, UserCog, Trash2, MoreVertical, AlertTriangle, SendHorizonal } from "lucide-react"; // Changed MailKey to SendHorizonal
    import {
      DropdownMenu,
      DropdownMenuContent,
      DropdownMenuItem,
      DropdownMenuLabel,
      DropdownMenuSeparator,
      DropdownMenuTrigger,
    } from "@/components/ui/dropdown-menu";
    import { CreateUserDialog } from "@/components/admin/CreateUserDialog";
    import { EditUserDialog } from "@/components/admin/EditUserDialog";
    import { toast } from '@/hooks/use-toast';
    import { useUser } from "@/contexts/UserContext";
    import { usePermissions } from "@/hooks/usePermissions";
    import { Permission } from "@/constants/permissions"; // Ensure Permission enum is imported

    export type UserProfile = {
      id: string;
      email: string | null;
      created_at: string | null;
      username: string | null;
      full_name: string | null;
      avatar_url: string | null;
      status: 'pending_approval' | 'approved' | 'rejected' | null;
      role: 'USER' | 'MODERATOR' | 'ADMIN' | 'SUPER_ADMIN' | null;
    };

    const UserManagementPage = () => {
      const [users, setUsers] = useState<UserProfile[]>([]);
      const [isLoading, setIsLoading] = useState(true);
      const [error, setError] = useState<string | null>(null);
      
      const [isEditUserDialogOpen, setIsEditUserDialogOpen] = useState(false);
      const [selectedUserForEdit, setSelectedUserForEdit] = useState<UserProfile | null>(null);
      
      const { user: contextUser, profile: contextProfile, isLoadingAuth: isAuthLoading } = useUser();
      const { can, currentRole, isLoading: permissionsLoading } = usePermissions();

      const canViewUserList = can(Permission.VIEW_USER_LIST);
      const canCreateUser = can(Permission.CREATE_USER);
      const canEditUserProfile = can(Permission.EDIT_USER_PROFILE);
      const canChangeUserRole = can(Permission.CHANGE_USER_ROLE);
      const canApproveUser = can(Permission.APPROVE_USER_REGISTRATION);
      const canDeleteUser = can(Permission.DELETE_USER);
      const canSendPasswordReset = can(Permission.SEND_PASSWORD_RESET_EMAIL);

      const fetchUsers = useCallback(async () => {
        if (!canViewUserList && !permissionsLoading) {
          setError("Accès refusé. Vous n'avez pas la permission de voir la liste des utilisateurs.");
          setIsLoading(false);
          setUsers([]);
          return;
        }
        setIsLoading(true);
        setError(null);
        try {
          const { data, error: rpcError } = await supabase.rpc('get_all_user_details');
          if (rpcError) throw rpcError;
          setUsers(data as UserProfile[] || []);
        } catch (err: any) {
          const errorMessage = err.message || "Erreur lors de la récupération de la liste des utilisateurs.";
          setError(errorMessage);
          toast({
            title: "Erreur de chargement des utilisateurs",
            description: errorMessage,
            variant: "destructive",
          });
        } finally {
          setIsLoading(false);
        }
      }, [canViewUserList, permissionsLoading]);

      useEffect(() => {
        if (!isAuthLoading && !permissionsLoading) {
          if (canViewUserList) {
            fetchUsers();
          } else {
            setError("Accès refusé. Vous n'avez pas les permissions nécessaires pour voir cette page.");
            setIsLoading(false);
            setUsers([]);
          }
        } else if (isAuthLoading || permissionsLoading) {
          setIsLoading(true);
        }
      }, [isAuthLoading, permissionsLoading, canViewUserList, fetchUsers]);

      const getRoleBadgeVariant = (role: UserProfile['role']) => {
        switch (role) {
          case 'ADMIN':
          case 'SUPER_ADMIN':
            return 'destructive';
          case 'MODERATOR':
            return 'secondary';
          case 'USER':
          default:
            return 'outline';
        }
      };

      const formatRoleForDisplay = (roleString: UserProfile['role']): string => {
        if (!roleString) return 'N/A';
        switch (roleString) {
            case 'SUPER_ADMIN': return 'Super Admin';
            case 'ADMIN': return 'Admin';
            case 'MODERATOR': return 'Modérateur';
            case 'USER': return 'Utilisateur';
            default: 
                const lower = roleString.toLowerCase();
                return lower.charAt(0).toUpperCase() + lower.slice(1).replace('_', ' ');
        }
      };

      const getStatusBadgeVariant = (status: UserProfile['status']) => {
        switch (status) {
          case 'approved':
            return 'default';
          case 'pending_approval':
            return 'secondary';
          case 'rejected':
            return 'destructive';
          default:
            return 'outline';
        }
      };
      
      const handleUserUpdateViaFunction = async (userId: string, updates: Partial<UserProfile>, successMessage: string, actionDescription: string) => {
        if (updates.status === 'approved' && !canApproveUser) {
            toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission d'approuver des utilisateurs.", variant: "destructive" });
            return;
        }
        if (updates.role && !canChangeUserRole) {
            toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission de changer les rôles.", variant: "destructive" });
            return;
        }

        try {
          const { data: functionData, error: functionError } = await supabase.functions.invoke('update-user-details-admin', {
            body: { targetUserId: userId, updates },
          });

          if (functionError) {
            throw new Error(functionError.message || `Impossible de ${actionDescription.toLowerCase()} l'utilisateur.`);
          }
          
          const responseBody = functionData;
          if (responseBody && responseBody.data) {
            toast({ title: "Succès", description: successMessage });
          } else if (responseBody && responseBody.error) {
            toast({ title: "Erreur de mise à jour", description: responseBody.error, variant: "destructive" });
          } else {
             toast({ title: "Avertissement", description: `L'action "${actionDescription}" pour ${userId} a été appelée mais la réponse n'est pas claire.`, variant: "default", duration: 7000 });
          }
          fetchUsers();
        } catch (err: any) {
          toast({ title: "Erreur", description: err.message || `Impossible de ${actionDescription.toLowerCase()} l'utilisateur.`, variant: "destructive" });
        }
      };

      const handleApproveUser = async (userId: string) => {
        if (!canApproveUser) {
          toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission d'approuver des utilisateurs.", variant: "destructive" });
          return;
        }
        await handleUserUpdateViaFunction(userId, { status: 'approved' }, "Utilisateur approuvé.", "Approuver utilisateur");
      };

      const handleChangeRole = async (userId: string, newRole: UserProfile['role']) => {
        if (!canChangeUserRole) {
            toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission de changer les rôles.", variant: "destructive" });
            return;
        }
        if (!newRole) {
            toast({ title: "Erreur", description: "Nouveau rôle non spécifié.", variant: "destructive" });
            return;
        }
        const targetUser = users.find(u => u.id === userId);
        if (currentRole === 'ADMIN' && (userId === contextUser?.id || targetUser?.role === 'SUPER_ADMIN')) {
             toast({ title: "Action non autorisée", description: "Les administrateurs ne peuvent pas changer leur propre rôle ou celui d'un Super Admin.", variant: "destructive" });
             return;
        }
        if (currentRole === 'SUPER_ADMIN' && userId === contextUser?.id && newRole !== 'SUPER_ADMIN') {
            toast({ title: "Action non autorisée", description: "Un Super Admin ne peut pas changer son propre rôle de cette manière.", variant: "destructive" });
            return;
        }
        await handleUserUpdateViaFunction(userId, { role: newRole }, `Rôle de l'utilisateur mis à jour en ${formatRoleForDisplay(newRole)}.`, `Changer rôle en ${formatRoleForDisplay(newRole)}`);
      };

      const handleDeleteUser = async (userId: string, userEmail: string | null) => {
        if (!canDeleteUser) {
          toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission de supprimer des utilisateurs.", variant: "destructive" });
          return;
        }
        if (contextUser?.id === userId) {
          toast({ title: "Action non autorisée", description: "Vous ne pouvez pas supprimer votre propre compte.", variant: "destructive" });
          return;
        }
        if (!window.confirm(`Êtes-vous sûr de vouloir supprimer l'utilisateur ${userEmail || userId}? Cette action est irréversible.`)) {
          return;
        }
        try {
          const { error: functionError } = await supabase.functions.invoke('delete-user-admin', {
            body: { userIdToDelete: userId },
          });

          if (functionError) throw functionError;

          toast({ title: "Succès", description: `Utilisateur ${userEmail || userId} supprimé.` });
          fetchUsers();
        } catch (err: any) {
          toast({
            title: "Erreur de suppression",
            description: err.message || "Impossible de supprimer l'utilisateur.",
            variant: "destructive",
          });
        }
      };

      const handleSendPasswordReset = async (userEmail: string | null) => {
        if (!canSendPasswordReset) {
          toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission d'envoyer des emails de réinitialisation de mot de passe.", variant: "destructive" });
          return;
        }
        if (!userEmail) {
          toast({ title: "Erreur", description: "L'email de l'utilisateur n'est pas disponible.", variant: "destructive" });
          return;
        }
        if (!window.confirm(`Êtes-vous sûr de vouloir envoyer un email de réinitialisation de mot de passe à ${userEmail}?`)) {
          return;
        }
        try {
          toast({ title: "Envoi en cours...", description: `Demande de réinitialisation pour ${userEmail}.`});
          const { error: functionError, data } = await supabase.functions.invoke('admin-send-password-reset', {
            body: { email: userEmail },
          });

          if (functionError) throw functionError;
          
          if (data?.error) {
             toast({ title: "Erreur d'envoi", description: data.error, variant: "destructive" });
          } else {
             toast({ title: "Succès", description: data?.message || `Email de réinitialisation envoyé à ${userEmail}.` });
          }

        } catch (err: any) {
          toast({
            title: "Erreur d'envoi",
            description: err.message || "Impossible d'envoyer l'email de réinitialisation.",
            variant: "destructive",
          });
        }
      };

      const openEditDialog = (user: UserProfile) => {
        if (!canEditUserProfile && user.id !== contextUser?.id) {
          toast({ title: "Action non autorisée", description: "Vous n'avez pas la permission de modifier ce profil.", variant: "destructive" });
          return;
        }
        setSelectedUserForEdit(user);
        setIsEditUserDialogOpen(true);
      };

      if (isAuthLoading || permissionsLoading || (isLoading && users.length === 0 && !error) ) { 
        return (
          <div className="flex items-center justify-center h-64">
            <Loader2 className="h-12 w-12 animate-spin text-primary" />
            <p className="ml-4 text-lg dark:text-gray-300">Chargement des utilisateurs...</p>
          </div>
        );
      }

      if (!canViewUserList && !permissionsLoading) {
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
                  {error || "Vous n'avez pas les permissions nécessaires pour gérer les utilisateurs."}
                </p>
              </CardContent>
            </Card>
          </div>
        );
      }
      
      if (error && !isLoading) {
        return <p className="text-red-500 dark:text-red-400 bg-red-100 dark:bg-red-900/30 p-4 rounded-md text-center">{error}</p>;
      }

      return (
        <div className="space-y-6 p-4 md:p-6">
          <header className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-800 dark:text-white">
                Gestion des Utilisateurs
              </h1>
              <p className="mt-1 text-md text-gray-600 dark:text-gray-300">
                Visualiser, modifier et gérer les comptes utilisateurs. ({users.length} utilisateurs)
              </p>
            </div>
            { canCreateUser &&
              <CreateUserDialog onUserCreated={fetchUsers} />
            }
          </header>

          <Card className="dark:bg-gray-800 shadow-lg">
            <CardHeader>
              <CardTitle className="flex items-center text-xl text-gray-800 dark:text-white">
                <Users className="mr-2 h-6 w-6 text-blue-500 dark:text-blue-400" />
                Liste des Utilisateurs
              </CardTitle>
              <CardDescription className="text-gray-600 dark:text-gray-400">
                {users.length > 0 ? `Total de ${users.length} utilisateurs.` : "Aucun utilisateur trouvé."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              {users.length === 0 && !isLoading ? (
                <p className="text-gray-500 dark:text-gray-400 text-center py-8">
                  Aucun utilisateur à afficher.
                </p>
              ) : (
                <div className="overflow-x-auto">
                  <Table>
                    <TableHeader>
                      <TableRow className="dark:border-gray-700">
                        <TableHead className="dark:text-gray-300">Utilisateur</TableHead>
                        <TableHead className="dark:text-gray-300">Email</TableHead>
                        <TableHead className="dark:text-gray-300">Rôle</TableHead>
                        <TableHead className="dark:text-gray-300">Statut</TableHead>
                        <TableHead className="dark:text-gray-300">Inscrit le</TableHead>
                        <TableHead className="text-right dark:text-gray-300">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {users.map((user) => {
                        const isSelf = user.id === contextUser?.id;
                        let canManageTargetUserGeneral = false; 
                        let canManageTargetUserRoleChange = false; 
                        let canManageTargetUserDeletion = false; 

                        if (currentRole === 'SUPER_ADMIN' && !isSelf) {
                            canManageTargetUserGeneral = true;
                            canManageTargetUserRoleChange = true;
                            canManageTargetUserDeletion = true;
                        } else if (currentRole === 'ADMIN' && !isSelf) {
                            if (user.role !== 'SUPER_ADMIN') { 
                                canManageTargetUserGeneral = true; 
                                if (user.role !== 'ADMIN') { 
                                    canManageTargetUserRoleChange = true;
                                }
                                if (user.role !== 'ADMIN' && user.role !== 'SUPER_ADMIN') {
                                   canManageTargetUserDeletion = true;
                                }
                            }
                        }
                        
                        const effectiveCanManageForReset = (currentRole === 'SUPER_ADMIN' && !isSelf) || 
                                                           (currentRole === 'ADMIN' && !isSelf && user.role !== 'SUPER_ADMIN');


                        return (
                        <TableRow key={user.id} className="dark:border-gray-700 hover:dark:bg-gray-700/50">
                          <TableCell className="dark:text-gray-200">
                            <div className="font-medium">{user.full_name || user.username || 'N/A'}</div>
                            <div className="text-xs text-muted-foreground dark:text-gray-400">{user.username || user.id.substring(0,8)}</div>
                          </TableCell>
                          <TableCell className="dark:text-gray-300">{user.email || 'Non fourni'}</TableCell>
                          <TableCell>
                            <Badge variant={getRoleBadgeVariant(user.role)}>
                              {formatRoleForDisplay(user.role)}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            <Badge variant={getStatusBadgeVariant(user.status)} className="capitalize">
                              {user.status?.replace('_', ' ') || 'N/A'}
                            </Badge>
                          </TableCell>
                          <TableCell className="dark:text-gray-300">
                            {user.created_at ? new Date(user.created_at).toLocaleDateString() : 'N/A'}
                          </TableCell>
                          <TableCell className="text-right">
                            <DropdownMenu>
                              <DropdownMenuTrigger asChild>
                                <Button 
                                  variant="ghost" 
                                  size="icon" 
                                  className="dark:text-gray-400 dark:hover:bg-gray-700"
                                  disabled={!canManageTargetUserGeneral && !isSelf && !canEditUserProfile}
                                >
                                  <MoreVertical className="h-4 w-4" />
                                </Button>
                              </DropdownMenuTrigger>
                              <DropdownMenuContent align="end" className="dark:bg-gray-800 dark:border-gray-700">
                                <DropdownMenuLabel className="dark:text-gray-300">Actions</DropdownMenuLabel>
                                {(canEditUserProfile && (canManageTargetUserGeneral || isSelf )) && 
                                  <DropdownMenuItem onClick={() => openEditDialog(user)} className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                    <UserCog className="mr-2 h-4 w-4" /> Modifier Profil
                                  </DropdownMenuItem>
                                }
                                {user.status === 'pending_approval' && canApproveUser && canManageTargetUserGeneral && (
                                  <DropdownMenuItem onClick={() => handleApproveUser(user.id)} className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                    <ShieldCheck className="mr-2 h-4 w-4" /> Approuver Inscription
                                  </DropdownMenuItem>
                                )}

                                {canSendPasswordReset && effectiveCanManageForReset && !isSelf && (
                                  <DropdownMenuItem onClick={() => handleSendPasswordReset(user.email)} className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                    <SendHorizonal className="mr-2 h-4 w-4" /> Envoyer Réinitialisation MDP 
                                  </DropdownMenuItem>
                                )}
                                
                                {canChangeUserRole && canManageTargetUserRoleChange && <DropdownMenuSeparator className="dark:bg-gray-700" />}

                                { canChangeUserRole && currentRole === 'SUPER_ADMIN' && user.role !== 'SUPER_ADMIN' && !isSelf && (
                                    <DropdownMenuItem 
                                        onClick={() => handleChangeRole(user.id, 'SUPER_ADMIN')}
                                        className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                       <ShieldAlert className="mr-2 h-4 w-4 text-red-500" /> Passer Super Admin
                                    </DropdownMenuItem>
                                )}
                                { canChangeUserRole && canManageTargetUserRoleChange && user.role !== 'ADMIN' && (currentRole === 'SUPER_ADMIN' || (currentRole === 'ADMIN' && user.role !== 'SUPER_ADMIN')) && !isSelf && (
                                    <DropdownMenuItem 
                                        onClick={() => handleChangeRole(user.id, 'ADMIN')}
                                        className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                       <ShieldAlert className="mr-2 h-4 w-4 text-orange-500" /> Passer Admin
                                    </DropdownMenuItem>
                                )}
                                { canChangeUserRole && canManageTargetUserRoleChange && user.role !== 'MODERATOR' && !isSelf && (
                                    <DropdownMenuItem 
                                        onClick={() => handleChangeRole(user.id, 'MODERATOR')}
                                        className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                       <ShieldAlert className="mr-2 h-4 w-4 text-yellow-500" /> Passer Modérateur
                                    </DropdownMenuItem>
                                )}
                                { canChangeUserRole && canManageTargetUserRoleChange && user.role !== 'USER' && !isSelf && (
                                    <DropdownMenuItem 
                                        onClick={() => handleChangeRole(user.id, 'USER')}
                                        className="dark:text-gray-300 dark:hover:!bg-gray-700">
                                       <ShieldAlert className="mr-2 h-4 w-4 text-green-500" /> Passer Utilisateur
                                    </DropdownMenuItem>
                                )}
                                
                                {canDeleteUser && canManageTargetUserDeletion && !isSelf && <DropdownMenuSeparator className="dark:bg-gray-700"/>}
                                {canDeleteUser && canManageTargetUserDeletion && !isSelf &&
                                  <DropdownMenuItem 
                                    onClick={() => handleDeleteUser(user.id, user.email)} 
                                    className="text-red-600 dark:text-red-500 hover:!text-red-700 dark:hover:!text-red-400 dark:hover:!bg-red-700/50"
                                  >
                                    <Trash2 className="mr-2 h-4 w-4" /> Supprimer Utilisateur
                                  </DropdownMenuItem>
                                }
                              </DropdownMenuContent>
                            </DropdownMenu>
                          </TableCell>
                        </TableRow>
                      )})}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
          <EditUserDialog 
            user={selectedUserForEdit} 
            isOpen={isEditUserDialogOpen} 
            onOpenChange={setIsEditUserDialogOpen} 
            onUserUpdated={() => {
              fetchUsers();
              setSelectedUserForEdit(null); 
            }} 
          />
        </div>
      );
    };

    export default UserManagementPage;
