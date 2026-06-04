import express from "express";
import { once } from "node:events";
import { callCatalog } from "./pythonCatalog.mjs";
import { loadDeemixModules } from "./deemixModules.mjs";
import { readARL, setRuntimeARL } from "./session.mjs";
import {
  cachedStartupPrefix,
  cachedStartupRange,
  parseRangeHeader,
  readDeezerStartupSegment,
  streamDeezerMedia,
} from "./streaming.mjs";
import { normalizeLyricsPayload } from "./lyricsMapper.mjs";

const app = express();
const port = Number(process.env.NOIRWAVE_BACKEND_PORT ?? 6605);
const host = process.env.NOIRWAVE_BACKEND_HOST ?? "127.0.0.1";
const preferredFormat = process.env.NOIRWAVE_DEEZER_FORMAT ?? "MP3_320";
const startupSegmentBytes = Math.max(64 * 1024, Number(process.env.NOIRWAVE_STARTUP_CACHE_BYTES) || 384 * 1024);
const startupSegmentMaxEntries = Math.max(1, Number(process.env.NOIRWAVE_STARTUP_CACHE_TRACKS) || 64);
const startupJoinTimeoutMs = Math.max(100, Number(process.env.NOIRWAVE_STARTUP_JOIN_TIMEOUT_MS) || 650);
const prefetchConcurrency = Math.max(1, Number(process.env.NOIRWAVE_PREFETCH_CONCURRENCY) || 4);
const backgroundPrefetchLimit = Math.max(0, Number(process.env.NOIRWAVE_BACKGROUND_PREFETCH_TRACKS) || 16);
const foregroundPrefetchLimit = Math.max(0, Number(process.env.NOIRWAVE_FOREGROUND_PREFETCH_TRACKS) || 8);
const foregroundPrefetchTimeoutMs = Math.max(0, Number(process.env.NOIRWAVE_FOREGROUND_PREFETCH_TIMEOUT_MS) || 0);
const bitrateByFormat = new Map([
  ["MP3_320", 3],
  ["MP3_128", 1],
]);

let sdkState = null;
const mediaURLCache = new Map();
const mediaURLFailureCache = new Map();
const mediaURLInflight = new Map();
const trackMediaCache = new Map();
const trackMediaInflight = new Map();
const startupSegmentCache = new Map();
const startupSegmentInflight = new Map();
const startupPrefetchQueue = [];
const startupPrefetchQueuedKeys = new Set();
let activeStartupPrefetches = 0;

app.use(express.json());

const isValidTrackId = (value) => /^\d+$/.test(String(value ?? ""));

const normalizeFormat = (value) => {
  const requestedFormat = String(value ?? preferredFormat).trim();
  return bitrateByFormat.has(requestedFormat) ? requestedFormat : preferredFormat;
};

const selectFormatsForSession = (_currentUser, requestedFormat) => [normalizeFormat(requestedFormat)];

const estimatedSizeForFormat = (media, format) => {
  const size = format === "MP3_320"
    ? Number(media.estimatedSize320)
    : Number(media.estimatedSize128);
  return Number.isSafeInteger(size) && size > 0 ? size : null;
};

const isWrongLicenseError = (error) =>
  error?.name === "WrongLicense" || /wronglicense|wrong license|license/i.test(error?.message ?? "");

const isTransientNetworkError = (error) =>
  /connection reset|cannot connect|timeout|timed out|econnreset|etimedout/i.test(error.message ?? "");

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

const withTransientRetry = async (
  operation,
  { attempts = 3, delayMs = 350, shouldRetry = isTransientNetworkError } = {}
) => {
  let lastError;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await operation(attempt);
    } catch (error) {
      lastError = error;
      if (attempt >= attempts - 1 || !shouldRetry(error)) throw error;
      await delay(delayMs * (attempt + 1));
    }
  }

  throw lastError;
};

const isRetryableMediaResolutionError = (error) =>
  isTransientNetworkError(error) || error?.name === "MediaURLNotFound";

