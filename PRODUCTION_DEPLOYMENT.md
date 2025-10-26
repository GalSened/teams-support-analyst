# Production Deployment Guide

Complete guide for deploying Teams Support Analyst to production.

---

## 📋 Pre-Deployment Checklist

### Requirements Validation

- [ ] Windows Server 2019+ or Windows 10/11 Pro
- [ ] Node.js 18.x or higher installed
- [ ] PowerShell 5.1 or higher
- [ ] ripgrep installed and in PATH
- [ ] 4GB+ RAM available
- [ ] 10GB+ disk space
- [ ] Network access to Teams, Claude API
- [ ] Admin rights for service installation

### Access & Credentials

- [ ] Microsoft Teams tenant admin access
- [ ] Azure AD application registration
- [ ] Claude API key (Anthropic)
- [ ] Repository access (read-only recommended)
- [ ] Firewall rules for localhost services

---

## 🚀 Step-by-Step Deployment

### Phase 1: System Preparation

#### 1.1 Install Prerequisites

**Node.js**:
```powershell
# Download and install Node.js 18.x LTS
winget install OpenJS.NodeJS.LTS

# Verify installation
node --version  # Should be v18.x.x
npm --version   # Should be 9.x.x or higher
```

**ripgrep**:
```powershell
# Using Chocolatey
choco install ripgrep

# Or download from https://github.com/BurntSushi/ripgrep/releases
# Extract rg.exe to C:\Program Files\ripgrep\
# Add to PATH

# Verify
rg --version
```

#### 1.2 Create Service Account

```powershell
# Create dedicated user for the service
New-LocalUser -Name "TeamsAnalystSvc" -Description "Teams Support Analyst Service Account" -NoPassword

# Grant "Log on as a service" right
# Open: secpol.msc → Local Policies → User Rights Assignment
# Add TeamsAnalystSvc to "Log on as a service"

# Grant read access to repositories
icacls "C:\Repositories" /grant "TeamsAnalystSvc:(OI)(CI)R" /T
```

---

### Phase 2: Application Deployment

#### 2.1 Clone Repository

```powershell
# Create application directory
New-Item -ItemType Directory -Path "C:\TeamsSupportAnalyst" -Force

# Clone or copy files
cd C:\TeamsSupportAnalyst
git clone <your-repo-url> .

# Or copy from development machine
```

#### 2.2 Install Dependencies

```powershell
# LocalSearch API
cd C:\TeamsSupportAnalyst\local-search-api
npm install
npm run build

# Verify build
Test-Path ".\dist\server.js"  # Should return True
```

#### 2.3 Configure Environment

```powershell
# Create production .env
Copy-Item .env.example .env

# Edit .env with production values
notepad .env
```

**Production `.env` template**:
```env
# ==========================================
# PRODUCTION CONFIGURATION
# ==========================================

# Repository Paths (READ-ONLY recommended)
REPO_ROOTS=D:/Repositories/backend;D:/Repositories/frontend;D:/Repositories/signer

# LocalSearch API
LOCALSEARCH_PORT=3001
MAX_SEARCH_RESULTS=30
MAX_FILE_LINES=200

# Teams Configuration
TEAMS_CHAT_ID=<your-chat-id>
TEAMS_CHANNEL_NAME=support-bot
BOT_NAME=SupportBot

# Security
API_KEY=<generate-strong-random-key>

# Performance
MAX_ATTEMPTS=2
CONFIDENCE_THRESHOLD=0.75
STABLE_HASH_COUNT=2

# Logging
LOG_LEVEL=info
LOG_FILE=C:\TeamsSupportAnalyst\logs\orchestrator.log
```

**Generate API key**:
```powershell
# Generate secure random key
$apiKey = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
Write-Host "API_KEY=$apiKey"
```

---

### Phase 3: Service Installation

#### 3.1 Install LocalSearch API as Service

