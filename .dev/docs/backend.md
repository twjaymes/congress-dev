# Backend Documentation

## Overview

The Congress.dev backend provides a dual API architecture (Flask + FastAPI) for accessing congressional data, along with a comprehensive parser/importer system for ingesting data from various government sources.

**Key Components:**
- **APIs**: Flask (OpenAPI/Connexion) and FastAPI for data access
- **Parser**: Bill parsing, bioguide import, and data transformation utilities
- **Database**: PostgreSQL with SQLAlchemy ORM and Alembic migrations
- **Importers**: Automated data ingestion from Congress.gov, GovInfo, and other sources

---

## API Architecture

### FastAPI (`congress_fastapi/`)

**Framework**: FastAPI 0.108.0 with async database support  
**Port**: 9001 (configurable via `FASTAPI_PORT`)  
**Entry Point**: `congress_fastapi/app.py`

#### Features
- Async database operations via `databases[postgresql]`
- Rate limiting with `slowapi`
- CORS enabled for `localhost:3000` and `congress.dev`
- CamelCase/snake_case conversion via `pyhumps`
- Exception logging middleware

#### Routes

**Members** (`routes/members.py`)
- `GET /members` - List legislators with filtering and sorting
- `GET /member/{bioguide_id}` - Get legislator details
- `GET /member/{bioguide_id}/sponsorships` - Get sponsorship history
- `POST /members/search` - Full-text search for legislators

**Legislation** (`routes/legislation.py`)
- `GET /legislation` - List bills with pagination
- `GET /legislation/{legislation_id}` - Get bill details
- `GET /legislation/{legislation_id}/actions` - Get legislative actions
- `GET /legislation/{legislation_id}/versions` - Get bill versions

**Legislation Versions** (`routes/legislation_version.py`)
- `GET /legislation_version/{version_id}` - Get version details
- `GET /legislation_version/{version_id}/content` - Get bill text
- `GET /legislation_version/{version_id}/sections` - Get section breakdown
- `GET /legislation_version/{version_id}/diff` - Compare versions
- `POST /legislation_version/{version_id}/summary` - Generate AI summary
- `GET /legislation_version/{version_id}/tags` - Get categorization tags

**Committees** (`routes/committees.py`)
- `GET /committees` - List congressional committees
- `GET /committees/{committee_id}` - Get committee details
- `GET /committees/{committee_id}/members` - Get committee membership
- `GET /committees/{committee_id}/legislation` - Get bills by committee

**Search** (`routes/search.py`)
- `GET /search` - Full-text search across legislation
- `GET /legislation/search` - Advanced legislation search (MCP tagged)

**Stats** (`routes/stats.py`)
- `GET /stats/legislation_calendar` - Legislative activity by date
- `GET /stats/legislation_funnel` - Bill progression statistics

**US Code** (`routes/uscode.py`)
- `GET /uscode` - Browse US Code structure
- `GET /uscode/{title}/{section}` - Get specific code sections
- `GET /uscode/search` - Search US Code

**Congress** (`routes/congress_dev.py`)
- `GET /congress` - List congress sessions

**User** (`routes/user.py`)
- User authentication and preferences (sensitive schema)

### Flask API (`congress_api/`)

**Framework**: Flask 2.0.2 with Connexion (OpenAPI)  
**Port**: 9000 (configurable via `PORT`)  
**Entry Point**: `congress_api/__main__.py`

#### Features
- OpenAPI 3.0 specification-driven via `openapi/openapi.yaml`
- Response compression with Flask-Compress
- CORS support for all origins
- Configurable cache headers (`CACHE_HEADER_TIME` env var)
- SQLAlchemy session management

#### Controllers

**Legislation Controller** (`controllers/legislation_controller.py`)
- `/congress` - Get list of congress sessions
- `/congress/search` - Bill search endpoint
- `/congress/{session}` - Get session metadata
- `/congress/{session}/bill/{chamber}/{billType}/{billNumber}` - Get specific bill
- `/congress/{session}/bill/{chamber}/{billType}/{billNumber}/{version}` - Get bill version

