import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import fs from 'fs';

const execAsync = promisify(exec);

/**
 * Get ripgrep command - checks for local rg.exe first, then PATH
 */
function getRipgrepCommand(): string {
  // Check for local ripgrep in project directory
  const localRg = path.join(__dirname, '..', 'rg.exe');
  if (fs.existsSync(localRg)) {
    return `"${localRg}"`;
  }
  return 'rg';
}

export interface SearchResult {
  path: string;
  line: number;
  text: string;
}

export interface SearchOptions {
  query: string;
  maxResults?: number;
  timeout?: number;
}

/**
 * Validate that a path is within allowed repository roots
 */
export function validatePath(inputPath: string, allowedRoots: string[]): boolean {
  const resolved = path.resolve(inputPath);
  return allowedRoots.some(root => {
    const resolvedRoot = path.resolve(root);
    return resolved.startsWith(resolvedRoot);
  });
}

/**
 * Sanitize search query to prevent command injection
 */
export function sanitizeQuery(query: string): string {
  // Remove dangerous characters while preserving regex functionality
  // Allow: alphanumeric, spaces, common regex chars, Hebrew Unicode
  const sanitized = query.replace(/[;&|`$()]/g, '');
  return sanitized.substring(0, 500); // Max length
}

/**
 * Search code using ripgrep across allowed repositories
 */
export async function searchCode(
  repoRoots: string[],
  options: SearchOptions
): Promise<SearchResult[]> {
  const { query, maxResults = 30, timeout = 5000 } = options;

  if (!query || query.trim().length === 0) {
    throw new Error('Query cannot be empty');
  }

  const sanitizedQuery = sanitizeQuery(query);
  const results: SearchResult[] = [];

  // Build ripgrep command with JSON output
  // -i: case insensitive
  // -n: show line numbers
  // --json: JSON output
  // --max-count: limit results per file
  // --max-filesize: skip large files (10MB)
  const maxPerFile = Math.ceil(maxResults / repoRoots.length);

  for (const root of repoRoots) {
    try {
      // Get ripgrep command (local or PATH)
      const rgCommand = getRipgrepCommand();

      const command = `${rgCommand} -i -n --json --max-count ${maxPerFile} --max-filesize 10M "${sanitizedQuery}" "${root}"`;

      const { stdout } = await execAsync(command, {
        timeout,
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
        encoding: 'utf8'
      });

      // Parse JSON lines from ripgrep
      const lines = stdout.trim().split('\n');
      for (const line of lines) {
        if (!line) continue;

        try {
          const parsed = JSON.parse(line);

          // ripgrep outputs different types of JSON lines
          // We only want "match" type
          if (parsed.type === 'match') {
            const data = parsed.data;
            results.push({
              path: data.path.text,
              line: data.line_number,
              text: data.lines.text.trim()
            });

            if (results.length >= maxResults) {
              return results.slice(0, maxResults);
            }
          }
        } catch (parseErr) {
          // Skip malformed JSON lines
          continue;
        }
      }
    } catch (error: any) {
      // If ripgrep returns exit code 1, it means no matches found (not an error)
      if (error.code === 1) {
        continue;
      }

      // For other errors, log but continue with other repos
      console.error(`Search error in ${root}:`, error.message);
    }
  }

  return results.slice(0, maxResults);
}

/**
 * Check if ripgrep is installed
 */
export async function checkRipgrepInstalled(): Promise<boolean> {
  try {
    const rgCommand = getRipgrepCommand();
    await execAsync(`${rgCommand} --version`, { timeout: 2000 });
    return true;
  } catch {
    return false;
  }
}
