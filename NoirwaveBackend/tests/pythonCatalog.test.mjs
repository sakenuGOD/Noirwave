import test from "node:test";
import assert from "node:assert/strict";
import {
  publicCatalogError,
  shouldRetryCatalogError,
} from "../src/pythonCatalog.mjs";

test("retries empty catalog process exits because they are usually transient", () => {
  const error = new Error("catalog_cli exited with code 1");
  error.name = "CatalogProcessError";

  assert.equal(shouldRetryCatalogError(error), true);
});

test("maps catalog process failures to user-safe API errors", () => {
  const error = new Error("catalog_cli exited with code 1");
  error.name = "CatalogProcessError";
  error.statusCode = 503;

  const mapped = publicCatalogError(error);

  assert.equal(mapped.name, "CatalogUnavailable");
  assert.equal(mapped.statusCode, 503);
  assert.equal(mapped.message, "Music catalog is temporarily unavailable.");
});
