import { DEFAULT_ALLOWED_ORIGIN } from "../constants/index.js";
import { json } from "./responses.js";

/**
 * @typedef {Error & { status?: number; details?: unknown }} ApiError
 */

/**
 * @param {number} status
 * @param {string} message
 * @param {unknown} [details]
 * @returns {ApiError}
 */
export function createApiError(status, message, details) {
  const error = /** @type {ApiError} */ (new Error(message));
  error.status = status;
  error.details = details;
  return error;
}

/**
 * @param {unknown} error
 * @param {string} [origin=DEFAULT_ALLOWED_ORIGIN]
 */
export function mapErrorToResponse(error, origin = DEFAULT_ALLOWED_ORIGIN) {
  const apiError = /** @type {ApiError | null | undefined} */ (error);
  if (apiError?.status && Number.isInteger(apiError.status)) {
    if (apiError.status >= 500) {
      console.log("pos_worker_internal_error", {
        status: apiError.status,
        errorName: apiError.name || "Error",
      });
      return json({ 
        error: apiError.message || "Internal Server Error", 
        details: apiError.details ?? null,
        stack: apiError.stack ?? null 
      }, apiError.status, origin);
    }

    return json(
      {
        error: apiError.message || "Request failed",
        details: apiError.details ?? null,
      },
      apiError.status,
      origin,
    );
  }

  console.log("pos_worker_unhandled_error", {
    errorName: error instanceof Error ? error.name : "UnknownError",
  });
  return json(
    { 
      error: error instanceof Error ? error.message : "Internal Server Error",
      stack: error instanceof Error ? error.stack : null 
    },
    500,
    origin,
  );
}
