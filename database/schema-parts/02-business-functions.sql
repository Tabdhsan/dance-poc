-- --------------------------------------------------------------------------------
-- BUSINESS LOGIC FUNCTIONS - Core Discovery & Analytics Functions
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Function for class discovery with search and filtering capabilities
-- Returns class details pre-sorted for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Supports flexible sorting and comprehensive filtering
CREATE OR REPLACE FUNCTION discover_classes(
    p_search_text TEXT DEFAULT NULL,  -- Optional text search in class title only
    p_styles TEXT[] DEFAULT NULL,     -- Array of styles for OR filtering
    p_borough TEXT DEFAULT NULL,
    p_location_name TEXT DEFAULT NULL,
    p_choreographer_id UUID DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NOW(),
    p_to_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    -- Essential class info only
    id UUID,
    title TEXT,
    description TEXT,
    style TEXT,
    skill_level TEXT,
    location_name TEXT,
    borough TEXT,
    price NUMERIC,
    booking_url TEXT,
    class_timestamp TIMESTAMPTZ,
    choreographer_note TEXT,
    
    -- Choreographer info
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Input validation
    IF p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'from_date cannot be greater than to_date';
    END IF;

    -- Execute the main query - always sorted by timestamp
    RETURN QUERY
    SELECT 
        c.id,
        c.title,
        c.description,
        c.style,
        c.skill_level,
        c.location_name,
        c.borough,
        c.price,
        c.booking_url,
        c.class_timestamp,
        c.choreographer_note,
        c.choreographer_id,
        c.choreographer_display_name,
        c.choreographer_url_slug,
        c.created_at
            
        WHERE 
            -- Date range filtering
            c.class_timestamp >= p_from_date
            AND (p_to_date IS NULL OR c.class_timestamp <= p_to_date)
            -- Optional filters
            AND (p_styles IS NULL OR c.style = ANY(p_styles))
            AND (p_borough IS NULL OR c.borough = p_borough)
            AND (p_location_name IS NULL OR c.location_name ILIKE '%' || p_location_name || '%')
            AND (p_choreographer_id IS NULL OR c.choreographer_id = p_choreographer_id)
            -- Optional text search in class title
            AND (p_search_text IS NULL OR 
                 p_search_text = '' OR 
                 to_tsvector('english', COALESCE(c.title, '')) @@ plainto_tsquery('english', p_search_text))
    ORDER BY c.class_timestamp ASC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for choreographer discovery with search and filtering capabilities
-- Returns choreographer profiles for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Supports filtering by class style, upcoming classes, and name search
CREATE OR REPLACE FUNCTION discover_choreographers(
    p_search_name TEXT DEFAULT NULL,  -- Optional text search in choreographer name
    p_class_styles TEXT[] DEFAULT NULL, -- Array of styles for OR filtering
    p_has_upcoming_classes BOOLEAN DEFAULT NULL -- Filter by choreographers with upcoming classes
)
RETURNS TABLE (
    -- Essential choreographer info only
    user_id UUID,
    display_name TEXT,
    bio TEXT,
    profile_picture_url TEXT,
    url_slug TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Execute the main query with filtering
    RETURN QUERY
    SELECT DISTINCT
        cp.user_id,
        cp.display_name,
        cp.bio,
        cp.profile_picture_url,
        cp.url_slug,
        cp.created_at
    FROM active_choreographer_profiles cp
    
    -- Optional JOIN for style filtering
    LEFT JOIN active_classes c ON cp.user_id = c.choreographer_id
        AND (p_class_styles IS NULL OR c.style = ANY(p_class_styles))
        AND (p_has_upcoming_classes IS NULL OR 
             (p_has_upcoming_classes = true AND c.class_timestamp > NOW()) OR
             (p_has_upcoming_classes = false))
    
    WHERE 
        -- Name search filtering
        (p_search_name IS NULL OR 
         p_search_name = '' OR 
         to_tsvector('english', COALESCE(cp.display_name, '')) @@ plainto_tsquery('english', p_search_name))
        
        -- Style filtering (ensure choreographer teaches this style)
        AND (p_class_styles IS NULL OR c.choreographer_id IS NOT NULL)
        
        -- Upcoming classes filtering
        AND (p_has_upcoming_classes IS NULL OR
             (p_has_upcoming_classes = true AND EXISTS (
                 SELECT 1 FROM active_classes ac 
                 WHERE ac.choreographer_id = cp.user_id 
                 AND ac.class_timestamp > NOW()
             )) OR
             (p_has_upcoming_classes = false AND NOT EXISTS (
                 SELECT 1 FROM active_classes ac 
                 WHERE ac.choreographer_id = cp.user_id 
                 AND ac.class_timestamp > NOW()
             )))
    
    ORDER BY cp.created_at DESC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive choreographer analytics for dashboard
CREATE OR REPLACE FUNCTION get_choreographer_analytics(
    p_choreographer_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_choreographer RECORD;
    v_follower_count INTEGER;
    v_profile_views INTEGER;
    v_total_classes INTEGER;
    v_total_class_views INTEGER;
    v_total_watchlists INTEGER;
    v_upcoming_classes INTEGER;
    v_upcoming_class_views INTEGER;
    v_upcoming_watchlists INTEGER;
    v_result JSONB;
BEGIN
    -- Authorization handled by RLS policies - function assumes caller is authorized

    -- Get choreographer data (RLS will handle access control)
    SELECT u.*, cp.view_count as profile_view_count INTO v_choreographer
    FROM active_users u
    JOIN active_choreographer_profiles cp ON u.id = cp.user_id
    WHERE u.id = p_choreographer_id AND u.role = 'choreographer';

    IF NOT FOUND THEN
        -- RLS either blocked access or choreographer doesn't exist
        -- This is the correct behavior - no need to distinguish
        RAISE EXCEPTION 'Choreographer not found or access denied';
    END IF;

    -- Get follower count
    SELECT COUNT(*) INTO v_follower_count
    FROM choreographer_follows cf
    JOIN active_users u ON cf.follower_user_id = u.id
    WHERE cf.followed_choreographer_id = p_choreographer_id;

    -- Get profile views
    v_profile_views := v_choreographer.profile_view_count;

    -- Get class metrics (all-time and upcoming)
    SELECT 
        -- All-time metrics
        COUNT(*) as total_classes,
        COALESCE(SUM(c.view_count), 0) as total_class_views,
        COALESCE(SUM(cw_count.watchlist_count), 0) as total_watchlists,
        -- Upcoming class metrics
        SUM(CASE WHEN c.class_timestamp > NOW() THEN 1 ELSE 0 END) as upcoming_classes,
        COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN c.view_count ELSE 0 END), 0) as upcoming_class_views,
        COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN cw_count.watchlist_count ELSE 0 END), 0) as upcoming_watchlists
    INTO v_total_classes, v_total_class_views, v_total_watchlists, 
         v_upcoming_classes, v_upcoming_class_views, v_upcoming_watchlists
    FROM active_classes c
    LEFT JOIN (
        SELECT class_id, COUNT(*) as watchlist_count
        FROM class_watchlists
        GROUP BY class_id
    ) cw_count ON c.id = cw_count.class_id
    WHERE c.choreographer_id = p_choreographer_id;

    -- Handle case where choreographer has no classes
    v_total_classes := COALESCE(v_total_classes, 0);
    v_total_class_views := COALESCE(v_total_class_views, 0);
    v_total_watchlists := COALESCE(v_total_watchlists, 0);
    v_upcoming_classes := COALESCE(v_upcoming_classes, 0);
    v_upcoming_class_views := COALESCE(v_upcoming_class_views, 0);
    v_upcoming_watchlists := COALESCE(v_upcoming_watchlists, 0);

    -- Build final result
    v_result := JSONB_BUILD_OBJECT(
        'follower_count', v_follower_count,
        'profile_views', v_profile_views,
        -- All-time metrics
        'total_classes', v_total_classes,
        'total_class_views', v_total_class_views,
        'total_watchlists', v_total_watchlists,
        -- Upcoming class metrics
        'upcoming_classes', v_upcoming_classes,
        'upcoming_class_views', v_upcoming_class_views,
        'upcoming_watchlists', v_upcoming_watchlists,
        'generated_at', NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get "hot" choreographers sorted by computed hotness score
-- This powers the HEAT feature for discovering trending choreographers
-- Returns choreographer profiles pre-sorted by hotness for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
CREATE OR REPLACE FUNCTION get_hot_choreographers()
RETURNS TABLE (
    -- Essential choreographer info only
    user_id UUID,
    display_name TEXT,
    bio TEXT,
    profile_picture_url TEXT,
    url_slug TEXT,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    -- Hotness score weights - easily adjustable for algorithm tuning
    WEIGHT_UPCOMING_WATCHLISTS REAL := 0.5;    -- 50% - most important for current momentum
    WEIGHT_UPCOMING_VIEWS REAL := 0.25;        -- 25% - engagement with current classes
    WEIGHT_FOLLOWER_COUNT REAL := 0.1;         -- 10% - established popularity
    WEIGHT_PROFILE_VIEWS REAL := 0.15;         -- 15% - general interest
BEGIN
    -- Execute the main query with computed hotness score for sorting
    -- Hotness metrics are calculated but not returned to keep FE clean
    RETURN QUERY
    WITH choreographer_metrics AS (
        SELECT 
            cp.user_id,
            cp.display_name,
            cp.bio,
            cp.profile_picture_url,
            cp.url_slug,
            cp.created_at,
            
            -- Hotness score calculation using named constants
            -- Computed for sorting but not returned to frontend
            (
                (COALESCE(cm.upcoming_watchlists, 0) * WEIGHT_UPCOMING_WATCHLISTS) +
                (COALESCE(cm.upcoming_class_views, 0) * WEIGHT_UPCOMING_VIEWS) +
                (COALESCE(fc.follower_count, 0) * WEIGHT_FOLLOWER_COUNT) +
                (cp.view_count * WEIGHT_PROFILE_VIEWS)
            )::REAL as hotness_score
            
        FROM active_choreographer_profiles cp
        
        -- Follower count subquery
        LEFT JOIN (
            SELECT 
                followed_choreographer_id,
                COUNT(*) as follower_count
            FROM choreographer_follows cf
            JOIN active_users au ON cf.follower_user_id = au.id
            GROUP BY followed_choreographer_id
        ) fc ON cp.user_id = fc.followed_choreographer_id
        
        -- Upcoming class metrics subquery
        LEFT JOIN (
            SELECT 
                c.choreographer_id,
                COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN c.view_count ELSE 0 END), 0) as upcoming_class_views,
                COALESCE(SUM(CASE WHEN c.class_timestamp > NOW() THEN cw.watchlist_count ELSE 0 END), 0) as upcoming_watchlists
            FROM active_classes c
            LEFT JOIN (
                SELECT 
                    class_id,
                    COUNT(*) as watchlist_count
                FROM class_watchlists
                GROUP BY class_id
            ) cw ON c.id = cw.class_id
            GROUP BY c.choreographer_id
        ) cm ON cp.user_id = cm.choreographer_id
    )
    SELECT 
        cm.user_id,
        cm.display_name,
        cm.bio,
        cm.profile_picture_url,
        cm.url_slug,
        cm.created_at
    FROM choreographer_metrics cm
    ORDER BY cm.hotness_score DESC, cm.created_at DESC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get "hot" classes sorted by computed hotness score
