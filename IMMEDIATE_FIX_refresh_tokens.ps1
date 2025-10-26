# IMMEDIATE FIX: Implement Custom OAuth Flow with Refresh Tokens
# This replaces @floriscornel/teams-mcp to support automatic token renewal

$CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft Graph Command Line Tools
$TENANT = "common"
$SCOPES = "Chat.Read Chat.ReadWrite User.Read offline_access"  # ← offline_access gives us refresh tokens!
$AUTH_FILE = "$PSScriptRoot\.msgraph-auth-with-refresh.json"

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Custom OAuth Flow with Refresh Token Support             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Get device code
Write-Host "[1/4] Requesting device code..." -ForegroundColor Yellow
$deviceCodeResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/devicecode" -Body @{
    client_id = $CLIENT_ID
    scope = $SCOPES
}

Write-Host "`n📱 Please complete authentication:" -ForegroundColor Green
Write-Host "🌐 Visit: $($deviceCodeResponse.verification_uri)" -ForegroundColor White
Write-Host "🔑 Enter code: $($deviceCodeResponse.user_code)`n" -ForegroundColor Cyan

# Step 2: Poll for token
Write-Host "[2/4] Waiting for authentication..." -ForegroundColor Yellow
$interval = $deviceCodeResponse.interval
$expires = $deviceCodeResponse.expires_in
$startTime = Get-Date

$tokenResponse = $null
while ($true) {
    Start-Sleep -Seconds $interval

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    if ($elapsed -gt $expires) {
        Write-Host "❌ Authentication timeout. Please try again." -ForegroundColor Red
        exit 1
    }

    try {
        $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/token" -Body @{
            client_id = $CLIENT_ID
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
            device_code = $deviceCodeResponse.device_code
        }
        break
    }
    catch {
        if ($_.Exception.Response.StatusCode -ne 400) {
            Write-Host "❌ Error: $_" -ForegroundColor Red
            exit 1
        }
        # 400 means still pending, continue polling
    }
}

Write-Host "✅ Authentication successful!" -ForegroundColor Green

# Step 3: Save tokens with refresh token
Write-Host "[3/4] Saving tokens with refresh token..." -ForegroundColor Yellow
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$authData = @{
    clientId = $CLIENT_ID
    authenticated = $true
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    expiresAt = (Get-Date).AddSeconds($tokenResponse.expires_in).ToUniversalTime().ToString("o")
    expires_in_seconds = $tokenResponse.expires_in
    token = $tokenResponse.access_token
    refresh_token = $tokenResponse.refresh_token  # ← THE KEY ADDITION!
    token_type = $tokenResponse.token_type
    scope = $tokenResponse.scope
}

$authData | ConvertTo-Json | Set-Content $AUTH_FILE
Write-Host "✅ Tokens saved to: $AUTH_FILE" -ForegroundColor Green

# Step 4: Update graph-api-helpers.ps1 to use new auth file
Write-Host "[4/4] Updating graph-api-helpers.ps1..." -ForegroundColor Yellow

$helpersFile = "$PSScriptRoot\graph-api-helpers.ps1"
$helpersBackup = "$PSScriptRoot\graph-api-helpers.ps1.backup"

# Backup original
Copy-Item $helpersFile $helpersBackup -Force

# Read current content
$content = Get-Content $helpersFile -Raw

# Replace auth file path
$content = $content -replace 'C:\\Users\\gals\\.msgraph-mcp-auth.json', $AUTH_FILE

# Add refresh token function if not exists
if ($content -notmatch 'function Refresh-GraphToken') {
    $refreshFunction = @'

# Refresh expired access token using refresh token
function Refresh-GraphToken {
    param([string]$RefreshToken)

    try {
        Write-Host "🔄 Refreshing expired token..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/common/oauth2/v2.0/token" -Body @{
            client_id = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
            grant_type = "refresh_token"
            refresh_token = $RefreshToken
            scope = "Chat.Read Chat.ReadWrite User.Read offline_access"
        }

        return $response
    }
    catch {
        Write-Host "❌ Token refresh failed: $_" -ForegroundColor Red
        throw
    }
}
'@
    $content = $content -replace '(# Get authentication token from auth file)', "$refreshFunction`n`n`$1"
}

# Update Get-GraphToken to check expiration and refresh
$newGetToken = @'
# Get authentication token from auth file
function Get-GraphToken {
    $authFile = "$PSScriptRoot\.msgraph-auth-with-refresh.json"

    if (-not (Test-Path $authFile)) {
        throw "Auth file not found at $authFile. Please run IMMEDIATE_FIX_refresh_tokens.ps1"
    }

    $authData = Get-Content $authFile | ConvertFrom-Json

    # Check if token is expired or will expire in next 5 minutes
    $now = Get-Date
    $expiresAt = [DateTime]::Parse($authData.expiresAt)
    $timeUntilExpiry = ($expiresAt - $now).TotalSeconds

    if ($timeUntilExpiry -lt 300) {  # Less than 5 minutes
        Write-Host "⚠️  Token expires in $([math]::Round($timeUntilExpiry/60, 1)) minutes, refreshing..." -ForegroundColor Yellow

        # Refresh the token
        $newTokens = Refresh-GraphToken -RefreshToken $authData.refresh_token

        # Update auth file
        $authData.token = $newTokens.access_token
        $authData.refresh_token = $newTokens.refresh_token
        $authData.expiresAt = (Get-Date).AddSeconds($newTokens.expires_in).ToUniversalTime().ToString("o")
        $authData.timestamp = (Get-Date).ToUniversalTime().ToString("o")

        $authData | ConvertTo-Json | Set-Content $authFile
        Write-Host "✅ Token refreshed successfully! New expiry: $($authData.expiresAt)" -ForegroundColor Green
    }

    return $authData.token
}
'@

# Replace the existing Get-GraphToken function
$content = $content -replace '(?s)(# Get authentication token from auth file\s+function Get-GraphToken \{.*?\n\})', $newGetToken

# Save updated content
$content | Set-Content $helpersFile -Force

Write-Host "✅ graph-api-helpers.ps1 updated!" -ForegroundColor Green
Write-Host "✅ Backup saved to: $helpersBackup" -ForegroundColor Gray

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ SETUP COMPLETE!                                         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "✨ Your bot now has automatic token renewal!" -ForegroundColor Green
Write-Host "📊 Current token expires: $($authData.expiresAt)" -ForegroundColor White
Write-Host "🔄 Will auto-refresh before: $(((Get-Date).AddSeconds($tokenResponse.expires_in - 300)).ToUniversalTime().ToString('o'))" -ForegroundColor White
Write-Host "`n🚀 Restart your orchestrator to use the new authentication:" -ForegroundColor Cyan
Write-Host "   powershell -ExecutionPolicy Bypass -File ./run-orchestrator.ps1`n" -ForegroundColor White
