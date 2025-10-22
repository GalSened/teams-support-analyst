# 🚀 Teams Support Analyst - Complete Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Microsoft Teams                           │
│               (User sends support question)                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Teams MCP Server (@floriscornel)               │
│          (Polls Teams channels every 10 seconds)            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                 Orchestrator Script                          │
│        (Bash/PowerShell - runs continuously)                │
│   • Detects new messages                                     │
│   • Invokes Claude Code per message                          │
│   • Sends responses back to Teams                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                   Claude Code (You!)                          │
│          Uses MCP tools to analyze messages:                  │
│   • Teams MCP (read/send messages)                            │
│   • LocalSearch MCP (search code)                             │
│   • Other tools (memory, web search, etc.)                    │
└──────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│             LocalSearch MCP Server (Custom)                   │
│               Wraps LocalSearch HTTP API                      │
└──────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│              LocalSearch API (HTTP)                           │
│          Fast code search with ripgrep                        │
│          • POST /search - find code                           │
│          • POST /file - read file snippets                    │
└──────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                Local Code Repositories                        │
│          (Your codebase on this machine)                      │
└──────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Software

- ✅ **Node.js** 18+ ([Download](https://nodejs.org))
- ✅ **Claude Desktop** ([Download](https://claude.ai/download))
- ✅ **ripgrep** (rg) for code search
  - Windows: `choco install ripgrep` or download from [GitHub](https://github.com/BurntSushi/ripgrep/releases)
  - Linux/Mac: `brew install ripgrep`
- ✅ **Git** (for cloning)
- ✅ **PowerShell 7+** (Windows) or **Bash** (Linux/Mac)

### Required Accounts

- Microsoft 365 account with Teams access
- Permissions to read/send messages in target Teams channels

---

## Installation Steps

### Step 1: Install ripgrep

```bash
# Windows (with Chocolatey)
choco install ripgrep

# Mac
brew install ripgrep

# Linux
sudo apt install ripgrep   # Debian/Ubuntu
sudo dnf install ripgrep   # Fedora
```

Verify:
```bash
rg --version
```

---

### Step 2: Clone and Setup Project

```bash
# Clone the repository
cd C:/Users/gals
git clone [your-repo-url] teams-support-analyst
cd teams-support-analyst

# Create environment file
cp .env.example .env
```

Edit `.env` and configure:
```env
# Local repositories to search
REPO_ROOTS=C:/Projects/repo1:C:/Projects/repo2:C:/Projects/repo3

# LocalSearch API port
LOCALSEARCH_PORT=3001

# Teams channel to monitor
TEAMS_CHANNEL_NAME=General
```

---

### Step 3: Build and Start LocalSearch API

```bash
cd local-search-api

# Install dependencies
npm install

# Build TypeScript
npm run build

# Start the API server
npm start
```

**Expected output:**
```
✓ LocalSearch API server running on http://localhost:3001
✓ Monitoring 3 repository root(s)
✓ Ripgrep status: installed
```

**Keep this terminal open!**

---

### Step 4: Build LocalSearch MCP Server

Open a **NEW terminal**:

```bash
cd localsearch-mcp

# Install dependencies
npm install

# Build TypeScript
npm run build
```

---

### Step 5: Configure Claude Desktop MCP Servers

**Close Claude Desktop** (important!)

Edit config file:
- Windows: `C:\Users\gals\AppData\Roaming\Claude\claude_desktop_config.json`
- Mac: `~/Library/Application Support/Claude/claude_desktop_config.json`

Add these entries to the `mcpServers` object:

```json
{
  "mcpServers": {
    "teams": {
      "command": "npx",
      "args": ["-y", "@floriscornel/teams-mcp@latest"]
    },
    "localsearch": {
      "command": "node",
      "args": ["C:/Users/gals/teams-support-analyst/localsearch-mcp/dist/index.js"]
    }
  }
}
```

**Save and restart Claude Desktop.**

---

### Step 6: Authenticate Teams MCP

After restarting Claude Desktop:

1. The Teams MCP will automatically open a browser for OAuth
2. Sign in with your Microsoft 365 account
3. Grant permissions:
   - Read Teams messages
   - Send Teams messages
   - Access channel information

4. After successful auth, the token is saved locally

**Test it:**
- Open Claude Desktop or Claude Code
- Type: "List my Teams channels"
- You should see your Teams channels!

---

### Step 7: Test LocalSearch MCP

In Claude Desktop/Code, type:

```
Search for "function getUserInfo" in the code
```

If configured correctly, you should see search results from your local repositories!

---

### Step 8: Start the Orchestrator

Open a **NEW terminal** in the project root:

**Windows (PowerShell):**
```powershell
cd C:/Users/gals/teams-support-analyst
./orchestrator.ps1
```

**Linux/Mac (Bash):**
```bash
cd ~/teams-support-analyst
chmod +x orchestrator.sh
./orchestrator.sh
```

**Expected output:**
```
=== Teams Support Analyst Orchestrator Starting ===
[2025-01-23 10:00:00] [INFO] Dependencies OK
[2025-01-23 10:00:00] [INFO] Starting polling loop (interval: 10s)
[2025-01-23 10:00:00] [INFO] Monitoring channel: General
[2025-01-23 10:00:00] [INFO] Checking for new messages...
```

**Keep this terminal open!**

---

## Testing the Complete Flow

### Test 1: Send a Message in Teams

1. Open Microsoft Teams
2. Go to the monitored channel (e.g., "General")
3. Send a test message:
   ```
   Why does the getUserInfo function return null sometimes?
   ```

### Test 2: Watch the Orchestrator

You should see logs like:
```
[INFO] New message from John Doe: Why does the getUserInfo function...
[INFO] Detected language: en
[INFO] Analyzing with Claude Code...
[SUCCESS] Analysis complete (1247 chars)
[INFO] Sending response to Teams...
[SUCCESS] Response sent successfully
```

### Test 3: Check Teams for Response

You should receive a response in Teams like:

```
## Analysis

**Hypothesis:** The getUserInfo function returns null when the session has expired
**Confidence:** 0.87

## Evidence

1. `src/auth/user.ts:138-145`
```typescript
export function getUserInfo(sessionId: string) {
  const session = sessions.get(sessionId); // Can be undefined
  return {
    id: session.userId, // ❌ No null check
    name: session.userName
  };
}
```

2. `src/api/handler.ts:86-92`
```typescript
app.get('/user', (req, res) => {
  const info = getUserInfo(req.sessionId);
  res.json(info); // Crashes if session expired
});
```

## Fix Suggestion

Add session validation before accessing properties:
```typescript
if (!session) {
  throw new Error('Session expired');
}
```
```

---

## Configuration Options

### Environment Variables

```env
# Local repositories (colon-separated on Windows, colon on Linux/Mac)
REPO_ROOTS=C:/repo1:C:/repo2

# LocalSearch API settings
LOCALSEARCH_PORT=3001
MAX_SEARCH_RESULTS=30
MAX_FILE_LINES=200

# Orchestrator settings
POLL_INTERVAL=10             # seconds between Teams checks
TEAMS_CHANNEL_NAME=General   # channel to monitor

# LocalSearch MCP
LOCALSEARCH_API_URL=http://localhost:3001
```

### Orchestrator Script Options

Edit `orchestrator.ps1` or `orchestrator.sh`:

```bash
# Change polling interval
$POLL_INTERVAL = 30  # check every 30 seconds

# Change monitored channel
$CHANNEL_NAME = "Support"

# Change state file location
$STATE_FILE = "./state/messages.txt"
```

---

## Running as a Service

### Windows (Task Scheduler)

1. Open Task Scheduler
2. Create Basic Task
3. **Trigger:** At system startup
4. **Action:** Start a program
   - Program: `powershell.exe`
   - Arguments: `-File "C:\Users\gals\teams-support-analyst\orchestrator.ps1"`
   - Start in: `C:\Users\gals\teams-support-analyst`

### Linux/Mac (systemd)

Create `/etc/systemd/system/teams-analyst.service`:

```ini
[Unit]
Description=Teams Support Analyst Orchestrator
After=network.target

[Service]
Type=simple
User=gals
WorkingDirectory=/home/gals/teams-support-analyst
ExecStart=/bin/bash /home/gals/teams-support-analyst/orchestrator.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable teams-analyst
sudo systemctl start teams-analyst
sudo systemctl status teams-analyst
```

---

## Troubleshooting

### Issue: "Claude CLI not found"

**Solution:** Make sure Claude Desktop is installed and `claude` is in PATH.

Windows:
```powershell
where claude
```

If not found, add Claude to PATH or use full path in orchestrator.

---

### Issue: "Teams MCP not working"

**Solution:**
1. Check Claude Desktop MCP config is correct
2. Restart Claude Desktop
3. Test manually: "List my Teams channels"
4. Re-authenticate if needed: Delete `~/.teams-mcp/tokens.json`

---

### Issue: "LocalSearch API not available"

**Solution:**
1. Check if API is running: `curl http://localhost:3001/health`
2. Check logs in `local-search-api` terminal
3. Verify `REPO_ROOTS` env variable is set
4. Make sure ripgrep is installed: `rg --version`

---

### Issue: "No search results found"

**Solution:**
1. Check `REPO_ROOTS` points to correct directories
2. Verify repositories contain code files
3. Test search manually:
   ```bash
   curl -X POST http://localhost:3001/search \
     -H "Content-Type: application/json" \
     -d '{"query": "function"}'
   ```

---

### Issue: "Orchestrator stops responding"

**Solution:**
1. Check logs in `./logs/orchestrator.log`
2. Restart the orchestrator script
3. Check Claude Desktop is running
4. Verify Teams MCP authentication is still valid

---

## Security Considerations

- ✅ All code search is local (no data leaves your machine)
- ✅ Teams authentication uses Microsoft OAuth (secure)
- ✅ No API keys stored in code (environment variables only)
- ✅ Path traversal protection (repository allowlist)
- ✅ File size limits (prevent reading huge files)
- ✅ Rate limiting recommended (avoid spam)

**Best Practices:**
- Don't commit `.env` file to git
- Keep Teams auth tokens secure (`~/.teams-mcp/`)
- Use dedicated service account for Teams bot (optional)
- Monitor orchestrator logs for suspicious activity

---

## Performance Tuning

### For Large Codebases

1. **Increase search results limit:**
   ```env
   MAX_SEARCH_RESULTS=100
   ```

2. **Add file type filters** (edit `local-search-api/src/search.ts`):
   ```typescript
   const command = `${rgCommand} --type js --type ts ...`;
   ```

3. **Exclude directories:**
   ```typescript
   const command = `${rgCommand} --glob '!node_modules/*' --glob '!dist/*' ...`;
   ```

### For Better Responses

1. **Use specific channel names:**
   ```env
   TEAMS_CHANNEL_NAME=Engineering-Support
   ```

2. **Adjust polling interval** (lower = faster, higher = less load):
   ```env
   POLL_INTERVAL=5   # more responsive
   POLL_INTERVAL=30  # less frequent checks
   ```

---

## Logs and Monitoring

### Log Locations

- **Orchestrator:** `./logs/orchestrator.log`
- **LocalSearch API:** Terminal output or configure file logging
- **Claude Desktop:** Check Claude Desktop logs

### Log Rotation

For production, use logrotate (Linux) or similar:

```bash
# /etc/logrotate.d/teams-analyst
/home/gals/teams-support-analyst/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

---

## Next Steps

1. ✅ Test with real support questions
2. ✅ Add more repositories to `REPO_ROOTS`
3. ✅ Configure additional Teams channels
4. ✅ Set up as system service for 24/7 operation
5. ✅ Monitor logs and adjust polling interval
6. ✅ Train team on how to ask questions

---

## Support

- **Issues:** [GitHub Issues](https://github.com/YOUR_USERNAME/teams-support-analyst/issues)
- **Documentation:** See `/docs` folder
- **LocalSearch API:** `local-search-api/README.md`
- **Teams MCP:** https://github.com/floriscornel/teams-mcp

---

## Summary

**You've successfully deployed:**

1. ✅ **LocalSearch API** - Fast local code search
2. ✅ **LocalSearch MCP** - MCP wrapper for Claude Code
3. ✅ **Teams MCP** - Microsoft Teams integration
4. ✅ **Orchestrator** - Automated message handling
5. ✅ **Claude Code Integration** - AI-powered analysis

**The system:**
- Monitors Teams channels 24/7
- Analyzes support questions using your local code
- Provides evidence-based answers with file paths and code snippets
- Supports Hebrew and English
- Runs completely local (no external APIs except Teams and Claude)

**Enjoy your automated support analyst!** 🎉
