
### Epic 1: Core Platform & User Authentication

#### Story: AUTH-00 - Database Schema & Security Foundation

**Description:** Create proper PostgreSQL DDL schema with security policies, audit trail, soft delete strategy, and auth integration before any application development begins.

**Subtasks:**

##### Subtask 1: Schema Analysis & Design
- [x] Analyze existing table-schema.md and identify all table requirements
- [x] Design comprehensive column strategy with database-enforced timestamps (created_at, updated_at, deleted_at)
- [x] Plan trigger strategy for automatic timestamp updates and soft delete cascading
- [x] Document all constraints, indexes, and relationships in finalized schema design
- [x] Define audit trail requirements and what operations need tracking

##### Subtask 2.1: Schema Validation & Audit Foundation
- [x] Convert custom schema notation to proper PostgreSQL DDL syntax (table-schema.md -> sql file)
- [x] Plan strategic indexing for performance (class_timestamp, choreographer_id, deleted_at)
- [x] Design partial indexes for soft delete filtering (WHERE deleted_at IS NULL)
- [x] Validate existing schema against all business requirements from general-plan.md
- [x] Add view_count fields to classes and choreographer_profiles tables
- [x] Design audit_logs table structure with proper indexing strategy and column definitions
- [x] Document audit_logs table schema and integration points

##### Subtask 2.2: Core Automation & Views
- [x] Design comprehensive trigger functions for automatic updated_at timestamp management
- [x] Design database views (active_users, active_classes, active_choreographer_profiles, active_invites) that filter soft-deleted records
- [x] Plan database-level soft delete cascading triggers (user deletion cascades to classes, profiles, follows)
- [x] Document core automation architecture and trigger dependencies

### Subtask 2.3: Auth Integration & User Workflows ✅ COMPLETED
- [x] Design multi-tier subscription model with feature-based access control
- [x] Create subscription_tiers and subscriptions tables with proper relationships  
- [x] Design auth triggers to sync auth.users with public.users table automatically
- [x] **SECURITY FIX**: Implement invite token validation in handle_new_user() trigger for choreographer signup
- [x] Design proper user creation workflow that maintains referential integrity
- [x] Design database functions for role validation and choreographer invite processing with subscription support
- [x] Plan database functions for secure role assignment with subscription tier management
- [x] Implement subscription status management functions (update_subscription_status, assign_choreographer_role)
- [x] **VIEW STANDARDIZATION**: Rename public_classes to active_classes for consistency
- [x] Plan cleanup functions for expired invite tokens
- [x] Document complete user lifecycle and auth integration architecture with subscription flow
- [x] **DOCUMENTATION UPDATE**: Update core-automation-architecture.md and auth-integration-design.md to match implementation
- [x] **FILE CONSOLIDATION**: Consolidate all SQL into single master schema.sql file (removed 6+ duplicate files)

**OUTCOME**: Database is production-ready with secure invite-only choreographer signup, subscription management, and comprehensive automation. Ready for Subtask 2.4.

##### Subtask 2.4: Business Logic Functions 🔄 READY TO IMPLEMENT

**CURRENT STATE**: Database foundation is complete. Schema is production-ready with subscription system, secure authentication, and automation. All prerequisites satisfied.

**IMPLEMENTATION REQUIREMENTS**: All business logic functions must respect subscription tiers using `user_has_feature()` and use `active_*` views for data access.

- [x] Design function for efficient class "Heat" calculation (get_classes_with_watchlist_count) ✅
- [x] Design choreographer analytics functions (follower counts, view counts, class engagement metrics) ✅  
- [x] Design class search and filtering functions (title, location search with style + borough + class_timestamp composite filtering) ✅
- [x] Design "most popular choreographers" function (by follower count and engagement) ✅
- [x] Design "trending classes" function (most watchlisted within time periods) ✅
- [x] Add view_count fields to classes and choreographer_profiles tables with increment functions ✅
- [x] Plan composite indexes for multi-factor filtering (style + borough + class_timestamp, location_name + style, choreographer_id + class_timestamp)
- [x] Document all business logic function specifications and performance requirements

**AVAILABLE FOUNDATION**: 
- ✅ Subscription-aware views (`active_users`, `active_classes`, `active_choreographer_profiles`)
- ✅ Feature access functions (`user_has_feature()`, `get_user_features()`)
- ✅ Performance indexes and automation triggers
- ✅ Complete documentation and architecture guides

