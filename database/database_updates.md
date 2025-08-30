## Database Schema Updates: Normalized Feature Management System

### Overview
This document outlines the changes needed to move from a JSONB-based feature system to a normalized, database-driven approach. This will make permissions scalable, maintainable, and properly validated.

### Current State
- Features are stored as JSONB in `subscription_tiers.features` column
- No validation or referential integrity
- Difficult to manage and scale

### Target State  
- Normalized `features` table for all available permissions
- `tier_features` join table linking tiers to features
- Updated functions to use new table structure
- RLS policies enforcing feature-based permissions

## Step 1: Update Schema Files

### 1.1 Modify `01-core-tables.sql`

**Task**: Add two new tables for the normalized feature system.

**Location**: Add after the existing `audit_logs` table (around line 150)

**Add this code**:
```sql
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
    -- Foreign key to the subscription_tiers table and features table
    FOREIGN KEY (tier_role, tier_name) REFERENCES subscription_tiers(role, tier_name) ON DELETE CASCADE
    FOREIGN KEY (feature_id) REFERENCES features(id) ON DELETE CASCADE
);
```

**Task**: Remove the JSONB features column from subscription_tiers table.

**Location**: Around line 34, find this line:
```sql
features JSONB NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(features) = 'object'),
```

**Action**: Delete that entire line.

### 1.2 Modify `04-indexes.sql`

**Task**: Add index for the new tier_features table.

**Location**: Add at the end of the file

**Add this code**:
```sql
-- Indexes for normalized feature system
CREATE INDEX idx_tier_features_feature_id ON tier_features(feature_id);
CREATE INDEX idx_tier_features_tier ON tier_features(tier_role, tier_name);
```

### 1.3 Modify `06-seed-data.sql`

**Task**: Replace the current subscription_tiers inserts with new approach.

**Current lines to replace**: Lines 7-18 (the entire INSERT statements with JSONB features)

**Replace with**:
```sql
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
```

## Step 2: Update Function Files

### 2.1 Modify `03-auth-functions.sql`

**Task**: Replace the existing `user_has_feature()` function to use the new normalized tables.

**Location**: Find the existing `user_has_feature()` function (around lines 52-60)

