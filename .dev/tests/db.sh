#!/bin/bash
set -e

# Database connection test script
# Tests that the database has data in key tables

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_USER=${DB_USER:-parser}
DB_PASS=${DB_PASS:-parser}
DB_NAME=${DB_TABLE:-us_code_2025}

CONNECTION_STRING="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"

echo "=================================================="
echo "Congress.dev Database Test"
echo "=================================================="
echo ""
echo "Database: ${DB_NAME}@${DB_HOST}"
echo ""

# Track failures
FAILED=0

# Test congress table
echo -e "${YELLOW}Testing 'congress' table...${NC}"
CONGRESS_ROW=$(psql "$CONNECTION_STRING" -t -c "SELECT session_number, start_year, end_year FROM congress LIMIT 1;" 2>&1)
if [ $? -eq 0 ] && [ -n "$(echo "$CONGRESS_ROW" | tr -d '[:space:]')" ]; then
    echo -e "${GREEN}✓ Congress table has data${NC}"
    echo "  Sample: $CONGRESS_ROW"
else
    echo -e "${RED}✗ Congress table is empty or query failed${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test legislation table
echo -e "${YELLOW}Testing 'legislation' table...${NC}"
LEGISLATION_ROW=$(psql "$CONNECTION_STRING" -t -c "SELECT legislation_id, chamber, number, title FROM legislation LIMIT 1;" 2>&1)
if [ $? -eq 0 ] && [ -n "$(echo "$LEGISLATION_ROW" | tr -d '[:space:]')" ]; then
    echo -e "${GREEN}✓ Legislation table has data${NC}"
    echo "  Sample: $(echo "$LEGISLATION_ROW" | cut -c 1-80)..."
else
    echo -e "${RED}✗ Legislation table is empty or query failed${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test legislator table
echo -e "${YELLOW}Testing 'legislator' table...${NC}"
LEGISLATOR_ROW=$(psql "$CONNECTION_STRING" -t -c "SELECT legislator_id, bioguide_id, first_name, last_name FROM legislator LIMIT 1;" 2>&1)
if [ $? -eq 0 ] && [ -n "$(echo "$LEGISLATOR_ROW" | tr -d '[:space:]')" ]; then
    echo -e "${GREEN}✓ Legislator table has data${NC}"
    echo "  Sample: $LEGISLATOR_ROW"
else
    echo -e "${RED}✗ Legislator table is empty or query failed${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=================================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo "Database has data in all required tables."
    exit 0
else
    echo -e "${RED}✗ $FAILED test(s) failed${NC}"
    echo "Some tables are missing data. Run import scripts to populate the database."
    exit 1
fi
