import { useState } from 'react';
    import { supabase } from '@/lib/supabaseClient';
    import { useNavigate, Link } from 'react-router-dom';
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
    import { AlertCircle, UserPlus, CheckCircle, ChromeIcon } from 'lucide-react';

    const SignUpPage = () => {
      const [email, setEmail] = useState('');
      const [password, setPassword] = useState('');
      const [username, setUsername] = useState('');
      const [fullName, setFullName] = useState('');
      const [error, setError] = useState<string | null>(null);
      const [successMessage, setSuccessMessage] = useState<string | null>(null);
      const [loading, setLoading] = useState(false);
      const [googleLoading, setGoogleLoading] = useState(false); // État de chargement pour Google
      const navigate = useNavigate();

      const handleEmailSignUp = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        setSuccessMessage(null);

        if (password.length < 6) {
          setError("Le mot de passe doit contenir au moins 6 caractères.");
          setLoading(false);
          return;
        }
        if (!username.trim()) {
          setError("Le nom d'utilisateur est requis.");
          setLoading(false);
          return;
        }
        if (!fullName.trim()) {
          setError("Le nom complet est requis.");
          setLoading(false);
          return;
        }

        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              username: username.trim(),
              full_name: fullName.trim(),
              // avatar_url can be added here if collected, or updated later by user/admin
            },
          },
        });

        setLoading(false);

        if (signUpError) {
          setError(signUpError.message || "Une erreur s'est produite lors de l'inscription.");
        } else if (data.user) {
          // The trigger handle_new_user will create the profile entry.
          // The profile status will default to 'pending_approval'.
          setSuccessMessage("Inscription réussie ! Votre compte est en attente d'approbation par un administrateur. Vous serez notifié une fois approuvé.");
          // Optionally, clear form or redirect after a delay
          // setTimeout(() => navigate('/connexion'), 5000);
        } else {
          setError("Un problème inattendu est survenu. L'utilisateur n'a pas été créé.");
        }
      };

      const handleGoogleSignUp = async () => {
        setGoogleLoading(true);
        setError(null); // Clear previous errors
        setSuccessMessage(null); // Clear previous success messages

        const { error: googleError } = await supabase.auth.signInWithOAuth({
          provider: 'google',
          options: {
            redirectTo: `${window.location.origin}/` // Redirect to home page after Google auth
          }
        });

        if (googleError) {
          console.error("SignUpPage - Google OAuth error:", googleError);
          setError(googleError.message || "Erreur lors de l'inscription avec Google.");
          setGoogleLoading(false);
        }
        // If no immediate error, Supabase handles redirection. Loading state will persist until page navigates away.
      };

      return (
        <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 p-4">
          <Card className="w-full max-w-lg shadow-2xl bg-slate-800/50 backdrop-blur-lg border-slate-700">
            <CardHeader className="text-center">
              <div className="mx-auto mb-4 p-3 bg-green-600/20 rounded-full w-fit">
                <UserPlus className="h-10 w-10 text-green-400" />
              </div>
              <CardTitle className="text-3xl font-bold text-slate-100">Créer un compte</CardTitle>
              <CardDescription className="text-slate-400">
                Rejoignez le forum du PRCF. Votre compte nécessitera une approbation administrateur.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {successMessage ? (
                <div className="flex flex-col items-center p-4 text-green-300 bg-green-900/30 rounded-md border border-green-700">
                  <CheckCircle className="h-12 w-12 mb-3 text-green-400" />
                  <p className="text-center">{successMessage}</p>
                  <Button onClick={() => navigate('/connexion')} className="mt-4 bg-green-600 hover:bg-green-700 text-white">
                    Aller à la page de connexion
                  </Button>
                </div>
              ) : (
                <>
                  <form onSubmit={handleEmailSignUp} className="space-y-5">
                    <div className="space-y-2">
                      <Label htmlFor="username" className="text-slate-300">Nom d'utilisateur</Label>
                      <Input
                        id="username"
                        type="text"
                        placeholder="Votre nom d'utilisateur unique"
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                        required
                        className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                        disabled={googleLoading}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="fullName" className="text-slate-300">Nom complet</Label>
                      <Input
                        id="fullName"
                        type="text"
                        placeholder="Prénom Nom"
                        value={fullName}
                        onChange={(e) => setFullName(e.target.value)}
                        required
                        className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                        disabled={googleLoading}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="email" className="text-slate-300">Email</Label>
                      <Input
                        id="email"
                        type="email"
                        placeholder="votreadresse@email.com"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                        disabled={googleLoading}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="password" className="text-slate-300">Mot de passe</Label>
                      <Input
                        id="password"
                        type="password"
                        placeholder="******** (min. 6 caractères)"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        required
                        className="bg-slate-700 border-slate-600 text-slate-100 placeholder-slate-500 focus:ring-green-500 focus:border-green-500"
                        disabled={googleLoading}
                      />
                    </div>
                    {error && (
                      <div className="flex items-center p-3 text-sm text-red-400 bg-red-900/30 rounded-md border border-red-700">
                        <AlertCircle className="h-5 w-5 mr-2" />
                        <span>{error}</span>
                      </div>
                    )}
                    <Button type="submit" className="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-3 text-base" disabled={loading || googleLoading}>
                      {loading ? "Création du compte..." : "S'inscrire avec Email"}
                    </Button>
                  </form>

                  <div className="my-6 flex items-center">
                    <div className="flex-grow border-t border-slate-600"></div>
                    <span className="mx-4 text-slate-400 text-sm">OU</span>
                    <div className="flex-grow border-t border-slate-600"></div>
                  </div>

                  <Button 
                    variant="outline" 
                    className="w-full bg-slate-700 hover:bg-slate-600 border-slate-600 text-slate-100 font-semibold py-3 text-base flex items-center justify-center space-x-2" 
                    onClick={handleGoogleSignUp}
                    disabled={loading || googleLoading}
                  >
                    <ChromeIcon className="h-5 w-5" /> 
                    <span>{googleLoading ? 'Inscription avec Google...' : "S'inscrire avec Google"}</span>
                  </Button>
                </>
              )}
            </CardContent>
            {!successMessage && (
              <CardFooter className="flex flex-col items-center space-y-3 pt-6">
                <p className="text-sm text-slate-400">
                  Déjà un compte ?{' '}
                  <Link to="/connexion" className="text-green-400 hover:text-green-300 hover:underline">
                    Se connecter
                  </Link>
                </p>
              </CardFooter>
            )}
          </Card>
        </div>
      );
    };

    export default SignUpPage;
