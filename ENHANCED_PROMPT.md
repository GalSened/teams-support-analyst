# Enhanced Prompt for Intelligent Repo Selection

## Current Prompt vs Enhanced Prompt

### ❌ Current (searches all repos blindly)
```
Your task:
1. Use the 'search_code' tool to search our local repositories
2. Analyze and respond
```

### ✅ Enhanced (smart repo selection)
```
Your task:
1. FIRST: Determine which repository is most relevant:
   - user-backend: API, authentication, database, server logic
   - wesign-client-DEV: UI, frontend, React components, forms
   - wesignsigner-client-app-DEV: Document signing, signatures, PDF

2. If unclear, ask user: "Is this a UI issue or backend API issue?"

3. Search the MOST RELEVANT repo first (narrow search = faster + more accurate)

4. Only search other repos if needed
```

## Enhanced Orchestrator Prompt (v3)

Replace the prompt in `orchestrator-v2.ps1` line 193 with:

```powershell
$prompt = @"
You are a support analyst for our WeSign codebase.

User question ($Language): $MessageText

$attemptInfo

Available Repositories:
- **user-backend**: Backend API, authentication, database, server logic
- **wesign-client-DEV**: Frontend UI, React components, forms, pages
- **wesignsigner-client-app-DEV**: Document signing features, signatures, PDF handling

Your task:

**STEP 1: Repository Selection Strategy**
- Analyze the question keywords to determine the most relevant repository
- Keywords for user-backend: API, login, authentication, database, getUserInfo, server, backend
- Keywords for wesign-client-DEV: UI, button, form, display, page, render, component
- Keywords for wesignsigner-client-app-DEV: sign, signature, document, PDF, upload

**STEP 2: Smart Search**
- Search the MOST RELEVANT repository FIRST (not all repos)
- Example: "Why does login fail?" → Search user-backend first
- Example: "Button doesn't work" → Search wesign-client-DEV or wesignsigner-client-app-DEV
- Only search additional repos if first search yields no results

**STEP 3: Ask if Unclear**
If you cannot determine which repo from the question, ask:
"To provide accurate analysis, is this:
 - A UI/frontend issue?
 - A backend/API issue?
 - A document signing specific issue?"

**STEP 4: Analysis**
Once you've searched the right repo(s), provide:
- Root cause hypothesis
- Confidence level (0-1)
- Evidence (file paths + line numbers + code snippets)
- Fix suggestion

IMPORTANT: Return your analysis in this EXACT format:

## Repository Search Strategy
**Selected Repos:** [which repos you searched and why]

## Analysis
**Hypothesis:** [your hypothesis in $Language]
**Confidence:** [0.0-1.0 as decimal number]

## Evidence
1. \`\`path/to/file.ts:120-135\`\`
\`\`\`
[code snippet]
\`\`\`

## Fix Suggestion
[how to fix in $Language]
"@
```

## Benefits of Enhanced Prompt

| Aspect | Before | After |
|--------|--------|-------|
| **Search Speed** | Searches 3 repos (slow) | Searches 1 repo first (fast) |
| **Accuracy** | Mixed results from all repos | Focused results from right repo |
| **Token Usage** | High (all results) | Low (targeted results) |
| **Context** | Harder to analyze | Clearer context |
| **Confidence** | Lower | Higher |

## Example Conversations

### Example 1: Clear Question ✅
```
User: @SupportBot Why does getUserInfo API return null?

Claude thinks:
- "getUserInfo API" = backend function
- Select: user-backend only

Claude searches: user-backend
Claude finds: Missing null check in user.ts:138
Result: Fast, accurate, high confidence (0.92)
```

### Example 2: Ambiguous Question ❓
```
User: @SupportBot Why doesn't document upload work?

Claude thinks:
- Could be frontend upload UI
- Could be backend upload API
- Need clarification

Claude asks: "Is this a UI issue (upload button/form) or API issue (server processing)?"
User: "The button works but server returns error"
Claude searches: user-backend (API issue)
Result: Accurate, user-guided
```

### Example 3: Integration Issue 🔗
```
User: @SupportBot Authentication flow is broken

Claude thinks:
- Authentication involves frontend (login form) + backend (API)
- This is an integration issue

Claude searches:
1. user-backend (authentication API)
2. wesign-client-DEV (login form)

Result: Found issue in both - frontend not sending token correctly
```

## How to Apply This

**Option 1: Update orchestrator-v2.ps1 manually**
- Edit line 193-231 in `orchestrator-v2.ps1`
- Replace with enhanced prompt above
- Save and restart orchestrator

**Option 2: Create orchestrator-v3.ps1 (Recommended)**
- Copy orchestrator-v2.ps1 to orchestrator-v3.ps1
- Update prompt section
- Use v3 going forward

**Option 3: Dynamic Prompt (Advanced)**
- Load REPO_GUIDE.md as context for each analysis
- Claude reads the guide before answering

## Testing the Enhancement

Test with these questions:

1. **Backend question**: "@SupportBot Why does login API fail?"
   - Expected: Search user-backend only
   - Time: ~5 seconds

2. **Frontend question**: "@SupportBot Signature button is disabled"
   - Expected: Search wesignsigner-client-app-DEV only
   - Time: ~5 seconds

3. **Ambiguous question**: "@SupportBot Documents not working"
   - Expected: Ask for clarification
   - Time: Instant response asking for details

## Next Steps

1. ✅ Created `.env` with correct repos
2. ✅ Created `REPO_GUIDE.md` with repo descriptions
3. ⏭️ **You decide**: Apply enhanced prompt or keep current?
4. ⏭️ Test with real questions
5. ⏭️ Push to GitHub
