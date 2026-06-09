import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "node:http";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

import { NoirwaveMCPLibraryStore } from "../src/mcpLibraryStore.mjs";
import { createNoirwaveMCPHttpApp } from "../src/mcpHttpServer.mjs";

const httpToken = "test-noirwave-mcp-token-000000000000";

const snapshot = () => ({
  version: 1,
  updatedAt: "2026-06-10T12:00:00.000Z",
  permissions: {
    readLibrary: true,
    editPlaylists: true,
    editMetadata: false,
    deletePlaylists: false,
    playbackControl: false,
  },
  tracks: [
    {
      id: "track-1",
      title: "Night Voltage",
      artist: "NOVA UNIT",
      album: "Afterimage",
      duration: 240,
      durationLabel: "4:00",
      kind: "Track",
      catalogID: "1001",
      previewURL: null,
      artistCatalogID: "artist-1",
      albumCatalogID: "album-1",
      artworkURL: "https://example.test/night.jpg",
      rank: 800000,
      fanCount: null,
      albumCount: null,
      trackCount: null,
      releaseDate: "2026-01-01",
      recordType: "studio",
      trackPosition: 1,
      discNumber: 1,
      liked: true,
      saved: false,
      tags: ["synthwave", "night"],
      metadata: {},
    },
  ],
  artists: [],
  albums: [],
  playlists: [],
});

const listen = async (app) => {
  const server = createServer(app);
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  return {
    server,
    url: new URL(`http://127.0.0.1:${port}/mcp`),
  };
};

const closeServer = (server) => new Promise((resolve) => server.close(resolve));

test("HTTP MCP endpoint rejects requests without bearer token", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "noirwave-mcp-http-auth-"));
  const store = new NoirwaveMCPLibraryStore({ root });
  await store.writeSnapshot(snapshot());

  const app = createNoirwaveMCPHttpApp({ store, root, token: httpToken });
  const { server, url } = await listen(app);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
    });

    assert.equal(response.status, 401);
    assert.match(await response.text(), /Unauthorized MCP request/);
  } finally {
    await closeServer(server);
    await fs.rm(root, { recursive: true, force: true });
  }
});

test("HTTP MCP client can discover tools and mutate playlists with bearer token", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "noirwave-mcp-http-"));
  const store = new NoirwaveMCPLibraryStore({ root });
  await store.writeSnapshot(snapshot());

  const app = createNoirwaveMCPHttpApp({ store, root, token: httpToken });
  const { server, url } = await listen(app);
  const client = new Client({ name: "noirwave-http-test-client", version: "1.0.0" });
  const transport = new StreamableHTTPClientTransport(url, {
    requestInit: {
      headers: {
        authorization: `Bearer ${httpToken}`,
      },
    },
  });

  try {
    await client.connect(transport);

    const tools = await client.listTools();
    assert.ok(tools.tools.some((tool) => tool.name === "add_track_to_playlist"));

    const created = await client.callTool({
      name: "create_playlist",
      arguments: { name: "Remote Agent" },
    });
    const playlistId = created.structuredContent.id;

    const added = await client.callTool({
      name: "add_track_to_playlist",
      arguments: { playlistId, trackId: "track-1" },
    });

    assert.deepEqual(added.structuredContent.trackIds, ["track-1"]);
    const log = await store.readActivityLog();
    assert.equal(log[0].action, "add_track_to_playlist");
  } finally {
    await client.close();
    await closeServer(server);
    await fs.rm(root, { recursive: true, force: true });
  }
});
