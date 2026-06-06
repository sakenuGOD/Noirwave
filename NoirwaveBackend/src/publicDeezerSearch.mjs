import got from "got";
import {
  recordTypeLabel,
  splitArtistReleases,
} from "./catalogMapper.mjs";

const deezerSearchEndpointByScope = new Map([
  ["track", "search/track"],
  ["artist", "search/artist"],
  ["album", "search/album"],
]);

const maxPublicSearchPageLimit = 100;
const maxPublicSearchResultCount = 500;
const weakArtistPrefixMinFans = 5_000;
const weakArtistContainsMinFans = 50_000;

const normalizeSearchText = (value) =>
  String(value ?? "")
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");

const boundedResultCount = (count) => {
  const numeric = Number(count);
  if (!Number.isFinite(numeric)) return 30;
  return Math.min(Math.max(1, Math.trunc(numeric)), maxPublicSearchResultCount);
};

const publicSearchPageLimit = (targetCount) => Math.min(targetCount, maxPublicSearchPageLimit);

const allowsPublicArtist = (artist, term) => {
  const name = normalizeSearchText(artist?.name);
  if (!name || !term) return false;
  if (name === term) return true;
  if (name.startsWith(`${term} `)) {
    return Number(artist?.nb_fan ?? 0) >= weakArtistPrefixMinFans;
  }
  if (!name.includes(term)) return false;
  return Number(artist?.nb_fan ?? 0) >= weakArtistContainsMinFans;
};

const artistRelevanceScore = (artist, term) => {
  const name = normalizeSearchText(artist?.name);
  const fans = Math.max(0, Number(artist?.nb_fan ?? 0));
  const albums = Math.max(0, Number(artist?.nb_album ?? 0));
  let score = Math.min(Math.floor(fans / 50), 400_000) + Math.min(albums * 250, 50_000);

  if (name === term) score += 1_000_000;
  else if (name.startsWith(`${term} `)) score += 700_000;
  else if (name.includes(term)) score += 300_000;

  return score;
};

const deduplicatePublicArtists = (artists) => {
  const bestByName = new Map();
  for (const artist of artists) {
    const key = normalizeSearchText(artist?.name);
    if (!key) continue;

    const current = bestByName.get(key);
    const artistFans = Number(artist?.nb_fan ?? 0);
    const currentFans = Number(current?.nb_fan ?? 0);
    if (!current || artistFans > currentFans) {
      bestByName.set(key, artist);
    }
  }

  return [...bestByName.values()];
};

const normalizePublicResponse = ({ json, query, scope, targetCount }) => {
  if (json?.error) {
    const message = json.error.message ?? json.error.code ?? "Deezer public search failed.";
    const error = new Error(message);
    error.name = "PublicDeezerSearchError";
    error.statusCode = 503;
    throw error;
  }

  const term = normalizeSearchText(query);
  let data = Array.isArray(json?.data) ? json.data.slice(0, targetCount) : [];
  if (scope === "artist") {
    data = deduplicatePublicArtists(data)
      .filter((artist) => allowsPublicArtist(artist, term))
      .sort((lhs, rhs) => artistRelevanceScore(rhs, term) - artistRelevanceScore(lhs, term));
  }

  return {
    data,
    total: Number.isFinite(Number(json?.total)) ? Number(json.total) : data.length,
    type: scope,
    source: "deezer-public-search",
  };
};

const publicSearchRequestError = (error) => {
  if (error?.name === "AbortError" || error?.name === "TimeoutError" || error?.code === "ETIMEDOUT") {
    const timeout = new Error("Deezer public search timed out.");
    timeout.name = "PublicDeezerSearchTimeout";
    timeout.statusCode = 504;
    timeout.cause = error;
    return timeout;
  }

  const statusCode = error?.response?.statusCode ?? error?.statusCode;
  const mapped = new Error(error?.message ?? "Deezer public search failed.");
  mapped.name = "PublicDeezerSearchError";
  mapped.statusCode = statusCode >= 500 ? 503 : statusCode ?? 503;
  mapped.cause = error;
  return mapped;
};

const publicArtwork = (item) =>
  item?.cover_xl
  ?? item?.cover_big
  ?? item?.cover_medium
  ?? item?.cover
  ?? item?.picture_xl
  ?? item?.picture_big
  ?? item?.picture_medium
  ?? item?.picture
  ?? null;

