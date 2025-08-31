-- --------------------------------------------------------------------------------
-- SUBSCRIPTION & AUTH FUNCTIONS - User Management & Authentication
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Function to get user's available features based on subscription
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
    JOIN tier_features tf ON tf.tier_role = u.role AND tf.tier_name = u.tier_name
    JOIN features f ON tf.feature_id = f.id
    WHERE u.id = p_user_id
      AND u.subscription_status = 'active'
      AND u.deleted_at IS NULL;

    RETURN v_features;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has specific feature
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
    u.tier_name,
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

-- Function to update subscription status
CREATE OR REPLACE FUNCTION update_subscription_status(
    p_user_id UUID,
    p_new_status TEXT,
    p_stripe_subscription_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_old_status TEXT;
BEGIN
    -- Get current user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
    END IF;
    
    v_old_status := v_user.subscription_status;
    
    -- Update user subscription status
    UPDATE users 
    SET subscription_status = p_new_status, updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Update corresponding subscription record if provided
    IF p_stripe_subscription_id IS NOT NULL THEN
        UPDATE subscriptions 
        SET status = p_new_status, updated_at = NOW()
        WHERE user_id = p_user_id AND stripe_subscription_id = p_stripe_subscription_id;
    END IF;
    
    RETURN jsonb_build_object('success', true, 'old_status', v_old_status, 'new_status', p_new_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle new user creation from auth.users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT;
    v_tier_name TEXT;
    v_invite_token TEXT;
    v_invite RECORD;
BEGIN
    v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'dancer');
    v_invite_token := NEW.raw_user_meta_data->>'invite_token';
    
    -- SECURITY: Choreographer role requires valid invite token
    IF v_role = 'choreographer' THEN
        IF v_invite_token IS NULL THEN
            RAISE EXCEPTION 'Choreographer signup requires invite token';
        END IF;
        
        -- Validate invite token
        SELECT * INTO v_invite FROM invites 
        WHERE token = v_invite_token 
          AND is_used = false 
          AND deleted_at IS NULL 
          AND expires_at > NOW();
          
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Invalid or expired invite token';
        END IF;
        
        -- Mark invite as used
        UPDATE invites 
        SET is_used = true, used_at = NOW(), used_by = NEW.id 
        WHERE id = v_invite.id;
    END IF;
    
    -- Set tier name to match subscription_tiers table
    v_tier_name := CASE 
        WHEN v_role = 'choreographer' THEN 'basic'
        ELSE 'free'
    END;

    INSERT INTO public.users (
        id, email, full_name, role, email_verified, last_login_at,
        tier_name, subscription_status, created_at, updated_at
    )
    VALUES (
        NEW.id, NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'),
        v_role,
        CASE 
            WHEN NEW.email_confirmed_at IS NOT NULL THEN true
            WHEN NEW.raw_user_meta_data->>'provider' = 'google' THEN true
            ELSE false
        END,
        NEW.last_sign_in_at, v_tier_name, 'active', NEW.created_at, NEW.updated_at
    );
    
    -- Create choreographer profile if needed
    IF v_role = 'choreographer' THEN
        INSERT INTO choreographer_profiles (user_id, display_name, created_at, updated_at)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'), NOW(), NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to assign choreographer role with subscription setup
CREATE OR REPLACE FUNCTION assign_choreographer_role(
    p_user_id UUID,
    p_invite_token TEXT,
    p_requesting_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_invite RECORD;
BEGIN
    -- Validate invite
    SELECT * INTO v_invite FROM invites 
    WHERE token = p_invite_token AND is_used = false AND deleted_at IS NULL AND expires_at > NOW();

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_INVITE');
    END IF;

    -- Get user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;

    -- Update user role and subscription
    UPDATE users SET 
        role = 'choreographer',
        tier_name = 'basic',
        subscription_status = 'active',
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Create choreographer profile
    INSERT INTO choreographer_profiles (user_id, display_name, created_at, updated_at)
    VALUES (p_user_id, v_user.full_name, NOW(), NOW())
    ON CONFLICT (user_id) DO NOTHING;

    -- Mark invite as used
    UPDATE invites SET is_used = true, used_at = NOW(), used_by = p_user_id WHERE id = v_invite.id;

    RETURN jsonb_build_object('success', true, 'message', 'Choreographer role assigned successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically handle new user creation from Supabase auth
-- This trigger ensures new users are properly created in the public.users table
-- and choreographer profiles are created when needed
CREATE TRIGGER trigger_handle_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
