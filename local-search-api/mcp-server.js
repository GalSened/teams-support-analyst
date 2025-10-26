#!/usr/bin/env node

/**
 * MCP Server for LocalSearch API
 * Provides codebase search capabilities to Claude via MCP protocol
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} = require('@modelcontextprotocol/sdk/types.js');

const LOCALSEARCH_API_URL = process.env.LOCALSEARCH_API_URL || 'http://localhost:3001';

// MCP Server
const server = new Server(
  {
    name: 'local-search',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper function to call LocalSearch API
async function callLocalSearch(endpoint, body) {
  try {
    const response = await fetch(`${LOCALSEARCH_API_URL}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`LocalSearch API error: ${response.status} - ${errorText}`);
    }

    return await response.json();
  } catch (error) {
    throw new Error(`Failed to call LocalSearch API: ${error.message}`);
  }
}

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'search_code',
        description: 'Search for code across all configured repositories (user-backend, wesign-client-DEV, wesignsigner-client-app-DEV). Returns matching code snippets with file paths and line numbers.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query (e.g., function name, class name, or code pattern)',
            },
            maxResults: {
              type: 'number',
              description: 'Maximum number of results to return (default: 10)',
              default: 10,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'get_file_content',
        description: 'Get the full content of a specific file from any of the configured repositories.',
        inputSchema: {
          type: 'object',
          properties: {
            path: {
              type: 'string',
              description: 'File path (can be relative to any repository root)',
            },
            startLine: {
              type: 'number',
              description: 'Optional: Start line number (1-based)',
            },
            endLine: {
              type: 'number',
              description: 'Optional: End line number (1-based)',
            },
          },
          required: ['path'],
        },
      },
      {
        name: 'get_file_info',
        description: 'Get metadata about a file (size, line count, last modified, etc.)',
        inputSchema: {
          type: 'object',
          properties: {
            path: {
              type: 'string',
              description: 'File path (can be relative to any repository root)',
            },
          },
          required: ['path'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'search_code': {
        const results = await callLocalSearch('/search', {
          query: args.query,
          maxResults: args.maxResults || 10,
        });

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(results, null, 2),
            },
          ],
        };
      }

      case 'get_file_content': {
        // Normalize Windows paths to forward slashes to prevent JSON parsing errors
        const normalizedPath = args.path.replace(/\\/g, '/');

        const result = await callLocalSearch('/file', {
          path: normalizedPath,
          start: args.startLine,
          end: args.endLine,
        });

        return {
          content: [
            {
              type: 'text',
              text: result.content || '',
            },
          ],
        };
      }

      case 'get_file_info': {
        // Normalize Windows paths to forward slashes to prevent JSON parsing errors
        const normalizedPath = args.path.replace(/\\/g, '/');

        const result = await callLocalSearch('/file-info', {
          path: normalizedPath,
        });

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('LocalSearch MCP server running');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
