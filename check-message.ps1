# Check latest messages
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"
$messages = Get-TeamsChatMessages -ChatId $chatId -Top 10

Write-Host "=== LAST 10 MESSAGES ===" -ForegroundColor Cyan
foreach ($msg in $messages) {
    $preview = $msg.body.content.Substring(0, [Math]::Min(80, $msg.body.content.Length))
    Write-Host "`n[$($msg.id)] From: $($msg.from.user.displayName)" -ForegroundColor Yellow
    Write-Host "Content: $preview..." -ForegroundColor White

    if ($msg.body.content -match '@') {
        Write-Host "  >>> Contains @ mention!" -ForegroundColor Green
    }
}
Write-Host "`n=== END ===" -ForegroundColor Cyan
