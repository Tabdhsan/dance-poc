# Core Database Automation Architecture

## Overview

This document outlines the core automation layer of the Muvv database, including automatic timestamp management, soft delete cascading, active record views, and utility functions. This automation ensures data consistency, simplifies application logic, and provides clean interfaces for working with soft-deleted records.

## Automatic Timestamp Management

### Universal Trigger Function

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Purpose**: Automatically updates the `updated_at` timestamp whenever a record is modified.

**Applied to Tables**:
- `users`
- `choreographer_profiles` 
- `classes`
- `invites`
- `subscription_tiers`
- `subscriptions`

**Benefits**:
- Eliminates need for application-level timestamp management
- Ensures consistent timestamp behavior across all updates
- Prevents forgotten timestamp updates in application code

## Active Record Views

### Overview
Active record views provide clean interfaces for accessing non-deleted records, automatically filtering out soft-deleted entries.

### active_users
```sql
CREATE VIEW active_users AS
SELECT u.*, get_user_features(u.id) as features
FROM users u WHERE u.deleted_at IS NULL;
```

**Usage**: Replace direct `users` table queries in application code. Includes subscription features automatically.

### active_choreographer_profiles
```sql
CREATE VIEW active_choreographer_profiles AS
SELECT cp.*, u.subscription_tier, u.subscription_status
FROM choreographer_profiles cp
JOIN users u ON cp.user_id = u.id
WHERE cp.deleted_at IS NULL AND u.deleted_at IS NULL AND u.role = 'choreographer' AND u.subscription_status = 'active';
```

**Usage**: For public choreographer directory, profile lookups, and profile management. Only shows active subscribers.

### active_classes
```sql
CREATE VIEW active_classes AS
SELECT c.*, cp.display_name as choreographer_display_name, cp.url_slug as choreographer_url_slug, u.subscription_status
FROM classes c
JOIN users u ON c.choreographer_id = u.id
JOIN choreographer_profiles cp ON u.id = cp.user_id
WHERE c.deleted_at IS NULL AND u.deleted_at IS NULL AND cp.deleted_at IS NULL AND u.role = 'choreographer' AND u.subscription_status = 'active';
```

**Features**:
- Filters out deleted classes
- Includes choreographer information for convenience
- Only shows classes from active choreographer subscribers
- Includes subscription status for business logic

**Usage**: Primary view for class listings, search, and detail pages.

## Soft Delete Cascading

### User Deletion Cascade Logic

When a user is soft deleted (`deleted_at` set), the following automatic cascading occurs:

