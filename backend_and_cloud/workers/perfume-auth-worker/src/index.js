import { generateOtp, hmacSha256Hex, timingSafeEqual } from "./crypto.js";
import { lookupUserByEmail, updateUserPassword } from "./firebase-auth-rest.js";
import {
  corsPreflight,
  createApiError,
  json,
  publicErrorResponse,
  resolveCorsOrigin,
  safeJsonBody,
} from "./http.js";
import {
  isValidEmail,
  isValidOtpShape,
  normalizeEmail,
  normalizeOtp,
  validatePassword,
} from "./password-rules.js";
import {
  emailKey,
  enforceSendLimits,
  LOCK_SECONDS,
  OTP_TTL_SECONDS,
  requireKv,
  RESEND_COOLDOWN_SECONDS,
  VERIFY_ATTEMPT_LIMIT,
  enforceVerifyLimits,
} from "./rate-limit.js";
import { sendPasswordResetOtp } from "./resend.js";

const GENERIC_REQUEST_RESPONSE = {
  ok: true,
  message: "If this email exists, a reset code has been sent.",
};

export default {
  /**
   * @param {Request} request
   * @param {Record<string, any>} env
   */
  async fetch(request, env) {
    const origin = resolveCorsOrigin(request, env);
    const traceId = createTraceId();

    try {
      const url = new URL(request.url);
      const path = url.pathname;
      const method = request.method.toUpperCase();

      if (method === "OPTIONS") {
        return corsPreflight(origin);
      }

      if (method === "GET" && path === "/health") {
        return json(
          {
            ok: true,
            service: "perfume-auth-worker",
            version: "0.1.0",
          },
          200,
          origin,
        );
      }

      if (method === "POST" && path === "/password-reset/request") {
        return await handlePasswordResetRequest(request, env, origin, traceId);
      }

      if (method === "POST" && path === "/password-reset/verify") {
        return await handlePasswordResetVerify(request, env, origin, traceId);
      }

      if (method === "POST" && path === "/password-reset/confirm") {
        return await handlePasswordResetConfirm(request, env, origin, traceId);
      }

      return json({ error: "Not found." }, 404, origin);
    } catch (error) {
      console.log("auth_worker_error", {
        traceId,
        status: error?.status || 500,
        message: error instanceof Error ? error.message : "unknown",
      });
      return publicErrorResponse(error, origin);
    }
  },
};

/**
 * @param {Request} request
 * @param {Record<string, any>} env
 * @param {string} origin
 * @param {string} traceId
 */
async function handlePasswordResetRequest(request, env, origin, traceId) {
  logResetEvent("request_started", { traceId });

  const body = await safeJsonBody(request);
  const email = normalizeEmail(body.email);

  if (!isValidEmail(email)) {
    logResetEvent("request_invalid_email", { traceId });
    return json(GENERIC_REQUEST_RESPONSE, 200, origin);
  }

  const ip = request.headers.get("CF-Connecting-IP") || "";
  await enforceSendLimits(env, email, ip);
  logResetEvent("request_rate_limit_passed", { traceId });

  const kv = requireKv(env);
  const key = await passwordResetRecordKey(env, email);
  const emailRef = keyFingerprint(key);
  const now = Date.now();
  const existing = await getResetRecord(kv, key);

  if (existing?.resendAvailableAt && existing.resendAvailableAt > now) {
    logResetEvent("request_resend_cooldown", { traceId, emailRef });
    throw createApiError(429, "Reset email cooldown active");
  }

  const user = await lookupUserByEmail(env, email);
  if (!user) {
    logResetEvent("request_user_not_found", { traceId, emailRef });
    return json(GENERIC_REQUEST_RESPONSE, 200, origin);
  }
  logResetEvent("request_user_found", { traceId, emailRef });

  const otpSecret = requireSecret(env.OTP_HASH_SECRET, "OTP_HASH_SECRET");
  const otp = generateOtp();
  const otpHash = await hmacSha256Hex(otpSecret, otp);

  await kv.put(
    key,
    JSON.stringify({
      uid: user.uid,
      otpHash,
      attempts: 0,
      expiresAt: now + OTP_TTL_SECONDS * 1000,
      resendAvailableAt: now + RESEND_COOLDOWN_SECONDS * 1000,
      lockedUntil: 0,
    }),
    { expirationTtl: OTP_TTL_SECONDS },
  );
  logResetEvent("request_record_stored", { traceId, emailRef, ttlSeconds: OTP_TTL_SECONDS });

  try {
    await sendPasswordResetOtp(env, user.email || email, otp, { traceId, emailRef });
    logResetEvent("request_email_sent", { traceId, emailRef });
  } catch (error) {
    await kv.delete(key);
    logResetEvent("request_record_deleted_after_send_failure", { traceId, emailRef });
    throw error;
  }

  logResetEvent("request_completed", { traceId, emailRef });
  return json(GENERIC_REQUEST_RESPONSE, 200, origin);
}

/**
 * @param {Request} request
 * @param {Record<string, any>} env
 * @param {string} origin
 * @param {string} traceId
 */
async function handlePasswordResetVerify(request, env, origin, traceId) {
  logResetEvent("verify_started", { traceId });

  const body = await safeJsonBody(request);
  const email = normalizeEmail(body.email);
  const otp = normalizeOtp(body.otp);

  if (!isValidEmail(email) || !isValidOtpShape(otp)) {
    logResetEvent("verify_invalid_input", { traceId });
    return json({ error: "Invalid or expired code." }, 400, origin);
  }

  const ip = request.headers.get("CF-Connecting-IP") || "";
  await verifyResetOtp(env, email, otp, traceId, "verify", ip);
  logResetEvent("verify_completed", { traceId });
  return json({ ok: true, message: "Reset code verified." }, 200, origin);
}

