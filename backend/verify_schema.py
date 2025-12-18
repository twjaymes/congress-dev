#!/usr/bin/env python3
"""
Database Schema Setup and Verification Script
Ensures the database has the correct schema before importing data.
"""

import os
import sys
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import OperationalError, ProgrammingError

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from billparser.db.models import Base, AppropriationsBase, PromptsBase


def get_database_url():
    """Construct database URL from environment variables"""
    username = os.environ.get("db_user", "parser")
    password = os.environ.get("db_pass", "parser")
    host = os.environ.get("db_host", "localhost")
    database = os.environ.get("db_table", "us_code_2025")
    
    return f"postgresql://{username}:{password}@{host}/{database}"


def test_connection(engine):
    """Test database connection"""
    print("Testing database connection...")
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            print(f"✓ Connected to PostgreSQL")
            print(f"  Version: {version.split(',')[0]}")
            return True
    except OperationalError as e:
        print(f"✗ Connection failed: {e}")
        return False


def check_schemas(engine):
    """Check if required schemas exist"""
    print("\nChecking schemas...")
    inspector = inspect(engine)
    schemas = inspector.get_schema_names()
    
    required_schemas = ['public', 'appropriations', 'prompts']
    missing_schemas = []
    
    for schema in required_schemas:
        if schema in schemas:
            print(f"  ✓ Schema '{schema}' exists")
        else:
            print(f"  ✗ Schema '{schema}' missing")
            missing_schemas.append(schema)
    
    # Create missing schemas
    if missing_schemas:
        print("\nCreating missing schemas...")
        with engine.begin() as conn:
            for schema in missing_schemas:
                try:
                    conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema}"))
                    print(f"  ✓ Created schema '{schema}'")
                except Exception as e:
                    print(f"  ✗ Failed to create schema '{schema}': {e}")
                    return False
    
    return True


def check_tables(engine):
    """Check if required tables exist"""
    print("\nChecking tables...")
    inspector = inspect(engine)
    
    # Check public schema tables
    public_tables = inspector.get_table_names(schema='public')
    required_public_tables = [
        'congress', 'legislation', 'legislation_version', 'legislation_content',
        'usc_section', 'usc_content', 'usc_release', 'version',
        'legislator', 'sponsor', 'committee', 'vote', 'legislator_vote'
    ]
    
    missing_tables = []
    for table in required_public_tables:
        if table in public_tables:
            print(f"  ✓ Table 'public.{table}' exists")
        else:
            print(f"  ✗ Table 'public.{table}' missing")
            missing_tables.append(table)
    
    # Check appropriations schema
    try:
        approp_tables = inspector.get_table_names(schema='appropriations')
        print(f"  ✓ Schema 'appropriations' has {len(approp_tables)} tables")
    except Exception:
        print(f"  ⚠ Schema 'appropriations' not accessible")
    
    # Check prompts schema
    try:
        prompt_tables = inspector.get_table_names(schema='prompts')
        print(f"  ✓ Schema 'prompts' has {len(prompt_tables)} tables")
    except Exception:
        print(f"  ⚠ Schema 'prompts' not accessible")
    
    return len(missing_tables) == 0, missing_tables


def create_tables(engine):
    """Create all tables using SQLAlchemy models"""
    print("\nCreating database tables...")
    try:
        # Create tables in order
        print("  Creating public schema tables...")
        Base.metadata.create_all(engine)
        
        print("  Creating appropriations schema tables...")
        AppropriationsBase.metadata.create_all(engine)
        
        print("  Creating prompts schema tables...")
        PromptsBase.metadata.create_all(engine)
        
        print("✓ All tables created successfully")
        return True
    except Exception as e:
        print(f"✗ Failed to create tables: {e}")
        return False


def verify_critical_tables(engine):
    """Verify critical tables have correct structure"""
    print("\nVerifying table structure...")
    inspector = inspect(engine)
    
    # Check congress table
    try:
        columns = [col['name'] for col in inspector.get_columns('congress', schema='public')]
        required_columns = ['congress_id', 'session_number', 'start_year', 'end_year']
        
        if all(col in columns for col in required_columns):
            print(f"  ✓ Table 'congress' has all required columns")
        else:
            missing = [col for col in required_columns if col not in columns]
            print(f"  ✗ Table 'congress' missing columns: {missing}")
            return False
    except Exception as e:
        print(f"  ✗ Could not verify 'congress' table: {e}")
        return False
    
    # Check legislation table
    try:
        columns = [col['name'] for col in inspector.get_columns('legislation', schema='public')]
        required_columns = ['legislation_id', 'number', 'title', 'chamber', 'congress_id']
        
        if all(col in columns for col in required_columns):
            print(f"  ✓ Table 'legislation' has all required columns")
        else:
            missing = [col for col in required_columns if col not in columns]
            print(f"  ✗ Table 'legislation' missing columns: {missing}")
            return False
    except Exception as e:
        print(f"  ✗ Could not verify 'legislation' table: {e}")
        return False
    
    return True


def get_database_stats(engine):
    """Get statistics about database contents"""
    print("\nDatabase Statistics:")
    inspector = inspect(engine)
    
    with engine.connect() as conn:
        # Count tables
        public_tables = inspector.get_table_names(schema='public')
        print(f"  Total tables in public schema: {len(public_tables)}")
        
        # Count records in key tables
        key_tables = ['congress', 'legislation', 'legislation_version', 'legislator']
        for table in key_tables:
            if table in public_tables:
                try:
                    result = conn.execute(text(f"SELECT COUNT(*) FROM public.{table}"))
                    count = result.fetchone()[0]
                    print(f"  Records in {table}: {count}")
                except Exception as e:
                    print(f"  Could not count {table}: {e}")


def main():
    """Main setup and verification function"""
    print("=" * 60)
    print("Congress.dev Database Schema Setup and Verification")
    print("=" * 60)
    print()
    
    # Get database URL
    db_url = get_database_url()
    print(f"Database: {db_url.replace(':' + os.environ.get('db_pass', 'parser'), ':***')}")
    print()
    
    # Create engine
    try:
        engine = create_engine(db_url, echo=False)
    except Exception as e:
        print(f"✗ Failed to create database engine: {e}")
        return 1
    
    # Test connection
    if not test_connection(engine):
        return 1
    
    # Check and create schemas
    if not check_schemas(engine):
        return 1
    
    # Check tables
    all_exist, missing_tables = check_tables(engine)
    
    # Create tables if needed
    if not all_exist:
        print(f"\n{len(missing_tables)} table(s) need to be created.")
        response = input("Create missing tables? (y/N): ")
        if response.lower() == 'y':
            if not create_tables(engine):
                return 1
        else:
            print("Skipping table creation. Run Alembic migrations instead:")
            print("  alembic upgrade head")
            return 1
    
    # Verify structure
    if not verify_critical_tables(engine):
        print("\n⚠ Some tables may have incorrect structure.")
        print("Consider running: alembic upgrade head")
        return 1
    
    # Get stats
    get_database_stats(engine)
    
    print()
    print("=" * 60)
    print("✓ Database schema verification complete!")
    print("=" * 60)
    print()
    print("Next steps:")
    print("  1. If tables are empty, run: ./setup_and_import.sh")
    print("  2. Or import data manually: python -m billparser.importers.bills")
    print("  3. Start the API: cd .. && ./start_local.sh")
    print()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
