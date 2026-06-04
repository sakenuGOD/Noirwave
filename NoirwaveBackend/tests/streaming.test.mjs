import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { Readable } from "node:stream";
import {
  createByteRangeStream,
  isEncryptedStreamURL,
  isRetriableStreamError,
  parseRangeHeader,
} from "../src/streaming.mjs";

test("detects encrypted Deezer media URLs", () => {
  assert.equal(isEncryptedStreamURL("https://e-cdns-proxy-a.dzcdn.net/mobile/1/abc"), true);
  assert.equal(isEncryptedStreamURL("https://media.deezer.com/v1/abc"), true);
  assert.equal(isEncryptedStreamURL("https://cdn.example.com/file.mp3"), false);
});

test("classifies transient media stream failures for retry", () => {
  assert.equal(isRetriableStreamError(new Error("read ECONNRESET")), true);
  assert.equal(isRetriableStreamError(Object.assign(new Error("socket hang up"), { code: "ECONNRESET" })), true);
  assert.equal(isRetriableStreamError(new Error("wrong license")), false);
});

test("parses AVPlayer byte range probes", () => {
  assert.deepEqual(parseRangeHeader("bytes=0-1", 1000), {
    start: 0,
    end: 1,
    total: 1000,
    contentLength: 2,
  });
  assert.deepEqual(parseRangeHeader("bytes=2-", 1000), {
    start: 2,
    end: 999,
    total: 1000,
    contentLength: 998,
  });
});

test("rejects unsatisfiable byte ranges", () => {
  assert.equal(parseRangeHeader("bytes=1000-", 1000), "unsatisfiable");
  assert.equal(parseRangeHeader("items=0-1", 1000), null);
  assert.equal(parseRangeHeader("bytes=0-1", null), null);
});

test("cuts byte range streams and ends after the requested bytes", async () => {
  const chunks = [];
  const stream = Readable
    .from([Buffer.from("abcdef")])
    .pipe(createByteRangeStream({ start: 1, end: 3 }));

  stream.on("data", (chunk) => chunks.push(chunk));
  await once(stream, "end");

  assert.equal(Buffer.concat(chunks).toString("utf8"), "bcd");
});