const publicArtistPayload = (artist) => artist
  ? {
      id: artist.id ?? null,
      name: artist.name ?? "Unknown Artist",
      link: artist.link ?? (artist.id ? `https://www.deezer.com/artist/${artist.id}` : null),
      picture: publicArtwork(artist),
      picture_small: artist.picture_small ?? publicArtwork(artist),
      picture_medium: artist.picture_medium ?? publicArtwork(artist),
      picture_big: artist.picture_big ?? publicArtwork(artist),
      picture_xl: artist.picture_xl ?? publicArtwork(artist),
      nb_album: artist.nb_album ?? null,
      nb_fan: artist.nb_fan ?? null,
      tracklist: artist.tracklist ?? (artist.id ? `https://api.deezer.com/artist/${artist.id}/top?limit=50` : null),
    }
  : null;

const publicAlbumPayload = (album) => {
  const artwork = publicArtwork(album);
  const artist = publicArtistPayload(album?.artist);
  const id = album?.id ?? null;
  return {
    id,
    title: album?.title ?? "Unknown Album",
    link: album?.link ?? (id ? `https://www.deezer.com/album/${id}` : null),
    cover: album?.cover ?? artwork,
    cover_small: album?.cover_small ?? artwork,
    cover_medium: album?.cover_medium ?? artwork,
    cover_big: album?.cover_big ?? artwork,
    cover_xl: album?.cover_xl ?? artwork,
    artist,
    nb_tracks: album?.nb_tracks ?? album?.tracks?.data?.length ?? null,
    fans: album?.fans ?? null,
    release_date: album?.release_date ?? null,
    record_type: recordTypeLabel(album?.record_type, album?.title),
    rank: album?.rank ?? null,
    tracklist: album?.tracklist ?? (id ? `https://api.deezer.com/album/${id}/tracks` : null),
  };
};

const publicTrackPayload = (track, fallbackIndex, album) => {
  const albumData = publicAlbumPayload(album);
  const artist = publicArtistPayload(track?.artist ?? album?.artist);
  const id = track?.id ?? `fallback-${fallbackIndex}`;
  return {
    id,
    readable: track?.readable ?? true,
    title: track?.title ?? "Untitled Track",
    title_short: track?.title_short ?? track?.title ?? "Untitled Track",
    title_version: track?.title_version ?? null,
    link: track?.link ?? (id ? `https://www.deezer.com/track/${id}` : null),
    duration: track?.duration ?? 0,
    rank: track?.rank ?? null,
    explicit_lyrics: track?.explicit_lyrics ?? false,
    preview: track?.preview ?? null,
    track_position: track?.track_position ?? fallbackIndex + 1,
    disk_number: track?.disk_number ?? 1,
    artist,
    album: {
      ...albumData,
      artist: albumData.artist ?? artist,
    },
  };
};

const publicTrackPageItems = (json) => {
  if (Array.isArray(json?.tracks?.data)) return json.tracks.data;
  if (Array.isArray(json?.data)) return json.data;
  return [];
};

const publicTrackPageNext = (json) => json?.tracks?.next ?? json?.next ?? null;

const publicDataPageItems = (json) => Array.isArray(json?.data) ? json.data : [];
const publicDataPageNext = (json) => json?.next ?? null;

const collectPublicDataPages = async (firstJson, { fetchImpl, timeoutMs, limit = 100, maxPages = 5 }) => {
  const items = [];
  const seen = new Set();

  const appendItems = (pageItems) => {
    for (const item of pageItems) {
      const key = item?.id == null ? `${items.length}:${item?.title ?? item?.name ?? ""}` : String(item.id);
      if (seen.has(key)) continue;
      seen.add(key);
      items.push(item);
      if (items.length >= limit) break;
    }
  };

  appendItems(publicDataPageItems(firstJson));
  let next = publicDataPageNext(firstJson);
  let pageCount = 0;

  while (next && items.length < limit && pageCount < maxPages) {
    pageCount += 1;
    const pageJson = await requestPublicJSON(new URL(next), { fetchImpl, timeoutMs });
    appendItems(publicDataPageItems(pageJson));
    next = publicDataPageNext(pageJson);
  }

  return items;
};

