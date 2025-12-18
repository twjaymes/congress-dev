#!/bin/bash
set -e

# Congress.dev Database Setup and Data Import Script
# This script will:
# 1. Verify database connection
# 2. Run database migrations to set up schema
# 3. Download sample congressional data
# 4. Import the data into PostgreSQL

echo "=================================================="
echo "Congress.dev Database Setup and Import"
echo "=================================================="
echo ""

# Configuration
export db_host=${DB_HOST:-localhost}
export db_user=${DB_USER:-parser}
export db_pass=${DB_PASS:-parser}
export db_table=${DB_TABLE:-us_code_2025}
export PARSE_THREADS=${PARSE_THREADS:-4}
export CONGRESS_API_KEY=${CONGRESS_API_KEY:-}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Navigate to backend directory
cd "$(dirname "$0")"
BACKEND_DIR=$(pwd)

echo -e "${YELLOW}Configuration:${NC}"
echo "  Database Host: $db_host"
echo "  Database User: $db_user"
echo "  Database Name: $db_table"
echo "  Parse Threads: $PARSE_THREADS"
echo ""

# Step 1: Verify database connection
echo -e "${YELLOW}Step 1: Verifying database connection...${NC}"
if psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c '\q' 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Please check your database credentials and ensure PostgreSQL is running."
    echo "Connection string: postgresql://${db_user}:***@${db_host}/${db_table}"
    exit 1
fi
echo ""

# Step 2: Run database migrations
echo -e "${YELLOW}Step 2: Setting up database schema...${NC}"
echo "Running Alembic migrations..."

# Update alembic.ini with correct connection string
export SQLALCHEMY_URL="postgresql://${db_user}:${db_pass}@${db_host}/${db_table}"
sed -i.bak "s|^sqlalchemy.url = .*|sqlalchemy.url = ${SQLALCHEMY_URL}|" alembic.ini

# Run migrations
if alembic upgrade head; then
    echo -e "${GREEN}✓ Database schema created successfully${NC}"
else
    echo -e "${RED}✗ Migration failed${NC}"
    echo "You may need to install alembic: pip install alembic"
    exit 1
fi
echo ""

# Step 3: Create bills directory
echo -e "${YELLOW}Step 3: Creating data directories...${NC}"
mkdir -p bills
echo -e "${GREEN}✓ Created bills/ directory${NC}"
echo ""

# Step 4: Download sample data
echo -e "${YELLOW}Step 4: Downloading sample congressional data...${NC}"
echo "This will download bills from the 119th Congress (current)"
echo ""

# Calculate current congress
CURRENT_YEAR=$(date +%Y)
CONGRESS=$(( (CURRENT_YEAR - 2001) / 2 + 107 ))
echo "Current Congress: $CONGRESS"
echo ""

# Download both sessions for both chambers
DOWNLOAD_SUCCESS=0
for SESSION in 1; do
    for CHAMBER in hr s; do
        URL="https://www.govinfo.gov/bulkdata/BILLS/${CONGRESS}/${SESSION}/${CHAMBER}/BILLS-${CONGRESS}-${SESSION}-${CHAMBER}.zip"
        OUTPUT_FILE="bills/BILLS-${CONGRESS}-${SESSION}-${CHAMBER}.zip"
        
        if [ -f "$OUTPUT_FILE" ]; then
            echo -e "${GREEN}✓ Already downloaded: $OUTPUT_FILE${NC}"
        else
            echo "Downloading: $URL"
            if wget -q --spider "$URL" 2>/dev/null; then
                if wget -q --show-progress -O "$OUTPUT_FILE" "$URL"; then
                    echo -e "${GREEN}✓ Downloaded: $OUTPUT_FILE${NC}"
                    DOWNLOAD_SUCCESS=1
                else
                    echo -e "${YELLOW}⚠ Failed to download $OUTPUT_FILE (may not exist yet)${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ URL not found: $URL (may not exist yet)${NC}"
            fi
        fi
    done
done

if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    echo -e "${YELLOW}No new files downloaded. Using existing files if available.${NC}"
fi
echo ""

# Step 5: Import data
echo -e "${YELLOW}Step 5: Importing data into database...${NC}"
echo "This may take several minutes..."
echo ""