const cacheTrackMedia = (trackId, media) => {
  const now = Date.now();
  const tokenExpiresAt = Number(media.tokenExpire) > 0
    ? Number(media.tokenExpire) * 1000
    : now + 45 * 60 * 1000;
  const expiresAt = Math.min(tokenExpiresAt - 60 * 1000, now + 45 * 60 * 1000);
  const cached = {
    ...media,
    expiresAt: Math.max(expiresAt, now + 5 * 60 * 1000),
  };
  trackMediaCache.set(String(trackId), cached);
  return cached;
};

const cacheTrackMediaFromPayload = (payload) => {
  const seen = new Set();

  const visit = (value) => {
    if (!value) return;
    if (Array.isArray(value)) {
      for (const item of value) visit(item);
      return;
    }
    if (typeof value !== "object") return;

    const id = value.id ?? value.SNG_ID;
    const mediaToken = value.mediaToken ?? value.TRACK_TOKEN;
    if (isValidTrackId(id) && typeof mediaToken === "string" && mediaToken.length > 0) {
      const trackId = String(id);
      const cacheKey = `${trackId}:${mediaToken}`;
      if (!seen.has(cacheKey)) {
        seen.add(cacheKey);
        cacheTrackMedia(trackId, {
          id: trackId,
          title: value.title ?? value.SNG_TITLE ?? null,
          duration: Number(value.duration ?? value.DURATION ?? 0),
          mediaToken,
          mediaVersion: value.mediaVersion ?? value.MEDIA_VERSION ?? null,
          tokenExpire: value.tokenExpire ?? value.TRACK_TOKEN_EXPIRE ?? null,
          canStreamSub: value.canStreamSub ?? value.readable !== false,
          estimatedSize128: Number(value.estimatedSize128 ?? value.FILESIZE_MP3_128 ?? 0),
          estimatedSize320: Number(value.estimatedSize320 ?? value.FILESIZE_MP3_320 ?? 0),
          source: "deezer-gql-catalog",
        });
      }
    }

    for (const key of ["data", "tracks", "items"]) visit(value[key]);
  };

  visit(payload);
};

const startupSegmentKey = (trackId, format) => `${trackId}:${format}`;

const getCachedStartupSegment = (key) => {
  const cached = startupSegmentCache.get(key);
  if (!cached) return null;
  if (cached.expiresAt <= Date.now()) {
    startupSegmentCache.delete(key);
    return null;
  }

  startupSegmentCache.delete(key);
  startupSegmentCache.set(key, cached);
  return cached;
};

const setCachedStartupSegment = (key, value) => {
  startupSegmentCache.delete(key);
  startupSegmentCache.set(key, value);

  while (startupSegmentCache.size > startupSegmentMaxEntries) {
    const oldestKey = startupSegmentCache.keys().next().value;
    startupSegmentCache.delete(oldestKey);
  }
};

const getCachedMediaURLFailure = (key) => {
  const cached = mediaURLFailureCache.get(key);
  if (!cached) return null;
  if (cached.expiresAt <= Date.now()) {
    mediaURLFailureCache.delete(key);
    return null;
  }

  const error = new Error(cached.message);
  error.name = cached.name;
  error.statusCode = cached.statusCode;
  error.bitrate = cached.bitrate;
  return error;
};

const setCachedMediaURLFailure = (key, error) => {
  if (isTransientNetworkError(error) || error?.name === "MediaURLNotFound") return;

  mediaURLFailureCache.set(key, {
    name: error.name ?? "MediaURLFailure",
    message: error.message ?? "Deezer did not return a media URL.",
    statusCode: error.statusCode ?? 500,
    bitrate: error.bitrate ?? null,
    expiresAt: Date.now() + 90 * 1000,
  });
};

const mapWithConcurrency = async (items, concurrency, worker) => {
  const results = new Array(items.length);
  let cursor = 0;
  const workerCount = Math.max(1, Math.min(concurrency, items.length));

  await Promise.all(Array.from({ length: workerCount }, async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await worker(items[index], index);
    }
  }));

  return results;
};

