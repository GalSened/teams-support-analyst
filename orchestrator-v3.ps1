# Teams Support Analyst - Orchestrator Script v3 (PowerShell)
#
# This script:
# 1. Polls Microsoft Teams for new messages (via Teams MCP)
# 2. ONLY responds when bot is @mentioned
# 3. Uses stability loop for iterative refinement
# 4. Replies in same thread
# 5. **NEW: Intelligent repo selection for faster, more accurate analysis**
# 6. Invokes Claude Code to analyze each message (using LocalSearch MCP)
# 7. Sends the response back to Teams (via Teams MCP)
#
# Requirements:
# - Claude Desktop with Teams MCP and LocalSearch MCP configured
# - LocalSearch API running on http://localhost:3001
# - claude CLI in PATH

# Configuration
$POLL_INTERVAL = 10  # seconds
$STATE_FILE = "./state/last_message_id.txt"
$ANALYSIS_STATE_FILE = "./state/analysis_state.json"
$LOG_FILE = "./logs/orchestrator.log"
$CHANNEL_NAME = if ($env:TEAMS_CHANNEL_NAME) { $env:TEAMS_CHANNEL_NAME } else { "General" }
$BOT_NAME = if ($env:BOT_NAME) { $env:BOT_NAME } else { "SupportBot" }

# Analysis settings (Stability Loop)
$MAX_ATTEMPTS = 4
$CONFIDENCE_THRESHOLD = 0.9
$STABLE_HASH_COUNT = 2

# Initialize
Write-Host "=== Teams Support Analyst Orchestrator v3 Starting ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path (Split-Path $STATE_FILE) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LOG_FILE) | Out-Null
Write-Host "Bot Name: $BOT_NAME" -ForegroundColor Yellow
Write-Host "Will only respond to @mentions" -ForegroundColor Yellow
Write-Host "ENHANCED: Intelligent repo selection enabled" -ForegroundColor Green

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

# Function to check if bot is mentioned
function Test-BotMentioned {
    param([string]$Text)

    $mentionPatterns = @(
        "@$BOT_NAME\b",
        "@Support\s*Bot\b",
        "@Support\s*Analyst\b",
        "<at>.*?$BOT_NAME.*?</at>",
        "<at>.*?Support.*?</at>"
    )

    foreach ($pattern in $mentionPatterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
}

# Function to clean message text (remove @mention)
function Get-CleanMessage {
    param([string]$Text)

    # Remove @mentions
    $cleaned = $Text -replace '@\w+\s*', ''
    $cleaned = $cleaned -replace '<at>.*?</at>\s*', ''

    # Trim whitespace
    $cleaned = $cleaned.Trim()

    return $cleaned
}

# Function to compute SHA-256 hash
function Get-StringHash {
    param([string]$Text)

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text.Trim().ToLower())
    $hashBytes = $hasher.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hashBytes) -replace '-', ''
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

# Function to extract confidence from analysis text
function Get-ConfidenceFromAnalysis {
    param([string]$AnalysisText)

    # Try to extract confidence value
    if ($AnalysisText -match '\*\*Confidence:\*\*\s*([0-9.]+)') {
        return [double]$matches[1]
    }
    elseif ($AnalysisText -match 'Confidence:\s*([0-9.]+)') {
        return [double]$matches[1]
    }
    elseif ($AnalysisText -match 'confidence[:\s]+([0-9.]+)') {
        return [double]$matches[1]
    }

    # Default to 0 if not found
    return 0.0
}

# Function to extract hypothesis from analysis
function Get-HypothesisFromAnalysis {
    param([string]$AnalysisText)

    # Try to extract hypothesis
    if ($AnalysisText -match '\*\*Hypothesis:\*\*\s*(.+?)(?:\r?\n|$)') {
        return $matches[1].Trim()
    }
    elseif ($AnalysisText -match 'Hypothesis:\s*(.+?)(?:\r?\n|$)') {
        return $matches[1].Trim()
    }

    # Return first 100 chars as fallback
    return $AnalysisText.Substring(0, [Math]::Min(100, $AnalysisText.Length))
}

