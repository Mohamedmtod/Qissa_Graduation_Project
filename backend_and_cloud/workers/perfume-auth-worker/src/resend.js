import { createApiError } from "./http.js";

const RESEND_EMAILS_URL = "https://api.resend.com/emails";
const RESEND_FETCH_TIMEOUT_MS = 8000;

/**
 * @param {{ RESEND_API_KEY?: string, RESEND_FROM?: string }} env
 * @param {string} email
 * @param {string} otp
 * @param {{ traceId?: string, emailRef?: string }} [logContext]
 */
export async function sendPasswordResetOtp(env, email, otp, logContext = {}) {
  const apiKey = requireSecret(env.RESEND_API_KEY, "RESEND_API_KEY");
  const from = env.RESEND_FROM || "Qissa <otp@qessa-suez.site>";

  console.log("resend_send_started", {
    traceId: logContext.traceId,
    emailRef: logContext.emailRef,
  });

  const response = await fetchWithTimeout(RESEND_EMAILS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: "Qissa password reset code",
      html: buildOtpEmailHtml(otp),
      text: `Your Qissa password reset code is ${otp}. It expires in 3 minutes.`,
    }),
  }, RESEND_FETCH_TIMEOUT_MS);

  if (!response.ok) {
    const errorText = await response.text();
    console.log("resend_send_failed", {
      traceId: logContext.traceId,
      emailRef: logContext.emailRef,
      status: response.status,
      body: safeLogText(errorText),
    });
    throw createApiError(500, "Failed to send reset email");
  }

  console.log("resend_send_succeeded", {
    traceId: logContext.traceId,
    emailRef: logContext.emailRef,
    status: response.status,
  });
}

/**
 * @param {string} otp
 */
function buildOtpEmailHtml(otp) {
  return `
    <div style="direction: rtl; font-family: Arial, sans-serif; text-align: center; color: #1A1A1A;">
      <h2>قصة</h2>
      <p>رمز إعادة تعيين كلمة المرور هو:</p>
      <div style="font-size: 32px; font-weight: 700; letter-spacing: 6px; margin: 18px 0;">
        ${escapeHtml(otp)}
      </div>
      <p>هذا الرمز صالح لمدة 3 دقائق فقط.</p>
      <p style="font-size: 12px; color: #666;">إذا لم تطلب تغيير كلمة المرور، تجاهل هذه الرسالة.</p>
    </div>
  `;
}

/**
 * @param {string} value
 */
function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * @param {string} value
 */
function safeLogText(value) {
  return value
    .replace(/re_[A-Za-z0-9_-]+/g, "re_[redacted]")
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[email-redacted]")
    .slice(0, 600);
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
