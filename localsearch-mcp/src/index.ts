#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';

const LOCALSEARCH_API_URL = process.env.LOCALSEARCH_API_URL || 'http://localhost:3001';

interface SearchResult {
  path: string;
  line: number;
  text: string;
}

interface FileSnippet {
  path: string;
  start: number;
  end: number;
  snippet: string;
  totalLines: number;
}

/**
 * LocalSearch MCP Server
 * Provides code search and file reading capabilities via MCP protocol
 */
class LocalSearchMCPServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'localsearch-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();

    // Error handling
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'search_code',
          description:
            'Search for code across local repositories using regex or text patterns. ' +
            'Returns file paths, line numbers, and matching text. Use this to find ' +
            'functions, classes, error messages, or any code pattern.',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Search query (text or regex pattern). Example: "function.*Login" or "getUserInfo"',
              },
              max_results: {
                type: 'number',
                description: 'Maximum number of results to return (default: 30, max: 100)',
                default: 30,
              },
            },
            required: ['query'],
          },
        },
        {
          name: 'read_file',
          description:
            'Read a specific file snippet by line range. Use this after search_code to get ' +
            'more context around the code you found. Provide the exact file path from search results.',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'Absolute file path from search results',
              },
              start: {
                type: 'number',
                description: 'Start line number (1-based)',
                default: 1,
              },
              end: {
                type: 'number',
                description: 'End line number (max 200 lines per request)',
              },
            },
            required: ['path', 'start', 'end'],
          },
        },
        {
          name: 'health_check',
          description: 'Check if LocalSearch API is running and available',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'search_code':
            return await this.handleSearchCode(args);

          case 'read_file':
            return await this.handleReadFile(args);

          case 'health_check':
            return await this.handleHealthCheck();

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error: any) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message || 'Unknown error occurred'}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private async handleSearchCode(args: any) {
    const { query, max_results = 30 } = args;

    if (!query) {
      throw new Error('Query parameter is required');
    }

    const response = await axios.post<{
      success: boolean;
      results: SearchResult[];
      count: number;
    }>(`${LOCALSEARCH_API_URL}/search`, {
      query,
      max_results,
    });

    const { results, count } = response.data;

    if (results.length === 0) {
      return {
        content: [
          {
            type: 'text',
            text: `No results found for query: "${query}"`,
          },
        ],
      };
    }

    // Format results as text
    const formattedResults = results
      .map((r, i) => `${i + 1}. ${r.path}:${r.line}\n   ${r.text}`)
      .join('\n\n');

    return {
      content: [
        {
          type: 'text',
          text: `Found ${count} results:\n\n${formattedResults}`,
        },
      ],
    };
  }

  private async handleReadFile(args: any) {
    const { path, start, end } = args;

    if (!path || !start || !end) {
      throw new Error('path, start, and end parameters are required');
    }

    const response = await axios.post<{
      success: boolean;
    } & FileSnippet>(`${LOCALSEARCH_API_URL}/file`, {
      path,
      start,
      end,
    });

    const { snippet, totalLines } = response.data;

    return {
      content: [
        {
          type: 'text',
          text: `File: ${path}\nLines: ${start}-${end} (total: ${totalLines})\n\n${snippet}`,
        },
      ],
    };
  }

  private async handleHealthCheck() {
    try {
      const response = await axios.get(`${LOCALSEARCH_API_URL}/health`);
      const data = response.data;

      return {
        content: [
          {
            type: 'text',
            text: `LocalSearch API Status: ${data.status}\nRipgrep installed: ${data.ripgrep_installed}\nRepositories: ${data.repo_count}`,
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `LocalSearch API is not available: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('LocalSearch MCP server running on stdio');
  }
}

// Start the server
const server = new LocalSearchMCPServer();
server.run().catch(console.error);