**Using NSSM (Non-Sucking Service Manager)**:
```powershell
# Download NSSM
choco install nssm

# Install service
nssm install LocalSearchAPI "C:\Program Files\nodejs\node.exe" "C:\TeamsSupportAnalyst\local-search-api\dist\server.js"

# Configure service
nssm set LocalSearchAPI AppDirectory "C:\TeamsSupportAnalyst\local-search-api"
nssm set LocalSearchAPI AppEnvironmentExtra "REPO_ROOTS=D:/Repositories/backend;D:/Repositories/frontend" "LOCALSEARCH_PORT=3001"
nssm set LocalSearchAPI DisplayName "LocalSearch API for Teams Analyst"
nssm set LocalSearchAPI Description "Code search API for Teams Support Analyst"
nssm set LocalSearchAPI Start SERVICE_AUTO_START
nssm set LocalSearchAPI AppStdout "C:\TeamsSupportAnalyst\logs\localsearch.log"
nssm set LocalSearchAPI AppStderr "C:\TeamsSupportAnalyst\logs\localsearch-error.log"
nssm set LocalSearchAPI AppRotateFiles 1
nssm set LocalSearchAPI AppRotateBytes 10485760  # 10MB

# Start service
Start-Service LocalSearchAPI

# Verify
Get-Service LocalSearchAPI
Test-NetConnection -ComputerName localhost -Port 3001
```

#### 3.2 Install Orchestrator as Service

```powershell
# Install orchestrator service
nssm install TeamsOrchestrator "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-ExecutionPolicy Bypass -File C:\TeamsSupportAnalyst\orchestrator-v5.ps1"

# Configure
nssm set TeamsOrchestrator AppDirectory "C:\TeamsSupportAnalyst"
nssm set TeamsOrchestrator DisplayName "Teams Support Analyst Orchestrator"
nssm set TeamsOrchestrator Description "Monitors Teams and responds with AI analysis"
nssm set TeamsOrchestrator Start SERVICE_AUTO_START
nssm set TeamsOrchestrator AppStdout "C:\TeamsSupportAnalyst\logs\orchestrator.log"
nssm set TeamsOrchestrator AppStderr "C:\TeamsSupportAnalyst\logs\orchestrator-error.log"
nssm set TeamsOrchestrator AppRotateFiles 1

# Start service
Start-Service TeamsOrchestrator

# Verify
Get-Service TeamsOrchestrator
```

---

### Phase 4: Monitoring & Alerting

#### 4.1 Configure Windows Event Log

```powershell
# Create custom event log
New-EventLog -LogName "Teams Support Analyst" -Source "Orchestrator","LocalSearchAPI"

# Test logging
Write-EventLog -LogName "Teams Support Analyst" -Source "Orchestrator" -EntryType Information -EventId 1000 -Message "Service started successfully"
```

#### 4.2 Setup Health Checks

**Create health check script** (`C:\TeamsSupportAnalyst\health-check.ps1`):
```powershell
param([string]$AlertEmail = "admin@company.com")

# Check LocalSearch API
$apiHealth = $false
try {
    $response = Invoke-RestMethod -Uri "http://localhost:3001/health" -TimeoutSec 10
    $apiHealth = ($response.status -eq "ok")
} catch {
    Write-EventLog -LogName "Teams Support Analyst" -Source "LocalSearchAPI" -EntryType Error -EventId 2001 -Message "API health check failed: $_"
}

# Check Orchestrator
$orchestratorRunning = (Get-Service TeamsOrchestrator).Status -eq "Running"

# Send alert if unhealthy
if (-not $apiHealth -or -not $orchestratorRunning) {
    $body = "Teams Support Analyst Health Alert:`n`nAPI Health: $apiHealth`nOrchestrator Running: $orchestratorRunning"
    # Send-MailMessage -To $AlertEmail -Subject "Alert: Teams Analyst Unhealthy" -Body $body
    Write-EventLog -LogName "Teams Support Analyst" -Source "Orchestrator" -EntryType Warning -EventId 3001 -Message $body
}
```

**Schedule health checks**:
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\TeamsSupportAnalyst\health-check.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "TeamsAnalystHealthCheck" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest
```

#### 4.3 Log Rotation

```powershell
# Create log rotation script
$script = @'
$logDir = "C:\TeamsSupportAnalyst\logs"
$maxAge = 30  # days
$maxSize = 100MB

Get-ChildItem $logDir -Filter "*.log" | Where-Object {
    ($_.LastWriteTime -lt (Get-Date).AddDays(-$maxAge)) -or ($_.Length -gt $maxSize)
} | ForEach-Object {
    $archived = "$($_.FullName).$(Get-Date -Format 'yyyyMMdd').old"
    Move-Item $_.FullName $archived
    Compress-Archive $archived "$archived.zip"
    Remove-Item $archived
}
'@

Set-Content "C:\TeamsSupportAnalyst\rotate-logs.ps1" $script

# Schedule daily
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\TeamsSupportAnalyst\rotate-logs.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
Register-ScheduledTask -TaskName "TeamsAnalystLogRotation" -Action $action -Trigger $trigger
```

