const fallbackRateLimitStore = globalThis.__ordersRateLimitStore ||
  (globalThis.__ordersRateLimitStore = new Map());

/**
 * @param {Record<string, unknown>} env
 * @param {string} key
 * @param {number} limit
 * @param {number} windowSeconds
 */
export async function enforceRateLimit(env, key, limit, windowSeconds) {
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  const hashedKey = await sha256Hex(key);
  const storageKey = `rl:${hashedKey}`;
  const kv = env.ORDERS_RATE_LIMIT_KV || env.RATE_LIMIT_KV;

  let count;
  if (kv) {
    const current = Number(await kv.get(storageKey) || "0");
    count = Number.isFinite(current) ? current + 1 : 1;
    if (current <= 0) {
      await kv.put(storageKey, String(count), { expirationTtl: windowSeconds });
    } else {
      await kv.put(storageKey, String(count));
    }
  } else {
    const bucket = fallbackRateLimitStore.get(storageKey);
    if (!bucket || bucket.expiresAt <= now) {
      count = 1;
      fallbackRateLimitStore.set(storageKey, { count, expiresAt: now + windowMs });
    } else {
      count = bucket.count + 1;
      bucket.count = count;
    }
  }

  if (count > limit) {
    const error = /** @type {Error & { status?: number }} */ (new Error("Too many requests"));
    error.status = 429;
    throw error;
  }
}

async function sha256Hex(value) {
  const input = new TextEncoder().encode(String(value || ""));
  const digest = await crypto.subtle.digest("SHA-256", input);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
