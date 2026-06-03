import { ORDER_STATUSES, allowedTransitions } from "../constants/index.js";
import { createApiError } from "../http/errors.js";

/**
 * @typedef {{ restockRequestId?: string }} AttributionMetadata
 */

/**
 * @typedef {{
 *   idempotencyKey: string,
 *   itemsByProductId: Map<string, { productId: string, variantId: string, quantity: number }>,
 *   address: string,
 *   phone: string,
 *   paymentMethod: string,
 *   shippingZoneCode: string,
 *   shippingGovernorate: string | null,
 *   clientShippingFee: number | null,
 *   orderSource: string,
 *   attributionMetadata: AttributionMetadata | null,
 *   notes: string | null
 * }} NormalizedOrderPayload
 */

/**
 * @param {unknown} value
 */
export function isOrderStatus(value) {
  return typeof value === "string" && ORDER_STATUSES.includes(value);
}

/**
 * @param {string} from
 * @param {string} to
 */
export function canTransition(from, to) {
  const nextStates = Object.prototype.hasOwnProperty.call(allowedTransitions, from)
    ? allowedTransitions[/** @type {keyof typeof allowedTransitions} */ (from)]
    : undefined;
  if (!Array.isArray(nextStates)) {
    return false;
  }
  return nextStates.includes(to);
}

/**
 * @param {unknown} text
 */
async function sha256Hex(text) {
  const input = new TextEncoder().encode(String(text || ""));
  const digest = await crypto.subtle.digest("SHA-256", input);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * @param {NormalizedOrderPayload & { payloadHash?: string }} payload
 */
export async function buildOrderPayloadHash(payload) {
  const canonicalItems = [...payload.itemsByProductId.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, item]) => ({
      productId: item.productId,
      variantId: item.variantId,
      quantity: item.quantity,
    }));

  const canonical = {
    items: canonicalItems,
    address: payload.address,
    phone: payload.phone,
    paymentMethod: payload.paymentMethod,
    shippingZoneCode: payload.shippingZoneCode,
    orderSource: payload.orderSource,
    attributionMetadata: payload.attributionMetadata ?? null,
    notes: payload.notes ?? null,
  };

  return sha256Hex(JSON.stringify(canonical));
}

/**
 * @param {unknown} rawValue
 * @param {string} orderSource
 * @returns {AttributionMetadata | null}
 */
function normalizeAttributionMetadata(rawValue, orderSource) {
  if (!rawValue || typeof rawValue !== "object" || Array.isArray(rawValue)) {
    return null;
  }

  const rawMetadata = /** @type {Record<string, unknown>} */ (rawValue);
  /** @type {AttributionMetadata} */
  const metadata = {};
  if (orderSource === "restock_alert") {
    const restockRequestId = String(rawMetadata.restockRequestId || "").trim();
    if (restockRequestId) {
      metadata.restockRequestId = restockRequestId;
    }
  }

  return Object.keys(metadata).length > 0 ? metadata : null;
}

/**
 * @param {Record<string, unknown>} body
 * @returns {NormalizedOrderPayload}
 */
export function normalizeOrderPayload(body) {
  const idempotencyKey = body.idempotencyKey;
  const items = body.items;

  if (typeof idempotencyKey !== "string" || idempotencyKey.trim().length < 8) {
    throw createApiError(400, "idempotencyKey is required (min 8 chars)");
  }

  if (!Array.isArray(items) || items.length === 0) {
    throw createApiError(400, "items must be a non-empty array");
  }

  const itemsByProductId = new Map();
  for (const rawItem of /** @type {unknown[]} */ (items)) {
    const item = /** @type {{ productId?: unknown, variantId?: unknown, quantity?: unknown }} */ (rawItem);
    const productId = String(item.productId || "").trim();
    const variantId = String(item.variantId || "default").trim() || "default";
    const quantity = Number(item.quantity);

    if (!productId) {
      throw createApiError(400, "Each item must include productId");
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw createApiError(400, `Invalid quantity for product '${productId}'`);
    }

    const lineKey = `${productId}::${variantId}`;
    const prev = itemsByProductId.get(lineKey);
    const nextQuantity = (prev?.quantity || 0) + quantity;
    if (nextQuantity > 10) {
      throw createApiError(400, `Quantity for product '${productId}' variant '${variantId}' cannot exceed 10`);
    }
    itemsByProductId.set(lineKey, {
      productId,
      variantId,
      quantity: nextQuantity,
    });
    if (itemsByProductId.size > 20) {
      throw createApiError(400, "orders cannot contain more than 20 unique items");
    }
  }

  const address = typeof body.address === "string" ? body.address.trim() : "";
  const phone = typeof body.phone === "string" ? body.phone.trim() : "";
  const paymentMethod =
    typeof body.paymentMethod === "string" && body.paymentMethod.trim().length > 0
      ? body.paymentMethod.trim()
      : "cash_on_delivery";
  const notes = typeof body.notes === "string" ? body.notes.trim() : null;
  const shippingZoneCode =
    typeof body.shippingZoneCode === "string" ? body.shippingZoneCode.trim().toLowerCase() : "";
  const shippingGovernorate =
    typeof body.shippingGovernorate === "string" && body.shippingGovernorate.trim().length > 0
      ? body.shippingGovernorate.trim()
      : null;
  const rawClientShippingFee = Number(body.clientShippingFee);
  const clientShippingFee = Number.isFinite(rawClientShippingFee)
    ? Math.max(0, rawClientShippingFee)
    : null;
  const rawOrderSource =
    typeof body.orderSource === "string" ? body.orderSource.trim().toLowerCase() : "";
  const allowedOrderSources = new Set(["app", "ai_chat", "restock_alert"]);
  const orderSource = allowedOrderSources.has(rawOrderSource)
    ? rawOrderSource
    : "app";
  const attributionMetadata = normalizeAttributionMetadata(
    body.attributionMetadata,
    orderSource,
  );

  if (!address) throw createApiError(400, "address is required");
  if (!phone) throw createApiError(400, "phone is required");
  if (!/^(010|011|012|015)\d{8}$/.test(phone)) {
    throw createApiError(400, "phone is invalid");
  }
  if (paymentMethod !== "cash_on_delivery") {
    throw createApiError(400, "Unsupported payment method");
  }
  if (!shippingZoneCode) throw createApiError(400, "shippingZoneCode is required");

  return {
    idempotencyKey: idempotencyKey.trim(),
    itemsByProductId,
    address,
    phone,
    paymentMethod,
    shippingZoneCode,
    shippingGovernorate,
    clientShippingFee,
    orderSource,
    attributionMetadata,
    notes,
  };
}
