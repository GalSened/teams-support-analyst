# Send new Hebrew test with UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

Write-Host "=== Sending Final Hebrew Test ===" -ForegroundColor Cyan
$msg = Send-TeamsChatMessage -ChatId $chatId -Message "@supportbot שלום, איך אני יכול לעדכן טלפון?"
Write-Host "✅ Hebrew test sent: ID $($msg.id)" -ForegroundColor Green
Write-Host "Hebrew message: שלום, איך אני יכול לעדכן טלפון?" -ForegroundColor Yellow
Write-Host "(Translation: Hello, how can I update my phone?)" -ForegroundColor Gray
