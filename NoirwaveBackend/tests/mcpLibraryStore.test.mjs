import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import {
  NoirwaveMCPLibraryStore,
  confirmationPhrase,
} from "../src/mcpLibraryStore.mjs";

const sampleSnapshot = () => ({
  version: 1,
  updatedAt: "2026-06-10T12:00:00.000Z",
  permissions: {
    readLibrary: true,
    editPlaylists: true,
    editMetadata: true,
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
    {
      id: "track-2",
      title: "Acid Window",
      artist: "Glass Relay",
      album: "Midnight Utility",
      duration: 180,
      durationLabel: "3:00",
      kind: "Track",
      catalogID: "1002",
      previewURL: null,
      artistCatalogID: "artist-2",
      albumCatalogID: "album-2",
      artworkURL: null,
      rank: 620000,
      fanCount: null,
      albumCount: null,
      trackCount: null,
      releaseDate: "2025-11-02",
      recordType: "studio",
      trackPosition: 2,
      discNumber: 1,
      liked: true,
      saved: false,
      tags: ["acid", "night"],
      metadata: {},
    },
    {
      id: "track-3",
      title: "Short Intercom",
      artist: "Glass Relay",
      album: "Midnight Utility",
      duration: 45,
      durationLabel: "0:45",
      kind: "Track",
      catalogID: "1003",
      previewURL: null,
      artistCatalogID: "artist-2",
      albumCatalogID: "album-2",
      artworkURL: "https://example.test/short.jpg",
      rank: 300000,
      fanCount: null,
      albumCount: null,
      trackCount: null,
      releaseDate: "2025-11-02",
      recordType: "studio",
      trackPosition: 3,
      discNumber: 1,
      liked: false,
      saved: false,
      tags: [],
      metadata: {},
    },
  ],
  artists: [
    { id: "nova-unit", name: "NOVA UNIT", trackCount: 1, albumCount: 1 },
    { id: "glass-relay", name: "Glass Relay", trackCount: 2, albumCount: 1 },
  ],
  albums: [
    { id: "afterimage-nova-unit", title: "Afterimage", artist: "NOVA UNIT", trackCount: 1 },
    { id: "midnight-utility-glass-relay", title: "Midnight Utility", artist: "Glass Relay", trackCount: 2 },
  ],
  playlists: [
    {
      id: "playlist-1",
      name: "Late Drive",
      description: "Existing playlist",
      trackIds: ["track-1"],
      tracks: [],
      createdAt: "2026-06-10T12:00:00.000Z",
      updatedAt: "2026-06-10T12:00:00.000Z",
    },
  ],
});

const withTempStore = async (fn) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "noirwave-mcp-"));
  const store = new NoirwaveMCPLibraryStore({ root });
  await store.writeSnapshot(sampleSnapshot());
  try {
    await fn(store, root);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
};

test("exposes library resources and searchable track records", async () => {
  await withTempStore(async (store) => {
    const resourceList = await store.listResources();
    assert.deepEqual(resourceList.map((item) => item.uri).sort(), [
      "library://albums",
      "library://artists",
      "library://playlist/playlist-1",
      "library://playlists",
      "library://track/track-1",
      "library://track/track-2",
      "library://track/track-3",
      "library://tracks",
    ]);

    const withoutCovers = await store.searchTracks("night", { hasArtwork: false });
    assert.deepEqual(withoutCovers.map((track) => track.id), ["track-2"]);

    const playlist = await store.readResource("library://playlist/playlist-1");
    assert.equal(playlist.name, "Late Drive");
    assert.deepEqual(playlist.tracks.map((track) => track.id), ["track-1"]);
  });
});

test("creates playlists, adds tracks, reorders with confirmation preview, and logs activity", async () => {
  await withTempStore(async (store) => {
    const created = await store.createPlaylist({ name: "Acid Night", description: "Synthwave set" });
    assert.equal(created.name, "Acid Night");

    const added = await store.addTrackToPlaylist({ playlistId: created.id, trackId: "track-1" });
    assert.equal(added.trackIds.length, 1);

    await store.addTrackToPlaylist({ playlistId: created.id, trackId: "track-2" });
    const preview = await store.reorderPlaylistTracks({
      playlistId: created.id,
      trackIds: ["track-2", "track-1"],
    });
    assert.equal(preview.requiresConfirmation, true);
    assert.deepEqual(preview.preview.after, ["track-2", "track-1"]);

    const applied = await store.reorderPlaylistTracks({
      playlistId: created.id,
      trackIds: ["track-2", "track-1"],
      confirm: true,
      confirmation: preview.confirmation,
    });
    assert.deepEqual(applied.trackIds, ["track-2", "track-1"]);

    const log = await store.readActivityLog();
    assert.equal(log[0].action, "reorder_playlist_tracks");
    assert.ok(log.some((entry) => entry.action === "create_playlist"));
  });
});

test("protects destructive playlist deletion with permission and confirmation", async () => {
  await withTempStore(async (store) => {
    await assert.rejects(
      () => store.deletePlaylist({ playlistId: "playlist-1", confirm: true, confirmation: "delete playlist playlist-1" }),
      /Permission denied: delete playlists/
    );

    const snapshot = await store.readSnapshot();
    snapshot.permissions.deletePlaylists = true;
    await store.writeSnapshot(snapshot);

    const preview = await store.deletePlaylist({ playlistId: "playlist-1" });
    assert.equal(preview.requiresConfirmation, true);
    assert.equal(preview.confirmation, confirmationPhrase("delete_playlist", "playlist-1"));

    await assert.rejects(
      () => store.deletePlaylist({ playlistId: "playlist-1", confirm: true, confirmation: "wrong" }),
      /Confirmation required/
    );

    const deleted = await store.deletePlaylist({
      playlistId: "playlist-1",
      confirm: true,
      confirmation: preview.confirmation,
    });
    assert.equal(deleted.deletedPlaylist.id, "playlist-1");
    assert.deepEqual((await store.listPlaylists()).map((playlist) => playlist.id), []);
  });
});

test("previews smart playlist before applying and can enforce unique artists", async () => {
  await withTempStore(async (store) => {
    const preview = await store.createSmartPlaylist({
      prompt: "Собери плейлист из любимых night, но без повторов артистов на 7 минут",
    });
    assert.equal(preview.requiresConfirmation, true);
    assert.deepEqual(preview.preview.tracks.map((track) => track.artist), ["NOVA UNIT", "Glass Relay"]);

    const playlist = await store.createSmartPlaylist({
      prompt: "Собери плейлист из любимых night, но без повторов артистов на 7 минут",
      confirm: true,
      confirmation: preview.confirmation,
    });
    assert.equal(playlist.name, "Smart: любимых night");
    assert.deepEqual(playlist.trackIds, ["track-1", "track-2"]);
  });
});

test("updates tags and metadata only when metadata permission is enabled", async () => {
  await withTempStore(async (store) => {
    await store.tagTrack({ trackId: "track-1", tags: ["Night", "drive"] });
    await store.updateTrackMetadata({ trackId: "track-1", metadata: { mood: "nocturnal" } });

    const track = await store.getTrack("track-1");
    assert.deepEqual(track.tags, ["drive", "night", "synthwave"]);
    assert.equal(track.metadata.mood, "nocturnal");

    const snapshot = await store.readSnapshot();
    snapshot.permissions.editMetadata = false;
    await store.writeSnapshot(snapshot);

    await assert.rejects(
      () => store.tagTrack({ trackId: "track-1", tags: ["blocked"] }),
      /Permission denied: edit metadata/
    );
  });
});
