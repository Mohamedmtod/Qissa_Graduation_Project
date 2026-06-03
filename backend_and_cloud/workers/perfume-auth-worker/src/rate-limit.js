import { hmacSha256Hex } from "./crypto.js";
import { createApiError } from "./http.js";

export const OTP_TTL_SECONDS = 180;
export const RESEND_COOLDOWN_SECONDS = 60;
export const EMAIL_SEND_LIMIT_PER_HOUR = 5;
export const IP_SEND_LIMIT_PER_HOUR = 10;
export const VERIFY_ATTEMPT_LIMIT = 5;
export const VERIFY_EMAIL_LIMIT_PER_WINDOW = 10;
export const VERIFY_IP_LIMIT_PER_WINDOW = 30;
export const VERIFY_LIMIT_WINDOW_SECONDS = 900;
export const LOCK_SECONDS = 900;

/**
 * @param {{ EMAIL_KEY_SECRET?: string }} env
 * @param {string} email
 */
export async function emailKey(env, email) {
  requireSecret(env.EMAIL_KEY_SECRET, "EMAIL_KEY_SECRET");
  return hmacSha256Hex(env.EMAIL_KEY_SECRET, email);
}

/**
 * @param {{ EMAIL_KEY_SECRET?: string }} env
 * @param {string} ip
 */
export async function ipKey(env, ip) {
  requireSecret(env.EMAIL_KEY_SECRET, "EMAIL_KEY_SECRET");
  return hmacSha256Hex(env.EMAIL_KEY_SECRET, ip || "unknown");
}

/**
 * @param {{ PASSWORD_RESET_KV?: KVNamespace, EMAIL_KEY_SECRET?: string }} env
 * @param {string} email
 * @param {string} ip
 */
export async function enforceSendLimits(env, email, ip) {
  const kv = requireKv(env);
  const emailHash = await emailKey(env, email);
  const ipHash = await ipKey(env, ip);

  const emailCount = await incrementCounter(kv, `rl:email:${emailHash}`, 3600);
  if (emailCount > EMAIL_SEND_LIMIT_PER_HOUR) {
    throw createApiError(429, "Email send limit exceeded");
  }

  const ipCount = await incrementCounter(kv, `rl:ip:${ipHash}`, 3600);
  if (ipCount > IP_SEND_LIMIT_PER_HOUR) {
    throw createApiError(429, "IP send limit exceeded");
  }
}

/**
 * @param {{ PASSWORD_RESET_KV?: KVNamespace, EMAIL_KEY_SECRET?: string }} env
 * @param {string} email
 * @param {string} ip
 * @param {"verify" | "confirm"} phase
 */
export async function enforceVerifyLimits(env, email, ip, phase) {
  const kv = requireKv(env);
  const emailHash = await emailKey(env, email);
  const ipHash = await ipKey(env, ip);

  const emailCount = await incrementCounter(
    kv,
    `rl:${phase}:email:${emailHash}`,
    VERIFY_LIMIT_WINDOW_SECONDS,
  );
  if (emailCount > VERIFY_EMAIL_LIMIT_PER_WINDOW) {
    throw createApiError(429, "Verify limit exceeded");
  }

  const ipCount = await incrementCounter(
    kv,
    `rl:${phase}:ip:${ipHash}`,
    VERIFY_LIMIT_WINDOW_SECONDS,
  );
  if (ipCount > VERIFY_IP_LIMIT_PER_WINDOW) {
    throw createApiError(429, "Verify IP limit exceeded");
  }
}

/**
 * @param {KVNamespace} kv
 * @param {string} key
 * @param {number} ttlSeconds
 */
async function incrementCounter(kv, key, ttlSeconds) {
  const rawCurrent = await kv.get(key);
  const now = Date.now();
  const current = parseCounter(rawCurrent, now);
  const next = current.count + 1;
  const expiresAt = current.expiresAt || now + ttlSeconds * 1000;
  const remainingTtl = Math.max(1, Math.ceil((expiresAt - now) / 1000));

  await kv.put(
    key,
    JSON.stringify({
      count: next,
      expiresAt,
    }),
    { expirationTtl: remainingTtl },
  );
  return next;
}

/**
 * @param {string | null} rawCurrent
 * @param {number} now
 * @returns {{ count: number, expiresAt: number }}
 */
function parseCounter(rawCurrent, now) {
  if (!rawCurrent) {
    return { count: 0, expiresAt: 0 };
  }

  try {
    const parsed = JSON.parse(rawCurrent);
    const count = Number(parsed?.count || 0);
    const expiresAt = Number(parsed?.expiresAt || 0);
    if (!Number.isFinite(count) || !Number.isFinite(expiresAt) || expiresAt <= now) {
      return { count: 0, expiresAt: 0 };
    }
    return { count, expiresAt };
  } catch {
    // Legacy counters were stored as plain numbers and could lose their KV TTL
    // on later writes. Start a fresh window so old stuck attempts self-heal.
    return { count: 0, expiresAt: 0 };
  }
}

/**
 * @param {{ PASSWORD_RESET_KV?: KVNamespace }} env
 */
export function requireKv(env) {
  if (!env.PASSWORD_RESET_KV) {
    throw createApiError(500, "Missing PASSWORD_RESET_KV binding");
  }
  return env.PASSWORD_RESET_KV;
}

/**
 * @param {string | undefined} value
 * @param {string} name
 */
function requireSecret(value, name) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw createApiError(500, `Missing ${name} secret`);
  }
}
