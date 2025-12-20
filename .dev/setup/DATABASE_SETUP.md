# Database Setup and Import Guide

This guide explains how to set up your database and import congressional data.

## Prerequisites

- PostgreSQL 16 running (check with `docker ps`)
- Python 3.9+ with required packages installed
- Environment variables set (see `.env` file)

## Quick Start (Recommended)

**Import sample data in ~10 minutes:**

```bash
cd backend
./quick_import.sh
```

This will:
- Download House bills from current Congress (~500MB)
- Import into your database
- Show statistics

## Full Setup and Import

**Complete data import with all options:**

```bash
cd backend
./setup_and_import.sh
```

This comprehensive script will:
1. Verify database connection
2. Run schema migrations
3. Download data from current Congress
4. Import bills, sponsors, actions, statuses
5. Optionally import US Code
6. Verify the import

## Database Schema Verification

**Check if your database schema is correct:**

```bash
cd backend
python verify_schema.py
```

This will:
- Test database connection
- Check for required schemas (public, appropriations, prompts, sensitive)
- Verify table structure
- Show database statistics

## Manual Import Steps

If you need more control, import data step by step:

### 1. Set Environment Variables

```bash
export db_host=localhost
export db_user=parser
export db_pass=parser
export db_table=us_code_2025
export PARSE_THREADS=4
export CONGRESS_API_KEY="your_key"  # Get from https://api.congress.gov/
```

### 2. Create Database Schema

```bash
cd backend

# Option A: Use Alembic migrations (recommended)
alembic upgrade head

# Option B: Create tables directly
python verify_schema.py  # Choose 'y' when prompted
```

### 3. Download Data

Bills are available at: `https://www.govinfo.gov/bulkdata/BILLS/{congress}/{session}/{chamber}/`

Example downloads:
```bash
mkdir -p bills
cd bills

# 119th Congress, Session 1, House
wget https://www.govinfo.gov/bulkdata/BILLS/119/1/hr/BILLS-119-1-hr.zip

# 119th Congress, Session 1, Senate
wget https://www.govinfo.gov/bulkdata/BILLS/119/1/s/BILLS-119-1-s.zip
```

### 4. Import Data

Import in this order for best results:

```bash
cd backend

# 1. Bills (required first)
python -m billparser.importers.bills

# 2. Sponsors (requires CONGRESS_API_KEY)
python -m billparser.importers.sponsors

# 3. Actions (requires CONGRESS_API_KEY)
python -m billparser.importers.actions

# 4. Bill statuses
python -m billparser.importers.statuses

# 5. Votes
python -m billparser.importers.votes

# 6. Cleanup
python -m billparser.importers.cleanup
```

### 5. Optional: Import US Code

```bash
# This takes several hours and significant disk space
python -m billparser.importers.releases \
  --release-point="https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip"
```

## Database Schema

The database contains several schemas:

### `public` Schema
Core legislative data:
- `congress` - Congressional sessions
- `legislation` - Bills and resolutions
- `legislation_version` - Different versions of bills (IH, RH, etc.)
- `legislation_content` - Structured bill text
- `legislator` - Members of Congress
- `sponsor` - Bill sponsors/cosponsors
- `committee` - Congressional committees
- `vote` - Voting records
- `usc_section` - US Code sections
- `usc_content` - US Code text
- `usc_release` - US Code release points

### `appropriations` Schema
Appropriations data extracted from bills

### `prompts` Schema
AI-generated analysis and tags

### `sensitive` Schema
User authentication data

## Verification

**Check what's in your database:**

```bash
psql "postgresql://parser:parser@localhost/us_code_2025" -c "
SELECT 
    c.session_number as congress,
    l.chamber,
    COUNT(DISTINCT l.legislation_id) as bills,
    COUNT(DISTINCT lv.legislation_version_id) as versions
FROM legislation l
JOIN congress c ON l.congress_id = c.congress_id
LEFT JOIN legislation_version lv ON l.legislation_id = lv.legislation_id
GROUP BY c.session_number, l.chamber
ORDER BY c.session_number DESC, l.chamber;
"
```

## Troubleshooting

### "Connection refused" error
- Check if PostgreSQL container is running: `docker ps`
- Verify connection string in `.env`
- Check if port 5432 is accessible: `nc -zv localhost 5432`

### "Schema does not exist" error
- Run: `python verify_schema.py` to create schemas
- Or manually: `psql ... -c "CREATE SCHEMA IF NOT EXISTS appropriations;"`

### "No such file or directory: bills/*.zip"
- Download data first (see step 3 above)
- Or run `./quick_import.sh` which downloads automatically

### Import runs but no data appears
- Check the logs: `import_*.log`
- Verify Congress session exists: `SELECT * FROM congress;`
- Ensure downloaded ZIP files contain XML files

### "Module not found" errors
- Install dependencies: `pip install -r requirements.txt`
- Activate virtual environment: `pyenv activate congress-dev`

## Data Sources

- **Congressional Bills**: https://www.govinfo.gov/bulkdata/BILLS/
- **US Code**: https://uscode.house.gov/download/
- **Congress API**: https://api.congress.gov/ (requires free API key)

## Next Steps

After importing data:

1. **Start the API server:**
   ```bash
   cd ..
   ./start_local.sh
   ```

2. **Test the API:**
   ```bash
   curl http://localhost:9091/congress
   curl http://localhost:9091/legislation?congress=119&chamber=House
   ```

3. **Run the frontend:**
   ```bash
   cd ../frontend
   npm install
   npm start
   ```

## Additional Resources

- Import script: `./import.sh` - Production import script
- Alembic migrations: `alembic/versions/` - Database schema versions
- Database models: `billparser/db/models.py` - SQLAlchemy models
- Import modules: `billparser/importers/` - Individual importer scripts
