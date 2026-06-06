import test from "node:test";
import assert from "node:assert/strict";
import { normalizeCatalogLimit } from "../src/requestLimits.mjs";

test("allows expanded catalog result windows without the old 50 item cap", () => {
  assert.equal(normalizeCatalogLimit("180"), 180);
});

test("still protects catalog requests from empty or excessive limits", () => {
  assert.equal(normalizeCatalogLimit(""), 80);
  assert.equal(normalizeCatalogLimit("-4"), 1);
  assert.equal(normalizeCatalogLimit("9000"), 500);
});
