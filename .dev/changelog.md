# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed - auto-edits-001 (2025-12-19)

#### Backend

**billparser/importers/cleanup.py**
- Fixed SQLAlchemy 2.0 compatibility issues in `cleanup_legislation()` function
- Replaced deprecated `engine.execute(query)` with `engine.connect()` context manager
- Added `text()` wrapper for raw SQL queries to comply with SQLAlchemy 2.0 requirements
- Added explicit `conn.commit()` for transaction management
- **Impact**: Prevents `AttributeError: 'Engine' object has no attribute 'execute'` during cleanup operations

**billparser/run_through.py**
- Fixed IndexError in `find_or_create_bill()` when USCRelease table is empty
- Added conditional check for empty `release_point` query result before accessing index `[0]`
- Allows `Version(base_id=None)` when no USC releases exist yet
- **Impact**: Enables bills to be imported before US Code releases (resolves import order dependency)
- **Related**: Bills are imported in step 1, US Code releases in step 5 of import process

**billparser/bioguide/types.py**
- Fixed Pydantic validation error in `ResearchRecordItem` model
- Made `recordLocation` field optional to handle missing field in some bioguide records
- Fixed Pydantic validation error in `NameHistoryItem` model
- Made all fields in `NameHistoryItem` optional (familyName, givenName, middleName, duplicateName, startDate, startCirca, endDate, endCirca)
- **Error**: `ValidationError: nameHistory.0.startDate/endDate Field required [type=missing]`
- **Impact**: Bioguide importer can now process all legislator profiles including those with incomplete name history records

**billparser/metadata/sponsors.py**
- Fixed foreign key constraint violation in `extract_sponsors_from_api()` function
- Added check to verify legislator exists in database before creating sponsorship record
- **Error**: `ForeignKeyViolation: legislation_sponsorship_legislator_bioguide_id_fkey - Key (legislator_bioguide_id)=(S001176) is not present in table "legislator"`
- **Impact**: Sponsors importer now skips sponsors with missing bioguide IDs instead of crashing
- Logs warning message when sponsor bioguide_id not found in legislator table

### Changed

#### Backend

**import.sh**
- Updated `DATABASE_HOST` from `localhost` to `host.docker.internal`
- **Reason**: Docker containers on macOS cannot access `localhost` - must use special DNS name to reach host machine services
- **Impact**: Docker-based import process can now connect to PostgreSQL running on host

### Added

#### Documentation

**.dev/docs/backend.md**
- Created comprehensive backend documentation (400+ lines)
- Documented dual API architecture (Flask + FastAPI)
- Detailed parser/importer system with 9-step import order
- Complete database schema documentation (28+ tables)
- Dependencies, configuration, observability, and troubleshooting guides

---

## Notes

- **auto-edits-001**: Marker for tracking automated code fixes applied during debugging session
- All changes tested and verified working with Python 3.9.25 and PostgreSQL
- Import process now completes successfully with proper error handling
