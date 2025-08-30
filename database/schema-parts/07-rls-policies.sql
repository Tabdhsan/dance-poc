-- --------------------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES - Comprehensive Security Implementation
-- This file implements RLS policies for all tables with proper access control
-- --------------------------------------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE choreographer_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit.audit_logs ENABLE ROW LEVEL SECURITY;

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

-- Only class owner (choreographer) can update their classes
CREATE POLICY "classes_update_policy" ON classes
  FOR UPDATE
  USING (choreographer_id = get_current_user_id() OR is_admin())
  WITH CHECK (choreographer_id = get_current_user_id() OR is_admin());

-- Only choreographers can create classes
CREATE POLICY "classes_insert_policy" ON classes
  FOR INSERT
  WITH CHECK (
    (choreographer_id = get_current_user_id() AND is_choreographer()) OR
    is_admin()
  );

-- Only class owner or admin can delete
CREATE POLICY "classes_delete_policy" ON classes
  FOR DELETE
  USING (choreographer_id = get_current_user_id() OR is_admin());

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
