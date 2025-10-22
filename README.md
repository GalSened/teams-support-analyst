# 🤖 Teams Local Support Analyst

AI-powered support bot for Microsoft Teams that analyzes questions and searches local code repositories to provide root cause analysis with evidence.

## 🌟 Features

- 🌐 **Multilingual Support**: Hebrew & English automatic detection
- 🔍 **Local Repository Search**: Fast code search with ripgrep (no GitHub API needed)
- 🤖 **Claude LLM Integration**: Advanced reasoning with Claude Sonnet 4.5
- 🔄 **Stability Loop**: Iterative refinement for high-confidence results
- 📴 **Offline Graceful Degradation**: Clear messaging when services unavailable
- 🔒 **Security First**: Path validation, input sanitization, rate limiting
- 📊 **Rich Evidence**: File paths, line numbers, code snippets

## 🏗️ Architecture

```
┌─────────────┐
│ Teams User  │
└──────┬──────┘
       │ Question (he/en)
       ▼
┌─────────────────┐
│  Teams Bot      │ ◄─── Azure Bot Service
│  (Bot Framework)│
└────────┬────────┘
         │ Webhook POST
         ▼
┌──────────────────┐
│  n8n Workflow    │ ◄─── Orchestrator
│  (Local)         │
└────┬─────┬───────┘
     │     │
     │     └────────────┐
     │                  │
     ▼                  ▼
┌──────────┐    ┌───────────────┐
│ Claude   │    │ LocalSearch   │
│ API      │    │ API (ripgrep) │
└──────────┘    └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐
                │ Local Repos   │
                │ (Code Files)  │
                └───────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Python 3.9+ (for ripgrep)
- n8n (self-hosted)
- Azure account (for Teams Bot)
- Claude API key (Anthropic)

### Installation

1. **Clone and setup:**
```bash
git clone https://github.com/YOUR_USERNAME/teams-support-analyst.git
cd teams-support-analyst
cp .env.example .env
# Edit .env with your configuration
```

2. **Install LocalSearch API:**
```bash
cd local-search-api
npm install
npm run build
npm start
```

3. **Install Teams Bot:**
```bash
cd teams-bot
npm install
npm run build
npm start
```

4. **Import n8n workflow:**
```bash
n8n import:workflow --input=./n8n-workflows/teams-analyst.json
n8n start
```

5. **Deploy to Azure:**
- Follow [docs/deployment.md](docs/deployment.md) for Azure Bot setup

### Configuration

Edit `.env` and set:
- `REPO_ROOTS`: Colon-separated paths to your local repositories
- `CLAUDE_API_KEY`: Your Anthropic API key
- `MICROSOFT_APP_ID` & `MICROSOFT_APP_PASSWORD`: From Azure Bot registration
- `TENANT_ID`: Your Azure AD tenant ID

## 📝 Usage

### In Teams Channel:
```
@SupportAnalyst Why does getUserInfo return null?
```

### In Direct Message:
```
למה הפונקציה loadConfig קורסת כשאין קובץ config.json?
```

### With Stack Trace:
```
Getting this error:
TypeError: Cannot read properties of undefined (reading 'id')
    at getUserInfo (src/auth/user.ts:142:28)
    at processRequest (src/api/handler.ts:89:15)
```

## 🔧 Components

### LocalSearch API
HTTP service for code search and file snippet extraction.
- `POST /search` - Search code with regex/text
- `POST /file` - Get file snippet by line range
- `GET /health` - Health check

### Teams Bot
Azure Bot Framework adapter for Teams integration.
- Receives Teams messages
- Forwards to n8n webhook
- Handles message routing (channels/chats)

### n8n Workflow
Main orchestration logic:
1. Parse Teams message
2. Check connectivity (Claude + Graph)
3. Build prompt and call Claude
4. Execute tool requests (search/file)
5. Run stability loop
6. Format and send response

### Prompts
Claude LLM prompt templates:
- System prompt with JSON schema
- User prompt with context
- Follow-up prompts for stability

## 🧪 Testing

```bash
# Unit tests (LocalSearch API)
cd local-search-api
npm test

# Integration tests
npm run test:integration

# Manual test with sample payload
curl -X POST http://localhost:5678/webhook/teams/support \
  -H "Content-Type: application/json" \
  -d @tests/sample-payload.json
```

## 📚 Documentation

- [Deployment Guide](docs/deployment.md) - Step-by-step deployment
- [Testing Guide](docs/testing-guide.md) - Testing scenarios
- [Architecture](docs/architecture.md) - Technical deep dive
- [API Reference](docs/api-reference.md) - API endpoints

## 🔒 Security

- Path traversal protection (allowlist validation)
- Input sanitization (max lengths, character filtering)
- Rate limiting (10 requests/minute per user)
- Secret management (environment variables)
- No code execution from user input

## 🌍 Localization

Supports:
- **Hebrew (עברית)**: Right-to-left display, Hebrew prompts
- **English**: Default language
- **Auto-detection**: Based on user message content

## 📊 Example Output

```
🧭 Analysis Findings

• Hypothesis: Null dereference in getUserInfo when session is expired
• Confidence: 87%

🔎 Evidence

1) src/auth/user.ts:138-145
```typescript
export function getUserInfo(sessionId: string) {
  const session = sessions.get(sessionId); // Can be undefined
  return {
    id: session.userId, // ❌ No null check
    name: session.userName
  };
}
```

2) src/api/handler.ts:86-92
```typescript
app.get('/user', (req, res) => {
  const info = getUserInfo(req.sessionId);
  res.json(info); // Crashes if session expired
});
```

✅ Fix Suggestion
Add session validation before accessing properties:
```typescript
if (!session) {
  throw new Error('Session expired');
}
```
```

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- [Anthropic Claude](https://anthropic.com) - LLM provider
- [n8n](https://n8n.io) - Workflow automation
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast code search
- [Microsoft Teams](https://teams.microsoft.com) - Collaboration platform

## 📞 Support

- Issues: [GitHub Issues](https://github.com/YOUR_USERNAME/teams-support-analyst/issues)
- Docs: [Documentation](docs/)
- Email: support@your-domain.com
