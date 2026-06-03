import test from "node:test";
import assert from "node:assert/strict";
import { isEncryptedStreamURL } from "../src/streaming.mjs";

test("detects encrypted Deezer media URLs", () => {
  assert.equal(isEncryptedStreamURL("https://e-cdns-proxy-a.dzcdn.net/mobile/1/abc"), true);
  assert.equal(isEncryptedStreamURL("https://media.deezer.com/v1/abc"), true);
  assert.equal(isEncryptedStreamURL("https://cdn.example.com/file.mp3"), false);
});
