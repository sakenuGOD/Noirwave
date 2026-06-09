import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";

import {
  NoirwaveMCPLibraryStore,
  defaultMCPRoot,
  toToolError,
  toToolResult,
} from "./mcpLibraryStore.mjs";

export const noirwaveMCPTools = [
  "search_tracks",
  "get_track",
  "list_playlists",
  "create_playlist",
  "rename_playlist",
  "delete_playlist",
  "add_track_to_playlist",
  "remove_track_from_playlist",
  "reorder_playlist_tracks",
  "create_smart_playlist",
  "find_similar_tracks",
  "get_library_stats",
  "tag_track",
  "update_track_metadata",
];

const jsonResource = (uri, value) => ({
  contents: [
    {
      uri,
      mimeType: "application/json",
      text: JSON.stringify(value, null, 2),
    },
  ],
});

const objectSchema = z.record(z.string(), z.unknown());

const filtersSchema = z.object({
  artist: z.string().optional(),
  album: z.string().optional(),
  liked: z.boolean().optional(),
  saved: z.boolean().optional(),
  hasArtwork: z.boolean().optional(),
  missingArtwork: z.boolean().optional(),
  minDuration: z.number().optional(),
  maxDuration: z.number().optional(),
  minDurationSeconds: z.number().optional(),
  maxDurationSeconds: z.number().optional(),
  tags: z.array(z.string()).optional(),
  limit: z.number().int().min(1).max(500).optional(),
}).passthrough();

const registerTool = (server, name, config, handler) => {
  server.registerTool(name, config, async (args) => {
    try {
      return toToolResult(await handler(args ?? {}));
    } catch (error) {
      return toToolError(error);
    }
  });
};

