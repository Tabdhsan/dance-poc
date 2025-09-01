#!/bin/bash

# --------------------------------------------------------------------------------
# Schema Build Script - Combines all schema-parts into deployable schema.sql
# --------------------------------------------------------------------------------

echo "Building deployable schema.sql from schema-parts..."

# Output file
OUTPUT_FILE="schema.sql"
PARTS_DIR="schema-parts"

# Remove existing output file
rm -f "$OUTPUT_FILE"

# Add header to output file
cat << 'EOF' > "$OUTPUT_FILE"
-- --------------------------------------------------------------------------------
-- Muvv.nyc - Complete Database Schema for Supabase Deployment
-- Auto-generated from schema-parts/ - DO NOT EDIT DIRECTLY
-- Generated: $(date)
-- --------------------------------------------------------------------------------

EOF

echo "Combining schema parts in dependency order..."

# Combine files in proper dependency order
echo "-- CORE TABLES" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/01-core-tables.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- BUSINESS FUNCTIONS" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/02-business-functions.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- AUTH FUNCTIONS" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/03-auth-functions.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- INDEXES" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/04-indexes.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- AUTOMATION & TRIGGERS" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/05-automation.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- AUDIT SYSTEM" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/05-audit.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- SEED DATA" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/06-seed-data.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- RLS POLICIES" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/07-rls-policies.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

echo "-- ADMIN UTILITIES" >> "$OUTPUT_FILE"
cat "$PARTS_DIR/08-admin-utilities.sql" >> "$OUTPUT_FILE"
echo -e "\n\n" >> "$OUTPUT_FILE"

# Add footer
cat << 'EOF' >> "$OUTPUT_FILE"

-- --------------------------------------------------------------------------------
-- DEPLOYMENT COMPLETE
-- Schema ready for Supabase deployment
-- Next steps:
-- 1. Copy contents of this file
-- 2. Paste into Supabase SQL Editor
-- 3. Execute and fix any errors iteratively
-- --------------------------------------------------------------------------------
EOF

echo "✅ Schema build complete!"
echo "📄 Output: $OUTPUT_FILE"
echo "📏 Size: $(wc -l < "$OUTPUT_FILE") lines"
echo ""
echo "🚀 Ready to deploy to Supabase!"
echo "   1. Copy the contents of $OUTPUT_FILE"
echo "   2. Paste into Supabase SQL Editor"
echo "   3. Execute and fix any deployment errors"
