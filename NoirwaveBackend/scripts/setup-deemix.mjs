import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const vendorRoot = path.join(backendRoot, "vendor");
const deemixRoot = path.join(vendorRoot, "deemix");

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    ...options,
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
};

fs.mkdirSync(vendorRoot, { recursive: true });

if (!fs.existsSync(deemixRoot)) {
  run("git", ["clone", "--depth", "1", "https://github.com/bambanah/deemix", deemixRoot]);
}

run("corepack", ["pnpm", "install"], { cwd: deemixRoot });
run("corepack", ["pnpm", "--filter", "deezer-sdk", "build"], { cwd: deemixRoot });
run("corepack", ["pnpm", "--filter", "deemix", "build"], { cwd: deemixRoot });
