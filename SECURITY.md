# Security Guidelines and Hardening

## 🔒 Security Overview

This document outlines security considerations and hardening steps for the Teams Support Analyst system.

---

## Security Model

### Threat Model
**Assets:**
- Local source code repositories
- Microsoft Teams messages and conversations
- API credentials (Teams, Claude)
- System resources

**Threats:**
- Unauthorized code access
- Command injection via search queries
- Path traversal attacks
- Credential exposure
- Resource exhaustion (DoS)
- Information leakage

### Trust Boundaries
1. **User Input** → LocalSearch API (validate & sanitize)
2. **API** → File System (path validation)
3. **Orchestrator** → Claude API (secure transmission)
4. **System** → Teams (OAuth authentication)

---

## ✅ Implemented Security Controls

### 1. Input Validation & Sanitization

**Search Query Sanitization** (`search.ts:46-51`):
```typescript
export function sanitizeQuery(query: string): string {
  // Remove dangerous characters
  const sanitized = query.replace(/[;&|`$()]/g, '');
  return sanitized.substring(0, 500); // Max length
}
```

**What it protects against:**
- Command injection via shell metacharacters
- Buffer overflow attacks
- Resource exhaustion via massive queries

### 2. Path Validation

**Repository Root Validation** (`search.ts:35-41`):
```typescript
export function validatePath(inputPath: string, allowedRoots: string[]): boolean {
  const resolved = path.resolve(inputPath);
  return allowedRoots.some(root => {
    const resolvedRoot = path.resolve(root);
    return resolved.startsWith(resolvedRoot);
  });
}
```

**What it protects against:**
- Path traversal attacks (`../../../etc/passwd`)
- Access to files outside repository roots
- Symlink exploitation

**Applied to:**
- File read operations
- File info queries
- Search operations

### 3. File Size Limits

**Multiple layers of protection:**
```typescript
// API level (server.ts:32)
app.use(express.json({ limit: '1mb' }));

// Search level (search.ts:74)
--max-filesize 10M

// File read level (file.ts:100-102)
if (stats.size > 10 * 1024 * 1024) {
  throw new Error('File too large (max 10MB)');
}
```

**What it protects against:**
- Memory exhaustion
- DoS via large file uploads
- System resource depletion

### 4. CORS Configuration

**Restricted origins** (`server.ts:31`):
```typescript
app.use(cors({
  origin: ['http://localhost:5678', 'http://localhost:3978']
}));
```

**What it protects against:**
- Cross-origin attacks
- Unauthorized API access from web browsers
- CSRF attacks

### 5. Rate Limiting (Orchestrator)

**Polling interval** (`orchestrator-v5.ps1:22`):
```powershell
$POLL_INTERVAL = 10  # seconds
```

**What it protects against:**
- API quota exhaustion
- Cost overrun from excessive Claude API calls
- Teams API rate limiting

### 6. Binary File Detection

**Prevents reading sensitive binaries** (`file.ts:22-38`):
```typescript
async function isBinaryFile(filePath: string): Promise<boolean> {
  // Check for null bytes (binary indicator)
  for (let i = 0; i < sample.length; i++) {
    if (sample[i] === 0) return true;
  }
}
```

**What it protects against:**
- Information leakage from compiled binaries
- Credential exposure from binary config files
- Performance issues from parsing binaries

### 7. Secret Management

**Environment-based configuration** (`.env`):
- API keys in environment variables
- No secrets in source code
- `.env` excluded from git via `.gitignore`

### 8. Error Handling

**Graceful degradation**:
- API errors don't expose system paths
- Generic error messages to users
- Detailed logging only server-side

---

## ⚠️ Security Recommendations

### High Priority

#### 1. Add Authentication to LocalSearch API
**Current:** No authentication required
**Risk:** Anyone on localhost can access API
**Solution:**
```typescript
// Add API key middleware
app.use((req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== process.env.API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});
```

#### 2. Implement Request Rate Limiting
**Current:** Unlimited requests allowed
**Risk:** Resource exhaustion, DoS
**Solution:**
```bash
npm install express-rate-limit
```
```typescript
import rateLimit from 'express-rate-limit';
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 20 // 20 requests per minute
});
app.use('/search', limiter);
```

#### 3. Add Request Logging with Audit Trail
**Current:** Basic console logging
**Risk:** No audit trail for security incidents
**Solution:**
```typescript
import winston from 'winston';
const logger = winston.createLogger({
  transports: [
    new winston.transports.File({ filename: 'audit.log' })
  ]
});
```

### Medium Priority

#### 4. HTTPS for LocalSearch API
**Current:** HTTP only
**Risk:** Credentials/data in transit
**Solution:**
```typescript
import https from 'https';
import fs from 'fs';
const options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem')
};
https.createServer(options, app).listen(3001);
```

#### 5. Content Security Policy
**For Web UI** (`web-ui/index.html`):
```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; script-src 'self' 'unsafe-inline'">
```

#### 6. Add File Type Whitelist
**Current:** Reads any non-binary file
**Risk:** Sensitive file exposure
**Solution:**
```typescript
const ALLOWED_EXTENSIONS = ['.ts', '.js', '.cs', '.md', '.json', '.txt'];
const ext = path.extname(filePath);
if (!ALLOWED_EXTENSIONS.includes(ext)) {
  throw new Error('File type not allowed');
}
```

### Low Priority

#### 7. Dependency Scanning
```bash
npm audit
npm audit fix
```

#### 8. Add Security Headers
```typescript
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});
```

---

## 🔐 Secret Management Best Practices

### Current Setup
```
.env file (gitignored):
├── REPO_ROOTS (semi-sensitive)
├── TEAMS_CHAT_ID (sensitive)
├── Bot credentials (highly sensitive)
└── Claude API key (highly sensitive)
```

### Recommendations

#### 1. Use Azure Key Vault (Production)
```powershell
# Store secrets
az keyvault secret set --vault-name "my-vault" --name "ClaudeAPIKey" --value "..."

