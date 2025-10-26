# Smart Bilingual Test - Real Technical Questions
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SMART BILINGUAL TEST - Technical Support Questions       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Test 1: English - Real technical question about document upload
Write-Host "[TEST 1] Sending English Question..." -ForegroundColor Yellow
Write-Host "Question: User getting 500 error when uploading PDF documents" -ForegroundColor White
$msg1 = Send-TeamsChatMessage -ChatId $chatId -Message "@supportbot I'm getting a 500 internal server error when trying to upload PDF documents. The upload works for Word files but fails for PDFs over 5MB. What could be causing this?"
Write-Host "✅ Sent: ID $($msg1.id)" -ForegroundColor Green
$englishTestId = $msg1.id
Write-Host "   Expected: Language='en', Acknowledgment='Got it! Looking into this...'" -ForegroundColor Gray

Start-Sleep -Seconds 15

# Test 2: Hebrew - Real technical question about template management
Write-Host "`n[TEST 2] Sending Hebrew Question..." -ForegroundColor Yellow
Write-Host "Question: בעיה עם תבניות - לא שומר שדות חתימה" -ForegroundColor White
$msg2 = Send-TeamsChatMessage -ChatId $chatId -Message "@supportbot יש לי בעיה עם תבניות. כשאני יוצר תבנית חדשה ומוסיף שדות חתימה, השדות לא נשמרים. מה הבעיה?"
Write-Host "✅ Sent: ID $($msg2.id)" -ForegroundColor Green
$hebrewTestId = $msg2.id
Write-Host "   Expected: Language='he', Acknowledgment='הבנתי! בודק את זה...'" -ForegroundColor Gray
Write-Host "   Translation: Problem with templates - signature fields not saving" -ForegroundColor DarkGray

Write-Host "`n⏳ Waiting 30 seconds for bot to process both questions..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check logs for verification
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  VERIFICATION - Checking Logs                              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$logFile = "$PSScriptRoot\logs\orchestrator.log"
$recentLogs = Get-Content $logFile -Tail 100

# Check English test
Write-Host "[ENGLISH TEST VERIFICATION]" -ForegroundColor Yellow
$englishDetection = $recentLogs | Select-String -Pattern "$englishTestId" -Context 5 | Select-Object -First 1
if ($englishDetection) {
    $contextLines = $englishDetection.Context.PostContext
    $langLine = $contextLines | Select-String "Detected language: (en|he)"
    if ($langLine -match "en") {
        Write-Host "  ✅ Language detected: en" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Language detection failed: $langLine" -ForegroundColor Red
    }

    $ackLine = $contextLines | Select-String "Got it! Looking into this"
    if ($ackLine) {
        Write-Host "  ✅ English acknowledgment sent" -ForegroundColor Green
    } else {
        Write-Host "  ❌ English acknowledgment not found" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️  Message not yet processed" -ForegroundColor Yellow
}

# Check Hebrew test
Write-Host "`n[HEBREW TEST VERIFICATION]" -ForegroundColor Yellow
$hebrewDetection = $recentLogs | Select-String -Pattern "$hebrewTestId" -Context 5 | Select-Object -First 1
if ($hebrewDetection) {
    $contextLines = $hebrewDetection.Context.PostContext
    $langLine = $contextLines | Select-String "Detected language: (en|he)"
    if ($langLine -match "he") {
        Write-Host "  ✅ Language detected: he" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Language detection failed: $langLine" -ForegroundColor Red
    }

    $hebrewAckLine = $contextLines | Select-String "הבנתי"
    if ($hebrewAckLine) {
        Write-Host "  ✅ Hebrew acknowledgment sent (הבנתי! בודק את זה...)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Hebrew acknowledgment not found" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️  Message not yet processed" -ForegroundColor Yellow
}

# Check bot self-detection
Write-Host "`n[BOT SELF-DETECTION CHECK]" -ForegroundColor Yellow
$botSkips = $recentLogs | Select-String "Skipping bot's own message" | Select-Object -Last 5
if ($botSkips.Count -gt 0) {
    Write-Host "  ✅ Bot correctly skipping own messages: $($botSkips.Count) detected" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  No bot self-detection events found (may not have responded yet)" -ForegroundColor Yellow
}

# Show recent messages from Teams
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TEAMS MESSAGES - Last 5 Messages                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$messages = Get-TeamsChatMessages -ChatId $chatId -Top 5
foreach ($msg in $messages) {
    $preview = $msg.body.content.Substring(0, [Math]::Min(60, $msg.body.content.Length))
    Write-Host "[$($msg.id)] " -NoNewline -ForegroundColor DarkGray

    if ($msg.body.content -match "הבנתי|Got it") {
        Write-Host "🤖 BOT: " -NoNewline -ForegroundColor Cyan
    } elseif ($msg.body.content -match "@supportbot") {
        Write-Host "👤 USER: " -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host "📝 RESPONSE: " -NoNewline -ForegroundColor Magenta
    }

    Write-Host "$preview..."
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  TEST COMPLETE                                             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
