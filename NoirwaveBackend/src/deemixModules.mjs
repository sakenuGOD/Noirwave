import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const candidateRoots = [
  process.env.NOIRWAVE_DEEMIX_ROOT,
  path.join(backendRoot, "vendor", "deemix"),
  "/tmp/noirwave-deemix-inspect",
  "/tmp/noirwave-deemix",
].filter(Boolean);

const resolveDeemixRoot = () => {
  for (const root of candidateRoots) {
    const sdk = path.join(root, "packages", "deezer-sdk", "dist", "index.js");
    const deemix = path.join(root, "packages", "deemix", "dist", "index.js");
    if (existsSync(sdk) && existsSync(deemix)) return root;
  }

  throw new Error("Deemix dist not found. Run `npm run setup:deemix` in NoirwaveBackend or set NOIRWAVE_DEEMIX_ROOT.");
};

export const loadDeemixModules = async () => {
  const root = resolveDeemixRoot();
  const deezerSdk = await import(pathToFileURL(path.join(root, "packages", "deezer-sdk", "dist", "index.js")));
  const deemix = await import(pathToFileURL(path.join(root, "packages", "deemix", "dist", "index.js")));
  return { root, deezerSdk, deemix };
};