##### Subtask 2.5: Audit Integration & Security ✅ COMPLETED
- [x] Design audit triggers for critical operations (user role changes, class creation/updates/deletion, profile changes)
- [x] Design audit triggers for social actions (watchlist additions/removals, follow/unfollow actions)
- [x] Design audit triggers for analytics tracking (search queries, profile views, class views)
- [x] Plan audit trail functions that integrate with business logic triggers
- [x] Plan soft delete and restore utility functions for administrative use
- [x] Design comprehensive Row Level Security (RLS) policies for all tables including audit considerations
- [x] Document complete database architecture with all functions, triggers, views, and policies

##### Subtask 3: MVP Database Deployment ✅ SIMPLIFIED
**All core implementation already completed in previous subtasks. This subtask focuses on deployment only.**

##### Subtask 3.1: Schema Consolidation ✅ COMPLETED
- [x] Add RLS enabling statements to 07-rls-policies.sql file (at the beginning)
- [x] Create bash script to combine all schema-parts/*.sql files into deployable schema.sql
- [x] Ensure proper ordering: tables → functions → triggers → views → policies → admin utilities
- [x] **Output**: Single deployable schema.sql file ready for Supabase

##### Subtask 3.2: Deploy to Supabase ✅ COMPLETED
- [x] Deploy schema.sql to Supabase SQL Editor
- [x] Fix any deployment errors that Supabase reports (iterative approach)
- [x] Verify all tables, functions, triggers, and policies are created successfully
- [x] **Goal**: Working database with all core functionality

##### Subtask 3.3: Basic Validation
- [ ] Create test user via Supabase Auth
- [ ] Create test class via SQL/API
- [ ] Verify basic CRUD operations work (users, classes, watchlists, follows)
- [ ] Confirm RLS policies are active and working
- [ ] **Goal**: Database ready for application development

**OUTCOME**: Complete Muvv database deployed and functional in Supabase, ready for frontend development.

#### Story: AUTH-01 - Project Scaffolding & Tech Stack Setup

**Description:** Initialize the frontend and backend projects, install all core dependencies with specific versions, and establish a basic connection to ensure the development environment is fully functional.

**Acceptance Criteria:**

- [ ] A new Vite + React (TypeScript) project is created with strict TypeScript configuration
- [ ] A new Supabase project is created on the cloud platform with proper environment separation
- [ ] All core dependencies are installed with specific versions: supabase-js@^2.39.0, @tanstack/react-router@^1.45.0, @tanstack/react-query@^5.45.0, tailwindcss@^3.4.0, shadcn-ui@latest, lucide-react@^0.400.0, react-hook-form@^7.52.0, dayjs@^1.11.0, sonner@^1.5.0
- [ ] Add additional dependencies: zod for validation, react-dropzone for file uploads, @supabase/storage-js for file management
- [ ] Tailwind CSS is configured with custom design tokens and shadcn-ui is initialized
- [ ] A basic TanStack Router instance is created with proper error boundaries and loading states
- [ ] Environment variables are properly configured for development, staging, and production
- [ ] Sentry is configured with proper error boundaries and performance monitoring
- [ ] ESLint, Prettier, and pre-commit hooks are configured for code quality

#### Story: AUTH-02 - Authentication Infrastructure & Error Handling

**Description:** Set up comprehensive authentication infrastructure with proper error handling, validation, and security measures including user-friendly error messages.

**Acceptance Criteria:**

- [ ] Create authentication context with TypeScript interfaces for user states
- [ ] Implement comprehensive error handling with user-friendly message translation layer for Supabase errors
- [ ] Create error utility function to map Supabase/PostgREST error codes to user-friendly messages
- [ ] Set up protected route middleware with role-based access control
- [ ] Create auth utilities for token validation and refresh handling
- [ ] Implement proper logout functionality with session cleanup
- [ ] Add rate limiting protection for auth endpoints
- [ ] Create comprehensive validation schemas using Zod for all auth forms
- [ ] Set up proper CSRF protection and security headers
- [ ] Configure Sentry for error logging and monitoring with proper error boundaries
- [ ] Implement toast notifications for auth success/error states with user-friendly messages

#### Story: AUTH-03 - Dancer Email/Password Signup & Login

**Description:** Implement the complete user journey for signing up and logging in with an email and password, including email verification and comprehensive validation.

**Acceptance Criteria:**

- [ ] Create routes for /signup and /login with proper loading and error states
- [ ] Build a SignupForm component using Shadcn, React Hook Form, and Zod validation (name not empty, valid email, password > 8 chars with complexity requirements)
- [ ] On signup submission, call supabase.auth.signUp() with proper error handling and user feedback
- [ ] Configure a Resend integration with custom email templates and ensure the Supabase Auth verification email is sent successfully
- [ ] Build a LoginForm component with proper validation and error handling
- [ ] Implement account verification flow with proper error messages for unverified users
- [ ] Add "Remember Me" functionality with secure token storage
- [ ] Create comprehensive test suite for authentication flows

#### Story: AUTH-04 - Dancer Google OAuth Signup & Login

**Description:** Allow users to sign up and log in using their Google account for a frictionless authentication experience with proper security measures.

**Acceptance Criteria:**

- [ ] Configure the Google OAuth provider in the Supabase dashboard with proper security settings and redirect URLs
- [ ] Add a "Sign in with Google" button to the /signup and /login pages with proper loading states
- [ ] Implement OAuth flow with supabase.auth.signInWithOAuth({ provider: 'google' }) and proper error handling
- [ ] Handle OAuth callbacks with proper state validation and PKCE implementation
- [ ] Ensure proper user data mapping from Google profile to internal user schema
- [ ] Implement account linking for users who already have email/password accounts
- [ ] Add proper fallback handling for OAuth failures

#### Story: AUTH-05 - Choreographer Invite-Only Signup with Security

**Description:** Create a secure, invite-only signup flow for choreographers with proper token validation, expiration, and security measures.

**Acceptance Criteria:**

- [ ] Create a Supabase Edge Function (/validate-invite) with proper input validation, rate limiting, and security headers
- [ ] Implement secure token generation with cryptographic randomness and expiration timestamps
- [ ] Create a private route at /join with token validation middleware and proper error handling
- [ ] Build invite management system for administrators to generate and track invites
- [ ] Implement database triggers for role assignment with audit logging
- [ ] Add proper token cleanup for expired invites
- [ ] Create comprehensive validation for invite flow with detailed error messages
- [ ] Implement invite usage tracking and analytics

#### Story: AUTH-06 - Password Reset Flow with Security

**Description:** Implement secure "forgot password" functionality with proper validation, rate limiting, and user experience.

**Acceptance Criteria:**

- [ ] Create a route at /forgot-password with proper validation and rate limiting
- [ ] Implement secure password reset form with email validation and captcha protection
- [ ] Call supabase.auth.resetPasswordForEmail() with proper error handling and user feedback
- [ ] Configure custom password reset email templates with proper security messaging
- [ ] Create a route at /update-password with secure token validation and password complexity requirements
- [ ] Implement password strength validation with real-time feedback
- [ ] Add proper session invalidation after password change
- [ ] Create audit logging for password reset attempts

### Epic 2: Core Infrastructure & Performance

#### Story: INFRA-01 - Database Functions & Edge Functions

**Description:** Create custom database functions (RPCs) and Edge Functions for complex business logic that Supabase's auto-generated REST API cannot handle, with proper documentation, optimization, and user-friendly error handling.

**Acceptance Criteria:**

- [ ] Create PostgreSQL RPC function get_classes_with_watchlist_count for efficient class listings with heat counts
- [ ] Implement database function for complex class filtering and search with proper indexing
- [ ] Create RPC function for choreographer analytics (follower counts, class engagement metrics)
- [ ] Build Edge Function for invite token validation with proper security and rate limiting
- [ ] Create Edge Function for complex recommendation algorithm based on user preferences
- [ ] Implement proper error handling for all database functions with user-friendly error messages returned in structured format
- [ ] Create global error translation utility to map Supabase/PostgREST error codes to user-friendly messages
- [ ] Set up function-level security and RLS integration for all custom functions
- [ ] Create comprehensive input validation using Zod schemas for all function parameters
- [ ] Design efficient query patterns in RPC functions to avoid N+1 problems (use proper joins and subqueries)
- [ ] Create OpenAPI/Swagger documentation for all custom Edge Functions with examples
- [ ] Configure Sentry integration for error logging and monitoring across all custom functions
- [ ] Add monitoring and logging for custom functions performance
- [ ] Document all custom functions with usage examples and parameter definitions

#### Story: INFRA-02 - Real-time Features & Pagination

**Description:** Implement optional real-time features and efficient pagination patterns using Supabase's built-in capabilities with proper error handling and optimization.

**Acceptance Criteria:**

- [ ] Set up TanStack Query with proper caching strategies for Supabase REST API calls
- [ ] Implement cursor-based pagination using Supabase's range() method for class listings
- [ ] Create standardized pagination response format with total counts, next/prev cursors, and page metadata
- [ ] Create standardized pagination hooks with proper cache key management
- [ ] Add optional real-time subscriptions for live class updates using Supabase Realtime
- [ ] Implement real-time follower count updates for choreographer profiles (optional feature)
- [ ] Create real-time watchlist updates for immediate UI feedback (optional feature)
- [ ] Set up proper subscription cleanup to prevent memory leaks
- [ ] Add fallback strategies for when real-time features fail or are unavailable
- [ ] Implement optimistic updates for immediate UI feedback on mutations
- [ ] Create efficient query invalidation strategies for related data updates
- [ ] Implement comprehensive error handling middleware with structured error responses
- [ ] Set up proper CORS configuration for production deployment
- [ ] Design pagination to handle edge cases (deleted records, concurrent updates, timezone changes)

#### Story: INFRA-03 - Performance Optimization & Bundle Management

**Description:** Implement frontend performance optimization with code splitting, lazy loading, and bundle optimization.

**Acceptance Criteria:**

- [ ] Implement React.lazy() for code splitting on all major routes (/dashboard, /profile, etc.)
- [ ] Configure Vite bundle optimization with proper chunk splitting for vendor libraries
- [ ] Implement image optimization and lazy loading for profile pictures and media
- [ ] Set up service worker for offline capability and static asset caching
- [ ] Add performance monitoring with Core Web Vitals tracking using Sentry
- [ ] Create performance budgets and monitoring alerts for bundle size increases
- [ ] Implement proper loading states and skeleton screens for better perceived performance
- [ ] Add compression and minification for production builds

#### Story: INFRA-04 - Testing Infrastructure

**Description:** Set up comprehensive testing infrastructure for unit, integration, and end-to-end testing.

**Acceptance Criteria:**

- [ ] Configure Vitest for unit testing with proper TypeScript support
- [ ] Set up React Testing Library for component testing
- [ ] Implement Playwright for end-to-end testing with proper test environments
- [ ] Create database seeding and cleanup utilities for testing
- [ ] Set up continuous integration with automated test runs
- [ ] Implement test coverage reporting with minimum coverage thresholds
- [ ] Create visual regression testing for UI components
- [ ] Set up performance testing for critical user flows

### Epic 3: Class & Choreographer Discovery

#### Story: DISC-01 - Build Reusable Class Card Component with Performance

**Description:** Create a stateless, reusable React component that displays a summary of a single dance class with proper performance optimization and accessibility.

**Acceptance Criteria:**

- [ ] The ClassCard component accepts a strongly-typed class object as a prop with proper TypeScript interfaces
- [ ] It displays the title, choreographer.display_name, location_name, class_timestamp (formatted with dayjs and timezone support), and style
- [ ] Implement proper accessibility with ARIA labels and keyboard navigation
- [ ] It includes a real-time "Heat" count (watchlist count) with optimistic updates
- [ ] Clicking the card navigates to the class detail page with proper loading states
- [ ] Implement image lazy loading for choreographer profile pictures
- [ ] Add proper error boundaries for component failure handling
- [ ] Create comprehensive Storybook stories for all component variants

#### Story: DISC-02 - Implement Public Class Browser Page with Optimization

**Description:** Build the homepage that fetches and displays a list of all upcoming classes using the ClassCard component with proper pagination, performance optimization and user experience.

**Acceptance Criteria:**

- [ ] The root route (/) uses TanStack Router loader with proper error handling and loading states
- [ ] Implement cursor-based pagination using class_timestamp for consistent ordering and performance
- [ ] Create useInfiniteQuery implementation with proper page management and cache key strategy
- [ ] The data is fetched using optimized PostgreSQL queries with proper joins and indexing
- [ ] Create a PostgreSQL RPC function get_classes_with_watchlist_count with cursor pagination support
- [ ] Implement infinite scrolling with intersection observer and proper loading indicators
- [ ] Add skeleton loading states with proper accessibility and responsive design
- [ ] Add proper SEO meta tags and Open Graph data for the homepage
- [ ] Implement real-time updates for new classes using Supabase realtime subscriptions
- [ ] Create proper error fallbacks for network failures and empty states
- [ ] Design pagination to handle edge cases (deleted classes, time zone changes, concurrent updates)

#### Story: DISC-03 - Implement Advanced Class Filtering & Search

**Description:** Allow users to filter the class list based on style, borough, and a text search for choreographer or class title with proper performance and UX.

**Acceptance Criteria:**

- [ ] Create filter components using Shadcn with proper accessibility and keyboard navigation
- [ ] Implement debounced search with minimum character requirements to reduce API calls
- [ ] The state of these filters is managed using TanStack Router's useSearch hook with proper type safety
- [ ] Implement URL-based filtering with shareable links and browser history support
- [ ] Add advanced filters: date range, price range, skill level, and availability
- [ ] Create filter persistence using localStorage with proper serialization
- [ ] Implement search analytics and popular filter tracking
- [ ] Add "Clear all filters" functionality with proper state management

#### Story: DISC-04 - Build Public Choreographer Profile Page with Rich Features

**Description:** Create a dynamic page to display a single choreographer's profile and their upcoming class schedule with rich features and proper SEO.

**Acceptance Criteria:**

- [ ] Create a dynamic route at /c/[slug] with proper TypeScript route parameters
- [ ] The loader fetches data from the choreographer_profiles table with proper error handling and 404 states
- [ ] Implement SEO optimization with dynamic meta tags, structured data, and Open Graph tags
- [ ] The page displays the choreographer's display_name, bio, profile_picture_url, and social_links with proper formatting
- [ ] Create a follow/unfollow button with optimistic updates and proper authentication checks
- [ ] Implement social sharing functionality for choreographer profiles
- [ ] Add a contact form or booking integration for direct communication
- [ ] Create analytics tracking for profile views and engagement metrics

### Epic 4: File Management & Storage

#### Story: STORAGE-01 - Implement Secure File Upload System

**Description:** Create a secure, performant file upload system for profile pictures and media with proper validation, optimization, and CloudFlare CDN integration.

**Acceptance Criteria:**

- [ ] Set up Supabase Storage buckets with proper security policies and file type restrictions
- [ ] Configure CloudFlare CDN integration for fast global image delivery and caching
- [ ] Implement file upload component using react-dropzone with drag-and-drop functionality
- [ ] Add comprehensive file validation: size limits (max 10MB), file types (JPEG, PNG, WebP), image dimensions
- [ ] Implement image optimization and compression before upload with WebP conversion
- [ ] Create progress indicators and upload cancellation functionality
- [ ] Set up automatic image resizing for different use cases (thumbnails 150x150, profile 400x400, full size)
- [ ] Configure CloudFlare image optimization and transformation rules
- [ ] Add proper error handling for upload failures and storage quota limits
- [ ] Implement CDN cache invalidation for updated images
- [ ] Set up proper cache headers and CDN rules for optimal performance

### Epic 5: Choreographer Dashboard & Management

#### Story: CHOR-01 - Create Secure Choreographer Dashboard Layout

**Description:** Build the main layout for the private choreographer dashboard with proper security, role-based access control, and user experience.

**Acceptance Criteria:**

- [ ] Create a new route group for /dashboard with proper TypeScript route definitions
- [ ] Implement middleware for authentication and role validation with proper error handling
- [ ] The root of this group checks if the user is logged in and has 'choreographer' role with proper redirects
- [ ] Create responsive dashboard layout with proper navigation and user context
- [ ] Implement breadcrumb navigation and active state management
- [ ] Add user profile dropdown with logout functionality and profile quick-edit
- [ ] Create dashboard analytics widgets showing class engagement and metrics
- [ ] Implement proper loading states and error boundaries for all dashboard routes

#### Story: CHOR-02 - Implement Comprehensive Profile Management

**Description:** Build a comprehensive form that allows choreographers to edit their public-facing profile information with rich features, validation, and structured social links management.

**Acceptance Criteria:**

- [ ] Create a route at /dashboard/profile with proper form state management
- [ ] The loader fetches the current choreographer's profile data with proper error handling
- [ ] Implement rich text editor for bio with proper sanitization and validation
- [ ] Create structured social links management with Zod validation for flexible platform support (Instagram, TikTok, YouTube, personal websites, etc.)
- [ ] Implement social links validation: each entry must have valid URL format, maximum 10 social links, and proper key-value structure
- [ ] Add dynamic social platform detection with appropriate icons and URL format validation
- [ ] Implement profile picture upload with cropping functionality and image optimization
- [ ] Add URL slug customization with availability checking and validation
- [ ] Create profile preview functionality to see public-facing profile
- [ ] Implement form auto-save functionality to prevent data loss
- [ ] Add comprehensive validation with real-time feedback and error messages
- [ ] Ensure all profile changes are properly audited in the audit trail system

#### Story: CHOR-03 - Implement Advanced Class Creation & Editing

**Description:** Build comprehensive forms for creating and editing classes with rich features, validation, soft delete support, and audit trail integration.

**Acceptance Criteria:**

- [ ] Create a route at /dashboard/classes/new with proper form state management and validation
- [ ] Create a dynamic route at /dashboard/classes/[classId]/edit with proper parameter validation
- [ ] Build a reusable ClassForm component using Shadcn, React Hook Form, and Zod validation
- [ ] Implement rich text editor for class descriptions with proper sanitization
- [ ] Add location autocomplete with Google Places API integration
- [ ] Create recurring class scheduling functionality with proper date/time handling
- [ ] Implement draft functionality to save incomplete class forms
- [ ] Add class capacity management and waitlist functionality
- [ ] Create class template system for quick class creation from previous classes
- [ ] Implement comprehensive validation with real-time feedback
- [ ] Integrate soft delete functionality - classes are marked as deleted rather than permanently removed
- [ ] Ensure all class creation, updates, and deletions are logged in the audit trail system
- [ ] Add "restore deleted class" functionality for choreographers and administrators

#### Story: CHOR-04 - Implement Advanced Class Management View

**Description:** Build a comprehensive UI that lists a choreographer's classes with advanced management features, soft delete support, analytics, and audit trail visibility.

**Acceptance Criteria:**

- [ ] Create a route at /dashboard/classes with proper data fetching and state management
- [ ] Implement advanced filtering and sorting options (date, status, capacity, etc.) with support for viewing deleted classes
- [ ] Create bulk actions for multiple class management (delete, duplicate, reschedule, restore)
- [ ] Add class analytics: views, watchlists, attendance tracking with historical data preservation
- [ ] Implement class status management (draft, published, cancelled, completed, deleted)
- [ ] Create export functionality for class data and attendee lists including audit information
- [ ] Add calendar view integration for visual class scheduling with deleted class indicators
- [ ] Implement drag-and-drop rescheduling functionality with audit logging
- [ ] Create comprehensive empty states with onboarding guidance
- [ ] Add "Recently Deleted" section with restore functionality and permanent delete options
- [ ] Implement audit trail viewer to show class history and changes
- [ ] Ensure all bulk operations are properly logged in the audit system

### Epic 6: Dancer-Specific Features

#### Story: DANC-01 - Follow Choreographers with Rich Interactions

**Description:** As a Dancer, I want to follow my favorite choreographers with rich interaction features and personalized recommendations.

**Acceptance Criteria:**

- [ ] A "Follow" button is present on choreographer profile pages and class listings with proper authentication checks
- [ ] Implement optimistic updates for follow/unfollow actions with proper error handling and rollback
- [ ] The button state updates with proper loading states and visual feedback
- [ ] Create a comprehensive "Followed Choreographers" section with activity feeds and notifications
- [ ] Implement notification system for new classes from followed choreographers
- [ ] Add recommendation system based on followed choreographers and engagement patterns
- [ ] Create social proof indicators showing mutual follows and popular choreographers
- [ ] Implement follow activity analytics for choreographers

#### Story: DANC-02 - Advanced Class Watchlist & Personalization

**Description:** As a Dancer, I want to save interesting classes to a watchlist with advanced features and personalized recommendations.

**Acceptance Criteria:**

- [ ] A "Save" (❤️) icon is present on all class listings with proper visual feedback and authentication checks
- [ ] Implement optimistic updates for watchlist actions with proper error handling and rollback
- [ ] The icon state updates with smooth animations and proper loading states
- [ ] Create a comprehensive "My Watchlist" section with filtering, sorting, and calendar integration
- [ ] Implement smart notifications for watchlisted classes (reminders, cancellations, updates)
- [ ] Add calendar export functionality for watchlisted classes
- [ ] Create personalized class recommendations based on watchlist patterns and preferences
- [ ] Implement watchlist analytics to track user engagement and class popularity

### Epic 7: Final Check List
- [ ] SEO
- [ ] Accessiblity
- [ ] Chrome Web Vitals
- [ ] Lighthouse 
- [ ] Responseiveness Considerations
- [ ] Pre commit hooks
- [ ] PWA setup
- [ ] E2E testing
- [ ] Missing offline capability considerations
- [ ] Performance optimization considerations: 
  - [ ] Evaluate materialized views for expensive queries (popular choreographers ranking, trending classes, class heat calculations)
  - [ ] **Heat calculation optimization**: Monitor performance of `get_classes_with_watchlist_count()` JOIN queries - if consistently >300ms, implement materialized view `class_heat_cache` with 5-10 minute refresh strategy
  - [ ] Implement caching strategy for "Heat" calculations if real-time performance becomes an issue (trade-off: real-time accuracy vs query speed)
  - [ ] Consider query result caching for frequently accessed data (choreographer analytics, search results)
  - [ ] **Migration path**: Plan materialized view implementation that maintains same API contract - functions can switch from real-time JOINs to cached lookups without breaking frontend
- [ ] Advanced features to consider for post-MVP:
  - [ ] Class sessions/recurring classes functionality
  - [ ] Notification system for dancers
  - [ ] Advanced recommendation algorithms
  - [ ] Geographic analytics and location-based features

### Epic 8: MVP Monitoring & Analytics

#### Story: MONITOR-01 - Essential Error & Performance Monitoring

**Description:** Set up basic but comprehensive monitoring for MVP launch with Sentry and Supabase built-in analytics.

**Acceptance Criteria:**

- [ ] Configure Sentry for error tracking with proper source maps and release tracking
- [ ] Set up Sentry performance monitoring for Core Web Vitals and page load times
- [ ] Implement error boundaries in React with Sentry integration for crash reporting
- [ ] Configure Sentry user context to track errors by user role (dancer vs choreographer)
- [ ] Set up basic alerting for critical errors and performance degradation
- [ ] Configure Supabase Analytics dashboard for database performance monitoring
- [ ] Monitor authentication metrics using Supabase built-in auth analytics
- [ ] Set up storage usage monitoring through Supabase dashboard
- [ ] Create simple performance budget alerts for bundle size increases

#### Story: MONITOR-02 - Business Metrics & User Analytics

**Description:** Implement lightweight business metrics tracking to understand user behavior and platform usage patterns.

**Acceptance Criteria:**

- [ ] Create analytics_events table for custom business event tracking
- [ ] Implement client-side event tracking utility with privacy considerations
- [ ] Track key business metrics: class views, choreographer profile views, follows, watchlist additions
- [ ] Monitor user engagement: session duration, pages per session, bounce rate
- [ ] Track conversion funnels: signup → profile completion → first interaction
- [ ] Implement search analytics: popular search terms, filter usage, result click-through rates
- [ ] Create basic analytics dashboard using Supabase data with simple SQL queries
- [ ] Set up weekly automated reports for key business metrics
- [ ] Ensure GDPR compliance with proper consent management and data anonymization
- [ ] Add geographic usage analytics to understand market penetration by borough

### Epic 9: Production Deployment & Monitoring

#### Story: DEPLOY-01 - Production Infrastructure Setup

**Description:** Set up production-ready infrastructure with proper security, monitoring, and deployment automation.

**Acceptance Criteria:**

- [ ] Configure production Supabase project with proper security settings and backup strategies
- [ ] Set up production domain with SSL certificates and proper DNS configuration
- [ ] Implement proper environment variable management for production secrets
- [ ] Configure CDN for static assets and image optimization
- [ ] Set up database backups and disaster recovery procedures
- [ ] Implement proper logging infrastructure with log aggregation and analysis
- [ ] Configure monitoring and alerting for application performance and errors
- [ ] Set up continuous deployment pipeline with proper testing and rollback procedures

#### Story: DEPLOY-02 - Security Hardening & Compliance

**Description:** Implement comprehensive security measures and compliance requirements for production deployment.

**Acceptance Criteria:**

- [ ] Implement comprehensive security headers and CSP policies
- [ ] Set up rate limiting and DDoS protection at the application and infrastructure level
- [ ] Configure proper CORS policies for production domains
- [ ] Implement comprehensive audit logging for sensitive operations
- [ ] Set up security monitoring and intrusion detection
- [ ] Configure proper backup encryption and access controls
- [ ] Implement GDPR compliance features (data export, deletion, consent management)
- [ ] Set up security scanning and vulnerability assessment automation
