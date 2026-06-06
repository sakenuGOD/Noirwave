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
