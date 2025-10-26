# Teams Support Analyst - Orchestrator Script v3 (PowerShell) - Group Chat Edition
#
# This script:
# 1. Polls Microsoft Teams GROUP CHAT for new messages (via Graph API)
# 2. ONLY responds when bot is @mentioned
# 3. Uses stability loop for iterative refinement
# 4. Replies in same thread
# 5. **NEW: Intelligent repo selection for faster, more accurate analysis**
# 6. Invokes Claude Code to analyze each message (using LocalSearch MCP)
# 7. Sends the response back to Teams group chat (via Graph API)
#
# Requirements:
# - Microsoft Graph API authentication token (in C:\Users\gals\.msgraph-mcp-auth.json)
# - LocalSearch API running on http://localhost:3001
# - claude CLI in PATH
# - TEAMS_CHAT_ID environment variable set

# Import Graph API helpers
. "$PSScriptRoot\graph-api-helpers.ps1"

# Configuration
$POLL_INTERVAL = 10  # seconds
$STATE_FILE = "./state/last_message_id.txt"
$ANALYSIS_STATE_FILE = "./state/analysis_state.json"
$LOG_FILE = "./logs/orchestrator.log"
$CHAT_ID = if ($env:TEAMS_CHAT_ID) { $env:TEAMS_CHAT_ID } else { "" }
$CHAT_NAME = if ($env:TEAMS_CHANNEL_NAME) { $env:TEAMS_CHANNEL_NAME } else { "support" }
$BOT_NAME = if ($env:BOT_NAME) { $env:BOT_NAME } else { "SupportBot" }

# Analysis settings (Stability Loop - OPTIMIZED for speed)
$MAX_ATTEMPTS = 2  # Reduced from 4 for faster responses
$CONFIDENCE_THRESHOLD = 0.75  # Lowered from 0.9 for quicker exits
$STABLE_HASH_COUNT = 2

# Initialize
Write-Host "=== Teams Support Analyst Orchestrator v4 (Humanized Edition) Starting ===" -ForegroundColor Cyan
Write-Host "🤖 Meet Alex: Your friendly senior dev teammate!" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path (Split-Path $STATE_FILE) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $LOG_FILE) | Out-Null

# Validate CHAT_ID
if ([string]::IsNullOrWhiteSpace($CHAT_ID)) {
    Write-Host "ERROR: TEAMS_CHAT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it in the .env file or environment." -ForegroundColor Red
    exit 1
}

Write-Host "Bot Name: $BOT_NAME (Persona: Alex)" -ForegroundColor Yellow
Write-Host "Group Chat: $CHAT_NAME (ID: $CHAT_ID)" -ForegroundColor Yellow
Write-Host "Will only respond to @mentions" -ForegroundColor Yellow
Write-Host "✨ NEW: Fast-fail on access errors (MAX_ATTEMPTS: $MAX_ATTEMPTS)" -ForegroundColor Green
Write-Host "✨ NEW: Humanized responses with empathy & clarity" -ForegroundColor Green
Write-Host "✨ NEW: No permission requests in chat!" -ForegroundColor Green

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

