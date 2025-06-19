import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Loader2, Edit, Save, XCircle, UserCircle, Mail, CalendarDays, ShieldCheck, Info, Settings, Activity } from 'lucide-react';
import { useEffect, useState, FormEvent } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Profile } from '@/contexts/UserContext';
import { toast } from 'sonner';

interface ProfileFormData {
  full_name: string;
  avatar_url: string;
  biography: string;
  signature: string;
}

const ProfilePage = () => {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const { profile: currentUserProfile, isLoadingAuth: isLoadingCurrentUserAuth, authUser, session } = useAuth();
  
  const [profileData, setProfileData] = useState<Profile | null>(null);
  const [isLoadingProfile, setIsLoadingProfile] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [formData, setFormData] = useState<ProfileFormData>({
    full_name: '',
    avatar_url: '',
    biography: '',
    signature: '',
  });

  const fetchProfile = async (id: string) => {
    setIsLoadingProfile(true);
    setError(null);
    try {
      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('id, username, full_name, avatar_url, status, role, biography, signature, created_at')
        .eq('id', id)
        .single();

      if (fetchError) {
        console.error("Error fetching profile:", fetchError);
        setError(`Erreur lors de la récupération du profil: ${fetchError.message}`);
        setProfileData(null);
      } else {
        setProfileData(data as Profile);
        // Initialize form data if this is the current user's profile being fetched
        if (data && authUser?.id === data.id) {
          setFormData({
            full_name: data.full_name || '',
            avatar_url: data.avatar_url || '',
            biography: data.biography || '',
            signature: data.signature || '',
          });
        }
      }
    } catch (e: any) {
      console.error("Exception fetching profile:", e);
      setError(`Une erreur inattendue est survenue: ${e.message}`);
      setProfileData(null);
    } finally {
      setIsLoadingProfile(false);
    }
  };
  
  useEffect(() => {
    if (!userId) {
      setError("ID d'utilisateur manquant.");
      setIsLoadingProfile(false);
      navigate('/404'); // Or some other appropriate action
      return;
    }

    // If viewing own profile and current user's profile is loaded from context, use it
    if (userId === authUser?.id && currentUserProfile) {
      setProfileData(currentUserProfile);
      setFormData({
        full_name: currentUserProfile.full_name || '',
        avatar_url: currentUserProfile.avatar_url || '',
        biography: currentUserProfile.biography || '',
        signature: currentUserProfile.signature || '',
      });
      setIsLoadingProfile(false);
    } else {
      // Otherwise, fetch the profile for the given userId
      fetchProfile(userId);
    }
  }, [userId, authUser?.id, currentUserProfile, navigate]);


  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleEditToggle = () => {
    if (isEditing) { // If cancelling edit
      // Reset form data to profile data
      if (profileData) {
        setFormData({
          full_name: profileData.full_name || '',
          avatar_url: profileData.avatar_url || '',
          biography: profileData.biography || '',
          signature: profileData.signature || '',
        });
      }
    }
    setIsEditing(!isEditing);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!profileData || !authUser || authUser.id !== profileData.id) return;

    setIsSaving(true);
    const updates = {
      id: authUser.id,
      full_name: formData.full_name,
      avatar_url: formData.avatar_url,
      biography: formData.biography,
      signature: formData.signature,
      updated_at: new Date().toISOString(),
    };

    try {
      const { error: updateError } = await supabase.from('profiles').upsert(updates);

      if (updateError) {
        throw updateError;
      }
      
      // Update local profileData state immediately for responsiveness
      setProfileData(prev => prev ? { ...prev, ...updates } : null);
      // Also update currentUserProfile in context if possible, or trigger a refetch
      // For simplicity, we'll rely on next context fetch or page reload for full sync
      // Or, more directly:
      if (currentUserProfile && currentUserProfile.id === authUser.id) {
         // This is tricky because useAuth doesn't provide a setter for profile
         // A full refetch of the profile might be better or a global state management solution
         // For now, local state update is fine, context will catch up on next load/event
      }

      toast.success('Profil mis à jour avec succès!');
      setIsEditing(false);
    } catch (error: any) {
      console.error('Error updating profile:', error);
      toast.error(`Erreur lors de la mise à jour du profil: ${error.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const isLoading = isLoadingCurrentUserAuth || isLoadingProfile;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <Loader2 className="h-12 w-12 animate-spin text-primary" />
        <p className="ml-3 text-lg">Chargement du profil...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-10">
        <h2 className="text-2xl font-semibold text-red-600 dark:text-red-400">Erreur</h2>
        <p className="text-gray-600 dark:text-gray-300">{error}</p>
      </div>
    );
  }

  if (!profileData) {
    return (
      <div className="text-center py-10">
        <h2 className="text-2xl font-semibold">Profil introuvable</h2>
        <p className="text-gray-600 dark:text-gray-300">L'utilisateur avec l'ID {userId} n'a pas été trouvé.</p>
      </div>
    );
  }

  const canEdit = authUser?.id === profileData.id;
  const registrationDate = profileData.created_at ? new Date(profileData.created_at).toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' }) : 'N/A';
  const userEmail = (authUser?.id === profileData.id) ? authUser.email : 'Non disponible';


  return (
    <div className="container mx-auto py-8 px-4 md:px-6 min-h-screen bg-gradient-to-br from-slate-50 to-gray-100 dark:from-slate-900 dark:to-gray-800">
      <Card className="max-w-3xl mx-auto dark:bg-gray-850 shadow-xl rounded-xl overflow-hidden">
        <CardHeader className="bg-gray-100 dark:bg-gray-800 p-6 border-b dark:border-gray-700">
          <div className="flex flex-col sm:flex-row items-center space-y-4 sm:space-y-0 sm:space-x-6">
            <Avatar className="w-28 h-28 sm:w-32 sm:h-32 border-4 border-primary dark:border-primary-dark ring-2 ring-primary-focus dark:ring-primary-dark-focus shadow-lg">
              <AvatarImage src={isEditing ? formData.avatar_url : profileData.avatar_url || undefined} alt={profileData.username || profileData.full_name || 'User Avatar'} />
              <AvatarFallback className="text-4xl bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300">
                {(profileData.username || profileData.full_name || 'U').charAt(0).toUpperCase()}
              </AvatarFallback>
            </Avatar>
            <div className="text-center sm:text-left">
              <CardTitle className="text-3xl font-bold text-gray-800 dark:text-white">{profileData.username || 'Utilisateur Anonyme'}</CardTitle>
              {isEditing ? (
                <Input
                  name="full_name"
                  value={formData.full_name}
                  onChange={handleInputChange}
                  placeholder="Nom complet"
                  className="mt-1 text-lg"
                />
              ) : (
                <CardDescription className="text-xl text-primary dark:text-primary-light mt-1">{profileData.full_name || 'Nom non spécifié'}</CardDescription>
              )}
              <div className="text-sm text-gray-500 dark:text-gray-400 mt-2">
                <p className="flex items-center justify-center sm:justify-start"><ShieldCheck className="w-4 h-4 mr-1.5 text-green-500" />Rôle: <span className="font-medium ml-1">{profileData.role || 'Utilisateur'}</span></p>
                <p className="flex items-center justify-center sm:justify-start mt-1"><CalendarDays className="w-4 h-4 mr-1.5 text-blue-500" />Membre depuis: {registrationDate}</p>
              </div>
            </div>
            {canEdit && !isEditing && (
              <Button onClick={handleEditToggle} className="sm:ml-auto bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white px-6 py-2 rounded-lg shadow-md transition-transform duration-150 hover:scale-105">
                <Edit className="mr-2 h-5 w-5" />
                Modifier
              </Button>
            )}
          </div>
        </CardHeader>
        
        <CardContent className="p-6 space-y-8">
          {isEditing && canEdit && (
            <form onSubmit={handleSubmit} className="space-y-6 bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
              <div>
                <Label htmlFor="avatar_url" className="text-sm font-medium text-gray-700 dark:text-gray-300">URL de l'avatar</Label>
                <Input
                  id="avatar_url"
                  name="avatar_url"
                  type="url"
                  value={formData.avatar_url}
                  onChange={handleInputChange}
                  placeholder="https://example.com/avatar.png"
                  className="mt-1"
                />
              </div>
              <div>
                <Label htmlFor="biography" className="text-sm font-medium text-gray-700 dark:text-gray-300">Biographie</Label>
                <Textarea
                  id="biography"
                  name="biography"
                  value={formData.biography}
                  onChange={handleInputChange}
                  placeholder="Parlez-nous un peu de vous..."
                  rows={4}
                  className="mt-1"
                />
              </div>
              <div>
                <Label htmlFor="signature" className="text-sm font-medium text-gray-700 dark:text-gray-300">Signature (forum)</Label>
                <Input
                  id="signature"
                  name="signature"
                  value={formData.signature}
                  onChange={handleInputChange}
                  placeholder="Votre signature pour les messages du forum"
                  className="mt-1"
                />
              </div>
              <div className="flex items-center justify-end space-x-3 pt-4 border-t dark:border-gray-700">
                <Button type="button" variant="outline" onClick={handleEditToggle} disabled={isSaving} className="px-6 py-2 rounded-lg">
                  <XCircle className="mr-2 h-5 w-5" />
                  Annuler
                </Button>
                <Button type="submit" disabled={isSaving} className="bg-green-600 hover:bg-green-700 dark:bg-green-500 dark:hover:bg-green-600 text-white px-6 py-2 rounded-lg shadow-md transition-transform duration-150 hover:scale-105">
                  {isSaving ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : <Save className="mr-2 h-5 w-5" />}
                  Enregistrer
                </Button>
              </div>
            </form>
          )}

          {!isEditing && (
            <>
              <div className="space-y-3">
                <h3 className="text-lg font-semibold text-gray-700 dark:text-gray-300 flex items-center"><UserCircle className="w-5 h-5 mr-2 text-indigo-500" />Informations Personnelles</h3>
                <div className="pl-7 space-y-1 text-gray-600 dark:text-gray-400">
                  <p><strong className="font-medium text-gray-700 dark:text-gray-300">Nom d'utilisateur:</strong> {profileData.username}</p>
                  <p><strong className="font-medium text-gray-700 dark:text-gray-300">Nom complet:</strong> {profileData.full_name || 'Non spécifié'}</p>
                  <p className="flex items-center"><Mail className="w-4 h-4 mr-1.5 text-gray-500" /> <strong className="font-medium text-gray-700 dark:text-gray-300">Email:</strong> {userEmail} {canEdit && <em className="text-xs ml-2">(La modification de l'email sera bientôt disponible)</em>}</p>
                </div>
              </div>

              <div className="space-y-3">
                <h3 className="text-lg font-semibold text-gray-700 dark:text-gray-300 flex items-center"><Info className="w-5 h-5 mr-2 text-teal-500" />À Propos</h3>
                <div className="pl-7 space-y-2 text-gray-600 dark:text-gray-400">
                  <p><strong className="font-medium text-gray-700 dark:text-gray-300">Biographie:</strong></p>
                  <p className="italic whitespace-pre-wrap">{profileData.biography || 'Aucune biographie fournie.'}</p>
                  <p><strong className="font-medium text-gray-700 dark:text-gray-300 mt-2">Signature (forum):</strong></p>
                  <p className="italic">{profileData.signature || 'Aucune signature fournie.'}</p>
                </div>
              </div>
            </>
          )}
          
          <div className="mt-8 pt-6 border-t dark:border-gray-700">
            <h3 className="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center"><Activity className="w-6 h-6 mr-2 text-purple-500" />Activité Récente</h3>
            <div className="p-4 bg-gray-50 dark:bg-gray-750 rounded-lg text-center">
              <p className="text-gray-500 dark:text-gray-400 italic">L'affichage de l'activité récente sera bientôt disponible.</p>
              {/* Placeholder for activity items */}
            </div>
          </div>

          <div className="mt-8 pt-6 border-t dark:border-gray-700">
            <h3 className="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-3 flex items-center"><Settings className="w-6 h-6 mr-2 text-orange-500" />Préférences du Compte</h3>
            <div className="p-4 bg-gray-50 dark:bg-gray-750 rounded-lg text-center">
              <p className="text-gray-500 dark:text-gray-400 italic">La gestion des préférences du compte sera bientôt disponible.</p>
              {/* Placeholder for preference settings */}
            </div>
          </div>

        </CardContent>
      </Card>
    </div>
  );
};

export default ProfilePage;
