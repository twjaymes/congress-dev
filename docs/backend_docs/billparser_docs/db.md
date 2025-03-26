# Billparser.DB

## handler.py

This script processes and imports U.S. Code (USC) legal documents into a PostgreSQL database. Key functionalities include:

1.	Database Connection:

- Uses SQLAlchemy to establish a connection to a PostgreSQL database.
- Database credentials are sourced from environment variables.
- The NullPool option ensures no connection pooling.

2.	Session Management:

- Implements scoped_session for database transactions.
- Provides functions (init_session, get_scoped_session) to initialize database sessions.

3.	USC XML Parsing:

- Uses lxml to parse USC XML documents and extract elements with an identifier attribute.
- Constructs a lookup table of identifiers.

4.	Data Import & Processing:

- import_title(): Parses XML USC files, extracts sections, and recursively processes content.
- Utilizes resolve_citations() to clean up and link legal citations.
- Converts identifiers into sortable numeric values with get_number().

5.	Data Storage:

- Inserts parsed USC sections and content into database tables (USCChapter, USCContent).
- Handles document versioning and ensures duplicate chapters are not re-imported.

Dependencies:
- External Libraries: lxml, SQLAlchemy, unidecode
- Custom Modules: billparser.utils.citation, billparser.db.models

Purpose: Automates the extraction, transformation, and loading (ETL) of U.S. Code legal text into a structured PostgreSQL database.

## models.py



This file defines an SQLAlchemy ORM schema for storing and managing legislative data, including bills, actions, tags, summaries, and U.S. Code (USC) releases, chapters, and sections. The schema includes multiple models representing different entities, each mapped to a database table. Key components include:

1.	Legislation Content & Actions

- LegislationContent: Stores individual sections of a legislative bill.
- LegislationActionParse: Represents parsed actions associated with a bill.
- LegislationAction: Stores bill status actions, including dates, types, and sources.

2.	Tags & Summaries

- LegislationContentTag & LegislationVersionTag: Store tags applied to legislation for categorization.
- LegislationContentSummary: Stores text summaries of legislative content.

3.	U.S. Code (USC) Structure

- USCRelease: Represents different release versions of the U.S. Code.
- USCChapter: Represents a chapter within a U.S. Code release.
- USCSection: Stores sections within a chapter, including references to parent sections.

4.	General Features

- to_dict() methods are included for serialization.
- Relationships are managed using foreign keys, with ondelete="CASCADE" for proper cleanup.
- Uses PostgreSQL-specific types like JSONB and ARRAY.



## queries.py

This file is a Flask SQLAlchemy data access module that provides cached queries for retrieving legal documents, specifically U.S. Code chapters, sections, and legislative bills. Here’s a summary of its key components:

### Dependencies

- Flask-SQLAlchemy-Session: Manages database sessions.
- SQLAlchemy: ORM for querying the database.
- cachetools.TTLCache: Implements an in-memory cache to speed up repeated queries.
- re: Used for sanitizing and formatting search queries.
- platform: Detects the OS (Windows-specific caching behavior).

### Constants & Configuration

- DEFAULT_VERSION_ID = 1: Default version ID for retrieving legal documents.
- CACHE_TIME = 600: Cache duration (disabled on Windows for development).

### Cached Query Functions

Each function retrieves specific data from the database while leveraging caching to improve performance.

#### U.S. Code Queries
- get_chapters(version_id): Retrieves all chapters for the latest U.S. Code version.
- get_latest_sections(chapter_number): Gets sections for a given chapter from the latest revision.
- get_sections(chapter_id, version_id): Fetches sections based on chapter and version ID.
- get_latest_content(chapter_number, section_number): Retrieves the latest legal text for a given chapter and section.
- get_content(section_id, version_id): Gets section content.

#### Legislation Queries
- get_bills(house, senate, query, incl, decl): Searches for bills based on chamber (House/Senate), title, and version filters.
- get_versions(): Retrieves all bill versions.
- get_revisions(): Retrieves all U.S. Code revisions.


### Functionality & Optimizations

- Uses SQLAlchemy ORM queries with filters and joins.
- Implements caching via @cached(cache=TTLCache(...)) to avoid redundant database queries.
- Allows filtering by chamber, bill title, version, and inclusion/exclusion criteria.
- Uses case-insensitive search (ilike()) for query matching.
- Handles Windows-specific caching behavior.

