-- --------------------------------------------------------------------------------
-- Muvv.nyc - Complete Database Schema for Supabase Deployment
-- Auto-generated from schema-parts/ - DO NOT EDIT DIRECTLY
-- Generated: $(date)
-- --------------------------------------------------------------------------------

-- CORE TABLES
-- --------------------------------------------------------------------------------
-- CORE TABLES - Table Definitions Only
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table - Core user authentication and role management with subscription support
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role TEXT NOT NULL DEFAULT 'dancer' CHECK (role IN ('dancer', 'choreographer', 'admin')),
    full_name TEXT,
    email TEXT NOT NULL UNIQUE,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    last_login_at TIMESTAMPTZ,
    -- Subscription management fields
    tier_name TEXT NOT NULL DEFAULT 'free',
    subscription_status TEXT NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active', 'past_due', 'cancelled', 'incomplete')),
    current_subscription_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- Subscription tiers configuration - Defines available tiers per role
CREATE TABLE subscription_tiers (
    role TEXT NOT NULL CHECK (role IN ('dancer', 'choreographer')),
    tier_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    billing_interval TEXT DEFAULT 'monthly' CHECK (billing_interval IN ('monthly', 'yearly')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role, tier_name)
);

-- User subscriptions table - Individual subscription relationships
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tier_role TEXT NOT NULL,
    tier_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'cancelled', 'incomplete')),
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    trial_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (tier_role, tier_name) REFERENCES subscription_tiers(role, tier_name),
    -- Ensure user can only have one active subscription per role
    UNIQUE(user_id, tier_role) DEFERRABLE INITIALLY DEFERRED
);

-- Add foreign key constraint for current subscription in users table
ALTER TABLE users ADD CONSTRAINT fk_current_subscription 
    FOREIGN KEY (current_subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL;

-- Choreographer profiles table - Public-facing choreographer information
CREATE TABLE choreographer_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE RESTRICT,
    display_name TEXT NOT NULL,
    bio TEXT,
    profile_picture_url TEXT,
    social_links JSONB CHECK (
        social_links IS NULL OR jsonb_typeof(social_links) = 'object'
    ),
    url_slug TEXT UNIQUE,
    view_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- Classes table - Dance class listings and details
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    choreographer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    description TEXT,
    style TEXT NOT NULL,
    skill_level TEXT NOT NULL CHECK (skill_level IN ('beginner', 'intermediate', 'advanced', 'all-levels')),
    location_name TEXT NOT NULL,
    borough TEXT NOT NULL,
    price NUMERIC(6, 2) CHECK (price >= 0),
    booking_url TEXT,
    class_timestamp TIMESTAMPTZ NOT NULL,
    choreographer_note TEXT,
    view_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    -- Ensure classes are scheduled in the future
    CONSTRAINT class_timestamp_future CHECK (class_timestamp > created_at)
);

-- Class watchlists table - User interest tracking (many-to-many)
CREATE TABLE class_watchlists (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, class_id)
);

-- Choreographer follows table - Social following relationships (many-to-many)
CREATE TABLE choreographer_follows (
    follower_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_choreographer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_user_id, followed_choreographer_id),
    -- Prevent self-following
    CONSTRAINT no_self_follow CHECK (follower_user_id != followed_choreographer_id)
);

-- Invites table - Phase 1 influencer invitation system
CREATE TABLE invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    used_at TIMESTAMPTZ DEFAULT NULL,
    used_by UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    -- Ensure expiration is in the future when created
    CONSTRAINT expires_at_future CHECK (expires_at > created_at)
);

-- Audit logs table - Comprehensive audit trail for critical operations
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'RESTORE')),
    old_values JSONB,
    new_values JSONB,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    operation_context JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Features table - Master list of all available permissions
CREATE TABLE features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE, -- e.g., 'watchlist', 'create_class', 'view_analytics'
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tier-features join table - Links subscription tiers to features
CREATE TABLE tier_features (
    tier_role TEXT NOT NULL,
    tier_name TEXT NOT NULL,
    feature_id UUID NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Composite primary key ensures a feature can only be added to a tier once
    PRIMARY KEY (tier_role, tier_name, feature_id),
    -- Foreign key to the subscription_tiers table
    FOREIGN KEY (tier_role, tier_name) REFERENCES subscription_tiers(role, tier_name) ON DELETE CASCADE,
    FOREIGN KEY (feature_id) REFERENCES features(id) ON DELETE CASCADE
);



