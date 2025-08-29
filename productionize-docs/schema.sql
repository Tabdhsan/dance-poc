-- --------------------------------------------------------------------------------
-- Muvv.nyc - Complete PostgreSQL Database Schema (Master File)
-- Single file containing all tables, functions, triggers, views, and automation
-- Includes subscription management and multi-tier architecture
-- --------------------------------------------------------------------------------

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------------------
-- CORE TABLES
-- --------------------------------------------------------------------------------

-- Users table - Core user authentication and role management with subscription support
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role TEXT NOT NULL DEFAULT 'dancer' CHECK (role IN ('dancer', 'choreographer', 'admin')),
    full_name TEXT,
    email TEXT NOT NULL UNIQUE,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    last_login_at TIMESTAMPTZ,
    -- Subscription management fields
    subscription_tier TEXT NOT NULL DEFAULT 'dancer_free',
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
    features JSONB NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(features) = 'object'),
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
-- (This must be done after subscriptions table creation due to circular dependency)
ALTER TABLE users ADD CONSTRAINT fk_current_subscription 
    FOREIGN KEY (current_subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL;

-- Choreographer profiles table - Public-facing choreographer information
CREATE TABLE choreographer_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE RESTRICT,
    display_name TEXT NOT NULL,
    bio TEXT,
    profile_picture_url TEXT,
    social_links JSONB CHECK (
        social_links IS NULL OR (
            jsonb_typeof(social_links) = 'object' AND 
            jsonb_array_length(jsonb_object_keys(social_links)) <= 10
        )
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

-- --------------------------------------------------------------------------------
-- INITIAL SUBSCRIPTION TIER DATA
-- --------------------------------------------------------------------------------

-- Dancer tiers
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents, features) VALUES
('dancer', 'free', 'Free Dancer', 'Basic access to browse and like classes', 0, 
 '{"like": true, "follow": true, "watchlist": true, "browse_classes": true}'::jsonb),
('dancer', 'premium', 'Premium Dancer', 'Enhanced features with advanced search and notifications', 999, 
 '{"like": true, "follow": true, "watchlist": true, "browse_classes": true, "advanced_search": true, "notifications": true, "priority_support": true}'::jsonb);

-- Choreographer tiers  
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents, features) VALUES
('choreographer', 'basic', 'Basic Choreographer', 'Essential tools for choreographers', 2999,
 '{"create_classes": true, "basic_analytics": true, "profile_customization": true, "max_classes": 10}'::jsonb),
('choreographer', 'pro', 'Pro Choreographer', 'Advanced choreographer features', 4999,
 '{"create_classes": true, "advanced_analytics": true, "priority_listing": true, "profile_customization": true, "max_classes": null, "bulk_operations": true, "export_data": true}'::jsonb);

-- --------------------------------------------------------------------------------
-- ESSENTIAL INDEXES FOR PERFORMANCE
-- --------------------------------------------------------------------------------

-- Users table indexes
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_subscription_status_tier ON users(subscription_status, subscription_tier) WHERE deleted_at IS NULL;

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

-- Social relationship indexes
CREATE INDEX idx_watchlists_user ON class_watchlists(user_id);
CREATE INDEX idx_watchlists_class ON class_watchlists(class_id);
CREATE INDEX idx_follows_follower ON choreographer_follows(follower_user_id);
CREATE INDEX idx_follows_followed ON choreographer_follows(followed_choreographer_id);

-- Invites table indexes
CREATE INDEX idx_invites_token ON invites(token) WHERE deleted_at IS NULL;
CREATE INDEX idx_invites_active ON invites(id) WHERE deleted_at IS NULL AND expires_at > NOW() AND is_used = false;

-- Audit logs table indexes
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;

-- --------------------------------------------------------------------------------
-- SUBSCRIPTION MANAGEMENT FUNCTIONS
-- --------------------------------------------------------------------------------

