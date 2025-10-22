import fs from 'fs/promises';
import path from 'path';
import { validatePath } from './search';

export interface FileSnippet {
  path: string;
  start: number;
  end: number;
  snippet: string;
  totalLines: number;
}

export interface FileReadOptions {
  path: string;
  start: number;
  end: number;
}

/**
 * Check if file is binary (heuristic check)
 */
async function isBinaryFile(filePath: string): Promise<boolean> {
  try {
    const buffer = await fs.readFile(filePath);
    const sample = buffer.slice(0, Math.min(8000, buffer.length));

    // Check for null bytes (common in binary files)
    for (let i = 0; i < sample.length; i++) {
      if (sample[i] === 0) {
        return true;
      }
    }

    return false;
  } catch {
    return true; // Treat unreadable files as binary
  }
}

/**
 * Detect file encoding (simplified - defaults to UTF-8)
 */
function detectEncoding(buffer: Buffer): BufferEncoding {
  // Check for BOM
  if (buffer.length >= 3 && buffer[0] === 0xEF && buffer[1] === 0xBB && buffer[2] === 0xBF) {
    return 'utf8';
  }

  // Default to UTF-8 (works for Hebrew and English)
  return 'utf8';
}

/**
 * Read file snippet by line range
 */
export async function readFileSnippet(
  allowedRoots: string[],
  options: FileReadOptions
): Promise<FileSnippet> {
  const { path: filePath, start, end } = options;

  // Validate inputs
  if (!filePath || filePath.trim().length === 0) {
    throw new Error('File path is required');
  }

  if (start < 1) {
    throw new Error('Start line must be >= 1');
  }

  if (end < start) {
    throw new Error('End line must be >= start line');
  }

  const lineRange = end - start + 1;
  if (lineRange > 200) {
    throw new Error('Maximum 200 lines per request');
  }

  // Validate path is within allowed roots
  if (!validatePath(filePath, allowedRoots)) {
    throw new Error('Access denied: path is outside allowed repositories');
  }

  // Check if file exists
  const resolvedPath = path.resolve(filePath);
  try {
    await fs.access(resolvedPath, fs.constants.R_OK);
  } catch {
    throw new Error('File not found or not readable');
  }

  // Check if binary
  if (await isBinaryFile(resolvedPath)) {
    throw new Error('Cannot read binary file');
  }

  // Read file with size limit (10MB)
  const stats = await fs.stat(resolvedPath);
  if (stats.size > 10 * 1024 * 1024) {
    throw new Error('File too large (max 10MB)');
  }

  // Read entire file (we need to count lines anyway)
  const buffer = await fs.readFile(resolvedPath);
  const encoding = detectEncoding(buffer);
  const content = buffer.toString(encoding);

  // Split into lines
  const lines = content.split(/\r?\n/);
  const totalLines = lines.length;

  // Validate line range
  if (start > totalLines) {
    throw new Error(`Start line ${start} exceeds file length ${totalLines}`);
  }

  // Extract snippet (1-based indexing)
  const actualEnd = Math.min(end, totalLines);
  const snippetLines = lines.slice(start - 1, actualEnd);
  const snippet = snippetLines.join('\n');

  return {
    path: filePath,
    start,
    end: actualEnd,
    snippet,
    totalLines
  };
}

/**
 * Get file metadata without reading content
 */
export async function getFileInfo(
  allowedRoots: string[],
  filePath: string
): Promise<{ exists: boolean; size: number; lines?: number; isBinary?: boolean }> {
  if (!validatePath(filePath, allowedRoots)) {
    throw new Error('Access denied: path is outside allowed repositories');
  }

  const resolvedPath = path.resolve(filePath);

  try {
    const stats = await fs.stat(resolvedPath);

    if (!stats.isFile()) {
      return { exists: false, size: 0 };
    }

    const isBinary = await isBinaryFile(resolvedPath);

    if (isBinary) {
      return {
        exists: true,
        size: stats.size,
        isBinary: true
      };
    }

    // Count lines for text files
    const buffer = await fs.readFile(resolvedPath);
    const content = buffer.toString('utf8');
    const lines = content.split(/\r?\n/).length;

    return {
      exists: true,
      size: stats.size,
      lines,
      isBinary: false
    };
  } catch {
    return { exists: false, size: 0 };
  }
}