# Retrieve in app
$apiKey = az keyvault secret show --vault-name "my-vault" --name "ClaudeAPIKey" --query value -o tsv
```

#### 2. Rotate Credentials Regularly
- Claude API keys: Every 90 days
- Teams bot credentials: Every 180 days
- Graph API tokens: Auto-expire (follow OAuth flow)

#### 3. Principle of Least Privilege
- LocalSearch API: Read-only filesystem access
- Teams bot: Only channels it needs
- Orchestrator: Minimal Teams permissions

---

## 🛡️ Hardening Checklist

### Pre-Production

- [x] Input validation on all endpoints
- [x] Path traversal protection
- [x] File size limits
- [x] CORS configuration
- [ ] API authentication
- [ ] Rate limiting
- [ ] HTTPS/TLS
- [ ] Security headers
- [ ] Audit logging
- [ ] Dependency updates

### Production

- [ ] Secrets in Azure Key Vault
- [ ] Regular security patches
- [ ] Monitoring and alerting
- [ ] Incident response plan
- [ ] Regular penetration testing
- [ ] Security awareness training

---

## 🚨 Incident Response

### If Credentials Are Exposed

1. **Immediately:**
   - Revoke compromised credentials
   - Generate new API keys
   - Update `.env` file
   - Restart services

2. **Investigate:**
   - Check logs for unauthorized access
   - Review recent API calls
   - Identify scope of exposure

3. **Remediate:**
   - Deploy credential rotation
   - Update security policies
   - Document incident

### If Unauthorized Code Access Detected

1. **Isolate:**
   - Stop LocalSearch API
   - Review access logs
   - Identify compromised files

2. **Assess:**
   - Determine what was accessed
   - Check for data exfiltration
   - Review repository history

3. **Recover:**
   - Implement additional path restrictions
   - Add audit logging
   - Enhance monitoring

---

## 📋 Security Testing Checklist

### Manual Testing

```bash
# 1. Test path traversal
curl -X POST http://localhost:3001/file \
  -H "Content-Type: application/json" \
  -d '{"path":"../../../etc/passwd","start":1,"end":10}'
# Expected: Error - path outside allowed repositories

# 2. Test command injection
curl -X POST http://localhost:3001/search \
  -H "Content-Type: application/json" \
  -d '{"query":"test; rm -rf /","max_results":5}'
# Expected: Sanitized query, no command execution

# 3. Test file size limit
# Create 20MB file and try to read
# Expected: Error - file too large

# 4. Test invalid CORS origin
curl -H "Origin: http://evil.com" http://localhost:3001/health
# Expected: CORS error
```

### Automated Testing

```powershell
# Run security test suite
.\test-security.ps1
```

---

## 📚 Security References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Microsoft Graph Security](https://docs.microsoft.com/en-us/graph/security-concept-overview)
- [Express.js Security](https://expressjs.com/en/advanced/best-practice-security.html)

---

**Last Updated**: October 25, 2025
**Next Review**: November 25, 2025
**Security Contact**: security@your-domain.com
