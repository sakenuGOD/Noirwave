import { timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import {
  NoirwaveMCPLibraryStore,
  defaultMCPRoot,
} from "./mcpLibraryStore.mjs";
import {
  createNoirwaveMCPServer,
  noirwaveMCPTools,
} from "./mcpServer.mjs";

const defaultHost = "127.0.0.1";
const defaultPort = 6615;
const defaultPath = "/mcp";

const jsonRpcError = (response, status, code, message) => {
  if (response.headersSent) return;
  response.status(status).json({
    jsonrpc: "2.0",
    error: { code, message },
    id: null,
  });
};

const bearerToken = (request) => {
  const header = String(request.headers.authorization ?? "");
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? "";
};

const safeTokenEquals = (actual, expected) => {
  const actualBuffer = Buffer.from(String(actual));
  const expectedBuffer = Buffer.from(String(expected));
  return actualBuffer.length === expectedBuffer.length
    && timingSafeEqual(actualBuffer, expectedBuffer);
};

const parseAllowedHosts = (value) =>
  String(value ?? "")
    .split(",")
    .map((host) => host.trim())
    .filter(Boolean);

const isLoopbackHost = (host) =>
  ["127.0.0.1", "localhost", "::1"].includes(host);

export const createNoirwaveMCPHttpApp = ({
  store = new NoirwaveMCPLibraryStore(),
  root = defaultMCPRoot(),
  token = process.env.NOIRWAVE_MCP_HTTP_TOKEN ?? "",
  host = process.env.NOIRWAVE_MCP_HTTP_HOST ?? defaultHost,
  endpointPath = process.env.NOIRWAVE_MCP_HTTP_PATH ?? defaultPath,
  allowedHosts = parseAllowedHosts(process.env.NOIRWAVE_MCP_HTTP_ALLOWED_HOSTS),
} = {}) => {
  if (!token) {
    throw new Error("NOIRWAVE_MCP_HTTP_TOKEN is required for remote MCP HTTP access.");
  }
  if (String(token).length < 24) {
    throw new Error("NOIRWAVE_MCP_HTTP_TOKEN must be at least 24 characters.");
  }
  if (!String(endpointPath).startsWith("/")) {
    throw new Error("NOIRWAVE_MCP_HTTP_PATH must start with '/'.");
  }

  const app = createMcpExpressApp({
    host,
    allowedHosts: allowedHosts.length > 0 ? allowedHosts : undefined,
  });

  const requireBearerToken = (request, response, next) => {
    if (!safeTokenEquals(bearerToken(request), token)) {
      jsonRpcError(response, 401, -32001, "Unauthorized MCP request.");
      return;
    }
    next();
  };

  const handleMCPRequest = async (request, response) => {
    const server = createNoirwaveMCPServer({ store, root });
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
    });

    response.on("close", () => {
      transport.close().catch(() => {});
      server.close().catch(() => {});
    });

    try {
      await server.connect(transport);
      await transport.handleRequest(request, response, request.body);
    } catch (error) {
      console.error(`[noirwave-mcp-http] ${error.stack ?? error.message}`);
      jsonRpcError(response, 500, -32603, "Internal MCP server error.");
    }
  };

  app.post(endpointPath, requireBearerToken, handleMCPRequest);
  app.get(endpointPath, requireBearerToken, (_request, response) => {
    jsonRpcError(response, 405, -32000, "Method not allowed.");
  });
  app.delete(endpointPath, requireBearerToken, (_request, response) => {
    jsonRpcError(response, 405, -32000, "Method not allowed.");
  });

  app.get("/health", (_request, response) => {
    response.json({
      ok: true,
      name: "noirwave-mcp-http",
      transport: "streamable-http",
      endpoint: endpointPath,
      root,
      tools: noirwaveMCPTools,
    });
  });

  return app;
};

export const runNoirwaveMCPHttpServer = async ({
  store = new NoirwaveMCPLibraryStore(),
  host = process.env.NOIRWAVE_MCP_HTTP_HOST ?? defaultHost,
  port = Number(process.env.NOIRWAVE_MCP_HTTP_PORT ?? defaultPort),
  endpointPath = process.env.NOIRWAVE_MCP_HTTP_PATH ?? defaultPath,
  token = process.env.NOIRWAVE_MCP_HTTP_TOKEN ?? "",
} = {}) => {
  if (!Number.isInteger(port) || port <= 0 || port > 65535) {
    throw new Error(`Invalid NOIRWAVE_MCP_HTTP_PORT: ${port}`);
  }

  await store.ensureFiles();
  const app = createNoirwaveMCPHttpApp({ store, host, endpointPath, token });
  const endpoint = `http://${host}:${port}${endpointPath}`;
  const server = createServer(app);

  const writeRunningStatus = async () => {
    await store.writeStatus({
      state: "running",
      pid: process.pid,
      root: store.root,
      transport: "streamable-http",
      endpoint,
      tools: noirwaveMCPTools,
    });
  };

  await writeRunningStatus();
  const heartbeat = setInterval(() => {
    writeRunningStatus().catch((error) => {
      console.error(`[noirwave-mcp-http] failed to write heartbeat: ${error.message}`);
    });
  }, 2_500);

  const stop = async () => {
    clearInterval(heartbeat);
    await store.writeStatus({
      state: "stopped",
      pid: process.pid,
      root: store.root,
      transport: "streamable-http",
      endpoint,
      tools: noirwaveMCPTools,
    }).catch(() => {});
    await new Promise((resolve) => server.close(resolve));
  };

  process.once("SIGINT", () => {
    stop().finally(() => process.exit(0));
  });
  process.once("SIGTERM", () => {
    stop().finally(() => process.exit(0));
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, resolve);
  });

  const exposure = isLoopbackHost(host)
    ? "loopback-only; expose with a reverse tunnel if needed"
    : "network-facing; keep the bearer token secret and restrict the tunnel/proxy";
  console.error(`[noirwave-mcp-http] listening on ${endpoint} (${exposure})`);

  return { app, server, endpoint, stop };
};

if (import.meta.url === `file://${process.argv[1]}`) {
  runNoirwaveMCPHttpServer().catch((error) => {
    console.error(`[noirwave-mcp-http] ${error.stack ?? error.message}`);
    process.exit(1);
  });
}
