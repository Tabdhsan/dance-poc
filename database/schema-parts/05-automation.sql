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
