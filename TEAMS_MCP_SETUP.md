# Teams MCP Server Setup Guide

## Step 1: Add Teams MCP to Claude Desktop Config

1. **Close Claude Desktop** (Important!)

2. **Edit config file:**
   - Windows: `C:\Users\gals\AppData\Roaming\Claude\claude_desktop_config.json`

3. **Add this configuration** after the "jira" entry:

```json
    "teams": {
      "command": "npx",
      "args": [
        "-y",
        "@floriscornel/teams-mcp@latest"
      ]
    }
```

**Full example** (add comma after jira, then add teams):
```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@wunderfrucht/jira-mcp-server"],
      "env": {...}
    },
    "teams": {
      "command": "npx",
      "args": ["-y", "@floriscornel/teams-mcp@latest"]
    }
  }
}
```

4. **Save the file**

5. **Restart Claude Desktop**

---

## Step 2: Authenticate with Microsoft Teams

After restarting Claude Desktop, the Teams MCP server will start automatically.

**First time setup:**
1. The MCP server will open a browser for OAuth authentication
2. Sign in with your Microsoft 365 account
3. Grant permissions for:
   - Read Teams messages
   - Send Teams messages
   - Access channel information
   - Read user information

4. After successful authentication, the token will be stored locally

---

## Step 3: Verify Installation

In Claude Desktop (or Claude Code), try:

```
List my Teams channels
```

or

```
Get recent messages from [channel-name]
```

If successful, you'll see Teams data!

---

## Available Tools (after installation)

Once configured, Claude Code will have access to these Teams MCP tools:

### Reading Messages
- `teams_list_channels` - List all Teams channels you have access to
- `teams_get_messages` - Get messages from a specific channel
- `teams_search_messages` - Search for messages by content
- `teams_get_user_info` - Get information about Teams users

### Sending Messages
- `teams_send_message` - Send a message to a channel or chat
- `teams_reply_to_message` - Reply to a specific message
- `teams_send_mention` - Send a message with @mentions

### Channel Management
- `teams_list_members` - List members of a channel/team
- `teams_get_channel_info` - Get details about a channel

---

## Step 4: Configure LocalSearch MCP (for code search)

While we're at it, let's also add our LocalSearch API as an MCP server:

1. Create `C:\Users\gals\teams-support-analyst\localsearch-mcp\` directory

2. We'll build a simple MCP wrapper around the LocalSearch API (next step)

---

## What's Next?

After Teams MCP is installed and authenticated:

1. **Build LocalSearch MCP wrapper** - So Claude can use the code search API
2. **Create orchestrator script** - Polls Teams messages and invokes Claude
3. **Test the full flow** - Teams message → Claude analysis → Teams response

---

## Troubleshooting

### "Teams MCP not found"
- Make sure you restarted Claude Desktop after editing the config
- Check that the JSON syntax is valid (commas, brackets)

### "Authentication failed"
- Clear the token cache: Delete `~/.teams-mcp/` folder
- Re-authenticate by restarting Claude Desktop

### "Permission denied"
- Make sure your Microsoft 365 account has access to the Teams workspace
- Check that you granted all required permissions during OAuth

---

## Security Note

- Authentication tokens are stored locally in `~/.teams-mcp/tokens.json`
- Never commit this file to git
- Tokens are encrypted and auto-refresh
- Only works with your Microsoft 365 account
