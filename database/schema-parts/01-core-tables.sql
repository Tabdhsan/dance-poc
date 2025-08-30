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
