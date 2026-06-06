export const bitrateByFormat = new Map([
  ["MP3_320", 3],
  ["MP3_128", 1],
]);

const canStreamHQ = (currentUser) => currentUser?.can_stream_hq ?? currentUser?.canStreamHQ;

export const normalizeFormat = (value, fallbackFormat = "MP3_320") => {
  const fallback = bitrateByFormat.has(fallbackFormat) ? fallbackFormat : "MP3_320";
  const requestedFormat = String(value ?? fallback).trim();
  return bitrateByFormat.has(requestedFormat) ? requestedFormat : fallback;
};

export const defaultFormatForSession = (currentUser, preferredFormat = "MP3_320") => {
  const normalized = normalizeFormat(preferredFormat);
  if (normalized === "MP3_320" && canStreamHQ(currentUser) === false) return "MP3_128";
  return normalized;
};

export const fallbackFormatForSession = (currentUser, preferredFormat = "MP3_320") => {
  const normalized = normalizeFormat(preferredFormat);
  const selected = defaultFormatForSession(currentUser, normalized);
  return selected === normalized ? null : selected;
};

export const selectFormatsForSession = (currentUser, requestedFormat, preferredFormat = "MP3_320") => {
  const requested = normalizeFormat(requestedFormat, preferredFormat);
  if (requested === "MP3_128") return ["MP3_128"];
  if (requested === "MP3_320" && canStreamHQ(currentUser) === false) return ["MP3_128"];
  if (requested === "MP3_320") return ["MP3_320", "MP3_128"];
  return [requested];
};
