export const searchPayloadCount = (payload) =>
  Array.isArray(payload?.data) ? payload.data.length : 0;

export const isWeakSearchPayload = (payload, requestedCount = 0) => {
  const count = searchPayloadCount(payload);
  if (count === 0) return true;

  const requested = Number(requestedCount);
  const total = Number(payload?.total);
  if (!Number.isFinite(requested) || requested <= 0) return false;
  if (count >= requested) return false;
  if (Number.isFinite(total) && total <= count) return false;

  return true;
};

export const shouldPreferFallbackSearchPayload = (catalogPayload, fallbackPayload, requestedCount = 0) =>
  isWeakSearchPayload(catalogPayload, requestedCount)
    && searchPayloadCount(fallbackPayload) > searchPayloadCount(catalogPayload);
