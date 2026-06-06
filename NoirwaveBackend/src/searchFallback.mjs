export const searchPayloadCount = (payload) =>
  Array.isArray(payload?.data) ? payload.data.length : 0;

export const isWeakSearchPayload = (payload) =>
  searchPayloadCount(payload) === 0;

export const shouldPreferFallbackSearchPayload = (catalogPayload, fallbackPayload) =>
  isWeakSearchPayload(catalogPayload) && searchPayloadCount(fallbackPayload) > 0;
