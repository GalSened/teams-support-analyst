# Repository Guide for Claude Code

When analyzing support questions, use this guide to determine which repository to search:

## Available Repositories

### 1. **user-backend** (`C:/Users/gals/source/repos/user-backend`)
- **Purpose**: Backend API server
- **Keywords**: API, authentication, database, endpoints, server, backend logic
- **Search when question mentions**: login, user management, API calls, authentication, authorization, database queries, server errors

### 2. **wesign-client-DEV** (`C:/Users/gals/Desktop/wesign-client-DEV`)
- **Purpose**: Client-side web application
- **Keywords**: UI, frontend, React, components, forms, buttons, pages
- **Search when question mentions**: UI issues, forms, buttons, display problems, client-side errors, rendering, pages, components

### 3. **wesignsigner-client-app-DEV** (`C:/Users/gals/Desktop/wesignsigner-client-app-DEV`)
- **Purpose**: Signer application (separate client)
- **Keywords**: signing, signature, PDF, document signing, signer interface
- **Search when question mentions**: signing documents, signatures, PDF handling, signer features, document workflow

## Decision Tree

```
Question: "Why does login fail?"
→ Could be backend (API) OR frontend (form)
→ Strategy: Search user-backend FIRST (authentication is usually backend)
→ If no results, then search wesign-client-DEV

Question: "Button doesn't appear on signature page"
→ Clearly UI/frontend issue
→ Strategy: Search wesignsigner-client-app-DEV ONLY

Question: "getUserInfo returns null"
→ Backend API function
→ Strategy: Search user-backend ONLY

Question: "Document upload fails"
→ Could be frontend OR backend
→ Strategy: Search BOTH (wesign-client-DEV for upload UI, user-backend for API)
```

## Best Practices

1. **ASK if unclear**: If the question is ambiguous, ask user: "Is this a UI issue or API/backend issue?"
2. **Search narrow first**: Start with the most likely repo
3. **Expand if needed**: If no results, search other repos
4. **Use keywords**: Look for keywords in the question to determine repo
5. **Context matters**: Consider previous messages in the thread

## Example Analysis Flow

### Good Approach ✅
```
User: "@SupportBot Why does the signature button not work?"

Claude thinks:
- "signature button" = UI component
- Likely in wesignsigner-client-app-DEV
- Search that repo first

Action: search_code in wesignsigner-client-app-DEV only
Result: Fast, accurate answer
```

### Inefficient Approach ❌
```
User: "@SupportBot Why does the signature button not work?"

Claude thinks:
- Search all 3 repos simultaneously

Action: search_code in ALL repos
Result: Slow, many irrelevant results, harder to analyze
```

## When to Search Multiple Repos

Search multiple repos when:
- Integration issues (frontend + backend)
- Shared code/utilities
- User explicitly mentions multiple components
- First search yields no results

## Prompt Template for Clarification

If unclear, ask:
```
I need clarification to provide accurate analysis:
- Is this a **UI/display** issue? (frontend)
- Is this an **API/server** issue? (backend)
- Is this related to **document signing** specifically? (signer app)

This helps me search the right repository.
```
