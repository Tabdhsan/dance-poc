-- --------------------------------------------------------------------------------
-- SEED DATA & CONFIGURATION - Initial Subscription Tiers & Reference Data
-- Extracted from master schema.sql for focused editing
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