**US Code Controller** (`controllers/uscode_controller.py`)
- `/usc` - Browse US Code
- `/usc/{title}` - Get title structure
- `/usc/{title}/{section}` - Get section content
- `/usc/search` - Search US Code

**Default Controller** (`controllers/default_controller.py`)
- `/bill` - Quick bill lookup
- Health check endpoints

**Security Controller** (`controllers/security_controller_.py`)
- Authentication endpoints

#### OpenAPI Specification

Full API specification: `congress_api/openapi/openapi.yaml`
- 1503 lines defining all endpoints, schemas, and responses
- Automatically generates Swagger UI documentation
- Enforces request/response validation

---

## Parser & Data Pipeline

### Importers (`billparser/importers/`)

The import system ingests data from multiple government sources in a specific order to maintain referential integrity.

#### Import Order (defined in `.dev/local/scripts/import.sh`)

1. **Bills** (`bills.py`)
   - Downloads bill archives from GovInfo bulk data API
   - Source: `https://www.govinfo.gov/bulkdata/BILLS/{congress}/{session}/{chamber}/`
   - Parses XML to extract bill metadata, text, and versions
   - Stores in `legislation` and `legislation_version` tables
   - Runs appropriations analysis for spending bills

2. **Prompts** (`prompts.py`)
   - Processes LLM-generated summaries and tags
   - Links to bills via `legislation_id`
   - Schema: `prompts.legislation_content_summary`

3. **Bioguide** (`bioguide.py`)
   - Imports legislator biographical data
   - Source: Congress.gov bioguide API
   - Handles social media, committee memberships, terms
   - Uses Pydantic validation for data integrity

4. **Sponsors** (`sponsors.py`)
   - Links bills to their sponsors
   - Requires: CONGRESS_API_KEY environment variable
   - Populates `legislation_sponsorship` table

5. **US Code Releases** (`releases.py`)
   - Downloads US Code XML releases (600MB+)
   - Source: `https://uscode.house.gov/download/releasepoints/`
   - Parses into `usc_section`, `usc_content`, `usc_chapter`
   - Creates full-text search indexes

6. **Legislative Actions** (`actions.py`)
   - Imports bill action history
   - Requires: CONGRESS_API_KEY
   - Parses action text using NLP pipeline
   - Populates `legislation_action` and `legislation_action_parse`

7. **Votes** (`votes.py`)
   - Imports roll call votes
   - Links votes to bills and legislators
   - Stores in `legislation_vote` and `legislator_vote`

8. **Statuses** (`statuses.py`)
   - Updates bill status tracking
   - Processes status change events

9. **Cleanup** (`cleanup.py`)
   - Removes bills with no content
   - Deduplicates US Code releases
   - Database maintenance operations

#### Import Configuration

Environment variables (from `.dev/local/.env`):
```bash
DB_HOST=localhost:5432
DB_USER=parser
DB_PASS=parser
DB_TABLE=us_code
CONGRESS_API_KEY=<key>
PARSE_THREADS=16
DISCORD_WEBHOOK=<optional>
```

### Parser Modules

#### Bill Parser (`billparser/`)

**Main Components:**

- **`run_through.py`** - Orchestrates bill parsing from ZIP archives
- **`translater.py`** - Transforms USC XML to standardized HTML format
- **`status_parser.py`** - Parses bill status information
- **`downloader.py`** - Handles file downloads with retry logic
- **`compare.py`** - Generates bill version diffs

**Specialized Parsers:**

- **`actions/`** - Legislative action parsing and categorization
  - `parser.py` - Main action parser
  - `redesignate.py` - Handles section redesignation actions
  - `utils.py` - Action parsing utilities

- **`appropriations/`** - Spending bill analysis
  - `parser.py` - Extracts appropriation amounts using spaCy NLP
  - Identifies funding recipients and amounts

- **`bioguide/`** - Legislator data management
  - `manager.py` - Bioguide API integration
  - `generator.py` - Profile generation
  - `types.py` - Pydantic models for validation

- **`metadata/`** - Bill metadata extraction

- **`prompt_runners/`** - LLM integration for summaries and tags
  - Uses LiteLLM for multi-provider support
  - Generates structured JSON output with jsonschema validation

