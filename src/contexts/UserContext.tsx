import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { supabase } from '@/lib/supabaseClient';
import { Session, User } from '@supabase/supabase-js';

// Define the structure of the profile data we expect
export interface Profile {
  id: string;
  username: string | null;
  full_name: string | null;
  avatar_url: string | null;
  status: 'pending_approval' | 'approved' | 'rejected' | null;
  role: 'USER' | 'ADMIN' | 'MODERATOR' | 'SUPER_ADMIN' | null; // Changed to uppercase
}

interface UserContextType {
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  isLoadingAuth: boolean;
  signOut: () => Promise<void>;
}

// Create a unique sentinel object to use as a default value
const UNINITIALIZED_SENTINEL = {} as UserContextType;

const UserContext = createContext<UserContextType>(UNINITIALIZED_SENTINEL);

export const UserProvider = ({ children }: { children: ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoadingAuth, setIsLoadingAuth] = useState(true); // Start true
  const [lastAuthEvent, setLastAuthEvent] = useState<string | null>(null);

  // Memoized profile fetching logic
  const fetchProfile = useCallback(async (userId: string): Promise<Profile | null> => {
    console.log(`[UserProvider] fetchProfile: Called for user ID: ${userId}`);
    
    const queryPromise = supabase
      .from('profiles')
      .select('id, username, full_name, avatar_url, status, role')
      .eq('id', userId)
      .single();

    const timeoutPromise = new Promise<never>((_, reject) => 
      setTimeout(() => reject(new Error('Supabase query timed out after 10 seconds')), 10000)
    );

    try {
      console.log(`[UserProvider] fetchProfile: Attempting Supabase query for user ${userId} with 10s timeout...`);
      const result = await Promise.race([queryPromise, timeoutPromise]);
      const { data, error, status } = result;

      console.log(`[UserProvider] fetchProfile: Supabase query responded for user ${userId}. Status: ${status}, Error: ${error ? error.message : 'null'}, HasData: ${!!data}`);
      
      if (error && status !== 406) { // 406 for .single() means no rows, not necessarily a system error
        console.error(`[UserProvider] fetchProfile: Error fetching profile for user ${userId}: ${error.message}. Status: ${status}`);
        return null;
      }
      
      console.log(`[UserProvider] fetchProfile: Raw profile data from Supabase for user ${userId}:`, data);

      if (!data) {
        console.warn(`[UserProvider] fetchProfile: Profile not found for user ID ${userId}.`);
        return null;
      }

      // Ensure role is one of the expected uppercase values
      const validRoles: Array<Profile['role']> = ['USER', 'ADMIN', 'MODERATOR', 'SUPER_ADMIN', null];
      if (typeof data.status === 'undefined' || typeof data.role === 'undefined' || !validRoles.includes(data.role as Profile['role'])) {
        console.warn(`[UserProvider] fetchProfile: Profile data for user ID ${userId} is incomplete or role is invalid. Data:`, data);
        // Optionally, you could default the role or handle this more gracefully
        // For now, returning null if role is not as expected to highlight issues.
        if (!validRoles.includes(data.role as Profile['role'])) {
            console.error(`[UserProvider] fetchProfile: Invalid role "${data.role}" received for user ${userId}. Expected one of ${validRoles.join(', ')}.`);
        }
        return null; 
      }
      
      console.log(`[UserProvider] fetchProfile: Profile fetched and validated for user ${userId}:`, data);
      return data as Profile;
    } catch (e: any) {
      if (e.message && e.message.includes('timed out')) {
        console.error(`[UserProvider] fetchProfile: Supabase query for user ${userId} explicitly TIMED OUT. ${e.message}`);
      } else {
        console.error(`[UserProvider] fetchProfile: Exception during fetchProfile for user ${userId}: ${e.message}`, e);
      }
      return null;
    }
  }, []); // fetchProfile is stable

  // Effect 1: Setup onAuthStateChange listener
  useEffect(() => {
    // No need to set isLoadingAuth here, SessionProcessingEffect will manage it based on lastAuthEvent
    console.log('[UserProvider] AuthListenerEffect: Setting up onAuthStateChange listener.');
    let isActive = true;

    const { data: authListener } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        if (!isActive) {
          console.log('[UserProvider] onAuthStateChange: Stale listener, aborting.');
          return;
        }
        console.log(`[UserProvider] onAuthStateChange: Event: ${_event}, New Session User: ${newSession?.user?.id ?? 'null'}`);
        setSession(newSession);
        setUser(newSession?.user ?? null);
        setLastAuthEvent(_event); 
      }
    );

    return () => {
      isActive = false;
      authListener?.subscription.unsubscribe();
      console.log('[UserProvider] AuthListenerEffect: Cleaned up auth listener.');
    };
  }, []); // Empty dependency array: runs once on mount

  // Effect 2: Process session changes (fetch profile if needed)
  useEffect(() => {
    const processSessionChange = async () => {
      // If lastAuthEvent is null, it means onAuthStateChange hasn't fired its first event.
      // In this case, we are still loading, so keep isLoadingAuth true.
      if (lastAuthEvent === null) {
        console.log('[UserProvider] SessionProcessingEffect: lastAuthEvent is null, initial auth state not yet determined. isLoadingAuth remains true.');
        setIsLoadingAuth(true); // Explicitly ensure it's true
        return;
      }

      if (!session?.user) {
        console.log(`[UserProvider] SessionProcessingEffect: No user in session (lastAuthEvent: ${lastAuthEvent}). Clearing profile.`);
        setProfile(null);
        setIsLoadingAuth(false); // Auth check complete, no user.
        return;
      }

      const userId = session.user.id;
      console.log(`[UserProvider] SessionProcessingEffect: User ${userId} detected. LastAuthEvent: ${lastAuthEvent}. Current profile ID: ${profile?.id}`);

      const profileIsMissing = !profile;
      const profileIsForDifferentUser = profile?.id !== userId;
      const userWasJustUpdated = lastAuthEvent === 'USER_UPDATED';
      const initialSessionOrSignedIn = lastAuthEvent === 'INITIAL_SESSION' || lastAuthEvent === 'SIGNED_IN';
      
      const shouldFetchProfile = (initialSessionOrSignedIn && (profileIsMissing || profileIsForDifferentUser)) || userWasJustUpdated;

      if (shouldFetchProfile) {
        console.log(`[UserProvider] SessionProcessingEffect: Fetching profile for user ${userId}. Initial/SignedIn: ${initialSessionOrSignedIn}, Missing: ${profileIsMissing}, DifferentUser: ${profileIsForDifferentUser}, UserUpdated: ${userWasJustUpdated}`);
        setIsLoadingAuth(true); 
        const fetchedProfileData = await fetchProfile(userId);
        setProfile(fetchedProfileData);
        setIsLoadingAuth(false); 
        console.log(`[UserProvider] SessionProcessingEffect: Profile fetch for ${userId} ${fetchedProfileData ? 'succeeded' : 'failed/timed out'}. isLoadingAuth is false.`);
      } else {
        console.log(`[UserProvider] SessionProcessingEffect: Profile for user ${userId} is current or no need to fetch. isLoadingAuth is false.`);
        setIsLoadingAuth(false); 
      }
    };
    
    processSessionChange();

  }, [session, lastAuthEvent, fetchProfile, profile?.id]);

  const signOut = async () => {
    console.log('[UserProvider] signOut called.');
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error('[UserProvider] Error signing out:', error);
    }
    // onAuthStateChange will trigger SessionProcessingEffect to clear profile and set loading states.
  };

  const value = {
    session,
    user,
    profile,
    isLoadingAuth,
    signOut,
  };

  return <UserContext.Provider value={value}>{children}</UserContext.Provider>;
};

export const useUser = () => {
  const context = useContext(UserContext);
  if (context === UNINITIALIZED_SENTINEL) { 
    console.error("[UserContext] 'useUser' was called outside of a UserProvider or context is uninitialized (using sentinel).");
    throw new Error('useUser must be used within a UserProvider (sentinel check)');
  }
  return context;
};
