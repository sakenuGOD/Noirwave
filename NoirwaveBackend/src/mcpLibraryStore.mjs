import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";

const libraryFile = "library.json";
const permissionsFile = "mcp-config.json";
const activityLogFile = "activity-log.json";
const statusFile = "mcp-status.json";
const snapshotVersion = 1;
const maxActivityEntries = 120;

const defaultPermissions = Object.freeze({
  readLibrary: true,
  editPlaylists: true,
  editMetadata: false,
  deletePlaylists: false,
  playbackControl: false,
});

export const defaultMCPRoot = () => {
  if (process.env.NOIRWAVE_MCP_ROOT) return process.env.NOIRWAVE_MCP_ROOT;
  return path.join(os.homedir(), "Library", "Application Support", "Noirwave", "MCP");
};

export const confirmationPhrase = (action, id) => `${action}:${id}`;

const nowISO = () => new Date().toISOString();

const normalizeText = (value) =>
  String(value ?? "")
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();

const tokenList = (value) => normalizeText(value).split(/\s+/u).filter(Boolean);

const uniqueLowercase = (values) => [
  ...new Set(
    values
      .map((value) => normalizeText(value))
      .filter(Boolean)
  ),
].sort((lhs, rhs) => lhs.localeCompare(rhs));

const playlistName = (name) => String(name ?? "").trim() || "New Playlist";

const textContent = (payload) => ({
  content: [
    {
      type: "text",
      text: typeof payload === "string" ? payload : JSON.stringify(payload, null, 2),
    },
  ],
});

export const toToolResult = (payload) => ({
  ...textContent(payload),
  structuredContent: payload,
});

export const toToolError = (error) => ({
  isError: true,
  ...textContent({
    error: {
      code: error?.code ?? "mcp_library_error",
      message: error?.message ?? String(error),
    },
  }),
});

const ensureObject = (value) => value && typeof value === "object" && !Array.isArray(value);

const sortedByName = (items, key) =>
  [...items].sort((lhs, rhs) => String(lhs[key] ?? "").localeCompare(String(rhs[key] ?? ""), undefined, {
    sensitivity: "base",
  }));

const groupedBy = (items, keyForItem) => {
  const groups = new Map();
  for (const item of items) {
    const key = keyForItem(item);
    const group = groups.get(key) ?? [];
    group.push(item);
    groups.set(key, group);
  }
  return groups;
};

const trackText = (track) => [
  track.title,
  track.artist,
  track.album,
  ...(Array.isArray(track.tags) ? track.tags : []),
  ...Object.values(ensureObject(track.metadata) ? track.metadata : {}),
].join(" ");

const trackScore = (track, query) => {
  const normalizedQuery = normalizeText(query);
  if (!normalizedQuery) return 1;

  const haystack = normalizeText(trackText(track));
  if (haystack === normalizedQuery) return 1000;
  if (haystack.includes(normalizedQuery)) return 720;

  const queryTokens = tokenList(normalizedQuery);
  const haystackTokens = new Set(tokenList(haystack));
  const hits = queryTokens.filter((token) => haystackTokens.has(token) || haystack.includes(token)).length;
  if (hits === 0) return 0;

  return hits * 100 + Math.round((hits / queryTokens.length) * 50) + Math.min(Number(track.rank) || 0, 1_000_000) / 20_000;
};

const matchesFilters = (track, filters = {}) => {
  if (filters == null) return true;
  if (!ensureObject(filters)) throw new Error("filters must be an object");

  if (filters.artist && normalizeText(track.artist) !== normalizeText(filters.artist)) return false;
  if (filters.album && normalizeText(track.album) !== normalizeText(filters.album)) return false;
  if (typeof filters.liked === "boolean" && Boolean(track.liked) !== filters.liked) return false;
  if (typeof filters.saved === "boolean" && Boolean(track.saved) !== filters.saved) return false;
  if (typeof filters.hasArtwork === "boolean" && Boolean(track.artworkURL) !== filters.hasArtwork) return false;
  if (typeof filters.missingArtwork === "boolean" && !Boolean(track.artworkURL) !== filters.missingArtwork) return false;
  if (Number.isFinite(filters.minDuration) && Number(track.duration) < filters.minDuration) return false;
  if (Number.isFinite(filters.maxDuration) && Number(track.duration) > filters.maxDuration) return false;
  if (Number.isFinite(filters.minDurationSeconds) && Number(track.duration) < filters.minDurationSeconds) return false;
  if (Number.isFinite(filters.maxDurationSeconds) && Number(track.duration) > filters.maxDurationSeconds) return false;

  if (Array.isArray(filters.tags) && filters.tags.length > 0) {
    const trackTags = new Set((track.tags ?? []).map((tag) => normalizeText(tag)));
    if (!filters.tags.every((tag) => trackTags.has(normalizeText(tag)))) return false;
  }

  return true;
};

