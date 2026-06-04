import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readARL } from "./session.mjs";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(backendRoot, "scripts", "catalog_cli.py");

export const shouldRetryCatalogError = (error) =>
  error?.name === "CatalogProcessError"
  || error?.name === "CatalogTimeout"
  || /connection reset|cannot connect|timeout|timed out|econnreset|etimedout|catalog_cli exited/i
    .test(error?.message ?? "");

export const publicCatalogError = (error) => {
  const mapped = new Error(
    error?.name === "CatalogTimeout"
      ? "Music catalog request timed out."
      : "Music catalog is temporarily unavailable."
  );
  mapped.name = error?.name === "CatalogTimeout" ? "CatalogTimeout" : "CatalogUnavailable";
  mapped.statusCode = error?.statusCode ?? 503;
  mapped.cause = error;
  return mapped;
};

const catalogProcessError = ({ code, stderr }) => {
  const detail = stderr.trim();
  const error = new Error(detail || `catalog_cli exited with code ${code}`);
  error.name = "CatalogProcessError";
  error.statusCode = 503;
  error.exitCode = code;
  return error;
};

const runCatalogOnce = (args, { timeoutMs = 22000 } = {}) =>
  new Promise((resolve, reject) => {
    const arl = readARL();
    if (!arl) {
      reject(new Error("NOIRWAVE_DEEZER_ARL is not configured and no saved ARL was found."));
      return;
    }

    const child = spawn("uv", ["run", "--project", backendRoot, "python", scriptPath, ...args], {
      cwd: backendRoot,
      env: {
        ...process.env,
        NOIRWAVE_DEEZER_ARL: arl,
      },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let didTimeout = false;
    let didSettle = false;
    const settle = (callback) => {
      if (didSettle) return;
      didSettle = true;
      clearTimeout(timer);
      callback();
    };
    const timer = setTimeout(() => {
      didTimeout = true;
      child.kill("SIGTERM");
    }, timeoutMs);

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.once("error", (error) => {
      settle(() => reject(catalogProcessError({ code: "spawn", stderr: error.message })));
    });
    child.on("close", (code) => {
      settle(() => {
        if (didTimeout) {
          const error = new Error(`Catalog request timed out after ${timeoutMs}ms.`);
          error.name = "CatalogTimeout";
          error.statusCode = 504;
          reject(error);
          return;
        }

        if (code !== 0) {
          reject(catalogProcessError({ code, stderr }));
          return;
        }

        try {
          resolve(JSON.parse(stdout));
        } catch (error) {
          reject(catalogProcessError({
            code: "json",
            stderr: `catalog_cli returned invalid JSON: ${error.message}`,
          }));
        }
      });
    });
  });

export const callCatalog = async (args, { timeoutMs = 22000, attempts = 3 } = {}) => {
  let lastError;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await runCatalogOnce(args, { timeoutMs });
    } catch (error) {
      lastError = error;
      if (attempt >= attempts - 1 || !shouldRetryCatalogError(error)) break;
      await new Promise((resolve) => setTimeout(resolve, 600 * (attempt + 1)));
    }
  }

  throw publicCatalogError(lastError);
};
