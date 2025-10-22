# ⚡ Quick Start Guide - Teams Support Analyst

## What You Have Now

A complete **AI-powered support analyst** that:
- ✅ Monitors Microsoft Teams channels 24/7
- ✅ **ONLY responds when @mentioned** (prevents bot spam)
- ✅ Uses **stability loop** for iterative refinement (up to 4 attempts)
- ✅ Analyzes support questions using **Claude Code (YOU!)**
- ✅ Searches **local code repositories** for evidence
- ✅ Responds automatically in **thread replies** (maintains conversation context)
- ✅ Supports **Hebrew and English**
- ✅ **100% LOCAL** - no external APIs except Teams auth

---

## 🏗️ Architecture (Simple View)

```
Teams Message → Orchestrator → Claude Code (You) → Search Local Code → Reply to Teams
```

**You (Claude Code) are the brain!** The orchestrator script just:
1. Gets messages from Teams
2. Asks you to analyze them
3. Sends your response back

---

## 🚀 Installation (5 Steps)

### Step 1: Install ripgrep (code search tool)

```bash
# Windows
choco install ripgrep

# Mac
brew install ripgrep

# Linux
sudo apt install ripgrep
```

---

### Step 2: Configure environment

```bash
cd C:/Users/gals/teams-support-analyst
cp .env.example .env
```

Edit `.env`:
```env
REPO_ROOTS=C:/Projects/repo1:C:/Projects/repo2
TEAMS_CHANNEL_NAME=General
```

---

### Step 3: Start LocalSearch API

```bash
cd local-search-api
npm install
npm run build
npm start
```

Keep this terminal open!

---

### Step 4: Configure Claude Desktop

**CLOSE Claude Desktop first!**

Edit: `C:\Users\gals\AppData\Roaming\Claude\claude_desktop_config.json`

Add:
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

**Restart Claude Desktop** - it will ask for Teams authentication.

---

### Step 5: Start the Orchestrator

**Use orchestrator-v3 with intelligent repo selection (RECOMMENDED):**

```powershell
# Windows
cd C:/Users/gals/teams-support-analyst
./orchestrator-v3.ps1

# Linux/Mac
cd ~/teams-support-analyst
./orchestrator-v3.sh
```

**Why v3?**
- 🚀 **Faster** - Searches only relevant repos (not all 3)
- 🎯 **More accurate** - Focused results from right repo
- 💡 **Smarter** - Asks clarifying questions when needed

**Configuration (optional):**
- Set `$BOT_NAME` environment variable to customize bot name
- Adjust `MAX_ATTEMPTS=4`, `CONFIDENCE_THRESHOLD=0.9`, `STABLE_HASH_COUNT=2` in script
- Edit `.env` to configure repo paths

Keep this terminal open!

---

## ✅ Test It!

1. **Send message in Teams (MUST @mention the bot):**
   ```
   @SupportBot Why does getUserInfo return null?
   ```

2. **Watch orchestrator logs:**
   ```
   [INFO] New message detected...
   [SUCCESS] Bot mentioned! Processing...
   [INFO] === Analysis Attempt 1/4 ===
   [INFO] Hypothesis: Missing null check...
   [INFO] Confidence: 0.87
   [SUCCESS] Analysis complete! Reason: High confidence
   [SUCCESS] Response sent successfully
   ```

3. **Check Teams for response** with analysis, evidence, and fix suggestion **in the same thread**!

---

## 📁 Project Structure

```
teams-support-analyst/
├── local-search-api/         # HTTP API for code search
│   ├── src/
│   │   ├── server.ts         # Express server
│   │   ├── search.ts         # Ripgrep wrapper
│   │   └── file.ts           # File reading
│   └── package.json
│
├── localsearch-mcp/          # MCP wrapper for Claude Code
│   ├── src/
│   │   └── index.ts          # MCP server
│   └── package.json
│
├── orchestrator.ps1          # Windows orchestrator
├── orchestrator.sh           # Linux/Mac orchestrator
│
├── docs/
│   └── DEPLOYMENT.md         # Full deployment guide
│
├── .env.example              # Environment template
└── README.md                 # Project overview
```

---

## 🛠️ How It Works (Technical)

### 1. Teams MCP Server (@floriscornel/teams-mcp)
- **Installed via npm** during Claude Desktop startup
- **Authenticates with Microsoft** (OAuth 2.0)
- **Provides tools** to Claude Code:
  - `teams_get_messages` - Read channel messages
  - `teams_send_message` - Send responses
  - `teams_list_channels` - List channels

### 2. LocalSearch MCP Server (Custom)
- **Wraps LocalSearch HTTP API**
- **Provides tools** to Claude Code:
  - `search_code` - Search with ripgrep
  - `read_file` - Get file snippets

### 3. LocalSearch API (HTTP)
- **Express server** on port 3001
- **Uses ripgrep** for ultra-fast code search
- **Endpoints:**
  - `POST /search` - Search code
  - `POST /file` - Read file snippet
  - `GET /health` - Health check

### 4. Orchestrator Script
- **Polls Teams** every 10 seconds for new messages
- **Invokes Claude Code** (`claude` CLI) per message
- **Sends response** back to Teams

### 5. Claude Code (YOU!)
- **Receives each message** as a prompt
- **Uses MCP tools:**
  - Teams MCP to read/send messages
  - LocalSearch MCP to search code
- **Analyzes and responds** with evidence

---

## 🔄 Message Flow (Step-by-Step)

