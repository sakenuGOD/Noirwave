const cleanText = (value) => String(value ?? "").trim();

const normalizedLineText = (line) => cleanText(line?.text ?? line?.line);

const normalizedMilliseconds = (line) => {
  const value = Number(line?.milliseconds);
  return Number.isFinite(value) && value >= 0 ? Math.round(value) : null;
};

const normalizedDuration = (line) => {
  const value = Number(line?.duration);
  return Number.isFinite(value) && value > 0 ? Math.round(value) : null;
};

export const normalizeLyricsPayload = (payload, fallbackTrackId) => {
  const lines = (Array.isArray(payload?.lines) ? payload.lines : [])
    .map((line) => ({
      milliseconds: normalizedMilliseconds(line),
      duration: normalizedDuration(line),
      text: normalizedLineText(line),
    }))
    .filter((line) => line.milliseconds !== null && line.text.length > 0)
    .sort((lhs, rhs) => lhs.milliseconds - rhs.milliseconds);

  const text = cleanText(payload?.text) || lines.map((line) => line.text).join("\n");

  return {
    result: true,
    id: String(payload?.id ?? fallbackTrackId),
    available: text.length > 0 || lines.length > 0,
    hasSynced: lines.length > 0,
    text,
    lines,
    copyright: cleanText(payload?.copyright) || null,
    writers: cleanText(payload?.writers) || null,
  };
};
