import { useCallback } from 'react';
import { useUser } from '@/contexts/UserContext';
import { Permission, ROLE_PERMISSIONS, Role } from '@/constants/permissions'; // Corrected import name

export const usePermissions = () => {
  const { profile: userProfile, isLoadingAuth } = useUser();

  const currentRole = userProfile?.role || null;

  const can = useCallback(
    (permissionToCheck: Permission): boolean => {
      if (isLoadingAuth || !userProfile || !userProfile.role) {
        return false;
      }

      // SUPER_ADMIN has all permissions
      if (userProfile.role === 'SUPER_ADMIN') {
        return true; 
      }

      const userPermissions = ROLE_PERMISSIONS[userProfile.role as Role]; // Corrected usage
      
      if (!userPermissions) {
        console.warn(`No permissions defined for role: ${userProfile.role}`);
        return false;
      }
      
      return userPermissions.includes(permissionToCheck);
    },
    [isLoadingAuth, userProfile]
  );

  return { 
    can, 
    currentRole,
    isLoading: isLoadingAuth // isLoading can represent permission loading readiness
  };
};
