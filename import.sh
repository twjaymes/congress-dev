#!/bin/bash
set -e
set -o pipefail

############################################################
# Environment Setup
############################################################

PROJECT_ROOT_DIR=~/projects/congress-dev/congress-dev
DOCKER_DIR=${PROJECT_ROOT_DIR}/.docker
DOCKER_COMPOSE_FILE_NAME=docker-compose.dev.yml
DOCKER_PROJECT_NAME="congress-dev"
CONGRESS_API_KEY=By7KBbvlbNsDfoBPLxVAaZj3hvm7aQOnwLOhxvOo
DATABASE_NAME="us_code"
DATABASE_PASS="parser"
DATABASE_USER="parser"
# host.docker.internal: Used inside Docker containers to reach host machine services (macOS/Windows)
# localhost: Used on host machine to connect to services directly
DATABASE_HOST="host.docker.internal"
DATABASE_PORT="5432"
TABLE_NAME="us_code"
PARSE_THREADS=16
DISCORD_WEBHOOK=https://discord.com/api/webhooks/817897502442913822/M-6FpliQvtba68dSnL6AqviGkRgSZb5Jan0Hte841WrIxmJiWFWoEN5caWSxahf0Ydha

cd ${PROJECT_ROOT_DIR}/backend
pwd
# if bills/ directory is empty, remove contents, else continue
if [ -d "bills" ] && [ "$(ls -A bills)" ]; then
    echo "Bills directory exists and is not empty. Continuing with import."
else
    echo "Bills directory is empty or does not exist. Creating bills directory."
    mkdir -p bills
fi

cd ${PROJECT_ROOT_DIR}

# Clean Python bytecode cache to ensure updated code is used
echo "Cleaning Python bytecode cache..."
find ${PROJECT_ROOT_DIR}/backend -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find ${PROJECT_ROOT_DIR}/backend -type f -name "*.pyc" -delete 2>/dev/null || true

echo "Building congress_parser_api image..."
docker compose -p ${DOCKER_PROJECT_NAME} -f ${DOCKER_DIR}/${DOCKER_COMPOSE_FILE_NAME} build congress_parser_api

echo ""
echo "Starting import process..."
echo ""

# Helper function to run importers
run_importer() {
    local importer_name=$1
    local extra_args=$2
    
    echo "==> Running ${importer_name} importer..."
    docker compose -p ${DOCKER_PROJECT_NAME} -f ${DOCKER_DIR}/${DOCKER_COMPOSE_FILE_NAME} run --rm \
        -e db_host=${DATABASE_HOST} \
        -e db_user=${DATABASE_USER} \
        -e db_pass=${DATABASE_PASS} \
        -e db_table=${TABLE_NAME} \
        -e CONGRESS_API_KEY=${CONGRESS_API_KEY} \
        -e PARSE_THREADS=${PARSE_THREADS} \
        -e DISCORD_WEBHOOK=${DISCORD_WEBHOOK} \
        congress_parser_api -m billparser.importers.${importer_name} ${extra_args}
    echo ""
}

# Function to run specific importer based on name
run_specific_importer() {
    case "$1" in
        bills)
            run_importer "bills"
            ;;
        prompts)
            run_importer "prompts"
            ;;
        bioguide)
            run_importer "bioguide"
            ;;
        sponsors)
            run_importer "sponsors"
            ;;
        releases)
            run_importer "releases" '--release-point="https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip"'
            ;;
        actions)
            run_importer "actions"
            ;;
        votes)
            run_importer "votes"
            ;;
        statuses)
            run_importer "statuses"
            ;;
        cleanup)
            run_importer "cleanup"
            ;;
        *)
            echo "Unknown importer: $1"
            echo "Available importers: bills, prompts, bioguide, sponsors, releases, actions, votes, statuses, cleanup"
            exit 1
            ;;
    esac
}

# Check if specific importers were requested
if [ $# -gt 0 ]; then
    echo "Running specific importers: $@"
    echo ""
    for importer in "$@"; do
        run_specific_importer "$importer"
    done
else
    echo "Running all importers in sequence..."
    echo ""
    
    # Import bills first
    run_importer "bills"

    # Run prompts
    run_importer "prompts"

    # Import bioguide
    run_importer "bioguide"

    # Grab sponsors
    run_importer "sponsors"

    # Import US Code releases
    run_importer "releases" '--release-point="https://uscode.house.gov/download/releasepoints/us/pl/118/209not159/xml_uscAll@118-209not159.zip"'

    # Run action importer
    run_importer "actions"

    # Import votes
    run_importer "votes"

    # Import statuses
    run_importer "statuses"

    # Run cleanup
    run_importer "cleanup"
fi

echo ""
echo "=========================================="
echo "Import process complete!"
echo "=========================================="

