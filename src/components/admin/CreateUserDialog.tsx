import { useState } from 'react';
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
  DialogTrigger,
  DialogClose,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { toast } from '@/hooks/use-toast';
import { UserPlus } from 'lucide-react';
import { FunctionsHttpError, FunctionsRelayError, FunctionsFetchError } from '@supabase/supabase-js';

const userRoles = ['user', 'moderator', 'admin'] as const;

const createUserSchema = z.object({
  full_name: z.string().min(2, { message: "Le nom complet doit contenir au moins 2 caractères." }),
  username: z.string().min(3, { message: "Le nom d'utilisateur doit contenir au moins 3 caractères." }).regex(/^[a-zA-Z0-9_]+$/, { message: "Le nom d'utilisateur ne peut contenir que des lettres, chiffres et underscores."}),
  email: z.string().email({ message: "Adresse e-mail invalide." }),
  password: z.string().min(8, { message: "Le mot de passe doit contenir au moins 8 caractères." }),
  role: z.enum(userRoles, { errorMap: () => ({ message: "Rôle invalide." }) }),
});

type CreateUserFormData = z.infer<typeof createUserSchema>;

interface CreateUserDialogProps {
  onUserCreated: () => void;
}

export const CreateUserDialog: React.FC<CreateUserDialogProps> = ({ onUserCreated }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<CreateUserFormData>({
    resolver: zodResolver(createUserSchema),
    defaultValues: {
      full_name: '',
      username: '',
      email: '',
      password: '',
      role: 'user',
    },
  });

  const onSubmit = async (data: CreateUserFormData) => {
    setIsSubmitting(true);
    console.log("CreateUserDialog: Submitting form data for new user:", data);

    try {
      const { data: functionResponse, error: functionError } = await supabase.functions.invoke('create-user-admin', {
        body: {
          email: data.email,
          password: data.password,
          full_name: data.full_name,
          username: data.username,
          role: data.role,
        },
      });

      if (functionError) {
        console.error("CreateUserDialog: Edge function invocation returned an error. Raw error object:", functionError);
        let detailedMessage = "Une erreur est survenue lors de l'appel à la fonction Edge.";
        
        if (functionError instanceof FunctionsHttpError) {
          console.log("CreateUserDialog: Error is FunctionsHttpError. Status:", functionError.context.status, "Response object:", functionError.context);
          try {
            // functionError.context is the Response object. We need to parse its body.
            const errorBody = await functionError.context.json();
            if (errorBody && errorBody.error && typeof errorBody.error === 'string') {
              detailedMessage = errorBody.error;
            } else if (errorBody && errorBody.message && typeof errorBody.message === 'string') { // Some functions might return { message: "..." }
              detailedMessage = errorBody.message;
            } else {
               detailedMessage = `Erreur HTTP ${functionError.context.status}: ${functionError.context.statusText || 'Erreur inconnue de la fonction Edge.'}`;
            }
          } catch (e) {
            console.error("CreateUserDialog: Failed to parse JSON error response body from FunctionsHttpError:", e);
            detailedMessage = `Erreur HTTP ${functionError.context.status}: ${functionError.context.statusText || 'Impossible de lire la réponse d\'erreur de la fonction Edge.'}`;
          }
        } else if (functionError instanceof FunctionsRelayError) {
          detailedMessage = `Erreur de relais de la fonction: ${functionError.message}`;
        } else if (functionError instanceof FunctionsFetchError) {
          detailedMessage = `Erreur de réseau lors de l'appel de la fonction: ${functionError.message}`;
        } else if (functionError.message) {
          detailedMessage = functionError.message; // For other error types
        }
        
        console.error("CreateUserDialog: Throwing error with detailed message:", detailedMessage);
        throw new Error(detailedMessage);
      }
      
      if (functionResponse && functionResponse.error) {
         console.error("CreateUserDialog: Edge function returned 2xx but with an error in its response body:", functionResponse.error);
         const responseError = typeof functionResponse.error === 'string' 
            ? functionResponse.error 
            : (functionResponse.error.message || JSON.stringify(functionResponse.error));
         throw new Error(responseError || "La fonction a retourné une erreur inattendue dans sa réponse.");
      }

      console.log("CreateUserDialog: Edge function call successful. Response:", functionResponse);

      toast({
        title: "Utilisateur créé avec succès",
        description: `${data.email} a été ajouté et son profil mis à jour.`,
      });
      onUserCreated();
      setIsOpen(false);
      form.reset();

    } catch (error: any) {
      console.error("CreateUserDialog: Error caught in onSubmit handler:", error);
      toast({
        title: "Erreur lors de la création",
        description: error.message || "Une erreur non spécifiée est survenue lors de la création de l'utilisateur.",
        variant: "destructive",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => {
      setIsOpen(open);
      if (!open) {
        form.reset();
      }
    }}>
      <DialogTrigger asChild>
        <Button variant="default" className="bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-600">
          <UserPlus className="mr-2 h-4 w-4" /> Créer un utilisateur
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[425px] dark:bg-gray-800">
        <DialogHeader>
          <DialogTitle className="dark:text-white">Créer un nouvel utilisateur</DialogTitle>
          <DialogDescription className="dark:text-gray-400">
            Remplissez les informations ci-dessous pour ajouter un nouvel utilisateur. Le mot de passe doit être communiqué à l'utilisateur.
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
                    <Input placeholder="Jean Dupont" {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
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
                    <Input placeholder="jeandupont" {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Email</FormLabel>
                  <FormControl>
                    <Input type="email" placeholder="utilisateur@example.com" {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="password"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Mot de passe</FormLabel>
                  <FormControl>
                    <Input type="password" placeholder="********" {...field} className="dark:bg-gray-700 dark:border-gray-600 dark:text-white" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="role"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="dark:text-gray-300">Rôle</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger className="dark:bg-gray-700 dark:border-gray-600 dark:text-white">
                        <SelectValue placeholder="Sélectionner un rôle" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent className="dark:bg-gray-800 dark:border-gray-700 dark:text-white">
                      {userRoles.map(roleValue => (
                        <SelectItem key={roleValue} value={roleValue} className="capitalize hover:dark:bg-gray-700">
                          {roleValue}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            <DialogFooter>
              <DialogClose asChild>
                <Button type="button" variant="outline" className="dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-700">
                  Annuler
                </Button>
              </DialogClose>
              <Button type="submit" disabled={isSubmitting} className="bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-600">
                {isSubmitting ? 'Création en cours...' : 'Créer utilisateur'}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
};