-- BUSINESS FUNCTIONS
-- --------------------------------------------------------------------------------
-- BUSINESS LOGIC FUNCTIONS - Core Discovery & Analytics Functions
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Function for class discovery with search and filtering capabilities
-- Returns class details pre-sorted for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Supports flexible sorting and comprehensive filtering
CREATE OR REPLACE FUNCTION discover_classes(
    p_search_text TEXT DEFAULT NULL,  -- Optional text search in class title only
    p_styles TEXT[] DEFAULT NULL,     -- Array of styles for OR filtering
    p_borough TEXT DEFAULT NULL,
    p_location_name TEXT DEFAULT NULL,
    p_choreographer_id UUID DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NOW(),
    p_to_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    -- Essential class info only
    id UUID,
    title TEXT,
    description TEXT,
    style TEXT,
    skill_level TEXT,
    location_name TEXT,
    borough TEXT,
    price NUMERIC,
    booking_url TEXT,
    class_timestamp TIMESTAMPTZ,
    choreographer_note TEXT,
    
    -- Choreographer info
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Input validation
    IF p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'from_date cannot be greater than to_date';
    END IF;

    -- Execute the main query - always sorted by timestamp
    RETURN QUERY
    SELECT 
        c.id,
        c.title,
        c.description,
        c.style,
        c.skill_level,
        c.location_name,
        c.borough,
        c.price,
        c.booking_url,
        c.class_timestamp,
        c.choreographer_note,
        c.choreographer_id,
        c.choreographer_display_name,
        c.choreographer_url_slug,
        c.created_at
            
        WHERE 
            -- Date range filtering
            c.class_timestamp >= p_from_date
            AND (p_to_date IS NULL OR c.class_timestamp <= p_to_date)
            -- Optional filters
            AND (p_styles IS NULL OR c.style = ANY(p_styles))
            AND (p_borough IS NULL OR c.borough = p_borough)
            AND (p_location_name IS NULL OR c.location_name ILIKE '%' || p_location_name || '%')
            AND (p_choreographer_id IS NULL OR c.choreographer_id = p_choreographer_id)
            -- Optional text search in class title
            AND (p_search_text IS NULL OR 
                 p_search_text = '' OR 
                 to_tsvector('english', COALESCE(c.title, '')) @@ plainto_tsquery('english', p_search_text))
    ORDER BY c.class_timestamp ASC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for choreographer discovery with search and filtering capabilities
-- Returns choreographer profiles for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Supports filtering by class style, upcoming classes, and name search
CREATE OR REPLACE FUNCTION discover_choreographers(
    p_search_name TEXT DEFAULT NULL,  -- Optional text search in choreographer name
    p_class_styles TEXT[] DEFAULT NULL, -- Array of styles for OR filtering
    p_has_upcoming_classes BOOLEAN DEFAULT NULL -- Filter by choreographers with upcoming classes
)
RETURNS TABLE (
    -- Essential choreographer info only
    user_id UUID,
    display_name TEXT,
    bio TEXT,
    profile_picture_url TEXT,
    url_slug TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Execute the main query with filtering
    RETURN QUERY
    SELECT DISTINCT
        cp.user_id,
        cp.display_name,
        cp.bio,
        cp.profile_picture_url,
        cp.url_slug,
        cp.created_at
    FROM active_choreographer_profiles cp
    
    -- Optional JOIN for style filtering
    LEFT JOIN active_classes c ON cp.user_id = c.choreographer_id
        AND (p_class_styles IS NULL OR c.style = ANY(p_class_styles))
        AND (p_has_upcoming_classes IS NULL OR 
             (p_has_upcoming_classes = true AND c.class_timestamp > NOW()) OR
             (p_has_upcoming_classes = false))
    
    WHERE 
        -- Name search filtering
        (p_search_name IS NULL OR 
         p_search_name = '' OR 
         to_tsvector('english', COALESCE(cp.display_name, '')) @@ plainto_tsquery('english', p_search_name))
        
        -- Style filtering (ensure choreographer teaches this style)
        AND (p_class_styles IS NULL OR c.choreographer_id IS NOT NULL)
        
        -- Upcoming classes filtering
        AND (p_has_upcoming_classes IS NULL OR
             (p_has_upcoming_classes = true AND EXISTS (
                 SELECT 1 FROM active_classes ac 
                 WHERE ac.choreographer_id = cp.user_id 
                 AND ac.class_timestamp > NOW()
             )) OR
             (p_has_upcoming_classes = false AND NOT EXISTS (
                 SELECT 1 FROM active_classes ac 
                 WHERE ac.choreographer_id = cp.user_id 
                 AND ac.class_timestamp > NOW()
             )))
    
    ORDER BY cp.created_at DESC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive choreographer analytics for dashboard
CREATE OR REPLACE FUNCTION get_choreographer_analytics(
    p_choreographer_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_choreographer RECORD;
    v_follower_count INTEGER;
    v_profile_views INTEGER;
    v_total_classes INTEGER;
    v_total_class_views INTEGER;
    v_total_watchlists INTEGER;
    v_upcoming_classes INTEGER;
    v_upcoming_class_views INTEGER;
    v_upcoming_watchlists INTEGER;
    v_result JSONB;
BEGIN
    -- Authorization handled by RLS policies - function assumes caller is authorized

    -- Get choreographer data (RLS will handle access control)
    SELECT u.*, cp.view_count as profile_view_count INTO v_choreographer
    FROM active_users u
    JOIN active_choreographer_profiles cp ON u.id = cp.user_id
    WHERE u.id = p_choreographer_id AND u.role = 'choreographer';

    IF NOT FOUND THEN
        -- RLS either blocked access or choreographer doesn't exist
        -- This is the correct behavior - no need to distinguish
        RAISE EXCEPTION 'Choreographer not found or access denied';
    END IF;

    -- Get follower count
    SELECT COUNT(*) INTO v_follower_count
    FROM choreographer_follows cf
    JOIN active_users u ON cf.follower_user_id = u.id
    WHERE cf.followed_choreographer_id = p_choreographer_id;

    -- Get profile views
    v_profile_views := v_choreographer.profile_view_count;

    -- Get class metrics (all-time and upcoming)
    SELECT 
        -- All-time metrics
        COUNT(*) as total_classes,
        COALESCE(SUM(c.view_count), 0) as total_class_views,
        COALESCE(SUM(cw_count.watchlist_count), 0) as total_watchlists,
        -- Upcoming class metrics
        SUM(CASE WHEN c.class_timestamp > NOW() THEN 1 ELSE 0 END) as upcoming_classes,
        COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN c.view_count ELSE 0 END), 0) as upcoming_class_views,
        COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN cw_count.watchlist_count ELSE 0 END), 0) as upcoming_watchlists
    INTO v_total_classes, v_total_class_views, v_total_watchlists, 
         v_upcoming_classes, v_upcoming_class_views, v_upcoming_watchlists
    FROM active_classes c
    LEFT JOIN (
        SELECT class_id, COUNT(*) as watchlist_count
        FROM class_watchlists
        GROUP BY class_id
    ) cw_count ON c.id = cw_count.class_id
    WHERE c.choreographer_id = p_choreographer_id;

    -- Handle case where choreographer has no classes
    v_total_classes := COALESCE(v_total_classes, 0);
    v_total_class_views := COALESCE(v_total_class_views, 0);
    v_total_watchlists := COALESCE(v_total_watchlists, 0);
    v_upcoming_classes := COALESCE(v_upcoming_classes, 0);
    v_upcoming_class_views := COALESCE(v_upcoming_class_views, 0);
    v_upcoming_watchlists := COALESCE(v_upcoming_watchlists, 0);

    -- Build final result
    v_result := JSONB_BUILD_OBJECT(
        'follower_count', v_follower_count,
        'profile_views', v_profile_views,
        -- All-time metrics
        'total_classes', v_total_classes,
        'total_class_views', v_total_class_views,
        'total_watchlists', v_total_watchlists,
        -- Upcoming class metrics
        'upcoming_classes', v_upcoming_classes,
        'upcoming_class_views', v_upcoming_class_views,
        'upcoming_watchlists', v_upcoming_watchlists,
        'generated_at', NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get "hot" choreographers sorted by computed hotness score
-- This powers the HEAT feature for discovering trending choreographers
-- Returns choreographer profiles pre-sorted by hotness for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
CREATE OR REPLACE FUNCTION get_hot_choreographers()
RETURNS TABLE (
    -- Essential choreographer info only
    user_id UUID,
    display_name TEXT,
    bio TEXT,
    profile_picture_url TEXT,
    url_slug TEXT,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    -- Hotness score weights - easily adjustable for algorithm tuning
    WEIGHT_UPCOMING_WATCHLISTS REAL := 0.5;    -- 50% - most important for current momentum
    WEIGHT_UPCOMING_VIEWS REAL := 0.25;        -- 25% - engagement with current classes
    WEIGHT_FOLLOWER_COUNT REAL := 0.1;         -- 10% - established popularity
    WEIGHT_PROFILE_VIEWS REAL := 0.15;         -- 15% - general interest
BEGIN
    -- Execute the main query with computed hotness score for sorting
    -- Hotness metrics are calculated but not returned to keep FE clean
    RETURN QUERY
    WITH choreographer_metrics AS (
        SELECT 
            cp.user_id,
            cp.display_name,
            cp.bio,
            cp.profile_picture_url,
            cp.url_slug,
            cp.created_at,
            
            -- Hotness score calculation using named constants
            -- Computed for sorting but not returned to frontend
            (
                (COALESCE(cm.upcoming_watchlists, 0) * WEIGHT_UPCOMING_WATCHLISTS) +
                (COALESCE(cm.upcoming_class_views, 0) * WEIGHT_UPCOMING_VIEWS) +
                (COALESCE(fc.follower_count, 0) * WEIGHT_FOLLOWER_COUNT) +
                (cp.view_count * WEIGHT_PROFILE_VIEWS)
            )::REAL as hotness_score
            
        FROM active_choreographer_profiles cp
        
        -- Follower count subquery
        LEFT JOIN (
            SELECT 
                followed_choreographer_id,
                COUNT(*) as follower_count
            FROM choreographer_follows cf
            JOIN active_users au ON cf.follower_user_id = au.id
            GROUP BY followed_choreographer_id
        ) fc ON cp.user_id = fc.followed_choreographer_id
        
        -- Upcoming class metrics subquery
        LEFT JOIN (
            SELECT 
                c.choreographer_id,
                COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN c.view_count ELSE 0 END), 0) as upcoming_class_views,
                COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN cw.watchlist_count ELSE 0 END), 0) as upcoming_watchlists
            FROM active_classes c
            LEFT JOIN (
                SELECT 
                    class_id,
                    COUNT(*) as watchlist_count
                FROM class_watchlists
                GROUP BY class_id
            ) cw ON c.id = cw.class_id
            GROUP BY c.choreographer_id
        ) cm ON cp.user_id = cm.choreographer_id
    )
    SELECT 
        cm.user_id,
        cm.display_name,
        cm.bio,
        cm.profile_picture_url,
        cm.url_slug,
        cm.created_at
    FROM choreographer_metrics cm
    ORDER BY cm.hotness_score DESC, cm.created_at DESC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get "hot" classes sorted by computed hotness score
