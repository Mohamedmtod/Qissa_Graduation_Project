import { DEFAULT_ALLOWED_ORIGIN } from "../constants/index.js";

export const MAX_JSON_BODY_BYTES = 32 * 1024;

/**
 * @typedef {{ ALLOWED_ORIGIN?: string }} WorkerEnv
 */

/**
 * @param {unknown} data
 * @param {number} [status=200]
 * @param {string} [origin=DEFAULT_ALLOWED_ORIGIN]
 */
export function json(data, status = 200, origin = DEFAULT_ALLOWED_ORIGIN) {
  return Response.json(data, {
    status,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Trace-Id, X-Worker-Api-Key",
      "Access-Control-Max-Age": "86400",
      Vary: "Origin",
    },
  });
}

/**
 * @param {string} [origin=DEFAULT_ALLOWED_ORIGIN]
 */
export function corsPreflight(origin = DEFAULT_ALLOWED_ORIGIN) {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Trace-Id, X-Worker-Api-Key",
      "Access-Control-Max-Age": "86400",
      Vary: "Origin",
    },
  });
}

/**
 * @param {Request} request
 * @returns {Promise<Record<string, unknown>>}
 */
export async function safeJsonBody(request) {
  const contentLength = request.headers.get("Content-Length");
  if (contentLength && Number(contentLength) > MAX_JSON_BODY_BYTES) {
    throw createResponseError(413, "Request body too large");
  }

  let rawBody;
  try {
    rawBody = await request.text();
  } catch {
    throw createResponseError(400, "Invalid JSON body");
  }

  if (new TextEncoder().encode(rawBody).byteLength > MAX_JSON_BODY_BYTES) {
    throw createResponseError(413, "Request body too large");
  }

  let parsed;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    throw createResponseError(400, "Invalid JSON body");
  }

  if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
    return /** @type {Record<string, unknown>} */ (parsed);
  }
  throw createResponseError(400, "Invalid JSON body");
}

/**
 * @param {number} status
 * @param {string} message
 */
function createResponseError(status, message) {
  const error = /** @type {Error & { status?: number }} */ (new Error(message));
  error.status = status;
  return error;
}

/**
 * @param {Request} request
 * @param {WorkerEnv} env
 */
export function resolveCorsOrigin(request, env) {
  const requestOrigin = request.headers.get("Origin")?.trim() || "";
  const configuredOrigins = parseAllowedOrigins(env.ALLOWED_ORIGIN);

  if (configuredOrigins.includes("*")) {
    return requestOrigin || DEFAULT_ALLOWED_ORIGIN;
  }

  if (requestOrigin && isTrustedDevOrigin(requestOrigin)) {
    return requestOrigin;
  }

  if (requestOrigin && configuredOrigins.includes(requestOrigin)) {
    return requestOrigin;
  }

  if (configuredOrigins.length) {
    return configuredOrigins[0];
  }

  return DEFAULT_ALLOWED_ORIGIN;
}

/**
 * @param {string | undefined} rawValue
 * @returns {string[]}
 */
function parseAllowedOrigins(rawValue) {
  if (typeof rawValue !== "string" || rawValue.trim().length === 0) {
    return [];
  }
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
    return (
      host === "localhost" ||
      host === "127.0.0.1" ||
      host === "::1" ||
      host.endsWith(".perfume-app.local")
    );
  } catch {
    return false;
  }
}
