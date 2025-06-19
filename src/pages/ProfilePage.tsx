import { useParams } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Loader2, Edit } from 'lucide-react'; // Added Edit icon
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabaseClient'; // For fetching other user's profile
import { Profile } from '@/contexts/UserContext'; // Import Profile type

const ProfilePage = () => {
  const { userId } = useParams<{ userId: string }>();
  const { profile: currentUserProfile, isLoadingAuth: isLoadingCurrentUserAuth, authUser } = useAuth();
  
  const [profileData, setProfileData] = useState<Profile | null>(null);
  const [isLoadingProfile, setIsLoadingProfile] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchProfile = async () => {
      if (!userId) {
        setError("ID d'utilisateur manquant.");
        setIsLoadingProfile(false);
        return;
      }

      // If viewing own profile and current user's profile is loaded, use it
      if (userId === authUser?.id && currentUserProfile) {
        setProfileData(currentUserProfile);
        setIsLoadingProfile(false);
        return;
      }
      
      // Otherwise, fetch the profile for the given userId
      setIsLoadingProfile(true);
      setError(null);
      try {
        const { data, error: fetchError } = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, status, role') // Add created_at if you have it
          .eq('id', userId)
          .single();

        if (fetchError) {
          console.error("Error fetching profile:", fetchError);
          setError(`Erreur lors de la récupération du profil: ${fetchError.message}`);
          setProfileData(null);
        } else {
          setProfileData(data as Profile);
        }
      } catch (e: any) {
        console.error("Exception fetching profile:", e);
        setError(`Une erreur inattendue est survenue: ${e.message}`);
        setProfileData(null);
      } finally {
        setIsLoadingProfile(false);
      }
    };

    if (!isLoadingCurrentUserAuth) { // Only fetch if current user auth state is resolved
        fetchProfile();
    }
  }, [userId, authUser?.id, currentUserProfile, isLoadingCurrentUserAuth]);

  const isLoading = isLoadingCurrentUserAuth || isLoadingProfile;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full py-10">
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
  // const registrationDate = profileData.created_at ? new Date(profileData.created_at).toLocaleDateString() : 'N/A';

  return (
    <div className="container mx-auto py-8 px-4 md:px-6">
      <Card className="max-w-2xl mx-auto dark:bg-gray-800 shadow-lg rounded-lg">
        <CardHeader className="text-center border-b dark:border-gray-700 pb-6">
          <Avatar className="w-28 h-28 mx-auto mb-4 border-4 border-primary ring-2 ring-primary-focus shadow-md">
            <AvatarImage src={profileData.avatar_url || undefined} alt={profileData.username || profileData.full_name || 'User Avatar'} />
            <AvatarFallback className="text-3xl">{(profileData.username || profileData.full_name || 'U').charAt(0).toUpperCase()}</AvatarFallback>
          </Avatar>
          <CardTitle className="text-3xl font-bold text-gray-800 dark:text-white">{profileData.username || profileData.full_name || 'Utilisateur Anonyme'}</CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-400">
            {/* Membre depuis {registrationDate} - Rôle: {profileData.role} */}
            Rôle: <span className="font-medium">{profileData.role}</span>
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6 p-6">
          <div>
            <h3 className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-1">Biographie</h3>
            <p className="text-gray-600 dark:text-gray-400 italic">
              {/* TODO: Add biography field to profiles table and display here */}
              Biographie non encore disponible. L'utilisateur pourra bientôt l'ajouter.
            </p>
          </div>
          
          {canEdit && (
            <Button className="w-full mt-6 bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 text-white">
              <Edit className="mr-2 h-4 w-4" />
              Modifier le profil
            </Button>
          )}

          <div className="mt-8 pt-6 border-t dark:border-gray-700">
            <h3 className="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-3">Activité Récente</h3>
            <div className="space-y-4">
              <p className="text-gray-500 dark:text-gray-400 italic">L'affichage de l'activité récente sera bientôt disponible.</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default ProfilePage;
