import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { z } from 'zod';
import { searchCode, checkRipgrepInstalled } from './search';
import { readFileSnippet, getFileInfo } from './file';

// Load environment variables
dotenv.config();

const app = express();
const PORT = parseInt(process.env.LOCALSEARCH_PORT || '3001', 10);

// Parse REPO_ROOTS from environment
// Use semicolon (;) for Windows, colon (:) for Unix
const repoRootsEnv = process.env.REPO_ROOTS || '';
const separator = repoRootsEnv.includes(';') ? ';' : ':';
const REPO_ROOTS = repoRootsEnv
  .split(separator)
  .map(p => p.trim())
  .filter(p => p.length > 0);

if (REPO_ROOTS.length === 0) {
  console.error('ERROR: REPO_ROOTS environment variable is not set or empty');
  process.exit(1);
}

console.log(`Configured repository roots: ${REPO_ROOTS.join(', ')}`);

// Middleware
app.use(cors({ origin: ['http://localhost:5678', 'http://localhost:3978'] }));
app.use(express.json({ limit: '1mb' }));

// Request logging
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });
  next();
});

// ==========================================
// Validation Schemas
// ==========================================

const searchSchema = z.object({
  query: z.string().min(1).max(500),
  max_results: z.number().int().min(1).max(100).optional().default(30)
});

const fileSchema = z.object({
  path: z.string().min(1),
  start: z.number().int().min(1),
  end: z.number().int().min(1).max(1000)
});

// ==========================================
// Routes
// ==========================================

/**
 * POST /search
 * Search code across repositories
 */
app.post('/search', async (req: Request, res: Response) => {
  try {
    const parsed = searchSchema.parse(req.body);

    const results = await searchCode(REPO_ROOTS, {
      query: parsed.query,
      maxResults: parsed.max_results
    });

    res.json({
      success: true,
      query: parsed.query,
      count: results.length,
      results
    });
  } catch (error: any) {
    console.error('Search error:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors
      });
    }

    res.status(500).json({
      success: false,
      error: error.message || 'Search failed'
    });
  }
});

/**
 * POST /file
 * Get file snippet by line range
 */
app.post('/file', async (req: Request, res: Response) => {
  try {
    const parsed = fileSchema.parse(req.body);

    const snippet = await readFileSnippet(REPO_ROOTS, {
      path: parsed.path,
      start: parsed.start,
      end: parsed.end
    });

    res.json({
      success: true,
      ...snippet
    });
  } catch (error: any) {
    console.error('File read error:', error);

    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors
      });
    }

    res.status(error.message.includes('Access denied') ? 403 : 500).json({
      success: false,
      error: error.message || 'File read failed'
    });
  }
});

/**
 * POST /file-info
 * Get file metadata without reading content
 */
app.post('/file-info', async (req: Request, res: Response) => {
  try {
    const { path } = z.object({ path: z.string().min(1) }).parse(req.body);

    const info = await getFileInfo(REPO_ROOTS, path);

    res.json({
      success: true,
      ...info
    });
  } catch (error: any) {
    console.error('File info error:', error);

    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get file info'
    });
  }
});

/**
 * GET /health
 * Health check endpoint
 */
app.get('/health', async (req: Request, res: Response) => {
  const ripgrepInstalled = await checkRipgrepInstalled();

  res.json({
    status: ripgrepInstalled ? 'ok' : 'degraded',
    ripgrep_installed: ripgrepInstalled,
    repo_count: REPO_ROOTS.length,
    repos: REPO_ROOTS,
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /
 * Root endpoint
 */
app.get('/', (req: Request, res: Response) => {
  res.json({
    name: 'LocalSearch API',
    version: '1.0.0',
    endpoints: {
      'POST /search': 'Search code with query',
      'POST /file': 'Get file snippet by line range',
      'POST /file-info': 'Get file metadata',
      'GET /health': 'Health check'
    }
  });
});

// ==========================================
// Error Handler
// ==========================================

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// ==========================================
// Start Server
// ==========================================

async function startServer() {
  // Check ripgrep before starting
  const rgInstalled = await checkRipgrepInstalled();
  if (!rgInstalled) {
    console.warn('WARNING: ripgrep (rg) is not installed or not in PATH');
    console.warn('Search functionality will not work properly');
    console.warn('Install ripgrep: https://github.com/BurntSushi/ripgrep#installation');
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`✓ LocalSearch API server running on http://localhost:${PORT}`);
    console.log(`✓ Monitoring ${REPO_ROOTS.length} repository root(s)`);
    console.log(`✓ Ripgrep status: ${rgInstalled ? 'installed' : 'NOT FOUND'}`);
  });
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

startServer();
