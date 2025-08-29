# Auth Integration Design & Implementation

## Overview

This document outlines the design decisions and implementation for Supabase auth integration with our custom user management system. The integration handles the sync between `auth.users` (Supabase managed) and `public.users` (our custom table).

## Key Design Decisions

### 1. **Two-Table Architecture**

**`auth.users` (Supabase Managed)**
- Handles: passwords, OAuth tokens, email verification, security
- Contains: `id`, `email`, `email_confirmed_at`, `raw_user_meta_data`, etc.
- **We never directly modify this table**

**`public.users` (Our Business Logic)**
- Handles: roles, profile data, business relationships, subscription management
- Contains: `role`, `full_name`, `subscription_tier`, `subscription_status`, business-specific fields
- **Connected via trigger-based sync**

### 2. **Trigger-Based Synchronization**

```sql
-- Triggers on auth.users automatically maintain public.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users  
  FOR EACH ROW EXECUTE FUNCTION handle_user_update();
```

**Benefits**:
- Automatic sync - no application code needed
- Atomic operations - if auth fails, public record isn't created
- Audit trail - all user creation is logged
- Works with email/password AND OAuth flows

### 3. **Role Assignment Strategy**

**Default Role**: All new users start as `'dancer'` with `'dancer_free'` subscription
**Choreographer Promotion**: Requires valid invite token, gets `'choreo_basic'` subscription

**Flow**:
1. User signs up → automatically gets `'dancer'` role with `'dancer_free'` subscription
2. To become choreographer → must use `assign_choreographer_role()` with valid invite, gets `'choreo_basic'` subscription
3. Role downgrade (choreographer → dancer) is prevented (business rule)

### 4. **Invite Token Security**

**Token Lifecycle**:
- Generated with cryptographic randomness
- Has expiration timestamp
- Single-use only (marked as used after consumption)
- Audit logged when used

**Validation Points**:
- During user creation (for direct choreographer signup)
- During role promotion (dancer → choreographer)
- Cleanup of expired tokens

## Current Implementation Status

**✅ Implemented and Working**:
- Two-table architecture with trigger sync
- **Secure invite validation during choreographer signup**
- Role assignment with subscription tiers
- Dancer signup flows (email/password and OAuth)
- Role promotion via `assign_choreographer_role()`
- Automatic choreographer profile creation
- Subscription tier assignment

**🔒 Security Enforced**:
- Choreographer role **requires valid invite token** during signup
- Invalid/expired/missing tokens will **reject the signup**
- Invite tokens are single-use and automatically marked as used

## Authentication Flows

### 1. **Dancer Email/Password Signup**

```javascript
// Frontend
const { data, error } = await supabase.auth.signUp({
  email: 'dancer@example.com',
  password: 'securepassword',
  options: {
    data: {
      full_name: 'Jane Dancer',
      role: 'dancer'  // Optional, defaults to dancer with dancer_free subscription
    }
  }
})

// Database (automatic)
// 1. Record created in auth.users
// 2. handle_new_user() trigger fires
// 3. Record created in public.users with role='dancer', subscription_tier='dancer_free'
// 4. Audit log entry created
```

### 2. **Dancer Google OAuth Signup**

```javascript
// Frontend
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    queryParams: {
      role: 'dancer'  // Passed in metadata
    }
  }
})

// Database (automatic)
// 1. Google OAuth flow completes
// 2. auth.users record created with Google profile data
// 3. handle_new_user() trigger extracts Google profile info
// 4. public.users record created with email_verified=true, subscription_tier='dancer_free'
```

### 3. **Choreographer Invite-Only Signup**

```javascript
// Frontend - Direct signup with invite validation in trigger
const { data, error } = await supabase.auth.signUp({
  email: 'choreo@example.com',
  password: 'securepassword',
  options: {
    data: {
      full_name: 'John Choreographer',
      role: 'choreographer',
      invite_token: 'invite-token-123'  // REQUIRED for choreographer role
    }
  }
})

// Database (automatic via handle_new_user trigger):
// 1. Validates invite token exists and is valid
// 2. Creates user with choreographer role and choreo_basic subscription
// 3. Creates choreographer_profiles record
// 4. Marks invite as used
// 5. REJECTS signup if invite is invalid/expired/missing
```

