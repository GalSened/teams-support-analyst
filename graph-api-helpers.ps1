# Microsoft Graph API Helper Functions for Teams

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

# Get messages from a Teams chat
function Get-TeamsChatMessages {
    param(
        [string]$ChatId,
        [int]$Top = 5
    )

    try {
        $token = Get-GraphToken
        $headers = @{
            "Authorization" = "Bearer $token"
            "Accept-Charset" = "utf-8"
        }

        $uri = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages?`$top=$Top`&`$orderby=createdDateTime desc"

        # Force UTF-8 encoding for Hebrew and Unicode support
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ContentType "application/json; charset=utf-8"
        return $response.value
    } catch {
        Write-Error "Failed to get chat messages: $_"
        return $null
    }
}

# Get current user ID (to identify bot's own messages)
function Get-CurrentUserId {
    try {
        $token = Get-GraphToken
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }

        $uri = "https://graph.microsoft.com/v1.0/me"

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        return $response.id
    } catch {
        Write-Error "Failed to get current user ID: $_"
        return $null
    }
}

# Send message to Teams chat
function Send-TeamsChatMessage {
    param(
        [string]$ChatId,
        [string]$Message,
        [string]$ReplyToId = $null
    )

    try {
        $token = Get-GraphToken
        $headers = @{
            "Authorization" = "Bearer $token"
            "Accept-Charset" = "utf-8"
        }

        $body = @{
            body = @{
                content = $Message
            }
        }

        # If replying to a message, add replyToId
        if ($ReplyToId) {
            $body.replyToId = $ReplyToId
        }

        $bodyJson = $body | ConvertTo-Json -Depth 3

        $uri = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages"

        # Force UTF-8 encoding for Hebrew and Unicode support
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($bodyJson)) -ContentType "application/json; charset=utf-8"
        return $response
    } catch {
        Write-Error "Failed to send chat message: $_"
        return $null
    }
}

# Add a reaction to a Teams message
function Add-MessageReaction {
    param(
        [string]$ChatId,
        [string]$MessageId,
        [string]$ReactionType = "like"  # like, heart, laugh, surprised, sad, angry
    )

    try {
        $token = Get-GraphToken
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }

        $uri = "https://graph.microsoft.com/v1.0/chats/$ChatId/messages/$MessageId/reactions"

        # Send POST request to add reaction
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body "{`"reactionType`": `"$ReactionType`"}"
        return $response
    } catch {
        Write-Error "Failed to add reaction: $_"
        return $null
    }
}
