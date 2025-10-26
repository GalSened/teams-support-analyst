# Teams Support Analyst - Orchestrator Script v5 (PowerShell) - Human-Like Edition
#
# This script:
# 1. Polls Microsoft Teams GROUP CHAT for new messages (via Graph API)
# 2. Responds to @mentions AND auto-detects errors/questions
# 3. Uses stability loop for iterative refinement
# 4. Replies in same thread
# 5. Separates internal analysis from user-facing responses
# 6. Sends clean, human-like responses to Teams (no technical jargon)
# 7. Logs full analysis for debugging
#
# Requirements:
# - Microsoft Graph API authentication token (in C:\Users\gals\.msgraph-mcp-auth.json)
# - LocalSearch API running on http://localhost:3001
# - claude CLI in PATH
# - TEAMS_CHAT_ID environment variable set

# Fix encoding for Hebrew and Unicode characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ═══════════════════════════════════════════════════════════════
# PROCESS LOCKING - Prevent duplicate orchestrator instances
# ═══════════════════════════════════════════════════════════════
$LOCK_FILE = "$PSScriptRoot\state\orchestrator.lock"
$LOCK_DIR = Split-Path $LOCK_FILE
if (!(Test-Path $LOCK_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOCK_DIR | Out-Null
}

# Check if lock file exists and contains a valid PID
if (Test-Path $LOCK_FILE) {
    try {
        $lockPid = Get-Content $LOCK_FILE -ErrorAction SilentlyContinue
        if ($lockPid -and ($lockPid -match '^\d+$')) {
            # Check if process is still running
            $existingProcess = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
            if ($existingProcess) {
                Write-Host "" -ForegroundColor Red
                Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
                Write-Host "║  ⚠️  ORCHESTRATOR ALREADY RUNNING                              ║" -ForegroundColor Red
                Write-Host "║                                                                ║" -ForegroundColor Red
                Write-Host "║  Another orchestrator instance is already active:              ║" -ForegroundColor Red
                Write-Host "║  PID: $($lockPid.PadRight(58))║" -ForegroundColor Red
                Write-Host "║                                                                ║" -ForegroundColor Red
                Write-Host "║  To restart the orchestrator, use:                             ║" -ForegroundColor Red
                Write-Host "║  .\restart-orchestrator-clean.ps1                              ║" -ForegroundColor Red
                Write-Host "║                                                                ║" -ForegroundColor Red
                Write-Host "║  Or manually kill PID $lockPid and delete the lock file:       " -ForegroundColor Red
                Write-Host "║  Stop-Process -Id $lockPid -Force                              " -ForegroundColor Red
                Write-Host "║  Remove-Item '$LOCK_FILE'                                      " -ForegroundColor Red
                Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
                Write-Host "" -ForegroundColor Red
                exit 1
            } else {
                # Stale lock file - process no longer running
                Write-Host "⚠️  Found stale lock file (PID $lockPid no longer running). Cleaning up..." -ForegroundColor Yellow
                Remove-Item $LOCK_FILE -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "⚠️  Error checking lock file: $_" -ForegroundColor Yellow
        Write-Host "Attempting to clean up and continue..." -ForegroundColor Yellow
        Remove-Item $LOCK_FILE -Force -ErrorAction SilentlyContinue
    }
}

# Create lock file with current PID
try {
    Set-Content $LOCK_FILE $PID -Force
    Write-Host "✅ Process lock acquired (PID: $PID)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create lock file: $_" -ForegroundColor Red
    exit 1
}

# Cleanup lock file on exit
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $lockPath = "$PSScriptRoot\state\orchestrator.lock"
    if (Test-Path $lockPath) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        Write-Host "`n🔓 Process lock released" -ForegroundColor Cyan
    }
}

# Import Graph API helpers
. "$PSScriptRoot\graph-api-helpers.ps1"

# Configuration
$POLL_INTERVAL = 10  # seconds
$STATE_FILE = "./state/last_message_id.txt"
$BOT_MESSAGES_FILE = "./state/bot_sent_messages.json"  # Track message IDs sent by bot
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
Write-Host "=== Teams Support Analyst Orchestrator v5 (Human-Like Edition) Starting ===" -ForegroundColor Cyan
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
Write-Host "✨ v5-FIXED: Responds to @mentions only (message ID tracking prevents feedback loop!)" -ForegroundColor Green
Write-Host "✨ v4: Fast-fail on access errors (MAX_ATTEMPTS: $MAX_ATTEMPTS)" -ForegroundColor Green
Write-Host "✨ v5: Clean user responses (no technical jargon)" -ForegroundColor Green
Write-Host "✨ v5: Full analysis kept in logs for debugging" -ForegroundColor Green
Write-Host "✨ v5: Instant acknowledgment (users see 'working on it' immediately)" -ForegroundColor Green

# Initialize bot messages tracking file
if (-not (Test-Path $BOT_MESSAGES_FILE)) {
    Write-Host "Creating bot messages tracking file..." -ForegroundColor Yellow
    @{} | ConvertTo-Json | Set-Content $BOT_MESSAGES_FILE
}
Write-Host "Bot messages tracking initialized" -ForegroundColor Green

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

# Function to check if message ID was sent by bot
function Test-BotSentMessage {
    param([string]$MessageId)

    if (-not (Test-Path $BOT_MESSAGES_FILE)) {
        return $false
    }

    try {
        $botMessages = Get-Content $BOT_MESSAGES_FILE | ConvertFrom-Json
        return $botMessages.PSObject.Properties.Name -contains $MessageId
    } catch {
        Write-Log "Error reading bot messages file: $_" "WARN"
        return $false
    }
}

# Function to save message ID sent by bot
function Save-BotSentMessage {
    param([string]$MessageId)

    try {
        $botMessages = @{}
        if (Test-Path $BOT_MESSAGES_FILE) {
            # PowerShell 5.1 compatible: Convert PSCustomObject to hashtable
            $jsonObj = Get-Content $BOT_MESSAGES_FILE | ConvertFrom-Json
            foreach ($property in $jsonObj.PSObject.Properties) {
                $botMessages[$property.Name] = $property.Value
            }
        }

        # Add new message ID with timestamp
        $botMessages[$MessageId] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        # Keep only last 100 message IDs to prevent file from growing too large
        if ($botMessages.Count -gt 100) {
            $sortedKeys = $botMessages.GetEnumerator() | Sort-Object Value | Select-Object -First ($botMessages.Count - 100) | ForEach-Object { $_.Key }
            foreach ($key in $sortedKeys) {
                $botMessages.Remove($key)
            }
        }

        $botMessages | ConvertTo-Json | Set-Content $BOT_MESSAGES_FILE
        Write-Log "Saved bot message ID: $MessageId"
    } catch {
        Write-Log "Error saving bot message ID: $_" "WARN"
    }
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

# Function to check if message is from the bot itself (FEEDBACK LOOP PREVENTION)
function Test-IsBotMessage {
    param([string]$Text)

    $botMessagePatterns = @(
        # English patterns - old format
        "^Got it! Looking into this",
        "^👋 Hey! I looked into this",
        "^<p>Got it! Looking into this",
        "^<p>👋 Hey! I looked into this",

        # English patterns - new pretty format
        "╔═+╗",
        "║.*ANALYSIS COMPLETE",
        "🔍 ANALYSIS COMPLETE",
        "^📌 WHAT'S HAPPENING",
        "^💡 ROOT CAUSE",
        "^🔧 RECOMMENDED FIX",
        "^📂 CODE LOCATION",

        # Hebrew patterns - acknowledgment
        "^הבנתי! בודק את זה",
        "^רגע, אני בודק",

        # Hebrew patterns - responses
        "^👋 היי! בדקתי את זה",
        "^שלום! בדקתי את זה",
        "מה קורה:",
        "הסיבה השורשית:",
        "תיקון מומלץ:",
        "מיקום בקוד:"
    )

    foreach ($pattern in $botMessagePatterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
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

# Function to detect question type and return appropriate template
function Get-QuestionType {
    param([string]$MessageText)

    # Type 3: Log paste (highest priority - look for stack traces, exceptions, error dumps)
    if ($MessageText -match "Exception:|Error:|at .* line \d+|Stack trace:|Traceback|^\s+at\s+|System\.\w+Exception") {
        return "LOG_PASTE"
    }

    # Type 4: API Usage (second priority - look for API-related questions)
    if ($MessageText -match "API|דרך API|באמצעות API|עם API|קריאת API|via API|using API|through API|API call|API endpoint|REST API|POST|GET|PUT|DELETE|endpoint") {
        return "API_USAGE"
    }

    # Type 2: Issue/Problem (look for problem indicators)
    if ($MessageText -match "בעיה|שגיאה|לא עובד|לא מצליח|תקוע|error|issue|problem|not working|doesn't work|failing|broken") {
        return "ISSUE"
    }

    # Type 1: How-to (default - look for question words)
    if ($MessageText -match "איך|כיצד|מה ה|how to|how do|how can|what is|where is|explain") {
        return "HOWTO"
    }

    # Default to HOWTO for general questions
    return "HOWTO"
}

# Function to analyze message with Claude Code (v3: ENHANCED with intelligent repo selection)
function Invoke-Analysis {
    param(
        [string]$MessageText,
        [string]$Language,
        [int]$Attempt,
        [string]$PreviousHypothesis = "",
        [string]$PreviousEvidence = "",
        [string]$UserName = "there"
    )

    # Detect question type
    $questionType = Get-QuestionType -MessageText $MessageText
    Write-Log "Detected question type: $questionType"

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

CRITICAL: Your response must have TWO separate sections:
1. INTERNAL ANALYSIS (for logs only) - detailed technical analysis
2. USER RESPONSE (sent to Teams) - clean, formatted, visual structure

User question ($Language): $MessageText
Asker's name: $UserName

$attemptInfo

**CONTEXT:**
The WeSign system has 3 main repositories:
- user-backend - Backend API, C#, auth, database
- wesign-client-DEV - Frontend, React/TypeScript
- wesignsigner-client-app-DEV - Signing app

**REQUIRED RESPONSE FORMAT:**

--- INTERNAL ANALYSIS START ---
**Hypothesis:** [Your detailed technical theory based on actual code you found]
**Confidence:** [0.75-1.0 as decimal]
**Evidence:** [MUST include specific file paths with line numbers - e.g., src/upload.ts:45-67]
**Code Found:** [Brief code snippet or function names you discovered]
**Repository:** [Which repo you searched]
--- INTERNAL ANALYSIS END ---

--- USER RESPONSE START ---
$(
    switch ($questionType) {
        "HOWTO" {
            if ($Language -eq 'he') {
@"
היי $UserName,

[Direct answer with specific API/method/function name - 1 sentence]
[Where to find it: file:line - 1 sentence]
[Basic code example or usage pattern - 1-2 sentences]

_[Optional: One-line offer about related functionality in existing code]_
"@
            } else {
@"
Hey $UserName,

[Direct answer with specific API/method/function name - 1 sentence]
[Where to find it: file:line - 1 sentence]
[Basic code example or usage pattern - 1-2 sentences]

_[Optional: One-line offer about related functionality in existing code]_
"@
            }
        }
        "ISSUE" {
            if ($Language -eq 'he') {
@"
היי $UserName,

## מה קורה
[What's happening in simple terms - 1 sentence]

## למה זה קורה
[Root cause explanation - 1-2 sentences]

## מה לעשות
1. [Specific actionable step with file:line]
2. [Specific actionable step with file:line]
3. [Specific actionable step with file:line]

_[Optional: Prevention tip or related info]_
"@
            } else {
@"
Hey $UserName,

## What's Happening
[What's happening in simple terms - 1 sentence]

## Why It Happens
[Root cause explanation - 1-2 sentences]

## What to Do
1. [Specific actionable step with file:line]
2. [Specific actionable step with file:line]
3. [Specific actionable step with file:line]

_[Optional: Prevention tip or related info]_
"@
            }
        }
        "LOG_PASTE" {
            if ($Language -eq 'he') {
@"
היי $UserName,

[Error interpretation - what it means - 1 sentence]
[Exact location: file:line where the error originates - 1 sentence]
[Quick fix action - what to do right now - 1 sentence]

_[Optional: Want to understand the root cause?]_
"@
            } else {
@"
Hey $UserName,

[Error interpretation - what it means - 1 sentence]
[Exact location: file:line where the error originates - 1 sentence]
[Quick fix action - what to do right now - 1 sentence]

_[Optional: Want to understand the root cause?]_
"@
            }
        }
        "API_USAGE" {
            if ($Language -eq 'he') {
@"
היי $UserName,

[API endpoint description - what it does - 1 sentence]
[Exact endpoint and HTTP method - e.g., POST /api/documents - 1 sentence]
[Request format with required fields - 1-2 sentences]
[Response format - what you'll get back - 1 sentence]
[Practical code example in curl or C# HttpClient - 1-2 sentences]

_[Optional: Additional API tips or related endpoints]_
"@
            } else {
@"
Hey $UserName,

[API endpoint description - what it does - 1 sentence]
[Exact endpoint and HTTP method - e.g., POST /api/documents - 1 sentence]
[Request format with required fields - 1-2 sentences]
[Response format - what you'll get back - 1 sentence]
[Practical code example in curl or C# HttpClient - 1-2 sentences]

_[Optional: Additional API tips or related endpoints]_
"@
            }
        }
    }
)
--- USER RESPONSE END ---

CRITICAL VALIDATION RULES (ALL QUESTION TYPES):
- SEARCH FIRST, ASK LATER: Use MCP tools to search the code FIRST. Only ask for clarification if you genuinely find NO relevant code
- BE CONFIDENT: If you find code (even partially related), answer directly. Don't explain what you are or ask for clarification
- NO META-TALK: Never say "I'm a support system" or "I monitor the code" - just answer the question
- PERSONALIZATION: Start with user's first name (e.g., "Hey Sarah," or "היי גל,")
- NO EMOJIS: Unless user uses them first or the context is very casual
- EXISTING CODE ONLY: Answer about what exists in the code - no development suggestions
- FORBIDDEN PHRASES: NEVER use "how to add", "how to implement", "you could add", "I can help you build"
- NO DEVELOPMENT SUGGESTIONS: If something doesn't exist, say "That doesn't exist yet, but here's what IS there:"
- SIMPLE LANGUAGE: Plain everyday language - avoid heavy jargon (e.g., "endpoint (נקודת קצה)" instead of just "endpoint")
- INTERNAL section: Provide detailed technical analysis
- USER section: Natural conversational tone - like chatting with a colleague
- ANSWER EXACTLY WHAT WAS ASKED: Read the question carefully - don't drift to related topics
- SECURITY: If asked for secrets/passwords/tokens, REFUSE and explain WHERE to find them securely (Key Vault, env vars)
- HEBREW LANGUAGE: Read Hebrew carefully - translate to yourself first, then answer THAT exact question

QUESTION TYPE SPECIFIC RULES (Current question is: $questionType):

$(if ($questionType -eq 'HOWTO') {
@"
**HOWTO QUESTIONS:**
- Length: 4-5 sentences total
- Structure: NO sections, conversational flow
- Must include: API/method name, file:line location, code example
- Tone: Instructional and direct
- Example: "היי גל, יצירת מסמך עובדת דרך DocumentsController.CreateDocument() שנמצא ב-DocumentsController.cs:45. אתה שולח POST request עם DocumentDTO שמכיל Name, Content, Type."
"@
} elseif ($questionType -eq 'ISSUE') {
@"
**ISSUE/BUG QUESTIONS:**
- Length: 5-6 sentences total (including numbered steps)
- Structure: USE sections (## מה קורה, ## למה זה קורה, ## מה לעשות)
- Must include: Root cause explanation, numbered action steps with file:line
- Tone: Problem-solver, structured
- Example: "היי גל, ## מה קורה\nהמסמך לא נשמר כי validation נכשל. ## למה זה קורה\nב-DocumentValidator.cs:23 יש בדיקה שהשדה Name חייב להיות לפחות 3 תווים..."
"@
} elseif ($questionType -eq 'API_USAGE') {
@"
**API USAGE QUESTIONS:**
- Length: 5-6 sentences total
- Structure: NO sections, but clear API documentation flow
- Must include: Endpoint URL, HTTP method (POST/GET/etc), request JSON structure, response format, practical code example
- Tone: Technical documentation, external consumer perspective
- Focus: How external users/integrators consume the API, NOT internal implementation
- Code examples: Prefer curl or C# HttpClient format (what API consumers would use)
- Example: "היי גל, יצירת מסמך עובדת דרך POST /api/v1/documents. אתה שולח JSON עם {name: 'document.pdf', content: 'base64...', type: 'pdf'}. התשובה תהיה {documentId: '123', status: 'pending'}. דוגמה ב-curl: curl -X POST https://api.wesign.co.il/v1/documents -H 'Authorization: Bearer YOUR_TOKEN' -d '{...}'."
"@
} else {
@"
**LOG PASTE / ERROR TRACE:**
- Length: 2-3 sentences ONLY - ultra concise!
- Structure: NO sections, just diagnostic facts
- Must include: Error interpretation, exact file:line, immediate fix
- Tone: Diagnostic mode - get straight to the point
- Example: "היי גל, זה NullReferenceException שקורה כי UserContext.Current הוא null. הבעיה ב-AuthMiddleware.cs:67 בשורה 'var user = UserContext.Current.Id'. תבדוק שה-authentication middleware רץ לפני."
"@
})
"@

    try {
        Write-Log "Invoking Claude Code v3 (Attempt $Attempt) with MCP enabled for code access..."
        # MCP enabled to allow bot to search code repositories
        $response = $prompt | claude --mcp-config "$PSScriptRoot\mcp-config.json" --print 2>&1
        return $response
    } catch {
        Write-Log "Error invoking Claude: $_" "ERROR"
        return $null
    }
}

# Function to extract USER RESPONSE section from Claude's two-part response
function Extract-UserResponse {
    param([string]$FullResponse)

    # Extract text between USER RESPONSE markers
    if ($FullResponse -match '--- USER RESPONSE START ---\s*(.+?)\s*--- USER RESPONSE END ---') {
        return $matches[1].Trim()
    }

    # Fallback: if markers not found, return full response (for backward compatibility)
    Write-Log "WARNING: Could not find USER RESPONSE markers in Claude response" "WARN"
    return $FullResponse
}

# Function to extract INTERNAL ANALYSIS section for logging
function Extract-InternalAnalysis {
    param([string]$FullResponse)

    # Extract text between INTERNAL ANALYSIS markers
    if ($FullResponse -match '--- INTERNAL ANALYSIS START ---\s*(.+?)\s*--- INTERNAL ANALYSIS END ---') {
        return $matches[1].Trim()
    }

    # Fallback: return empty if not found
    return ""
}

# Function to send response to Teams (as thread reply)
function Send-ToTeams {
    param([string]$ChatId, [string]$Message, [string]$ReplyToId)

    try {
        Write-Log "Sending reply to Teams chat (message ID: $ReplyToId)..."
        $result = Send-TeamsChatMessage -ChatId $ChatId -Message $Message -ReplyToId $ReplyToId

        # Save the bot's message ID to prevent feedback loop
        if ($result -and $result.id) {
            Save-BotSentMessage $result.id
            Write-Log "Bot message ID saved: $($result.id)" "SUCCESS"
        }

        return $result
    } catch {
        Write-Log "Error sending to Teams: $_" "ERROR"
        return $null
    }
}

# Main polling loop
Write-Log "Starting polling loop (interval: ${POLL_INTERVAL}s)"
Write-Log "Monitoring group chat: $CHAT_NAME (ID: $CHAT_ID)"
Write-Log "Will respond to @$BOT_NAME mentions only (message ID tracking prevents feedback loop!)"

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
            $msgFromName = if ($msg.from.user) { $msg.from.user.displayName } else { "Unknown" }

            # Skip if already processed
            if ($msgId -eq $lastId) {
                continue
            }

            Write-Log "New message from ${msgFromName}: $($msgText.Substring(0, [Math]::Min(50, $msgText.Length)))..."

            # FIXED: Check if message was sent by bot (FEEDBACK LOOP PREVENTION)
            if (Test-BotSentMessage $msgId) {
                Write-Log "Skipping bot's own message (message ID: $msgId)" "WARN"
                # DON'T save lastId for bot messages - it overwrites user message tracking!
                continue
            }

            # Check @mention requirement
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

            # Send immediate acknowledgment to Teams (Hebrew or English)
            Write-Log "Sending acknowledgment to Teams..."
            $ackMessage = if ($lang -eq "he") {
                "רגע, בודק..."
            } else {
                "Looking into it..."
            }
            $ackResult = Send-ToTeams $CHAT_ID $ackMessage $msgId
            if ($ackResult) {
                Write-Log "Acknowledgment sent successfully" "SUCCESS"
            } else {
                Write-Log "Failed to send acknowledgment (continuing anyway...)" "WARN"
            }
            Write-Log "Acknowledgment sent - proceeding to analysis"

            # Initialize analysis state for stability loop
            $attempt = 1
            $stableCount = 0
            $lastHypothesisHash = ""
            $lastHypothesis = ""
            $finalAnalysis = ""
            $finalConfidence = 0.0

            # Stability Loop with v5 human-like responses
            while ($attempt -le $MAX_ATTEMPTS) {
                Write-Log "=== Analysis Attempt $attempt/$MAX_ATTEMPTS (v5: Human-Like Edition) ===" "INFO"

                # Analyze with Claude Code v3
                $analysis = Invoke-Analysis $cleanMessage $lang $attempt $lastHypothesis "" $msgFromName

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

            # Extract sections from response
            $userResponse = Extract-UserResponse $finalAnalysis
            $internalAnalysis = Extract-InternalAnalysis $finalAnalysis

            # Log full internal analysis for debugging
            if (-not [string]::IsNullOrWhiteSpace($internalAnalysis)) {
                Write-Log "=== INTERNAL ANALYSIS (v5) ===" "INFO"
                Write-Log $internalAnalysis "INFO"
                Write-Log "=== END INTERNAL ANALYSIS ===" "INFO"
            }

            # Send only user-friendly response to Teams (as thread reply)
            Write-Log "Sending user response to Teams chat (length: $($userResponse.Length) chars)..."
            $sendResult = Send-ToTeams $CHAT_ID $userResponse $msgId

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