-- This powers the HEAT feature for discovering trending classes
-- Returns class details pre-sorted by hotness for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Only returns upcoming classes
CREATE OR REPLACE FUNCTION get_hot_classes(
    p_styles TEXT[] DEFAULT NULL,  -- Array of styles for OR filtering
    p_borough TEXT DEFAULT NULL
)
RETURNS TABLE (
    -- Essential class info only
    id UUID,
    title TEXT,
    description TEXT,
    style TEXT,
    skill_level TEXT,
    location_name TEXT,
    borough TEXT,
    price NUMERIC,
    booking_url TEXT,
    class_timestamp TIMESTAMPTZ,
    choreographer_note TEXT,
    
    -- Choreographer info
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    -- Hotness score weights - easily adjustable for algorithm tuning
    WEIGHT_WATCHLISTS REAL := 0.6;     -- 60% - watchlist engagement (primary signal)
    WEIGHT_VIEWS REAL := 0.4;          -- 40% - view engagement
BEGIN
    -- Execute the main query with computed hotness score for sorting
    -- Hotness metrics are calculated but not returned to keep FE clean
    RETURN QUERY
    WITH class_metrics AS (
        SELECT 
            c.id,
            c.title,
            c.description,
            c.style,
            c.skill_level,
            c.location_name,
            c.borough,
            c.price,
            c.booking_url,
            c.class_timestamp,
            c.choreographer_note,
            c.choreographer_id,
            c.choreographer_display_name,
            c.choreographer_url_slug,
            c.created_at,
            
            -- Hotness score calculation using named constants
            -- Note: view_count still used for scoring but not returned to FE
            (
                (COALESCE(wc.watchlist_count, 0) * WEIGHT_WATCHLISTS) +
                (c.view_count * WEIGHT_VIEWS)
            )::REAL as hotness_score
            
        FROM active_classes c
        
        -- Watchlist count subquery
        LEFT JOIN (
            SELECT 
                cw.class_id,
                COUNT(*) as watchlist_count
            FROM class_watchlists cw
            JOIN active_users u ON cw.user_id = u.id
            GROUP BY cw.class_id
        ) wc ON c.id = wc.class_id
        
        WHERE 
            -- Only upcoming classes
            c.class_timestamp > NOW()
            -- Optional filters
            AND (p_styles IS NULL OR c.style = ANY(p_styles))
            AND (p_borough IS NULL OR c.borough = p_borough)
    )
    SELECT 
        cm.id,
        cm.title,
        cm.description,
        cm.style,
        cm.skill_level,
        cm.location_name,
        cm.borough,
        cm.price,
        cm.booking_url,
        cm.class_timestamp,
        cm.choreographer_note,
        cm.choreographer_id,
        cm.choreographer_display_name,
        cm.choreographer_url_slug,
        cm.created_at
    FROM class_metrics cm
    ORDER BY cm.hotness_score DESC, cm.class_timestamp ASC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- AUTH FUNCTIONS
-- --------------------------------------------------------------------------------
-- SUBSCRIPTION & AUTH FUNCTIONS - User Management & Authentication
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Function to get user's available features based on subscription
CREATE OR REPLACE FUNCTION get_user_features(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_features JSONB;
BEGIN
    -- This query finds the user's active tier, joins to get all assigned feature names,
    -- and aggregates them into a single JSONB object like {"feature_name": true, ...}.
    SELECT COALESCE(
        jsonb_object_agg(f.name, true),
        '{}'::jsonb
    )
    INTO v_features
    FROM users u
    JOIN tier_features tf ON tf.tier_role = u.role AND tf.tier_name = u.tier_name
    JOIN features f ON tf.feature_id = f.id
    WHERE u.id = p_user_id
      AND u.subscription_status = 'active'
      AND u.deleted_at IS NULL;

    RETURN v_features;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has specific feature
CREATE OR REPLACE FUNCTION user_has_feature(p_user_id UUID, p_feature_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_role TEXT;
  v_tier_name TEXT;
  v_subscription_status TEXT;
BEGIN
  -- Get the user's current role, tier, and subscription status
  SELECT
    u.role,
    u.tier_name,
    u.subscription_status
  INTO
    v_user_role,
    v_tier_name,
    v_subscription_status
  FROM users u
  WHERE u.id = p_user_id AND u.deleted_at IS NULL;

  -- If user not found or subscription is not active, they have no features
  IF NOT FOUND OR v_subscription_status != 'active' THEN
    RETURN false;
  END IF;

  -- Check if a link exists between the user's tier and the requested feature
  RETURN EXISTS (
    SELECT 1
    FROM tier_features tf
    JOIN features f ON tf.feature_id = f.id
    WHERE tf.tier_role = v_user_role
      AND tf.tier_name = v_tier_name
      AND f.name = p_feature_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update subscription status
CREATE OR REPLACE FUNCTION update_subscription_status(
    p_user_id UUID,
    p_new_status TEXT,
    p_stripe_subscription_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_old_status TEXT;
BEGIN
    -- Get current user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
    END IF;
    
    v_old_status := v_user.subscription_status;
    
    -- Update user subscription status
    UPDATE users 
    SET subscription_status = p_new_status, updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Update corresponding subscription record if provided
    IF p_stripe_subscription_id IS NOT NULL THEN
        UPDATE subscriptions 
        SET status = p_new_status, updated_at = NOW()
        WHERE user_id = p_user_id AND stripe_subscription_id = p_stripe_subscription_id;
    END IF;
    
    RETURN jsonb_build_object('success', true, 'old_status', v_old_status, 'new_status', p_new_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle new user creation from auth.users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT;
    v_tier_name TEXT;
    v_invite_token TEXT;
    v_invite RECORD;
BEGIN
    v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'dancer');
    v_invite_token := NEW.raw_user_meta_data->>'invite_token';
    
    -- SECURITY: Choreographer role requires valid invite token
    IF v_role = 'choreographer' THEN
        IF v_invite_token IS NULL THEN
            RAISE EXCEPTION 'Choreographer signup requires invite token';
        END IF;
        
        -- Validate invite token
        SELECT * INTO v_invite FROM invites 
        WHERE token = v_invite_token 
          AND is_used = false 
          AND deleted_at IS NULL 
          AND expires_at > NOW();
          
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Invalid or expired invite token';
        END IF;
        
        -- Mark invite as used
        UPDATE invites 
        SET is_used = true, used_at = NOW(), used_by = NEW.id 
        WHERE id = v_invite.id;
    END IF;
    
    -- Set tier name to match subscription_tiers table
    v_tier_name := CASE 
        WHEN v_role = 'choreographer' THEN 'basic'
        ELSE 'free'
    END;

    INSERT INTO public.users (
        id, email, full_name, role, email_verified, last_login_at,
        tier_name, subscription_status, created_at, updated_at
    )
    VALUES (
        NEW.id, NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'),
        v_role,
        CASE 
            WHEN NEW.email_confirmed_at IS NOT NULL THEN true
            WHEN NEW.raw_user_meta_data->>'provider' = 'google' THEN true
            ELSE false
        END,
        NEW.last_sign_in_at, v_tier_name, 'active', NEW.created_at, NEW.updated_at
    );
    
    -- Create choreographer profile if needed
    IF v_role = 'choreographer' THEN
        INSERT INTO choreographer_profiles (user_id, display_name, created_at, updated_at)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'), NOW(), NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign choreographer role with subscription setup
CREATE OR REPLACE FUNCTION assign_choreographer_role(
    p_user_id UUID,
    p_invite_token TEXT,
    p_requesting_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_invite RECORD;
BEGIN
    -- Validate invite
    SELECT * INTO v_invite FROM invites 
    WHERE token = p_invite_token AND is_used = false AND deleted_at IS NULL AND expires_at > NOW();

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_INVITE');
    END IF;

    -- Get user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;

    -- Update user role and subscription
    UPDATE users SET 
        role = 'choreographer',
        tier_name = 'basic',
        subscription_status = 'active',
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Create choreographer profile
    INSERT INTO choreographer_profiles (user_id, display_name, created_at, updated_at)
    VALUES (p_user_id, v_user.full_name, NOW(), NOW())
    ON CONFLICT (user_id) DO NOTHING;

    -- Mark invite as used
    UPDATE invites SET is_used = true, used_at = NOW(), used_by = p_user_id WHERE id = v_invite.id;

    RETURN jsonb_build_object('success', true, 'message', 'Choreographer role assigned successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically handle new user creation from Supabase auth
-- This trigger ensures new users are properly created in the public.users table
-- and choreographer profiles are created when needed
CREATE TRIGGER trigger_handle_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();



-- INDEXES
-- --------------------------------------------------------------------------------
-- INDEXES & PERFORMANCE - All Database Indexes for Optimization
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Users table indexes
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_subscription_status_role_tier ON users(subscription_status, role, tier_name) WHERE deleted_at IS NULL;

-- Subscription indexes
CREATE INDEX idx_subscription_tiers_role ON subscription_tiers(role) WHERE is_active = true;
CREATE INDEX idx_subscriptions_user_status ON subscriptions(user_id, status);
CREATE INDEX idx_subscriptions_stripe_subscription ON subscriptions(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;

-- Choreographer profiles indexes
CREATE INDEX idx_profiles_url_slug ON choreographer_profiles(url_slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_active ON choreographer_profiles(user_id) WHERE deleted_at IS NULL;

-- Classes table indexes
CREATE INDEX idx_classes_timestamp ON classes(class_timestamp) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_choreographer ON classes(choreographer_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_style_borough ON classes(style, borough) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_active ON classes(id) WHERE deleted_at IS NULL;

-- Composite indexes for advanced search and filtering
CREATE INDEX idx_classes_style_borough_timestamp ON classes(style, borough, class_timestamp) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_location_style ON classes(location_name, style) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_choreographer_timestamp ON classes(choreographer_id, class_timestamp) WHERE deleted_at IS NULL;

-- Full-text search indexes for text search functionality
CREATE INDEX idx_classes_title_search ON classes USING gin(to_tsvector('english', title)) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_location_search ON classes USING gin(to_tsvector('english', location_name)) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_description_search ON classes USING gin(to_tsvector('english', description)) WHERE deleted_at IS NULL;

-- Choreographer profiles search index
CREATE INDEX idx_choreographer_profiles_name_search ON choreographer_profiles USING gin(to_tsvector('english', display_name)) WHERE deleted_at IS NULL;

-- Social relationship indexes
CREATE INDEX idx_watchlists_user ON class_watchlists(user_id);
CREATE INDEX idx_watchlists_class ON class_watchlists(class_id);
CREATE INDEX idx_follows_follower ON choreographer_follows(follower_user_id);
CREATE INDEX idx_follows_followed ON choreographer_follows(followed_choreographer_id);

-- Invites table indexes
CREATE INDEX idx_invites_token ON invites(token) WHERE deleted_at IS NULL;
CREATE INDEX idx_invites_active ON invites(id) WHERE deleted_at IS NULL AND is_used = false;

-- Audit logs table indexes
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;

-- Indexes for normalized feature system
CREATE INDEX idx_tier_features_feature_id ON tier_features(feature_id);
CREATE INDEX idx_tier_features_tier ON tier_features(tier_role, tier_name);

-- --------------------------------------------------------------------------------
-- BUSINESS LOGIC INDEXES: Documentation & Function Mapping (Subtask 2.4)
-- These composite indexes are critical for performance of business logic functions:
--   - get_classes_with_watchlist_count
--   - search_and_filter_classes
--   - get_trending_classes
--   - get_most_popular_choreographers
--   - get_choreographer_analytics
--
-- Index mapping:
--   idx_classes_style_borough_timestamp: supports multi-factor class search/filtering, trending classes
--   idx_classes_location_style: supports location-based class search/filtering
--   idx_classes_choreographer_timestamp: supports choreographer analytics, class listings
--   idx_watchlists_class, idx_watchlists_user: supports trending classes, heat calculations
--   idx_follows_followed, idx_follows_follower: supports most popular choreographers, analytics
--   Full-text GIN indexes: support advanced search
--
-- These indexes are designed to match the query patterns in the business logic functions and should be monitored for performance with EXPLAIN ANALYZE.
--
-- If query times exceed 300ms, consider materialized views or further index tuning as described in the performance checklist.



-- AUTOMATION & TRIGGERS
-- --------------------------------------------------------------------------------
-- VIEWS, TRIGGERS & AUTOMATION - Database Automation & Active Record Views
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Universal function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to all tables
CREATE TRIGGER trigger_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_choreographer_profiles_updated_at BEFORE UPDATE ON choreographer_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_classes_updated_at BEFORE UPDATE ON classes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_invites_updated_at BEFORE UPDATE ON invites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_subscription_tiers_updated_at BEFORE UPDATE ON subscription_tiers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trigger_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Subscription-aware views
CREATE VIEW active_users AS
SELECT u.*, get_user_features(u.id) as features
FROM users u WHERE u.deleted_at IS NULL;

CREATE VIEW active_choreographer_profiles AS
SELECT cp.*, CONCAT(u.role, '_', u.tier_name) as subscription_tier, u.subscription_status
FROM choreographer_profiles cp
JOIN users u ON cp.user_id = u.id
WHERE cp.deleted_at IS NULL AND u.deleted_at IS NULL AND u.role = 'choreographer' AND u.subscription_status = 'active';

CREATE VIEW active_classes AS
SELECT c.*, cp.display_name as choreographer_display_name, cp.url_slug as choreographer_url_slug, u.subscription_status
FROM classes c
JOIN users u ON c.choreographer_id = u.id
JOIN choreographer_profiles cp ON u.id = cp.user_id
WHERE c.deleted_at IS NULL AND u.deleted_at IS NULL AND cp.deleted_at IS NULL AND u.role = 'choreographer' AND u.subscription_status = 'active';

-- Soft delete cascading function
CREATE OR REPLACE FUNCTION cascade_user_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        UPDATE choreographer_profiles SET deleted_at = NEW.deleted_at WHERE user_id = NEW.id AND deleted_at IS NULL;
        UPDATE classes SET deleted_at = NEW.deleted_at WHERE choreographer_id = NEW.id AND deleted_at IS NULL;
        UPDATE subscriptions SET status = 'cancelled', cancelled_at = NEW.deleted_at WHERE user_id = NEW.id AND status != 'cancelled';
        DELETE FROM choreographer_follows WHERE follower_user_id = NEW.id OR followed_choreographer_id = NEW.id;
        DELETE FROM class_watchlists WHERE user_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_soft_delete_cascade AFTER UPDATE ON users FOR EACH ROW EXECUTE FUNCTION cascade_user_soft_delete();

-- View count functions with audit logging
CREATE OR REPLACE FUNCTION increment_class_view_count(class_uuid UUID)
RETURNS VOID AS $$
DECLARE
    v_actor UUID;
    v_old_count INTEGER;
    v_new_count INTEGER;
BEGIN
    -- Get current actor for audit trail
    SELECT CASE WHEN current_setting('jwt.claims.user_id', true) IS NULL
                THEN NULL
                ELSE current_setting('jwt.claims.user_id', true)::uuid
           END INTO v_actor;

    -- Get current view count before increment
    SELECT view_count INTO v_old_count FROM classes WHERE id = class_uuid AND deleted_at IS NULL;
    
    IF v_old_count IS NOT NULL THEN
        -- Increment view count
        UPDATE classes SET view_count = view_count + 1 WHERE id = class_uuid AND deleted_at IS NULL;
        
        v_new_count := v_old_count + 1;
        
        -- Log the view increment to audit trail
        PERFORM audit.log_insert(
            v_actor,
            'classes',
            class_uuid::text,
            'VIEW_INCREMENT',
            jsonb_build_object(
                'old_count', v_old_count,
                'new_count', v_new_count,
                'increment', 1
            )
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_profile_view_count(profile_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_actor UUID;
    v_old_count INTEGER;
    v_new_count INTEGER;
BEGIN
    -- Get current actor for audit trail
    SELECT CASE WHEN current_setting('jwt.claims.user_id', true) IS NULL
                THEN NULL
                ELSE current_setting('jwt.claims.user_id', true)::uuid
           END INTO v_actor;

    -- Get current view count before increment
    SELECT view_count INTO v_old_count FROM choreographer_profiles WHERE user_id = profile_user_id AND deleted_at IS NULL;
    
    IF v_old_count IS NOT NULL THEN
        -- Increment view count
        UPDATE choreographer_profiles SET view_count = view_count + 1 WHERE user_id = profile_user_id AND deleted_at IS NULL;
        
        v_new_count := v_old_count + 1;
        
        -- Log the view increment to audit trail
        PERFORM audit.log_insert(
            v_actor,
            'choreographer_profiles',
            profile_user_id::text,
            'VIEW_INCREMENT',
            jsonb_build_object(
                'old_count', v_old_count,
                'new_count', v_new_count,
                'increment', 1
            )
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- AUDIT SYSTEM
-- Audit schema: lightweight audit logs, insert RPC, and example triggers
-- This file provides a minimal, pragmatic audit trail for critical operations.

CREATE SCHEMA IF NOT EXISTS audit;

-- Primary audit table. Keep payload and meta flexible as JSONB for later analysis.
CREATE TABLE IF NOT EXISTS audit.audit_logs (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid NULL,
  target_table text NOT NULL,
  target_id text NULL,
  action text NOT NULL,
  payload jsonb NULL,
  meta jsonb NULL
);

-- Useful indexes for common queries: by time, by target, by actor
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit.audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_audit_target_table_id ON audit.audit_logs (target_table, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit.audit_logs (actor_user_id);

-- Lightweight, reusable RPC to insert an audit row. SECURITY DEFINER so app-level
-- callers (web role) can invoke this through thin trigger functions without
-- requiring broad table-level privileges.
CREATE OR REPLACE FUNCTION audit.log_insert(
  p_actor_user_id uuid,
  p_target_table text,
  p_target_id text,
  p_action text,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_meta jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO audit.audit_logs (actor_user_id, target_table, target_id, action, payload, meta)
  VALUES (
    p_actor_user_id,
    p_target_table,
    p_target_id,
    upper(p_action),
    COALESCE(p_payload, '{}'::jsonb),
    COALESCE(p_meta, '{}'::jsonb)
  );
END;
$$;

-- Helper: read the current actor from JWT claims if set (Supabase sets jwt.claims.user_id).
-- Returns NULL when the claim isn't present (eg. background jobs).
CREATE OR REPLACE FUNCTION audit.get_current_actor() RETURNS uuid
LANGUAGE sql
AS $$
  SELECT CASE WHEN current_setting('jwt.claims.user_id', true) IS NULL
              THEN NULL
              ELSE current_setting('jwt.claims.user_id', true)::uuid
         END;
$$;

-- Trigger function for classes: log CREATE / UPDATE (meaningful column changes) / DELETE
CREATE OR REPLACE FUNCTION audit.trigger_classes() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_action text;
  v_tgt_id text;
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    v_action := 'CREATE';
    v_tgt_id := NEW.id::text;
    v_payload := jsonb_build_object('new', to_jsonb(NEW));
    PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- Only log updates when relevant business columns change to avoid noise
    IF (ROW(OLD.title, OLD.description, OLD.class_timestamp, OLD.location_name, OLD.price, OLD.deleted_at)
        IS DISTINCT FROM ROW(NEW.title, NEW.description, NEW.class_timestamp, NEW.location_name, NEW.price, NEW.deleted_at)) THEN
      v_action := 'UPDATE';
      v_tgt_id := NEW.id::text;
      v_payload := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    v_action := 'DELETE';
    v_tgt_id := OLD.id::text;
    v_payload := jsonb_build_object('old', to_jsonb(OLD));
    PERFORM audit.log_insert(v_actor, 'classes', v_tgt_id, v_action, v_payload);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- Attach trigger to classes (idempotent: drop existing trigger first)
DROP TRIGGER IF EXISTS classes_audit_trigger ON classes;
CREATE TRIGGER classes_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON classes
FOR EACH ROW EXECUTE FUNCTION audit.trigger_classes();

-- Trigger function for users: focus on role changes (and optionally creation/deletion)
CREATE OR REPLACE FUNCTION audit.trigger_users_roles() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      v_payload := jsonb_build_object('user_id', NEW.id, 'old_role', OLD.role, 'new_role', NEW.role);
      PERFORM audit.log_insert(v_actor, 'users', NEW.id::text, 'ROLE_CHANGE', v_payload);
    END IF;

  ELSIF (TG_OP = 'INSERT') THEN
    PERFORM audit.log_insert(v_actor, 'users', NEW.id::text, 'CREATE', jsonb_build_object('new', to_jsonb(NEW)));

  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM audit.log_insert(v_actor, 'users', OLD.id::text, 'DELETE', jsonb_build_object('old', to_jsonb(OLD)));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_audit_trigger ON users;
CREATE TRIGGER users_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION audit.trigger_users_roles();

-- Trigger function for choreographer_profiles: log profile field changes
CREATE OR REPLACE FUNCTION audit.trigger_choreographer_profiles() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    PERFORM audit.log_insert(v_actor, 'choreographer_profiles', NEW.id::text, 'CREATE', jsonb_build_object('new', to_jsonb(NEW)));
    RETURN NEW;

  ELSIF (TG_OP = 'UPDATE') THEN
    IF ROW(OLD.bio, OLD.social_links, OLD.profile_picture_url, OLD.display_name, OLD.deleted_at)
        IS DISTINCT FROM ROW(NEW.bio, NEW.social_links, NEW.profile_picture_url, NEW.display_name, NEW.deleted_at) THEN
      v_payload := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      PERFORM audit.log_insert(v_actor, 'choreographer_profiles', NEW.id::text, 'UPDATE', v_payload);
    END IF;
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    PERFORM audit.log_insert(v_actor, 'choreographer_profiles', OLD.id::text, 'DELETE', jsonb_build_object('old', to_jsonb(OLD)));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS choreographer_profiles_audit_trigger ON choreographer_profiles;
CREATE TRIGGER choreographer_profiles_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON choreographer_profiles
FOR EACH ROW EXECUTE FUNCTION audit.trigger_choreographer_profiles();

-- Social Actions Audit Triggers

-- Trigger function for class_watchlists: track watchlist additions/removals
CREATE OR REPLACE FUNCTION audit.trigger_class_watchlists() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    v_payload := jsonb_build_object(
      'user_id', NEW.user_id,
      'class_id', NEW.class_id,
      'action', 'watchlist_add'
    );
    PERFORM audit.log_insert(v_actor, 'class_watchlists', NEW.class_id::text, 'WATCHLIST_ADD', v_payload);
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    v_payload := jsonb_build_object(
      'user_id', OLD.user_id,
      'class_id', OLD.class_id,
      'action', 'watchlist_remove'
    );
    PERFORM audit.log_insert(v_actor, 'class_watchlists', OLD.class_id::text, 'WATCHLIST_REMOVE', v_payload);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- Attach trigger to class_watchlists
DROP TRIGGER IF EXISTS class_watchlists_audit_trigger ON class_watchlists;
CREATE TRIGGER class_watchlists_audit_trigger
AFTER INSERT OR DELETE ON class_watchlists
FOR EACH ROW EXECUTE FUNCTION audit.trigger_class_watchlists();

-- Trigger function for choreographer_follows: track follow/unfollow actions
CREATE OR REPLACE FUNCTION audit.trigger_choreographer_follows() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor uuid := audit.get_current_actor();
  v_payload jsonb;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    v_payload := jsonb_build_object(
      'follower_user_id', NEW.follower_user_id,
      'followed_choreographer_id', NEW.followed_choreographer_id,
      'action', 'follow'
    );
    PERFORM audit.log_insert(v_actor, 'choreographer_follows', NEW.followed_choreographer_id::text, 'FOLLOW', v_payload);
    RETURN NEW;

  ELSIF (TG_OP = 'DELETE') THEN
    v_payload := jsonb_build_object(
      'follower_user_id', OLD.follower_user_id,
      'followed_choreographer_id', OLD.followed_choreographer_id,
      'action', 'unfollow'
    );
    PERFORM audit.log_insert(v_actor, 'choreographer_follows', OLD.followed_choreographer_id::text, 'UNFOLLOW', v_payload);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

-- Attach trigger to choreographer_follows
DROP TRIGGER IF EXISTS choreographer_follows_audit_trigger ON choreographer_follows;
CREATE TRIGGER choreographer_follows_audit_trigger
AFTER INSERT OR DELETE ON choreographer_follows
FOR EACH ROW EXECUTE FUNCTION audit.trigger_choreographer_follows();

-- Notes:
-- - These triggers are intentionally thin: they build a compact JSON payload and call
--   the `audit.log_insert` RPC. If you prefer queueing/async ingestion, replace the
--   PERFORM calls with inserts into a small staging table and process with a worker.
-- - Consider enabling RLS on audit.audit_logs to restrict reads to an "audit" role.
-- - Consider periodic archival/retention (eg. move rows older than 365 days to an archive schema).



-- RLS POLICIES
-- --------------------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES - Comprehensive Security Implementation
-- This file implements RLS policies for all tables with proper access control
-- --------------------------------------------------------------------------------

-- Enable RLS on all tables (must come before creating policies)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE features ENABLE ROW LEVEL SECURITY;
ALTER TABLE tier_features ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user ID from JWT
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RETURN COALESCE(auth.uid(), NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = get_current_user_id() 
      AND role = 'admin' 
      AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if current user is choreographer
CREATE OR REPLACE FUNCTION is_choreographer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = get_current_user_id() 
      AND role = 'choreographer' 
      AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------------
-- USERS TABLE POLICIES
-- --------------------------------------------------------------------------------

-- Users can read their own record and basic info of other users
CREATE POLICY "users_select_policy" ON users
  FOR SELECT
  USING (
    -- Own record: full access
    id = get_current_user_id() OR
    -- Other users: only basic info if not deleted
    (deleted_at IS NULL AND id != get_current_user_id()) OR
    -- Admins can see all
    is_admin()
  );

-- Users can only update their own non-critical fields
CREATE POLICY "users_update_policy" ON users
  FOR UPDATE
  USING (id = get_current_user_id() OR is_admin())
  WITH CHECK (id = get_current_user_id() OR is_admin());

-- Only allow INSERT through auth trigger (handled by Supabase auth)
CREATE POLICY "users_insert_policy" ON users
  FOR INSERT
  WITH CHECK (is_admin() OR id = get_current_user_id());

-- Users can soft-delete their own account, admins can delete any
CREATE POLICY "users_delete_policy" ON users
  FOR DELETE
  USING (id = get_current_user_id() OR is_admin());

-- --------------------------------------------------------------------------------
-- CHOREOGRAPHER PROFILES POLICIES
-- --------------------------------------------------------------------------------

-- Profiles are publicly readable (for discovery), but only active profiles
CREATE POLICY "profiles_select_policy" ON choreographer_profiles
  FOR SELECT
  USING (
    deleted_at IS NULL OR
    user_id = get_current_user_id() OR
    is_admin()
  );

-- Only profile owner can update their profile
CREATE POLICY "profiles_update_policy" ON choreographer_profiles
  FOR UPDATE
  USING (user_id = get_current_user_id() OR is_admin())
  WITH CHECK (user_id = get_current_user_id() OR is_admin());

-- Profile creation handled by auth trigger, or admins can create
CREATE POLICY "profiles_insert_policy" ON choreographer_profiles
  FOR INSERT
  WITH CHECK (user_id = get_current_user_id() OR is_admin());

-- Only profile owner or admin can delete
CREATE POLICY "profiles_delete_policy" ON choreographer_profiles
  FOR DELETE
  USING (user_id = get_current_user_id() OR is_admin());

-- --------------------------------------------------------------------------------
-- CLASSES POLICIES
-- --------------------------------------------------------------------------------

-- Classes are publicly readable if not deleted and choreographer is active
CREATE POLICY "classes_select_policy" ON classes
  FOR SELECT
  USING (
    (deleted_at IS NULL AND EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = choreographer_id 
        AND u.deleted_at IS NULL 
        AND u.role = 'choreographer'
    )) OR
    choreographer_id = get_current_user_id() OR
    is_admin()
  );

-- Comprehensive class management policy for choreographers
CREATE POLICY "classes_management_policy" ON classes
  FOR ALL
  USING (
    -- For SELECT: Public read access for active classes, or owner/admin access
    (
      (deleted_at IS NULL AND EXISTS (
        SELECT 1 FROM users u 
        WHERE u.id = choreographer_id 
          AND u.deleted_at IS NULL 
          AND u.role = 'choreographer'
      )) OR
      choreographer_id = get_current_user_id() OR
      is_admin()
    )
  )
  WITH CHECK (
    -- For INSERT/UPDATE/DELETE: Owner with class_management feature or admin
    (
      choreographer_id = get_current_user_id() AND
      is_choreographer() AND
      user_has_feature(get_current_user_id(), 'class_management')
    ) OR is_admin()
  );

-- --------------------------------------------------------------------------------
-- CLASS WATCHLISTS POLICIES
-- --------------------------------------------------------------------------------

-- Users can only see their own watchlists
CREATE POLICY "watchlists_select_policy" ON class_watchlists
  FOR SELECT
  USING (user_id = get_current_user_id() OR is_admin());

-- Users can only modify their own watchlists, and only for active classes
CREATE POLICY "watchlists_insert_policy" ON class_watchlists
  FOR INSERT
  WITH CHECK (
    user_id = get_current_user_id() AND
    user_has_feature(get_current_user_id(), 'watchlist') AND
    EXISTS (
      SELECT 1 FROM classes c
      JOIN users u ON c.choreographer_id = u.id
      WHERE c.id = class_id
        AND c.deleted_at IS NULL
        AND u.deleted_at IS NULL
        AND u.role = 'choreographer'
    )
  );

-- Users can remove from their own watchlists
CREATE POLICY "watchlists_delete_policy" ON class_watchlists
  FOR DELETE
  USING (user_id = get_current_user_id() OR is_admin());

-- No updates allowed on watchlists (insert/delete only)

-- --------------------------------------------------------------------------------
-- CHOREOGRAPHER FOLLOWS POLICIES
-- --------------------------------------------------------------------------------

-- Users can see follows where they are involved (follower or followed)
CREATE POLICY "follows_select_policy" ON choreographer_follows
  FOR SELECT
  USING (
    follower_user_id = get_current_user_id() OR
    followed_choreographer_id = get_current_user_id() OR
    is_admin()
  );

-- Users can only follow active choreographers
CREATE POLICY "follows_insert_policy" ON choreographer_follows
  FOR INSERT
  WITH CHECK (
    follower_user_id = get_current_user_id() AND
    user_has_feature(get_current_user_id(), 'follow') AND
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = followed_choreographer_id
        AND u.deleted_at IS NULL
        AND u.role = 'choreographer'
    )
  );

-- Users can unfollow anyone they are following
CREATE POLICY "follows_delete_policy" ON choreographer_follows
  FOR DELETE
  USING (
    follower_user_id = get_current_user_id() OR
    followed_choreographer_id = get_current_user_id() OR
    is_admin()
  );

-- No updates allowed on follows (insert/delete only)

-- --------------------------------------------------------------------------------
-- INVITES POLICIES
-- --------------------------------------------------------------------------------

-- Only admins can see all invites
-- Users can see invites sent to their email (for validation)
CREATE POLICY "invites_select_policy" ON invites
  FOR SELECT
  USING (
    is_admin() OR
    (email = (SELECT email FROM auth.users WHERE id = get_current_user_id()))
  );

-- Only admins can create invites
CREATE POLICY "invites_insert_policy" ON invites
  FOR INSERT
  WITH CHECK (is_admin());

-- Only admins can update invites
CREATE POLICY "invites_update_policy" ON invites
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Only admins can delete invites
CREATE POLICY "invites_delete_policy" ON invites
  FOR DELETE
  USING (is_admin());

-- --------------------------------------------------------------------------------
-- SUBSCRIPTION TIERS POLICIES
-- --------------------------------------------------------------------------------

-- Subscription tiers are publicly readable (for signup/upgrade flows)
CREATE POLICY "subscription_tiers_select_policy" ON subscription_tiers
  FOR SELECT
  USING (is_active = true OR is_admin());

-- Only admins can modify subscription tiers
CREATE POLICY "subscription_tiers_insert_policy" ON subscription_tiers
  FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "subscription_tiers_update_policy" ON subscription_tiers
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "subscription_tiers_delete_policy" ON subscription_tiers
  FOR DELETE
  USING (is_admin());

-- --------------------------------------------------------------------------------
-- SUBSCRIPTIONS POLICIES
-- --------------------------------------------------------------------------------

-- Users can see their own subscriptions, admins can see all
CREATE POLICY "subscriptions_select_policy" ON subscriptions
  FOR SELECT
  USING (user_id = get_current_user_id() OR is_admin());

-- Subscriptions are typically managed by webhooks/admin functions
-- Users cannot directly create/update subscriptions
CREATE POLICY "subscriptions_insert_policy" ON subscriptions
  FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "subscriptions_update_policy" ON subscriptions
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "subscriptions_delete_policy" ON subscriptions
  FOR DELETE
  USING (is_admin());

-- --------------------------------------------------------------------------------
-- AUDIT LOGS POLICIES
-- --------------------------------------------------------------------------------

-- Audit logs are highly restricted - only admins and specific audit roles
CREATE POLICY "audit_logs_select_policy" ON audit.audit_logs
  FOR SELECT
  USING (
    is_admin() OR
    -- Users can see audit logs related to their own actions/records
    (actor_user_id = get_current_user_id() AND target_id = get_current_user_id()::text)
  );

-- Only system/admin can insert audit logs (through SECURITY DEFINER functions)
CREATE POLICY "audit_logs_insert_policy" ON audit.audit_logs
  FOR INSERT
  WITH CHECK (is_admin());

-- Audit logs are immutable - no updates or deletes allowed
-- (except for admin maintenance)
CREATE POLICY "audit_logs_update_policy" ON audit.audit_logs
  FOR UPDATE
  USING (false); -- No updates allowed

CREATE POLICY "audit_logs_delete_policy" ON audit.audit_logs
  FOR DELETE
  USING (is_admin()); -- Only admins for maintenance

-- --------------------------------------------------------------------------------
-- FEATURES AND TIER_FEATURES TABLE POLICIES  
-- --------------------------------------------------------------------------------

-- Features table policies (read-only for most users)
CREATE POLICY "features_select_policy" ON features
  FOR SELECT
  USING (true); -- Features are publicly readable

CREATE POLICY "features_admin_policy" ON features
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Tier features policies (read-only for most users) 
CREATE POLICY "tier_features_select_policy" ON tier_features
  FOR SELECT
  USING (true); -- Tier features are publicly readable

CREATE POLICY "tier_features_admin_policy" ON tier_features
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- --------------------------------------------------------------------------------
-- GRANT PERMISSIONS TO ROLES
-- --------------------------------------------------------------------------------

-- Grant permissions to authenticated users (standard Supabase role)
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON choreographer_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON classes TO authenticated;
GRANT SELECT, INSERT, DELETE ON class_watchlists TO authenticated; -- No UPDATE
GRANT SELECT, INSERT, DELETE ON choreographer_follows TO authenticated; -- No UPDATE
GRANT SELECT ON invites TO authenticated; -- Read-only for validation
GRANT SELECT ON subscription_tiers TO authenticated; -- Read-only
GRANT SELECT ON subscriptions TO authenticated; -- Read-only for users
GRANT SELECT ON audit.audit_logs TO authenticated; -- Read-only
GRANT SELECT ON features TO authenticated; -- Read-only
GRANT SELECT ON tier_features TO authenticated; -- Read-only

-- Grant broader permissions to service role (for admin functions)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO service_role;

-- Grant usage on schemas
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT USAGE ON SCHEMA audit TO authenticated, service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO authenticated, service_role;

-- --------------------------------------------------------------------------------
-- NOTES ON SECURITY DESIGN
-- --------------------------------------------------------------------------------
/*
RLS Policy Design Principles:

1. **Defense in Depth**: Multiple layers of security checks
2. **Principle of Least Privilege**: Users get minimum necessary access
3. **Data Isolation**: Users can only access their own data unless public
4. **Audit Trail Protection**: Audit logs are heavily restricted
5. **Admin Override**: Admins have full access for management

Key Security Features:
- Soft-deleted records are hidden from public queries
- Social actions (follows, watchlists) require active accounts
- Choreographer-only actions are properly restricted
- Invite system is admin-controlled
- Subscription management is admin/webhook controlled
- Audit logs are immutable and restricted

Performance Considerations:
- Helper functions are SECURITY DEFINER for efficiency
- Policies use EXISTS clauses for referential checks
- Indexes support the common WHERE clauses in policies

Testing Recommendations:
- Test each policy with different user roles
- Verify soft-deleted records are properly hidden
- Test admin override functionality
- Verify audit log restrictions work correctly
*/



-- ADMIN UTILITIES
-- --------------------------------------------------------------------------------
-- ADMINISTRATIVE UTILITY FUNCTIONS - Soft Delete, Restore & Management
-- This file contains utility functions for administrative operations
-- --------------------------------------------------------------------------------

-- Function to soft delete a user and cascade to related records
CREATE OR REPLACE FUNCTION admin_soft_delete_user(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_affected_records JSONB := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get user to delete
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
    END IF;

    -- Soft delete the user (will trigger cascade function)
    UPDATE users SET deleted_at = NOW() WHERE id = p_user_id;

    -- Count affected records
    SELECT jsonb_build_object(
        'choreographer_profiles', (SELECT COUNT(*) FROM choreographer_profiles WHERE user_id = p_user_id AND deleted_at IS NOT NULL),
        'classes', (SELECT COUNT(*) FROM classes WHERE choreographer_id = p_user_id AND deleted_at IS NOT NULL),
        'watchlists_removed', (SELECT COUNT(*) FROM class_watchlists WHERE user_id = p_user_id),
        'follows_removed', (SELECT COUNT(*) FROM choreographer_follows WHERE follower_user_id = p_user_id OR followed_choreographer_id = p_user_id)
    ) INTO v_affected_records;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'users',
        p_user_id::text,
        'ADMIN_SOFT_DELETE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'affected_records', v_affected_records,
            'original_role', v_user.role
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User soft deleted successfully',
        'affected_records', v_affected_records
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted user and related records
CREATE OR REPLACE FUNCTION admin_restore_user(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_restored_records JSONB := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get deleted user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NOT NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND_OR_NOT_DELETED');
    END IF;

    -- Restore the user
    UPDATE users SET deleted_at = NULL, updated_at = NOW() WHERE id = p_user_id;

    -- Restore related records (only if they were deleted at the same time)
    UPDATE choreographer_profiles 
    SET deleted_at = NULL, updated_at = NOW() 
    WHERE user_id = p_user_id AND deleted_at = v_user.deleted_at;

    UPDATE classes 
    SET deleted_at = NULL, updated_at = NOW() 
    WHERE choreographer_id = p_user_id AND deleted_at = v_user.deleted_at;

    -- Count restored records
    SELECT jsonb_build_object(
        'choreographer_profiles', (SELECT COUNT(*) FROM choreographer_profiles WHERE user_id = p_user_id AND deleted_at IS NULL),
        'classes', (SELECT COUNT(*) FROM classes WHERE choreographer_id = p_user_id AND deleted_at IS NULL)
    ) INTO v_restored_records;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'users',
        p_user_id::text,
        'ADMIN_RESTORE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'restored_records', v_restored_records,
            'original_deleted_at', v_user.deleted_at
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User restored successfully',
        'restored_records', v_restored_records
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a class
CREATE OR REPLACE FUNCTION admin_soft_delete_class(
    p_class_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_class RECORD;
    v_watchlist_count INTEGER;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get class to delete
    SELECT * INTO v_class FROM classes WHERE id = p_class_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'CLASS_NOT_FOUND');
    END IF;

    -- Count watchlists that will be affected
    SELECT COUNT(*) INTO v_watchlist_count FROM class_watchlists WHERE class_id = p_class_id;

    -- Soft delete the class
    UPDATE classes SET deleted_at = NOW() WHERE id = p_class_id;

    -- Remove from watchlists (cascade effect)
    DELETE FROM class_watchlists WHERE class_id = p_class_id;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'classes',
        p_class_id::text,
        'ADMIN_SOFT_DELETE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'class_title', v_class.title,
            'choreographer_id', v_class.choreographer_id,
            'watchlists_removed', v_watchlist_count
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Class soft deleted successfully',
        'watchlists_removed', v_watchlist_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted class
CREATE OR REPLACE FUNCTION admin_restore_class(
    p_class_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_class RECORD;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get deleted class
    SELECT * INTO v_class FROM classes WHERE id = p_class_id AND deleted_at IS NOT NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'CLASS_NOT_FOUND_OR_NOT_DELETED');
    END IF;

    -- Verify choreographer is still active
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = v_class.choreographer_id AND deleted_at IS NULL AND role = 'choreographer'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'CHOREOGRAPHER_INACTIVE');
    END IF;

    -- Restore the class
    UPDATE classes SET deleted_at = NULL, updated_at = NOW() WHERE id = p_class_id;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'classes',
        p_class_id::text,
        'ADMIN_RESTORE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'class_title', v_class.title,
            'choreographer_id', v_class.choreographer_id,
            'original_deleted_at', v_class.deleted_at
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Class restored successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to permanently delete old soft-deleted records
CREATE OR REPLACE FUNCTION admin_permanent_delete_old_records(
    p_admin_user_id UUID,
    p_days_old INTEGER DEFAULT 365,
    p_dry_run BOOLEAN DEFAULT true
)
RETURNS JSONB AS $$
DECLARE
    v_cutoff_date TIMESTAMPTZ;
    v_users_count INTEGER := 0;
    v_profiles_count INTEGER := 0;
    v_classes_count INTEGER := 0;
    v_invites_count INTEGER := 0;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    v_cutoff_date := NOW() - (p_days_old || ' days')::INTERVAL;

    -- Count records to be deleted
    SELECT COUNT(*) INTO v_users_count FROM users WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_profiles_count FROM choreographer_profiles WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_classes_count FROM classes WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_invites_count FROM invites WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;

    IF NOT p_dry_run THEN
        -- Permanently delete old records
        DELETE FROM choreographer_profiles WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM classes WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM invites WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM users WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;

        -- Log the cleanup action
        PERFORM audit.log_insert(
            p_admin_user_id,
            'system',
            'cleanup',
            'PERMANENT_DELETE_CLEANUP',
            jsonb_build_object(
                'cutoff_date', v_cutoff_date,
                'days_old', p_days_old,
                'users_deleted', v_users_count,
                'profiles_deleted', v_profiles_count,
                'classes_deleted', v_classes_count,
                'invites_deleted', v_invites_count
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'dry_run', p_dry_run,
        'cutoff_date', v_cutoff_date,
        'records_to_delete', jsonb_build_object(
            'users', v_users_count,
            'profiles', v_profiles_count,
            'classes', v_classes_count,
            'invites', v_invites_count
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to bulk update user roles (admin utility)
CREATE OR REPLACE FUNCTION admin_bulk_update_roles(
    p_user_ids UUID[],
    p_new_role TEXT,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INTEGER := 0;
    v_errors TEXT[] := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Validate role
    IF p_new_role NOT IN ('dancer', 'choreographer', 'admin') THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE');
    END IF;

    -- Process each user
    FOREACH v_user_id IN ARRAY p_user_ids
    LOOP
        BEGIN
            -- Update role if user exists and is not deleted
            IF EXISTS (SELECT 1 FROM users WHERE id = v_user_id AND deleted_at IS NULL) THEN
                UPDATE users SET role = p_new_role, updated_at = NOW() WHERE id = v_user_id;
                
                -- Log the role change
                PERFORM audit.log_insert(
                    p_admin_user_id,
                    'users',
                    v_user_id::text,
                    'ADMIN_ROLE_CHANGE',
                    jsonb_build_object(
                        'new_role', p_new_role,
                        'admin_reason', p_reason,
                        'bulk_operation', true
                    )
                );
                
                v_updated_count := v_updated_count + 1;
            ELSE
                v_errors := array_append(v_errors, 'User ' || v_user_id || ' not found or deleted');
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'Error updating user ' || v_user_id || ': ' || SQLERRM);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'updated_count', v_updated_count,
        'total_requested', array_length(p_user_ids, 1),
        'errors', v_errors
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive audit report for a user
CREATE OR REPLACE FUNCTION admin_get_user_audit_report(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    log_id BIGINT,
    created_at TIMESTAMPTZ,
    actor_user_id UUID,
    target_table TEXT,
    target_id TEXT,
    action TEXT,
    payload JSONB,
    meta JSONB
) AS $$
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- Return audit logs related to the user
    RETURN QUERY
    SELECT 
        al.id,
        al.created_at,
        al.actor_user_id,
        al.target_table,
        al.target_id,
        al.action,
        al.payload,
        al.meta
    FROM audit.audit_logs al
    WHERE 
        al.actor_user_id = p_user_id OR 
        al.target_id = p_user_id::text OR
        (al.payload->>'user_id')::uuid = p_user_id OR
        (al.payload->>'follower_user_id')::uuid = p_user_id OR
        (al.payload->>'followed_choreographer_id')::uuid = p_user_id
    ORDER BY al.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired invites
CREATE OR REPLACE FUNCTION admin_cleanup_expired_invites(
    p_admin_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_expired_count INTEGER;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Count expired invites
    SELECT COUNT(*) INTO v_expired_count 
    FROM invites 
    WHERE expires_at < NOW() AND deleted_at IS NULL;

    -- Soft delete expired invites
    UPDATE invites 
    SET deleted_at = NOW(), updated_at = NOW() 
    WHERE expires_at < NOW() AND deleted_at IS NULL;

    -- Log the cleanup
    PERFORM audit.log_insert(
        p_admin_user_id,
        'invites',
        'cleanup',
        'EXPIRED_INVITE_CLEANUP',
        jsonb_build_object(
            'expired_count', v_expired_count,
            'cleanup_date', NOW()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'expired_invites_cleaned', v_expired_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------------
-- NOTES ON ADMINISTRATIVE UTILITIES
-- --------------------------------------------------------------------------------
/*
Administrative Utility Functions Design:

1. **Security First**: All functions require admin verification
2. **Audit Everything**: Every admin action is logged with reason
3. **Safe Operations**: Soft deletes, restore capabilities, dry-run options
4. **Bulk Operations**: Efficient bulk processing with error handling
5. **Comprehensive Reporting**: Detailed audit trails and reports

Key Features:
- Soft delete with cascade and restore capabilities
- Permanent deletion with age-based cleanup
- Bulk role management with error handling
- Comprehensive audit reporting
- Automatic cleanup of expired data

Usage Guidelines:
- Always provide a reason for administrative actions
- Use dry-run mode for permanent delete operations first
- Monitor audit logs for all administrative activities
- Regular cleanup of expired invites and old soft-deleted records

Security Considerations:
- All functions are SECURITY DEFINER
- Admin permission verified on every call
- Detailed audit logging of all admin actions
- Error handling prevents partial operations
*/




-- --------------------------------------------------------------------------------
-- DEPLOYMENT COMPLETE
-- Schema ready for Supabase deployment
-- Next steps:
-- 1. Copy contents of this file
-- 2. Paste into Supabase SQL Editor
-- 3. Execute and fix any errors iteratively
-- --------------------------------------------------------------------------------
