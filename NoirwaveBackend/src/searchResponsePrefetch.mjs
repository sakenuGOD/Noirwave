export const applySearchResponsePrefetch = ({
  scope,
  payload,
  preferredFormat,
  cacheTrackMediaFromPayload,
  extractTrackIds,
  scheduleBackgroundPrefetch,
}) => {
  if (scope !== "track") {
    return { mode: "none", trackIds: [] };
  }

  cacheTrackMediaFromPayload(payload);

  if (payload?.source === "deezer-public-search") {
    return { mode: "cache-only", trackIds: [] };
  }

  const trackIds = extractTrackIds(payload);
  if (trackIds.length === 0) {
    return { mode: "cache-only", trackIds: [] };
  }

  scheduleBackgroundPrefetch(trackIds, preferredFormat, { priority: true });
  return { mode: "background-priority", trackIds };
};
