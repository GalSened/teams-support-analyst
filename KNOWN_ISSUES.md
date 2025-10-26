# Known Issues and Workarounds

## Issue #1: Windows Reserved Filename "nul" in user-backend Repository

**Problem**: The user-backend repository contains a file named "nul" which is a Windows reserved filename (like CON, PRN, AUX, etc.). This causes ripgrep to fail with error:
```
rg: C:/Users/gals/source/repos/user-backend\nul: Incorrect function. (os error 1)
```

**Impact**:
- Search errors in user-backend repository
- Reduced search results from that repository
- No impact on other repositories (wesign-client-DEV, wesignsigner-client-app-DEV)

**Root Cause**:
The file `C:/Users/gals/source/repos/user-backend/nul` (0 bytes, created Oct 23 16:00) is a Windows reserved device name. Windows treats NUL as the null device (like /dev/null in Unix), making it impossible for applications to reliably access files with this name.

**Workarounds**:

### Option 1: Rename or Delete the File (Recommended)
```bash
# Navigate to the repository
cd C:/Users/gals/source/repos/user-backend

# Remove the problematic file (if it's safe to delete)
git rm nul
git commit -m "Remove Windows reserved filename 'nul'"
```

### Option 2: Add to .gitignore
```bash
# Add to .gitignore to prevent future issues
echo "nul" >> .gitignore
git commit -m "Ignore Windows reserved filename"
```

### Option 3: Update ripgrep Command (Already Implemented in Code)
Add glob patterns to exclude Windows reserved filenames:
```typescript
const command = `${rgCommand} --glob "!nul" --glob "!con" --glob "!prn" --glob "!aux" --glob "!com[1-9]" --glob "!lpt[1-9]" ...`;
```

**Status**: Workaround option 1 or 2 recommended for permanent fix.

---

## Issue #2: File Endpoint JSON Escaping with Windows Paths

**Problem**: When testing file endpoints with curl, Windows paths with backslashes cause JSON parsing errors:
```
Bad escaped character in JSON at position 49
```

**Impact**:
- File info and file read endpoints fail when called with curl
- Only affects manual testing with curl, not the actual API functionality

**Root Cause**:
Windows paths use backslashes (`C:\path\to\file`) which are escape characters in JSON. When passed in curl command line, they need to be double-escaped.

**Workaround**:
Use forward slashes in paths when testing with curl:
```bash
# ✗ Incorrect (will fail)
curl -X POST http://localhost:3001/file-info -d '{"path":"C:\Users\file.txt"}'

# ✓ Correct (use forward slashes)
curl -X POST http://localhost:3001/file-info -d '{"path":"C:/Users/file.txt"}'
```

**Status**: This is a testing-only issue. The PowerShell test suite handles this correctly.

---

## Issue #3: LocalSearch API Requires REPO_ROOTS Environment Variable

**Problem**: Running `npm start` directly in local-search-api fails with:
```
ERROR: REPO_ROOTS environment variable is not set or empty
```

**Impact**:
- API won't start without environment configuration
- Manual startup requires setting environment variables

**Solution**:
Use the provided startup scripts that load environment from .env:

**Windows (PowerShell)**:
```powershell
cd C:/Users/gals/teams-support-analyst
.\start-localsearch-api.ps1
```

**Linux/Mac (Bash)**:
```bash
cd ~/teams-support-analyst
./start-localsearch-api.sh
```

**Status**: Fixed with startup scripts. No code changes needed.

---

## Future Improvements

1. **Add .rgignore file** to each repository to exclude problematic files at the repository level
2. **Implement path normalization** to handle both forward and back slashes in API
3. **Add environment variable validation** on API startup with helpful error messages
4. **Create health check** that detects and reports problematic files in repositories

---

**Last Updated**: October 25, 2025
**Maintained By**: Support Analyst Team

---

## Issue #4: Duplicate Acknowledgments (PowerShell 5.1 Compatibility)

**Status**: ✅ RESOLVED (October 26, 2025)

**Symptom**: Bot sends immediate acknowledgment message ("Got it! Looking into this...") twice for the same user message.

**Root Cause**: 
- The `Save-BotSentMessage` function used `-AsHashtable` parameter with `ConvertFrom-Json`
- This parameter doesn't exist in PowerShell 5.1 (only in PowerShell 6+)
- Function was failing silently, causing bot message tracking to fail
- Bot couldn't remember which messages it already processed
- Same user message was processed multiple times on subsequent polling cycles

**Error Message**:
```
[WARN] Error saving bot message ID: A parameter cannot be found that matches parameter name 'AsHashtable'.
```

**Fix Applied**:
Changed line 105 in `orchestrator-v5.ps1` from:
```powershell
$botMessages = Get-Content $BOT_MESSAGES_FILE | ConvertFrom-Json -AsHashtable
```

To PowerShell 5.1 compatible version:
```powershell
# PowerShell 5.1 compatible: Convert PSCustomObject to hashtable
$jsonObj = Get-Content $BOT_MESSAGES_FILE | ConvertFrom-Json
foreach ($property in $jsonObj.PSObject.Properties) {
    $botMessages[$property.Name] = $property.Value
}
```

**Verification**: 
- Orchestrator restarted with fixed code
- No more `-AsHashtable` errors in logs
- Bot message IDs now being tracked properly in `state/bot_sent_messages.json`

**Prevention**: Test all PowerShell code with PowerShell 5.1 before deployment to ensure compatibility.

