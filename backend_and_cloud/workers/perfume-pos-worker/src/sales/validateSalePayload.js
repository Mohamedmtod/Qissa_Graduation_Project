import { createApiError } from "../http/errors.js";

/**
 * Validates the top-level sale payload (outside transaction).
 * Pure function — no Firestore calls. Throws ApiError on invalid input.
 *
 * @param {{ idempotencyKey?: unknown, sessionId?: unknown, items?: unknown[], paymentMethod?: unknown }} payload
 */
export function validateSalePayload(payload) {
  const { idempotencyKey, sessionId, items = [], paymentMethod } = payload;

  const VALID_PAYMENT_METHODS = new Set(["cash", "card"]);
  if (!VALID_PAYMENT_METHODS.has(paymentMethod)) {
    throw createApiError(400, `Invalid paymentMethod "${paymentMethod}": must be cash or card`);
  }

  if (!idempotencyKey || !sessionId || !items.length) {
    throw createApiError(400, "Missing required parameters (idempotencyKey, sessionId, items)");
  }
}

/**
 * Validates a single cart item's quantity.
 * Pure function — no Firestore calls. Throws ApiError on invalid input.
 *
 * @param {string} productId
 * @param {unknown} quantity
 */
export function validateItemQuantity(productId, quantity) {
  const qty = Number(quantity);
  if (!Number.isFinite(qty) || qty <= 0) {
    throw createApiError(400, `Invalid quantity for item ${productId}: must be a positive number (got ${quantity})`);
  }
  return qty;
}

/**
 * Validates session ownership.
 * Pure function. Throws ApiError if session does not belong to cashier.
 *
 * @param {{ openedBy?: string, status?: string }} sessionData
 * @param {string} cashierUid
 * @param {string} sessionId
 */
export function validateSessionOwnership(sessionData, cashierUid, sessionId) {
  if (sessionData.openedBy !== cashierUid) {
    throw createApiError(403, `Cash session ${sessionId} does not belong to this cashier`);
  }
}
