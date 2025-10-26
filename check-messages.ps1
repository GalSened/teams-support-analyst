# Check recent messages
. "$PSScriptRoot\graph-api-helpers.ps1"

$messages = Get-TeamsChatMessages -ChatId '19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2' -Top 5

Write-Host "=== Last 5 Messages ===" -ForegroundColor Cyan
$messages | ForEach-Object {
    Write-Host "`n---" -ForegroundColor Yellow
    Write-Host "From: $($_.from.user.displayName)" -ForegroundColor Green
    Write-Host "Time: $($_.createdDateTime)" -ForegroundColor Gray
    Write-Host "Content Preview:" -ForegroundColor Cyan
    $content = $_.body.content
    if ($content.Length -gt 300) {
        Write-Host $content.Substring(0, 300) + "..."
    } else {
        Write-Host $content
    }
}