-- This powers the HEAT feature for discovering trending classes
-- Returns class details pre-sorted by hotness for frontend display
-- Compatible with Supabase's built-in pagination (.range()) for infinite scroll
-- Only returns upcoming classes
CREATE OR REPLACE FUNCTION get_hot_classes(
    p_styles TEXT[] DEFAULT NULL,  -- Array of styles for OR filtering
    p_borough TEXT DEFAULT NULL
)
RETURNS TABLE (
    -- Essential class info only
    id UUID,
    title TEXT,
    description TEXT,
    style TEXT,
    skill_level TEXT,
    location_name TEXT,
    borough TEXT,
    price NUMERIC,
    booking_url TEXT,
    class_timestamp TIMESTAMPTZ,
    choreographer_note TEXT,
    
    -- Choreographer info
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    -- Hotness score weights - easily adjustable for algorithm tuning
    WEIGHT_WATCHLISTS REAL := 0.6;     -- 60% - watchlist engagement (primary signal)
    WEIGHT_VIEWS REAL := 0.4;          -- 40% - view engagement
BEGIN
    -- Execute the main query with computed hotness score for sorting
    -- Hotness metrics are calculated but not returned to keep FE clean
    RETURN QUERY
    WITH class_metrics AS (
        SELECT 
            c.id,
            c.title,
            c.description,
            c.style,
            c.skill_level,
            c.location_name,
            c.borough,
            c.price,
            c.booking_url,
            c.class_timestamp,
            c.choreographer_note,
            c.choreographer_id,
            c.choreographer_display_name,
            c.choreographer_url_slug,
            c.created_at,
            
            -- Hotness score calculation using named constants
            -- Note: view_count still used for scoring but not returned to FE
            (
                (COALESCE(wc.watchlist_count, 0) * WEIGHT_WATCHLISTS) +
                (c.view_count * WEIGHT_VIEWS)
            )::REAL as hotness_score
            
        FROM active_classes c
        
        -- Watchlist count subquery
        LEFT JOIN (
            SELECT 
                cw.class_id,
                COUNT(*) as watchlist_count
            FROM class_watchlists cw
            JOIN active_users u ON cw.user_id = u.id
            GROUP BY cw.class_id
        ) wc ON c.id = wc.class_id
        
        WHERE 
            -- Only upcoming classes
            c.class_timestamp > NOW()
            -- Optional filters
            AND (p_styles IS NULL OR c.style = ANY(p_styles))
            AND (p_borough IS NULL OR c.borough = p_borough)
    )
    SELECT 
        cm.id,
        cm.title,
        cm.description,
        cm.style,
        cm.skill_level,
        cm.location_name,
        cm.borough,
        cm.price,
        cm.booking_url,
        cm.class_timestamp,
        cm.choreographer_note,
        cm.choreographer_id,
        cm.choreographer_display_name,
        cm.choreographer_url_slug,
        cm.created_at,
    FROM class_metrics cm
    ORDER BY cm.hotness_score DESC, cm.class_timestamp ASC;
    -- No LIMIT - let Supabase handle pagination via .range(from, to)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
