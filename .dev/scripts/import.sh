#!/bin/bash
set -e

# Congress.dev Data Import Script
# This script imports congressional data into the database using billparser importers.
# 
# Prerequisites:
# - Database must be set up (run setup.sh first)
# - Python virtual environment must be activated
# - Environment variables must be configured
#
# Import Order (based on congress-dev/import.sh):
# 1. Bills - Download and import bill XML data
# 2. Prompts - Process prompts/summaries
# 3. Bioguide - Import bioguide data (legislator info)
# 4. Sponsors - Import bill sponsor data (requires API key)
# 5. Releases - Import US Code release points
# 6. Actions - Import legislative actions (requires API key)
# 7. Votes - Import vote records
# 8. Statuses - Import bill statuses
# 9. Cleanup - Post-import cleanup operations

echo "=================================================="
echo "Congress.dev Data Import"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Navigate to backend directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../../../backend" && pwd)"
ROOT_DIR="$(cd "$BACKEND_DIR/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
cd "$BACKEND_DIR"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"

echo -e "${YELLOW}Loading environment configuration...${NC}"

# Load .env file if it exists
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Loaded .env file${NC}"
fi

# Set configuration with defaults
export db_host=${DB_HOST:-localhost}
export db_user=${DB_USER:-parser}
export db_pass=${DB_PASS:-parser}
export db_table=${DB_TABLE:-us_code_2025}
export PARSE_THREADS=${PARSE_THREADS:-4}
export CONGRESS_API_KEY=${CONGRESS_API_KEY:-}

# Activate virtual environment
echo -e "${YELLOW}Activating Python virtual environment...${NC}"
VENV_DIR="$(cd "$BACKEND_DIR/../../.venv" && pwd)"
if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
    echo -e "${GREEN}✓ Activated virtual environment${NC}"
else
    echo -e "${RED}✗ Virtual environment not found at $VENV_DIR${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}Configuration:${NC}"
echo "  Database: $db_table@$db_host"
echo "  Parse Threads: $PARSE_THREADS"
if [ -n "$CONGRESS_API_KEY" ]; then
    echo "  Congress API Key: ${CONGRESS_API_KEY:0:8}..."
else
    echo -e "  Congress API Key: ${YELLOW}not set (some importers will be skipped)${NC}"
fi
echo ""

