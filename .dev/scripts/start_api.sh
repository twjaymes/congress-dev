#!/bin/bash
# Start FastAPI server with correct environment variables

# Navigate to backend directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../../../backend" && pwd)"
ROOT_DIR="$(cd "$BACKEND_DIR/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
cd "$BACKEND_DIR"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"

# Set database connection environment variables
export db_host=localhost
export db_user=parser
export db_pass=parser
export db_table=us_code_2025

echo "Starting FastAPI server with database connection:"
echo "  Host: $db_host"
echo "  User: $db_user"
echo "  Database: $db_table"
echo "  Logs: $LOG_DIR/api.log"
echo ""
echo "Server will be available at: http://127.0.0.1:9091"
echo "Press CTRL+C to stop"
echo ""

# Start uvicorn with reload and log to file
uvicorn congress_fastapi.app:app --host 0.0.0.0 --port 9091 --reload --log-config <(cat <<EOF
version: 1
disable_existing_loggers: false
formatters:
  default:
    format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: default
    stream: ext://sys.stdout
  file:
    class: logging.FileHandler
    formatter: default
    filename: $LOG_DIR/api.log
    mode: a
loggers:
  uvicorn:
    level: INFO
    handlers:
      - console
      - file
  uvicorn.error:
    level: INFO
  uvicorn.access:
    level: INFO
    handlers:
      - console
      - file
EOF
) 2>&1 | tee -a "$LOG_DIR/api.log"
