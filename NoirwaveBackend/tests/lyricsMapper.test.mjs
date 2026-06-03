import test from "node:test";
import assert from "node:assert/strict";
import { normalizeLyricsPayload } from "../src/lyricsMapper.mjs";

test("normalizes synchronized lyrics and keeps stable ordering", () => {
  const payload = normalizeLyricsPayload({
    id: "13791932",
    text: "first line\nsecond line",
    lines: [
      { line: "second line", milliseconds: 12000, duration: 1800 },
      { text: "first line", milliseconds: 8000, duration: 2000 },
      { line: "   ", milliseconds: 9000, duration: 400 },
    ],
    copyright: "provider copyright",
    writers: "writer one",
  }, "fallback");

  assert.equal(payload.result, true);
  assert.equal(payload.id, "13791932");
  assert.equal(payload.available, true);
  assert.equal(payload.hasSynced, true);
  assert.deepEqual(payload.lines.map((line) => line.text), ["first line", "second line"]);
  assert.deepEqual(payload.lines.map((line) => line.milliseconds), [8000, 12000]);
  assert.equal(payload.copyright, "provider copyright");
  assert.equal(payload.writers, "writer one");
});

test("marks lyrics unavailable when no text or timed lines exist", () => {
  const payload = normalizeLyricsPayload({ id: "42", text: "", lines: [] }, "42");

  assert.equal(payload.result, true);
  assert.equal(payload.available, false);
  assert.equal(payload.hasSynced, false);
  assert.equal(payload.text, "");
  assert.deepEqual(payload.lines, []);
});