### 4. **Role Promotion (Dancer → Choreographer)**

```javascript
// User already exists as dancer, wants to become choreographer
const result = await supabase.rpc('assign_choreographer_role', {
  p_user_id: currentUser.id,
  p_invite_token: 'valid-invite-token',
  p_requesting_user_id: currentUser.id
})

// Database effects:
// 1. Updates user role to 'choreographer' with subscription_tier='choreo_basic'
// 2. Marks invite as used
// 3. Creates choreographer_profiles record
// 4. Logs role change in audit trail
```

## Security Considerations

### 1. **Function Security**

All functions use `SECURITY DEFINER` to run with elevated privileges:
- Functions can access `auth.users` (normally restricted)
- Proper validation prevents privilege escalation
- Audit logging tracks all security-sensitive operations

### 2. **Input Validation**

```sql
-- Email format validation
IF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
  RETURN jsonb_build_object('success', false, 'error', 'INVALID_EMAIL');
END IF;

-- Role validation
IF p_role NOT IN ('dancer', 'choreographer') THEN
  RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE');
END IF;
```

### 3. **Authorization Checks**

- Users can only change their own roles
- Role downgrades are prevented
- Invite tokens are validated before use
- All changes are audit logged

## Error Handling

### Structured Error Responses

All functions return standardized JSON responses:

```sql
-- Success
{
  "success": true,
  "message": "Operation completed",
  "data": { ... }
}

-- Error
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "User-friendly error message"
}
```

### Error Codes

- `INVALID_ROLE`: Role must be dancer or choreographer
- `INVITE_REQUIRED`: Choreographer role requires invite
- `INVALID_INVITE`: Invalid or expired invite token
- `EMAIL_EXISTS`: Email already registered
- `UNAUTHORIZED`: Insufficient permissions
- `USER_NOT_FOUND`: User does not exist

## Audit Trail Integration

Every auth operation is logged:

```sql
INSERT INTO audit_logs (
  table_name, record_id, operation, old_values, new_values, user_id, metadata
) VALUES (
  'users', user_id, 'INSERT',
  '{}',
  jsonb_build_object('role', 'dancer', 'email', email),
  user_id,
  jsonb_build_object('source', 'auth_trigger', 'provider', 'google')
);
```

**Tracked Events**:
- User creation (email, OAuth)
- Role changes
- Invite usage
- Profile creation
- Email verification changes

## Implementation Questions for Discussion

### 1. **Choreographer Profile Auto-Creation**

When a user becomes a choreographer, should we:
- **Option A**: Auto-create basic profile (current implementation)
- **Option B**: Require explicit profile creation step
- **Option C**: Create profile but mark as "incomplete"

### 2. **Role Change Authorization**

Currently only self-role-changes are allowed. Should we add:
- **Admin role** that can change any user's role?
- **Invite-based role elevation** only?
- **Two-step verification** for role changes?

### 3. **OAuth Profile Data Handling**

For Google OAuth, should we:
- **Auto-populate** profile fields from Google data?
- **Allow override** of Google profile data?
- **Sync updates** when Google profile changes?

### 4. **Account Linking**

If someone signs up with email then later wants to add Google OAuth:
- **How should we handle account linking?**
- **Should we merge accounts or prevent duplicate emails?**
- **What about role preservation during linking?**

### 5. **Invite Token Management**

Current design uses single-use tokens. Should we support:
- **Multi-use tokens** with usage limits?
- **Role-specific tokens** (only for choreographer invites)?
- **Expiration extension** for unused tokens?

## Next Steps

1. **Review the auth flow design** - does this match your vision?
2. **Discuss the implementation questions** above
3. **Plan invite token generation** and management system
4. **Design the Edge Functions** that will use these database functions
5. **Plan the frontend auth integration** patterns

What aspects would you like to dive deeper into or modify?