const withTimeout = async (promise, timeoutMs) => {
  let timeout;
  try {
    return await Promise.race([
      promise,
      new Promise((resolve) => {
        timeout = setTimeout(() => resolve(null), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timeout);
  }
};

const withRejectTimeout = async (promise, timeoutMs, message) => {
  let timeout;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timeout = setTimeout(() => {
          const error = new Error(message);
          error.name = "OperationTimeout";
          reject(error);
        }, timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timeout);
  }
};

const resolveTrackMediaFromGW = async (dz, trackId) => {
  const track = await dz.gw.get_track_with_fallback(trackId);
  const mediaToken = track?.TRACK_TOKEN;
  if (!mediaToken) {
    const error = new Error("Deezer gateway did not return a track token.");
    error.name = "MediaTokenNotFound";
    throw error;
  }

  return cacheTrackMedia(trackId, {
    id: String(track?.SNG_ID ?? trackId),
    title: track?.SNG_TITLE ?? null,
    duration: Number(track?.DURATION ?? 0),
    mediaToken,
    mediaVersion: track?.MEDIA_VERSION ?? null,
    tokenExpire: track?.TRACK_TOKEN_EXPIRE ?? null,
    canStreamSub: track?.RIGHTS?.STREAM_SUB_AVAILABLE !== false,
    estimatedSize128: Number(track?.FILESIZE_MP3_128 ?? 0),
    estimatedSize320: Number(track?.FILESIZE_MP3_320 ?? 0),
    source: "deezer-gw",
  });
};

const resolveTrackMedia = async (dz, trackId) => {
  const cacheKey = String(trackId);
  const cached = trackMediaCache.get(cacheKey);
  if (cached?.expiresAt > Date.now()) return cached;

  const inflight = trackMediaInflight.get(cacheKey);
  if (inflight) return inflight;

  const promise = (async () => {
    try {
      return await withTransientRetry(
        () => withRejectTimeout(
          resolveTrackMediaFromGW(dz, trackId),
          900,
          "Deezer gateway track metadata timed out."
        ),
        { attempts: 1, delayMs: 300 }
      );
    } catch (_gwError) {
      const media = await callCatalog(["track-media", "--id", trackId], { timeoutMs: 12000, attempts: 2 });
      return cacheTrackMedia(trackId, {
        ...media,
        source: "deezer-gql",
      });
    }
  })().finally(() => {
    trackMediaInflight.delete(cacheKey);
  });

  trackMediaInflight.set(cacheKey, promise);
  return promise;
};

const loginViaArlWithRetry = async (dz, arl, attempts = 3) => {
  let lastError;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await dz.loginViaArl(arl);
    } catch (error) {
      lastError = error;
      if (attempt >= attempts - 1 || !isTransientNetworkError(error)) throw error;
      await delay(650 * (attempt + 1));
    }
  }

  throw lastError;
};

const normalizeARL = (value) => {
  const normalized = String(value ?? "").trim();
  if (normalized.length < 32 || /\s/.test(normalized)) return null;
  return normalized;
};

const asyncHandler = (handler) => async (request, response) => {
  try {
    await handler(request, response);
  } catch (error) {
    const networkError = isTransientNetworkError(error);
    const status = error.statusCode ?? (networkError ? 503 : 500);
    response.status(status).json({
      result: false,
      errid: networkError ? "NetworkUnavailable" : error.name ?? "NoirwaveBackendError",
      error: error.message,
    });
  }
};

const applyStreamProbeHeaders = (response, { range, size }) => {
  response.status(range ? 206 : 200);
  response.setHeader("Content-Type", "audio/mpeg");
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Accept-Ranges", "bytes");
  response.setHeader("X-Content-Type-Options", "nosniff");

  if (range) {
    response.setHeader("Content-Range", `bytes ${range.start}-${range.end}/${range.total}`);
    response.setHeader("Content-Length", String(range.contentLength));
  } else if (Number.isSafeInteger(size) && size > 0) {
    response.setHeader("Content-Length", String(size));
  }
};

const logStreamRequest = (request, { resolved, range, status, startupCache = null }) => {
  console.log("[stream]", {
    method: request.method,
    trackId: request.params.trackId,
    requestRange: request.headers.range ?? null,
    status,
    responseRange: range && range !== "unsatisfiable"
      ? `bytes ${range.start}-${range.end}/${range.total}`
      : null,
    format: resolved?.format ?? null,
    bitrate: resolved?.bitrate ?? null,
    size: resolved?.size ?? null,
    startupCache,
  });
};

const ensureSDK = async () => {
  if (sdkState) return sdkState;

  const arl = readARL();
  if (!arl) {
    const error = new Error("No Deezer session configured.");
    error.statusCode = 401;
    throw error;
  }

  const modules = await loadDeemixModules();
  const dz = new modules.deezerSdk.Deezer();
  const loggedIn = await loginViaArlWithRetry(dz, arl);
  if (!loggedIn) {
    const error = new Error("Deezer session login failed.");
    error.statusCode = 401;
    throw error;
  }

  sdkState = { ...modules, dz };
  return sdkState;
};

const resolveMediaURLForFormat = async (dz, media, trackId, selectedFormat) => {
  const cacheKey = `${trackId}:${selectedFormat}`;
  const cachedFormat = mediaURLCache.get(cacheKey);
  if (cachedFormat?.expiresAt > Date.now()) return cachedFormat;

  const cachedFailure = getCachedMediaURLFailure(cacheKey);
  if (cachedFailure) throw cachedFailure;

  const inflight = mediaURLInflight.get(cacheKey);
  if (inflight) return inflight;

  const promise = (async () => {
    const url = await withTransientRetry(
      async () => {
        const candidate = await withRejectTimeout(
          dz.get_track_url(media.mediaToken, selectedFormat),
          1500,
          "Deezer media URL timed out."
        );
        if (candidate) return candidate;

        const error = new Error("Deezer did not return a media URL.");
        error.name = "MediaURLNotFound";
        error.statusCode = 404;
        error.bitrate = bitrateByFormat.get(selectedFormat);
        throw error;
      },
      { attempts: 3, delayMs: 350, shouldRetry: isRetryableMediaResolutionError }
    );

    const resolved = {
      url,
      format: selectedFormat,
      bitrate: bitrateByFormat.get(selectedFormat),
      size: estimatedSizeForFormat(media, selectedFormat),
      expiresAt: Date.now() + 10 * 60 * 1000,
    };
    mediaURLCache.set(cacheKey, resolved);
    return resolved;
  })()
    .catch((error) => {
      setCachedMediaURLFailure(cacheKey, error);
      throw error;
    })
    .finally(() => {
      mediaURLInflight.delete(cacheKey);
    });

  mediaURLInflight.set(cacheKey, promise);
  return promise;
};

const resolveMediaURL = async (trackId, requestedFormat = preferredFormat) => {
  const { dz } = await ensureSDK();
  const media = await resolveTrackMedia(dz, trackId);
  const selectedFormats = selectFormatsForSession(dz.currentUser, requestedFormat);

  if (!media.canStreamSub) {
    const error = new Error("The current Deezer session cannot stream this track.");
    error.name = "CantStream";
    error.statusCode = 403;
    error.bitrate = bitrateByFormat.get(normalizeFormat(requestedFormat));
    throw error;
  }

  let lastError;
  for (const selectedFormat of selectedFormats) {
    try {
      return await resolveMediaURLForFormat(dz, media, trackId, selectedFormat);
    } catch (error) {
      lastError = error;
      if (isWrongLicenseError(error)) continue;
      throw error;
    }
  }

  if (isWrongLicenseError(lastError)) {
    const requested = normalizeFormat(requestedFormat);
    const mapped = new Error(`The current Deezer session cannot stream ${requested}.`);
    mapped.name = "CantStream";
    mapped.statusCode = 403;
    mapped.bitrate = bitrateByFormat.get(requested);
    throw mapped;
  }

  throw lastError ?? new Error("Deezer did not return a media URL.");
};

const prefetchStartupSegment = async (trackId, requestedFormat = preferredFormat) => {
  const format = normalizeFormat(requestedFormat);
  const cacheKey = startupSegmentKey(trackId, format);
  const cached = getCachedStartupSegment(cacheKey);
  if (cached) return { ...cached, cacheHit: true };

  const inflight = startupSegmentInflight.get(cacheKey);
  if (inflight) return inflight;

  const promise = (async () => {
    const resolved = await withTransientRetry(
      () => resolveMediaURL(trackId, format),
      { attempts: 3, delayMs: 500, shouldRetry: isRetryableMediaResolutionError }
    );
    const { deemix } = await ensureSDK();
    const buffer = await withTransientRetry(
      () => readDeezerStartupSegment({
        mediaURL: resolved.url,
        trackId,
        utils: deemix.utils,
        byteLimit: startupSegmentBytes,
      }),
      { attempts: 3, delayMs: 300 }
    );
    const startup = {
      ...resolved,
      buffer,
      expiresAt: Math.min(resolved.expiresAt, Date.now() + 10 * 60 * 1000),
    };
    setCachedStartupSegment(cacheKey, startup);
    return { ...startup, cacheHit: false };
  })().finally(() => {
    startupSegmentInflight.delete(cacheKey);
  });

  startupSegmentInflight.set(cacheKey, promise);
  return promise;
};

const startupForInitialRange = async (trackId, format, range, { startIfMissing = false } = {}) => {
  if (!range || range === "unsatisfiable" || range.start !== 0) return { startup: null, state: null };

  const cacheKey = startupSegmentKey(trackId, format);
  const cached = getCachedStartupSegment(cacheKey);
  if (cached) return { startup: cached, state: "hit" };

  const inflight = startupSegmentInflight.get(cacheKey)
    ?? (startIfMissing ? prefetchStartupSegment(trackId, format) : null);
  if (!inflight) return { startup: null, state: "miss" };

  const startup = await withTimeout(inflight, startupJoinTimeoutMs);
  return startup ? { startup, state: "joined" } : { startup: null, state: "miss" };
};

const continueRangeAfterPrefix = (range, prefixLength) => ({
  ...range,
  start: range.start + prefixLength,
  contentLength: range.contentLength - prefixLength,
});

const writeStartupPrefix = async (response, prefix) => {
  response.flushHeaders();
  if (!response.write(prefix)) {
    await once(response, "drain");
  }
};

const extractTrackIds = (payload) => {
  const ids = [];
  const seen = new Set();
  const visit = (value) => {
    if (!value || ids.length >= backgroundPrefetchLimit) return;
    if (Array.isArray(value)) {
      for (const item of value) visit(item);
      return;
    }
    if (typeof value !== "object") return;

    const id = value.id ?? value.SNG_ID;
    if (isValidTrackId(id) && !seen.has(String(id))) {
      seen.add(String(id));
      ids.push(String(id));
    }

    for (const key of ["data", "tracks", "items"]) visit(value[key]);
  };

  visit(payload);
  return ids;
};

const drainStartupPrefetchQueue = () => {
  while (activeStartupPrefetches < prefetchConcurrency && startupPrefetchQueue.length > 0) {
    const task = startupPrefetchQueue.shift();
    startupPrefetchQueuedKeys.delete(task.key);

    if (getCachedStartupSegment(task.key) || startupSegmentInflight.has(task.key)) {
      continue;
    }

    activeStartupPrefetches += 1;
    prefetchStartupSegment(task.trackId, task.format)
      .catch((error) => {
        if (task.attempt < 2 && isRetryableMediaResolutionError(error)) {
          setTimeout(() => {
            enqueueStartupPrefetch(task.trackId, task.format, task.attempt + 1);
          }, 750 * (task.attempt + 1));
          return;
        }

        console.log("[prefetch] skipped", {
          trackId: task.trackId,
          format: task.format,
          errid: error.name ?? "PrefetchFailed",
          message: error.message,
        });
      })
      .finally(() => {
        activeStartupPrefetches -= 1;
        drainStartupPrefetchQueue();
      });
  }
};

const enqueueStartupPrefetch = (trackId, format = preferredFormat, attempt = 0, { priority = false } = {}) => {
  const normalizedFormat = normalizeFormat(format);
  const key = startupSegmentKey(trackId, normalizedFormat);
  if (
    getCachedStartupSegment(key)
    || startupSegmentInflight.has(key)
  ) {
    return;
  }

  if (startupPrefetchQueuedKeys.has(key)) {
    if (priority) {
      const index = startupPrefetchQueue.findIndex((task) => task.key === key);
      if (index >= 0) {
        const [task] = startupPrefetchQueue.splice(index, 1);
        startupPrefetchQueue.unshift({ ...task, attempt: Math.min(task.attempt, attempt) });
        drainStartupPrefetchQueue();
      }
    }
    return;
  }

  startupPrefetchQueuedKeys.add(key);
  const task = { key, trackId, format: normalizedFormat, attempt };
  if (priority) {
    startupPrefetchQueue.unshift(task);
  } else {
    startupPrefetchQueue.push(task);
  }
  drainStartupPrefetchQueue();
};

const scheduleBackgroundPrefetch = (trackIds, format = preferredFormat, { priority = false } = {}) => {
  const ids = [...new Set(trackIds.map(String).filter(isValidTrackId))].slice(0, backgroundPrefetchLimit);
  if (ids.length === 0) return;

  const orderedIds = priority ? [...ids].reverse() : ids;
  for (const trackId of orderedIds) {
    enqueueStartupPrefetch(trackId, format, 0, { priority });
  }
};

const warmForegroundPrefetch = async (trackIds, format = preferredFormat) => {
  const ids = [...new Set(trackIds.map(String).filter(isValidTrackId))].slice(0, foregroundPrefetchLimit);
  if (ids.length === 0 || foregroundPrefetchTimeoutMs === 0) return;

  await withTimeout(
    Promise.allSettled(ids.map((trackId) => prefetchStartupSegment(trackId, format))),
    foregroundPrefetchTimeoutMs
  );
};

app.get("/api/connect", asyncHandler(async (_request, response) => {
  const sdk = await ensureSDK();
  response.json({
    result: true,
    deezerAvailable: "yes",
    autologin: false,
    currentUser: {
      id: sdk.dz.currentUser?.id ?? null,
      name: sdk.dz.currentUser?.name ?? null,
      picture: sdk.dz.currentUser?.picture ?? null,
      can_stream_hq: sdk.dz.currentUser?.can_stream_hq ?? false,
      can_stream_lossless: sdk.dz.currentUser?.can_stream_lossless ?? false,
    },
    source: "Noirwave Backend",
    playback: "deezer-sdk",
    format: preferredFormat,
    fallbackFormat: null,
  });
}));

app.post("/api/loginArl", asyncHandler(async (request, response) => {
  const arl = normalizeARL(request.body?.arl);
  if (!arl) {
    response.status(400).json({ result: false, errid: "InvalidSession", error: "Invalid Deezer session token." });
    return;
  }

  setRuntimeARL(arl);
  sdkState = null;
  mediaURLCache.clear();
  mediaURLFailureCache.clear();
  mediaURLInflight.clear();
  trackMediaCache.clear();
  trackMediaInflight.clear();
  startupSegmentCache.clear();
  startupSegmentInflight.clear();
  startupPrefetchQueue.length = 0;
  startupPrefetchQueuedKeys.clear();

  const sdk = await ensureSDK();
  response.json({
    result: true,
    status: 1,
    user: {
      id: sdk.dz.currentUser?.id ?? null,
      name: sdk.dz.currentUser?.name ?? null,
      picture: sdk.dz.currentUser?.picture ?? null,
      can_stream_hq: sdk.dz.currentUser?.can_stream_hq ?? false,
      can_stream_lossless: sdk.dz.currentUser?.can_stream_lossless ?? false,
    },
  });
}));

app.get("/api/search", asyncHandler(async (request, response) => {
  const term = String(request.query.term ?? "").trim();
  const scope = String(request.query.type ?? "track");
  const count = Number(request.query.nb ?? 30);
  if (!term) {
    response.json({ data: [], total: 0, type: scope });
    return;
  }

  const payload = await callCatalog([
    "search",
    "--query",
    term,
    "--scope",
    scope,
    "--limit",
    String(count),
  ]);
  if (scope === "track") {
    cacheTrackMediaFromPayload(payload);
    const trackIds = extractTrackIds(payload);
    await warmForegroundPrefetch(trackIds, preferredFormat);
    scheduleBackgroundPrefetch(trackIds, preferredFormat);
  }

  response.json(payload);
}));

app.get("/api/getTracklist", asyncHandler(async (request, response) => {
  const type = String(request.query.type ?? "");
  const id = String(request.query.id ?? "");
  if (!id || !["artist", "album"].includes(type)) {
    response.status(400).json({ result: false, error: "type and id are required" });
    return;
  }

  const payload = await callCatalog([type, "--id", id], { timeoutMs: 30000 });
  cacheTrackMediaFromPayload(payload);
  response.json(payload);
  scheduleBackgroundPrefetch(extractTrackIds(payload), preferredFormat);
}));

app.get("/api/trackMedia/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).json({ result: false, errid: "InvalidTrackId", error: "trackId must be numeric" });
    return;
  }

  const payload = await callCatalog(["track-media", "--id", request.params.trackId]);
  cacheTrackMediaFromPayload(payload);
  response.json(payload);
}));

