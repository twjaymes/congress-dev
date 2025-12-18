#!/usr/bin/env python3
"""
Quick database status check
Shows what's currently in your database
"""
import os
import sys
from sqlalchemy import create_engine, text

def get_db_url():
    user = os.environ.get("db_user", "parser")
    password = os.environ.get("db_pass", "parser")
    host = os.environ.get("db_host", "host.docker.internal")
    db = os.environ.get("db_table", "us_code_2025")
    return f"postgresql://{user}:{password}@{host}/{db}"

def main():
    print("=" * 60)
    print("Congress.dev Database Status")
    print("=" * 60)
    print()
    
    engine = create_engine(get_db_url(), echo=False)
    
    try:
        with engine.connect() as conn:
            # Database info
            result = conn.execute(text("SELECT current_database(), current_user"))
            db_name, db_user = result.fetchone()
            print(f"Database: {db_name}")
            print(f"User: {db_user}")
            print()
            
            # Congress sessions
            print("Congressional Sessions:")
            result = conn.execute(text("""
                SELECT session_number, start_year, end_year 
                FROM congress 
                ORDER BY session_number DESC
            """))
            for row in result:
                print(f"  {row[0]}th Congress ({row[1]}-{row[2]})")
            print()
            
            # Bills by Congress and Chamber
            print("Bills by Congress:")
            result = conn.execute(text("""
                SELECT 
                    c.session_number,
                    l.chamber,
                    COUNT(DISTINCT l.legislation_id) as bill_count,
                    COUNT(DISTINCT lv.legislation_version_id) as version_count
                FROM legislation l
                JOIN congress c ON l.congress_id = c.congress_id
                LEFT JOIN legislation_version lv ON l.legislation_id = lv.legislation_id
                GROUP BY c.session_number, l.chamber
                ORDER BY c.session_number DESC, l.chamber
            """))
            for row in result:
                print(f"  {row[0]}th {row[1]:8s} {row[2]:5d} bills, {row[3]:5d} versions")
            print()
            
            # Recent bills
            print("Recent Bills:")
            result = conn.execute(text("""
                SELECT 
                    c.session_number,
                    l.chamber,
                    l.number,
                    LEFT(l.title, 60) as title
                FROM legislation l
                JOIN congress c ON l.congress_id = c.congress_id
                ORDER BY c.session_number DESC, l.legislation_id DESC
                LIMIT 5
            """))
            for row in result:
                print(f"  {row[0]}-{row[1]}-{row[2]:4d} {row[3]}...")
            print()
            
            # Table sizes
            print("Table Record Counts:")
            tables = [
                'congress', 'legislation', 'legislation_version', 
                'legislation_content', 'usc_section', 'usc_content'
            ]
            for table in tables:
                try:
                    result = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
                    count = result.fetchone()[0]
                    print(f"  {table:25s} {count:10,d} records")
                except Exception as e:
                    print(f"  {table:25s} (not accessible)")
            
    except Exception as e:
        print(f"Error: {e}")
        print()
        print("Make sure:")
        print("  1. PostgreSQL is running")
        print("  2. Environment variables are set (db_host, db_user, db_pass, db_table)")
        print("  3. Database schema is created (run: python verify_schema.py)")
        return 1
    
    print()
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())
