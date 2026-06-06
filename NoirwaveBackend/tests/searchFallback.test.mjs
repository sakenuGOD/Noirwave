import test from "node:test";
import assert from "node:assert/strict";
import {
  isWeakSearchPayload,
  shouldPreferFallbackSearchPayload,
} from "../src/searchFallback.mjs";

test("treats empty catalog search payloads as weak", () => {
  assert.equal(isWeakSearchPayload({ data: [], total: 0, type: "track" }), true);
  assert.equal(isWeakSearchPayload({ data: [{ id: 13791932 }], total: 1, type: "track" }), false);
});

test("treats short catalog search payloads as weak when more results were requested", () => {
  assert.equal(
    isWeakSearchPayload({ data: Array.from({ length: 8 }, (_, id) => ({ id })), total: 80, type: "track" }, 80),
    true
  );
  assert.equal(
    isWeakSearchPayload({ data: Array.from({ length: 80 }, (_, id) => ({ id })), total: 80, type: "track" }, 80),
    false
  );
});

test("prefers non-empty public fallback over empty catalog search payload", () => {
  const catalog = { data: [], total: 0, type: "track", source: "catalog" };
  const fallback = {
    data: [{ id: 13791932, title: "Come As You Are" }],
    total: 1,
    type: "track",
    source: "deezer-public-search",
  };

  assert.equal(shouldPreferFallbackSearchPayload(catalog, fallback), true);
});

test("prefers larger public fallback over short catalog search payloads", () => {
  const catalog = {
    data: Array.from({ length: 8 }, (_, id) => ({ id })),
    total: 80,
    type: "track",
    source: "catalog",
  };
  const fallback = {
    data: Array.from({ length: 60 }, (_, id) => ({ id: id + 100 })),
    total: 80,
    type: "track",
    source: "deezer-public-search",
  };

  assert.equal(shouldPreferFallbackSearchPayload(catalog, fallback, 80), true);
});