const trackRecord = (track) => ({
  id: String(track.id),
  title: String(track.title ?? "Untitled Track"),
  artist: String(track.artist ?? "Unknown Artist"),
  album: String(track.album ?? "Unknown Album"),
  duration: Number(track.duration) || 0,
  durationLabel: String(track.durationLabel ?? durationLabel(track.duration)),
  kind: String(track.kind ?? "Track"),
  catalogID: track.catalogID ?? null,
  previewURL: track.previewURL ?? null,
  artistCatalogID: track.artistCatalogID ?? null,
  albumCatalogID: track.albumCatalogID ?? null,
  artworkURL: track.artworkURL ?? null,
  rank: Number.isFinite(track.rank) ? track.rank : null,
  fanCount: Number.isFinite(track.fanCount) ? track.fanCount : null,
  albumCount: Number.isFinite(track.albumCount) ? track.albumCount : null,
  trackCount: Number.isFinite(track.trackCount) ? track.trackCount : null,
  releaseDate: track.releaseDate ?? null,
  recordType: track.recordType ?? null,
  trackPosition: Number.isFinite(track.trackPosition) ? track.trackPosition : null,
  discNumber: Number.isFinite(track.discNumber) ? track.discNumber : null,
  liked: Boolean(track.liked),
  saved: Boolean(track.saved),
  tags: uniqueLowercase(Array.isArray(track.tags) ? track.tags : []),
  metadata: ensureObject(track.metadata) ? Object.fromEntries(
    Object.entries(track.metadata).map(([key, value]) => [String(key), String(value)])
  ) : {},
});

