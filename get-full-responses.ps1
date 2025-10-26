# Get full bot responses
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$messages = Get-TeamsChatMessages -ChatId $chatId -Top 5

Write-Host "=== FULL BOT RESPONSES ===" -ForegroundColor Cyan
$messages | Where-Object { $_.id -ge 1761444156347 } | ForEach-Object {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Yellow
    Write-Host "Message ID: $($_.id)" -ForegroundColor Green
    Write-Host "Content:" -ForegroundColor Green
    Write-Host $_.body.content -ForegroundColor White
}