#### Utilities (`billparser/utils/`)

- **`citation.py`** - Legal citation parsing and resolution
- **`cite_parser.py`** - Citation format normalization
- **`logger.py`** - Centralized logging configuration

---

## Database

### Schema (`billparser/db/models.py`)

**Core Tables (1227 lines of SQLAlchemy models):**

#### Legislation Schema

**`legislation`** - Bills and resolutions
- `legislation_id` (PK)
- `chamber` (House/Senate)
- `legislation_type` (Bill/Resolution/Joint Resolution)
- `number`
- `title`
- `congress_id` (FK)
- `policy_areas` (JSONB)
- `legislative_subjects` (JSONB)

**`legislation_version`** - Bill versions (IH, IS, RFS, etc.)
- `legislation_version_id` (PK)
- `legislation_id` (FK)
- `legislation_version` (Enum: IS, IH, RAS, RAH, etc.)
- `effective_date`
- `created_at`, `completed_at`

**`legislation_content`** - Bill text sections
- `legislation_content_id` (PK)
- `legislation_version_id` (FK)
- `content_type` (section/subsection/paragraph)
- `content_str` (text content)
- `order` (section ordering)

**`legislation_content_diff`** - Version comparison data
- Tracks changes between bill versions

**`legislation_sponsorship`** - Bill sponsors
- `legislation_id` (FK)
- `bioguide_id` (FK)
- `is_original_cosponsor` (Boolean)

**`legislation_action`** - Legislative actions
- `legislation_action_id` (PK)
- `legislation_id` (FK)
- `action_date`
- `action_text`
- `action_type`

**`legislation_action_parse`** - Parsed action data
- Structured data extracted from action text

**`legislation_committee`** - Committee assignments
- Links bills to committees

**`legislation_vote`** - Roll call votes
- `legislation_vote_id` (PK)
- `legislation_id` (FK)
- `vote_date`, `vote_time`
- `vote_result` (pass/fail)
- `vote_metadata` (JSONB)

#### Legislator Schema

**`legislator`** - Member of Congress
- `bioguide_id` (PK)
- `first_name`, `last_name`
- `state`, `district`
- `party`
- `current_job` (Senator/Representative)
- `social_media` (JSONB)
- `fts` (TSVECTOR for full-text search)

**`legislator_vote`** - Individual vote records
- `legislation_vote_id` (FK)
- `bioguide_id` (FK)
- `vote` (Enum: yay/nay/present/abstain)

#### US Code Schema

**`usc_release`** - US Code release points
- `usc_release_id` (PK)
- `release_point`
- `release_date`

**`usc_section`** - Code sections
- `usc_section_id` (PK)
- `title`, `section`
- `heading`

**`usc_content`** - Section content
- `usc_content_id` (PK)
- `usc_section_id` (FK)
- `usc_release_id` (FK)
- `content` (text)

**`usc_content_diff`** - Code change tracking
- Tracks amendments between releases

**`usc_chapter`** - Code organization
- Chapter/subchapter metadata

**`usc_popular_name`** - Common law names
- Popular names for code sections

#### Metadata Schema

**`congress`** - Congress sessions
- `congress_id` (PK)
- `session_number` (116, 117, 118, etc.)
- `start_year`, `end_year`

**`version`** - Bill version types
- Defines IH, IS, RFS, etc.

**`legislative_policy_area`** - Policy categories
- `policy_area_id` (PK)
- `name`

**`legislative_subject`** - Subject tags
- `legislative_subject_id` (PK)
- `name`

#### LLM/Prompts Schema (schema: `prompts`)

**`legislation_content_summary`** - AI summaries
- Links to bill versions
- Stores generated summaries

**`legislation_content_tag`** - AI-generated tags
- Categorization tags

**`legislation_version_tag`** - Version-level tags

**`llm_query`** - LLM request tracking
- Query logging and analytics

#### Appropriations Schema (schema: `appropriations`)

- Spending analysis data
- Links appropriations to bills

#### User Schema (schema: `sensitive`)

**`user_ident`** - User accounts
- Authentication (password/Google)
- Profile data

