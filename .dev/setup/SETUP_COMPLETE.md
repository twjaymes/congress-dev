# Database Setup Complete! ✓

## Current Status

Your database is **already set up** with data! Here's what you have:

```
Database: us_code_2025@localhost
User: parser

Congressional Sessions:
  116th Congress (2019-2020)

Bills Imported:
  House:  5,524 bills (6,753 versions)
  Senate: 3,131 bills (3,578 versions)
  Total:  8,655 bills

Content:
  827,699 legislation content records
  56,676 US Code sections
  737,686 US Code content records
```

## Scripts Created

I've created three scripts for managing your database:

### 1. `check_db.py` - Quick Status Check
```bash
python check_db.py
```
Shows what's currently in your database.

### 2. `quick_import.sh` - Import Sample Data
```bash
./quick_import.sh
```
Downloads and imports House bills from current Congress (~10 minutes).

### 3. `setup_and_import.sh` - Full Import
```bash
./setup_and_import.sh
```
Complete setup with all importers (bills, sponsors, actions, votes, etc.).

### 4. `verify_schema.py` - Schema Verification
```bash
python verify_schema.py
```
Checks and creates database schemas and tables.

### 5. `start_api.sh` - Schema Verification
```bash
python start_api.sh
```
Starts API

## Next Steps

### Option A: Use Existing Data (Recommended)

Your database already has 116th Congress data. You can:

1. **Start the FastAPI server:**
   ```bash
   cd /home/ktnta/projects/congress-dev/congress-dev/backend
   # Set environment variables
   export db_host=localhost db_user=parser db_pass=parser db_table=us_code_2025
   # Run server
   uvicorn congress_fastapi.app:app --host 0.0.0.0 --port 9091 --reload
   ```

2. **Test the endpoints:**
   ```bash
   # List congress sessions
   curl http://localhost:9091/congress
   
   # Get specific congress
   curl http://localhost:9091/congress/116
   
   # List bills (once you've migrated more endpoints)
   curl http://localhost:9091/legislation?congress=116&chamber=House
   ```

### Option B: Import Current Congress (119th)

If you want newer data:

```bash
cd /home/ktnta/projects/congress-dev/congress-dev/backend
./quick_import.sh
```

This will download and import 119th Congress data (current).

### Option C: Full Data Import

For comprehensive data including sponsors, actions, and votes:

```bash
# Get a free API key from https://api.congress.gov/
export CONGRESS_API_KEY="your_key_here"

cd /home/ktnta/projects/congress-dev/congress-dev/backend
./setup_and_import.sh
```

## Database Connection Info

For all scripts and the API, use these environment variables:

```bash
export db_host=localhost
export db_user=parser
export db_pass=parser
export db_table=us_code_2025
```

Or add to your `.env` file:
```
DB_HOST=localhost
DB_USER=parser
DB_PASS=parser
DB_NAME=us_code_2025
DB_TABLE=us_code_2025
```

## Documentation

- `DATABASE_SETUP.md` - Complete setup guide
- `README.md` - Backend documentation (in /backend directory)
- Import logs: `import_*.log` files

## Useful Commands

```bash
# Check database status
python check_db.py

# Connect to database directly
psql "postgresql://parser:parser@localhost/us_code_2025"

# Count bills by congress
psql "postgresql://parser:parser@localhost/us_code_2025" -c \
  "SELECT c.session_number, COUNT(*) FROM legislation l
   JOIN congress c ON l.congress_id = c.congress_id
   GROUP BY c.session_number;"

# Import specific congress
python -m billparser.importers.bills

# View import logs
tail -f import_bills.log
```

## What's Already Working

Based on your existing data, these endpoints should work now:

- ✓ `GET /congress` - List congress sessions
- ✓ `GET /congress/{session}` - Get specific congress
- ✓ Bill queries (when you migrate those endpoints)
- ✓ US Code queries (when you migrate those endpoints)

## Testing the Migration

To test your newly migrated congress endpoints:

```bash
cd /home/ktnta/projects/congress-dev/congress-dev/backend

# Start the server
uvicorn congress_fastapi.app:app --port 9091

# In another terminal, test:
curl http://localhost:9091/congress
curl http://localhost:9091/congress/116
```

You should see the 116th Congress data returned!
