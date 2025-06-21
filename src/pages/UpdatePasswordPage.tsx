import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { useNavigate } from 'react-router-dom';
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AlertCircle, KeyRound, CheckCircle, Loader2, ArrowLeft } from 'lucide-react';
import { useToast } from "@/hooks/use-toast";

const UpdatePasswordPage = () => {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [canUpdate, setCanUpdate] = useState(false);
  const [initialLoading, setInitialLoading] = useState(true);
  const navigate = useNavigate();
  const { toast } = useToast();

  useEffect(() => {
    const processUrlHash = () => {
      const hash = window.location.hash;
      if (hash.includes('error_code=otp_expired') || (hash.includes('error=access_denied') && hash.includes('type=recovery'))) {
        const urlParams = new URLSearchParams(hash.substring(1)); // Remove #
        const errorDescription = urlParams.get('error_description') || "Le lien de récupération de mot de passe est invalide, a expiré, ou a déjà été utilisé.";
        setError(errorDescription.replace(/\+/g, ' ') + " Veuillez demander un nouveau lien.");
        setCanUpdate(false);
        setMessage(null);
        setInitialLoading(false);
        toast({
          variant: "destructive",
          title: "Lien invalide ou expiré",
          description: "Veuillez demander un nouveau lien de réinitialisation.",
        });
        return true; // Error processed
      }
      return false; // No error in hash
    };

    // Process hash on initial mount if still loading
    if (initialLoading) {
      if (processUrlHash()) {
        return; // Stop if hash error handled, auth listener will be cleaned up if already set
      }
    }

    const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log(`UpdatePasswordPage - Auth event: ${event}, session: ${!!session}, initialLoading: ${initialLoading}`);

      // Re-check hash in case it changed or event fired before initial check completed fully
      // This is important because the auth event might fire after the initial hash check
      if (processUrlHash()) {
        // If an error is found in the hash now, ensure we stop further processing
        // and don't proceed to setCanUpdate(true) from a PASSWORD_RECOVERY event.
        setInitialLoading(false); // ensure loader is off
        return;
      }

      if (event === "PASSWORD_RECOVERY") {
        if (session) {
          // No error in hash, and PASSWORD_RECOVERY event with session
          setCanUpdate(true);
          setMessage(null); // Clear message to show the form
          setError(null);   // Clear any previous error
          toast({
            title: "Prêt à mettre à jour",
            description: "Vous pouvez définir votre nouveau mot de passe.",
          });
        } else {
          // This case might occur if Supabase client fails to establish a session despite PASSWORD_RECOVERY event
          setError("Session de récupération invalide. Le lien est peut-être corrompu ou expiré.");
          setCanUpdate(false);
          setMessage(null);
          toast({
            variant: "destructive",
            title: "Erreur de session",
            description: "Impossible d'établir une session de récupération. Veuillez réessayer.",
          });
        }
      } else if (event === "SIGNED_OUT") {
        setCanUpdate(false); // If user signs out, they can't update password anymore
      } else if (event === "INITIAL_SESSION" || event === "SIGNED_IN") {
        // If not a PASSWORD_RECOVERY flow (e.g. user navigates here directly)
        // and canUpdate is not already true, it's not a valid recovery.
        // The processUrlHash and PASSWORD_RECOVERY checks should handle valid cases.
        // If initialLoading is true and no recovery hash, show error.
        if (initialLoading && !window.location.hash.includes('type=recovery')) {
            setError("Page accessible uniquement via un lien de récupération de mot de passe valide.");
            setCanUpdate(false);
        }
      }
      
      // Set initialLoading to false once we have processed relevant events or determined state.
      if (event === "PASSWORD_RECOVERY" || event === "INITIAL_SESSION" || event === "SIGNED_IN" || event === "SIGNED_OUT" || error) {
          setInitialLoading(false);
      }
    });

    // Fallback if no auth events fire quickly but not a recovery URL
    if (initialLoading && !window.location.hash.includes('type=recovery') && !window.location.hash.includes('error=')) {
        const timeoutId = setTimeout(() => {
            if (initialLoading) { // Check again, in case an auth event resolved it
                setError("Page accessible uniquement via un lien de récupération de mot de passe.");
                setCanUpdate(false);
                setInitialLoading(false);
            }
        }, 1500); // Give auth events a bit of time
        return () => {
            clearTimeout(timeoutId);
            authListener.subscription?.unsubscribe();
        };
    }


    return () => {
      authListener.subscription?.unsubscribe();
    };
  }, [navigate, toast, initialLoading]); // initialLoading is key here to control initial checks


  const handlePasswordUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      setError("Les mots de passe ne correspondent pas.");
      return;
    }
    if (password.length < 6) {
      setError("Le mot de passe doit contenir au moins 6 caractères.");
      return;
    }

    setLoading(true);
    setError(null);
    setMessage(null);

    const { error: updateError } = await supabase.auth.updateUser({ password });

    setLoading(false);
    if (updateError) {
      console.error("UpdatePasswordPage - Supabase updateUser error:", updateError);
      setError(updateError.message || "Erreur lors de la mise à jour du mot de passe.");
      toast({
        variant: "destructive",
        title: "Erreur de mise à jour",
        description: updateError.message || "Une erreur est survenue. Veuillez réessayer.",
      });
    } else {
      setMessage("Votre mot de passe a été mis à jour avec succès. Vous allez être redirigé vers la page de connexion.");
      toast({
        title: "Succès",
        description: "Mot de passe mis à jour. Vous pouvez maintenant vous connecter.",
      });
      setTimeout(() => {
        supabase.auth.signOut(); // Ensure any recovery session is cleared
        navigate('/connexion');
      }, 3000);
    }
  };

  if (initialLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 p-4 text-slate-100">
        <Loader2 className="h-12 w-12 animate-spin text-blue-400 mb-4" />
        <p>Vérification du lien de récupération...</p>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 p-4">
      <Card className="w-full max-w-md shadow-2xl bg-slate-800/50 backdrop-blur-lg border-slate-700">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 p-3 bg-green-600/20 rounded-full w-fit">
            <KeyRound className="h-10 w-10 text-green-400" />
          </div>
          <CardTitle className="text-3xl font-bold text-slate-100">Définir un nouveau mot de passe</CardTitle>
          {!canUpdate && !error && !message && ( // Default description if not updating, no error, no success message
             <CardDescription className="text-slate-400 pt-2">
              Pour réinitialiser votre mot de passe, veuillez utiliser le lien valide envoyé à votre adresse e-mail.
            </CardDescription>
          )}
        </CardHeader>
        <CardContent>
          {/* Error messages take precedence */}
          {error && (
            <div className="mb-4 flex items-center p-3 text-sm text-red-400 bg-red-900/30 rounded-md border border-red-700">
              <AlertCircle className="h-5 w-5 mr-2 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Success/info message (like password updated successfully) */}
          {message && !error && ( // Only show if no error
            <div className={`mb-4 flex items-start p-3 text-sm rounded-md border text-green-300 bg-green-900/40 border-green-700`}>
              <CheckCircle className="h-5 w-5 mr-2 mt-0.5 flex-shrink-0" />
              <span>{message}</span>
            </div>
          )}
          
          {/* Form: show if canUpdate is true, no overriding error, and no success message (message is for post-update success) */}
          {canUpdate && !error && !message && (
            <form onSubmit={handlePasswordUpdate} className="space-y-6">
              <CardDescription className="text-slate-400 text-center pb-2">
                Veuillez entrer votre nouveau mot de passe ci-dessous.
              </CardDescription>
              <div className="space-y-2">
                <Label htmlFor="password" className="text-slate-300">Nouveau mot de passe</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="******** (min. 6 caractères)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirmPassword" className="text-slate-300">Confirmer le nouveau mot de passe</Label>
                <Input
                  id="confirmPassword"
                  type="password"
                  placeholder="********"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                />
              </div>
              <Button type="submit" className="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-3 text-base" disabled={loading}>
                {loading ? (<> <Loader2 className="mr-2 h-4 w-4 animate-spin" /> Mise à jour en cours...</>) : 'Mettre à jour le mot de passe'}
              </Button>
            </form>
          )}
          
          {/* Fallback message if not allowed to update and not loading and no specific error/message already shown */}
          {!canUpdate && !initialLoading && !error && !message && (
             <div className="text-center text-slate-400 p-4 border border-slate-700 rounded-md">
                <AlertCircle className="h-8 w-8 mx-auto mb-2 text-yellow-500" />
                <p>Ce lien semble invalide ou a expiré. Veuillez demander un nouveau lien de réinitialisation si nécessaire.</p>
            </div>
          )}
        </CardContent>
        <CardFooter className="flex flex-col items-center space-y-4 pt-6">
           <Button variant="ghost" onClick={() => navigate('/connexion')} className="text-slate-400 hover:text-slate-200">
            <ArrowLeft className="mr-2 h-4 w-4" /> Retour à la connexion
          </Button>
        </CardFooter>
      </Card>
    </div>
  );
};

export default UpdatePasswordPage;