# Function to analyze message with Claude Code (v3: ENHANCED with intelligent repo selection)
function Invoke-Analysis {
    param(
        [string]$MessageText,
        [string]$Language,
        [int]$Attempt,
        [string]$PreviousHypothesis = "",
        [string]$PreviousEvidence = ""
    )

    $attemptInfo = if ($Attempt -eq 1) {
        "This is your first analysis attempt."
    } else {
        @"
This is attempt $Attempt of $MAX_ATTEMPTS.

Your previous hypothesis was: "$PreviousHypothesis"

Instructions:
- Try to FALSIFY your previous hypothesis
- Look for alternative explanations
- Check edge cases and overlooked areas
- Only keep the same hypothesis if evidence strongly supports it
- Be critical and thorough
"@
    }

    $prompt = @"
You are a support analyst for our WeSign codebase.

User question ($Language): $MessageText

$attemptInfo

Available Repositories:
- **user-backend** (C:/Users/gals/source/repos/user-backend): Backend API, authentication, database, server logic, getUserInfo, login endpoints
- **wesign-client-DEV** (C:/Users/gals/Desktop/wesign-client-DEV): Frontend UI, React components, forms, pages, buttons, display logic
- **wesignsigner-client-app-DEV** (C:/Users/gals/Desktop/wesignsigner-client-app-DEV): Document signing features, signatures, PDF handling, upload

Your task:

**STEP 1: Intelligent Repository Selection**
Analyze the question keywords to determine the MOST RELEVANT repository:

Backend keywords (user-backend):
- API, endpoint, server, backend, database
- login, authentication, authorization, getUserInfo, session
- "returns null", "API fails", "server error", "database query"

Frontend UI keywords (wesign-client-DEV):
- UI, button, form, page, display, render, component
- "button doesn't work", "form error", "page not loading"

Signing keywords (wesignsigner-client-app-DEV):
- sign, signature, document, PDF, upload, download
- "signature fails", "document upload", "PDF error"

**STEP 2: Smart Search Strategy**
- Search the MOST RELEVANT repo FIRST (not all repos at once)
- This gives you faster, more focused results
- Only search additional repos if needed (e.g., integration issues)

**STEP 3: Ask if Unclear**
If you cannot determine which repo from keywords alone, respond:
"To provide accurate analysis, I need clarification:
 - Is this a **UI/frontend** issue? (buttons, forms, display)
 - Is this a **backend/API** issue? (server, authentication, data)
 - Is this **document signing** specific? (signatures, PDF handling)

Please specify so I can search the right repository."

**STEP 4: Comprehensive Analysis**
Once you've searched the right repo(s), provide:
- Root cause hypothesis
- Confidence level (0-1, be honest about uncertainty)
- Evidence (file paths + line numbers + code snippets from the repo you searched)
- Fix suggestion

IMPORTANT: Return your analysis in this EXACT format:

## Repository Search Strategy
**Selected Repos:** [which repos you decided to search and why, e.g., "user-backend (keywords: API, getUserInfo)"]

## Analysis

**Hypothesis:** [your hypothesis in $Language]
**Confidence:** [0.0-1.0 as decimal number]

## Evidence

1. ``path/to/file.ts:120-135``
```
[code snippet from selected repo]
```

2. ``another/file.ts:45-60``
```
[code snippet]
```

## Fix Suggestion

[how to fix in $Language]
"@

    try {
        Write-Log "Invoking Claude Code v3 (Attempt $Attempt) with intelligent repo selection..."
        $response = $prompt | claude --no-stream 2>&1
        return $response
    } catch {
        Write-Log "Error invoking Claude: $_" "ERROR"
        return $null
    }
}

