import { useCallback } from 'react';
import { useUser } from '@/contexts/UserContext';
import { Permission, RolePermissions, Role } from '@/constants/permissions'; // Ensure this path is correct

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

      const userPermissions = RolePermissions[userProfile.role as Role]; // Cast because role from DB might not be strictly typed yet
      
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
