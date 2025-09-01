-- --------------------------------------------------------------------------------
-- SEED DATA & CONFIGURATION - Initial Subscription Tiers & Reference Data
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Insert initial features (all available features in the system)
INSERT INTO features (name, description) VALUES
  -- ('browse_classes', 'Allows browsing and viewing class listings (always available)'),
  ('watchlist', 'Allows a user to add a class to their watchlist'),
  ('follow', 'Allows a user to follow a choreographer'),
  ('class_management', 'Allows a choreographer to create, update, and delete class listings')
  -- ('profile_management', 'Allows a choreographer to manage their public profile'),
  -- ('analytics', 'Allows a choreographer to view basic analytics'),
  -- ('advanced_analytics', 'Allows a choreographer to view detailed analytics and insights'),
  -- ('priority_listing', 'Allows a choreographer to get priority placement in search results'),
  -- ('unlimited_classes', 'Allows a choreographer to create unlimited class listings'),
  -- ('custom_branding', 'Allows a choreographer to customize their profile with custom branding'),
  -- ('email_marketing', 'Allows a choreographer to send email campaigns to followers'),
  -- ('api_access', 'Allows a choreographer to access the API for integrations')
ON CONFLICT (name) DO NOTHING;

-- Dancer tiers
-- INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents, billing_interval, is_active) VALUES
-- ('dancer', 'free', 'Free Dancer', 'Basic access to browse and like classes', 0, 'monthly', true),
-- ('dancer', 'premium', 'Premium Dancer', 'Enhanced features for serious dancers', 999, 'monthly', true),
-- ('dancer', 'premium_yearly', 'Premium Dancer (Yearly)', 'Enhanced features for serious dancers - yearly discount', 9999, 'yearly', true)
-- ON CONFLICT (role, tier_name) DO NOTHING;

-- Choreographer tiers
INSERT INTO subscription_tiers (role, tier_name, display_name, description, price_cents, billing_interval, is_active) VALUES
('choreographer', 'invited', 'Invited Choreographer', 'Paid Features without a subscription', 0, 'lifetime', true)
-- ('choreographer', 'basic', 'Basic Choreographer', 'Essential tools for choreographers (free for invited users)', 0, 'monthly', true),
-- ('choreographer', 'professional', 'Professional Choreographer', 'Advanced tools for professional choreographers', 2999, 'monthly', true),
-- ('choreographer', 'professional_yearly', 'Professional Choreographer (Yearly)', 'Advanced tools for professional choreographers - yearly discount', 29999, 'yearly', true),
-- ('choreographer', 'premium', 'Premium Choreographer', 'Premium features for established choreographers', 4999, 'monthly', true),
-- ('choreographer', 'premium_yearly', 'Premium Choreographer (Yearly)', 'Premium features for established choreographers - yearly discount', 49999, 'yearly', true)
ON CONFLICT (role, tier_name) DO NOTHING;

-- Assign features to dancer tiers
-- Free Dancer: Basic browsing and social features
INSERT INTO tier_features (tier_role, tier_name, feature_id)
SELECT 'choreographer', 'invited', f.id FROM features f 
WHERE f.name IN ('watchlist', 'follow', 'class_management')
ON CONFLICT (tier_role, tier_name, feature_id) DO NOTHING;