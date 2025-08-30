export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.4"
  }
  public: {
    Tables: {
      audit_logs: {
        Row: {
          created_at: string
          id: string
          new_values: Json | null
          old_values: Json | null
          operation: string
          operation_context: Json | null
          record_id: string
          table_name: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          new_values?: Json | null
          old_values?: Json | null
          operation: string
          operation_context?: Json | null
          record_id: string
          table_name: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          new_values?: Json | null
          old_values?: Json | null
          operation?: string
          operation_context?: Json | null
          record_id?: string
          table_name?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      choreographer_follows: {
        Row: {
          created_at: string
          followed_choreographer_id: string
          follower_user_id: string
        }
        Insert: {
          created_at?: string
          followed_choreographer_id: string
          follower_user_id: string
        }
        Update: {
          created_at?: string
          followed_choreographer_id?: string
          follower_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "choreographer_follows_followed_choreographer_id_fkey"
            columns: ["followed_choreographer_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "choreographer_follows_followed_choreographer_id_fkey"
            columns: ["followed_choreographer_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "choreographer_follows_follower_user_id_fkey"
            columns: ["follower_user_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "choreographer_follows_follower_user_id_fkey"
            columns: ["follower_user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      choreographer_profiles: {
        Row: {
          bio: string | null
          created_at: string
          deleted_at: string | null
          display_name: string
          profile_picture_url: string | null
          social_links: Json | null
          updated_at: string
          url_slug: string | null
          user_id: string
          view_count: number
        }
        Insert: {
          bio?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name: string
          profile_picture_url?: string | null
          social_links?: Json | null
          updated_at?: string
          url_slug?: string | null
          user_id: string
          view_count?: number
        }
        Update: {
          bio?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name?: string
          profile_picture_url?: string | null
          social_links?: Json | null
          updated_at?: string
          url_slug?: string | null
          user_id?: string
          view_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "choreographer_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "choreographer_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      class_watchlists: {
        Row: {
          class_id: string
          created_at: string
          user_id: string
        }
        Insert: {
          class_id: string
          created_at?: string
          user_id: string
        }
        Update: {
          class_id?: string
          created_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "class_watchlists_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "active_classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_watchlists_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_watchlists_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_watchlists_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          booking_url: string | null
          borough: string
          choreographer_id: string
          choreographer_note: string | null
          class_timestamp: string
          created_at: string
          deleted_at: string | null
          description: string | null
          id: string
          location_name: string
          price: number | null
          skill_level: string
          style: string
          title: string
          updated_at: string
          view_count: number
        }
        Insert: {
          booking_url?: string | null
          borough: string
          choreographer_id: string
          choreographer_note?: string | null
          class_timestamp: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          location_name: string
          price?: number | null
          skill_level: string
          style: string
          title: string
          updated_at?: string
          view_count?: number
        }
        Update: {
          booking_url?: string | null
          borough?: string
          choreographer_id?: string
          choreographer_note?: string | null
          class_timestamp?: string
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          location_name?: string
          price?: number | null
          skill_level?: string
          style?: string
          title?: string
          updated_at?: string
          view_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "classes_choreographer_id_fkey"
            columns: ["choreographer_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_choreographer_id_fkey"
            columns: ["choreographer_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      features: {
        Row: {
          created_at: string
          description: string | null
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          name?: string
        }
        Relationships: []
      }
      invites: {
        Row: {
          created_at: string
          deleted_at: string | null
          email: string
          expires_at: string
          id: string
          is_used: boolean
          notes: string | null
          token: string
          updated_at: string
          used_at: string | null
          used_by: string | null
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          email: string
          expires_at: string
          id?: string
          is_used?: boolean
          notes?: string | null
          token: string
          updated_at?: string
          used_at?: string | null
          used_by?: string | null
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          email?: string
          expires_at?: string
          id?: string
          is_used?: boolean
          notes?: string | null
          token?: string
          updated_at?: string
          used_at?: string | null
          used_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invites_used_by_fkey"
            columns: ["used_by"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invites_used_by_fkey"
            columns: ["used_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_tiers: {
        Row: {
          billing_interval: string | null
          created_at: string
          description: string | null
          display_name: string
          is_active: boolean
          price_cents: number
          role: string
          tier_name: string
          updated_at: string
        }
        Insert: {
          billing_interval?: string | null
          created_at?: string
          description?: string | null
          display_name: string
          is_active?: boolean
          price_cents: number
          role: string
          tier_name: string
          updated_at?: string
        }
        Update: {
          billing_interval?: string | null
          created_at?: string
          description?: string | null
          display_name?: string
          is_active?: boolean
          price_cents?: number
          role?: string
          tier_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      subscriptions: {
        Row: {
          cancelled_at: string | null
          created_at: string
          current_period_end: string | null
          current_period_start: string | null
          id: string
          status: string
          stripe_customer_id: string | null
          stripe_subscription_id: string | null
          tier_name: string
          tier_role: string
          trial_end: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          cancelled_at?: string | null
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          id?: string
          status?: string
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          tier_name: string
          tier_role: string
          trial_end?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          cancelled_at?: string | null
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          id?: string
          status?: string
          stripe_customer_id?: string | null
          stripe_subscription_id?: string | null
          tier_name?: string
          tier_role?: string
          trial_end?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_tier_role_tier_name_fkey"
            columns: ["tier_role", "tier_name"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["role", "tier_name"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      tier_features: {
        Row: {
          created_at: string
          feature_id: string
          tier_name: string
          tier_role: string
        }
        Insert: {
          created_at?: string
          feature_id: string
          tier_name: string
          tier_role: string
        }
        Update: {
          created_at?: string
          feature_id?: string
          tier_name?: string
          tier_role?: string
        }
        Relationships: [
          {
            foreignKeyName: "tier_features_feature_id_fkey"
            columns: ["feature_id"]
            isOneToOne: false
            referencedRelation: "features"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tier_features_feature_id_fkey1"
            columns: ["feature_id"]
            isOneToOne: false
            referencedRelation: "features"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tier_features_tier_role_tier_name_fkey"
            columns: ["tier_role", "tier_name"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["role", "tier_name"]
          },
        ]
      }
      users: {
        Row: {
          created_at: string
          current_subscription_id: string | null
          deleted_at: string | null
          email: string
          email_verified: boolean
          full_name: string | null
          id: string
          last_login_at: string | null
          role: string
          subscription_status: string
          tier_name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          current_subscription_id?: string | null
          deleted_at?: string | null
          email: string
          email_verified?: boolean
          full_name?: string | null
          id?: string
          last_login_at?: string | null
          role?: string
          subscription_status?: string
          tier_name?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          current_subscription_id?: string | null
          deleted_at?: string | null
          email?: string
          email_verified?: boolean
          full_name?: string | null
          id?: string
          last_login_at?: string | null
          role?: string
          subscription_status?: string
          tier_name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_current_subscription"
            columns: ["current_subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      active_choreographer_profiles: {
        Row: {
          bio: string | null
          created_at: string | null
          deleted_at: string | null
          display_name: string | null
          profile_picture_url: string | null
          social_links: Json | null
          subscription_status: string | null
          subscription_tier: string | null
          updated_at: string | null
          url_slug: string | null
          user_id: string | null
          view_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "choreographer_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "choreographer_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      active_classes: {
        Row: {
          booking_url: string | null
          borough: string | null
          choreographer_display_name: string | null
          choreographer_id: string | null
          choreographer_note: string | null
          choreographer_url_slug: string | null
          class_timestamp: string | null
          created_at: string | null
          deleted_at: string | null
          description: string | null
          id: string | null
          location_name: string | null
          price: number | null
          skill_level: string | null
          style: string | null
          subscription_status: string | null
          title: string | null
          updated_at: string | null
          view_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "classes_choreographer_id_fkey"
            columns: ["choreographer_id"]
            isOneToOne: false
            referencedRelation: "active_users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "classes_choreographer_id_fkey"
            columns: ["choreographer_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      active_users: {
        Row: {
          created_at: string | null
          current_subscription_id: string | null
          deleted_at: string | null
          email: string | null
          email_verified: boolean | null
          features: Json | null
          full_name: string | null
          id: string | null
          last_login_at: string | null
          role: string | null
          subscription_status: string | null
          tier_name: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          current_subscription_id?: string | null
          deleted_at?: string | null
          email?: string | null
          email_verified?: boolean | null
          features?: never
          full_name?: string | null
          id?: string | null
          last_login_at?: string | null
          role?: string | null
          subscription_status?: string | null
          tier_name?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          current_subscription_id?: string | null
          deleted_at?: string | null
          email?: string | null
          email_verified?: boolean | null
          features?: never
          full_name?: string | null
          id?: string | null
          last_login_at?: string | null
          role?: string | null
          subscription_status?: string | null
          tier_name?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_current_subscription"
            columns: ["current_subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_bulk_update_roles: {
        Args: {
          p_admin_user_id: string
          p_new_role: string
          p_reason?: string
          p_user_ids: string[]
        }
        Returns: Json
      }
      admin_cleanup_expired_invites: {
        Args: { p_admin_user_id: string }
        Returns: Json
      }
      admin_get_user_audit_report: {
        Args: { p_admin_user_id: string; p_limit?: number; p_user_id: string }
        Returns: {
          action: string
          actor_user_id: string
          created_at: string
          log_id: number
          meta: Json
          payload: Json
          target_id: string
          target_table: string
        }[]
      }
      admin_permanent_delete_old_records: {
        Args: {
          p_admin_user_id: string
          p_days_old?: number
          p_dry_run?: boolean
        }
        Returns: Json
      }
      admin_restore_class: {
        Args: { p_admin_user_id: string; p_class_id: string; p_reason?: string }
        Returns: Json
      }
      admin_restore_user: {
        Args: { p_admin_user_id: string; p_reason?: string; p_user_id: string }
        Returns: Json
      }
      admin_soft_delete_class: {
        Args: { p_admin_user_id: string; p_class_id: string; p_reason?: string }
        Returns: Json
      }
      admin_soft_delete_user: {
        Args: { p_admin_user_id: string; p_reason?: string; p_user_id: string }
        Returns: Json
      }
      assign_choreographer_role: {
        Args: {
          p_invite_token: string
          p_requesting_user_id: string
          p_user_id: string
        }
        Returns: Json
      }
      discover_choreographers: {
        Args: {
          p_class_styles?: string[]
          p_has_upcoming_classes?: boolean
          p_search_name?: string
        }
        Returns: {
          bio: string
          created_at: string
          display_name: string
          profile_picture_url: string
          url_slug: string
          user_id: string
        }[]
      }
      discover_classes: {
        Args: {
          p_borough?: string
          p_choreographer_id?: string
          p_from_date?: string
          p_location_name?: string
          p_search_text?: string
          p_styles?: string[]
          p_to_date?: string
        }
        Returns: {
          booking_url: string
          borough: string
          choreographer_display_name: string
          choreographer_id: string
          choreographer_note: string
          choreographer_url_slug: string
          class_timestamp: string
          created_at: string
          description: string
          id: string
          location_name: string
          price: number
          skill_level: string
          style: string
          title: string
        }[]
      }
      get_choreographer_analytics: {
        Args: { p_choreographer_id: string }
        Returns: Json
      }
      get_current_user_id: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      get_hot_choreographers: {
        Args: Record<PropertyKey, never>
        Returns: {
          bio: string
          created_at: string
          display_name: string
          profile_picture_url: string
          url_slug: string
          user_id: string
        }[]
      }
      get_hot_classes: {
        Args: { p_borough?: string; p_styles?: string[] }
        Returns: {
          booking_url: string
          borough: string
          choreographer_display_name: string
          choreographer_id: string
          choreographer_note: string
          choreographer_url_slug: string
          class_timestamp: string
          created_at: string
          description: string
          id: string
          location_name: string
          price: number
          skill_level: string
          style: string
          title: string
        }[]
      }
      get_user_features: {
        Args: { p_user_id: string }
        Returns: Json
      }
      increment_class_view_count: {
        Args: { class_uuid: string }
        Returns: undefined
      }
      increment_profile_view_count: {
        Args: { profile_user_id: string }
        Returns: undefined
      }
      is_admin: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      is_choreographer: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      update_subscription_status: {
        Args: {
          p_new_status: string
          p_stripe_subscription_id?: string
          p_user_id: string
        }
        Returns: Json
      }
      user_has_feature: {
        Args: { p_feature_name: string; p_user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