app.get("/api/lyrics/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).json({ result: false, errid: "InvalidTrackId", error: "trackId must be numeric" });
    return;
  }

  const payload = await callCatalog(["lyrics", "--id", request.params.trackId], { timeoutMs: 22000 });
  response.json(normalizeLyricsPayload(payload, request.params.trackId));
}));

app.get("/api/playback/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).json({ result: false, errid: "InvalidTrackId", error: "trackId must be numeric" });
    return;
  }

  const requestedFormat = normalizeFormat(request.query.format);
  try {
    const resolved = await resolveMediaURL(request.params.trackId, requestedFormat);
    response.json({
      result: true,
      format: resolved.format,
      bitrate: resolved.bitrate,
      streamURL: `http://${host}:${port}/api/stream/${encodeURIComponent(request.params.trackId)}?format=${encodeURIComponent(resolved.format)}`,
    });
  } catch (error) {
    if (error.name === "CantStream") {
      response.status(403).json({
        result: false,
        errid: "CantStream",
        bitrate: error.bitrate ?? bitrateByFormat.get(requestedFormat),
        format: requestedFormat,
      });
      return;
    }

    throw error;
  }
}));

app.post("/api/prefetch", asyncHandler(async (request, response) => {
  const requestedFormat = normalizeFormat(request.body?.format);
  const waitForStartup = request.body?.waitForStartup === true;
  const waitTimeoutMs = Math.max(100, Math.min(Number(request.body?.timeoutMs) || startupJoinTimeoutMs, 3000));
  const rawTrackIds = Array.isArray(request.body?.trackIds) ? request.body.trackIds : [];
  const trackIds = [...new Set(rawTrackIds.map((value) => String(value)).filter(isValidTrackId))].slice(0, 40);

  if (trackIds.length === 0) {
    response.status(400).json({
      result: false,
      errid: "InvalidTrackIds",
      error: "trackIds must include at least one numeric track id",
    });
    return;
  }

  scheduleBackgroundPrefetch(trackIds, requestedFormat, { priority: true });
  if (waitForStartup) {
    await withTimeout(
      Promise.allSettled(trackIds.slice(0, 2).map((trackId) => prefetchStartupSegment(trackId, requestedFormat))),
      waitTimeoutMs
    );
  }

  const warmed = trackIds.map((trackId) => {
    const cacheKey = startupSegmentKey(trackId, requestedFormat);
    const cached = getCachedStartupSegment(cacheKey);
    const inflight = startupSegmentInflight.has(cacheKey);
    const queued = startupPrefetchQueuedKeys.has(cacheKey);

    return {
      result: true,
      trackId,
      format: requestedFormat,
      bitrate: bitrateByFormat.get(requestedFormat),
      startupBytes: cached?.buffer.length ?? null,
      cacheHit: Boolean(cached),
      inflight: !cached && inflight,
      queued: !cached && !inflight && queued,
      accepted: !cached && !inflight && !queued,
    };
  });

  response.json({
    result: true,
    format: requestedFormat,
    warmed,
  });
}));