const collectPublicAlbumTracks = async (albumJson, albumPayload, { fetchImpl, timeoutMs }) => {
  const declaredCount = Number(albumPayload?.nb_tracks ?? 0);
  const targetCount = Number.isFinite(declaredCount) && declaredCount > 0 ? declaredCount : 500;
  const tracks = [];
  const seen = new Set();

  const appendTracks = (items) => {
    for (const item of items) {
      const key = item?.id == null ? `${tracks.length}:${item?.title ?? ""}` : String(item.id);
      if (seen.has(key)) continue;
      seen.add(key);
      tracks.push(item);
      if (tracks.length >= targetCount) break;
    }
  };

  appendTracks(publicTrackPageItems(albumJson));
  let next = publicTrackPageNext(albumJson);
  let pageCount = 0;

  while (next && tracks.length < targetCount && pageCount < 20) {
    pageCount += 1;
    const pageJson = await requestPublicJSON(new URL(next), { fetchImpl, timeoutMs });
    appendTracks(publicTrackPageItems(pageJson));
    next = publicTrackPageNext(pageJson);
  }

  return tracks.map((track, index) => publicTrackPayload(track, index, albumJson));
};

const mapWithConcurrency = async (items, limit, mapper) => {
  const output = new Array(items.length);
  let nextIndex = 0;
  const workerCount = Math.min(Math.max(1, limit), items.length);

  const workers = Array.from({ length: workerCount }, async () => {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      output[index] = await mapper(items[index], index);
    }
  });

  await Promise.all(workers);
  return output;
};

const samePublicArtist = (track, artist) => {
  const trackArtist = track?.artist;
  const artistID = String(artist?.id ?? "");
  if (artistID && String(trackArtist?.id ?? "") === artistID) return true;

  return normalizeSearchText(trackArtist?.name) === normalizeSearchText(artist?.name);
};

const deduplicatePublicTracks = (tracks) => {
  const seen = new Set();
  const output = [];

  for (const track of tracks) {
    const key = track?.id == null
      ? `${normalizeSearchText(track?.title)}:${normalizeSearchText(track?.artist?.name)}:${normalizeSearchText(track?.album?.title)}`
      : String(track.id);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    output.push(track);
  }

  return output;
};

const requestPublicJSON = async (url, { fetchImpl, timeoutMs }) => {
  if (fetchImpl) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(url, { signal: controller.signal });
      if (!response.ok) {
        const error = new Error(`Deezer public search returned HTTP ${response.status}.`);
        error.name = "PublicDeezerSearchError";
        error.statusCode = response.status >= 500 ? 503 : response.status;
        throw error;
      }
      return await response.json();
    } catch (error) {
      throw publicSearchRequestError(error);
    } finally {
      clearTimeout(timer);
    }
  }

  try {
    return await got(url, {
      timeout: { request: timeoutMs },
      retry: { limit: 0 },
      headers: { "user-agent": "Noirwave/0.1" },
    }).json();
  } catch (error) {
    throw publicSearchRequestError(error);
  }
};

export const publicDeezerSearch = async (
  { query, scope = "track", count = 30 },
  { fetchImpl = null, timeoutMs = 15000 } = {}
) => {
  const endpoint = deezerSearchEndpointByScope.get(scope);
  if (!endpoint) {
    const error = new Error(`Unsupported Deezer search scope: ${scope}`);
    error.name = "UnsupportedSearchScope";
    error.statusCode = 400;
    throw error;
  }

  const targetCount = boundedResultCount(count);
  const pageLimit = publicSearchPageLimit(targetCount);
  const url = new URL(`https://api.deezer.com/${endpoint}`);
  url.searchParams.set("q", String(query ?? ""));
  url.searchParams.set("limit", String(pageLimit));

  const json = await requestPublicJSON(url, { fetchImpl, timeoutMs });
  const data = await collectPublicDataPages(json, {
    fetchImpl,
    timeoutMs,
    limit: targetCount,
    maxPages: Math.ceil(targetCount / pageLimit) + 1,
  });
  return normalizePublicResponse({ json: { ...json, data }, query, scope, targetCount });
};

export const publicDeezerAlbumDetail = async (
  { id },
  { fetchImpl = null, timeoutMs = 15000 } = {}
) => {
  const albumID = String(id ?? "").trim();
  if (!/^\d+$/.test(albumID)) {
    const error = new Error("Album id must be numeric.");
    error.name = "InvalidAlbumID";
    error.statusCode = 400;
    throw error;
  }

  const url = new URL(`https://api.deezer.com/album/${albumID}`);
  const json = await requestPublicJSON(url, { fetchImpl, timeoutMs });
  if (json?.error) {
    const message = json.error.message ?? json.error.code ?? "Deezer public album lookup failed.";
    const error = new Error(message);
    error.name = "PublicDeezerAlbumError";
    error.statusCode = 503;
    throw error;
  }

  const album = publicAlbumPayload(json);
  const tracks = await collectPublicAlbumTracks(json, album, { fetchImpl, timeoutMs });

  return {
    ...album,
    tracks,
    source: "deezer-public-album",
  };
};

