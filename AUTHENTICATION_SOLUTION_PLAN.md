# 🔐 Long-Term Authentication Solution Plan
**Critical Issue**: Current tokens expire every 1-2 hours, requiring manual re-authentication

---

## 🎯 GOAL
Transform the Teams Support Bot from manual authentication to fully autonomous 24/7 operation with automatic token renewal.

---

## 📊 CURRENT PROBLEMS

### Problem 1: Short-Lived Access Tokens
- **Current**: Access tokens expire in 1-2 hours
- **Impact**: Bot stops working, requires manual re-authentication
- **Location**: `.msgraph-mcp-auth.json` stores only access token

### Problem 2: No Refresh Token Implementation
- **Current**: No automatic token refresh mechanism
- **Impact**: Bot becomes non-operational silently
- **Location**: `graph-api-helpers.ps1` doesn't handle token refresh

### Problem 3: No Expiration Detection
- **Current**: Bot receives 401 errors but doesn't auto-recover
- **Impact**: Failed API calls until manual intervention
- **Location**: No token expiration checking in orchestrator

---

## 🛠️ SOLUTION ARCHITECTURE

### Option A: **REFRESH TOKEN IMPLEMENTATION** (Recommended)
✅ **Pros**:
- User authentication once, then automatic renewal
- Works indefinitely (refresh tokens valid for 90 days, auto-renewed)
- No infrastructure changes needed
- Most secure for production

❌ **Cons**:
- Requires updating @floriscornel/teams-mcp to store refresh tokens
- Need to implement refresh token flow

**Implementation Steps**:

1. **Update Authentication Flow** (High Priority)
   ```powershell
   # File: graph-api-helpers.ps1
   # New function to handle OAuth2 refresh token flow

   function Refresh-GraphToken {
       param([string]$RefreshToken)

       $body = @{
           client_id = $CLIENT_ID
           refresh_token = $RefreshToken
           grant_type = "refresh_token"
           scope = "Chat.Read Chat.ReadWrite User.Read"
       }

       $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/common/oauth2/v2.0/token" `
           -Method Post -Body $body

       return $response
   }
   ```

2. **Token Storage Enhancement**
   ```json
   // .msgraph-mcp-auth.json (enhanced)
   {
       "token": "eyJ0eXAi...",
       "refresh_token": "0.AXoA...",
       "expires_at": 1730012400,
       "refresh_expires_at": 1737788400
   }
   ```

3. **Automatic Token Renewal**
   ```powershell
   # Add to graph-api-helpers.ps1

   function Get-GraphToken {
       $authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
       $authData = Get-Content $authFile | ConvertFrom-Json

       $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

       # Check if token expired (with 5-minute buffer)
       if ($now -ge ($authData.expires_at - 300)) {
           Write-Host "Token expired, refreshing..." -ForegroundColor Yellow
           $newTokens = Refresh-GraphToken -RefreshToken $authData.refresh_token

           $authData.token = $newTokens.access_token
           $authData.refresh_token = $newTokens.refresh_token
           $authData.expires_at = $now + $newTokens.expires_in

           $authData | ConvertTo-Json | Set-Content $authFile
           Write-Host "✅ Token refreshed successfully" -ForegroundColor Green
       }

       return $authData.token
   }
   ```

---

### Option B: **SERVICE PRINCIPAL / APP-ONLY AUTHENTICATION**
✅ **Pros**:
- No user interaction required ever
- True 24/7 autonomous operation
- Tokens last longer (can be configured)

❌ **Cons**:
- Requires Azure AD app registration
- Need admin consent for application permissions
- More complex initial setup

**Implementation Steps**:

1. **Create Azure AD App Registration**
   - Navigate to Azure Portal → Azure Active Directory → App registrations
   - New registration: "Teams-Support-Bot"
   - Permissions needed:
     - `Chat.Read.All` (Application permission)
     - `Chat.ReadWrite.All` (Application permission)
   - Generate client secret (valid for 2 years, renewable)

2. **Certificate-Based Authentication** (Most Secure)
   ```powershell
   # Generate self-signed certificate
   $cert = New-SelfSignedCertificate -Subject "CN=TeamsSupportBot" `
       -CertStoreLocation "Cert:\CurrentUser\My" `
       -KeyExportPolicy Exportable `
       -KeySpec Signature `
       -KeyLength 2048 `
       -KeyAlgorithm RSA `
       -HashAlgorithm SHA256 `
       -NotAfter (Get-Date).AddYears(2)

   # Export certificate
   Export-Certificate -Cert $cert -FilePath "C:\certs\TeamsBot.cer"

   # Upload to Azure AD App Registration → Certificates & secrets
   ```

