#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------------------------
# Full Database Reset Script
# Drops all objects in `public`, rebuilds schema.sql from parts,
# copies to init migration, and reapplies it.
# --------------------------------------------------------------------------------

# SUPABASE_DB_URL="postgres://postgres:Whitney123%21TD%21%40%23@db.swpcydazgxrafkyoulsu.supabase.co:5432/postgres"
SUPABASE_DB_URL="postgresql://postgres.swpcydazgxrafkyoulsu:Whitney123%21TD%21%40%23@aws-1-us-east-2.pooler.supabase.com:5432/postgres"
PARTS_DIR="./schema-parts"
OUTPUT_FILE="./schema.sql"
MIGRATIONS_DIR="./supabase/migrations"
INIT_FILE="20250901003054_init.sql"

echo "🔄 Dropping all database objects in 'public' schema..."
psql "$SUPABASE_DB_URL" <<'EOSQL'
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop views
    FOR r IN (SELECT viewname FROM pg_views WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP VIEW IF EXISTS public.' || quote_ident(r.viewname) || ' CASCADE';
    END LOOP;

    -- Drop materialized views
    FOR r IN (SELECT matviewname FROM pg_matviews WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS public.' || quote_ident(r.matviewname) || ' CASCADE';
    END LOOP;

    -- Drop tables
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;

    -- Drop sequences
    FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP SEQUENCE IF EXISTS public.' || quote_ident(r.sequencename) || ' CASCADE';
    END LOOP;

    -- Drop functions
    FOR r IN (
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = 'public'
    ) LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.routine_name) || ' CASCADE';
    END LOOP;

    -- Drop triggers
    FOR r IN (
        SELECT tgname, tgrelid::regclass
        FROM pg_trigger
        WHERE NOT tgisinternal
    ) LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(r.tgname) ||
                ' ON ' || r.tgrelid || ' CASCADE';
    END LOOP;

    -- Drop types
    FOR r IN (SELECT typname FROM pg_type WHERE typnamespace = 'public'::regnamespace) LOOP
        EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
    END LOOP;

    -- Drop indexes (leftover)
    FOR r IN (SELECT indexname FROM pg_indexes WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP INDEX IF EXISTS public.' || quote_ident(r.indexname) || ' CASCADE';
    END LOOP;
END
$$;
EOSQL

echo "📝 Building $OUTPUT_FILE from $PARTS_DIR..."
rm -f "$OUTPUT_FILE"

cat << EOF > "$OUTPUT_FILE"
-- --------------------------------------------------------------------------------
-- Project Schema - Auto-generated from schema-parts
-- Generated: $(date)
-- --------------------------------------------------------------------------------

EOF

# Concatenate schema parts in order
for f in "$PARTS_DIR"/*.sql; do
  echo "-- Including: $(basename "$f")" >> "$OUTPUT_FILE"
  cat "$f" >> "$OUTPUT_FILE"
  echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "-- --------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "-- END SCHEMA" >> "$OUTPUT_FILE"
echo "-- --------------------------------------------------------------------------------" >> "$OUTPUT_FILE"

echo "📄 Schema assembled: $OUTPUT_FILE"

echo "📂 Copying schema into migrations/$INIT_FILE..."
cp "$OUTPUT_FILE" "$MIGRATIONS_DIR/$INIT_FILE"

echo "🚀 Applying schema to Supabase..."
psql "$SUPABASE_DB_URL" -f "$MIGRATIONS_DIR/$INIT_FILE"

echo "✅ Done! Database wiped and schema reloaded."