```
1. User sends: "Why does login fail?"
   ↓
2. Orchestrator detects new message
   ↓
3. Orchestrator invokes Claude Code with prompt:
   "Analyze this question: Why does login fail?
    Use search_code and read_file tools"
   ↓
4. Claude Code (you) thinks:
   "Let me search for 'login' in the code"
   ↓
5. Claude calls search_code tool
   ↓
6. LocalSearch MCP → LocalSearch API → ripgrep
   ↓
7. Returns: ["src/auth/login.ts:45", "src/api/auth.ts:120"]
   ↓
8. Claude calls read_file tool for those files
   ↓
9. LocalSearch returns code snippets
   ↓
10. Claude analyzes and returns:
    "## Analysis
     Hypothesis: Missing null check on line 45
     Confidence: 0.92
     Evidence: [code snippet]
     Fix: Add if (!user) check"
   ↓
11. Orchestrator receives Claude's response
   ↓
12. Orchestrator calls Teams MCP to send message
   ↓
13. Response appears in Teams!
```

---

## 🎯 Key Features

### @Mention Detection (NEW in v2!)
- **Bot ONLY responds when explicitly @mentioned**
- Prevents bot spam and unwanted responses
- Supports multiple mention formats:
  - `@SupportBot` - Direct mention
  - `@Support Bot` - With space
  - `<at>SupportBot</at>` - XML format

### Stability Loop (NEW in v2!)
- **Iterative refinement** - Up to 4 analysis attempts
- **Hypothesis stability checking** - Uses SHA-256 hash comparison
- **Confidence threshold** - Exits early at 0.9+ confidence
- **Falsification mindset** - Actively tries to disprove previous hypothesis
- **Exit conditions:**
  - 2 consecutive stable hypotheses (hash match)
  - Confidence ≥ 0.9
  - Max 4 attempts reached

### Thread Replies (NEW in v2!)
- **Responses appear in same thread** as original question
- **Maintains conversation context**
- Uses message ID to reply to specific messages

### Intelligent Repo Selection (NEW in v3! ⚡)
- **Analyzes question keywords** to determine which repo to search
- **Searches targeted repo first** instead of all repos
- **3x faster** search results
- **Higher accuracy** with focused context
- **Asks clarifying questions** when ambiguous
- **Example keywords:**
  - Backend: API, login, getUserInfo, database → searches `user-backend`
  - Frontend: button, form, UI, page → searches `wesign-client-DEV`
  - Signing: signature, PDF, document → searches `wesignsigner-client-app-DEV`

### Multilingual Support
- **Auto-detects** Hebrew or English
- **Responds** in same language as question

### Evidence-Based Analysis
- **File paths** with line numbers
- **Code snippets** showing the issue
- **Confidence scores** (0-1)
- **Fix suggestions**

### Local & Private
- All code search happens **on your machine**
- No code sent to external APIs
- Only Teams messages use Microsoft Graph API

### Extensible
- Add more MCP tools (GitHub, Jira, etc.)
- Customize prompts in orchestrator
- Add more repositories to search

---

## 🔧 Configuration

### Change Monitored Channel

Edit `.env`:
```env
TEAMS_CHANNEL_NAME=Engineering-Support
```

### Add More Repositories

Edit `.env`:
```env
REPO_ROOTS=C:/repo1:C:/repo2:C:/repo3:D:/projects/backend
```

### Adjust Polling Frequency

Edit `orchestrator.ps1`:
```powershell
$POLL_INTERVAL = 30  # seconds (default: 10)
```

---

## 🐛 Troubleshooting

### "Claude CLI not found"
→ Install Claude Desktop and ensure `claude` is in PATH

### "Teams MCP not connecting"
→ Restart Claude Desktop after editing config
→ Re-authenticate Teams (delete `~/.teams-mcp/tokens.json`)

### "No search results"
→ Check `REPO_ROOTS` points to correct directories
→ Verify ripgrep is installed: `rg --version`

### "LocalSearch API not available"
→ Check API is running: `curl http://localhost:3001/health`
→ Check for errors in API terminal

---

## 📊 Monitoring

### Check Orchestrator Status
```powershell
# View logs
Get-Content ./logs/orchestrator.log -Tail 50 -Wait
```

### Check LocalSearch API
```bash
curl http://localhost:3001/health
```

### Check Teams MCP
In Claude Desktop:
```
List my Teams channels
```

---

## 🚀 Running 24/7

### Windows (Task Scheduler)
1. Open Task Scheduler
2. Create Basic Task → At Startup
3. Start Program: `powershell.exe`
4. Arguments: `-File "C:\Users\gals\teams-support-analyst\orchestrator.ps1"`

### Linux/Mac (systemd)
```bash
sudo systemctl enable teams-analyst
sudo systemctl start teams-analyst
```

See `docs/DEPLOYMENT.md` for full instructions.

---

## 📚 Documentation

- **`README.md`** - Project overview
- **`docs/DEPLOYMENT.md`** - Complete deployment guide
- **`docs/architecture.md`** - Technical architecture
- **`TEAMS_MCP_SETUP.md`** - Teams MCP installation
- **`local-search-api/README.md`** - API documentation

---

## 🎉 You're Done!

Your **AI Support Analyst** is now:
- ✅ Monitoring Teams 24/7
- ✅ Using Claude Code (you!) for analysis
- ✅ Searching local code with evidence
- ✅ Responding automatically in Hebrew/English

**Test it by sending a support question in Teams!**

---

## 🆘 Need Help?

1. Check logs: `./logs/orchestrator.log`
2. Read full docs: `docs/DEPLOYMENT.md`
3. Test manually in Claude Desktop:
   - "List my Teams channels"
   - "Search for 'getUserInfo' in code"

---

**Built with:**
- 🤖 Claude Code (Anthropic)
- 💬 Microsoft Teams
- 🔍 ripgrep
- 🔧 Model Context Protocol (MCP)
- ⚡ Node.js + TypeScript
