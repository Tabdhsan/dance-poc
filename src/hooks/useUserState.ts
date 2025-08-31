// Custom hooks for managing user state and preferences
import { useCallback } from 'react';
import { useUser } from '@/contexts/UserContext';
import { usePreferences } from '@/contexts/PreferencesContext';
import type { UserRole, DanceClass } from '@/types/ui.types';  

/**
 * Hook for managing user state and role switching
 */
export const useUserState = () => {
  const { state: userState, switchUserRole, switchUser, refreshUsers } = useUser();
  const { updateCurrentUser } = usePreferences();

  // Switch user role and update preferences
  const handleRoleSwitch = useCallback((role: UserRole) => {
    switchUserRole(role);
  }, [switchUserRole]);

  // Switch to different user and update preferences
  const handleUserSwitch = useCallback((userId: string) => {
    switchUser(userId);
    updateCurrentUser(userId);
  }, [switchUser, updateCurrentUser]);

  // Check if current user is a choreographer
  const isChoreographer = useCallback(() => {
    return userState.currentUser?.role === 'choreographer' || userState.currentUser?.role === 'both';
  }, [userState.currentUser]);

  // Check if current user is a dancer
  const isDancer = useCallback(() => {
    return userState.currentUser?.role === 'dancer' || userState.currentUser?.role === 'both';
  }, [userState.currentUser]);

  // Get current user's classes (if choreographer)
  const getCurrentUserClasses = useCallback((allClasses: DanceClass[]) => {
    if (!userState.currentUser || !isChoreographer()) return [];
    return allClasses.filter(cls => cls.choreographerId === userState.currentUser!.id);
  }, [userState.currentUser, isChoreographer]);

  return {
    currentUser: userState.currentUser,
    users: userState.users,
    loading: userState.loading,
    error: userState.error,
    switchRole: handleRoleSwitch,
    switchUser: handleUserSwitch,
    refreshUsers,
    isChoreographer,
    isDancer,
    getCurrentUserClasses
  };
};
/**
 
* Hook for managing class preferences (interested/attending)
 */
export const useClassPreferences = () => {
  const { 
    state: preferencesState, 
    toggleClassInterest, 
    toggleClassAttending,
    isClassInterested,
    isClassAttending 
  } = usePreferences();

  // Get interested classes
  const getInterestedClasses = useCallback((allClasses: DanceClass[]) => {
    return allClasses.filter(cls => 
      preferencesState.userPreferences.interestedClasses.includes(cls.id)
    );
  }, [preferencesState.userPreferences.interestedClasses]);

  // Get attending classes
  const getAttendingClasses = useCallback((allClasses: DanceClass[]) => {
    return allClasses.filter(cls => 
      preferencesState.userPreferences.attendingClasses.includes(cls.id)
    );
  }, [preferencesState.userPreferences.attendingClasses]);

  // Toggle interest with callback
  const handleToggleInterest = useCallback((classId: string, onToggle?: (isInterested: boolean) => void) => {
    const newStatus = toggleClassInterest(classId);
    onToggle?.(newStatus);
    return newStatus;
  }, [toggleClassInterest]);

  // Toggle attending with callback
  const handleToggleAttending = useCallback((classId: string, onToggle?: (isAttending: boolean) => void) => {
    const newStatus = toggleClassAttending(classId);
    onToggle?.(newStatus);
    return newStatus;
  }, [toggleClassAttending]);

  return {
    interestedClasses: preferencesState.userPreferences.interestedClasses,
    attendingClasses: preferencesState.userPreferences.attendingClasses,
    getInterestedClasses,
    getAttendingClasses,
    toggleInterest: handleToggleInterest,
    toggleAttending: handleToggleAttending,
    isInterested: isClassInterested,
    isAttending: isClassAttending
  };
};

/**
 * Hook for managing choreographer favorites
 */
export const useChoreographerPreferences = () => {
  const { 
    state: preferencesState, 
    toggleChoreographerFavorite,
    isChoreographerFavorited 
  } = usePreferences();

  // Toggle favorite with callback
  const handleToggleFavorite = useCallback((choreographerId: string, onToggle?: (isFavorited: boolean) => void) => {
    const newStatus = toggleChoreographerFavorite(choreographerId);
    onToggle?.(newStatus);
    return newStatus;
  }, [toggleChoreographerFavorite]);

  return {
    favoritedChoreographers: preferencesState.userPreferences.favoritedChoreographers,
    toggleFavorite: handleToggleFavorite,
    isFavorited: isChoreographerFavorited
  };
};

/**
 * Hook for managing app settings
 */
export const useAppSettings = () => {
  const { 
    state: preferencesState, 
    updatePreferredView, 
    updateFilters 
  } = usePreferences();

  // Update view with persistence
  const handleViewChange = useCallback((view: 'list' | 'calendar') => {
    updatePreferredView(view);
  }, [updatePreferredView]);

  // Update filters with persistence
  const handleFiltersChange = useCallback((filters: typeof preferencesState.appSettings.filters) => {
    updateFilters(filters);
  }, [updateFilters]);

  return {
    preferredView: preferencesState.appSettings.preferredView,
    filters: preferencesState.appSettings.filters,
    updateView: handleViewChange,
    updateFilters: handleFiltersChange
  };
};

/**
 * Combined hook for all user-related state management
 */
export const useUserManagement = () => {
  const userState = useUserState();
  const classPreferences = useClassPreferences();
  const choreographerPreferences = useChoreographerPreferences();
  const appSettings = useAppSettings();
  const { clearAllData } = usePreferences();

  return {
    ...userState,
    ...classPreferences,
    ...choreographerPreferences,
    ...appSettings,
    clearAllData
  };
};