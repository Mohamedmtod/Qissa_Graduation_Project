const DEFAULT_ALLOWED_ORIGIN = "http://localhost:8080";

/**
 * @param {unknown} data
 * @param {number} [status]
 * @param {string} [origin]
 */
export function json(data, status = 200, origin = DEFAULT_ALLOWED_ORIGIN) {
  return Response.json(data, {
    status,
    headers: corsHeaders(origin),
  });
}

/**
 * @param {string} [origin]
 */
export function corsPreflight(origin = DEFAULT_ALLOWED_ORIGIN) {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(origin),
  });
}

/**
 * @param {string} origin
 */
function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-Trace-Id",
    "Access-Control-Max-Age": "86400",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    Vary: "Origin",
  };
}

/**
 * @param {Request} request
 * @returns {Promise<Record<string, unknown>>}
 */
export async function safeJsonBody(request) {
  try {
    const parsed = await request.json();
    return typeof parsed === "object" && parsed !== null
      ? /** @type {Record<string, unknown>} */ (parsed)
      : {};
  } catch {
    return {};
  }
}

/**
 * @param {Request} request
 * @param {{ ALLOWED_ORIGINS?: string }} env
 */
export function resolveCorsOrigin(request, env) {
  const requestOrigin = request.headers.get("Origin")?.trim() || "";
  const allowedOrigins = parseAllowedOrigins(env.ALLOWED_ORIGINS);

  if (allowedOrigins.includes("*")) {
    return requestOrigin || "*";
  }

  if (requestOrigin && allowedOrigins.includes(requestOrigin)) {
    return requestOrigin;
  }

  if (!allowedOrigins.length && requestOrigin && isTrustedDevOrigin(requestOrigin)) {
    return requestOrigin;
  }

  if (allowedOrigins.length) {
    return allowedOrigins[0];
  }

  return DEFAULT_ALLOWED_ORIGIN;
}

/**
 * @param {unknown} error
 */
export function publicErrorResponse(error, origin) {
  const status =
    typeof error === "object" &&
    error !== null &&
    Number.isInteger(/** @type {{ status?: unknown }} */ (error).status)
      ? Number(/** @type {{ status: number }} */ (error).status)
      : 500;

  if (status === 429) {
    return json({ error: "Too many attempts. Try again later." }, 429, origin);
  }

  if (
    status === 400 &&
    error instanceof Error &&
    error.message === "Invalid or expired code."
  ) {
    return json({ error: "Invalid or expired code." }, 400, origin);
  }

  if (status >= 400 && status < 500) {
    return json({ error: "Invalid request." }, status, origin);
  }

  return json({ error: "An unexpected error occurred. Please try again." }, 500, origin);
}

/**
 * @param {number} status
 * @param {string} message
 */
export function createApiError(status, message) {
  const error = /** @type {Error & { status?: number }} */ (new Error(message));
  error.status = status;
  return error;
}

/**
 * @param {string | undefined} rawValue
 */
function parseAllowedOrigins(rawValue) {
  if (typeof rawValue !== "string" || rawValue.trim().length === 0) return [];
  return rawValue
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry, index, self) => entry.length > 0 && self.indexOf(entry) === index);
}

/**
 * @param {string} origin
 */
function isTrustedDevOrigin(origin) {
  try {
    const url = new URL(origin);
    const host = url.hostname.toLowerCase();
    return host === "localhost" || host === "127.0.0.1" || host === "::1";
  } catch {
    return false;
  }
}
