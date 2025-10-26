# Test Hebrew message
. "$PSScriptRoot\graph-api-helpers.ps1"

$chatId = "19:921ad475e9a34c0898c8f6dc01bb969b@thread.v2"

# Send Hebrew test message
$body = @{
    body = @{
        content = "@SupportBot מהי אסטרטגיית האבטחה המומלצת לאימות משתמשים?"
    }
} | ConvertTo-Json -Depth 3

try {
    $token = Get-GraphToken
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json; charset=utf-8"
    }

    $uri = "https://graph.microsoft.com/v1.0/chats/$chatId/messages"
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

    Write-Host "✓ Hebrew test message sent successfully!" -ForegroundColor Green
    Write-Host "Message ID: $($response.id)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
