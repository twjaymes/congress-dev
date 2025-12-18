#!/bin/bash
set -e

# Quick Start: Download and Import Sample Congressional Data
# This script downloads bills from the current Congress and imports them

cd "$(dirname "$0")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================================="
echo "Congress.dev - Quick Data Import"
echo "=================================================="
echo ""

# Configuration
export db_host=${DB_HOST:-localhost}
export db_user=${DB_USER:-parser}
export db_pass=${DB_PASS:-parser}
export db_table=${DB_TABLE:-us_code_2025}
export PARSE_THREADS=${PARSE_THREADS:-4}

# Calculate current congress
CURRENT_YEAR=$(date +%Y)
CONGRESS=$(( (CURRENT_YEAR - 2001) / 2 + 107 ))

echo -e "${YELLOW}Configuration:${NC}"
echo "  Congress: $CONGRESS (current)"
echo "  Database: $db_table@$db_host"
echo "  Threads: $PARSE_THREADS"
echo ""

# Create bills directory
mkdir -p bills

# Download sample data (just session 1, house bills - ~500MB)
echo -e "${YELLOW}Downloading sample data...${NC}"
URL="https://www.govinfo.gov/bulkdata/BILLS/${CONGRESS}/1/hr/BILLS-${CONGRESS}-1-hr.zip"
OUTPUT="bills/BILLS-${CONGRESS}-1-hr.zip"

if [ -f "$OUTPUT" ]; then
    echo -e "${GREEN}✓ Already downloaded: $OUTPUT${NC}"
else
    echo "Downloading House bills from ${CONGRESS}th Congress..."
    if wget -q --show-progress -O "$OUTPUT" "$URL" 2>&1; then
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Download failed. Trying alternate session...${NC}"
        # Try previous congress if current doesn't exist yet
        CONGRESS=$((CONGRESS - 1))
        URL="https://www.govinfo.gov/bulkdata/BILLS/${CONGRESS}/1/hr/BILLS-${CONGRESS}-1-hr.zip"
        OUTPUT="bills/BILLS-${CONGRESS}-1-hr.zip"
        wget -q --show-progress -O "$OUTPUT" "$URL" || {
            echo -e "${RED}✗ Could not download data${NC}"
            exit 1
        }
    fi
fi

echo ""
echo -e "${YELLOW}Importing bills into database...${NC}"
echo "This will take 5-15 minutes depending on your system."
echo ""

# Import the data
if python -m billparser.importers.bills 2>&1 | tee import.log; then
    # Count imported bills
    IMPORTED=$(grep -c "Importing" import.log 2>/dev/null || echo "0")
    echo ""
    echo -e "${GREEN}✓ Import complete!${NC}"
    echo "  Bills processed: $IMPORTED"
else
    echo ""
    echo -e "${YELLOW}⚠ Import completed with warnings (see import.log)${NC}"
fi

echo ""
echo "=================================================="
echo "Quick Query Test"
echo "=================================================="

# Test query
psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c "
SELECT 
    c.session_number,
    l.chamber,
    COUNT(*) as bill_count,
    COUNT(DISTINCT lv.legislation_version) as version_count
FROM legislation l
JOIN congress c ON l.congress_id = c.congress_id
LEFT JOIN legislation_version lv ON l.legislation_id = lv.legislation_id
GROUP BY c.session_number, l.chamber
ORDER BY c.session_number DESC, l.chamber;
" 2>/dev/null || echo "Could not run test query"

echo ""
echo "Next steps:"
echo "  1. Start API: cd .. && ./start_local.sh"
echo "  2. Test endpoint: curl http://localhost:9091/congress"
echo "  3. View in browser: http://localhost:3000"
echo ""
echo "To import more data:"
echo "  - Senate bills: Change 'hr' to 's' in download URL"
echo "  - Different congress: Set CONGRESS variable"
echo "  - Full import: Use ./setup_and_import.sh"
echo ""
