// Core TypeScript interfaces for the Dance Class Management App
// Updated to ensure proper exports

export interface SocialLinks {
    instagram?: string;
    tiktok?: string;
    youtube?: string;
    website?: string;
  }
  
  export interface User {
    id: string;
    name: string;
    role: 'dancer' | 'choreographer' | 'both';
    pronouns?: string;
    bio?: string;
    profilePhoto?: string;
    website?: string;
    socialLinks?: SocialLinks;
    featuredVideo?: string;
    achievements?: string[];
    teachingStyle?: string;
    upcomingClasses?: string[];
  }
  
  export interface Choreographer extends User {
    // Add choreographer-specific fields here if needed in the future
  }
  
  export interface DanceClass {
    id: string;
    title: string;
    choreographerId: string;
    choreographerName: string;
    style: string[];
    dateTime: string;
    location: string;
    description: string;
    price?: number;
    videoLink?: string;
    rsvpLink?: string;
    flyer?: string;
    status: 'active' | 'cancelled' | 'featured';
  }
  
  export interface UserPreferences {
    currentUserId: string;
    interestedClasses: string[];
    attendingClasses: string[];
    favoritedChoreographers: string[];
  }
  
  export interface AppSettings {
    preferredView: 'list' | 'calendar';
    filters: {
      styles: string[];
      choreographers: string[];
      studios: string[];
      dateRange?: {
        start: string;
        end: string;
      };
    };
  }
  
  export interface AppState {
    currentUser: User;
    userPreferences: UserPreferences;
    classes: DanceClass[];
    choreographers: User[];
    settings: AppSettings;
  }
  
  // API response types for mock data
  export interface ClassesResponse {
    classes: DanceClass[];
  }
  
  export interface UsersResponse {
    users: User[];
  }
  
  export interface ChoreographersResponse {
    choreographers: User[];
  }
  
  // Component prop types
  export interface ClassCardProps {
    danceClass: DanceClass;
    isInterested?: boolean;
    isAttending?: boolean;
    onInterestToggle?: (classId: string) => void;
    onAttendingToggle?: (classId: string) => void;
    onChoreographerClick?: (choreographerId: string) => void;
    onViewDetails?: (danceClass: DanceClass) => void;
  }
  
  export interface FilterOptions {
    styles: string[];
    choreographers: string[];
    studios: string[];
    dateRange?: {
      start: Date;
      end: Date;
    };
  }
  
  // Utility types
  export type UserRole = User['role'];
  export type ClassStatus = DanceClass['status'];
  export type ViewMode = AppSettings['preferredView'];