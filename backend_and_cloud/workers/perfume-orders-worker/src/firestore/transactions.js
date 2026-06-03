import { MAX_TRANSACTION_RETRIES } from "../constants/index.js";
import { createApiError } from "../http/errors.js";
import { firestoreRequest } from "./client.js";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

/**
 * @param {number} ms
 */
export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * @param {unknown} error
 */
export function isRetryableTransactionError(error) {
  const retryableGoogleStatuses = new Set([
    "ABORTED",
    "DEADLINE_EXCEEDED",
    "UNAVAILABLE",
    "FAILED_PRECONDITION",
  ]);
  const firestoreError = /** @type {{ googleStatus?: string | null } | null | undefined} */ (error);
  const status = firestoreError?.googleStatus;
  return typeof status === "string" && retryableGoogleStatuses.has(status);
}

/**
 * @param {WorkerEnv} env
 * @returns {Promise<string>}
 */
export async function beginTransaction(env) {
  const data = /** @type {{ transaction?: string }} */ (await firestoreRequest(env, "documents:beginTransaction", {
    method: "POST",
    body: {},
  }));
  if (!data?.transaction) {
    throw createApiError(500, "Failed to begin Firestore transaction");
  }
  return data.transaction;
}

/**
 * @param {WorkerEnv} env
 * @param {string | null | undefined} transaction
 */
export async function rollbackTransaction(env, transaction) {
  if (!transaction) return;
  try {
    await firestoreRequest(env, "documents:rollback", {
      method: "POST",
      body: { transaction },
    });
  } catch {
    // Non-fatal.
  }
}

/**
 * @param {WorkerEnv} env
 * @param {string | null | undefined} transaction
 * @param {unknown[]} writes
 */
export async function commitTransaction(env, transaction, writes) {
  /** @type {{ writes: unknown[], transaction?: string }} */
  const body = { writes };
  if (transaction !== null && transaction !== undefined) {
    body.transaction = transaction;
  }

  return firestoreRequest(env, "documents:commit", {
    method: "POST",
    body,
  });
}

/**
 * @template T
 * @param {(attempt: number) => Promise<{ done?: boolean, value?: T }>} runner
 * @returns {Promise<T | undefined>}
 */
export async function runTransactionWithRetries(runner) {
  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    try {
      const result = await runner(attempt);
      if (result?.done) return result.value;
    } catch (error) {
      if (attempt < MAX_TRANSACTION_RETRIES && isRetryableTransactionError(error)) {
        await sleep(40 * attempt);
        continue;
      }
      throw error;
    }
  }

  throw createApiError(503, "Could not complete transaction after retries");
}
