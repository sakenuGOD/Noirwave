import test from "node:test";
import assert from "node:assert/strict";
import {
  defaultFormatForSession,
  fallbackFormatForSession,
  normalizeFormat,
  selectFormatsForSession,
} from "../src/playbackFormat.mjs";

test("selects 128 kbps when the Deezer session cannot stream HQ", () => {
  const currentUser = { can_stream_hq: false };

  assert.equal(defaultFormatForSession(currentUser, "MP3_320"), "MP3_128");
  assert.equal(fallbackFormatForSession(currentUser, "MP3_320"), "MP3_128");
  assert.deepEqual(selectFormatsForSession(currentUser, "MP3_320"), ["MP3_128"]);
});

test("keeps 320 kbps first for HQ-capable sessions with 128 fallback", () => {
  const currentUser = { can_stream_hq: true };

  assert.equal(defaultFormatForSession(currentUser, "MP3_320"), "MP3_320");
  assert.equal(fallbackFormatForSession(currentUser, "MP3_320"), null);
  assert.deepEqual(selectFormatsForSession(currentUser, "MP3_320"), ["MP3_320", "MP3_128"]);
});

test("normalizes unknown playback formats to the configured default", () => {
  assert.equal(normalizeFormat("FLAC", "MP3_128"), "MP3_128");
  assert.equal(normalizeFormat("MP3_128", "MP3_320"), "MP3_128");
});
