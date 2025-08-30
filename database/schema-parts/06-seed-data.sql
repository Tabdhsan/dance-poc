-- --------------------------------------------------------------------------------
-- SEED DATA & CONFIGURATION - Initial Subscription Tiers & Reference Data
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Insert initial features
INSERT INTO features (name, description) VALUES
  ('browse_classes', 'Allows browsing and viewing class listings (always available)'),
  ('watchlist', 'Allows a user to add a class to their watchlist'),
  ('follow', 'Allows a user to follow a choreographer'),
  ('class_management', 'Allows a choreographer to create, update, and delete class listings'),

-- Dancer tiers (without JSONB features column)
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents) VALUES
('dancer', 'free', 'Free Dancer', 'Basic access to browse and like classes', 0),

-- Choreographer tiers (without JSONB features column)
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents) VALUES
('choreographer', 'basic', 'Basic Choreographer', 'Essential tools for choreographers', 2999),

-- Assign features to dancer tiers
INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'dancer', 'free', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow');


-- Assign features to choreographer tiers  
INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'choreographer', 'basic', f.id FROM features f 
WHERE f.name IN ('browse_classes', 'watchlist', 'follow', 'class_management');
