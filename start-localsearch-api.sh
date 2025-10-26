#!/bin/bash
# Start LocalSearch API with environment variables
# This script loads the .env file and starts the LocalSearch API

echo "=== Starting LocalSearch API ==="

# Load .env file
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment from .env..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
    echo "Environment loaded!"
else
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Verify required variables
if [ -z "$REPO_ROOTS" ]; then
    echo "ERROR: REPO_ROOTS not set in .env"
    exit 1
fi

# Start the API
echo ""
echo "Starting LocalSearch API on port ${LOCALSEARCH_PORT:-3001}..."
echo "Monitoring repositories:"
echo "$REPO_ROOTS" | tr ':' '\n' | sed 's/^/  - /'
echo ""

cd "$(dirname "$0")/local-search-api"
npm start
