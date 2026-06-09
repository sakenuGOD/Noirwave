const yandexBaseURL = "https://api.music.yandex.net";
const yandexHeaders = {
  "Accept-Language": "ru",
  "User-Agent": "Yandex-Music-API",
  "X-Yandex-Music-Client": "YandexMusicAndroid/24023621",
};

const maxImportTracks = Math.max(1, Number(process.env.NOIRWAVE_YANDEX_IMPORT_LIMIT) || 500);

export const normalizeYandexToken = (value) => {
  const token = String(value ?? "").trim();
  if (token.length < 24 || /\s/.test(token)) return null;
  return token;
};

const yandexResult = (json) => json?.result ?? json;

const yandexJSON = async (path, { token, method = "GET", searchParams, form } = {}) => {
  const normalizedToken = normalizeYandexToken(token);
  if (!normalizedToken) {
    const error = new Error("Enter a valid Yandex OAuth token.");
    error.name = "YandexAuthError";
    error.statusCode = 400;
    throw error;
  }

  const url = new URL(path, yandexBaseURL);
  for (const [key, value] of Object.entries(searchParams ?? {})) {
    if (value !== undefined && value !== null) {
      url.searchParams.set(key, String(value));
    }
  }

  const headers = {
    ...yandexHeaders,
    Authorization: `OAuth ${normalizedToken}`,
  };

  const init = { method, headers };
  if (form) {
    const body = new URLSearchParams();
    for (const [key, value] of Object.entries(form)) {
      const values = Array.isArray(value) ? value : [value];
      for (const item of values) {
        if (item !== undefined && item !== null) {
          body.append(key, String(item));
        }
      }
    }
    init.body = body.toString();
    headers["Content-Type"] = "application/x-www-form-urlencoded";
  }

  const response = await fetch(url, init);
  const json = await response.json().catch(() => null);

  if (response.status === 401 || response.status === 403) {
    const error = new Error("Yandex Music token is invalid or expired.");
    error.name = "YandexAuthError";
    error.statusCode = 401;
    throw error;
  }

  if (!response.ok || json?.error) {
    const error = new Error(json?.error_description ?? json?.error?.message ?? "Yandex Music request failed.");
    error.name = "YandexImportError";
    error.statusCode = response.status || 502;
    throw error;
  }

  return yandexResult(json);
};

const trackShortID = (track) => {
  const id = track?.id ?? track?.track_id ?? track?.trackId;
  const album = Array.isArray(track?.albums) ? track.albums[0] : track?.album;
  const albumID = track?.album_id ?? track?.albumId ?? album?.id;
  if (!id) return null;
  return albumID ? `${id}:${albumID}` : String(id);
};

const coverURL = (track, album) => {
  const uri = track?.cover_uri ?? track?.coverUri ?? track?.og_image ?? album?.cover_uri ?? album?.coverUri;
  if (!uri) return null;
  const value = String(uri).replace("%%", "400x400");
  return value.startsWith("http") ? value : `https://${value}`;
};

const compactArtists = (artists) =>
  (Array.isArray(artists) ? artists : [])
    .map((artist) => artist?.name)
    .filter(Boolean)
    .join(", ");

export const normalizeYandexTrack = (track, fallbackIndex = 0) => {
  const album = Array.isArray(track?.albums) ? track.albums[0] : track?.album;
  const title = String(track?.title ?? track?.name ?? "").trim();
  const artist = compactArtists(track?.artists) || String(track?.artist ?? "").trim();
  if (!title || !artist) return null;

  const durationMs = Number(track?.duration_ms ?? track?.durationMs ?? 0);
  const durationSeconds = durationMs > 0 ? durationMs / 1000 : Number(track?.duration ?? 0) || null;
  const id = trackShortID(track) ?? `yandex-export-${fallbackIndex}`;

  return {
    id: String(id),
    title,
    artist,
    album: String(album?.title ?? track?.album_title ?? track?.albumTitle ?? "").trim(),
    duration: durationSeconds,
    artworkURL: coverURL(track, album),
  };
};

const yandexTrackIDsFromLikes = (library) => {
  const tracks = Array.isArray(library?.tracks) ? library.tracks : [];
  return tracks.map(trackShortID).filter(Boolean);
};