# Function to detect access/permission errors (FAST-FAIL)
function Test-AccessError {
    param([string]$AnalysisText, [string]$Hypothesis)

    $accessErrorPatterns = @(
        "cannot access",
        "permission denied",
        "outside accessible directory",
        "repository paths are outside",
        "don't have permission",
        "cannot perform analysis"
    )

    foreach ($pattern in $accessErrorPatterns) {
        if ($AnalysisText -match $pattern -or $Hypothesis -match $pattern) {
            return $true
        }
    }

    return $false
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
You are Alex, a senior developer on the WeSign support team. You're helpful, friendly, and patient.

CRITICAL RULES:
- NEVER ask the user for permissions or directory access in your response
- NEVER say things like "I need your permission to access..."
- If you can't access code, provide general guidance and ask clarifying questions instead
- Be conversational and helpful, like talking to a teammate

User question ($Language): $MessageText

$attemptInfo

Available Repositories (for reference):
- **user-backend**: Backend API, auth, database, getUserInfo, login
- **wesign-client-DEV**: Frontend UI, React, forms, pages, buttons
- **wesignsigner-client-app-DEV**: Document signing, PDF, upload

Your approach:

**ANALYZE the question keywords:**
- Backend: API, server, database, login, "returns null", "API fails"
- Frontend: UI, button, form, page, display, "button doesn't work"
- Signing: signature, document, PDF, upload, "signature fails"

**YOUR RESPONSE FORMAT** (friendly and readable):

👋 Hey! I looked into this for you.

**What's happening:**
[1-2 sentence summary in simple language]

**My analysis:**
[Root cause hypothesis - be honest about confidence]
**Confidence:** [0.75-1.0 as decimal]

**Why this happens:**
[Explain the cause in plain language, use analogies if helpful]

**How to fix it:**
1. [Specific step 1]
2. [Specific step 2]
3. [Specific step 3]

**Code pointers** (if you found specific files):
- \`path/to/file.ts:120\` - [what's there]
- \`another/file.ts:45\` - [what's there]

**If I can't access the code:**
Still provide value! Share:
- General guidance based on the error/symptom
- Common causes for this type of issue
- Questions to help narrow it down
- Where to look (files, logs, areas of code)

**Need more details?** Just let me know! 😊

REMEMBER: Be warm, conversational, and helpful. Never ask for permissions in chat!
"@

    try {
        Write-Log "Invoking Claude Code v3 (Attempt $Attempt) with intelligent repo selection..."
        $response = $prompt | claude 2>&1
        return $response
    } catch {
        Write-Log "Error invoking Claude: $_" "ERROR"
        return $null
    }
}

# Function to send response to Teams (as thread reply)
function Send-ToTeams {
    param([string]$ChatId, [string]$Message, [string]$ReplyToId)

    try {
        Write-Log "Sending reply to Teams chat (message ID: $ReplyToId)..."
        $result = Send-TeamsChatMessage -ChatId $ChatId -Message $Message -ReplyToId $ReplyToId
        return $result
    } catch {
        Write-Log "Error sending to Teams: $_" "ERROR"
        return $null
    }
}

# Main polling loop
Write-Log "Starting polling loop (interval: ${POLL_INTERVAL}s)"
Write-Log "Monitoring group chat: $CHAT_NAME (ID: $CHAT_ID)"
Write-Log "Only responding to @$BOT_NAME mentions"

while ($true) {
    Write-Log "Checking for new messages..."

    $lastId = Get-LastMessageId

    # Get new messages from Teams via Microsoft Graph API
    try {
        $messages = Get-TeamsChatMessages -ChatId $CHAT_ID -Top 5

        if ($null -eq $messages -or $messages.Count -eq 0) {
            Write-Log "No new messages"
            Start-Sleep -Seconds $POLL_INTERVAL
            continue
        }

        foreach ($msg in $messages) {
            $msgId = $msg.id
            $msgText = $msg.body.content
            $msgFrom = if ($msg.from.user) { $msg.from.user.displayName } else { "Unknown" }

            # Skip if already processed
            if ($msgId -eq $lastId) {
                continue
            }

            Write-Log "New message from ${msgFrom}: $($msgText.Substring(0, [Math]::Min(50, $msgText.Length)))..."

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

            # Stability Loop with v4 humanized responses
            while ($attempt -le $MAX_ATTEMPTS) {
                Write-Log "=== Analysis Attempt $attempt/$MAX_ATTEMPTS (v4: Humanized Edition) ===" "INFO"

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

                # FAST-FAIL: Check for access/permission errors
                $isAccessError = Test-AccessError $analysis $currentHypothesis

                # Check exit conditions
                $done = ($stableCount -ge $STABLE_HASH_COUNT) -or
                        ($currentConfidence -ge $CONFIDENCE_THRESHOLD) -or
                        ($attempt -ge $MAX_ATTEMPTS) -or
                        ($isAccessError -and $attempt -ge 1)  # Exit immediately on access errors

                if ($done) {
                    $reason = if ($isAccessError -and $attempt -ge 1) {
                        "Access error detected (fast-fail after attempt $attempt)"
                    } elseif ($stableCount -ge $STABLE_HASH_COUNT) {
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
            Write-Log "Sending response to Teams chat..."
            $sendResult = Send-ToTeams $CHAT_ID $finalAnalysis $msgId

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