**Current function to replace**:
```sql
CREATE OR REPLACE FUNCTION user_has_feature(p_user_id UUID, p_feature TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_features JSONB;
BEGIN
    SELECT get_user_features(p_user_id) INTO v_features;
    RETURN COALESCE((v_features->>p_feature)::boolean, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Replace with**:
```sql
CREATE OR REPLACE FUNCTION user_has_feature(p_user_id UUID, p_feature_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_role TEXT;
  v_tier_name TEXT;
  v_subscription_status TEXT;
BEGIN
  -- Get the user's current role, tier, and subscription status
  SELECT
    u.role,
    SPLIT_PART(u.subscription_tier, '_', 2),
    u.subscription_status
  INTO
    v_user_role,
    v_tier_name,
    v_subscription_status
  FROM users u
  WHERE u.id = p_user_id AND u.deleted_at IS NULL;

  -- If user not found or subscription is not active, they have no features
  IF NOT FOUND OR v_subscription_status != 'active' THEN
    RETURN false;
  END IF;

  -- Check if a link exists between the user's tier and the requested feature
  RETURN EXISTS (
    SELECT 1
    FROM tier_features tf
    JOIN features f ON tf.feature_id = f.id
    WHERE tf.tier_role = v_user_role
      AND tf.tier_name = v_tier_name
      AND f.name = p_feature_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Task**: Replace the existing `get_user_features()` function to use the new normalized tables.

**Location**: Find the existing `get_user_features()` function (around lines 7-49)

**Current function to replace**: The entire function that queries `subscription_tiers.features`

**Replace with**:
```sql
CREATE OR REPLACE FUNCTION get_user_features(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_features JSONB;
BEGIN
    -- This query finds the user's active tier, joins to get all assigned feature names,
    -- and aggregates them into a single JSONB object like {"feature_name": true, ...}.
    SELECT COALESCE(
        jsonb_object_agg(f.name, true),
        '{}'::jsonb
    )
    INTO v_features
    FROM users u
    JOIN tier_features tf ON tf.tier_role = u.role AND tf.tier_name = SPLIT_PART(u.subscription_tier, '_', 2)
    JOIN features f ON tf.feature_id = f.id
    WHERE u.id = p_user_id
      AND u.subscription_status = 'active'
      AND u.deleted_at IS NULL;

    RETURN v_features;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Step 3: Update RLS Policy Files

### 3.1 Modify `07-rls-policies.sql`

**Task**: Update existing policies to include feature permission checks.

**Location 1**: Find the `watchlists_insert_policy` (around line 159)

**Current policy to replace**:
```sql
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
```

**Replace with**:
```sql
CREATE POLICY "watchlists_insert_policy" ON class_watchlists
  FOR INSERT
  WITH CHECK (
    user_id = get_current_user_id() AND
    user_has_feature(get_current_user_id(), 'watchlist') AND
    EXISTS (
      SELECT 1 FROM classes c
      JOIN users u ON c.choreographer_id = u.id
      WHERE c.id = class_id
        AND c.deleted_at IS NULL
        AND u.deleted_at IS NULL
        AND u.role = 'choreographer'
    )
  );
```

**Location 2**: Find the `follows_insert_policy` (around line 194)

**Current policy to replace**:
```sql
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
```

**Replace with**:
```sql
CREATE POLICY "follows_insert_policy" ON choreographer_follows
  FOR INSERT
  WITH CHECK (
    follower_user_id = get_current_user_id() AND
    user_has_feature(get_current_user_id(), 'follow') AND
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = followed_choreographer_id
        AND u.deleted_at IS NULL
        AND u.role = 'choreographer'
    )
  );
```

**Location 3**: Find the `classes_insert_policy` (around line 137)

**Current policy to replace**:
```sql
CREATE POLICY "classes_insert_policy" ON classes
  FOR INSERT
  WITH CHECK (
    (choreographer_id = get_current_user_id() AND is_choreographer()) OR
    is_admin()
  );
```

**Replace with**:
```sql
CREATE POLICY "classes_insert_policy" ON classes
  FOR INSERT
  WITH CHECK (
    (
      choreographer_id = get_current_user_id() AND
      is_choreographer() AND
      user_has_feature(get_current_user_id(), 'create_class')
    ) OR is_admin()
  );
```

**Location 4**: Find the `classes_update_policy` (around line 131)

**Current policy to replace**:
```sql
CREATE POLICY "classes_update_policy" ON classes
  FOR UPDATE
  USING (choreographer_id = get_current_user_id() OR is_admin())
  WITH CHECK (choreographer_id = get_current_user_id() OR is_admin());
```

**Replace with**:
```sql
CREATE POLICY "classes_update_policy" ON classes
  FOR UPDATE
  USING (choreographer_id = get_current_user_id() OR is_admin())
  WITH CHECK (
    (
      choreographer_id = get_current_user_id() AND
      user_has_feature(get_current_user_id(), 'edit_class')
    ) OR is_admin()
  );
```

**Task**: Add RLS policies for the new tables.

**Location**: Add at the end of the file, before the "GRANT PERMISSIONS" section (around line 320)

**Add this code**:
```sql
-- --------------------------------------------------------------------------------
-- FEATURES AND TIER_FEATURES TABLE POLICIES  
-- --------------------------------------------------------------------------------

-- Enable RLS on new tables
ALTER TABLE features ENABLE ROW LEVEL SECURITY;
ALTER TABLE tier_features ENABLE ROW LEVEL SECURITY;

-- Features table policies (read-only for most users)
CREATE POLICY "features_select_policy" ON features
  FOR SELECT
  USING (true); -- Features are publicly readable

CREATE POLICY "features_admin_policy" ON features
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Tier features policies (read-only for most users) 
CREATE POLICY "tier_features_select_policy" ON tier_features
  FOR SELECT
  USING (true); -- Tier features are publicly readable

CREATE POLICY "tier_features_admin_policy" ON tier_features
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());
```

**Task**: Update the GRANT section to include new tables.

**Location**: Find the GRANT section (around line 325-334)

**Add these lines** after the existing GRANT statements:
```sql
GRANT SELECT ON features TO authenticated; -- Read-only
GRANT SELECT ON tier_features TO authenticated; -- Read-only
```

---

## Summary

These changes transform the permission system from a JSONB-based approach to a normalized, database-driven feature management system that:

1. **Ensures data integrity** through proper foreign key relationships
2. **Scales easily** by adding new features and tier assignments  
3. **Provides audit trails** through the normalized structure
4. **Enforces permissions** at the database level via RLS policies
5. **Maintains performance** through proper indexing