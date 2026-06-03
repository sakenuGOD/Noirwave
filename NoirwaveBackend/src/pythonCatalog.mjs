import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readARL } from "./session.mjs";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(backendRoot, "scripts", "catalog_cli.py");

const shouldRetryCatalogError = (error) =>
  /connection reset|cannot connect|timeout|timed out|econnreset|etimedout/i.test(error.message);

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
    child.on("close", (code) => {
      clearTimeout(timer);
      if (didTimeout) {
        const error = new Error(`Catalog request timed out after ${timeoutMs}ms.`);
        error.name = "CatalogTimeout";
        error.statusCode = 504;
        reject(error);
        return;
      }

      if (code !== 0) {
        reject(new Error(stderr.trim() || `catalog_cli exited with code ${code}`));
        return;
      }

      try {
        resolve(JSON.parse(stdout));
      } catch (error) {
        reject(new Error(`catalog_cli returned invalid JSON: ${error.message}`));
      }
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
      await new Promise((resolve) => setTimeout(resolve, 600));
    }
  }

  throw lastError;
};
