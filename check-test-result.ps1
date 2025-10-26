# Check test result
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$messages = Get-TeamsChatMessages -ChatId $chatId -Top 10

Write-Host "=== RECENT MESSAGES SINCE TEST ===" -ForegroundColor Cyan
$messages | Where-Object { $_.id -ge 1761444000000 } | ForEach-Object {
    Write-Host ""
    Write-Host "ID: $($_.id)" -ForegroundColor Yellow
    Write-Host "From: $($_.from.user.displayName)" -ForegroundColor Green
    $preview = $_.body.content.Substring(0, [Math]::Min(200, $_.body.content.Length))
    Write-Host "Content: $preview" -ForegroundColor White
}