-- Function to get user's available features based on subscription
CREATE OR REPLACE FUNCTION get_user_features(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_tier_features JSONB;
BEGIN
    SELECT u.subscription_tier, u.subscription_status, u.role INTO v_user
    FROM users u 
    WHERE u.id = p_user_id AND u.deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN '{}'::jsonb;
    END IF;
    
    -- Get features for user's current tier
    SELECT st.features INTO v_tier_features
    FROM subscription_tiers st
    WHERE st.role = v_user.role 
      AND st.tier_name = SPLIT_PART(v_user.subscription_tier, '_', 2)
      AND st.is_active = true;
    
    IF NOT FOUND THEN
        -- Fallback to free tier
        SELECT st.features INTO v_tier_features
        FROM subscription_tiers st
        WHERE st.role = v_user.role 
          AND st.tier_name = 'free'
          AND st.is_active = true;
    END IF;
    
    -- If subscription is not active, limit features
    IF v_user.subscription_status != 'active' THEN
        v_tier_features := jsonb_build_object(
            'like', COALESCE(v_tier_features->>'like', 'false')::boolean,
            'follow', COALESCE(v_tier_features->>'follow', 'false')::boolean,
            'watchlist', COALESCE(v_tier_features->>'watchlist', 'false')::boolean,
            'browse_classes', true
        );
    END IF;
    
    RETURN COALESCE(v_tier_features, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has specific feature
CREATE OR REPLACE FUNCTION user_has_feature(p_user_id UUID, p_feature TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_features JSONB;
BEGIN
    SELECT get_user_features(p_user_id) INTO v_features;
    RETURN COALESCE((v_features->>p_feature)::boolean, false);
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

-- --------------------------------------------------------------------------------
-- AUTH INTEGRATION FUNCTIONS
-- --------------------------------------------------------------------------------

-- Function to handle new user creation from auth.users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT;
    v_tier TEXT;
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
    
    v_tier := CASE 
        WHEN v_role = 'choreographer' THEN 'choreo_basic'
        ELSE 'dancer_free'
    END;

    INSERT INTO public.users (
        id, email, full_name, role, email_verified, last_login_at,
        subscription_tier, subscription_status, created_at, updated_at
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
        NEW.last_sign_in_at, v_tier, 'active', NEW.created_at, NEW.updated_at
    );
    
    -- Create choreographer profile if needed
    IF v_role = 'choreographer' THEN
        INSERT INTO choreographer_profiles (user_id, display_name, created_at, updated_at)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'), NOW(), NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to handle new user creation from auth.users
-- This trigger MUST be created manually in Supabase after schema deployment
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION handle_new_user();

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
        subscription_tier = 'choreo_basic',
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

-- --------------------------------------------------------------------------------
-- AUTOMATION TRIGGERS AND VIEWS
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
SELECT cp.*, u.subscription_tier, u.subscription_status
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

-- View count functions
CREATE OR REPLACE FUNCTION increment_class_view_count(class_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE classes SET view_count = view_count + 1 WHERE id = class_uuid AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_profile_view_count(profile_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE choreographer_profiles SET view_count = view_count + 1 WHERE user_id = profile_user_id AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------------------------------
-- ROW LEVEL SECURITY (Enable but policies added later)
-- --------------------------------------------------------------------------------

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------------------
-- COMMENTS FOR DOCUMENTATION
-- --------------------------------------------------------------------------------

COMMENT ON TABLE users IS 'Core user authentication and role management with subscription support';
COMMENT ON TABLE subscription_tiers IS 'Configuration of available subscription tiers per role';
COMMENT ON TABLE subscriptions IS 'Individual user subscription relationships and payment status';
COMMENT ON TABLE choreographer_profiles IS 'Public-facing choreographer information and social presence';
COMMENT ON TABLE classes IS 'Dance class listings and scheduling information';
COMMENT ON TABLE class_watchlists IS 'Many-to-many relationship tracking user interest in classes';
COMMENT ON TABLE choreographer_follows IS 'Many-to-many relationship for social following between users';
COMMENT ON TABLE invites IS 'Phase 1 influencer invitation system for controlled onboarding';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all critical database operations';

COMMENT ON FUNCTION get_user_features(UUID) IS 'Returns JSONB object of features available to user based on subscription tier and status';
COMMENT ON FUNCTION user_has_feature(UUID, TEXT) IS 'Returns boolean indicating if user has access to specific feature';
COMMENT ON FUNCTION update_subscription_status(UUID, TEXT, TEXT) IS 'Updates user subscription status and corresponding subscription record';
COMMENT ON FUNCTION handle_new_user() IS 'Trigger function to sync new users from auth.users to public.users with subscription setup. ENFORCES invite-only choreographer signup for Phase 1 security.';
COMMENT ON FUNCTION assign_choreographer_role(UUID, TEXT, UUID) IS 'Assigns choreographer role with invite validation and subscription setup';