---

### Phase 5: Security Hardening

#### 5.1 Filesystem Permissions

```powershell
# Application directory - read-only for service account
icacls "C:\TeamsSupportAnalyst" /grant "TeamsAnalystSvc:(OI)(CI)R" /T

# Logs directory - write access
icacls "C:\TeamsSupportAnalyst\logs" /grant "TeamsAnalystSvc:(OI)(CI)M" /T

# State directory - write access
icacls "C:\TeamsSupportAnalyst\state" /grant "TeamsAnalystSvc:(OI)(CI)M" /T

# Environment file - read-only, restricted
icacls "C:\TeamsSupportAnalyst\.env" /grant "TeamsAnalystSvc:R" /inheritance:r
icacls "C:\TeamsSupportAnalyst\.env" /remove "Users" "Everyone"
```

#### 5.2 Firewall Rules

```powershell
# Allow localhost only (default - no external access)
# If remote access needed:
New-NetFirewallRule -DisplayName "LocalSearch API" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow -RemoteAddress <allowed-ips>
```

#### 5.3 Credential Management

**Store secrets in Windows Credential Manager**:
```powershell
# Install CredentialManager module
Install-Module -Name CredentialManager -Scope CurrentUser

# Store Claude API key
New-StoredCredential -Target "TeamsAnalyst-ClaudeAPI" -Username "api" -Password "<your-api-key>" -Type Generic -Persist LocalMachine

# Retrieve in script
$cred = Get-StoredCredential -Target "TeamsAnalyst-ClaudeAPI"
$env:CLAUDE_API_KEY = $cred.GetNetworkCredential().Password
```

---

### Phase 6: Backup & Recovery

#### 6.1 Backup Strategy

**What to backup**:
- Configuration files (`.env`, `orchestrator-v5.ps1`)
- State files (`state/*.json`, `state/*.txt`)
- Logs (last 30 days)
- Application code (if customized)

**Backup script**:
```powershell
$backupDir = "D:\Backups\TeamsAnalyst\$(Get-Date -Format 'yyyyMMdd')"
New-Item -ItemType Directory -Path $backupDir -Force

# Backup config
Copy-Item "C:\TeamsSupportAnalyst\.env" $backupDir
Copy-Item "C:\TeamsSupportAnalyst\orchestrator-v5.ps1" $backupDir

# Backup state
Copy-Item "C:\TeamsSupportAnalyst\state\*" $backupDir\state\ -Recurse

# Backup recent logs
Get-ChildItem "C:\TeamsSupportAnalyst\logs" -Filter "*.log" |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) } |
    Copy-Item -Destination $backupDir\logs\

# Compress
Compress-Archive "$backupDir\*" "$backupDir.zip"
Remove-Item $backupDir -Recurse
```

#### 6.2 Disaster Recovery Plan

**Recovery Time Objective (RTO)**: 1 hour
**Recovery Point Objective (RPO)**: 24 hours

**Recovery steps**:
1. Restore from latest backup
2. Reinstall dependencies (Node.js, ripgrep)
3. Reinstall services
4. Verify configuration
5. Start services
6. Run health checks

---

## 📊 Operational Procedures

### Daily Operations

**Morning Checklist**:
```powershell
# Run daily check script
.\daily-check.ps1
```

**`daily-check.ps1`**:
```powershell
Write-Host "=== Daily Operations Check ===" -ForegroundColor Cyan

# 1. Check services
Write-Host "`n1. Service Status:" -ForegroundColor Yellow
Get-Service LocalSearchAPI, TeamsOrchestrator | Format-Table -AutoSize

# 2. API health
Write-Host "`n2. API Health:" -ForegroundColor Yellow
Invoke-RestMethod -Uri "http://localhost:3001/health"

# 3. Recent errors
Write-Host "`n3. Recent Errors (last 24 hours):" -ForegroundColor Yellow
Get-EventLog -LogName "Teams Support Analyst" -After (Get-Date).AddDays(-1) -EntryType Error | Format-Table -AutoSize

# 4. Disk space
Write-Host "`n4. Disk Space:" -ForegroundColor Yellow
Get-PSDrive C | Select-Object @{N="Free (GB)";E={[math]::Round($_.Free/1GB,2)}}, @{N="Used (GB)";E={[math]::Round($_.Used/1GB,2)}}

