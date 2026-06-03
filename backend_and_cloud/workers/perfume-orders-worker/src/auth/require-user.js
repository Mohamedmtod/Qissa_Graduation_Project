import { DEFAULT_ALLOWED_ORIGIN } from "../constants/index.js";
import { json } from "../http/responses.js";
import { getBearerToken, isAdminByClaims, parseAdminAllowlist } from "./admin.js";
import { verifyFirebaseIdToken } from "./firebase-jwt.js";

/**
 * @typedef {{
 *   ALLOWED_ORIGIN?: string,
 *   ADMIN_UIDS?: string,
 *   FIREBASE_PROJECT_ID?: string
 * }} WorkerEnv
 */

/**
 * @param {Request} request
 * @param {WorkerEnv} env
 * @param {string} [origin=env.ALLOWED_ORIGIN || DEFAULT_ALLOWED_ORIGIN]
 */
export async function requireUser(request, env, origin = env.ALLOWED_ORIGIN || DEFAULT_ALLOWED_ORIGIN) {
  const traceId = request.headers.get("x-trace-id") || "";
  const path = new URL(request.url).pathname;
  const token = getBearerToken(request);
  if (!token) {
    console.log("auth_missing_bearer_token", {
      path,
      traceId,
    });
    return { response: json({ error: "Missing Bearer token" }, 401, origin) };
  }

  try {
    const claims = await verifyFirebaseIdToken(token, env);
    const uid = typeof claims.user_id === "string" ? claims.user_id : claims.sub;

    if (!uid) {
      console.log("auth_invalid_token_missing_uid", {
        path,
        traceId,
      });
      return { response: json({ error: "Invalid token: missing uid/sub" }, 401, origin) };
    }

    const admins = parseAdminAllowlist(env.ADMIN_UIDS || "");
    const isAdmin = isAdminByClaims(claims) || admins.has(uid);
    console.log("auth_verified", {
      path,
      traceId,
      uid,
      isAdmin,
      hasAdminClaim: claims.admin === true,
      roleClaim: typeof claims.role === "string" ? claims.role : null,
      allowlistMatched: admins.has(uid),
    });

    return {
      auth: {
        uid,
        claims,
        isAdmin,
      },
    };
  } catch (error) {
    console.log("auth_verify_error", {
      path,
      traceId,
      projectIdConfigured: Boolean(env.FIREBASE_PROJECT_ID),
      message: error instanceof Error ? error.message : String(error),
    });
    return { response: json({ error: "Invalid or expired token" }, 401, origin) };
  }
}
