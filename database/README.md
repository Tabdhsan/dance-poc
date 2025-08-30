# Database Schema Structure

This directory contains the Muvv.nyc database schema broken down into focused, manageable files for easier development and LLM collaboration.

## File Structure

```
database/
├── README.md                           # This file
├── schema-parts/                       # Focused schema files
│   ├── 01-core-tables.sql             # Table definitions only
│   ├── 02-business-functions.sql      # Core business logic functions
│   ├── 03-auth-functions.sql          # Authentication & subscription functions
│   ├── 04-indexes.sql                 # All database indexes
│   ├── 05-automation.sql              # Views, triggers, automation
│   └── 06-seed-data.sql               # Initial/reference data
└── master-schema.sql                   # Combined schema (link to productionize-docs)
```

## File Descriptions

### 01-core-tables.sql
- **Purpose**: Core table definitions only
- **Contains**: All CREATE TABLE statements, constraints, foreign keys
- **Use for**: Schema design, table structure modifications

### 02-business-functions.sql
- **Purpose**: Core business logic functions
- **Contains**: 
  - `get_classes_with_watchlist_count()` - Heat calculation
  - `search_and_filter_classes()` - Advanced search with full-text
  - `get_choreographer_analytics()` - Dashboard analytics
- **Use for**: Business logic development, query optimization

### 03-auth-functions.sql
- **Purpose**: Authentication and subscription management
- **Contains**:
  - User feature access functions
  - Subscription status management
  - Auth trigger functions
  - Role assignment functions
- **Use for**: Auth flow development, subscription features

### 04-indexes.sql
- **Purpose**: All database indexes for performance
- **Contains**: 
  - Core table indexes
  - Composite indexes for search
  - Full-text search (GIN) indexes
  - Social relationship indexes
- **Use for**: Performance optimization, query tuning

### 05-automation.sql
- **Purpose**: Database automation and active record views
- **Contains**:
  - Trigger functions (updated_at, soft delete cascading)
  - Active record views (active_users, active_classes, etc.)
  - View count increment functions
- **Use for**: Automation development, view modifications

### 06-seed-data.sql
- **Purpose**: Initial data and configuration
- **Contains**: Subscription tier definitions, reference data
- **Use for**: Initial setup, tier modifications

## Usage Guidelines

### For Development
1. **Focused editing**: Work with individual files for specific changes
2. **LLM collaboration**: Share specific files based on the feature being developed
3. **Testing**: Each file can be loaded independently for testing

### For Deployment
- The master schema file in `productionize-docs/schema.sql` should be kept as the authoritative source
- These focused files are for development efficiency
- When ready for production, use Supabase migrations based on these components

### Current Status
**Subtask 2.4 Progress: 3 of 5 functions complete**
- ✅ Heat calculation function (`get_classes_with_watchlist_count`)
- ✅ Choreographer analytics function (`get_choreographer_analytics`)  
- ✅ Class search and filtering function (`search_and_filter_classes`)
- ⏳ Most popular choreographers function (pending)
- ⏳ Trending classes function (pending)

### Next Development Steps
1. Work on remaining business logic functions in `02-business-functions.sql`
2. Add new indexes as needed in `04-indexes.sql`
3. Update master schema when ready for deployment

## Benefits of This Structure

1. **LLM Efficiency**: Smaller, focused files are easier for AI to process and modify
2. **Developer Experience**: Find relevant code quickly without scrolling through large files
3. **Modularity**: Test and develop individual components independently
4. **Collaboration**: Share specific files based on the work being done
5. **Future Migration**: Easy to convert to proper Supabase migration files
