. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$messageId = "1761454770454"

Write-Host "Fetching message $messageId..." -ForegroundColor Cyan

$messages = Get-TeamsChatMessages -ChatId $chatId -Top 15

$msg = $messages | Where-Object { $_.id -eq $messageId }

if ($msg) {
    Write-Host "`n=== MESSAGE $messageId ===" -ForegroundColor Green
    Write-Host $msg.body.content
    Write-Host "`n=== END ===" -ForegroundColor Green
} else {
    Write-Host "Message not found" -ForegroundColor Red
}
