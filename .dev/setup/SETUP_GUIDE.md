# Congress.dev Local Setup Guide

## Overview

The setup process has been refactored into two distinct scripts with clear separation of concerns:

- **setup.sh**: Environment validation, configuration, and database schema setup
- **import.sh**: Data import workflow using billparser ETL components

## Scripts

### setup.sh - Environment Setup & Schema

**Purpose**: Validate environment, configure database, and apply schema migrations.

**What it does**:
1. Load and validate environment variables from `.env`
2. Verify database connectivity
3. Activate Python virtual environment
4. Check required Python dependencies
5. Run Alembic migrations to create database schema
6. Create required directories (bills/, logs/)
7. Verify schema creation

**Usage**:
```bash
cd /Users/tj/projects/congress-dev/congress-dev
./.dev/local/scripts/setup.sh
```

**Requirements**:
- PostgreSQL running and accessible
- `.env` file configured (or environment variables set)
- Python virtual environment at `~/projects/congress-dev/.venv`
- Core dependencies: sqlalchemy, psycopg2, alembic

**Output**:
- Database schema created (28 tables)
- Logs saved to `logs/setup_alembic.log` and `logs/setup_schema_check.log`
- Verification of database connection and schema

### import.sh - Data Import Workflow

**Purpose**: Import congressional data using billparser ETL components.

**What it does** (in order):
1. **Bills**: Download and import bill XML from GovInfo
2. **Prompts**: Process bill prompts/summaries
3. **Bioguide**: Import legislator biographical data
4. **Sponsors**: Import bill sponsorship data (requires API key)
5. **Releases**: Import US Code release points (optional, ~600MB+)
6. **Actions**: Import legislative actions (requires API key)
7. **Votes**: Import vote records
8. **Statuses**: Import bill statuses
9. **Cleanup**: Post-import data cleanup

**Usage**:
```bash
cd /Users/tj/projects/congress-dev/congress-dev
./.dev/local/scripts/import.sh
```

**Requirements**:
- Database schema must be set up (run setup.sh first)
- Python virtual environment activated
- Environment variables configured
- Optional: `CONGRESS_API_KEY` for sponsor/action imports

**Notes**:
- Import process is interactive with confirmation prompts
- Each step logs to separate files: `logs/import_<name>.log`
- Bills are downloaded to `backend/bills/` directory
- US Code import is optional and can take 30-60 minutes
- Importers requiring API key will be skipped if not configured

**Output**:
- Congressional data imported into database
- Logs saved to `logs/import_*.log`
- Database verification showing record counts

## Environment Variables

Required variables (set in `.dev/local/.env` or environment):

```bash
# Database Configuration
DB_HOST=localhost              # PostgreSQL host
DB_USER=parser                 # Database user
DB_PASS=parser                 # Database password
DB_TABLE=us_code_2025          # Database name

# Optional Configuration
PARSE_THREADS=16               # Parallel processing threads
CONGRESS_API_KEY=...           # API key from api.congress.gov
```

## Complete Setup Workflow

### First Time Setup

1. **Configure environment**:
   ```bash
   cd /Users/tj/projects/congress-dev/congress-dev/.dev/local
   # Edit .env file with your configuration
   ```

2. **Run setup**:
   ```bash
   cd /Users/tj/projects/congress-dev/congress-dev
   ./.dev/local/scripts/setup.sh
   ```
   This creates the database schema and validates the environment.

3. **Import data**:
   ```bash
   ./.dev/local/scripts/import.sh
   ```
   This downloads and imports congressional data.

4. **Verify import**:
   ```bash
   ./.dev/local/tests/db.sh
   ```
   This checks that data exists in key tables.

5. **Start API server**:
   ```bash
   ./.dev/local/scripts/start_api.sh
   ```

### Updating Data

To refresh congressional data without recreating the schema:

```bash
cd /Users/tj/projects/congress-dev/congress-dev
./.dev/local/scripts/import.sh
```

### Running Individual Importers

After setup, you can run specific importers:

```bash
cd /Users/tj/projects/congress-dev/congress-dev/backend
source ~/projects/congress-dev/.venv/bin/activate

# Import specific data
python -m billparser.importers.bills
python -m billparser.importers.sponsors
python -m billparser.importers.actions
# etc.
```

## Comparison with Docker Workflow

The local scripts mirror the Docker-based workflow in `congress-dev/import.sh`:

| Docker Version | Local Version | Notes |
|---------------|---------------|-------|
| `docker run ... bills` | `python -m billparser.importers.bills` | Downloads to backend/bills/ |
| `docker run ... prompts` | `python -m billparser.importers.prompts` | Processes prompts |
| `docker run ... bioguide` | `python -m billparser.importers.bioguide` | Imports legislator data |
| `docker run ... sponsors` | `python -m billparser.importers.sponsors` | Requires API key |
| `docker run ... releases` | `python -m billparser.importers.releases` | US Code, optional |
| `docker run ... actions` | `python -m billparser.importers.actions` | Requires API key |
| `docker run ... votes` | `python -m billparser.importers.votes` | Vote records |
| `docker run ... statuses` | `python -m billparser.importers.statuses` | Bill statuses |
| `docker run ... cleanup` | `python -m billparser.importers.cleanup` | Post-import cleanup |

**Key Differences**:
- Local version uses virtual environment instead of Docker containers
- Local version uses localhost database instead of Docker network IP
- Local version uses environment variables from .env file
- Local version downloads to backend/bills/ instead of mounted volume
- Local version is interactive with confirmation prompts

## Troubleshooting

### Database Connection Failed
- Verify PostgreSQL is running: `docker ps | grep postgres`
- Check credentials in `.env` file
- Ensure database exists: `psql -U parser -h localhost -l`

### Virtual Environment Not Found
- Create venv: `python3 -m venv ~/projects/congress-dev/.venv`
- Install dependencies: `pip install sqlalchemy psycopg2-binary alembic`

### Import Fails with Missing Modules
- Activate venv: `source ~/projects/congress-dev/.venv/bin/activate`
- Install requirements: `pip install -r backend/requirements.txt`
- Note: Some packages may fail on Python 3.13, but core functionality works

### No Data Downloaded
- Check internet connection
- Verify Congress session exists (current: 119th)
- Try previous congress: edit CONGRESS variable in import.sh

### API Key Required Errors
- Get API key at: https://api.congress.gov/
- Add to `.env`: `CONGRESS_API_KEY=your_key_here`

## Logs

All logs are saved to `congress-dev/logs/`:

- `setup_alembic.log` - Database migration logs
- `setup_schema_check.log` - Schema verification
- `import_bills.log` - Bill import logs
- `import_prompts.log` - Prompt processing logs
- `import_bioguide.log` - Bioguide import logs
- `import_sponsors.log` - Sponsor import logs
- `import_usc.log` - US Code import logs
- `import_actions.log` - Action import logs
- `import_votes.log` - Vote import logs
- `import_statuses.log` - Status import logs
- `import_cleanup.log` - Cleanup operation logs

See `logs/README.md` for log management details.