**`user_legislation`** - Favorited bills
**`user_legislator`** - Followed legislators
**`user_usc_content`** - Tracked code sections
**`user_usc_content_folder`** - Organization folders

### Database Operations (`billparser/db/`)

**`handler.py`** - Database connection management
```python
DATABASE_URI = f"postgresql://{username}:{password}@{db_host}/{table}"
engine = create_engine(DATABASE_URI, poolclass=NullPool)
Session = scoped_session(sessionmaker(bind=engine))
```

**`queries.py`** - Common query functions
- Optimized queries for frequent operations
- Joins and aggregations

### Migrations (`alembic/`)

**Configuration**: `alembic.ini`
- Connection: `postgresql://parser:parser@localhost:5432/us_code`

**Migration Files** (`alembic/versions/`):
- `f6488f13146c_initial_migration.py` - Base schema
- `d01322760f6d_bioguide.py` - Legislator tables
- `79a29914ef4a_votes.py` - Voting system
- `92a7b9f03f89_add_legis_action.py` - Legislative actions
- `bf2269ea67a1_action_parse_table.py` - Parsed actions
- `8da0e1e71536_bill_tags.py` - Tagging system
- `a3b78ac73761_create_summary_table.py` - LLM summaries
- `3e1b4b7108bb_add_llm_query_table.py` - Query tracking
- `a1b2c3d4e5f6_add_legislator_fts.py` - Full-text search
- `c941abf22042_add_usc_tracking.py` - Code tracking
- `ea85413bf51b_committee_upgrade.py` - Committee system
- `b1fe847bfdea_cascade_deletes.py` - Referential integrity
- `3749f666c0e6_create_sensitive_user.py` - User system

**Running Migrations**:
```bash
cd backend
export db_host=localhost:5432 db_user=parser db_pass=parser db_table=us_code
alembic upgrade heads
```

**Multiple Heads**: The project maintains separate migration branches for different feature sets. Use `alembic upgrade heads` to apply all branches.

---

## Dependencies

### Core Dependencies (`requirements.txt`)

**Python Runtime**: 3.9.25

**Web Frameworks:**
- Flask 2.0.2 - Lightweight WSGI framework
- Connexion 2.5.0+ - OpenAPI integration
- Flask-CORS 3.0.10 - Cross-origin support
- Flask-Compress 1.10.1 - Response compression
- Flask-SQLAlchemy 2.5.1 - ORM integration

**Database:**
- SQLAlchemy 1.4.0 - ORM
- Alembic 1.14.0 - Migrations
- psycopg2-binary 2.8.4 - PostgreSQL driver

**Parsing:**
- lxml 4.9.1 - XML parsing
- Unidecode 1.1.1 - Text normalization

**NLP/AI:**
- spaCy 3.7.2 - Natural language processing
- en_core_web_sm 3.7.1 - English language model
- LiteLLM 1.35.5 - Multi-provider LLM interface
- tokenizers 0.15.2 - Text tokenization

**Validation:**
- Pydantic 2.5.3 - Data validation

### FastAPI Dependencies (`requirements-fastapi.txt`)

**Framework:**
- FastAPI 0.108.0 - Modern async web framework
- uvicorn[standard] - ASGI server
- slowapi 0.1.9 - Rate limiting

**Database:**
- databases[postgresql] 0.8.0 - Async database support
- SQLAlchemy 1.4.0 - ORM
- psycopg2-binary 2.8.4 - PostgreSQL driver

**Utilities:**
- pyhumps 3.8.0 - Case conversion
- requests 2.32.2 - HTTP client

**AI/Vector:**
- chromadb 0.6.3 - Vector database for embeddings
- spaCy 3.7.2 - NLP
- LiteLLM 1.35.5 - LLM integration

### Test Dependencies (`requirements-test.txt`)

Testing framework and utilities for pytest.

---

## Development Configuration

### Environment Files

**`.dev/local/.env`** - Local development settings
```env
DB_HOST=localhost:5432
DB_USER=parser
DB_PASS=parser
DB_TABLE=us_code
CONGRESS_API_KEY=<key>
PARSE_THREADS=16
```

