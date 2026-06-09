import test from "node:test";
import assert from "node:assert/strict";
import { applySearchResponsePrefetch } from "../src/searchResponsePrefetch.mjs";

test("track search schedules startup prefetch without awaiting response delivery", () => {
  const events = [];
  const payload = {
    source: "catalog",
    data: [{ id: 101 }, { id: 202 }],
  };

  const result = applySearchResponsePrefetch({
    scope: "track",
    payload,
    preferredFormat: "MP3_320",
    cacheTrackMediaFromPayload: () => events.push("cache"),
    extractTrackIds: () => ["101", "202"],
    scheduleBackgroundPrefetch: (trackIds, format, options) => {
      events.push({ trackIds, format, options });
      return new Promise(() => {});
    },
  });

  assert.deepEqual(events, [
    "cache",
    { trackIds: ["101", "202"], format: "MP3_320", options: { priority: true } },
  ]);
  assert.deepEqual(result, {
    mode: "background-priority",
    trackIds: ["101", "202"],
  });
});

test("public fallback search only caches media and does not prefetch startup", () => {
  const events = [];
  const result = applySearchResponsePrefetch({
    scope: "track",
    payload: { source: "deezer-public-search", data: [{ id: 101 }] },
    preferredFormat: "MP3_320",
    cacheTrackMediaFromPayload: () => events.push("cache"),
    extractTrackIds: () => ["101"],
    scheduleBackgroundPrefetch: () => events.push("prefetch"),
  });

  assert.deepEqual(events, ["cache"]);
  assert.deepEqual(result, { mode: "cache-only", trackIds: [] });
});
