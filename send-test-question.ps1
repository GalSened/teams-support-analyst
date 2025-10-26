# Send test question to Teams to verify codebase access

# Import Graph API helpers
. "$PSScriptRoot\graph-api-helpers.ps1"

# Chat ID for the support group chat
$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Send a technical question to test codebase access
$testMessage = '@SupportBot There is an issue with the isHidden field in the document collection PUT API. When I send a PUT request to update a document collection, the isHidden field is not being updated. Can you check the code and tell me what might be wrong?'

Write-Host "📤 Sending test question to Teams chat..." -ForegroundColor Cyan
$result = Send-TeamsChatMessage -ChatId $chatId -Message $testMessage

if ($result) {
    Write-Host "✅ Test message sent successfully!" -ForegroundColor Green
    Write-Host "Message ID: $($result.id)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⏳ Waiting 30 seconds for bot to process and respond..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30

    # Check for bot response
    Write-Host ""
    Write-Host "📥 Checking for bot response..." -ForegroundColor Cyan
    $messages = Get-TeamsChatMessages -ChatId $chatId -Top 5

    $botResponses = $messages | Where-Object {
        $_.from.user.displayName -eq 'Gal Sitton' -and
        $_.createdDateTime -gt $result.createdDateTime
    }

    if ($botResponses) {
        Write-Host "✅ Bot responded! Response preview:" -ForegroundColor Green
        $botResponses | ForEach-Object {
            $preview = $_.body.content.Substring(0, [Math]::Min(200, $_.body.content.Length))
            Write-Host $preview -ForegroundColor White
        }
    } else {
        Write-Host "⏳ No response yet. Bot may still be processing..." -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Failed to send test message" -ForegroundColor Red
}