# Verify database connection
echo -e "${YELLOW}Verifying database connection...${NC}"
if psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c '\q' 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection verified${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Run setup.sh first to configure the database."
    exit 1
fi
echo ""

############################################################
# BILLS
############################################################


# Ensure bills directory exists
mkdir -p bills

# Calculate current congress
CURRENT_YEAR=$(date +%Y)
CONGRESS=$(( (CURRENT_YEAR - 2001) / 2 + 107 ))

echo "=================================================="
echo "Starting Import Process"
echo "=================================================="
echo ""
echo "This will import data for Congress: $CONGRESS"
echo "Import will run in the following order:"
echo "  1. Bills (download & import)"
echo "  2. Prompts"
echo "  3. Bioguide"
echo "  4. Sponsors (requires API key)"
echo "  5. US Code Release Points"
echo "  6. Legislative Actions (requires API key)"
echo "  7. Votes"
echo "  8. Statuses"
echo "  9. Cleanup"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Import cancelled."
    exit 0
fi
echo ""

# Track overall status
IMPORT_ERRORS=0

# Import 1: Bills
echo "=================================================="
echo -e "${YELLOW}[1/9] Importing Bills${NC}"
echo "=================================================="
echo ""
echo "Downloading and importing bill data..."
echo "This will take 10-30 minutes depending on your system and network."
echo ""

# Download bills if not already present
DOWNLOAD_COUNT=0
for SESSION in 1; do
    for CHAMBER in hr s; do
        URL="https://www.govinfo.gov/bulkdata/BILLS/${CONGRESS}/${SESSION}/${CHAMBER}/BILLS-${CONGRESS}-${SESSION}-${CHAMBER}.zip"
        OUTPUT_FILE="bills/BILLS-${CONGRESS}-${SESSION}-${CHAMBER}.zip"
        
        if [ -f "$OUTPUT_FILE" ]; then
            echo -e "${GREEN}✓ Already downloaded: $OUTPUT_FILE${NC}"
            DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
        else
            echo "Downloading: $URL"
            if wget -q --show-progress -O "$OUTPUT_FILE" "$URL" 2>&1; then
                echo -e "${GREEN}✓ Downloaded: $OUTPUT_FILE${NC}"
                DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
            else
                echo -e "${YELLOW}⚠ Failed to download (may not exist yet)${NC}"
            fi
        fi
    done
done

echo ""
if [ $DOWNLOAD_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No bill data available${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
else
    echo -e "${GREEN}Found $DOWNLOAD_COUNT bill archive(s)${NC}"
    echo "Importing bills into database..."
    if python -m billparser.importers.bills 2>&1 | tee "$LOG_DIR/import_bills.log"; then
        echo -e "${GREEN}✓ Bills imported successfully${NC}"
    else
        echo -e "${RED}✗ Bill import failed (see logs/import_bills.log)${NC}"
        IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
    fi
fi
echo ""

# Import 2: Prompts
echo "=================================================="
echo -e "${YELLOW}[2/9] Importing Prompts${NC}"
echo "=================================================="
echo ""
if python -m billparser.importers.prompts 2>&1 | tee "$LOG_DIR/import_prompts.log"; then
    echo -e "${GREEN}✓ Prompts imported successfully${NC}"
else
    echo -e "${RED}✗ Prompt import failed (see logs/import_prompts.log)${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
fi
echo ""

# Import 3: Bioguide
echo "=================================================="
echo -e "${YELLOW}[3/9] Importing Bioguide Data${NC}"
echo "=================================================="
echo ""
if python -m billparser.importers.bioguide 2>&1 | tee "$LOG_DIR/import_bioguide.log"; then
    echo -e "${GREEN}✓ Bioguide data imported successfully${NC}"
else
    echo -e "${RED}✗ Bioguide import failed (see logs/import_bioguide.log)${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
fi
echo ""

# Import 4: Sponsors (requires API key)
echo "=================================================="
echo -e "${YELLOW}[4/9] Importing Sponsors${NC}"
echo "=================================================="
echo ""
if [ -n "$CONGRESS_API_KEY" ]; then
    if python -m billparser.importers.sponsors 2>&1 | tee "$LOG_DIR/import_sponsors.log"; then
        echo -e "${GREEN}✓ Sponsors imported successfully${NC}"
    else
        echo -e "${RED}✗ Sponsor import failed (see logs/import_sponsors.log)${NC}"
        IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Skipping sponsors (CONGRESS_API_KEY not set)${NC}"
    echo "  Get your API key at: https://api.congress.gov/"
fi
echo ""

# Import 5: US Code Release Points
echo "=================================================="
echo -e "${YELLOW}[5/9] Importing US Code Release Points${NC}"
echo "=================================================="
echo ""
echo "This will download and import US Code XML (600MB+)."
echo "This can take 30-60 minutes."
read -p "Import US Code? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Use latest release point
    USC_URL="https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip"
    if python -m billparser.importers.releases --release-point="$USC_URL" 2>&1 | tee "$LOG_DIR/import_usc.log"; then
        echo -e "${GREEN}✓ US Code imported successfully${NC}"
    else
        echo -e "${RED}✗ US Code import failed (see logs/import_usc.log)${NC}"
        IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Skipping US Code import${NC}"
fi
echo ""

# Import 6: Actions (requires API key)
echo "=================================================="
echo -e "${YELLOW}[6/9] Importing Legislative Actions${NC}"
echo "=================================================="
echo ""
if [ -n "$CONGRESS_API_KEY" ]; then
    if python -m billparser.importers.actions 2>&1 | tee "$LOG_DIR/import_actions.log"; then
        echo -e "${GREEN}✓ Actions imported successfully${NC}"
    else
        echo -e "${RED}✗ Action import failed (see logs/import_actions.log)${NC}"
        IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Skipping actions (CONGRESS_API_KEY not set)${NC}"
fi
echo ""

# Import 7: Votes
echo "=================================================="
echo -e "${YELLOW}[7/9] Importing Votes${NC}"
echo "=================================================="
echo ""
if python -m billparser.importers.votes 2>&1 | tee "$LOG_DIR/import_votes.log"; then
    echo -e "${GREEN}✓ Votes imported successfully${NC}"
else
    echo -e "${RED}✗ Vote import failed (see logs/import_votes.log)${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
fi
echo ""

# Import 8: Statuses
echo "=================================================="
echo -e "${YELLOW}[8/9] Importing Bill Statuses${NC}"
echo "=================================================="
echo ""
if python -m billparser.importers.statuses 2>&1 | tee "$LOG_DIR/import_statuses.log"; then
    echo -e "${GREEN}✓ Statuses imported successfully${NC}"
else
    echo -e "${RED}✗ Status import failed (see logs/import_statuses.log)${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
fi
echo ""

# Import 9: Cleanup
echo "=================================================="
echo -e "${YELLOW}[9/9] Running Post-Import Cleanup${NC}"
echo "=================================================="
echo ""
if python -m billparser.importers.cleanup 2>&1 | tee "$LOG_DIR/import_cleanup.log"; then
    echo -e "${GREEN}✓ Cleanup completed successfully${NC}"
else
    echo -e "${RED}✗ Cleanup failed (see logs/import_cleanup.log)${NC}"
    IMPORT_ERRORS=$((IMPORT_ERRORS + 1))
fi
echo ""

# Verify import
echo "=================================================="
echo -e "${YELLOW}Verifying Import${NC}"
echo "=================================================="
echo ""

COUNT_QUERY="
SELECT 
    'Congress Sessions' as table_name, COUNT(*) as count FROM public.congress
UNION ALL
SELECT 'Legislation', COUNT(*) FROM public.legislation
UNION ALL
SELECT 'Legislators', COUNT(*) FROM public.legislator
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
if [ $IMPORT_ERRORS -eq 0 ]; then
    echo -e "${GREEN}Import Complete!${NC}"
else
    echo -e "${YELLOW}Import Completed with $IMPORT_ERRORS Error(s)${NC}"
fi
echo "=================================================="
echo ""
echo "Import Summary:"
if [ -n "$CONGRESS_API_KEY" ]; then
    echo "  ✓ Congress API Key configured"
else
    echo "  ⚠ Congress API Key not set (some data was skipped)"
fi
echo "  Logs saved to: $LOG_DIR/"
echo ""
echo "Next steps:"
echo "  1. Verify data: ../tests/db.sh"
echo "  2. Start API server: ../start_api.sh"
echo "  3. Test endpoint: curl http://localhost:9091/congress"
echo ""
echo "To re-run specific importers:"
echo "  cd $BACKEND_DIR"
echo "  python -m billparser.importers.<name>"
echo ""