# Function to send response to Teams (as thread reply)
function Send-ToTeams {
    param([string]$Channel, [string]$Message, [string]$ReplyToId)

    $prompt = "Using the Teams MCP tools, send this message as a REPLY to message ID '$ReplyToId' in the '$Channel' channel:`n`n$Message"

    try {
        Write-Log "Sending reply to Teams (message ID: $ReplyToId)..."
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
Write-Log "Only responding to @$BOT_NAME mentions"

while ($true) {
    Write-Log "Checking for new messages..."

    $lastId = Get-LastMessageId

    # Get new messages from Teams via Claude
    $getMessagesPrompt = "Using the Teams MCP tools, get the latest 5 messages from the '$CHANNEL_NAME' channel. Return only the JSON array of messages with id, text, and from fields."

    try {
        $messagesJson = $getMessagesPrompt | claude --no-stream 2>&1

        if ([string]::IsNullOrWhiteSpace($messagesJson) -or $messagesJson -eq "null" -or $messagesJson -eq "[]") {
            Write-Log "No new messages"
            Start-Sleep -Seconds $POLL_INTERVAL
            continue
        }

        # Parse messages (assuming JSON array)
        try {
            $messages = $messagesJson | ConvertFrom-Json
        } catch {
            Write-Log "Failed to parse messages JSON: $_" "ERROR"
            Start-Sleep -Seconds $POLL_INTERVAL
            continue
        }

        foreach ($msg in $messages) {
            $msgId = $msg.id
            $msgText = $msg.text
            $msgFrom = $msg.from.name

            # Skip if already processed
            if ($msgId -eq $lastId) {
                continue
            }

            Write-Log "New message from $msgFrom: $($msgText.Substring(0, [Math]::Min(50, $msgText.Length)))..."

            # Check if bot is mentioned
            $isMentioned = Test-BotMentioned $msgText

            if (-not $isMentioned) {
                Write-Log "Bot not mentioned, skipping..." "WARN"
                Save-LastMessageId $msgId
                continue
            }

            Write-Log "Bot mentioned! Processing..." "SUCCESS"

            # Clean message (remove @mention)
            $cleanMessage = Get-CleanMessage $msgText
            Write-Log "Clean message: $($cleanMessage.Substring(0, [Math]::Min(50, $cleanMessage.Length)))..."

            # Detect language
            $lang = Detect-Language $cleanMessage
            Write-Log "Detected language: $lang"

            # Initialize analysis state for stability loop
            $attempt = 1
            $stableCount = 0
            $lastHypothesisHash = ""
            $lastHypothesis = ""
            $finalAnalysis = ""
            $finalConfidence = 0.0

            # Stability Loop with v3 intelligent repo selection
            while ($attempt -le $MAX_ATTEMPTS) {
                Write-Log "=== Analysis Attempt $attempt/$MAX_ATTEMPTS (v3: Intelligent Repo Selection) ===" "INFO"

                # Analyze with Claude Code v3
                $analysis = Invoke-Analysis $cleanMessage $lang $attempt $lastHypothesis

                if ([string]::IsNullOrWhiteSpace($analysis)) {
                    Write-Log "Failed to get analysis from Claude" "ERROR"
                    break
                }

                Write-Log "Analysis received ($($analysis.Length) chars)"

                # Extract hypothesis and confidence
                $currentHypothesis = Get-HypothesisFromAnalysis $analysis
                $currentConfidence = Get-ConfidenceFromAnalysis $analysis

                Write-Log "Hypothesis: $($currentHypothesis.Substring(0, [Math]::Min(60, $currentHypothesis.Length)))..."
                Write-Log "Confidence: $currentConfidence"

                # Compute hash of hypothesis
                $currentHash = Get-StringHash $currentHypothesis

                # Check stability
                if ($currentHash -eq $lastHypothesisHash -and $lastHypothesisHash -ne "") {
                    $stableCount++
                    Write-Log "Hypothesis stable (count: $stableCount)" "SUCCESS"
                } else {
                    $stableCount = 1
                    Write-Log "Hypothesis changed, resetting stability count"
                }

                # Update state
                $lastHypothesisHash = $currentHash
                $lastHypothesis = $currentHypothesis
                $finalAnalysis = $analysis
                $finalConfidence = $currentConfidence

                # Check exit conditions
                $done = ($stableCount -ge $STABLE_HASH_COUNT) -or
                        ($currentConfidence -ge $CONFIDENCE_THRESHOLD) -or
                        ($attempt -ge $MAX_ATTEMPTS)

                if ($done) {
                    $reason = if ($stableCount -ge $STABLE_HASH_COUNT) {
                        "Hypothesis stable ($stableCount consecutive)"
                    } elseif ($currentConfidence -ge $CONFIDENCE_THRESHOLD) {
                        "High confidence ($currentConfidence >= $CONFIDENCE_THRESHOLD)"
                    } else {
                        "Max attempts reached ($MAX_ATTEMPTS)"
                    }

                    Write-Log "Analysis complete! Reason: $reason" "SUCCESS"
                    break
                }

                Write-Log "Continuing to next attempt..."
                $attempt++
            }

            # Send response to Teams (as thread reply)
            Write-Log "Sending response to Teams..."
            $sendResult = Send-ToTeams $CHANNEL_NAME $finalAnalysis $msgId

            if ($sendResult) {
                Write-Log "Response sent successfully (Confidence: $finalConfidence, Attempts: $attempt)" "SUCCESS"
            } else {
                Write-Log "Failed to send response" "ERROR"
            }

            # Save last processed message ID
            Save-LastMessageId $msgId

            Write-Log "==================================="
        }
    } catch {
        Write-Log "Error in polling loop: $_" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    }

    Start-Sleep -Seconds $POLL_INTERVAL
}