**`.docker/.env`** - Docker environment
```env
PORT=9000
FASTAPI_PORT=9001
DB_HOST=congress_postgres:5432
POSTGRES_DB=us_code
```

### Code Quality

**`.flake8`** - Linting configuration
```ini
ignore = E501,Q000,D103,D100,D101,D102,D107,Q002,D205,D400,E203,E266,W503
max-line-length = 88
max-complexity = 18
```

**`pytest.ini`** - Test configuration
```ini
[pytest]
pythonpath = . billparser
addopts = --ignore=billparser/tests/test_routes.py
```

**`.python-version`** - Python version specification
```
3.9.25
```

### Docker Configuration

**`.docker/Dockerfile`** - Flask API container
- Based on Python 3.9
- Installs libpq-dev for PostgreSQL support
- Copies requirements.txt and installs dependencies
- Exposes port 9000

**`.docker/Dockerfile.fastapi`** - FastAPI container
- Based on Python 3.9
- Installs libpq-dev for PostgreSQL support
- Copies requirements-fastapi.txt and installs dependencies
- Exposes port 9001

### Build Configuration

**`setup.py`** - Package configuration
- Defines billparser as installable package
- Specifies entry points and dependencies

---

## Observability & Logging

### Logging System

**Configuration**: `billparser/utils/logger.py`
- Centralized logging setup
- JSON structured logs via `python-json-logger`
- Configurable log levels

**Log Outputs**:
- Console (stdout/stderr)
- File logs in `logs/` directory
- Discord webhooks for critical events (via `DISCORD_WEBHOOK` env var)

### Monitoring Endpoints

**Health Checks**:
- Flask: `/` - Basic health check
- FastAPI: Root endpoint returns OpenAPI schema

**Metrics**:
- Database connection status
- Import progress tracking
- LLM query logging (via `llm_query` table)

### Error Handling

**FastAPI Middleware** (`congress_fastapi/app.py`):
```python
@app.middleware("http")
async def log_exceptions_middleware(request: Request, call_next):
    try:
        return await call_next(request)
    except Exception as e:
        print(f"Exception occurred: {e}")
        traceback.print_exc()
        raise e
```

**Flask Error Handlers** (`congress_api/__main__.py`):
- Automatic JSON error responses
- HTTP status code propagation
- Connexion validation errors

### Import Monitoring

**Discord Notifications**:
- Import start/completion
- Bill counts
- Error alerts
- Cleanup operations

**Example**:
```python
def send_message(text):
    if webhook_url is not None:
        requests.post(webhook_url, json={"content": text})
```

---

## Testing

### Test Structure (`tests/`)

**Unit Tests**: Test individual functions and classes
**Integration Tests**: Test database operations
**API Tests**: Test endpoint responses

### Running Tests

```bash
cd backend
source ../.venv/bin/activate
pytest
```

**Configuration**: Tests use `pytest.ini` settings
- Pythonpath includes `billparser`
- Ignores route tests by default

---

## API Keys & External Services

### Required Services

1. **Congress.gov API** - `CONGRESS_API_KEY`
   - Sponsor data
   - Legislative actions
   - Vote records
   - Obtain at: https://api.congress.gov/sign-up/

2. **GovInfo Bulk Data** - No key required
   - Bill text archives
   - US Code releases
   - Public access

3. **Bioguide** - No key required
   - Legislator biographical data
   - Committee assignments

### Optional Services

1. **Discord Webhooks** - `DISCORD_WEBHOOK`
   - Import notifications
   - Error alerts

2. **LLM Providers** (via LiteLLM)
   - OpenAI
   - Anthropic
   - Google
   - Local models

---

## Performance Considerations

### Database Optimization

**Indexes**:
- Full-text search indexes on `legislator.fts`
- Foreign key indexes on all relationship tables
- Composite indexes on frequently queried columns

**Query Optimization**:
- Connection pooling disabled (`NullPool`) for parser processes
- Scoped sessions per request in APIs
- Lazy loading with explicit joins

### Caching

**Flask API**:
- Configurable cache headers via `CACHE_HEADER_TIME`
- Immutable responses for successful requests