export const createNoirwaveMCPServer = ({ store = new NoirwaveMCPLibraryStore(), root = defaultMCPRoot() } = {}) => {
  const server = new McpServer(
    {
      name: "noirwave-library",
      version: "0.1.0",
    },
    {
      capabilities: {
        logging: {},
      },
      instructions: [
        "Expose only the Noirwave music library stored in the app MCP root.",
        "For destructive or mass operations, call the tool once to preview and then repeat with confirm=true and the returned confirmation phrase.",
        `Library root: ${root}`,
      ].join("\n"),
    }
  );

  server.registerResource(
    "library-tracks",
    "library://tracks",
    {
      title: "Noirwave Tracks",
      description: "All known tracks in the Noirwave music library.",
      mimeType: "application/json",
    },
    async () => jsonResource("library://tracks", await store.readResource("library://tracks"))
  );

  server.registerResource(
    "library-artists",
    "library://artists",
    {
      title: "Noirwave Artists",
      description: "Artists derived from the Noirwave track library.",
      mimeType: "application/json",
    },
    async () => jsonResource("library://artists", await store.readResource("library://artists"))
  );

  server.registerResource(
    "library-albums",
    "library://albums",
    {
      title: "Noirwave Albums",
      description: "Albums derived from the Noirwave track library.",
      mimeType: "application/json",
    },
    async () => jsonResource("library://albums", await store.readResource("library://albums"))
  );

  server.registerResource(
    "library-playlists",
    "library://playlists",
    {
      title: "Noirwave Playlists",
      description: "Local Noirwave playlists.",
      mimeType: "application/json",
    },
    async () => jsonResource("library://playlists", await store.readResource("library://playlists"))
  );

  server.registerResource(
    "library-playlist",
    new ResourceTemplate("library://playlist/{id}", {
      list: async () => ({
        resources: (await store.listPlaylists()).map((playlist) => ({
          uri: `library://playlist/${playlist.id}`,
          name: playlist.name,
          title: playlist.name,
          description: playlist.description ?? `${playlist.trackIds.length} tracks`,
          mimeType: "application/json",
        })),
      }),
      complete: {
        id: async (value) => (await store.listPlaylists())
          .map((playlist) => playlist.id)
          .filter((id) => id.includes(value)),
      },
    }),
    {
      title: "Noirwave Playlist",
      description: "Contents of one Noirwave playlist.",
      mimeType: "application/json",
    },
    async (uri) => jsonResource(uri.href, await store.readResource(uri.href))
  );

  server.registerResource(
    "library-track",
    new ResourceTemplate("library://track/{id}", {
      list: async () => ({
        resources: (await store.readResource("library://tracks")).map((track) => ({
          uri: `library://track/${track.id}`,
          name: `${track.title} - ${track.artist}`,
          title: track.title,
          description: `${track.artist} · ${track.album}`,
          mimeType: "application/json",
        })),
      }),
      complete: {
        id: async (value) => (await store.readResource("library://tracks"))
          .map((track) => track.id)
          .filter((id) => id.includes(value)),
      },
    }),
    {
      title: "Noirwave Track",
      description: "Full metadata for one Noirwave track.",
      mimeType: "application/json",
    },
    async (uri) => jsonResource(uri.href, await store.readResource(uri.href))
  );

  registerTool(server, "search_tracks", {
    title: "Search Tracks",
    description: "Search the Noirwave library by text and filters such as artist, album, liked, tags, artwork, and duration.",
    inputSchema: {
      query: z.string().default(""),
      filters: filtersSchema.optional().default({}),
    },
    annotations: {
      readOnlyHint: true,
      openWorldHint: false,
    },
  }, ({ query, filters }) => store.searchTracks(query, filters));

  registerTool(server, "get_track", {
    title: "Get Track",
    description: "Get full metadata for a Noirwave track.",
    inputSchema: {
      trackId: z.string(),
    },
    annotations: {
      readOnlyHint: true,
      openWorldHint: false,
    },
  }, ({ trackId }) => store.getTrack(trackId));

  registerTool(server, "list_playlists", {
    title: "List Playlists",
    description: "List Noirwave playlists.",
    inputSchema: {},
    annotations: {
      readOnlyHint: true,
      openWorldHint: false,
    },
  }, () => store.listPlaylists());

  registerTool(server, "create_playlist", {
    title: "Create Playlist",
    description: "Create a new local Noirwave playlist.",
    inputSchema: {
      name: z.string().min(1),
      description: z.string().optional(),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, ({ name, description }) => store.createPlaylist({ name, description }));

  registerTool(server, "rename_playlist", {
    title: "Rename Playlist",
    description: "Rename a local Noirwave playlist.",
    inputSchema: {
      playlistId: z.string(),
      name: z.string().min(1),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, ({ playlistId, name }) => store.renamePlaylist({ playlistId, name }));

  registerTool(server, "delete_playlist", {
    title: "Delete Playlist",
    description: "Preview or delete a playlist. Deletion requires delete-playlists permission plus confirm=true and the returned confirmation phrase.",
    inputSchema: {
      playlistId: z.string(),
      confirm: z.boolean().optional().default(false),
      confirmation: z.string().optional().default(""),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      openWorldHint: false,
    },
  }, (args) => store.deletePlaylist(args));

  registerTool(server, "add_track_to_playlist", {
    title: "Add Track To Playlist",
    description: "Add one track to a local Noirwave playlist.",
    inputSchema: {
      playlistId: z.string(),
      trackId: z.string(),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, (args) => store.addTrackToPlaylist(args));

  registerTool(server, "remove_track_from_playlist", {
    title: "Remove Track From Playlist",
    description: "Preview or remove one track from a playlist. Removal requires confirm=true and the returned confirmation phrase.",
    inputSchema: {
      playlistId: z.string(),
      trackId: z.string(),
      confirm: z.boolean().optional().default(false),
      confirmation: z.string().optional().default(""),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      openWorldHint: false,
    },
  }, (args) => store.removeTrackFromPlaylist(args));

  registerTool(server, "reorder_playlist_tracks", {
    title: "Reorder Playlist Tracks",
    description: "Preview or apply a playlist order. Reordering requires confirm=true and the returned confirmation phrase.",
    inputSchema: {
      playlistId: z.string(),
      trackIds: z.array(z.string()),
      confirm: z.boolean().optional().default(false),
      confirmation: z.string().optional().default(""),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, (args) => store.reorderPlaylistTracks(args));

  registerTool(server, "create_smart_playlist", {
    title: "Create Smart Playlist",
    description: "Build a playlist from a natural language prompt or rules. The first call returns a preview; apply with confirm=true and the returned confirmation phrase.",
    inputSchema: {
      prompt: z.string().optional().default(""),
      rules: objectSchema.optional().default({}),
      confirm: z.boolean().optional().default(false),
      confirmation: z.string().optional().default(""),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, (args) => store.createSmartPlaylist(args));

  registerTool(server, "find_similar_tracks", {
    title: "Find Similar Tracks",
    description: "Find tracks similar to a seed track by artist, album, tags, duration, and popularity.",
    inputSchema: {
      trackId: z.string(),
      limit: z.number().int().min(1).max(100).optional().default(12),
    },
    annotations: {
      readOnlyHint: true,
      openWorldHint: false,
    },
  }, (args) => store.findSimilarTracks(args));

  registerTool(server, "get_library_stats", {
    title: "Get Library Stats",
    description: "Summarize the Noirwave library and surface missing artwork and potential duplicate groups.",
    inputSchema: {},
    annotations: {
      readOnlyHint: true,
      openWorldHint: false,
    },
  }, () => store.getLibraryStats());

  registerTool(server, "tag_track", {
    title: "Tag Track",
    description: "Attach tags to a track. Requires edit-metadata permission.",
    inputSchema: {
      trackId: z.string(),
      tags: z.array(z.string()).min(1),
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, (args) => store.tagTrack(args));

  registerTool(server, "update_track_metadata", {
    title: "Update Track Metadata",
    description: "Add or replace MCP-visible metadata fields for a track. Requires edit-metadata permission.",
    inputSchema: {
      trackId: z.string(),
      metadata: objectSchema,
    },
    annotations: {
      readOnlyHint: false,
      openWorldHint: false,
    },
  }, (args) => store.updateTrackMetadata(args));

  return server;
};

export const runNoirwaveMCPServer = async ({ store = new NoirwaveMCPLibraryStore() } = {}) => {
  await store.ensureFiles();
  await store.writeStatus({
    state: "running",
    pid: process.pid,
    root: store.root,
    transport: "stdio",
    tools: noirwaveMCPTools,
  });

  const heartbeat = setInterval(() => {
    store.writeStatus({
      state: "running",
      pid: process.pid,
      root: store.root,
      transport: "stdio",
      tools: noirwaveMCPTools,
    }).catch((error) => {
      console.error(`[noirwave-mcp] failed to write heartbeat: ${error.message}`);
    });
  }, 2_500);

  const stop = async () => {
    clearInterval(heartbeat);
    await store.writeStatus({
      state: "stopped",
      pid: process.pid,
      root: store.root,
      transport: "stdio",
      tools: noirwaveMCPTools,
    }).catch(() => {});
  };

  process.once("SIGINT", () => {
    stop().finally(() => process.exit(0));
  });
  process.once("SIGTERM", () => {
    stop().finally(() => process.exit(0));
  });
  process.once("beforeExit", () => {
    clearInterval(heartbeat);
  });

  const server = createNoirwaveMCPServer({ store, root: store.root });
  await server.connect(new StdioServerTransport());
};

if (import.meta.url === `file://${process.argv[1]}`) {
  runNoirwaveMCPServer().catch((error) => {
    console.error(`[noirwave-mcp] ${error.stack ?? error.message}`);
    process.exit(1);
  });
}