export const publicDeezerArtistDetail = async (
  { id },
  { fetchImpl = null, timeoutMs = 15000 } = {}
) => {
  const artistID = String(id ?? "").trim();
  if (!/^\d+$/.test(artistID)) {
    const error = new Error("Artist id must be numeric.");
    error.name = "InvalidArtistID";
    error.statusCode = 400;
    throw error;
  }

  const artistUrl = new URL(`https://api.deezer.com/artist/${artistID}`);
  const topUrl = new URL(`https://api.deezer.com/artist/${artistID}/top`);
  topUrl.searchParams.set("limit", "100");
  const albumsUrl = new URL(`https://api.deezer.com/artist/${artistID}/albums`);
  albumsUrl.searchParams.set("limit", "100");

  const artistPromise = requestPublicJSON(artistUrl, { fetchImpl, timeoutMs });
  const topTracksPromise = requestPublicJSON(topUrl, { fetchImpl, timeoutMs })
    .then((json) => publicDataPageItems(json))
    .catch(() => []);
  const albumsPromise = requestPublicJSON(albumsUrl, { fetchImpl, timeoutMs })
    .then((json) => collectPublicDataPages(json, { fetchImpl, timeoutMs, limit: 500, maxPages: 25 }))
    .catch(() => []);

  const [artistJson, topTrackItems, albumItems] = await Promise.all([
    artistPromise,
    topTracksPromise,
    albumsPromise,
  ]);
  if (artistJson?.error) {
    const message = artistJson.error.message ?? artistJson.error.code ?? "Deezer public artist lookup failed.";
    const error = new Error(message);
    error.name = "PublicDeezerArtistError";
    error.statusCode = 503;
    throw error;
  }

  const artist = publicArtistPayload(artistJson);
  const topTracks = topTrackItems.map((track, index) => {
    const album = track?.album
      ? { ...track.album, artist: track.album.artist ?? track.artist ?? artistJson }
      : { id: null, title: "Deezer", artist: track?.artist ?? artistJson };
    return publicTrackPayload(track, index, album);
  });
  const albums = albumItems.map((album) => publicAlbumPayload({
    ...album,
    artist: album?.artist ?? artistJson,
  }));

  return {
    ...artist,
    releases: splitArtistReleases(albums),
    top_tracks: topTracks,
    source: "deezer-public-artist",
  };
};

export const publicDeezerArtistTracks = async (
  { id },
  { fetchImpl = null, timeoutMs = 18000, maxAlbums = 500, concurrency = 5 } = {}
) => {
  const artistID = String(id ?? "").trim();
  if (!/^\d+$/.test(artistID)) {
    const error = new Error("Artist id must be numeric.");
    error.name = "InvalidArtistID";
    error.statusCode = 400;
    throw error;
  }

  const artistUrl = new URL(`https://api.deezer.com/artist/${artistID}`);
  const albumsUrl = new URL(`https://api.deezer.com/artist/${artistID}/albums`);
  albumsUrl.searchParams.set("limit", "100");

  const [artistJson, firstAlbumsJson] = await Promise.all([
    requestPublicJSON(artistUrl, { fetchImpl, timeoutMs }),
    requestPublicJSON(albumsUrl, { fetchImpl, timeoutMs }),
  ]);
  if (artistJson?.error) {
    const message = artistJson.error.message ?? artistJson.error.code ?? "Deezer public artist lookup failed.";
    const error = new Error(message);
    error.name = "PublicDeezerArtistError";
    error.statusCode = 503;
    throw error;
  }

  const artist = publicArtistPayload(artistJson);
  const albumItems = await collectPublicDataPages(firstAlbumsJson, {
    fetchImpl,
    timeoutMs,
    limit: maxAlbums,
    maxPages: 25,
  });

  const albumTrackGroups = await mapWithConcurrency(albumItems, concurrency, async (albumItem) => {
    try {
      const albumID = albumItem?.id;
      if (!albumID) return [];
      const albumPayload = await publicDeezerAlbumDetail({ id: albumID }, { fetchImpl, timeoutMs });
      return (albumPayload.tracks ?? [])
        .filter((track) => samePublicArtist(track, artist))
        .map((track) => ({
          ...track,
          album: track.album ?? publicAlbumPayload({ ...albumItem, artist: albumItem?.artist ?? artistJson }),
        }));
    } catch (_error) {
      return [];
    }
  });

  const data = deduplicatePublicTracks(albumTrackGroups.flat());
  return {
    data,
    total: data.length,
    type: "artist-tracks",
    artist,
    source: "deezer-public-artist-tracks",
  };
};
