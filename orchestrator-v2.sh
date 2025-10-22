#!/bin/bash
# Teams Support Analyst - Orchestrator Script v2 (Bash)
#
# This script:
# 1. Polls Microsoft Teams for new messages (via Teams MCP)
# 2. ONLY responds when bot is @mentioned
# 3. Uses stability loop for iterative refinement
# 4. Replies in same thread
# 5. Invokes Claude Code to analyze each message (using LocalSearch MCP)
# 6. Sends the response back to Teams (via Teams MCP)
#
# Requirements:
# - Claude Desktop with Teams MCP and LocalSearch MCP configured
# - LocalSearch API running on http://localhost:3001
# - claude CLI in PATH

# Configuration
POLL_INTERVAL=10  # seconds
STATE_FILE="./state/last_message_id.txt"
ANALYSIS_STATE_FILE="./state/analysis_state.json"
LOG_FILE="./logs/orchestrator.log"
CHANNEL_NAME="${TEAMS_CHANNEL_NAME:-General}"
BOT_NAME="${BOT_NAME:-SupportBot}"

# Analysis settings (Stability Loop)
MAX_ATTEMPTS=4
CONFIDENCE_THRESHOLD=0.9
STABLE_HASH_COUNT=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize
echo -e "${CYAN}=== Teams Support Analyst Orchestrator v2 Starting ===${NC}"
mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
echo -e "${YELLOW}Bot Name: $BOT_NAME${NC}"
echo -e "${YELLOW}Will only respond to @mentions${NC}"

# Logging function
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"

    case "$level" in
        ERROR)
            echo -e "${RED}${log_entry}${NC}"
            ;;
        SUCCESS)
            echo -e "${GREEN}${log_entry}${NC}"
            ;;
        WARN)
            echo -e "${YELLOW}${log_entry}${NC}"
            ;;
        *)
            echo "$log_entry"
            ;;
    esac

    echo "$log_entry" >> "$LOG_FILE"
}

# Check dependencies
if ! command -v claude &> /dev/null; then
    log_message "claude CLI not found. Please install Claude Desktop." "ERROR"
    exit 1
fi
log_message "Claude CLI found" "SUCCESS"

# Function to check if bot is mentioned
is_bot_mentioned() {
    local text="$1"

    # Check various mention patterns
    if echo "$text" | grep -qE "@${BOT_NAME}\b|@Support\s*Bot\b|@Support\s*Analyst\b|<at>.*${BOT_NAME}.*</at>|<at>.*Support.*</at>"; then
        return 0
    fi

    return 1
}

# Function to clean message text (remove @mention)
clean_message() {
    local text="$1"

    # Remove @mentions and XML tags
    text=$(echo "$text" | sed -E 's/@[a-zA-Z0-9_]+\s*//g')
    text=$(echo "$text" | sed -E 's/<at>.*?<\/at>\s*//g')

    # Trim whitespace
    text=$(echo "$text" | xargs)

    echo "$text"
}

# Function to compute SHA-256 hash
compute_hash() {
    local text="$1"

    # Convert to lowercase and compute hash
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | sha256sum | awk '{print $1}'
}

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
    local message_id="$1"
    echo "$message_id" > "$STATE_FILE"
}

# Function to detect language
detect_language() {
    local text="$1"

    # Check for Hebrew unicode characters
    if echo "$text" | grep -qP '[\u0590-\u05FF]'; then
        echo "he"
    else
        echo "en"
    fi
}

# Function to extract confidence from analysis text
extract_confidence() {
    local analysis="$1"

    # Try various patterns to extract confidence
    if echo "$analysis" | grep -qoP '\*\*Confidence:\*\*\s*([0-9.]+)'; then
        echo "$analysis" | grep -oP '\*\*Confidence:\*\*\s*\K([0-9.]+)' | head -1
    elif echo "$analysis" | grep -qoP 'Confidence:\s*([0-9.]+)'; then
        echo "$analysis" | grep -oP 'Confidence:\s*\K([0-9.]+)' | head -1
    elif echo "$analysis" | grep -qoP 'confidence[:\s]+([0-9.]+)'; then
        echo "$analysis" | grep -oP 'confidence[:\s]+\K([0-9.]+)' | head -1
    else
        echo "0.0"
    fi
}

