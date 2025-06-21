import { useState } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Link, useNavigate } from 'react-router-dom';
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
import { AlertCircle, Mail, CheckCircle, ArrowLeft } from 'lucide-react';
import { useToast } from "@/hooks/use-toast"; // Corrected import path

const ForgotPasswordPage = () => {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const { toast } = useToast();
  const navigate = useNavigate();

  const handlePasswordResetRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setMessage(null);

    // IMPORTANT: Configure this redirect URL in your Supabase project settings:
    // Authentication -> URL Configuration -> Redirect URLs
    // Add: ${window.location.origin}/modifier-mot-de-passe
    const redirectTo = `${window.location.origin}/modifier-mot-de-passe`;

    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo,
    });

    setLoading(false);
    if (resetError) {
      console.error("ForgotPasswordPage - Supabase resetPasswordForEmail error:", resetError);
      setError(resetError.message || "Erreur lors de la demande de réinitialisation.");
      toast({
        variant: "destructive",
        title: "Erreur",
        description: resetError.message || "Une erreur est survenue. Veuillez réessayer.",
      });
    } else {
      setMessage("Si un compte existe pour cette adresse email, un lien de réinitialisation de mot de passe a été envoyé. Veuillez vérifier votre boîte de réception (et vos spams).");
      toast({
        title: "Email envoyé",
        description: "Vérifiez votre boîte de réception pour le lien de réinitialisation.",
      });
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 p-4">
      <Card className="w-full max-w-md shadow-2xl bg-slate-800/50 backdrop-blur-lg border-slate-700">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 p-3 bg-yellow-600/20 rounded-full w-fit">
            <Mail className="h-10 w-10 text-yellow-400" />
          </div>
          <CardTitle className="text-3xl font-bold text-slate-100">Mot de passe oublié ?</CardTitle>
          <CardDescription className="text-slate-400">
            Entrez votre adresse email pour recevoir un lien de réinitialisation.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {message && !error && (
            <div className="mb-4 flex items-start p-3 text-sm text-green-300 bg-green-900/40 rounded-md border border-green-700">
              <CheckCircle className="h-5 w-5 mr-2 mt-0.5 flex-shrink-0" />
              <span>{message}</span>
            </div>
          )}
          <form onSubmit={handlePasswordResetRequest} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-slate-300">Adresse Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="votreadresse@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-yellow-500 focus:border-yellow-500"
                disabled={loading || !!message}
              />
            </div>
            {error && (
              <div className="flex items-center p-3 text-sm text-red-400 bg-red-900/30 rounded-md border border-red-700">
                <AlertCircle className="h-5 w-5 mr-2 flex-shrink-0" />
                <span>{error}</span>
              </div>
            )}
            <Button 
              type="submit" 
              className="w-full bg-yellow-600 hover:bg-yellow-700 text-white font-semibold py-3 text-base" 
              disabled={loading || !!message}
            >
              {loading ? 'Envoi en cours...' : 'Envoyer le lien de réinitialisation'}
            </Button>
          </form>
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

export default ForgotPasswordPage;
