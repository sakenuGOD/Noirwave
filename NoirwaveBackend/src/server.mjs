import express from "express";
import { callCatalog } from "./pythonCatalog.mjs";
import { loadDeemixModules } from "./deemixModules.mjs";
import { readARL, setRuntimeARL } from "./session.mjs";
import { streamDeezerMedia } from "./streaming.mjs";
import { normalizeLyricsPayload } from "./lyricsMapper.mjs";

const app = express();
const port = Number(process.env.NOIRWAVE_BACKEND_PORT ?? 6605);
const host = process.env.NOIRWAVE_BACKEND_HOST ?? "127.0.0.1";
const preferredFormat = process.env.NOIRWAVE_DEEZER_FORMAT ?? "MP3_320";
const fallbackFormat = "MP3_128";
const formatPreferences = [...new Set([preferredFormat, fallbackFormat])];
const bitrateByFormat = new Map([
  ["MP3_320", 3],
  ["MP3_128", 1],
]);

let sdkState = null;
const mediaURLCache = new Map();

app.use(express.json());

const isValidTrackId = (value) => /^\d+$/.test(String(value ?? ""));

const normalizeFormat = (value) => {
  const requestedFormat = String(value ?? preferredFormat).trim();
  return bitrateByFormat.has(requestedFormat) ? requestedFormat : preferredFormat;
};

const isWrongLicenseError = (error) =>
  error?.name === "WrongLicense" || /wronglicense|wrong license|license/i.test(error?.message ?? "");

const isTransientNetworkError = (error) =>
  /connection reset|cannot connect|timeout|timed out|econnreset|etimedout/i.test(error.message ?? "");

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

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

const resolveMediaURL = async (trackId, requestedFormat = preferredFormat) => {
  const selectedFormats = requestedFormat === preferredFormat
    ? formatPreferences
    : [normalizeFormat(requestedFormat)];

  const [{ dz }, media] = await Promise.all([
    ensureSDK(),
    callCatalog(["track-media", "--id", trackId]),
  ]);

  if (!media.canStreamSub) {
    const error = new Error("The current Deezer session cannot stream this track.");
    error.name = "CantStream";
    error.statusCode = 403;
    error.bitrate = 3;
    throw error;
  }

  let lastError;
  for (const selectedFormat of selectedFormats) {
    const cacheKey = `${trackId}:${selectedFormat}`;
    const cachedFormat = mediaURLCache.get(cacheKey);
    if (cachedFormat?.expiresAt > Date.now()) return cachedFormat;

    try {
      const url = await dz.get_track_url(media.mediaToken, selectedFormat);
      if (!url) {
        const error = new Error("Deezer did not return a media URL.");
        error.name = "MediaURLNotFound";
        error.statusCode = 404;
        throw error;
      }

      const resolved = {
        url,
        format: selectedFormat,
        bitrate: bitrateByFormat.get(selectedFormat),
        expiresAt: Date.now() + 10 * 60 * 1000,
      };
      mediaURLCache.set(cacheKey, resolved);
      return resolved;
    } catch (error) {
      lastError = error;
      if (isWrongLicenseError(error)) continue;
      throw error;
    }
  }

  if (isWrongLicenseError(lastError)) {
    const mapped = new Error(`The current Deezer session cannot stream ${selectedFormats.join(" or ")}.`);
    mapped.name = "CantStream";
    mapped.statusCode = 403;
    mapped.bitrate = bitrateByFormat.get(selectedFormats.at(-1));
    throw mapped;
  }

  throw lastError ?? new Error("Deezer did not return a media URL.");
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
    fallbackFormat,
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

  response.json(await callCatalog([
    "search",
    "--query",
    term,
    "--scope",
    scope,
    "--limit",
    String(count),
  ]));
}));

app.get("/api/getTracklist", asyncHandler(async (request, response) => {
  const type = String(request.query.type ?? "");
  const id = String(request.query.id ?? "");
  if (!id || !["artist", "album"].includes(type)) {
    response.status(400).json({ result: false, error: "type and id are required" });
    return;
  }

  response.json(await callCatalog([type, "--id", id], { timeoutMs: 30000 }));
}));

app.get("/api/trackMedia/:trackId", asyncHandler(async (request, response) => {
  if (!isValidTrackId(request.params.trackId)) {
    response.status(400).json({ result: false, errid: "InvalidTrackId", error: "trackId must be numeric" });
    return;
  }

  response.json(await callCatalog(["track-media", "--id", request.params.trackId]));
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

  try {
    const resolved = await resolveMediaURL(request.params.trackId);
    response.json({
      result: true,
      format: resolved.format,
      bitrate: resolved.bitrate,
      streamURL: `http://${host}:${port}/api/stream/${encodeURIComponent(request.params.trackId)}?format=${encodeURIComponent(resolved.format)}`,
    });
  } catch (error) {
    if (error.name === "CantStream") {
      response.status(403).json({ result: false, errid: "CantStream", bitrate: error.bitrate ?? 1, format: fallbackFormat });
      return;
    }

    throw error;
  }
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

  streamDeezerMedia({
    mediaURL: resolved.url,
    trackId: request.params.trackId,
    response,
    utils: deemix.utils,
  });
}));

app.get("/health", (_request, response) => {
  response.json({ ok: true, source: "Noirwave Backend" });
});

app.listen(port, host, () => {
  console.log(`Noirwave backend listening on http://${host}:${port}`);
});
