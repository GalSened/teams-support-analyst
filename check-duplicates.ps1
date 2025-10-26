# Check for duplicate responses
. "$PSScriptRoot\graph-api-helpers.ps1"

$messages = Get-TeamsChatMessages -ChatId '19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2' -Top 10

Write-Host "=== Last 10 Messages (checking for duplicates) ===" -ForegroundColor Cyan

$messages | ForEach-Object {
    $preview = $_.body.content
    if ($preview.Length -gt 100) {
        $preview = $preview.Substring(0, 100) + "..."
    }

    Write-Host "`n---" -ForegroundColor Yellow
    Write-Host "ID: $($_.id)" -ForegroundColor Magenta
    Write-Host "From: $($_.from.user.displayName)" -ForegroundColor Green
    Write-Host "Time: $($_.createdDateTime)" -ForegroundColor Gray
    Write-Host "Preview: $preview" -ForegroundColor White
}
