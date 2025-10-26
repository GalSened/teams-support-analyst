# Send test messages to Teams
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

Write-Host "=== Sending English Test ===" -ForegroundColor Cyan
$msg1 = Send-TeamsChatMessage -ChatId $chatId -Message "@SupportBot How do I delete a document?"
Write-Host "✅ English message sent: ID $($msg1.id)" -ForegroundColor Green
Write-Host "Waiting 35 seconds for bot to process and respond..." -ForegroundColor Yellow

Start-Sleep -Seconds 35

Write-Host "`n=== Sending Hebrew Test ===" -ForegroundColor Cyan
$msg2 = Send-TeamsChatMessage -ChatId $chatId -Message "@supportbot איך מוחקים מסמך?"
Write-Host "✅ Hebrew message sent: ID $($msg2.id)" -ForegroundColor Green
Write-Host "`nDone! Check Teams for bot responses." -ForegroundColor Green
