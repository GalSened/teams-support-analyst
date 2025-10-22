#!/bin/bash

###############################################################################
# Teams Support Analyst - Orchestrator Script
#
# This script:
# 1. Polls Microsoft Teams for new messages (via Teams MCP)
# 2. Invokes Claude Code to analyze each message (using LocalSearch MCP)
# 3. Sends the response back to Teams (via Teams MCP)
#
# Requirements:
# - Claude Desktop with Teams MCP and LocalSearch MCP configured
# - LocalSearch API running on http://localhost:3001
# - claude CLI in PATH
###############################################################################

# Configuration
POLL_INTERVAL=10  # seconds between checks
STATE_FILE="./state/last_message_id.txt"
LOG_FILE="./logs/orchestrator.log"
CHANNEL_NAME="${TEAMS_CHANNEL_NAME:-General}"  # Default channel to monitor

# Colors for output
RED='\033[0.31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Success logging
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Warning logging
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize
log "=== Teams Support Analyst Orchestrator Starting ==="
mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"

# Check dependencies
if ! command -v claude &> /dev/null; then
    error "claude CLI not found. Please install Claude Desktop."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    error "jq not found. Please install jq for JSON parsing."
    exit 1
fi

log "Dependencies OK"

# Function to get last processed message ID
get_last_message_id() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

# Function to save last processed message ID
save_last_message_id() {
    echo "$1" > "$STATE_FILE"
}

# Function to detect language (Hebrew or English)
detect_language() {
    local text="$1"
    if echo "$text" | grep -q '[א-ת]'; then
        echo "he"
    else
        echo "en"
    fi
}

# Function to get new messages from Teams
get_new_messages() {
    local channel="$1"
    local last_id="$2"

    # Use Claude MCP to get messages
    local prompt="Using the Teams MCP tools, get the latest 5 messages from the '$channel' channel. Return only the JSON array of messages."

    local response=$(echo "$prompt" | claude --no-stream 2>/dev/null)

    echo "$response"
}

# Function to analyze message with Claude Code
analyze_message() {
    local message_text="$1"
    local language="$2"

    local prompt="You are a support analyst for our codebase.

User question ($language): $message_text

Your task:
1. Use the 'search_code' tool to search our local repositories for relevant code
2. Use the 'read_file' tool to read specific files if needed
3. Analyze the issue and provide:
   - Root cause hypothesis
   - Confidence level (0-1)
   - Evidence (file paths + line numbers + code snippets)
   - Fix suggestion

Return your analysis in this format:
## Analysis

**Hypothesis:** [your hypothesis]
**Confidence:** [0-1]

## Evidence

1. \`path/to/file.ts:120-135\`
\`\`\`
[code snippet]
\`\`\`

## Fix Suggestion

[how to fix]
"

    local response=$(echo "$prompt" | claude --no-stream 2>/dev/null)

    echo "$response"
}

# Function to send response to Teams
send_to_teams() {
    local channel="$1"
    local message="$2"
    local reply_to_id="$3"

    local prompt="Using the Teams MCP tools, send this message to the '$channel' channel"
    if [ -n "$reply_to_id" ]; then
        prompt="$prompt as a reply to message ID '$reply_to_id'"
    fi
    prompt="$prompt:

$message"

    echo "$prompt" | claude --no-stream 2>/dev/null
}

# Main polling loop
log "Starting polling loop (interval: ${POLL_INTERVAL}s)"
log "Monitoring channel: $CHANNEL_NAME"

while true; do
    log "Checking for new messages..."

    # Get last processed message ID
    LAST_ID=$(get_last_message_id)

    # Get new messages from Teams
    MESSAGES=$(get_new_messages "$CHANNEL_NAME" "$LAST_ID")

    # Check if there are new messages
    if [ -z "$MESSAGES" ] || [ "$MESSAGES" == "null" ] || [ "$MESSAGES" == "[]" ]; then
        log "No new messages"
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Process each message
    echo "$MESSAGES" | jq -c '.[]' 2>/dev/null | while read -r msg; do
        # Extract message details
        MSG_ID=$(echo "$msg" | jq -r '.id')
        MSG_TEXT=$(echo "$msg" | jq -r '.text')
        MSG_FROM=$(echo "$msg" | jq -r '.from.name')

        # Skip if already processed
        if [ "$MSG_ID" == "$LAST_ID" ]; then
            continue
        fi

        log "New message from $MSG_FROM: ${MSG_TEXT:0:50}..."

        # Detect language
        LANG=$(detect_language "$MSG_TEXT")
        log "Detected language: $LANG"

        # Analyze with Claude Code
        log "Analyzing with Claude Code..."
        ANALYSIS=$(analyze_message "$MSG_TEXT" "$LANG")

        if [ -z "$ANALYSIS" ]; then
            error "Failed to get analysis from Claude"
            continue
        fi

        success "Analysis complete (${#ANALYSIS} chars)"

        # Send response to Teams
        log "Sending response to Teams..."
        SEND_RESULT=$(send_to_teams "$CHANNEL_NAME" "$ANALYSIS" "$MSG_ID")

        if [ $? -eq 0 ]; then
            success "Response sent successfully"
        else
            error "Failed to send response: $SEND_RESULT"
        fi

        # Save last processed message ID
        save_last_message_id "$MSG_ID"

        log "---"
    done

    # Wait before next poll
    sleep "$POLL_INTERVAL"
done