app.head("/api/stream/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).end();
    return;
  }

  const requestedFormat = normalizeFormat(request.query.format);
  const resolved = await resolveMediaURL(request.params.trackId, requestedFormat);
  const range = parseRangeHeader(request.headers.range, resolved.size);

  if (range === "unsatisfiable") {
    logStreamRequest(request, { resolved, range, status: 416 });
    response
      .status(416)
      .set("Content-Range", `bytes */${resolved.size}`)
      .end();
    return;
  }

  if (range?.start === 0) {
    void prefetchStartupSegment(request.params.trackId, resolved.format).catch(() => {});
  }

  logStreamRequest(request, { resolved, range, status: range ? 206 : 200 });
  applyStreamProbeHeaders(response, { range, size: resolved.size });
  response.end();
}));

app.get("/api/stream/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).json({ result: false, errid: "InvalidTrackId", error: "trackId must be numeric" });
    return;
  }

  const requestedFormat = normalizeFormat(request.query.format);
  const [{ deemix }, resolved] = await Promise.all([
    ensureSDK(),
    resolveMediaURL(request.params.trackId, requestedFormat),
  ]);

  if (!resolved?.url) {
    response.status(404).json({ result: false, errid: "MediaURLNotFound", bitrate: bitrateByFormat.get(requestedFormat), format: requestedFormat });
    return;
  }

  const range = parseRangeHeader(request.headers.range, resolved.size);
  if (range === "unsatisfiable") {
    logStreamRequest(request, { resolved, range, status: 416 });
    response
      .status(416)
      .set("Content-Range", `bytes */${resolved.size}`)
      .end();
    return;
  }

  const shouldStartStartupPrefetch = range?.start === 0;
  const startupResult = await startupForInitialRange(
    request.params.trackId,
    resolved.format,
    range,
    { startIfMissing: shouldStartStartupPrefetch }
  );
  const startup = startupResult.startup;
  const startupRange = cachedStartupRange(startup, range);
  if (startupRange) {
    logStreamRequest(request, { resolved, range, status: range ? 206 : 200, startupCache: startupResult.state });
    response.setHeader("X-Noirwave-Startup-Cache", startupResult.state ?? "hit");
    applyStreamProbeHeaders(response, { range, size: resolved.size });
    response.end(startupRange);
    return;
  }

  const startupPrefix = cachedStartupPrefix(startup, range);
  if (startupPrefix?.length > 0) {
    const continuationRange = continueRangeAfterPrefix(range, startupPrefix.length);
    logStreamRequest(request, {
      resolved,
      range,
      status: range ? 206 : 200,
      startupCache: `${startupResult.state}:prefix`,
    });
    response.setHeader("X-Noirwave-Startup-Cache", `${startupResult.state ?? "hit"}; prefix`);
    applyStreamProbeHeaders(response, { range, size: resolved.size });
    await writeStartupPrefix(response, startupPrefix);

    if (continuationRange.contentLength <= 0) {
      response.end();
      return;
    }

    streamDeezerMedia({
      mediaURL: resolved.url,
      trackId: request.params.trackId,
      response,
      utils: deemix.utils,
      range: continuationRange,
    });
    return;
  }

  logStreamRequest(request, { resolved, range, status: range ? 206 : 200, startupCache: startupResult.state });
  streamDeezerMedia({
    mediaURL: resolved.url,
    trackId: request.params.trackId,
    response,
    utils: deemix.utils,
    range,
  });
}));

app.get("/health", (_request, response) => {
  response.json({ ok: true, source: "Noirwave Backend" });
});

app.listen(port, host, () => {
  console.log(`Noirwave backend listening on http://${host}:${port}`);
});
