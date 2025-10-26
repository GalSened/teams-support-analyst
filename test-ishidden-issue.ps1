# Test isHidden issue in document collection PUT API
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Testing Bot Analysis - isHidden Issue                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "[QUESTION] Sending technical question about isHidden issue..." -ForegroundColor Yellow
$msg = Send-TeamsChatMessage -ChatId $chatId -Message "@supportbot There's an issue with the isHidden field in the document collection PUT API. When I send a PUT request to update a document collection and include isHidden=true in the payload, the field is not being updated in the database. The API returns 200 OK but the isHidden value stays false. What could be causing this?"

Write-Host "✅ Question sent: ID $($msg.id)" -ForegroundColor Green
Write-Host "`n⏳ Waiting for bot to analyze the code and respond..." -ForegroundColor Yellow
Write-Host "   The bot will:" -ForegroundColor Gray
Write-Host "   1. Search the codebase for document collection PUT endpoints" -ForegroundColor Gray
Write-Host "   2. Find the isHidden field handling" -ForegroundColor Gray
Write-Host "   3. Identify the root cause" -ForegroundColor Gray
Write-Host "   4. Suggest a fix`n" -ForegroundColor Gray

Write-Host "Bot is processing... Check Teams for the response!" -ForegroundColor Green
Write-Host "Message ID: $($msg.id)" -ForegroundColor DarkGray
