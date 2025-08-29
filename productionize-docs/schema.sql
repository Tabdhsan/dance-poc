-- --------------------------------------------------------------------------------
-- Muvv.nyc - PostgreSQL Database Schema DDL
-- Converted from table-schema.md to proper PostgreSQL syntax
-- --------------------------------------------------------------------------------

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------------------
-- Core Tables
-- --------------------------------------------------------------------------------

-- Users table - Core user authentication and role management
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role TEXT NOT NULL DEFAULT 'dancer' CHECK (role IN ('dancer', 'choreographer', 'admin')),
    full_name TEXT,
    email TEXT NOT NULL UNIQUE,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- Choreographer profiles table - Public-facing choreographer information
CREATE TABLE choreographer_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE RESTRICT,
    display_name TEXT NOT NULL,
    bio TEXT,
    profile_picture_url TEXT,
    social_links JSONB,
    url_slug TEXT UNIQUE,
    view_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- Classes table - Dance class listings and details
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'SOFT_DELETE', 'RESTORE')),
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_role TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Additional context for specific operations
    operation_context JSONB
);

-- --------------------------------------------------------------------------------
-- JSONB Validation Constraints
-- --------------------------------------------------------------------------------

-- Validate social_links structure for choreographer_profiles
ALTER TABLE choreographer_profiles 
ADD CONSTRAINT social_links_validation 
CHECK (
    social_links IS NULL OR (
        jsonb_typeof(social_links) = 'object' AND 
        jsonb_array_length(jsonb_object_keys(social_links)) <= 10
    )
);

-- --------------------------------------------------------------------------------
-- Essential Indexes for Performance
-- --------------------------------------------------------------------------------

-- Users table indexes
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON users(id) WHERE deleted_at IS NULL;

-- Choreographer profiles indexes
CREATE INDEX idx_profiles_url_slug ON choreographer_profiles(url_slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_active ON choreographer_profiles(user_id) WHERE deleted_at IS NULL;

-- Classes table indexes
CREATE INDEX idx_classes_timestamp ON classes(class_timestamp) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_choreographer ON classes(choreographer_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_style ON classes(style) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_borough ON classes(borough) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_skill_level ON classes(skill_level) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_active ON classes(id) WHERE deleted_at IS NULL;

-- Class watchlists indexes
CREATE INDEX idx_watchlists_user ON class_watchlists(user_id);
CREATE INDEX idx_watchlists_class ON class_watchlists(class_id);
CREATE INDEX idx_watchlists_created_at ON class_watchlists(created_at);

-- Choreographer follows indexes
CREATE INDEX idx_follows_follower ON choreographer_follows(follower_user_id);
CREATE INDEX idx_follows_followed ON choreographer_follows(followed_choreographer_id);
CREATE INDEX idx_follows_created_at ON choreographer_follows(created_at);

-- Invites table indexes
CREATE INDEX idx_invites_token ON invites(token) WHERE deleted_at IS NULL;
CREATE INDEX idx_invites_email ON invites(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_invites_expires_at ON invites(expires_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_invites_active ON invites(id) WHERE deleted_at IS NULL;

-- Audit logs table indexes
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_audit_logs_operation ON audit_logs(operation, created_at);
CREATE INDEX idx_audit_logs_table_operation ON audit_logs(table_name, operation, created_at);

-- View count indexes for analytics
CREATE INDEX idx_profiles_view_count ON choreographer_profiles(view_count DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_classes_view_count ON classes(view_count DESC) WHERE deleted_at IS NULL;

-- --------------------------------------------------------------------------------
-- Comments for Documentation
-- --------------------------------------------------------------------------------

COMMENT ON TABLE users IS 'Core user authentication and role management';
COMMENT ON COLUMN users.id IS 'UUID primary key, links to auth.users.id in Supabase Auth';
COMMENT ON COLUMN users.role IS 'User role: dancer, choreographer, or admin';
COMMENT ON COLUMN users.deleted_at IS 'Soft delete timestamp - NULL means active';

COMMENT ON TABLE choreographer_profiles IS 'Public-facing choreographer information and social presence';
COMMENT ON COLUMN choreographer_profiles.social_links IS 'JSONB object with social media links, max 10 entries';
COMMENT ON COLUMN choreographer_profiles.url_slug IS 'Unique URL slug for choreographer profile pages';
COMMENT ON COLUMN choreographer_profiles.view_count IS 'Number of times this choreographer profile has been viewed';

COMMENT ON TABLE classes IS 'Dance class listings and scheduling information';
COMMENT ON COLUMN classes.class_timestamp IS 'When the class is scheduled to occur';
COMMENT ON COLUMN classes.price IS 'Class price in dollars, 2 decimal places';
COMMENT ON COLUMN classes.view_count IS 'Number of times this class has been viewed';

COMMENT ON TABLE class_watchlists IS 'Many-to-many relationship tracking user interest in classes';

COMMENT ON TABLE choreographer_follows IS 'Many-to-many relationship for social following between users';

COMMENT ON TABLE invites IS 'Phase 1 influencer invitation system for controlled onboarding';
COMMENT ON COLUMN invites.token IS 'Cryptographically secure invite token';
COMMENT ON COLUMN invites.used_by IS 'User who consumed this invite token';

COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all critical database operations';
COMMENT ON COLUMN audit_logs.table_name IS 'Name of the table that was modified';
COMMENT ON COLUMN audit_logs.record_id IS 'UUID of the record that was modified';
COMMENT ON COLUMN audit_logs.operation IS 'Type of operation: INSERT, UPDATE, DELETE, SOFT_DELETE, RESTORE';
COMMENT ON COLUMN audit_logs.old_values IS 'JSONB snapshot of record values before the change';
COMMENT ON COLUMN audit_logs.new_values IS 'JSONB snapshot of record values after the change';
COMMENT ON COLUMN audit_logs.changed_fields IS 'Array of field names that were modified';
COMMENT ON COLUMN audit_logs.operation_context IS 'Additional context specific to the operation (e.g., cascade info, bulk operation details)';

-- --------------------------------------------------------------------------------
-- Row Level Security (RLS) - Enable but policies will be added in later subtasks
-- --------------------------------------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Note: RLS policies will be implemented in Subtask 2.5: Audit Integration & Security