Write-Host "`nDaily check complete!" -ForegroundColor Green
```

### Maintenance Windows

**Monthly tasks**:
- Update dependencies: `npm update`
- Review security logs
- Rotate API keys (if policy requires)
- Test backup restoration
- Review and archive old logs

**Quarterly tasks**:
- Performance review
- Capacity planning
- Security audit
- Disaster recovery drill

---

## 🔧 Troubleshooting

### Common Issues

#### Issue: API Not Starting
**Symptoms**: Service starts then stops
**Diagnosis**:
```powershell
# Check event log
Get-EventLog -LogName "Application" -Source "Node.js" -Newest 10

# Check error log
Get-Content "C:\TeamsSupportAnalyst\logs\localsearch-error.log" -Tail 50
```
**Solutions**:
- Verify Node.js is installed and in PATH
- Check `.env` file has REPO_ROOTS set
- Ensure repositories are accessible
- Verify port 3001 is not in use

#### Issue: Orchestrator Not Responding to Messages
**Symptoms**: Messages in Teams but no response
**Diagnosis**:
```powershell
# Check service
Get-Service TeamsOrchestrator

# Check recent activity
Get-Content "C:\TeamsSupportAnalyst\logs\orchestrator.log" -Tail 100 | Select-String "mention"
```
**Solutions**:
- Verify bot is @mentioned in message
- Check Teams authentication is valid
- Ensure Claude CLI is accessible
- Review confidence threshold settings

#### Issue: High Memory Usage
**Symptoms**: System slow, services consuming >2GB RAM
**Diagnosis**:
```powershell
# Check process memory
Get-Process node, powershell | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | Format-Table Name, @{N="Memory (MB)";E={[math]::Round($_.WorkingSet64/1MB,2)}}
```
**Solutions**:
- Restart services during maintenance window
- Review MAX_SEARCH_RESULTS setting (reduce if high)
- Check for memory leaks in logs
- Consider increasing system RAM

---

## 📈 Performance Tuning

### Optimization Settings

**For high-traffic environments**:
```env
# Reduce max attempts for faster responses
MAX_ATTEMPTS=2

# Lower confidence threshold
CONFIDENCE_THRESHOLD=0.7

# Limit search results
MAX_SEARCH_RESULTS=20

# Increase polling interval to reduce load
POLL_INTERVAL=15
```

**For low-traffic environments**:
```env
# Higher quality responses
MAX_ATTEMPTS=4
CONFIDENCE_THRESHOLD=0.9
MAX_SEARCH_RESULTS=50
POLL_INTERVAL=5
```

### Capacity Planning

**Estimated resources per concurrent user**:
- CPU: 5-10% per query
- RAM: 100-200MB per concurrent query
- Disk: 100MB logs per day
- Network: Negligible (local API)

**Scaling recommendations**:
- 1-10 users: Single instance (current setup)
- 10-50 users: Add API rate limiting
- 50+ users: Consider load balancer + multiple API instances

---

## ✅ Production Readiness Checklist

### Pre-Go-Live

- [ ] All services installed and running
- [ ] Health checks passing
- [ ] Backups configured and tested
- [ ] Monitoring and alerting active
- [ ] Security hardening complete
- [ ] Documentation reviewed
- [ ] Team training completed
- [ ] Incident response plan documented
- [ ] Rollback procedure tested

### Go-Live

- [ ] Announce to users
- [ ] Monitor closely for 24 hours
- [ ] Review initial usage patterns
- [ ] Collect user feedback
- [ ] Document any issues

### Post-Go-Live (Week 1)

- [ ] Daily health checks
- [ ] Review performance metrics
- [ ] Address user feedback
- [ ] Tune configuration as needed
- [ ] Document lessons learned

---

## 📞 Support Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| Primary Admin | Your Name | your.email@company.com |
| Backup Admin | Backup Name | backup@company.com |
| Security Contact | Security Team | security@company.com |
| Vendor Support (Anthropic) | - | support@anthropic.com |

---

## 📚 Additional Resources

- [System Architecture](./README.md)
- [Security Guidelines](./SECURITY.md)
- [Known Issues](./KNOWN_ISSUES.md)
- [Quick Start Guide](./QUICK_START.md)
- [Changelog](./CHANGELOG-v6.md)

---

**Document Version**: 1.0
**Last Updated**: October 25, 2025
**Next Review**: December 1, 2025
**Maintained By**: DevOps Team