**FastAPI**:
- In-memory rate limiting
- Database connection pooling

### Parallel Processing

**Import System**:
- `PARSE_THREADS` environment variable (default: 16)
- Parallel bill parsing from ZIP archives
- Process pool for XML transformation

---

## Common Operations

### Starting APIs

**Flask API**:
```bash
cd backend
source ../.venv/bin/activate
export db_host=localhost:5432 db_user=parser db_pass=parser db_table=us_code
python -m congress_api
```

**FastAPI**:
```bash
cd backend
source ../.venv/bin/activate
export db_host=localhost:5432 db_user=parser db_pass=parser db_table=us_code
uvicorn congress_fastapi.app:app --reload --port 9001
```

### Running Importers

**Full Import**:
```bash
cd congress-dev
./.dev/local/scripts/import.sh
```

**Individual Importer**:
```bash
cd backend
source ../.venv/bin/activate
export db_host=localhost:5432 db_user=parser db_pass=parser db_table=us_code
python -m billparser.importers.bills
```

### Database Operations

**Run Migrations**:
```bash
cd backend
export db_host=localhost:5432 db_user=parser db_pass=parser db_table=us_code
alembic upgrade heads
```

**Create Migration**:
```bash
alembic revision --autogenerate -m "description"
```

**Check Current Version**:
```bash
alembic current
```

---

## Troubleshooting

### Common Issues

**1. Module Import Errors**
- Ensure virtual environment is activated
- Verify Python 3.9.25 is in use
- Check `PYTHONPATH` includes backend directory

**2. Database Connection Errors**
- Verify PostgreSQL is running
- Check environment variables (lowercase: `db_host`, `db_user`, `db_pass`, `db_table`)
- Ensure database exists: `createdb us_code`

**3. Missing Dependencies**
- spaCy model: `python -m spacy download en_core_web_sm`
- PostgreSQL headers: Install `libpq-dev` (Linux) or `postgresql` (Mac)

**4. Migration Conflicts**
- Multiple heads: Use `alembic upgrade heads` (not `head`)
- Check `alembic_version` table for current revision
- Manual conflict resolution may be needed

**5. Import Failures**
- Check API key: `echo $CONGRESS_API_KEY`
- Verify database schema exists: Run migrations first
- Check disk space for bill archives (multi-GB)

### Debug Mode

**Flask API**:
```bash
export STAGE=dev
python -m congress_api
```

**FastAPI**:
```bash
uvicorn congress_fastapi.app:app --reload --log-level debug
```

---

## Architecture Decisions

### Why Two APIs?

**Flask (Connexion)**:
- OpenAPI-first design
- Specification drives implementation
- Mature ecosystem for traditional REST
- Used for public-facing API

**FastAPI**:
- Modern async/await support
- Better performance for concurrent requests
- Automatic Pydantic validation
- Native async database operations
- Used for internal tools and new features

Both share the same database and core parser logic.

### Database Design Choices

**PostgreSQL**:
- JSONB for flexible metadata
- Full-text search capabilities
- Strong referential integrity
- Battle-tested reliability

**SQLAlchemy**:
- Cross-database compatibility
- Pythonic ORM
- Alembic migration support
- Both sync and async modes

### Parser Architecture

**Separation of Concerns**:
- Importers: Download and orchestrate
- Parsers: Transform and validate
- Database handlers: Persist data
- Each importer is independent and idempotent

**Why XML**:
- Official government format
- Rich structural metadata
- XPath querying
- Industry standard for legal documents

---

## Future Enhancements

- **GraphQL API**: Unified query interface
- **Real-time Updates**: WebSocket support for live bill tracking
- **Enhanced Search**: Vector embeddings for semantic search
- **API Documentation**: Interactive OpenAPI documentation site
- **Performance Metrics**: Prometheus/Grafana integration
- **Audit Logging**: Complete change history tracking

---

## Related Documentation

- [Frontend Documentation](./frontend.md)
- [Database Schema](./schema.md)
- [API Reference](./api.md)
- [Setup Guide](../local/README.md)

---

**Last Updated**: December 19, 2025  
**Maintainer**: Congress.dev Team
