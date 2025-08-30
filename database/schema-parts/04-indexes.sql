-- --------------------------------------------------------------------------------
-- INDEXES & PERFORMANCE - All Database Indexes for Optimization
-- Extracted from master schema.sql for focused editing
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
CREATE INDEX idx_invites_active ON invites(id) WHERE deleted_at IS NULL AND expires_at > NOW() AND is_used = false;

-- Audit logs table indexes
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;

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
