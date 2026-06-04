import got from "got";
import { Transform } from "node:stream";

const encryptedStreamMarkers = ["/mobile/", "/media/", "media.deezer.com"];
const decryptWindowSize = 2048 * 3;
const streamRetryDelayMs = 450;

export const isEncryptedStreamURL = (url) => encryptedStreamMarkers.some((marker) => url.includes(marker));

export const isRetriableStreamError = (error) =>
  /connection reset|socket hang up|timeout|timed out|econnreset|etimedout|econnrefused|eai_again|enetunreach/i
    .test(`${error?.code ?? ""} ${error?.message ?? ""}`);

export const parseRangeHeader = (rangeHeader, totalSize) => {
  const total = Number(totalSize);
  if (!Number.isSafeInteger(total) || total <= 0) return null;

  const match = /^bytes=(\d*)-(\d*)$/.exec(String(rangeHeader ?? "").trim());
  if (!match) return null;

  let start;
  let end;
  const [, rawStart, rawEnd] = match;

  if (rawStart === "" && rawEnd === "") return null;

  if (rawStart === "") {
    const suffixLength = Number(rawEnd);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) return "unsatisfiable";
    start = Math.max(total - suffixLength, 0);
    end = total - 1;
  } else {
    start = Number(rawStart);
    end = rawEnd === "" ? total - 1 : Number(rawEnd);
  }

  if (
    !Number.isSafeInteger(start)
    || !Number.isSafeInteger(end)
    || start < 0
    || end < start
    || start >= total
  ) {
    return "unsatisfiable";
  }

  const boundedEnd = Math.min(end, total - 1);
  return {
    start,
    end: boundedEnd,
    total,
    contentLength: boundedEnd - start + 1,
  };
};

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

export const createByteRangeStream = ({ start = 0, end = Number.POSITIVE_INFINITY }) => {
  let position = 0;
  let closed = false;

  return new Transform({
    transform(chunk, _encoding, callback) {
      if (closed) {
        callback();
        return;
      }

      const chunkStart = position;
      const chunkEnd = position + chunk.length - 1;
      position += chunk.length;

      if (chunkEnd < start) {
        callback();
        return;
      }

      const sliceStart = Math.max(start - chunkStart, 0);
      const sliceEnd = Math.min(end - chunkStart + 1, chunk.length);

      if (sliceEnd <= sliceStart) {
        callback();
        return;
      }

      const output = chunk.subarray(sliceStart, sliceEnd);
      if (chunkEnd >= end) {
        closed = true;
        this.push(output);
        this.emit("rangeEnd");
        this.push(null);
        callback();
        return;
      }
      callback(null, output);
    },
  });
};

const applyAudioHeaders = (response, range) => {
  if (response.headersSent) return;
  response.status(range ? 206 : 200);
  response.setHeader("Content-Type", "audio/mpeg");
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Accept-Ranges", "bytes");
  response.setHeader("X-Content-Type-Options", "nosniff");
  if (range) {
    response.setHeader("Content-Range", `bytes ${range.start}-${range.end}/${range.total}`);
    response.setHeader("Content-Length", String(range.contentLength));
  }
};

const sendStreamFailure = (response, error) => {
  console.error("[stream] upstream failure", {
    code: error?.code ?? null,
    name: error?.name ?? null,
    message: error?.message ?? null,
  });

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

export const streamDeezerMedia = ({
  mediaURL,
  trackId,
  response,
  utils,
  range = null,
  attempts = 3,
}) => {
  const encrypted = isEncryptedStreamURL(mediaURL);
  let activeSource;
  let activeDecrypt;
  let activeDepad;
  let activeRange;
  let didClose = false;
  let didStartAudio = false;
  let attempt = 0;

  const destroyActivePipeline = () => {
    activeSource?.destroy();
    activeDecrypt?.destroy();
    activeDepad?.destroy();
    activeRange?.destroy();
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
    const rangeStream = range ? createByteRangeStream(range) : null;

    activeSource = source;
    activeDecrypt = decrypt;
    activeDepad = depad;
    activeRange = rangeStream;

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
      applyAudioHeaders(response, range);
    });
    depad.once("data", () => {
      didStartAudio = true;
    });

    source.once("error", handlePipelineError);
    decrypt.once("error", handlePipelineError);
    depad.once("error", handlePipelineError);
    rangeStream?.once("error", handlePipelineError);
    rangeStream?.once("rangeEnd", () => {
      source.destroy();
      decrypt.destroy();
      depad.destroy();
    });

    let pipeline = source
      .pipe(decrypt)
      .pipe(depad);
    if (rangeStream) pipeline = pipeline.pipe(rangeStream);
    pipeline.pipe(response);
  };

  response.on("close", () => {
    didClose = true;
    destroyActivePipeline();
  });

  startAttempt();
};
