import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

import { NoirwaveMCPLibraryStore } from "../src/mcpLibraryStore.mjs";
import { createNoirwaveMCPServer, noirwaveMCPTools } from "../src/mcpServer.mjs";

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

test("MCP client can discover resources/tools and mutate playlists", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "noirwave-mcp-server-"));
  const store = new NoirwaveMCPLibraryStore({ root });
  await store.writeSnapshot(snapshot());

  const server = createNoirwaveMCPServer({ store, root });
  const client = new Client({ name: "noirwave-test-client", version: "1.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

  try {
    await Promise.all([
      server.connect(serverTransport),
      client.connect(clientTransport),
    ]);

    const tools = await client.listTools();
    assert.deepEqual(tools.tools.map((tool) => tool.name).sort(), [...noirwaveMCPTools].sort());

    const resources = await client.listResources();
    assert.ok(resources.resources.some((resource) => resource.uri === "library://tracks"));

    const tracksResource = await client.readResource({ uri: "library://tracks" });
    assert.equal(JSON.parse(tracksResource.contents[0].text)[0].id, "track-1");

    const created = await client.callTool({
      name: "create_playlist",
      arguments: { name: "AI Night" },
    });
    const playlistId = created.structuredContent.id;
    assert.equal(created.structuredContent.name, "AI Night");

    const added = await client.callTool({
      name: "add_track_to_playlist",
      arguments: { playlistId, trackId: "track-1" },
    });
    assert.deepEqual(added.structuredContent.trackIds, ["track-1"]);

    const log = await store.readActivityLog();
    assert.equal(log[0].action, "add_track_to_playlist");
  } finally {
    await client.close();
    await server.close();
    await fs.rm(root, { recursive: true, force: true });
  }
});
