import got from "got";
import { Transform } from "node:stream";

const encryptedStreamMarkers = ["/mobile/", "/media/", "media.deezer.com"];
const decryptWindowSize = 2048 * 3;

export const isEncryptedStreamURL = (url) => encryptedStreamMarkers.some((marker) => url.includes(marker));

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

export const streamDeezerMedia = ({ mediaURL, trackId, response, utils }) => {
  const encrypted = isEncryptedStreamURL(mediaURL);
  response.status(200);
  response.setHeader("Content-Type", "audio/mpeg");
  response.setHeader("Cache-Control", "no-store");

  const source = got.stream(mediaURL, {
    headers: {
      "User-Agent": "Mozilla/5.0 Noirwave/0.1",
    },
    https: {
      rejectUnauthorized: false,
    },
    retry: {
      limit: 1,
    },
  });

  source
    .pipe(createStripeDecryptStream({ trackId, utils, encrypted }))
    .pipe(createDepadStream())
    .pipe(response);

  response.on("close", () => {
    source.destroy();
  });
};