3. **Service Principal Authentication Flow**
   ```powershell
   function Get-ServicePrincipalToken {
       $tenantId = "YOUR_TENANT_ID"
       $clientId = "YOUR_APP_CLIENT_ID"
       $clientSecret = "YOUR_CLIENT_SECRET"

       $body = @{
           grant_type = "client_credentials"
           client_id = $clientId
           client_secret = $clientSecret
           scope = "https://graph.microsoft.com/.default"
       }

       $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
           -Method Post -Body $body

       return $response.access_token
   }
   ```

---

### Option C: **MANAGED IDENTITY** (Azure VM/Container Only)
✅ **Pros**:
- No credentials stored anywhere
- Automatic Azure-managed authentication
- Zero maintenance

❌ **Cons**:
- Only works if bot runs on Azure VM/Container/Function
- Requires Azure infrastructure migration

---

## 📋 RECOMMENDED IMPLEMENTATION PLAN

### **PHASE 1: Quick Fix - Refresh Token Implementation** (1-2 hours)

**Priority: CRITICAL**

1. **Update @floriscornel/teams-mcp Package**
   ```bash
   # Check if refresh token is stored
   cat C:\Users\gals\.msgraph-mcp-auth.json
   ```

   If refresh_token missing:
   - Fork/modify @floriscornel/teams-mcp to save refresh tokens
   - OR manually extract refresh token from OAuth flow

2. **Implement Token Refresh in graph-api-helpers.ps1**
   ```powershell
   # Add token expiration checking
   # Add automatic refresh before each API call
   # Add retry logic with token refresh on 401 errors
   ```

3. **Add Token Monitoring**
   ```powershell
   # Add to orchestrator-v5.ps1
   function Check-TokenHealth {
       $authFile = "C:\Users\gals\.msgraph-mcp-auth.json"
       $authData = Get-Content $authFile | ConvertFrom-Json

       $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
       $timeUntilExpiry = $authData.expires_at - $now

       if ($timeUntilExpiry -lt 600) {  # Less than 10 minutes
           Write-Log "⚠️ Token expires in $([math]::Round($timeUntilExpiry/60, 1)) minutes"
       }
   }
   ```

4. **Test Refresh Flow**
   - Force token expiration
   - Verify automatic refresh
   - Confirm 24+ hour operation

**Files to Modify**:
- `graph-api-helpers.ps1`: Add `Refresh-GraphToken` and update `Get-GraphToken`
- `orchestrator-v5.ps1`: Add token health monitoring
- `.msgraph-mcp-auth.json`: Ensure refresh_token is stored

---

### **PHASE 2: Service Principal Migration** (4-6 hours)

**Priority: HIGH (for production)**

1. **Azure AD Setup** (30 minutes)
   - Create app registration
   - Configure application permissions
   - Get admin consent
   - Generate client secret or certificate

2. **Update Authentication** (2 hours)
   - Create `service-principal-auth.ps1`
   - Implement certificate-based auth
   - Update all Graph API calls
   - Test with service principal

3. **Security Hardening** (1 hour)
   - Store secrets in Windows Credential Manager
   - Implement secret rotation
   - Add audit logging

4. **Deployment** (1 hour)
   - Switch orchestrator to service principal
   - Monitor for 24 hours
   - Document runbook

---

### **PHASE 3: Error Handling & Monitoring** (2-3 hours)

**Priority: MEDIUM**

