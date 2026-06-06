export const catalogDefaultLimit = 80;
export const catalogMaxLimit = 500;

export const normalizeCatalogLimit = (value) => {
  const parsed = Number.parseInt(String(value ?? catalogDefaultLimit), 10);
  const limit = Number.isFinite(parsed) && parsed !== 0 ? parsed : catalogDefaultLimit;
  return Math.min(Math.max(limit, 1), catalogMaxLimit);
};
