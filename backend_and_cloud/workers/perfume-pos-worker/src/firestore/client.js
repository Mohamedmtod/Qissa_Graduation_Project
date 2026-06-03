import {
  FIRESTORE_API_BASE,
  FIRESTORE_SCOPE,
  GOOGLE_TOKEN_URL,
} from "../constants/index.js";
import { createApiError } from "../http/errors.js";

/**
 * @typedef {{
 *   FIREBASE_PROJECT_ID?: string,
 *   SERVICE_ACCOUNT_JSON?: string,
 *   [key: string]: string | undefined
 * }} WorkerEnv
 */

/**
 * @typedef {{
 *   client_email: string,
 *   private_key: string,
 *   [key: string]: unknown
 * }} ServiceAccount
 */

/** @type {ServiceAccount | null} */
let cachedServiceAccount = null;
/** @type {string | null} */
let cachedAccessToken = null;
let cachedAccessTokenExp = 0;

/**
 * @param {string | Uint8Array | ArrayBuffer} input
 */
function base64UrlEncode(input) {
  const bytes =
    input instanceof Uint8Array
      ? input
      : input instanceof ArrayBuffer
        ? new Uint8Array(input)
        : new TextEncoder().encode(String(input));

  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

/**
 * @param {string} pem
 */
function pemToArrayBuffer(pem) {
  const clean = String(pem)
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * @param {WorkerEnv} env
 * @returns {ServiceAccount}
 */
function getServiceAccount(env) {
  if (cachedServiceAccount) return cachedServiceAccount;

  if (!env.SERVICE_ACCOUNT_JSON) {
    throw createApiError(500, "Missing SERVICE_ACCOUNT_JSON secret");
  }

  let parsed;
  try {
    parsed = JSON.parse(env.SERVICE_ACCOUNT_JSON);
  } catch {
    throw createApiError(500, "SERVICE_ACCOUNT_JSON is not valid JSON");
  }

  if (!parsed.client_email || !parsed.private_key) {
    throw createApiError(
      500,
      "SERVICE_ACCOUNT_JSON must contain client_email and private_key",
    );
  }

  cachedServiceAccount = parsed;
  return parsed;
}

/**
 * @param {WorkerEnv} env
 */
export async function createGoogleAssertionJwt(env) {
  const sa = getServiceAccount(env);
  const now = Math.floor(Date.now() / 1000);

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: sa.client_email,
    scope: FIRESTORE_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };

  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(payload),
  )}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  return `${unsigned}.${base64UrlEncode(signature)}`;
}

/**
 * @param {WorkerEnv} env
 */
export async function getGoogleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessTokenExp - 60 > now) {
    return cachedAccessToken;
  }

  const assertion = await createGoogleAssertionJwt(env);
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const text = await response.text();
  if (!response.ok) {
    throw createApiError(500, "Failed to obtain Google access token", text);
  }

  const jsonBody = JSON.parse(text);
  cachedAccessToken = jsonBody.access_token;
  cachedAccessTokenExp = now + Number(jsonBody.expires_in || 3600);
  return cachedAccessToken;
}

/**
 * @param {string} projectId
 * @param {string} path
 */
function firestoreDocumentUrl(projectId, path) {
  return `${FIRESTORE_API_BASE}/projects/${projectId}/databases/(default)/${path}`;
}

/**
 * @typedef {Object} FirestoreRequestOptions
 * @property {string=} method
 * @property {unknown=} body
 * @property {boolean=} expectText
 */

/**
 * @param {WorkerEnv} env
 * @param {string} path
 * @param {FirestoreRequestOptions=} options
 */
export async function firestoreRequest(
  env,
  path,
  options = {},
) {
  const { method = "GET", body, expectText = false } = options;
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const token = await getGoogleAccessToken(env);
  const url = firestoreDocumentUrl(projectId, path);

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const raw = await response.text();

  if (!response.ok) {
    let parsed = null;
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = raw;
    }

    const err = /** @type {Error & { googleStatus?: string | null }} */ (
      createApiError(
      response.status,
      parsed?.error?.message || `Firestore API error (${response.status})`,
      parsed,
      )
    );
    err.googleStatus = parsed?.error?.status || null;
    throw err;
  }

  if (expectText) return raw;
  if (!raw) return {};
  return JSON.parse(raw);
}
