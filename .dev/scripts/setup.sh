#!/bin/bash
set -e

# Congress.dev Environment Setup and Database Schema Script
# This script will:
# 1. Verify and configure environment variables
# 2. Verify database connection
# 3. Activate Python virtual environment
# 4. Run database migrations to set up schema
# 5. Create required directories
# 
# Note: This script does NOT import data. Use import.sh for data import.

echo "=================================================="
echo "Congress.dev Environment Setup"
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

echo -e "${YELLOW}Step 1: Verifying environment variables...${NC}"

# Load .env file if it exists
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment from: $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Loaded .env file${NC}"
else
    echo -e "${YELLOW}⚠ No .env file found at $ENV_FILE${NC}"
    echo "Using environment variables or defaults"
fi

# Set configuration with defaults
export db_host=${DB_HOST:-localhost}
export db_user=${DB_USER:-parser}
export db_pass=${DB_PASS:-parser}
export db_table=${DB_TABLE:-us_code_2025}
export PARSE_THREADS=${PARSE_THREADS:-4}
export CONGRESS_API_KEY=${CONGRESS_API_KEY:-}

# Validate required variables
MISSING_VARS=()
[ -z "$db_host" ] && MISSING_VARS+=("DB_HOST")
[ -z "$db_user" ] && MISSING_VARS+=("DB_USER")
[ -z "$db_pass" ] && MISSING_VARS+=("DB_PASS")
[ -z "$db_table" ] && MISSING_VARS+=("DB_TABLE")

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Missing required environment variables: ${MISSING_VARS[*]}${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Database Host: $db_host"
echo "  Database User: $db_user"
echo "  Database Name: $db_table"
echo "  Parse Threads: $PARSE_THREADS"
if [ -n "$CONGRESS_API_KEY" ]; then
    echo "  Congress API Key: ${CONGRESS_API_KEY:0:8}..."
else
    echo -e "  Congress API Key: ${YELLOW}not set${NC}"
fi
echo ""

# Step 2: Verify database connection
echo -e "${YELLOW}Step 2: Verifying database connection...${NC}"
if psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c '\q' 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Please check your database credentials and ensure PostgreSQL is running."
    echo "Connection string: postgresql://${db_user}:***@${db_host}/${db_table}"
    exit 1
fi
echo ""

# Step 3: Create and activate virtual environment
echo -e "${YELLOW}Step 3: Setting up Python virtual environment...${NC}"
VENV_DIR="$ROOT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Created virtual environment${NC}"
else
    echo "Virtual environment already exists"
fi

if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
    echo -e "${GREEN}✓ Activated Python virtual environment${NC}"
    echo "  Path: $VENV_DIR"
    echo "  Python: $(which python)"
else
    echo -e "${RED}✗ Failed to create virtual environment${NC}"
    exit 1
fi
echo ""

# Step 4: Install Python dependencies
echo -e "${YELLOW}Step 4: Installing Python dependencies...${NC}"

# Essential packages for core functionality
ESSENTIAL_PACKAGES=(
    "sqlalchemy"
    "psycopg2-binary"
    "alembic"
    "python-json-logger"
    "lxml"
    "beautifulsoup4"
    "click"
    "requests"
    "python-dateutil"
    "unidecode"
    "pytz"
    "joblib"
)

echo "Installing essential packages..."
pip install --upgrade pip > /dev/null 2>&1
pip install "${ESSENTIAL_PACKAGES[@]}" 2>&1 | grep -v "already satisfied" | grep -v "Requirement already" || true
echo -e "${GREEN}✓ Essential packages installed${NC}"

# Try to install full requirements if available
REQUIREMENTS_FILE="$BACKEND_DIR/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo ""
    echo "Full requirements.txt found. Attempting to install additional packages..."
    echo "(Some packages may fail on Python 3.13 - this is expected)"
    pip install -r "$REQUIREMENTS_FILE" 2>&1 | grep -E "(Successfully installed|ERROR|Failed)" | head -20 || true
    echo -e "${YELLOW}Note: Some packages (spacy, blis) may fail on Python 3.13. Core functionality works without them.${NC}"
fi
echo ""

# Verify critical packages
echo -e "${YELLOW}Verifying critical packages...${NC}"
CRITICAL_PACKAGES=("sqlalchemy" "psycopg2" "alembic")
ALL_INSTALLED=true

for package in "${CRITICAL_PACKAGES[@]}"; do
    if python -c "import $package" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $package"
    else
        echo -e "  ${RED}✗${NC} $package"
        ALL_INSTALLED=false
    fi
done

if [ "$ALL_INSTALLED" = false ]; then
    echo -e "${RED}✗ Critical packages missing${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All critical packages verified${NC}"
echo ""

# Step 5: Run database migrations
echo -e "${YELLOW}Step 5: Setting up database schema...${NC}"
echo "Running Alembic migrations..."

# Update alembic.ini with correct connection string
export SQLALCHEMY_URL="postgresql://${db_user}:${db_pass}@${db_host}/${db_table}"
sed -i.bak "s|^sqlalchemy.url = .*|sqlalchemy.url = ${SQLALCHEMY_URL}|" alembic.ini

# Run migrations
if alembic upgrade head 2>&1 | tee "$LOG_DIR/setup_alembic.log"; then
    echo -e "${GREEN}✓ Database schema created successfully${NC}"
else
    echo -e "${RED}✗ Migration failed${NC}"
    echo "Check logs at: $LOG_DIR/setup_alembic.log"
    exit 1
fi
echo ""

# Step 6: Create required directories
echo -e "${YELLOW}Step 6: Creating required directories...${NC}"
mkdir -p bills
echo -e "${GREEN}✓ Created bills/ directory${NC}"
echo ""

# Step 7: Verify schema
echo -e "${YELLOW}Step 7: Verifying database schema...${NC}"
SCHEMA_QUERY="
SELECT 
    schemaname,
    tablename 
FROM pg_catalog.pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
"

if psql "postgresql://${db_user}:${db_pass}@${db_host}/${db_table}" -c "$SCHEMA_QUERY" 2>/dev/null | tee "$LOG_DIR/setup_schema_check.log"; then
    echo -e "${GREEN}✓ Database schema verification successful${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify database schema${NC}"
fi
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}Environment Setup Complete!${NC}"
echo "=================================================="
echo ""
echo "Environment Configuration:"
echo "  ✓ Database connection verified"
echo "  ✓ Python virtual environment activated"
echo "  ✓ Database schema created"
echo "  ✓ Required directories created"
echo ""
echo "Next steps:"
echo "  1. Import data: ./import.sh"
echo "  2. Or run individual importers:"
echo "     python -m billparser.importers.bills"
echo "     python -m billparser.importers.sponsors"
echo "  3. Start API server: ../start_api.sh"
echo ""
echo "Logs saved to: $LOG_DIR/"
echo ""
