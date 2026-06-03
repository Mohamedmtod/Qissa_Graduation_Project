/**
 * @param {unknown} raw
 */
export function parseAdminAllowlist(raw) {
  return new Set(
    String(raw || "")
      .split(",")
      .map((uid) => uid.trim())
      .filter((uid) => uid.length > 0),
  );
}

/**
 * @param {Record<string, unknown>} claims
 */
export function isAdminByClaims(claims) {
  return claims.admin === true || claims.role === "admin" || claims.role === "owner";
}

/**
 * @param {Record<string, unknown>} claims
 */
export function isCashierByClaims(claims) {
  return claims.admin === true || claims.role === "admin" || claims.role === "owner" || claims.role === "cashier";
}

/**
 * @param {Request} request
 */
export function getBearerToken(request) {
  const auth = request.headers.get("authorization");
  if (!auth) return null;

  const [scheme, token] = auth.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;

  return token;
}
