import { base64UrlEncode, pemToArrayBuffer } from "./crypto.js";
import { createApiError } from "./http.js";

const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const IDENTITY_TOOLKIT_SCOPE = "https://www.googleapis.com/auth/identitytoolkit";
const IDENTITY_TOOLKIT_BASE = "https://identitytoolkit.googleapis.com/v1";
const EXTERNAL_FETCH_TIMEOUT_MS = 8000;

let cachedAccessToken = null;
let cachedAccessTokenExp = 0;

/**
 * @param {{
 *   FIREBASE_CLIENT_EMAIL?: string,
 *   FIREBASE_PRIVATE_KEY?: string,
 *   FIREBASE_PROJECT_ID?: string,
 * }} env
 */
async function getGoogleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessTokenExp - 60 > now) {
    return cachedAccessToken;
  }

  const assertion = await createGoogleAssertionJwt(env);
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const response = await fetchWithTimeout(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  }, EXTERNAL_FETCH_TIMEOUT_MS);

  const text = await response.text();
  if (!response.ok) {
    console.log("firebase_token_failed", {
      status: response.status,
      body: safeLogText(text),
    });
    throw createApiError(500, "Failed to obtain Google access token");
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw createApiError(500, "Invalid Google token response");
  }

  cachedAccessToken = String(parsed.access_token || "");
  cachedAccessTokenExp = now + Number(parsed.expires_in || 3600);

  if (!cachedAccessToken) {
    throw createApiError(500, "Google access token missing");
  }

  return cachedAccessToken;
}

/**
 * @param {{ FIREBASE_CLIENT_EMAIL?: string, FIREBASE_PRIVATE_KEY?: string }} env
 */
async function createGoogleAssertionJwt(env) {
  const clientEmail = requireSecret(env.FIREBASE_CLIENT_EMAIL, "FIREBASE_CLIENT_EMAIL");
  const privateKey = requireSecret(env.FIREBASE_PRIVATE_KEY, "FIREBASE_PRIVATE_KEY");
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: IDENTITY_TOOLKIT_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };

  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(payload),
  )}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
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
 * @param {{
 *   FIREBASE_CLIENT_EMAIL?: string,
 *   FIREBASE_PRIVATE_KEY?: string,
 *   FIREBASE_PROJECT_ID?: string,
 * }} env
 * @param {string} email
 * @returns {Promise<{ uid: string, email: string } | null>}
 */
export async function lookupUserByEmail(env, email) {
  const projectId = requireSecret(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
  const token = await getGoogleAccessToken(env);
  const url = `${IDENTITY_TOOLKIT_BASE}/projects/${encodeURIComponent(
    projectId,
  )}/accounts:lookup`;

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email: [email] }),
  }, EXTERNAL_FETCH_TIMEOUT_MS);

  const text = await response.text();
  if (!response.ok) {
    console.log("firebase_lookup_failed", {
      status: response.status,
      body: safeLogText(text),
    });
    throw createApiError(500, "Firebase user lookup failed");
  }

  const parsed = text ? JSON.parse(text) : {};
  const user = Array.isArray(parsed.users) ? parsed.users[0] : null;
  if (!user?.localId) return null;

  return {
    uid: String(user.localId),
    email: String(user.email || email),
  };
}

/**
 * @param {{
 *   FIREBASE_CLIENT_EMAIL?: string,
 *   FIREBASE_PRIVATE_KEY?: string,
 *   FIREBASE_PROJECT_ID?: string,
 * }} env
 * @param {string} uid
 * @param {string} newPassword
 */
export async function updateUserPassword(env, uid, newPassword) {
  const projectId = requireSecret(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
  const token = await getGoogleAccessToken(env);
  const url = `${IDENTITY_TOOLKIT_BASE}/projects/${encodeURIComponent(
    projectId,
  )}/accounts:update`;

  const response = await fetchWithTimeout(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      localId: uid,
      password: newPassword,
      validSince: String(Math.floor(Date.now() / 1000)),
    }),
  }, EXTERNAL_FETCH_TIMEOUT_MS);

  if (!response.ok) {
    const text = await response.text();
    console.log("firebase_update_failed", {
      status: response.status,
      body: safeLogText(text),
    });
    throw createApiError(500, "Firebase password update failed");
  }
}

/**
 * @param {string | undefined} value
 * @param {string} name
 */
function requireSecret(value, name) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw createApiError(500, `Missing ${name}`);
  }
  return value.trim();
}

/**
 * @param {string} value
 */
function safeLogText(value) {
  return value
    .replace(/ya29\.[A-Za-z0-9._-]+/g, "ya29.[redacted]")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[email-redacted]")
    .slice(0, 600);
}

async function fetchWithTimeout(url, init, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort("timeout"), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (error) {
    if (error?.name === "AbortError" || error === "timeout") {
      throw createApiError(504, "External provider timeout");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
