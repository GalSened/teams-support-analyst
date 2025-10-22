# Teams Support Analyst - Orchestrator Script (PowerShell)
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

# Configuration
$POLL_INTERVAL = 10  # seconds
$STATE_FILE = "./state/last_message_id.txt"
$LOG_FILE = "./logs/orchestrator.log"
$CHANNEL_NAME = if ($env:TEAMS_CHANNEL_NAME) { $env:TEAMS_CHANNEL_NAME } else { "General" }

# Initialize
Write-Host "=== Teams Support Analyst Orchestrator Starting ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path (Split-Path $STATE_FILE) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LOG_FILE) | Out-Null

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry }
    }

    Add-Content -Path $LOG_FILE -Value $logEntry
}

# Check dependencies
try {
    $null = Get-Command claude -ErrorAction Stop
    Write-Log "Claude CLI found" "SUCCESS"
} catch {
    Write-Log "claude CLI not found. Please install Claude Desktop." "ERROR"
    exit 1
}

# Function to get last processed message ID
function Get-LastMessageId {
    if (Test-Path $STATE_FILE) {
        return Get-Content $STATE_FILE
    }
    return ""
}

# Function to save last processed message ID
function Save-LastMessageId {
    param([string]$MessageId)
    Set-Content -Path $STATE_FILE -Value $MessageId
}

# Function to detect language
function Detect-Language {
    param([string]$Text)

    if ($Text -match '[\u0590-\u05FF]') {
        return "he"
    }
    return "en"
}

# Function to analyze message with Claude Code
function Invoke-Analysis {
    param([string]$MessageText, [string]$Language)

    $prompt = @"
You are a support analyst for our codebase.

User question ($Language): $MessageText

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

1. ``path/to/file.ts:120-135``
```
[code snippet]
```

## Fix Suggestion

[how to fix]
"@

    try {
        $response = $prompt | claude --no-stream 2>&1
        return $response
    } catch {
        Write-Log "Error invoking Claude: $_" "ERROR"
        return $null
    }
}

# Function to send response to Teams
function Send-ToTeams {
    param([string]$Channel, [string]$Message, [string]$ReplyToId)

    $prompt = "Using the Teams MCP tools, send this message to the '$Channel' channel"
    if ($ReplyToId) {
        $prompt += " as a reply to message ID '$ReplyToId'"
    }
    $prompt += ":`n`n$Message"

    try {
        $result = $prompt | claude --no-stream 2>&1
        return $result
    } catch {
        Write-Log "Error sending to Teams: $_" "ERROR"
        return $null
    }
}

# Main polling loop
Write-Log "Starting polling loop (interval: ${POLL_INTERVAL}s)"
Write-Log "Monitoring channel: $CHANNEL_NAME"

while ($true) {
    Write-Log "Checking for new messages..."

    $lastId = Get-LastMessageId

    # Get new messages from Teams via Claude
    $getMessagesPrompt = "Using the Teams MCP tools, get the latest 5 messages from the '$CHANNEL_NAME' channel. Return only the JSON array of messages."

    try {
        $messagesJson = $getMessagesPrompt | claude --no-stream 2>&1

        if ([string]::IsNullOrWhiteSpace($messagesJson) -or $messagesJson -eq "null" -or $messagesJson -eq "[]") {
            Write-Log "No new messages"
            Start-Sleep -Seconds $POLL_INTERVAL
            continue
        }

        # Parse messages (assuming JSON array)
        $messages = $messagesJson | ConvertFrom-Json

        foreach ($msg in $messages) {
            $msgId = $msg.id
            $msgText = $msg.text
            $msgFrom = $msg.from.name

            # Skip if already processed
            if ($msgId -eq $lastId) {
                continue
            }

            Write-Log "New message from $msgFrom: $($msgText.Substring(0, [Math]::Min(50, $msgText.Length)))..."

            # Detect language
            $lang = Detect-Language $msgText
            Write-Log "Detected language: $lang"

            # Analyze with Claude Code
            Write-Log "Analyzing with Claude Code..."
            $analysis = Invoke-Analysis $msgText $lang

            if ([string]::IsNullOrWhiteSpace($analysis)) {
                Write-Log "Failed to get analysis from Claude" "ERROR"
                continue
            }

            Write-Log "Analysis complete ($($analysis.Length) chars)" "SUCCESS"

            # Send response to Teams
            Write-Log "Sending response to Teams..."
            $sendResult = Send-ToTeams $CHANNEL_NAME $analysis $msgId

            if ($sendResult) {
                Write-Log "Response sent successfully" "SUCCESS"
            } else {
                Write-Log "Failed to send response" "ERROR"
            }

            # Save last processed message ID
            Save-LastMessageId $msgId

            Write-Log "---"
        }
    } catch {
        Write-Log "Error in polling loop: $_" "ERROR"
    }

    Start-Sleep -Seconds $POLL_INTERVAL
}
