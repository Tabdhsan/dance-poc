-- --------------------------------------------------------------------------------
-- BUSINESS LOGIC FUNCTIONS - Core Discovery & Analytics Functions
-- Extracted from master schema.sql for focused editing
-- --------------------------------------------------------------------------------

-- Function to get classes with watchlist counts ("Heat" calculation) and comprehensive filtering
CREATE OR REPLACE FUNCTION get_classes_with_watchlist_count(
    p_limit INTEGER DEFAULT 50,
    p_cursor_timestamp TIMESTAMPTZ DEFAULT NOW(),
    p_style TEXT DEFAULT NULL,
    p_borough TEXT DEFAULT NULL,
    p_choreographer_id UUID DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NOW(),
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'timestamp', -- 'timestamp' | 'heat' | 'created'
    p_sort_direction TEXT DEFAULT 'ASC' -- 'ASC' | 'DESC'
)
RETURNS TABLE (
    -- Core class fields
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
    view_count INTEGER,
    
    -- Choreographer info (from active_classes view)
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    choreographer_subscription_status TEXT,
    
    -- The "Heat" calculation - watchlist count
    watchlist_count BIGINT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_order_clause TEXT;
    v_query TEXT;
BEGIN
    -- Input validation
    IF p_limit <= 0 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Limit must be between 1 and 100, got: %', p_limit;
    END IF;

    IF p_sort_by NOT IN ('timestamp', 'heat', 'created') THEN
        RAISE EXCEPTION 'Invalid sort_by value: %. Use: timestamp, heat, created', p_sort_by;
    END IF;

    IF p_sort_direction NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'Invalid sort_direction value: %. Use: ASC, DESC', p_sort_direction;
    END IF;

    IF p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'from_date cannot be greater than to_date';
    END IF;

    -- Build dynamic ORDER BY clause
    v_order_clause := CASE 
        WHEN p_sort_by = 'timestamp' THEN 'c.class_timestamp'
        WHEN p_sort_by = 'heat' THEN 'COALESCE(COUNT(cw.class_id), 0)'
        WHEN p_sort_by = 'created' THEN 'c.created_at'
    END || ' ' || p_sort_direction;

    -- Add secondary sort for consistent pagination (especially important for heat sorting)
    IF p_sort_by != 'timestamp' THEN
        v_order_clause := v_order_clause || ', c.class_timestamp ASC';
    END IF;

    -- Execute the main query
    RETURN QUERY EXECUTE format('
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
            c.view_count,
            c.choreographer_id,
            c.choreographer_display_name,
            c.choreographer_url_slug,
            c.subscription_status as choreographer_subscription_status,
            COALESCE(COUNT(cw.class_id), 0) as watchlist_count,
            c.created_at,
            c.updated_at
        FROM active_classes c
        LEFT JOIN class_watchlists cw ON c.id = cw.class_id
        WHERE 
            -- Date range filtering
            c.class_timestamp >= $1
            AND ($2 IS NULL OR c.class_timestamp <= $2)
            -- Cursor pagination (only for timestamp sorting)
            AND ($3 != ''timestamp'' OR c.class_timestamp >= $4)
            -- Optional filters
            AND ($5 IS NULL OR c.style = $5)
            AND ($6 IS NULL OR c.borough = $6)
            AND ($7 IS NULL OR c.choreographer_id = $7)
        GROUP BY 
            c.id, c.title, c.description, c.style, c.skill_level,
            c.location_name, c.borough, c.price, c.booking_url,
            c.class_timestamp, c.choreographer_note, c.view_count,
            c.choreographer_id, c.choreographer_display_name, 
            c.choreographer_url_slug, c.subscription_status,
            c.created_at, c.updated_at
        ORDER BY %s
        LIMIT $8'
    , v_order_clause)
    USING p_from_date, p_to_date, p_sort_by, p_cursor_timestamp, 
          p_style, p_borough, p_choreographer_id, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for comprehensive class search and filtering with text search capabilities
CREATE OR REPLACE FUNCTION search_and_filter_classes(
    p_limit INTEGER DEFAULT 50,
    p_cursor_timestamp TIMESTAMPTZ DEFAULT NOW(),
    p_search_text TEXT DEFAULT NULL,  -- Text search in title, choreographer name, location
    p_style TEXT DEFAULT NULL,
    p_borough TEXT DEFAULT NULL,
    p_location_name TEXT DEFAULT NULL,
    p_choreographer_id UUID DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NOW(),
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'timestamp', -- 'timestamp' | 'heat' | 'created' | 'relevance'
    p_sort_direction TEXT DEFAULT 'ASC' -- 'ASC' | 'DESC'
)
RETURNS TABLE (
    -- Core class fields
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
    view_count INTEGER,
    
    -- Choreographer info (from active_classes view)
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    choreographer_subscription_status TEXT,
    
    -- Search relevance score (for text search)
    search_rank REAL,
    
    -- The "Heat" calculation - watchlist count
    watchlist_count BIGINT,
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_order_clause TEXT;
    v_query TEXT;
    v_search_query TEXT := '';
    v_using_params TEXT;
    v_param_count INTEGER := 0;
BEGIN
    -- Input validation
    IF p_limit <= 0 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Limit must be between 1 and 100, got: %', p_limit;
    END IF;

    IF p_sort_by NOT IN ('timestamp', 'heat', 'created', 'relevance') THEN
        RAISE EXCEPTION 'Invalid sort_by value: %. Use: timestamp, heat, created, relevance', p_sort_by;
    END IF;

    IF p_sort_direction NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'Invalid sort_direction value: %. Use: ASC, DESC', p_sort_direction;
    END IF;

    IF p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'from_date cannot be greater than to_date';
    END IF;

    -- Validate text search requirements
    IF p_sort_by = 'relevance' AND (p_search_text IS NULL OR trim(p_search_text) = '') THEN
        RAISE EXCEPTION 'search_text is required when sorting by relevance';
    END IF;

    -- Build text search components if search_text is provided
    IF p_search_text IS NOT NULL AND trim(p_search_text) != '' THEN
        v_search_query := '
            -- Text search rank calculation
            (
                -- Title search (highest weight)
                ts_rank_cd(to_tsvector(''english'', COALESCE(c.title, '''')), plainto_tsquery(''english'', $' || (v_param_count + 9) || ')) * 4.0 +
                -- Choreographer name search (high weight)
                ts_rank_cd(to_tsvector(''english'', COALESCE(c.choreographer_display_name, '''')), plainto_tsquery(''english'', $' || (v_param_count + 9) || ')) * 3.0 +
                -- Location search (medium weight)
                ts_rank_cd(to_tsvector(''english'', COALESCE(c.location_name, '''')), plainto_tsquery(''english'', $' || (v_param_count + 9) || ')) * 2.0 +
                -- Description search (low weight)
                ts_rank_cd(to_tsvector(''english'', COALESCE(c.description, '''')), plainto_tsquery(''english'', $' || (v_param_count + 9) || ')) * 1.0
            ) as search_rank,';
        v_param_count := v_param_count + 1;
    ELSE
        v_search_query := '0.0 as search_rank,';
    END IF;

    -- Build dynamic ORDER BY clause
    v_order_clause := CASE 
        WHEN p_sort_by = 'timestamp' THEN 'c.class_timestamp'
        WHEN p_sort_by = 'heat' THEN 'COALESCE(COUNT(cw.class_id), 0)'
        WHEN p_sort_by = 'created' THEN 'c.created_at'
        WHEN p_sort_by = 'relevance' THEN 'search_rank'
    END || ' ' || p_sort_direction;

    -- Add secondary sort for consistent pagination
    IF p_sort_by = 'relevance' THEN
        v_order_clause := v_order_clause || ', c.class_timestamp ASC';
    ELSIF p_sort_by != 'timestamp' THEN
        v_order_clause := v_order_clause || ', c.class_timestamp ASC';
    END IF;

    -- Execute the main query
    v_query := format('
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
            c.view_count,
            c.choreographer_id,
            c.choreographer_display_name,
            c.choreographer_url_slug,
            c.subscription_status as choreographer_subscription_status,
            %s
            COALESCE(COUNT(cw.class_id), 0) as watchlist_count,
            c.created_at,
            c.updated_at
        FROM active_classes c
        LEFT JOIN class_watchlists cw ON c.id = cw.class_id
        WHERE 
            -- Date range filtering
            c.class_timestamp >= $1
            AND ($2 IS NULL OR c.class_timestamp <= $2)
            -- Cursor pagination (only for timestamp sorting)
            AND ($3 != ''timestamp'' OR c.class_timestamp >= $4)
            -- Optional filters
            AND ($5 IS NULL OR c.style = $5)
            AND ($6 IS NULL OR c.borough = $6)
            AND ($7 IS NULL OR c.location_name ILIKE ''%%'' || $7 || ''%%'')
            AND ($8 IS NULL OR c.choreographer_id = $8)
            %s
        GROUP BY 
            c.id, c.title, c.description, c.style, c.skill_level,
            c.location_name, c.borough, c.price, c.booking_url,
            c.class_timestamp, c.choreographer_note, c.view_count,
            c.choreographer_id, c.choreographer_display_name, 
            c.choreographer_url_slug, c.subscription_status,
            c.created_at, c.updated_at
        %s
        ORDER BY %s
        LIMIT $9'
    , v_search_query
    , CASE WHEN p_search_text IS NOT NULL AND trim(p_search_text) != '' THEN
        '-- Text search filtering
        AND (
            to_tsvector(''english'', COALESCE(c.title, '''')) @@ plainto_tsquery(''english'', $10)
            OR to_tsvector(''english'', COALESCE(c.choreographer_display_name, '''')) @@ plainto_tsquery(''english'', $10)
            OR to_tsvector(''english'', COALESCE(c.location_name, '''')) @@ plainto_tsquery(''english'', $10)
            OR to_tsvector(''english'', COALESCE(c.description, '''')) @@ plainto_tsquery(''english'', $10)
        )'
      ELSE ''
      END
    , CASE WHEN p_search_text IS NOT NULL AND trim(p_search_text) != '' THEN
        ', search_rank'
      ELSE ''
      END
    , v_order_clause);

    -- Execute with the appropriate parameters
    IF p_search_text IS NOT NULL AND trim(p_search_text) != '' THEN
        RETURN QUERY EXECUTE v_query
        USING p_from_date, p_to_date, p_sort_by, p_cursor_timestamp, 
              p_style, p_borough, p_location_name, p_choreographer_id, p_limit, p_search_text;
    ELSE
        RETURN QUERY EXECUTE v_query
        USING p_from_date, p_to_date, p_sort_by, p_cursor_timestamp, 
              p_style, p_borough, p_location_name, p_choreographer_id, p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive choreographer analytics for dashboard
CREATE OR REPLACE FUNCTION get_choreographer_analytics(
    p_choreographer_id UUID,
    p_requesting_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_choreographer RECORD;
    v_follower_count INTEGER;
    v_profile_views INTEGER;
    v_total_classes INTEGER;
    v_total_class_views INTEGER;
    v_total_watchlists INTEGER;
    v_class_details JSONB;
    v_result JSONB;
BEGIN
    -- Authorization: Only choreographers can view their own analytics
    IF p_requesting_user_id != p_choreographer_id THEN
        RAISE EXCEPTION 'Unauthorized: Can only view your own analytics';
    END IF;

    -- Verify choreographer exists and is active
    SELECT u.*, cp.view_count as profile_view_count INTO v_choreographer
    FROM active_users u
    JOIN active_choreographer_profiles cp ON u.id = cp.user_id
    WHERE u.id = p_choreographer_id AND u.role = 'choreographer';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Choreographer not found or inactive';
    END IF;

    -- Get follower count
    SELECT COUNT(*) INTO v_follower_count
    FROM choreographer_follows cf
    JOIN active_users u ON cf.follower_user_id = u.id
    WHERE cf.followed_choreographer_id = p_choreographer_id;

    -- Get profile views
    v_profile_views := v_choreographer.profile_view_count;

    -- Get class metrics and detailed breakdown
    WITH class_metrics AS (
        SELECT 
            c.id,
            c.title,
            c.view_count,
            c.class_timestamp,
            c.style,
            c.skill_level,
            COALESCE(COUNT(cw.class_id), 0) as watchlist_count
        FROM active_classes c
        LEFT JOIN class_watchlists cw ON c.id = cw.class_id
        WHERE c.choreographer_id = p_choreographer_id
        GROUP BY c.id, c.title, c.view_count, c.class_timestamp, c.style, c.skill_level
    )
    SELECT 
        COUNT(*) as total_classes,
        COALESCE(SUM(view_count), 0) as total_class_views,
        COALESCE(SUM(watchlist_count), 0) as total_watchlists,
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'class_id', id,
                'title', title,
                'views', view_count,
                'watchlists', watchlist_count,
                'class_timestamp', class_timestamp,
                'style', style,
                'skill_level', skill_level
            ) ORDER BY class_timestamp DESC
        ) as class_details
    INTO v_total_classes, v_total_class_views, v_total_watchlists, v_class_details
    FROM class_metrics;

    -- Handle case where choreographer has no classes
    v_total_classes := COALESCE(v_total_classes, 0);
    v_total_class_views := COALESCE(v_total_class_views, 0);
    v_total_watchlists := COALESCE(v_total_watchlists, 0);
    v_class_details := COALESCE(v_class_details, '[]'::jsonb);

    -- Build final result
    v_result := JSONB_BUILD_OBJECT(
        'follower_count', v_follower_count,
        'profile_views', v_profile_views,
        'total_classes', v_total_classes,
        'total_class_views', v_total_class_views,
        'total_watchlists', v_total_watchlists,
        'classes', v_class_details,
        'subscription_tier', v_choreographer.subscription_tier,
        'generated_at', NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get most popular choreographers by follower count and engagement
CREATE OR REPLACE FUNCTION get_most_popular_choreographers(
    p_limit INTEGER DEFAULT 20,
    p_sort_by TEXT DEFAULT 'followers', -- 'followers' | 'engagement' | 'classes' | 'views'
    p_sort_direction TEXT DEFAULT 'DESC' -- 'ASC' | 'DESC'
)
RETURNS TABLE (
    -- Choreographer info
    user_id UUID,
    display_name TEXT,
    bio TEXT,
    profile_picture_url TEXT,
    url_slug TEXT,
    subscription_tier TEXT,
    
    -- Popularity metrics
    follower_count BIGINT,
    profile_views INTEGER,
    total_classes BIGINT,
    total_class_views BIGINT,
    total_watchlists BIGINT,
    
    -- Engagement score (computed metric)
    engagement_score REAL,
    
    -- Timestamps
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    v_order_clause TEXT;
BEGIN
    -- Input validation
    IF p_limit <= 0 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Limit must be between 1 and 100, got: %', p_limit;
    END IF;

    IF p_sort_by NOT IN ('followers', 'engagement', 'classes', 'views') THEN
        RAISE EXCEPTION 'Invalid sort_by value: %. Use: followers, engagement, classes, views', p_sort_by;
    END IF;

    IF p_sort_direction NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'Invalid sort_direction value: %. Use: ASC, DESC', p_sort_direction;
    END IF;

    -- Build dynamic ORDER BY clause
    v_order_clause := CASE 
        WHEN p_sort_by = 'followers' THEN 'follower_count'
        WHEN p_sort_by = 'engagement' THEN 'engagement_score'
        WHEN p_sort_by = 'classes' THEN 'total_classes'
        WHEN p_sort_by = 'views' THEN 'total_class_views'
    END || ' ' || p_sort_direction;

    -- Add secondary sort for consistent results
    v_order_clause := v_order_clause || ', cp.created_at DESC';

    -- Execute the main query with computed engagement score
    RETURN QUERY EXECUTE format('
        WITH choreographer_metrics AS (
            SELECT 
                cp.user_id,
                cp.display_name,
                cp.bio,
                cp.profile_picture_url,
                cp.url_slug,
                cp.created_at,
                u.subscription_tier,
                cp.view_count as profile_views,
                
                -- Follower count
                COALESCE(fc.follower_count, 0) as follower_count,
                
                -- Class metrics
                COALESCE(cm.total_classes, 0) as total_classes,
                COALESCE(cm.total_class_views, 0) as total_class_views,
                COALESCE(cm.total_watchlists, 0) as total_watchlists,
                
                -- Engagement score calculation (weighted formula)
                -- Followers (40%%) + Profile views (20%%) + Class watchlists (25%%) + Class views (15%%)
                (
                    (COALESCE(fc.follower_count, 0) * 0.4) +
                    (cp.view_count * 0.2) +
                    (COALESCE(cm.total_watchlists, 0) * 0.25) +
                    (COALESCE(cm.total_class_views, 0) * 0.15)
                )::REAL as engagement_score
                
            FROM active_choreographer_profiles cp
            JOIN active_users u ON cp.user_id = u.id
            
            -- Follower count subquery
            LEFT JOIN (
                SELECT 
                    followed_choreographer_id,
                    COUNT(*) as follower_count
                FROM choreographer_follows cf
                JOIN active_users au ON cf.follower_user_id = au.id
                GROUP BY followed_choreographer_id
            ) fc ON cp.user_id = fc.followed_choreographer_id
            
            -- Class metrics subquery
            LEFT JOIN (
                SELECT 
                    c.choreographer_id,
                    COUNT(*) as total_classes,
                    COALESCE(SUM(c.view_count), 0) as total_class_views,
                    COALESCE(SUM(cw.watchlist_count), 0) as total_watchlists
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
            user_id,
            display_name,
            bio,
            profile_picture_url,
            url_slug,
            subscription_tier,
            follower_count,
            profile_views,
            total_classes,
            total_class_views,
            total_watchlists,
            engagement_score,
            created_at
        FROM choreographer_metrics
        ORDER BY %s
        LIMIT $1'
    , v_order_clause)
    USING p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get trending classes by watchlist activity within time periods
CREATE OR REPLACE FUNCTION get_trending_classes(
    p_limit INTEGER DEFAULT 20,
    p_time_period TEXT DEFAULT '7d', -- '1d' | '3d' | '7d' | '30d' | 'all'
    p_from_date TIMESTAMPTZ DEFAULT NOW(),
    p_style TEXT DEFAULT NULL,
    p_borough TEXT DEFAULT NULL,
    p_sort_direction TEXT DEFAULT 'DESC' -- 'ASC' | 'DESC'
)
RETURNS TABLE (
    -- Core class fields
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
    view_count INTEGER,
    
    -- Choreographer info
    choreographer_id UUID,
    choreographer_display_name TEXT,
    choreographer_url_slug TEXT,
    choreographer_subscription_status TEXT,
    
    -- Trending metrics
    trending_watchlist_count BIGINT,  -- Watchlists within time period
    total_watchlist_count BIGINT,     -- All-time watchlists
    trending_score REAL,              -- Computed trending score
    
    -- Timestamps
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_period_start TIMESTAMPTZ;
    v_period_interval INTERVAL;
BEGIN
    -- Input validation
    IF p_limit <= 0 OR p_limit > 100 THEN
        RAISE EXCEPTION 'Limit must be between 1 and 100, got: %', p_limit;
    END IF;

    IF p_time_period NOT IN ('1d', '3d', '7d', '30d', 'all') THEN
        RAISE EXCEPTION 'Invalid time_period value: %. Use: 1d, 3d, 7d, 30d, all', p_time_period;
    END IF;

    IF p_sort_direction NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'Invalid sort_direction value: %. Use: ASC, DESC', p_sort_direction;
    END IF;

    -- Calculate time period boundaries
    v_period_interval := CASE 
        WHEN p_time_period = '1d' THEN INTERVAL '1 day'
        WHEN p_time_period = '3d' THEN INTERVAL '3 days'
        WHEN p_time_period = '7d' THEN INTERVAL '7 days'
        WHEN p_time_period = '30d' THEN INTERVAL '30 days'
        ELSE INTERVAL '100 years' -- 'all' - effectively no time limit
    END;
    
    v_period_start := p_from_date - v_period_interval;

    -- Execute the trending query
    RETURN QUERY
    WITH trending_metrics AS (
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
            c.view_count,
            c.choreographer_id,
            c.choreographer_display_name,
            c.choreographer_url_slug,
            c.subscription_status,
            c.created_at,
            c.updated_at,
            
            -- Trending watchlists (within time period)
            COALESCE(tw.trending_count, 0) as trending_watchlist_count,
            
            -- Total watchlists (all time)
            COALESCE(aw.total_count, 0) as total_watchlist_count,
            
            -- Trending score calculation
            -- Factors: recent watchlists (60%), class age bonus (20%), total watchlists (20%)
            (
                (COALESCE(tw.trending_count, 0) * 0.6) +
                -- Age bonus: newer classes get slight boost (max 7 days)
                (CASE 
                    WHEN c.created_at > (NOW() - INTERVAL '7 days') 
                    THEN (7 - EXTRACT(DAYS FROM (NOW() - c.created_at))) * 0.2
                    ELSE 0
                END) +
                (COALESCE(aw.total_count, 0) * 0.2)
            )::REAL as trending_score
            
        FROM active_classes c
        
        -- Trending watchlists within time period
        LEFT JOIN (
            SELECT 
                cw.class_id,
                COUNT(*) as trending_count
            FROM class_watchlists cw
            JOIN active_users u ON cw.user_id = u.id
            WHERE cw.created_at >= v_period_start
            GROUP BY cw.class_id
        ) tw ON c.id = tw.class_id
        
        -- All-time watchlists
        LEFT JOIN (
            SELECT 
                cw.class_id,
                COUNT(*) as total_count
            FROM class_watchlists cw
            JOIN active_users u ON cw.user_id = u.id
            GROUP BY cw.class_id
        ) aw ON c.id = aw.class_id
        
        WHERE 
            -- Only include classes that have some trending activity OR are highly watchlisted
            (COALESCE(tw.trending_count, 0) > 0 OR COALESCE(aw.total_count, 0) >= 3)
            -- Optional filters
            AND (p_style IS NULL OR c.style = p_style)
            AND (p_borough IS NULL OR c.borough = p_borough)
            -- Only future classes
            AND c.class_timestamp > NOW()
    )
    SELECT 
        tm.id,
        tm.title,
        tm.description,
        tm.style,
        tm.skill_level,
        tm.location_name,
        tm.borough,
        tm.price,
        tm.booking_url,
        tm.class_timestamp,
        tm.choreographer_note,
        tm.view_count,
        tm.choreographer_id,
        tm.choreographer_display_name,
        tm.choreographer_url_slug,
        tm.subscription_status,
        tm.trending_watchlist_count,
        tm.total_watchlist_count,
        tm.trending_score,
        tm.created_at,
        tm.updated_at
    FROM trending_metrics tm
    ORDER BY 
        CASE WHEN p_sort_direction = 'DESC' THEN tm.trending_score END DESC,
        CASE WHEN p_sort_direction = 'ASC' THEN tm.trending_score END ASC,
        tm.class_timestamp ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
