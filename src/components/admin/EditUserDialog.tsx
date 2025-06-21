import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { supabase } from '@/lib/supabaseClient';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
// import { Label } from '@/components/ui/label'; // Not used directly
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { toast } from '@/hooks/use-toast';
import { UserProfile } from '@/pages/admin/UserManagementPage'; // Assuming UserProfile is exported
import { useUser } from '@/contexts/UserContext'; // To get current admin's role for conditional disabling

const userRoles = ['user', 'moderator', 'admin', 'super_admin'] as const;
const userStatuses = ['pending_approval', 'approved', 'rejected'] as const;

const editUserSchema = z.object({
  full_name: z.string().min(2, { message: "Le nom complet doit contenir au moins 2 caractères." }).optional().or(z.literal('')),
  username: z.string().min(3, { message: "Le nom d'utilisateur doit contenir au moins 3 caractères." }).optional().or(z.literal('')),
  // email: z.string().email({ message: "Adresse e-mail invalide." }), // Email is not editable here
  role: z.enum(userRoles, { errorMap: () => ({ message: "Rôle invalide." }) }),
  status: z.enum(userStatuses, { errorMap: () => ({ message: "Statut invalide." }) }),
});

type EditUserFormData = z.infer<typeof editUserSchema>;

interface EditUserDialogProps {
  user: UserProfile | null;
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  onUserUpdated: () => void;
}

