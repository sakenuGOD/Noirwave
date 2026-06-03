import got from "got";
import { Transform } from "node:stream";

const encryptedStreamMarkers = ["/mobile/", "/media/", "media.deezer.com"];
const decryptWindowSize = 2048 * 3;
const streamRetryDelayMs = 450;

export const isEncryptedStreamURL = (url) => encryptedStreamMarkers.some((marker) => url.includes(marker));

export const isRetriableStreamError = (error) =>
  /connection reset|socket hang up|timeout|timed out|econnreset|etimedout|econnrefused|eai_again|enetunreach/i
    .test(`${error?.code ?? ""} ${error?.message ?? ""}`);

export const createStripeDecryptStream = ({ trackId, utils, encrypted }) => {
  if (!encrypted) return new Transform({
    transform(chunk, _encoding, callback) {
      callback(null, chunk);
    },
  });

  const blowfishKey = utils.generateBlowfishKey(String(trackId));
  let pending = Buffer.alloc(0);

  return new Transform({
    transform(chunk, _encoding, callback) {
      pending = Buffer.concat([pending, chunk]);
      const output = [];

      while (pending.length >= decryptWindowSize) {
        const window = pending.subarray(0, decryptWindowSize);
        pending = pending.subarray(decryptWindowSize);
        output.push(Buffer.concat([
          utils.decryptChunk(window.subarray(0, 2048), blowfishKey),
          window.subarray(2048),
        ]));
      }

      callback(null, output.length ? Buffer.concat(output) : undefined);
    },
    flush(callback) {
      if (pending.length >= 2048) {
        callback(null, Buffer.concat([
          utils.decryptChunk(pending.subarray(0, 2048), blowfishKey),
          pending.subarray(2048),
        ]));
        return;
      }

      callback(null, pending.length ? pending : undefined);
    },
  });
};

export const createDepadStream = () => {
  let isStart = true;

  return new Transform({
    transform(chunk, _encoding, callback) {
      let output = chunk;
      if (isStart && output[0] === 0 && output.subarray(4, 8).toString() !== "ftyp") {
        let index = 0;
        while (index < output.length && output[index] === 0) index += 1;
        output = output.subarray(index);
      }
      isStart = false;
      callback(null, output);
    },
  });
};

const applyAudioHeaders = (response) => {
  if (response.headersSent) return;
  response.status(200);
  response.setHeader("Content-Type", "audio/mpeg");
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Accept-Ranges", "none");
  response.setHeader("X-Content-Type-Options", "nosniff");
};

const sendStreamFailure = (response, error) => {
  if (response.headersSent) {
    response.destroy(error);
    return;
  }

  response.removeHeader("Content-Type");
  response.removeHeader("Cache-Control");
  response.removeHeader("Accept-Ranges");
  response.removeHeader("X-Content-Type-Options");
  response.status(503).json({
    result: false,
    errid: "NetworkUnavailable",
    error: "Deezer media stream failed before audio started.",
  });
};

export const streamDeezerMedia = ({ mediaURL, trackId, response, utils, attempts = 3 }) => {
  const encrypted = isEncryptedStreamURL(mediaURL);
  let activeSource;
  let activeDecrypt;
  let activeDepad;
  let didClose = false;
  let didStartAudio = false;
  let attempt = 0;

  const destroyActivePipeline = () => {
    activeSource?.destroy();
    activeDecrypt?.destroy();
    activeDepad?.destroy();
  };

  const startAttempt = () => {
    if (didClose || response.headersSent) return;

    attempt += 1;
    const source = got.stream(mediaURL, {
      headers: {
        "User-Agent": "Mozilla/5.0 Noirwave/0.1",
      },
      https: {
        rejectUnauthorized: false,
      },
      retry: {
        limit: 0,
      },
      timeout: {
        request: 18000,
      },
    });
    const decrypt = createStripeDecryptStream({ trackId, utils, encrypted });
    const depad = createDepadStream();

    activeSource = source;
    activeDecrypt = decrypt;
    activeDepad = depad;

    const handlePipelineError = (error) => {
      destroyActivePipeline();
      if (didClose) return;

      const canRetry = !didStartAudio
        && !response.headersSent
        && attempt < attempts
        && isRetriableStreamError(error);

      if (canRetry) {
        setTimeout(startAttempt, streamRetryDelayMs * attempt);
        return;
      }

      sendStreamFailure(response, error);
    };

    source.once("response", () => {
      applyAudioHeaders(response);
    });
    depad.once("data", () => {
      didStartAudio = true;
    });

    source.once("error", handlePipelineError);
    decrypt.once("error", handlePipelineError);
    depad.once("error", handlePipelineError);

    source
      .pipe(decrypt)
      .pipe(depad)
      .pipe(response);
  };

  response.on("close", () => {
    didClose = true;
    destroyActivePipeline();
  });

  startAttempt();
};
