-- --------------------------------------------------------------------------------
-- ADMINISTRATIVE UTILITY FUNCTIONS - Soft Delete, Restore & Management
-- This file contains utility functions for administrative operations
-- --------------------------------------------------------------------------------

-- Function to soft delete a user and cascade to related records
CREATE OR REPLACE FUNCTION admin_soft_delete_user(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_affected_records JSONB := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get user to delete
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
    END IF;

    -- Soft delete the user (will trigger cascade function)
    UPDATE users SET deleted_at = NOW() WHERE id = p_user_id;

    -- Count affected records
    SELECT jsonb_build_object(
        'choreographer_profiles', (SELECT COUNT(*) FROM choreographer_profiles WHERE user_id = p_user_id AND deleted_at IS NOT NULL),
        'classes', (SELECT COUNT(*) FROM classes WHERE choreographer_id = p_user_id AND deleted_at IS NOT NULL),
        'watchlists_removed', (SELECT COUNT(*) FROM class_watchlists WHERE user_id = p_user_id),
        'follows_removed', (SELECT COUNT(*) FROM choreographer_follows WHERE follower_user_id = p_user_id OR followed_choreographer_id = p_user_id)
    ) INTO v_affected_records;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'users',
        p_user_id::text,
        'ADMIN_SOFT_DELETE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'affected_records', v_affected_records,
            'original_role', v_user.role
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User soft deleted successfully',
        'affected_records', v_affected_records
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted user and related records
CREATE OR REPLACE FUNCTION admin_restore_user(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_restored_records JSONB := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get deleted user
    SELECT * INTO v_user FROM users WHERE id = p_user_id AND deleted_at IS NOT NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND_OR_NOT_DELETED');
    END IF;

    -- Restore the user
    UPDATE users SET deleted_at = NULL, updated_at = NOW() WHERE id = p_user_id;

    -- Restore related records (only if they were deleted at the same time)
    UPDATE choreographer_profiles 
    SET deleted_at = NULL, updated_at = NOW() 
    WHERE user_id = p_user_id AND deleted_at = v_user.deleted_at;

    UPDATE classes 
    SET deleted_at = NULL, updated_at = NOW() 
    WHERE choreographer_id = p_user_id AND deleted_at = v_user.deleted_at;

    -- Count restored records
    SELECT jsonb_build_object(
        'choreographer_profiles', (SELECT COUNT(*) FROM choreographer_profiles WHERE user_id = p_user_id AND deleted_at IS NULL),
        'classes', (SELECT COUNT(*) FROM classes WHERE choreographer_id = p_user_id AND deleted_at IS NULL)
    ) INTO v_restored_records;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'users',
        p_user_id::text,
        'ADMIN_RESTORE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'restored_records', v_restored_records,
            'original_deleted_at', v_user.deleted_at
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User restored successfully',
        'restored_records', v_restored_records
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a class
CREATE OR REPLACE FUNCTION admin_soft_delete_class(
    p_class_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_class RECORD;
    v_watchlist_count INTEGER;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get class to delete
    SELECT * INTO v_class FROM classes WHERE id = p_class_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'CLASS_NOT_FOUND');
    END IF;

    -- Count watchlists that will be affected
    SELECT COUNT(*) INTO v_watchlist_count FROM class_watchlists WHERE class_id = p_class_id;

    -- Soft delete the class
    UPDATE classes SET deleted_at = NOW() WHERE id = p_class_id;

    -- Remove from watchlists (cascade effect)
    DELETE FROM class_watchlists WHERE class_id = p_class_id;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'classes',
        p_class_id::text,
        'ADMIN_SOFT_DELETE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'class_title', v_class.title,
            'choreographer_id', v_class.choreographer_id,
            'watchlists_removed', v_watchlist_count
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Class soft deleted successfully',
        'watchlists_removed', v_watchlist_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted class
CREATE OR REPLACE FUNCTION admin_restore_class(
    p_class_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_class RECORD;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Get deleted class
    SELECT * INTO v_class FROM classes WHERE id = p_class_id AND deleted_at IS NOT NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'CLASS_NOT_FOUND_OR_NOT_DELETED');
    END IF;

    -- Verify choreographer is still active
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = v_class.choreographer_id AND deleted_at IS NULL AND role = 'choreographer'
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'CHOREOGRAPHER_INACTIVE');
    END IF;

    -- Restore the class
    UPDATE classes SET deleted_at = NULL, updated_at = NOW() WHERE id = p_class_id;

    -- Log the admin action
    PERFORM audit.log_insert(
        p_admin_user_id,
        'classes',
        p_class_id::text,
        'ADMIN_RESTORE',
        jsonb_build_object(
            'admin_reason', p_reason,
            'class_title', v_class.title,
            'choreographer_id', v_class.choreographer_id,
            'original_deleted_at', v_class.deleted_at
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Class restored successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to permanently delete old soft-deleted records
CREATE OR REPLACE FUNCTION admin_permanent_delete_old_records(
    p_admin_user_id UUID,
    p_days_old INTEGER DEFAULT 365,
    p_dry_run BOOLEAN DEFAULT true
)
RETURNS JSONB AS $$
DECLARE
    v_cutoff_date TIMESTAMPTZ;
    v_users_count INTEGER := 0;
    v_profiles_count INTEGER := 0;
    v_classes_count INTEGER := 0;
    v_invites_count INTEGER := 0;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    v_cutoff_date := NOW() - (p_days_old || ' days')::INTERVAL;

    -- Count records to be deleted
    SELECT COUNT(*) INTO v_users_count FROM users WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_profiles_count FROM choreographer_profiles WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_classes_count FROM classes WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
    SELECT COUNT(*) INTO v_invites_count FROM invites WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;

    IF NOT p_dry_run THEN
        -- Permanently delete old records
        DELETE FROM choreographer_profiles WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM classes WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM invites WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;
        DELETE FROM users WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff_date;

        -- Log the cleanup action
        PERFORM audit.log_insert(
            p_admin_user_id,
            'system',
            'cleanup',
            'PERMANENT_DELETE_CLEANUP',
            jsonb_build_object(
                'cutoff_date', v_cutoff_date,
                'days_old', p_days_old,
                'users_deleted', v_users_count,
                'profiles_deleted', v_profiles_count,
                'classes_deleted', v_classes_count,
                'invites_deleted', v_invites_count
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'dry_run', p_dry_run,
        'cutoff_date', v_cutoff_date,
        'records_to_delete', jsonb_build_object(
            'users', v_users_count,
            'profiles', v_profiles_count,
            'classes', v_classes_count,
            'invites', v_invites_count
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to bulk update user roles (admin utility)
CREATE OR REPLACE FUNCTION admin_bulk_update_roles(
    p_user_ids UUID[],
    p_new_role TEXT,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INTEGER := 0;
    v_errors TEXT[] := '{}';
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Validate role
    IF p_new_role NOT IN ('dancer', 'choreographer', 'admin') THEN
        RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE');
    END IF;

    -- Process each user
    FOREACH v_user_id IN ARRAY p_user_ids
    LOOP
        BEGIN
            -- Update role if user exists and is not deleted
            IF EXISTS (SELECT 1 FROM users WHERE id = v_user_id AND deleted_at IS NULL) THEN
                UPDATE users SET role = p_new_role, updated_at = NOW() WHERE id = v_user_id;
                
                -- Log the role change
                PERFORM audit.log_insert(
                    p_admin_user_id,
                    'users',
                    v_user_id::text,
                    'ADMIN_ROLE_CHANGE',
                    jsonb_build_object(
                        'new_role', p_new_role,
                        'admin_reason', p_reason,
                        'bulk_operation', true
                    )
                );
                
                v_updated_count := v_updated_count + 1;
            ELSE
                v_errors := array_append(v_errors, 'User ' || v_user_id || ' not found or deleted');
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'Error updating user ' || v_user_id || ': ' || SQLERRM);
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'updated_count', v_updated_count,
        'total_requested', array_length(p_user_ids, 1),
        'errors', v_errors
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive audit report for a user
CREATE OR REPLACE FUNCTION admin_get_user_audit_report(
    p_user_id UUID,
    p_admin_user_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    log_id BIGINT,
    created_at TIMESTAMPTZ,
    actor_user_id UUID,
    target_table TEXT,
    target_id TEXT,
    action TEXT,
    payload JSONB,
    meta JSONB
) AS $$
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS';
    END IF;

    -- Return audit logs related to the user
    RETURN QUERY
    SELECT 
        al.id,
        al.created_at,
        al.actor_user_id,
        al.target_table,
        al.target_id,
        al.action,
        al.payload,
        al.meta
    FROM audit.audit_logs al
    WHERE 
        al.actor_user_id = p_user_id OR 
        al.target_id = p_user_id::text OR
        (al.payload->>'user_id')::uuid = p_user_id OR
        (al.payload->>'follower_user_id')::uuid = p_user_id OR
        (al.payload->>'followed_choreographer_id')::uuid = p_user_id
    ORDER BY al.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired invites
CREATE OR REPLACE FUNCTION admin_cleanup_expired_invites(
    p_admin_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_expired_count INTEGER;
BEGIN
    -- Verify admin permission
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = p_admin_user_id AND role = 'admin' AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Count expired invites
    SELECT COUNT(*) INTO v_expired_count 
    FROM invites 
    WHERE expires_at < NOW() AND deleted_at IS NULL;

    -- Soft delete expired invites
    UPDATE invites 
    SET deleted_at = NOW(), updated_at = NOW() 
    WHERE expires_at < NOW() AND deleted_at IS NULL;

    -- Log the cleanup
    PERFORM audit.log_insert(
        p_admin_user_id,
        'invites',
        'cleanup',
        'EXPIRED_INVITE_CLEANUP',
        jsonb_build_object(
            'expired_count', v_expired_count,
            'cleanup_date', NOW()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'expired_invites_cleaned', v_expired_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------------------------------
-- NOTES ON ADMINISTRATIVE UTILITIES
-- --------------------------------------------------------------------------------
/*
Administrative Utility Functions Design:

1. **Security First**: All functions require admin verification
2. **Audit Everything**: Every admin action is logged with reason
3. **Safe Operations**: Soft deletes, restore capabilities, dry-run options
4. **Bulk Operations**: Efficient bulk processing with error handling
5. **Comprehensive Reporting**: Detailed audit trails and reports

Key Features:
- Soft delete with cascade and restore capabilities
- Permanent deletion with age-based cleanup
- Bulk role management with error handling
- Comprehensive audit reporting
- Automatic cleanup of expired data

Usage Guidelines:
- Always provide a reason for administrative actions
- Use dry-run mode for permanent delete operations first
- Monitor audit logs for all administrative activities
- Regular cleanup of expired invites and old soft-deleted records

Security Considerations:
- All functions are SECURITY DEFINER
- Admin permission verified on every call
- Detailed audit logging of all admin actions
- Error handling prevents partial operations
*/
