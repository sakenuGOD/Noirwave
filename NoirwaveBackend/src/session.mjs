import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const loginFilePath = path.join(os.homedir(), "Library", "Application Support", "deemix", "login.json");

let runtimeARL = null;

export const readARL = () => {
  if (runtimeARL) return runtimeARL;

  const fromEnv = process.env.NOIRWAVE_DEEZER_ARL?.trim();
  if (fromEnv) return fromEnv;

  try {
    const login = JSON.parse(fs.readFileSync(loginFilePath, "utf8"));
    const arl = String(login.arl ?? "").trim();
    return arl || null;
  } catch {
    return null;
  }
};

export const setRuntimeARL = (value) => {
  const normalized = String(value ?? "").trim();
  runtimeARL = normalized || null;
  return runtimeARL;
};

export const maskSession = (value) => (value ? `${value.slice(0, 4)}...${value.slice(-4)}` : null);
