# Send codebase access test message

. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Send test message about a technical issue
$testMessage = '@SupportBot In the user-backend repository, there is a DocumentCollection entity. Can you find the file that defines this entity and tell me what fields it has? Please search the actual codebase.'

Write-Host "📤 Sending codebase access test to Teams..." -ForegroundColor Cyan
Write-Host "Question: $testMessage" -ForegroundColor Yellow
Write-Host ""

$result = Send-TeamsChatMessage -ChatId $chatId -Message $testMessage

if ($result) {
    Write-Host "✅ Test message sent successfully!" -ForegroundColor Green
    Write-Host "Message ID: $($result.id)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⏳ Bot should now:" -ForegroundColor Cyan
    Write-Host "  1. Detect the @mention" -ForegroundColor White
    Write-Host "  2. Use search_code MCP tool to search for 'DocumentCollection'" -ForegroundColor White
    Write-Host "  3. Use get_file_content MCP tool to read the entity file" -ForegroundColor White
    Write-Host "  4. Provide detailed response with file path and field list" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 Wait 30-60 seconds, then run ./check-test-result.ps1 to see the response" -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to send test message" -ForegroundColor Red
}
