import test from "node:test";
import assert from "node:assert/strict";
import { isEncryptedStreamURL, isRetriableStreamError } from "../src/streaming.mjs";

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