const durationLabel = (duration) => {
  const total = Math.max(0, Math.round(Number(duration) || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
};

const artistRecords = (tracks) => sortedByName(
  [...groupedBy(tracks, (track) => track.artist).entries()].map(([artist, artistTracks]) => ({
    id: normalizeText(artist).replaceAll(" ", "-"),
    name: artist,
    trackCount: artistTracks.length,
    albumCount: new Set(artistTracks.map((track) => track.album)).size,
  })),
  "name"
);

const albumRecords = (tracks) => sortedByName(
  [...groupedBy(tracks, (track) => `${track.album}\u001f${track.artist}`).entries()].map(([, albumTracks]) => {
    const first = albumTracks[0];
    return {
      id: normalizeText(`${first.album} ${first.artist}`).replaceAll(" ", "-"),
      title: first.album,
      artist: first.artist,
      trackCount: albumTracks.length,
    };
  }),
  "title"
);

const normalizePermissions = (permissions) => ({
  ...defaultPermissions,
  ...(ensureObject(permissions) ? permissions : {}),
});

const normalizeSnapshot = (snapshot) => {
  const tracks = (Array.isArray(snapshot?.tracks) ? snapshot.tracks : [])
    .filter((track) => track?.id)
    .map(trackRecord);
  const trackById = new Map(tracks.map((track) => [track.id, track]));
  const playlists = (Array.isArray(snapshot?.playlists) ? snapshot.playlists : []).map((playlist) => {
    const trackIds = [...new Set((Array.isArray(playlist.trackIds) ? playlist.trackIds : []).map(String))]
      .filter((trackId) => trackById.has(trackId));
    return {
      id: String(playlist.id ?? randomUUID()),
      name: playlistName(playlist.name),
      description: String(playlist.description ?? "").trim() || null,
      trackIds,
      tracks: trackIds.map((trackId) => trackById.get(trackId)),
      createdAt: playlist.createdAt ?? nowISO(),
      updatedAt: playlist.updatedAt ?? nowISO(),
    };
  });

  return {
    version: Number(snapshot?.version) || snapshotVersion,
    updatedAt: snapshot?.updatedAt ?? nowISO(),
    tracks,
    artists: artistRecords(tracks),
    albums: albumRecords(tracks),
    playlists,
    permissions: normalizePermissions(snapshot?.permissions),
  };
};

const smartPromptStopWords = new Set([
  "собери",
  "плейлист",
  "playlist",
  "на",
  "минут",
  "мин",
  "minutes",
  "mins",
  "из",
  "но",
  "без",
  "повторов",
  "артистов",
  "любимых",
  "favorite",
  "favorites",
  "liked",
  "tracks",
  "track",
].map(normalizeText));

const smartRulesFromPrompt = (prompt = "", rules = {}) => {
  const text = normalizeText(prompt);
  const promptTokens = tokenList(text);
  const minuteMatch = text.match(/\b(\d{1,3})\s*(minutes?|mins?|минут|мин|m)\b/u);
  const targetMinutes = Number(rules.targetMinutes ?? rules.durationMinutes ?? minuteMatch?.[1] ?? 0);
  const queryTerms = promptTokens.filter((token) => !smartPromptStopWords.has(token) && !/^\d+$/.test(token));
  const likedOnly = Boolean(rules.likedOnly ?? promptTokens.some((token) =>
    token.startsWith("любим") || ["favorite", "favorites", "liked"].includes(token)
  ));

  return {
    query: rules.query ?? queryTerms.join(" "),
    targetSeconds: Number.isFinite(rules.targetSeconds)
      ? rules.targetSeconds
      : targetMinutes > 0
        ? targetMinutes * 60
        : 0,
    likedOnly,
    uniqueArtists: Boolean(rules.uniqueArtists ?? /без повторов артистов|no repeated artists|unique artists/u.test(text)),
    hasArtwork: typeof rules.hasArtwork === "boolean" ? rules.hasArtwork : undefined,
    missingArtwork: typeof rules.missingArtwork === "boolean" ? rules.missingArtwork : undefined,
    maxTracks: Number.isFinite(rules.maxTracks) ? Math.max(1, rules.maxTracks) : 100,
    name: rules.name ?? smartPlaylistName(prompt, queryTerms, { likedOnly }),
  };
};

const smartPlaylistName = (prompt, terms, { likedOnly = false } = {}) => {
  const selected = terms.slice(0, 4).join(" ");
  if (selected) return `Smart: ${likedOnly ? "любимых " : ""}${selected}`;
  const trimmed = String(prompt ?? "").trim();
  return trimmed ? `Smart: ${trimmed.slice(0, 36)}` : "Smart Playlist";
};

const selectSmartTracks = (tracks, prompt, rules) => {
  const normalizedRules = smartRulesFromPrompt(prompt, rules);
  const filters = {
    liked: normalizedRules.likedOnly ? true : undefined,
    hasArtwork: normalizedRules.hasArtwork,
    missingArtwork: normalizedRules.missingArtwork,
  };
  const seenArtists = new Set();
  let elapsed = 0;
  const scored = tracks
    .filter((track) => matchesFilters(track, filters))
    .map((track) => ({
      track,
      score: trackScore(track, normalizedRules.query) + (track.liked ? 90 : 0) + Math.min(Number(track.rank) || 0, 1_000_000) / 30_000,
    }))
    .filter(({ score }) => !normalizedRules.query || score > 0)
    .sort((lhs, rhs) => {
      if (lhs.score !== rhs.score) return rhs.score - lhs.score;
      return lhs.track.title.localeCompare(rhs.track.title, undefined, { sensitivity: "base" });
    });

  const selected = [];
  for (const { track } of scored) {
    if (selected.length >= normalizedRules.maxTracks) break;
    if (normalizedRules.uniqueArtists) {
      const artistKey = normalizeText(track.artist);
      if (seenArtists.has(artistKey)) continue;
      seenArtists.add(artistKey);
    }
    selected.push(track);
    elapsed += Number(track.duration) || 0;
    if (normalizedRules.targetSeconds > 0 && elapsed >= normalizedRules.targetSeconds) break;
  }

  return {
    rules: normalizedRules,
    tracks: selected,
    durationSeconds: elapsed,
  };
};

const duplicateGroups = (tracks) => [...groupedBy(
  tracks,
  (track) => normalizeText(`${track.title} ${track.artist}`)
).values()].filter((group) => group.length > 1);

export class NoirwaveMCPLibraryStore {
  constructor({ root = defaultMCPRoot() } = {}) {
    this.root = path.resolve(root);
    this.libraryPath = path.join(this.root, libraryFile);
    this.permissionsPath = path.join(this.root, permissionsFile);
    this.activityLogPath = path.join(this.root, activityLogFile);
    this.statusPath = path.join(this.root, statusFile);
  }

  async ensureFiles() {
    await fs.mkdir(this.root, { recursive: true });
    await this.ensureJSON(this.permissionsPath, defaultPermissions);
    await this.ensureJSON(this.activityLogPath, []);
    await this.ensureJSON(this.libraryPath, normalizeSnapshot({ permissions: defaultPermissions }));
  }

  async ensureJSON(filePath, fallback) {
    try {
      await fs.access(filePath);
    } catch {
      await this.writeJSON(filePath, fallback);
    }
  }

  async readJSON(filePath, fallback) {
    await this.ensureFiles();
    try {
      return JSON.parse(await fs.readFile(filePath, "utf8"));
    } catch {
      return fallback;
    }
  }

  async writeJSON(filePath, value) {
    await fs.mkdir(this.root, { recursive: true });
    const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
    await fs.writeFile(tempPath, `${JSON.stringify(value, null, 2)}\n`);
    await fs.rename(tempPath, filePath);
  }

  async readSnapshot() {
    const snapshot = await this.readJSON(this.libraryPath, null);
    return normalizeSnapshot(snapshot);
  }

  async writeSnapshot(snapshot) {
    const normalized = normalizeSnapshot({
      ...snapshot,
      permissions: normalizePermissions(snapshot?.permissions ?? await this.readPermissions()),
      updatedAt: nowISO(),
    });
    await this.writeJSON(this.libraryPath, normalized);
    await this.writeJSON(this.permissionsPath, normalized.permissions);
    return normalized;
  }

  async readPermissions() {
    return normalizePermissions(await this.readJSON(this.permissionsPath, defaultPermissions));
  }

  async writePermissions(permissions) {
    const normalized = normalizePermissions(permissions);
    await this.writeJSON(this.permissionsPath, normalized);
    const snapshot = await this.readSnapshot();
    snapshot.permissions = normalized;
    await this.writeSnapshot(snapshot);
    return normalized;
  }

  async requirePermission(permission, label) {
    const permissions = await this.readPermissions();
    if (!permissions[permission]) {
      const error = new Error(`Permission denied: ${label}`);
      error.code = "permission_denied";
      throw error;
    }
    return permissions;
  }

  async listResources() {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    return [
      { uri: "library://tracks", name: "Tracks", mimeType: "application/json" },
      { uri: "library://artists", name: "Artists", mimeType: "application/json" },
      { uri: "library://albums", name: "Albums", mimeType: "application/json" },
      { uri: "library://playlists", name: "Playlists", mimeType: "application/json" },
      ...snapshot.playlists.map((playlist) => ({
        uri: `library://playlist/${playlist.id}`,
        name: playlist.name,
        mimeType: "application/json",
      })),
      ...snapshot.tracks.map((track) => ({
        uri: `library://track/${track.id}`,
        name: `${track.title} - ${track.artist}`,
        mimeType: "application/json",
      })),
    ];
  }

  async readResource(uri) {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    const parsed = new URL(uri);
    const key = `${parsed.host}${parsed.pathname}`;

    switch (key) {
      case "tracks":
        return snapshot.tracks;
      case "artists":
        return snapshot.artists;
      case "albums":
        return snapshot.albums;
      case "playlists":
        return snapshot.playlists;
      default:
        break;
    }

    if (parsed.host === "playlist") {
      const playlist = snapshot.playlists.find((item) => item.id === parsed.pathname.slice(1));
      if (!playlist) throw new Error(`Playlist not found: ${parsed.pathname.slice(1)}`);
      return this.hydratedPlaylist(playlist, snapshot);
    }

    if (parsed.host === "track") {
      return this.getTrack(parsed.pathname.slice(1));
    }

    throw new Error(`Unsupported resource URI: ${uri}`);
  }

  hydratedPlaylist(playlist, snapshot) {
    const trackById = new Map(snapshot.tracks.map((track) => [track.id, track]));
    return {
      ...playlist,
      tracks: playlist.trackIds.map((trackId) => trackById.get(trackId)).filter(Boolean),
    };
  }

  async searchTracks(query = "", filters = {}) {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    const limit = Math.max(1, Math.min(Number(filters?.limit) || 50, 500));
    return snapshot.tracks
      .filter((track) => matchesFilters(track, filters))
      .map((track) => ({ track, score: trackScore(track, query) }))
      .filter(({ score }) => !String(query ?? "").trim() || score > 0)
      .sort((lhs, rhs) => {
        if (lhs.score !== rhs.score) return rhs.score - lhs.score;
        return lhs.track.title.localeCompare(rhs.track.title, undefined, { sensitivity: "base" });
      })
      .slice(0, limit)
      .map(({ track }) => track);
  }

  async getTrack(trackId) {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    const track = snapshot.tracks.find((item) => item.id === String(trackId));
    if (!track) throw new Error(`Track not found: ${trackId}`);
    return track;
  }

  async listPlaylists() {
    await this.requirePermission("readLibrary", "read library");
    return (await this.readSnapshot()).playlists;
  }

  async createPlaylist({ name, description = null, trackIds = [] }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    const snapshot = await this.readSnapshot();
    const trackById = new Map(snapshot.tracks.map((track) => [track.id, track]));
    const playlist = {
      id: randomUUID(),
      name: playlistName(name),
      description: String(description ?? "").trim() || null,
      trackIds: [...new Set(trackIds.map(String))].filter((trackId) => trackById.has(trackId)),
      tracks: [],
      createdAt: nowISO(),
      updatedAt: nowISO(),
    };
    snapshot.playlists.unshift(playlist);
    const saved = await this.writeSnapshot(snapshot);
    const created = saved.playlists.find((item) => item.id === playlist.id);
    await this.logActivity("create_playlist", `Created playlist "${created.name}"`, {
      playlistId: created.id,
      trackCount: created.trackIds.length,
    });
    return created;
  }

  async renamePlaylist({ playlistId, name }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    const snapshot = await this.readSnapshot();
    const playlist = snapshot.playlists.find((item) => item.id === String(playlistId));
    if (!playlist) throw new Error(`Playlist not found: ${playlistId}`);
    const previousName = playlist.name;
    playlist.name = playlistName(name);
    playlist.updatedAt = nowISO();
    await this.writeSnapshot(snapshot);
    await this.logActivity("rename_playlist", `Renamed playlist "${previousName}" to "${playlist.name}"`, {
      playlistId,
    });
    return playlist;
  }

  async deletePlaylist({ playlistId, confirm = false, confirmation = "" }) {
    await this.requirePermission("deletePlaylists", "delete playlists");
    const snapshot = await this.readSnapshot();
    const playlist = snapshot.playlists.find((item) => item.id === String(playlistId));
    if (!playlist) throw new Error(`Playlist not found: ${playlistId}`);
    const expected = confirmationPhrase("delete_playlist", playlist.id);
    if (confirm && confirmation !== expected) {
      throw new Error(`Confirmation required: pass confirmation="${expected}"`);
    }
    if (!confirm || confirmation !== expected) {
      return {
        requiresConfirmation: true,
        confirmation: expected,
        preview: {
          action: "delete_playlist",
          playlist,
          trackCount: playlist.trackIds.length,
        },
      };
    }
    snapshot.playlists = snapshot.playlists.filter((item) => item.id !== playlist.id);
    await this.writeSnapshot(snapshot);
    await this.logActivity("delete_playlist", `Deleted playlist "${playlist.name}"`, {
      playlistId: playlist.id,
      trackCount: playlist.trackIds.length,
    });
    return { deletedPlaylist: playlist };
  }

  async addTrackToPlaylist({ playlistId, trackId }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    const snapshot = await this.readSnapshot();
    const playlist = snapshot.playlists.find((item) => item.id === String(playlistId));
    if (!playlist) throw new Error(`Playlist not found: ${playlistId}`);
    const track = snapshot.tracks.find((item) => item.id === String(trackId));
    if (!track) throw new Error(`Track not found: ${trackId}`);
    if (!playlist.trackIds.includes(track.id)) {
      playlist.trackIds.push(track.id);
      playlist.updatedAt = nowISO();
      await this.writeSnapshot(snapshot);
      await this.logActivity("add_track_to_playlist", `Added "${track.title}" to "${playlist.name}"`, {
        playlistId: playlist.id,
        trackId: track.id,
      });
    }
    return this.hydratedPlaylist(playlist, await this.readSnapshot());
  }

  async removeTrackFromPlaylist({ playlistId, trackId, confirm = false, confirmation = "" }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    const snapshot = await this.readSnapshot();
    const playlist = snapshot.playlists.find((item) => item.id === String(playlistId));
    if (!playlist) throw new Error(`Playlist not found: ${playlistId}`);
    const track = snapshot.tracks.find((item) => item.id === String(trackId));
    if (!track) throw new Error(`Track not found: ${trackId}`);
    const expected = confirmationPhrase("remove_track_from_playlist", `${playlist.id}:${track.id}`);
    if (confirm && confirmation !== expected) {
      throw new Error(`Confirmation required: pass confirmation="${expected}"`);
    }
    if (!confirm || confirmation !== expected) {
      return {
        requiresConfirmation: true,
        confirmation: expected,
        preview: {
          action: "remove_track_from_playlist",
          playlistId: playlist.id,
          track,
        },
      };
    }
    playlist.trackIds = playlist.trackIds.filter((id) => id !== track.id);
    playlist.updatedAt = nowISO();
    await this.writeSnapshot(snapshot);
    await this.logActivity("remove_track_from_playlist", `Removed "${track.title}" from "${playlist.name}"`, {
      playlistId: playlist.id,
      trackId: track.id,
    });
    return this.hydratedPlaylist(playlist, await this.readSnapshot());
  }

  async reorderPlaylistTracks({ playlistId, trackIds, confirm = false, confirmation = "" }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    if (!Array.isArray(trackIds)) throw new Error("trackIds must be an array");
    const snapshot = await this.readSnapshot();
    const playlist = snapshot.playlists.find((item) => item.id === String(playlistId));
    if (!playlist) throw new Error(`Playlist not found: ${playlistId}`);
    const originalSet = new Set(playlist.trackIds);
    const nextTrackIds = [...new Set(trackIds.map(String))].filter((trackId) => originalSet.has(trackId));
    const missing = playlist.trackIds.filter((trackId) => !nextTrackIds.includes(trackId));
    const reordered = [...nextTrackIds, ...missing];
    const expected = confirmationPhrase("reorder_playlist_tracks", playlist.id);
    const preview = {
      before: playlist.trackIds,
      after: reordered,
      appendedMissingTracks: missing,
    };
    if (confirm && confirmation !== expected) {
      throw new Error(`Confirmation required: pass confirmation="${expected}"`);
    }
    if (!confirm || confirmation !== expected) {
      return {
        requiresConfirmation: true,
        confirmation: expected,
        preview,
      };
    }
    playlist.trackIds = reordered;
    playlist.updatedAt = nowISO();
    await this.writeSnapshot(snapshot);
    await this.logActivity("reorder_playlist_tracks", `Reordered "${playlist.name}"`, {
      playlistId: playlist.id,
      trackCount: playlist.trackIds.length,
    });
    return this.hydratedPlaylist(playlist, await this.readSnapshot());
  }

  async createSmartPlaylist({ prompt = "", rules = {}, confirm = false, confirmation = "" }) {
    await this.requirePermission("editPlaylists", "edit playlists");
    const snapshot = await this.readSnapshot();
    const selection = selectSmartTracks(snapshot.tracks, prompt, rules);
    const expected = confirmationPhrase("create_smart_playlist", normalizeText(`${selection.rules.name}:${selection.tracks.map((track) => track.id).join(",")}`));
    const preview = {
      name: selection.rules.name,
      prompt,
      rules: selection.rules,
      durationSeconds: selection.durationSeconds,
      tracks: selection.tracks,
    };
    if (confirm && confirmation !== expected) {
      throw new Error(`Confirmation required: pass confirmation="${expected}"`);
    }
    if (!confirm || confirmation !== expected) {
      return {
        requiresConfirmation: true,
        confirmation: expected,
        preview,
      };
    }
    const playlist = await this.createPlaylist({
      name: selection.rules.name,
      description: String(prompt ?? "").trim() || "Smart playlist generated by MCP",
      trackIds: selection.tracks.map((track) => track.id),
    });
    await this.logActivity("create_smart_playlist", `Created smart playlist "${playlist.name}"`, {
      playlistId: playlist.id,
      trackCount: playlist.trackIds.length,
      prompt,
    });
    return playlist;
  }

  async findSimilarTracks({ trackId, limit = 12 }) {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    const seed = snapshot.tracks.find((track) => track.id === String(trackId));
    if (!seed) throw new Error(`Track not found: ${trackId}`);
    const seedTags = new Set((seed.tags ?? []).map(normalizeText));
    const safeLimit = Math.max(1, Math.min(Number(limit) || 12, 100));
    return snapshot.tracks
      .filter((track) => track.id !== seed.id)
      .map((track) => {
        let score = 0;
        if (normalizeText(track.artist) === normalizeText(seed.artist)) score += 400;
        if (normalizeText(track.album) === normalizeText(seed.album)) score += 260;
        for (const tag of track.tags ?? []) {
          if (seedTags.has(normalizeText(tag))) score += 90;
        }
        score += Math.max(0, 80 - Math.abs((Number(track.duration) || 0) - (Number(seed.duration) || 0)) / 4);
        score += Math.min(Number(track.rank) || 0, 1_000_000) / 40_000;
        return { track, score };
      })
      .filter(({ score }) => score > 0)
      .sort((lhs, rhs) => rhs.score - lhs.score)
      .slice(0, safeLimit)
      .map(({ track }) => track);
  }

  async getLibraryStats() {
    await this.requirePermission("readLibrary", "read library");
    const snapshot = await this.readSnapshot();
    const totalDurationSeconds = snapshot.tracks.reduce((sum, track) => sum + (Number(track.duration) || 0), 0);
    const duplicates = duplicateGroups(snapshot.tracks);
    return {
      tracks: snapshot.tracks.length,
      artists: snapshot.artists.length,
      albums: snapshot.albums.length,
      playlists: snapshot.playlists.length,
      likedTracks: snapshot.tracks.filter((track) => track.liked).length,
      missingArtwork: snapshot.tracks.filter((track) => !track.artworkURL).length,
      totalDurationSeconds,
      totalDurationLabel: durationLabel(totalDurationSeconds),
      potentialDuplicateGroups: duplicates.map((group) => group.map((track) => ({
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
      }))),
    };
  }

  async tagTrack({ trackId, tags }) {
    await this.requirePermission("editMetadata", "edit metadata");
    if (!Array.isArray(tags)) throw new Error("tags must be an array");
    const snapshot = await this.readSnapshot();
    const track = snapshot.tracks.find((item) => item.id === String(trackId));
    if (!track) throw new Error(`Track not found: ${trackId}`);
    track.tags = uniqueLowercase([...(track.tags ?? []), ...tags]);
    await this.writeSnapshot(snapshot);
    await this.logActivity("tag_track", `Tagged "${track.title}"`, {
      trackId: track.id,
      tags: track.tags,
    });
    return track;
  }

  async updateTrackMetadata({ trackId, metadata }) {
    await this.requirePermission("editMetadata", "edit metadata");
    if (!ensureObject(metadata)) throw new Error("metadata must be an object");
    const snapshot = await this.readSnapshot();
    const track = snapshot.tracks.find((item) => item.id === String(trackId));
    if (!track) throw new Error(`Track not found: ${trackId}`);
    track.metadata = {
      ...(track.metadata ?? {}),
      ...Object.fromEntries(Object.entries(metadata).map(([key, value]) => [String(key), String(value)])),
    };
    await this.writeSnapshot(snapshot);
    await this.logActivity("update_track_metadata", `Updated metadata for "${track.title}"`, {
      trackId: track.id,
      keys: Object.keys(metadata),
    });
    return track;
  }

  async readActivityLog(limit = maxActivityEntries) {
    const entries = await this.readJSON(this.activityLogPath, []);
    return Array.isArray(entries) ? entries.slice(0, limit) : [];
  }

  async logActivity(action, summary, details = null) {
    const entries = await this.readActivityLog(maxActivityEntries);
    const entry = {
      id: randomUUID(),
      timestamp: nowISO(),
      actor: "AI MCP",
      action,
      summary,
      details: details == null ? null : JSON.stringify(details),
    };
    await this.writeJSON(this.activityLogPath, [entry, ...entries].slice(0, maxActivityEntries));
    return entry;
  }

  async writeStatus(status) {
    await this.writeJSON(this.statusPath, {
      updatedAt: nowISO(),
      ...status,
    });
  }
}
