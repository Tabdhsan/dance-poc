-- --------------------------------------------------------------------------------
-- SEED DATA & CONFIGURATION - Initial Subscription Tiers & Reference Data
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Insert initial features
INSERT INTO features (name, description) VALUES
  ('browse_classes', 'Allows browsing and viewing class listings (always available)'),
  ('watchlist', 'Allows a user to add a class to their watchlist'),
  ('follow', 'Allows a user to follow a choreographer'),
  ('create_class', 'Allows a choreographer to create a new class listing'),
  ('edit_class', 'Allows a choreographer to edit an existing class listing'),
  ('delete_class', 'Allows a choreographer to delete their class listings'),
  ('view_analytics', 'Allows a choreographer to view their analytics dashboard'),
  ('profile_customization', 'Allows advanced profile customization features'),
  ('priority_support', 'Access to priority customer support');

-- Dancer tiers (without JSONB features column)
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents) VALUES
('dancer', 'free', 'Free Dancer', 'Basic access to browse and like classes', 0),
('dancer', 'premium', 'Premium Dancer', 'Enhanced features with advanced search and notifications', 999);

-- Choreographer tiers (without JSONB features column)
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents) VALUES
('choreographer', 'basic', 'Basic Choreographer', 'Essential tools for choreographers', 2999),
('choreographer', 'pro', 'Pro Choreographer', 'Advanced choreographer features', 4999);

-- Assign features to dancer tiers
INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'dancer', 'free', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow');

INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'dancer', 'premium', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow', 'priority_support');

-- Assign features to choreographer tiers  
INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'choreographer', 'basic', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow', 'create_class', 'edit_class', 'delete_class', 'view_analytics', 'profile_customization');

INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'choreographer', 'pro', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow', 'create_class', 'edit_class', 'delete_class', 'view_analytics', 'profile_customization', 'priority_support');