# Function to extract hypothesis from analysis
extract_hypothesis() {
    local analysis="$1"

    # Try to extract hypothesis
    if echo "$analysis" | grep -qoP '\*\*Hypothesis:\*\*\s*(.+?)(?:\r?\n|$)'; then
        echo "$analysis" | grep -oP '\*\*Hypothesis:\*\*\s*\K(.+?)(?=\r?\n|$)' | head -1
    elif echo "$analysis" | grep -qoP 'Hypothesis:\s*(.+?)(?:\r?\n|$)'; then
        echo "$analysis" | grep -oP 'Hypothesis:\s*\K(.+?)(?=\r?\n|$)' | head -1
    else
        # Return first 100 chars as fallback
        echo "$analysis" | head -c 100
    fi
}

# Function to analyze message with Claude Code (with attempt info)
invoke_analysis() {
    local message_text="$1"
    local language="$2"
    local attempt="$3"
    local previous_hypothesis="${4:-}"
    local previous_evidence="${5:-}"

    local attempt_info
    if [ "$attempt" -eq 1 ]; then
        attempt_info="This is your first analysis attempt."
    else
        attempt_info="This is attempt $attempt of $MAX_ATTEMPTS.

Your previous hypothesis was: \"$previous_hypothesis\"

Instructions:
- Try to FALSIFY your previous hypothesis
- Look for alternative explanations
- Check edge cases and overlooked areas
- Only keep the same hypothesis if evidence strongly supports it
- Be critical and thorough"
    fi

    local prompt="You are a support analyst for our codebase.

User question ($language): $message_text

$attempt_info

Your task:
1. Use the 'search_code' tool to search our local repositories for relevant code
2. Use the 'read_file' tool to read specific files if needed
3. Analyze the issue and provide:
   - Root cause hypothesis
   - Confidence level (0-1, be honest about uncertainty)
   - Evidence (file paths + line numbers + code snippets)
   - Fix suggestion

IMPORTANT: Return your analysis in this EXACT format:

## Analysis

**Hypothesis:** [your hypothesis in $language]
**Confidence:** [0.0-1.0 as decimal number]

## Evidence

1. \`\`path/to/file.ts:120-135\`\`
\`\`\`
[code snippet]
\`\`\`

2. \`\`another/file.ts:45-60\`\`
\`\`\`
[code snippet]
\`\`\`

## Fix Suggestion

[how to fix in $language]"

    log_message "Invoking Claude Code (Attempt $attempt)..."

    # Invoke Claude CLI
    local response
    response=$(echo "$prompt" | claude --no-stream 2>&1)

    echo "$response"
}

# Function to send response to Teams (as thread reply)
send_to_teams() {
    local channel="$1"
    local message="$2"
    local reply_to_id="$3"

    local prompt="Using the Teams MCP tools, send this message as a REPLY to message ID '$reply_to_id' in the '$channel' channel:

$message"

    log_message "Sending reply to Teams (message ID: $reply_to_id)..."

    # Invoke Claude CLI
    local result
    result=$(echo "$prompt" | claude --no-stream 2>&1)

    echo "$result"
}

# Main polling loop
log_message "Starting polling loop (interval: ${POLL_INTERVAL}s)"
log_message "Monitoring channel: $CHANNEL_NAME"
log_message "Only responding to @$BOT_NAME mentions"

while true; do
    log_message "Checking for new messages..."

    last_id=$(get_last_message_id)

    # Get new messages from Teams via Claude
    get_messages_prompt="Using the Teams MCP tools, get the latest 5 messages from the '$CHANNEL_NAME' channel. Return only the JSON array of messages with id, text, and from fields."

    messages_json=$(echo "$get_messages_prompt" | claude --no-stream 2>&1)

    if [ -z "$messages_json" ] || [ "$messages_json" = "null" ] || [ "$messages_json" = "[]" ]; then
        log_message "No new messages"
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Parse messages with jq (if available) or process line by line
    if command -v jq &> /dev/null; then
        # Process with jq
        echo "$messages_json" | jq -c '.[]' | while IFS= read -r msg; do
            msg_id=$(echo "$msg" | jq -r '.id')
            msg_text=$(echo "$msg" | jq -r '.text')
            msg_from=$(echo "$msg" | jq -r '.from.name')

            # Skip if already processed
            if [ "$msg_id" = "$last_id" ]; then
                continue
            fi

            # Truncate message for logging
            msg_preview="${msg_text:0:50}"
            log_message "New message from $msg_from: $msg_preview..."

            # Check if bot is mentioned
            if ! is_bot_mentioned "$msg_text"; then
                log_message "Bot not mentioned, skipping..." "WARN"
                save_last_message_id "$msg_id"
                continue
            fi

            log_message "Bot mentioned! Processing..." "SUCCESS"

            # Clean message (remove @mention)
            clean_msg=$(clean_message "$msg_text")
            clean_preview="${clean_msg:0:50}"
            log_message "Clean message: $clean_preview..."

            # Detect language
            lang=$(detect_language "$clean_msg")
            log_message "Detected language: $lang"

            # Initialize analysis state for stability loop
            attempt=1
            stable_count=0
            last_hypothesis_hash=""
            last_hypothesis=""
            final_analysis=""
            final_confidence=0.0

            # Stability Loop
            while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
                log_message "=== Analysis Attempt $attempt/$MAX_ATTEMPTS ===" "INFO"

                # Analyze with Claude Code
                analysis=$(invoke_analysis "$clean_msg" "$lang" "$attempt" "$last_hypothesis")

                if [ -z "$analysis" ]; then
                    log_message "Failed to get analysis from Claude" "ERROR"
                    break
                fi

                log_message "Analysis received (${#analysis} chars)"

                # Extract hypothesis and confidence
                current_hypothesis=$(extract_hypothesis "$analysis")
                current_confidence=$(extract_confidence "$analysis")

                hyp_preview="${current_hypothesis:0:60}"
                log_message "Hypothesis: $hyp_preview..."
                log_message "Confidence: $current_confidence"

                # Compute hash of hypothesis
                current_hash=$(compute_hash "$current_hypothesis")

                # Check stability
                if [ -n "$last_hypothesis_hash" ] && [ "$current_hash" = "$last_hypothesis_hash" ]; then
                    stable_count=$((stable_count + 1))
                    log_message "Hypothesis stable (count: $stable_count)" "SUCCESS"
                else
                    stable_count=1
                    log_message "Hypothesis changed, resetting stability count"
                fi

                # Update state
                last_hypothesis_hash="$current_hash"
                last_hypothesis="$current_hypothesis"
                final_analysis="$analysis"
                final_confidence="$current_confidence"

                # Check exit conditions
                done=0
                reason=""

                if [ "$stable_count" -ge "$STABLE_HASH_COUNT" ]; then
                    done=1
                    reason="Hypothesis stable ($stable_count consecutive)"
                elif [ "$(echo "$current_confidence >= $CONFIDENCE_THRESHOLD" | bc -l)" -eq 1 ]; then
                    done=1
                    reason="High confidence ($current_confidence >= $CONFIDENCE_THRESHOLD)"
                elif [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
                    done=1
                    reason="Max attempts reached ($MAX_ATTEMPTS)"
                fi

                if [ "$done" -eq 1 ]; then
                    log_message "Analysis complete! Reason: $reason" "SUCCESS"
                    break
                fi

                log_message "Continuing to next attempt..."
                attempt=$((attempt + 1))
            done

            # Send response to Teams (as thread reply)
            log_message "Sending response to Teams..."
            send_result=$(send_to_teams "$CHANNEL_NAME" "$final_analysis" "$msg_id")

            if [ -n "$send_result" ]; then
                log_message "Response sent successfully (Confidence: $final_confidence, Attempts: $attempt)" "SUCCESS"
            else
                log_message "Failed to send response" "ERROR"
            fi

            # Save last processed message ID
            save_last_message_id "$msg_id"

            log_message "==================================="
        done
    else
        log_message "jq not found - skipping JSON parsing (install jq for proper parsing)" "WARN"
    fi

    sleep "$POLL_INTERVAL"
done
