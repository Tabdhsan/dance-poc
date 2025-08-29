
This schema should be implemented in the Supabase project. Row Level Security (RLS) must be enabled on all tables.

```sql
-- --------------------------------------------------------------------------------
-- Muvv.nyc - Database Schema for Implementation
-- --------------------------------------------------------------------------------

Table users {
  id uuid [pk, note: 'Links to auth.users.id']
  role text [not null, default: 'dancer']
  full_name text
}

Table choreographer_profiles {
  user_id uuid [pk, ref: > users.id]
  display_name text [not null]
  bio text
  profile_picture_url text
  social_links jsonb
  url_slug text [unique]
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz
}

Table classes {
  id uuid [pk, default: `gen_random_uuid()`]
  choreographer_id uuid [not null, ref: > users.id]
  title text [not null]
  description text
  style text [not null]
  skill_level text [not null]
  location_name text [not null]
  borough text [not null]
  price numeric(6, 2)
  booking_url text
  class_timestamp timestamptz [not null]
  choreographer_note text
  created_at timestamptz [not null, default: `now()`]
  updated_at timestamptz
}

Table class_watchlists {
  user_id uuid [pk, ref: > users.id]
  class_id uuid [pk, ref: > classes.id]
  created_at timestamptz [not null, default: `now()`]
}

Table choreographer_follows {
  follower_user_id uuid [pk, ref: > users.id]
  followed_choreographer_id uuid [pk, ref: > users.id]
  created_at timestamptz [not null, default: `now()`]
}

Table invites {
  id uuid [pk, default: `gen_random_uuid()`]
  email text [not null]
  token text [unique, not null]
  is_used boolean [not null, default: false]
  created_at timestamptz [not null, default: `now()`]
  expires_at timestamptz [not null]
}
```