```sql
CREATE OR REPLACE FUNCTION cascade_user_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        -- Soft delete choreographer profile
        UPDATE choreographer_profiles SET deleted_at = NEW.deleted_at WHERE user_id = NEW.id AND deleted_at IS NULL;
        
        -- Soft delete all classes created by this choreographer
        UPDATE classes SET deleted_at = NEW.deleted_at WHERE choreographer_id = NEW.id AND deleted_at IS NULL;
        
        -- Cancel subscriptions
        UPDATE subscriptions SET status = 'cancelled', cancelled_at = NEW.deleted_at WHERE user_id = NEW.id AND status != 'cancelled';
        
        -- Hard delete social relationships
        DELETE FROM choreographer_follows WHERE follower_user_id = NEW.id OR followed_choreographer_id = NEW.id;
        DELETE FROM class_watchlists WHERE user_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Cascade Behavior

#### Soft Delete Cascade
- **Choreographer Profile**: Soft deleted with same timestamp
- **Classes**: All classes by this choreographer are soft deleted
- **Subscriptions**: Cancelled with cancellation timestamp
- **Social Relationships**: Hard deleted (follows, watchlists)

#### Restoration Cascade
- **Choreographer Profile**: Restored if deleted at same time as user
- **Classes**: Restored if deleted at same time as user
- **Subscriptions**: Must be manually reactivated (business decision)
- **Social Relationships**: Not restored (user must re-follow/re-watchlist)

### Rationale for Mixed Approach

**Soft Delete (Preserves Data)**:
- `choreographer_profiles`: Business value in preserving profile history
- `classes`: Analytics value in class creation patterns
- `users`: Audit trail and potential account recovery

**Subscription Cancellation (Preserves Records)**:
- `subscriptions`: Payment history and billing audit trail

**Hard Delete (Clean Removal)**:
- `choreographer_follows`: Privacy - clean removal of social connections
- `class_watchlists`: Preference data with no business value when relationship ends

## View Count Management

### Increment Functions

```sql
-- Increment class view count
CREATE OR REPLACE FUNCTION increment_class_view_count(class_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE classes SET view_count = view_count + 1 
    WHERE id = class_uuid AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Increment profile view count  
CREATE OR REPLACE FUNCTION increment_profile_view_count(profile_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE choreographer_profiles SET view_count = view_count + 1 
    WHERE user_id = profile_user_id AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;
```

### Usage Patterns

**Application Integration**:
```javascript
// When user views a class detail page
await supabase.rpc('increment_class_view_count', { class_uuid: classId });

// When user views a choreographer profile
await supabase.rpc('increment_profile_view_count', { profile_user_id: userId });
```

**Benefits**:
- Atomic increment operations
- Automatic soft-delete checking
- Consistent interface for view tracking

## Application Integration Guidelines

### Query Patterns

**Instead of**: `SELECT * FROM users WHERE some_condition`
**Use**: `SELECT * FROM active_users WHERE some_condition`

**Instead of**: `SELECT * FROM classes WHERE some_condition`  
**Use**: `SELECT * FROM active_classes WHERE some_condition`

**Instead of**: `SELECT * FROM choreographer_profiles WHERE some_condition`
**Use**: `SELECT * FROM active_choreographer_profiles WHERE some_condition`

### Performance Considerations

- Views add minimal overhead as they're query rewrites
- Existing indexes on base tables apply to views
- Soft delete cascading triggers add write overhead but ensure consistency
- View count functions are lightweight atomic operations

### Error Handling

- View count functions silently handle deleted records (no-op)
- Cascade triggers are atomic within transaction boundaries
- Failed cascades will rollback the entire user deletion operation

## Trigger Dependencies

### Execution Order
1. **BEFORE UPDATE**: `update_updated_at_column()` - Updates timestamp
2. **AFTER UPDATE**: `cascade_user_soft_delete()` - Handles cascading

### Trigger Safety
- Triggers are idempotent (safe to run multiple times)
- Cascade logic checks for state changes to avoid infinite loops
- All operations are atomic within transaction boundaries

## Testing Scenarios

### Timestamp Management
```sql
-- Test automatic updated_at
UPDATE users SET full_name = 'New Name' WHERE id = 'some-uuid';
-- Verify: updated_at should be automatically set to NOW()
```

### Soft Delete Cascading
```sql
-- Test user soft delete cascade
UPDATE users SET deleted_at = NOW() WHERE id = 'choreographer-uuid';
-- Verify: choreographer_profiles.deleted_at is set
-- Verify: all classes by this choreographer have deleted_at set
-- Verify: social relationships are hard deleted
```

### View Functionality
```sql
-- Test active views filter correctly
SELECT COUNT(*) FROM users; -- includes deleted
SELECT COUNT(*) FROM active_users; -- excludes deleted
```

### View Count Increment
```sql
-- Test view count increments
SELECT view_count FROM classes WHERE id = 'class-uuid';
SELECT increment_class_view_count('class-uuid');
SELECT view_count FROM classes WHERE id = 'class-uuid'; -- should be +1
```

## Future Enhancements

- **Batch Operations**: Bulk soft delete/restore functions
- **Audit Integration**: Connect cascading operations to audit log
- **Performance Monitoring**: Track trigger execution times
- **Advanced Cascading**: Configurable cascade depth and rules
- **Restoration Logic**: More sophisticated restoration with user choice