const embeddedTracksFromLikes = (library) =>
  (Array.isArray(library?.tracks) ? library.tracks : [])
    .map((item) => item?.track)
    .filter(Boolean);

const fetchFullYandexTracks = async (trackIDs, token) => {
  if (trackIDs.length === 0) return [];
  const tracks = [];
  for (let index = 0; index < trackIDs.length; index += 100) {
    const chunk = trackIDs.slice(index, index + 100);
    const result = await yandexJSON("/tracks", {
      token,
      method: "POST",
      form: {
        "track-ids": chunk,
        "with-positions": "true",
      },
    });
    if (Array.isArray(result)) {
      tracks.push(...result);
    }
  }
  return tracks;
};

export const fetchYandexLikedTracks = async ({ token }) => {
  const status = await yandexJSON("/account/status", { token });
  const uid = status?.account?.uid ?? status?.account?.login;
  if (!uid) {
    const error = new Error("Yandex account status did not include a user id.");
    error.name = "YandexImportError";
    error.statusCode = 502;
    throw error;
  }

  const likes = await yandexJSON(`/users/${uid}/likes/tracks`, {
    token,
    searchParams: { "if-modified-since-revision": 0 },
  });
  const library = likes?.library ?? likes;
  const embeddedTracks = embeddedTracksFromLikes(library);
  const fullTracks = embeddedTracks.length > 0
    ? embeddedTracks
    : await fetchFullYandexTracks(yandexTrackIDsFromLikes(library).slice(0, maxImportTracks), token);

  return fullTracks
    .slice(0, maxImportTracks)
    .map(normalizeYandexTrack)
    .filter(Boolean);
};

const parseJSONExport = (text) => {
  const parsed = JSON.parse(text);
  const candidates = [
    parsed,
    parsed?.tracks,
    parsed?.items,
    parsed?.library?.tracks,
    parsed?.result?.library?.tracks,
  ];
  const items = candidates.find(Array.isArray) ?? [];
  return items
    .map((item, index) => normalizeYandexTrack(item?.track ?? item, index))
    .filter(Boolean);
};

const parseCSVLine = (line) => {
  const cells = [];
  let current = "";
  let quoted = false;
  for (const char of line) {
    if (char === "\"") {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      cells.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  cells.push(current.trim());
  return cells;
};

const parseDelimitedExport = (text) => {
  const lines = text.split(/\r?\n/u).map((line) => line.trim()).filter(Boolean);
  if (lines.length === 0) return [];

  const header = parseCSVLine(lines[0]).map((cell) => cell.toLocaleLowerCase());
  const titleIndex = header.findIndex((cell) => ["title", "track", "name", "название", "трек"].includes(cell));
  const artistIndex = header.findIndex((cell) => ["artist", "artists", "исполнитель", "артист"].includes(cell));
  const albumIndex = header.findIndex((cell) => ["album", "альбом"].includes(cell));
  const durationIndex = header.findIndex((cell) => ["duration", "duration_ms", "длительность"].includes(cell));

  if (titleIndex >= 0 && artistIndex >= 0) {
    return lines.slice(1).map((line, index) => {
      const cells = parseCSVLine(line);
      return normalizeYandexTrack({
        id: `yandex-export-${index}`,
        title: cells[titleIndex],
        artist: cells[artistIndex],
        album_title: albumIndex >= 0 ? cells[albumIndex] : "",
        duration: durationIndex >= 0 ? Number(cells[durationIndex]) : null,
      }, index);
    }).filter(Boolean);
  }

  return lines.map((line, index) => {
    const [artist, title] = line.split(/\s+-\s+/u);
    return normalizeYandexTrack({
      id: `yandex-export-${index}`,
      artist,
      title: title ?? line,
    }, index);
  }).filter(Boolean);
};

export const parseYandexExport = (text) => {
  const value = String(text ?? "").trim();
  if (!value) return [];
  try {
    return parseJSONExport(value).slice(0, maxImportTracks);
  } catch (_error) {
    return parseDelimitedExport(value).slice(0, maxImportTracks);
  }
};

export const yandexLikedTracksForImport = async ({ token, exportText }) => {
  if (String(exportText ?? "").trim()) {
    return parseYandexExport(exportText);
  }
  return fetchYandexLikedTracks({ token });
};