/**
 * @param {Request} request
 * @param {Record<string, any>} env
 * @param {string} origin
 * @param {string} traceId
 */
async function handlePasswordResetConfirm(request, env, origin, traceId) {
  logResetEvent("confirm_started", { traceId });

  const body = await safeJsonBody(request);
  const email = normalizeEmail(body.email);
  const otp = normalizeOtp(body.otp);
  const newPassword = body.newPassword;

  if (!isValidEmail(email) || !isValidOtpShape(otp)) {
    logResetEvent("confirm_invalid_input", { traceId });
    return json({ error: "Invalid or expired code." }, 400, origin);
  }

  const passwordError = validatePassword(newPassword);
  if (passwordError) {
    logResetEvent("confirm_password_rules_failed", { traceId });
    return json({ error: passwordError }, 400, origin);
  }

  const { kv, key, record, emailRef } = await verifyResetOtp(
    env,
    email,
    otp,
    traceId,
    "confirm",
    request.headers.get("CF-Connecting-IP") || "",
  );

  logResetEvent("confirm_otp_verified", { traceId, emailRef });
  await updateUserPassword(env, record.uid, newPassword);
  await kv.delete(key);
  logResetEvent("confirm_completed", { traceId, emailRef });

  return json({ ok: true, message: "Password changed successfully." }, 200, origin);
}

/**
 * @param {Record<string, any>} env
 * @param {string} email
 * @param {string} otp
 * @param {string} traceId
 * @param {"verify" | "confirm"} phase
 */
async function verifyResetOtp(env, email, otp, traceId, phase, ip = "") {
  await enforceVerifyLimits(env, email, ip, phase);

  const kv = requireKv(env);
  const key = await passwordResetRecordKey(env, email);
  const emailRef = keyFingerprint(key);
  const record = await getResetRecord(kv, key);
  const now = Date.now();

  if (!record || record.expiresAt <= now) {
    await kv.delete(key);
    logResetEvent(`${phase}_missing_or_expired_record`, { traceId, emailRef });
    throw createApiError(400, "Invalid or expired code.");
  }

  if (record.lockedUntil && record.lockedUntil > now) {
    logResetEvent(`${phase}_record_locked`, { traceId, emailRef });
    throw createApiError(429, "Reset code locked");
  }

  const otpSecret = requireSecret(env.OTP_HASH_SECRET, "OTP_HASH_SECRET");
  const submittedHash = await hmacSha256Hex(otpSecret, otp);
  if (!timingSafeEqual(submittedHash, record.otpHash)) {
    const attempts = Number(record.attempts || 0) + 1;
    const nextRecord = {
      ...record,
      attempts,
      lockedUntil: attempts >= VERIFY_ATTEMPT_LIMIT ? now + LOCK_SECONDS * 1000 : 0,
    };
    await kv.put(key, JSON.stringify(nextRecord), {
      expirationTtl:
        attempts >= VERIFY_ATTEMPT_LIMIT
          ? LOCK_SECONDS
          : Math.max(1, Math.ceil((record.expiresAt - now) / 1000)),
    });

    if (attempts >= VERIFY_ATTEMPT_LIMIT) {
      logResetEvent(`${phase}_otp_failed_locked`, { traceId, emailRef, attempts });
      throw createApiError(429, "Reset code locked");
    }

    logResetEvent(`${phase}_otp_failed`, { traceId, emailRef, attempts });
    throw createApiError(400, "Invalid or expired code.");
  }

  logResetEvent(`${phase}_otp_verified`, { traceId, emailRef });
  return { kv, key, record, emailRef };
}

/**
 * @param {Record<string, any>} env
 * @param {string} email
 */
async function passwordResetRecordKey(env, email) {
  const hashedEmail = await emailKey(env, email);
  return `reset:${hashedEmail}`;
}

/**
 * @param {KVNamespace} kv
 * @param {string} key
 * @returns {Promise<{
 *   uid: string,
 *   otpHash: string,
 *   attempts: number,
 *   expiresAt: number,
 *   resendAvailableAt: number,
 *   lockedUntil: number,
 * } | null>}
 */
async function getResetRecord(kv, key) {
  const raw = await kv.get(key);
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed?.uid !== "string" || typeof parsed?.otpHash !== "string") {
      return null;
    }
    return {
      uid: parsed.uid,
      otpHash: parsed.otpHash,
      attempts: Number(parsed.attempts || 0),
      expiresAt: Number(parsed.expiresAt || 0),
      resendAvailableAt: Number(parsed.resendAvailableAt || 0),
      lockedUntil: Number(parsed.lockedUntil || 0),
    };
  } catch {
    return null;
  }
}

/**
 * @param {unknown} value
 * @param {string} name
 */
function requireSecret(value, name) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw createApiError(500, `Missing ${name}`);
  }
  return value;
}

function createTraceId() {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * @param {string} key
 */
function keyFingerprint(key) {
  return key.replace(/^reset:/, "").slice(0, 12);
}

/**
 * @param {string} event
 * @param {Record<string, unknown>} details
 */
function logResetEvent(event, details) {
  console.log("password_reset", {
    event,
    ...details,
  });
}