export const EditUserDialog: React.FC<EditUserDialogProps> = ({ user, isOpen, onOpenChange, onUserUpdated }) => {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { profile: currentAdminProfile } = useUser();

  const form = useForm<EditUserFormData>({
    resolver: zodResolver(editUserSchema),
    defaultValues: {
      full_name: '',
      username: '',
      role: 'user',
      status: 'pending_approval',
    }
  });

  useEffect(() => {
    if (user && isOpen) { // Reset form when dialog opens with a new user
      form.reset({
        full_name: user.full_name || '',
        username: user.username || '',
        role: user.role || 'user',
        status: user.status || 'pending_approval',
      });
    }
  }, [user, form, isOpen]);

  const onSubmit = async (data: EditUserFormData) => {
    if (!user) return;
    setIsSubmitting(true);

    const updates: any = {};
    if (data.full_name !== user.full_name) updates.full_name = data.full_name;
    if (data.username !== user.username) updates.username = data.username;
    if (data.role !== user.role) updates.role = data.role;
    if (data.status !== user.status) updates.status = data.status;

    if (Object.keys(updates).length === 0) {
      toast({ title: "Aucune modification", description: "Aucun champ n'a été modifié." });
      setIsSubmitting(false);
      onOpenChange(false);
      return;
    }
    
    console.log("EditUserDialog: Invoking update-user-details-admin for user ID", user.id, "with updates:", updates);

    try {
      const { data: functionData, error: functionError } = await supabase.functions.invoke('update-user-details-admin', {
        body: { targetUserId: user.id, updates },
      });

      if (functionError) {
        console.error("EditUserDialog: Edge function error:", functionError);
        throw new Error(functionError.message || "Erreur de la fonction Edge.");
      }
      
      const responseBody = functionData; // Assuming functionData is the parsed JSON body
      console.log("EditUserDialog: Edge function success response:", responseBody);


      if (responseBody && responseBody.data) {
         toast({
          title: "Utilisateur mis à jour",
          description: `Le profil de ${user.email} a été mis à jour.`,
        });
      } else if (responseBody && responseBody.error) {
         toast({
          title: "Erreur de mise à jour (fonction)",
          description: responseBody.error,
          variant: "destructive",
        });
      } else {
         toast({
          title: "Mise à jour potentiellement incomplète",
          description: `La fonction a été appelée mais la réponse n'est pas claire pour ${user.email}. Veuillez vérifier.`,
          variant: "default"
        });
      }
      onUserUpdated();
      onOpenChange(false);
    } catch (error: any) {
      console.error("EditUserDialog: Error updating user:", error);
      toast({
        title: "Erreur de mise à jour",
        description: error.message || "Une erreur est survenue lors de la mise à jour du profil.",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };
  
  const handlePasswordReset = async () => {
    if (!user || !user.email) return;
    // This would typically involve another Edge Function that uses supabase.auth.admin.generateLink()
    // or similar, and then an email service to send the link.
    // For now, it's a placeholder.
    try {
        const { data, error } = await supabase.auth.resetPasswordForEmail(user.email, {
            redirectTo: `${window.location.origin}/update-password`, // Your redirect URL
        });
        if (error) throw error;
        toast({
            title: "Email de réinitialisation envoyé",
            description: `Un email a été envoyé à ${user.email} avec les instructions pour réinitialiser le mot de passe.`,
            variant: "default"
        });
    } catch (error: any) {
        toast({
            title: "Erreur d'envoi",
            description: error.message || "Impossible d'envoyer l'email de réinitialisation.",
            variant: "destructive"
        });
    }
  };

  if (!user) return null;

  const isEditingSelf = currentAdminProfile?.id === user.id;
  const currentAdminRole = currentAdminProfile?.role;

  // Determine if role select should be disabled
  let roleSelectDisabled = false;
  if (currentAdminRole === 'admin') {
    // Admin cannot edit another Admin or SuperAdmin's role
    if (user.role === 'admin' || user.role === 'super_admin') {
      roleSelectDisabled = true;
    }
    // Admin cannot edit their own role
    if (isEditingSelf) {
      roleSelectDisabled = true;
    }
  } else if (currentAdminRole === 'super_admin') {
    // SuperAdmin cannot edit their own role to something else
    if (isEditingSelf) {
      // Allow changing if it's to 'super_admin' (no change), but disable if trying to demote self
      // This logic is more complex and primarily enforced by the Edge Function.
      // For UI, we can simplify: if editing self as super_admin, disable role change.
      // Or, allow selection but the Edge Function will reject demotion.
      // Let's disable for simplicity in UI, Edge Function is the source of truth.
      // roleSelectDisabled = true; // This would prevent super_admin from even seeing their role selected.
      // Better: allow selection, rely on Edge Function to prevent self-demotion.
    }
  }


  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px] dark:bg-gray-800">
        <DialogHeader>
          <DialogTitle className="dark:text-white">Modifier l'utilisateur</DialogTitle>
          <DialogDescription className="dark:text-gray-400">
            Mettre à jour les informations de {user.email || user.id}.
          </DialogDescription>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="full_name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Nom complet</FormLabel>
                  <FormControl>
                    <Input {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="username"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Nom d'utilisateur</FormLabel>
                  <FormControl>
                    <Input {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
             <FormItem>
                <FormLabel className="dark:text-gray-300">Email (non modifiable ici)</FormLabel>
                <FormControl>
                    <Input type="email" value={user.email || ''} readOnly disabled className="dark:bg-gray-900 dark:border-gray-700 dark:text-gray-400" />
                </FormControl>
            </FormItem>

            <FormField
              control={form.control}
              name="role"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Rôle</FormLabel>
                  <Select 
                    onValueChange={field.onChange} 
                    defaultValue={field.value}
                    disabled={roleSelectDisabled || (isEditingSelf && currentAdminRole === 'super_admin' && field.value !== 'super_admin')} // SuperAdmin cannot demote self
                  >
                    <FormControl>
                      <SelectTrigger className="dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                        <SelectValue placeholder="Sélectionner un rôle" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent className="dark:bg-gray-800 dark:border-gray-700 dark:text-white">
                      {userRoles.map(roleValue => (
                        <SelectItem 
                          key={roleValue} 
                          value={roleValue} 
                          className="capitalize hover:dark:bg-gray-700"
                          // Admin cannot promote to Admin or SuperAdmin
                          disabled={
                            (currentAdminRole === 'admin' && (roleValue === 'admin' || roleValue === 'super_admin') && !isEditingSelf) ||
                            (isEditingSelf && currentAdminRole === 'super_admin' && roleValue !== 'super_admin') // SuperAdmin cannot demote self
                          }
                        >
                          {roleValue.replace('_', ' ').replace('super admin', 'Super Admin')}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="status"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Statut</FormLabel>
                  <Select 
                    onValueChange={field.onChange} 
                    defaultValue={field.value}
                    // Admin cannot change status of other Admins or SuperAdmins
                    disabled={(currentAdminRole === 'admin' && (user.role === 'admin' || user.role === 'super_admin') && !isEditingSelf)}
                  >
                    <FormControl>
                      <SelectTrigger className="dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                        <SelectValue placeholder="Sélectionner un statut" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent className="dark:bg-gray-800 dark:border-gray-700 dark:text-white">
                      {userStatuses.map(statusValue => (
                        <SelectItem key={statusValue} value={statusValue} className="capitalize hover:dark:bg-gray-700">
                          {statusValue.replace('_', ' ')}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
             <Button type="button" variant="outline" onClick={handlePasswordReset} className="w-full dark:text-blue-400 dark:border-blue-500 dark:hover:bg-blue-700/20">
                Envoyer lien de réinitialisation MDP
            </Button>
            <DialogFooter>
               <DialogClose asChild>
                <Button type="button" variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
                  Annuler
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isSubmitting} className="bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-600">
                {isSubmitting ? 'Mise à jour...' : 'Sauvegarder'}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
};
