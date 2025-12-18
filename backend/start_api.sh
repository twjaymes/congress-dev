#!/bin/bash
# Start FastAPI server with correct environment variables

cd "$(dirname "$0")"

# Set database connection environment variables
export db_host=localhost
export db_user=parser
export db_pass=parser
export db_table=us_code_2025

echo "Starting FastAPI server with database connection:"
echo "  Host: $db_host"
echo "  User: $db_user"
echo "  Database: $db_table"
echo ""
echo "Server will be available at: http://127.0.0.1:9091"
echo "Press CTRL+C to stop"
echo ""

# Start uvicorn with reload
uvicorn congress_fastapi.app:app --host 0.0.0.0 --port 9091 --reload
