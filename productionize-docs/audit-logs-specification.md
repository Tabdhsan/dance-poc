# Audit Logs Table Specification

## Overview

The `audit_logs` table provides comprehensive tracking of all critical database operations across the Muvv platform. This audit trail supports security monitoring, compliance requirements, debugging, and business analytics.

## Table Structure

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'SOFT_DELETE', 'RESTORE')),
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_role TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    operation_context JSONB
);
```

## Field Specifications

### Core Identification
- **`id`**: Unique identifier for each audit log entry
- **`table_name`**: Name of the table that was modified (e.g., 'users', 'classes', 'choreographer_profiles')
- **`record_id`**: UUID of the specific record that was modified
- **`operation`**: Type of operation performed

### Change Tracking
- **`old_values`**: Complete JSONB snapshot of the record before modification (NULL for INSERT)
- **`new_values`**: Complete JSONB snapshot of the record after modification (NULL for DELETE)
- **`changed_fields`**: Array of field names that were actually modified (for UPDATE operations)

### User Context
- **`user_id`**: ID of the user who performed the operation (NULL for system operations)
- **`user_role`**: Role of the user at the time of operation ('dancer', 'choreographer', 'admin')
- **`ip_address`**: IP address of the user performing the operation
- **`user_agent`**: Browser/client user agent string

### Additional Context
- **`operation_context`**: Flexible JSONB field for operation-specific metadata
- **`created_at`**: Timestamp when the audit log was created

## Operation Types

### INSERT
- Triggered when new records are created
- `old_values`: NULL
- `new_values`: Complete new record
- `changed_fields`: NULL

### UPDATE
- Triggered when existing records are modified
- `old_values`: Record state before update
- `new_values`: Record state after update
- `changed_fields`: Array of modified field names

### DELETE
- Triggered when records are permanently deleted (hard delete)
- `old_values`: Complete record before deletion
- `new_values`: NULL
- `changed_fields`: NULL

### SOFT_DELETE
- Triggered when records are soft deleted (deleted_at set)
- `old_values`: Record before soft delete
- `new_values`: Record after soft delete (with deleted_at timestamp)
- `changed_fields`: ['deleted_at']

### RESTORE
- Triggered when soft-deleted records are restored
- `old_values`: Record with deleted_at timestamp
- `new_values`: Record with deleted_at = NULL
- `changed_fields`: ['deleted_at']

## Tables Being Audited

### Critical Operations
- **`users`**: Role changes, profile updates, account deletion
- **`classes`**: Creation, updates, deletion, restoration
- **`choreographer_profiles`**: Profile changes, view count updates
- **`invites`**: Invite usage, token consumption

### Social Actions
- **`class_watchlists`**: Watchlist additions/removals
- **`choreographer_follows`**: Follow/unfollow actions

### Analytics Tracking
- Search queries, profile views, class views (via operation_context)

## Indexing Strategy

```sql
-- Core lookup patterns
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- User-specific auditing
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;

-- Operation-specific queries
CREATE INDEX idx_audit_logs_operation ON audit_logs(operation, created_at);
CREATE INDEX idx_audit_logs_table_operation ON audit_logs(table_name, operation, created_at);
```

## Integration Points

### Trigger Functions
Audit triggers will be implemented for each audited table:
- `trigger_audit_users()` - User table changes
- `trigger_audit_classes()` - Class table changes
- `trigger_audit_choreographer_profiles()` - Profile changes
- `trigger_audit_invites()` - Invite system changes
- `trigger_audit_social_actions()` - Watchlists and follows

### Application Integration
- View count increments will be audited via application-level logging
- Search queries will be logged with operation_context containing search parameters
- Bulk operations will include batch information in operation_context

### Security Integration
- All audit entries are immutable (no UPDATE or DELETE allowed on audit_logs)
- RLS policies will restrict access to admin users only
- Sensitive data will be excluded from audit snapshots (passwords, tokens)

## Usage Examples

### Track User Role Changes
```sql
SELECT 
    al.created_at,
    al.user_id,
    al.old_values->>'role' as old_role,
    al.new_values->>'role' as new_role,
    acting_user.full_name as changed_by
FROM audit_logs al
JOIN users acting_user ON al.user_id = acting_user.id
WHERE al.table_name = 'users' 
  AND al.operation = 'UPDATE'
  AND 'role' = ANY(al.changed_fields)
ORDER BY al.created_at DESC;
```

### Track Class Creation Patterns
```sql
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as classes_created
FROM audit_logs 
WHERE table_name = 'classes' 
  AND operation = 'INSERT'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date;
```

### Monitor Soft Delete Operations
```sql
SELECT 
    table_name,
    COUNT(*) as soft_deletes,
    COUNT(DISTINCT user_id) as unique_users
FROM audit_logs 
WHERE operation = 'SOFT_DELETE'
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY table_name;
```

## Performance Considerations

- Audit logs will grow rapidly; implement log rotation strategy
- Use partial indexes where possible to optimize query performance
- Consider partitioning by created_at for very large datasets
- Monitor audit trigger performance impact on write operations

## Security & Compliance

- Audit logs support compliance requirements (data access tracking)
- Enable detection of unauthorized access patterns
- Provide forensic capabilities for security incidents
- Support user data export requests (GDPR compliance)

## Future Enhancements

- Implement log retention policies
- Add geographic information (country, region) for security monitoring
- Consider real-time audit log streaming for security monitoring
- Add audit log integrity verification (checksums)
