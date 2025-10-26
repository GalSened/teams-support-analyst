# Test all 4 question types for bot question-type detection
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Get fresh token using bot's auth system
$token = Get-GraphToken

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "=== TESTING 4 QUESTION TYPES ===" -ForegroundColor Cyan
Write-Host ""

# TEST 1: HOWTO Question
Write-Host "[1/4] Testing HOWTO question..." -ForegroundColor Yellow
$howtoMessage = @"
@SupportBot איך עובד ה-validation של מסמכים במערכת?
"@

$body = @{
    body = @{
        content = $howtoMessage
    }
} | ConvertTo-Json -Depth 3

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body | Out-Null
Write-Host "✅ HOWTO question sent" -ForegroundColor Green
Write-Host "Expected: 4-5 sentences, conversational, with code location and example" -ForegroundColor Gray
Start-Sleep -Seconds 2

# TEST 2: ISSUE Question
Write-Host ""
Write-Host "[2/4] Testing ISSUE question..." -ForegroundColor Yellow
$issueMessage = @"
@SupportBot יש לי בעיה - המסמך לא נשמר למסד הנתונים אחרי validation
"@

$body = @{
    body = @{
        content = $issueMessage
    }
} | ConvertTo-Json -Depth 3

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body | Out-Null
Write-Host "✅ ISSUE question sent" -ForegroundColor Green
Write-Host "Expected: 5-6 sentences with sections (מה קורה, למה זה קורה, מה לעשות), numbered steps" -ForegroundColor Gray
Start-Sleep -Seconds 2

# TEST 3: LOG_PASTE Question
Write-Host ""
Write-Host "[3/4] Testing LOG_PASTE question..." -ForegroundColor Yellow
$logMessage = @"
@SupportBot קיבלתי את השגיאה הזאת:
System.NullReferenceException: Object reference not set to an instance of an object.
at WeSign.DocumentValidator.Validate(Document doc) in DocumentValidator.cs:line 45
"@

$body = @{
    body = @{
        content = $logMessage
    }
} | ConvertTo-Json -Depth 3

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body | Out-Null
Write-Host "✅ LOG_PASTE question sent" -ForegroundColor Green
Write-Host "Expected: 2-3 sentences only, ultra-concise diagnostic mode, exact file:line, immediate fix" -ForegroundColor Gray

# TEST 4: API_USAGE Question
Write-Host ""
Write-Host "[4/4] Testing API_USAGE question..." -ForegroundColor Yellow
$apiMessage = @"
@SupportBot איך יוצרים מסמך חדש דרך API?
"@

$body = @{
    body = @{
        content = $apiMessage
    }
} | ConvertTo-Json -Depth 3

$uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body | Out-Null
Write-Host "✅ API_USAGE question sent" -ForegroundColor Green
Write-Host "Expected: 5-6 sentences with endpoint, HTTP method, request/response format, curl example" -ForegroundColor Gray

Write-Host ""
Write-Host "=== ALL TESTS SENT ===" -ForegroundColor Cyan
Write-Host "Watch Teams channel for responses!" -ForegroundColor Yellow
Write-Host "Bot will respond in ~10 seconds (polling interval)" -ForegroundColor Gray