# Check if we have any zip files
ZIP_COUNT=$(ls -1 bills/*.zip 2>/dev/null | wc -l)
if [ $ZIP_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No data files found in bills/ directory${NC}"
    echo "Please download bill data manually or check the download step."
    exit 1
fi

echo -e "${GREEN}Found $ZIP_COUNT bill archive(s) to process${NC}"
echo ""

# Import bills
echo "Importing bills..."
if python -m billparser.importers.bills 2>&1 | tee import_bills.log; then
    echo -e "${GREEN}✓ Bills imported successfully${NC}"
    BILLS_IMPORTED=$(grep -c "Imported" import_bills.log 2>/dev/null || echo "unknown")
    echo "  Bills processed: $BILLS_IMPORTED"
else
    echo -e "${YELLOW}⚠ Bill import completed with warnings (check import_bills.log)${NC}"
fi
echo ""

# Optional: Import US Code release points
echo -e "${YELLOW}Optional: Import US Code?${NC}"
read -p "Would you like to import US Code data? This will take significant time. (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Importing US Code release point..."
    USC_URL="https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip"
    if python -m billparser.importers.releases --release-point="$USC_URL" 2>&1 | tee import_usc.log; then
        echo -e "${GREEN}✓ US Code imported successfully${NC}"
    else
        echo -e "${YELLOW}⚠ US Code import completed with warnings (check import_usc.log)${NC}"
    fi
    echo ""
fi

# Optional: Import sponsor data (requires API key)
if [ -n "$CONGRESS_API_KEY" ]; then
    echo "Importing sponsor data..."
    if python -m billparser.importers.sponsors 2>&1 | tee import_sponsors.log; then
        echo -e "${GREEN}✓ Sponsors imported successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Sponsor import completed with warnings (check import_sponsors.log)${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping sponsor import (CONGRESS_API_KEY not set)${NC}"
    echo "  Get your API key at: https://api.congress.gov/"
    echo ""
fi

# Import actions (requires API key)
if [ -n "$CONGRESS_API_KEY" ]; then
    echo "Importing legislative actions..."
    if python -m billparser.importers.actions 2>&1 | tee import_actions.log; then
        echo -e "${GREEN}✓ Actions imported successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Action import completed with warnings (check import_actions.log)${NC}"
    fi
    echo ""
fi

# Import statuses
echo "Importing bill statuses..."
if python -m billparser.importers.statuses 2>&1 | tee import_statuses.log; then
    echo -e "${GREEN}✓ Statuses imported successfully${NC}"
else
    echo -e "${YELLOW}⚠ Status import completed with warnings (check import_statuses.log)${NC}"
fi
echo ""

# Cleanup
echo "Running post-import cleanup..."
if python -m billparser.importers.cleanup 2>&1 | tee import_cleanup.log; then
    echo -e "${GREEN}✓ Cleanup completed successfully${NC}"
else
    echo -e "${YELLOW}⚠ Cleanup completed with warnings (check import_cleanup.log)${NC}"
fi
echo ""

# Step 6: Verify import
echo -e "${YELLOW}Step 6: Verifying import...${NC}"
echo "Checking database contents..."

# Query to count records
COUNT_QUERY="
SELECT 
    'Congress Sessions' as table_name, COUNT(*) as count FROM public.congress
UNION ALL
SELECT 'Legislation', COUNT(*) FROM public.legislation
UNION ALL
SELECT 'Legislation Versions', COUNT(*) FROM public.legislation_version
UNION ALL
SELECT 'Legislation Content', COUNT(*) FROM public.legislation_content;
"

if psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c "$COUNT_QUERY" 2>/dev/null; then
    echo -e "${GREEN}✓ Database verification successful${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify database contents${NC}"
fi
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}Setup and Import Complete!${NC}"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Start the FastAPI server: cd .. && ./start_local.sh"
echo "  2. Test the API: curl http://localhost:9091/congress"
echo "  3. View logs in: import_*.log"
echo ""
echo "To import more data:"
echo "  - Set CONGRESS_API_KEY environment variable"
echo "  - Run individual importers: python -m billparser.importers.<name>"
echo "  - Available importers: bills, sponsors, actions, votes, statuses, bioguide"
echo ""