1. **Robust Error Handling**
   ```powershell
   function Invoke-GraphAPIWithRetry {
       param($Uri, $Method, $Headers, $Body, $MaxRetries = 3)

       for ($i = 1; $i -le $MaxRetries; $i++) {
           try {
               return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body
           }
           catch {
               if ($_.Exception.Response.StatusCode -eq 401) {
                   Write-Log "Token expired, refreshing (attempt $i/$MaxRetries)..."
                   $headers["Authorization"] = "Bearer $(Get-GraphToken -ForceRefresh)"
               }
               elseif ($i -eq $MaxRetries) {
                   throw
               }
               else {
                   Start-Sleep -Seconds ([math]::Pow(2, $i))
               }
           }
       }
   }
   ```

2. **Health Monitoring**
   - Token expiration alerts
   - API call success rate tracking
   - Automatic alerting on failures

3. **Logging Enhancement**
   - Token refresh events
   - Authentication failures
   - API rate limiting detection

---

## 🎯 IMMEDIATE NEXT STEPS

### Step 1: Check Current Token Structure
```powershell
# Examine what's currently stored
Get-Content C:\Users\gals\.msgraph-mcp-auth.json | ConvertFrom-Json | Format-List
```

### Step 2: Test Token Refresh Manually
```powershell
# Try manual refresh to verify it works
# This will tell us if refresh tokens are available
```

### Step 3: Implement Automatic Refresh
```powershell
# Update graph-api-helpers.ps1 with refresh logic
# This is the HIGHEST PRIORITY fix
```

---

## 🔒 SECURITY CONSIDERATIONS

### Current Implementation
- ✅ OAuth2 device code flow (secure)
- ✅ Tokens stored locally
- ❌ No token encryption
- ❌ No secret rotation

### Recommended Security Enhancements
1. **Encrypt Token Storage**
   ```powershell
   # Use DPAPI to encrypt auth file
   $secureString = ConvertTo-SecureString $jsonContent -AsPlainText -Force
   $encrypted = ConvertFrom-SecureString $secureString
   $encrypted | Set-Content $authFile
   ```

2. **Windows Credential Manager Integration**
   ```powershell
   # Store refresh token in Windows Credential Manager
   cmdkey /generic:TeamsBotRefreshToken /user:bot /pass:$refreshToken
   ```

3. **Certificate-Based Auth** (Service Principal)
   - No secrets in configuration files
   - Certificate in Windows Certificate Store
   - Auto-rotation support

---

## 📊 SUCCESS METRICS

### Before Implementation
- ⏱️ Token lifetime: 1-2 hours
- 🔄 Manual re-auth required: Every 1-2 hours
- 🚫 Downtime: Frequent (every auth cycle)
- ⚙️ Automation level: 0% (manual intervention required)

### After Phase 1 (Refresh Tokens)
- ⏱️ Token lifetime: 90 days (auto-renewed)
- 🔄 Manual re-auth required: Every 90 days (or never with rotation)
- 🚫 Downtime: None (auto-recovery)
- ⚙️ Automation level: 95%

### After Phase 2 (Service Principal)
- ⏱️ Token lifetime: Indefinite
- 🔄 Manual re-auth required: Never
- 🚫 Downtime: None
- ⚙️ Automation level: 100%

---

## 🚀 QUICK START GUIDE

**To implement refresh tokens RIGHT NOW:**

1. **Check if refresh token exists**:
   ```powershell
   $auth = Get-Content C:\Users\gals\.msgraph-mcp-auth.json | ConvertFrom-Json
   if ($auth.refresh_token) {
       Write-Host "✅ Refresh token available!"
   } else {
       Write-Host "❌ Need to re-authenticate with refresh token support"
   }
   ```

2. **If available, implement refresh logic immediately**

3. **If not available, research @floriscornel/teams-mcp internals or switch to custom OAuth flow**

---

## 📞 SUPPORT & RESOURCES

### Microsoft Graph OAuth2 Documentation
- https://learn.microsoft.com/en-us/graph/auth-v2-user
- https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow

### Service Principal Setup
- https://learn.microsoft.com/en-us/graph/auth-v2-service

### PowerShell OAuth Examples
- https://github.com/microsoft/teams-powershell-samples

---

**Next Action**: Investigate current auth file structure and implement refresh token logic ASAP to achieve 24/7 autonomous operation.
