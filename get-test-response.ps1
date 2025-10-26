. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$testMsgId = "1761457418932"

Write-Host "Fetching messages after test message $testMsgId..." -ForegroundColor Cyan

$messages = Get-TeamsChatMessages -ChatId $chatId -Top 5

foreach ($msg in $messages) {
    if ($msg.id -gt $testMsgId) {
        Write-Host "`n=== BOT RESPONSE (ID: $($msg.id)) ===" -ForegroundColor Green
        Write-Host $msg.body.content
        Write-Host "`n=== END ===" -ForegroundColor Green
    }
}
