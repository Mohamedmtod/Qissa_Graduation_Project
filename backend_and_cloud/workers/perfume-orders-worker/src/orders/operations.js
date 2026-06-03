import { MAX_TRANSACTION_RETRIES } from "../constants/index.js";
import { createApiError } from "../http/errors.js";
import {
  decodeFirestoreDocument,
  toFirestoreFields,
} from "../firestore/codec.js";
import { batchGetDocuments, firestoreDocName } from "../firestore/queries.js";
import {
  beginTransaction,
  commitTransaction,
  rollbackTransaction,
  isRetryableTransactionError,
  sleep,
} from "../firestore/transactions.js";
import {
  buildRestockConversionPatch,
  buildRestockConversionSuccessEvent,
} from "../restock/events.js";
import { allowedTransitions } from "../constants/index.js";
import { canTransition, isOrderStatus } from "./validation.js";

const ORDER_CODE_PREFIX = "QA";
const ORDER_CODE_LENGTH = 8;
const ORDER_CODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const ORDER_CODE_SOURCE = "perfume-orders-worker";
const DEFAULT_VARIANT_ID = "default";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

/**
 * @typedef {{
 *   idempotencyKey: string,
 *   itemsByProductId: Map<string, { productId: string, variantId: string, quantity: number }>,
 *   address: string,
 *   phone: string,
 *   paymentMethod: string,
 *   shippingZoneCode: string,
 *   shippingGovernorate?: string | null,
 *   clientShippingFee?: number | null,
 *   orderSource: string,
 *   attributionMetadata?: Record<string, unknown> | null,
 *   notes?: string | null,
 *   payloadHash: string
 * }} OrderPayload
 */

/**
 * @typedef {{
 *   productId: string,
 *   variantId: string,
 *   variantLabel: string,
 *   name: string,
 *   quantity: number,
 *   priceSnapshot: number,
 *   productDocName: string
 * }} OrderItemWrite
 */

export function generateOrderCode() {
  const bytes = new Uint8Array(ORDER_CODE_LENGTH);
  crypto.getRandomValues(bytes);

  let code = `${ORDER_CODE_PREFIX}-`;
  for (let i = 0; i < bytes.length; i++) {
    code += ORDER_CODE_ALPHABET[bytes[i] % ORDER_CODE_ALPHABET.length];
  }
  return code;
}

/**
 * @param {unknown} error
 * @param {string | null | undefined} orderCode
 */
function isOrderCodeReservationCollision(error, orderCode) {
  if (!orderCode) return false;
  const firestoreError = /** @type {{ googleStatus?: string | null, message?: string, details?: unknown }} */ (error);
  if (firestoreError?.googleStatus !== "FAILED_PRECONDITION") return false;

  const details = JSON.stringify(firestoreError.details ?? "");
  const message = `${firestoreError.message ?? ""} ${details}`;
  return message.includes(orderCode) || message.includes("order_codes");
}

/**
 * @param {unknown} error
 * @param {string | null | undefined} orderCode
 */
function isRetryableCreateOrderError(error, orderCode) {
  const firestoreError = /** @type {{ googleStatus?: string | null }} */ (error);
  const retryableStatuses = new Set([
    "ABORTED",
    "DEADLINE_EXCEEDED",
    "UNAVAILABLE",
  ]);
  return (
    retryableStatuses.has(String(firestoreError?.googleStatus || "")) ||
    isOrderCodeReservationCollision(error, orderCode)
  );
}

/**
 * @param {unknown} value
 */
function normaliseZoneCode(value) {
  return String(value || "").trim().toLowerCase();
}

/**
 * @param {Record<string, unknown>} zone
 */
function zoneCodeOf(zone) {
  const explicit = normaliseZoneCode(zone.code);
  if (explicit) return explicit;

  return String(zone.governorateEn || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function normaliseVariantId(value) {
  const variantId = String(value || DEFAULT_VARIANT_ID).trim();
  return variantId || DEFAULT_VARIANT_ID;
}

function validSalePrice(price, salePrice) {
  return Number.isFinite(salePrice) && salePrice > 0 && salePrice < price;
}

function aggregateVariantStock(variants) {
  return variants.reduce((sum, variant) => {
    const stock = Number(variant?.stock || 0);
    return sum + (Number.isFinite(stock) && stock > 0 ? stock : 0);
  }, 0);
}

function resolveRequestedVariant(productData, productId, requestedVariantId) {
  const variantId = normaliseVariantId(requestedVariantId);
  const rawVariants = Array.isArray(productData.variants) ? productData.variants : [];
  const variants = rawVariants
    .filter((variant) => variant && typeof variant === "object" && !Array.isArray(variant))
    .map((variant) => ({ .../** @type {Record<string, unknown>} */ (variant) }));

  if (variants.length > 0) {
    const variantIndex = variants.findIndex(
      (variant) => normaliseVariantId(variant.id) === variantId,
    );
    if (variantIndex < 0) {
      throw createApiError(409, `Variant '${variantId}' for product '${productId}' is unavailable`, {
        productId,
        variantId,
      });
    }

    const variant = variants[variantIndex];
    const fallbackPrice = Number(productData.price || 0);
    const price = Number(variant.price ?? fallbackPrice);
    const salePrice = Number(variant.salePrice || 0);
    const effectivePrice = validSalePrice(price, salePrice) ? salePrice : price;
    const stock = Number(variant.stock || 0);
    if (!Number.isFinite(effectivePrice) || effectivePrice < 0) {
      throw createApiError(409, `Product '${productId}' variant '${variantId}' has invalid price`);
    }

    return {
      usesVariants: true,
      variants,
      variantIndex,
      variantId,
      variantLabel: String(variant.label || variant.size || productData.size || variantId).trim(),
      stock: Number.isFinite(stock) ? stock : 0,
      priceSnapshot: effectivePrice,
    };
  }

  if (variantId !== DEFAULT_VARIANT_ID) {
    throw createApiError(409, `Variant '${variantId}' for product '${productId}' is unavailable`, {
      productId,
      variantId,
    });
  }

  const price = Number(productData.price || 0);
  const salePrice = Number(productData.salePrice || 0);
  const effectivePrice = validSalePrice(price, salePrice) ? salePrice : price;
  if (!Number.isFinite(effectivePrice) || effectivePrice < 0) {
    throw createApiError(409, `Product '${productId}' has invalid price`);
  }

  const stock = Number(productData.stock || 0);
  return {
    usesVariants: false,
    variants: [],
    variantIndex: -1,
    variantId: DEFAULT_VARIANT_ID,
    variantLabel: String(productData.size || "").trim(),
    stock: Number.isFinite(stock) ? stock : 0,
    priceSnapshot: effectivePrice,
  };
}

function buildProductStockPatch(productData, productId, variantId, quantityDelta) {
  const variant = resolveRequestedVariant(productData, productId, variantId);
  const nextStock = variant.stock + quantityDelta;
  if (!Number.isFinite(nextStock) || nextStock < 0) {
    throw createApiError(409, `Insufficient stock for '${productId}'`, {
      productId,
      variantId: variant.variantId,
      available: variant.stock,
      requested: Math.abs(quantityDelta),
    });
  }

  if (variant.usesVariants) {
    const nextVariants = variant.variants.map((entry, index) =>
      index === variant.variantIndex ? { ...entry, stock: nextStock } : entry,
    );
    return {
      snapshot: variant,
      nextProductData: {
        ...productData,
        variants: nextVariants,
        stock: aggregateVariantStock(nextVariants),
      },
      fields: {
        variants: nextVariants,
        stock: aggregateVariantStock(nextVariants),
      },
      fieldPaths: ["variants", "stock"],
    };
  }

  return {
    snapshot: variant,
    nextProductData: {
      ...productData,
      stock: nextStock,
    },
    fields: {
      stock: nextStock,
    },
    fieldPaths: ["stock"],
  };
}

export function normalizeTraceId(value) {
  const traceId = String(value || "").trim();
  return traceId.replace(/[^a-zA-Z0-9_.:-]+/g, "-").slice(0, 180)
    || `admin-order-transition-${Date.now()}-${crypto.randomUUID()}`;
}

export function buildAdminTransitionTimelineValue({
  adminUid,
  fromStatus,
  toStatus,
  occurredAt,
}) {
  return {
    mapValue: {
      fields: {
        actorId: { stringValue: adminUid },
        actorRole: { stringValue: "admin" },
        source: { stringValue: "admin_dashboard" },
        occurredAt: { timestampValue: occurredAt },
        note: {
          stringValue: `Admin changed order status from ${fromStatus} to ${toStatus}.`,
        },
        fromStatus: { stringValue: fromStatus },
        toStatus: { stringValue: toStatus },
      },
    },
  };
}

function toMinorUnits(value) {
  const numberValue = Number(value || 0);
  if (!Number.isFinite(numberValue) || numberValue <= 0) return 0;
  return Math.round(numberValue * 100);
}

function orderTotalMinor(orderData) {
  if (Object.prototype.hasOwnProperty.call(orderData, "totalAmount")) {
    const value = Number(orderData.totalAmount || 0);
    return Number.isFinite(value) && value > 0 ? Math.round(value) : 0;
  }
  return toMinorUnits(orderData.total);
}

function monthKeyForOrder(orderData, fallbackIso) {
  const raw = typeof orderData.createdAt === "string" ? orderData.createdAt : fallbackIso;
  const date = new Date(raw);
  const safeDate = Number.isNaN(date.getTime()) ? new Date(fallbackIso) : date;
  const month = String(safeDate.getUTCMonth() + 1).padStart(2, "0");
  return `${safeDate.getUTCFullYear()}_${month}`;
}

function incrementTransform(fieldPath, value) {
  return {
    fieldPath,
    increment: { integerValue: String(Math.trunc(value)) },
  };
}

export function buildDeliveredAggregateWrites(projectId, orderData, occurredAt, orderId = "") {
  const totalMinor = orderTotalMinor(orderData);
  const monthKey = monthKeyForOrder(orderData, occurredAt);
  const source = String(orderData.orderSource || "app");
  const items = Array.isArray(orderData.items) ? orderData.items : [];
  const writes = [];

  const normalizedOrderId = String(orderId || orderData.id || "").trim();
  if (normalizedOrderId) {
    writes.push({
      update: {
        name: firestoreDocName(projectId, "admin_finance_aggregate_markers", normalizedOrderId),
        fields: toFirestoreFields({
          orderId: normalizedOrderId,
          source: "orders_worker",
        }),
      },
      currentDocument: { exists: false },
    });
    writes.push({
      transform: {
        document: firestoreDocName(projectId, "admin_finance_aggregate_markers", normalizedOrderId),
        fieldTransforms: [{ fieldPath: "aggregatedAt", setToServerValue: "REQUEST_TIME" }],
      },
    });
  }

  const summaryDocName = firestoreDocName(projectId, "admin_finance_aggregates", "summary");
  writes.push({
    update: {
      name: summaryDocName,
      fields: toFirestoreFields({
        schemaVersion: 1,
        currency: "EGP",
        source: "orders_worker",
      }),
    },
    updateMask: { fieldPaths: ["schemaVersion", "currency", "source"] },
  });
  writes.push({
    transform: {
      document: summaryDocName,
      fieldTransforms: [
        incrementTransform("totalDeliveredOrders", 1),
        incrementTransform("totalDeliveredRevenueMinor", totalMinor),
        incrementTransform(source === "ai_chat" ? "aiChatDeliveredOrders" : "appDeliveredOrders", 1),
        { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
      ],
    },
  });

  const monthlyDocName = firestoreDocName(projectId, "admin_finance_monthly_rollups", monthKey);
  writes.push({
    update: {
      name: monthlyDocName,
      fields: toFirestoreFields({
        schemaVersion: 1,
        currency: "EGP",
        monthKey,
        monthStart: `${monthKey.replace("_", "-")}-01T00:00:00.000Z`,
        source: "orders_worker",
      }),
    },
    updateMask: {
      fieldPaths: ["schemaVersion", "currency", "monthKey", "monthStart", "source"],
    },
  });
  writes.push({
    transform: {
      document: monthlyDocName,
      fieldTransforms: [
        incrementTransform("deliveredOrders", 1),
        incrementTransform("deliveredRevenueMinor", totalMinor),
        { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
      ],
    },
  });

  const productRollups = new Map();
  for (const item of items) {
    const productId = String(item?.productId || "").trim();
    if (!productId) continue;
    const quantity = Number(item.quantity || 0);
    if (!Number.isFinite(quantity) || quantity <= 0) continue;
    const unitPriceMinor = toMinorUnits(item.priceSnapshot);
    const existing = productRollups.get(productId) || {
      name: String(item.name || "").trim(),
      units: 0,
      revenueMinor: 0,
    };
    existing.units += Math.trunc(quantity);
    existing.revenueMinor += unitPriceMinor * Math.trunc(quantity);
    if (!existing.name && item.name) existing.name = String(item.name).trim();
    productRollups.set(productId, existing);
  }

  for (const [productId, rollup] of productRollups.entries()) {
    const publicStatsDocName = firestoreDocName(projectId, "product_public_stats", productId);
    writes.push({
      update: {
        name: publicStatsDocName,
        fields: toFirestoreFields({
          productId,
          productName: rollup.name || null,
          schemaVersion: 1,
          source: "orders_worker",
        }),
      },
      updateMask: { fieldPaths: ["productId", "productName", "schemaVersion", "source"] },
    });
    writes.push({
      transform: {
        document: publicStatsDocName,
        fieldTransforms: [
          incrementTransform("deliveredOrdersCount", 1),
          incrementTransform("unitsSold", rollup.units),
          incrementTransform("revenueMinor", rollup.revenueMinor),
          { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
        ],
      },
    });
  }

  return writes;
}

/**
 * @param {WorkerEnv} env
 * @param {string} projectId
 * @param {string} shippingZoneCode
 * @param {string | null | undefined} transaction
 */
async function resolveEnabledShippingZone(env, projectId, shippingZoneCode, transaction) {
  const requestedCode = normaliseZoneCode(shippingZoneCode);
  if (!requestedCode) {
    throw createApiError(400, "shippingZoneCode is required");
  }

  const shippingConfigDocName = firestoreDocName(projectId, "config", "shipping_zones");
  const shippingDocs = await batchGetDocuments(env, [shippingConfigDocName], transaction);
  const shippingDoc = shippingDocs.found.get(shippingConfigDocName);
  if (!shippingDoc) {
    throw createApiError(409, "Shipping zones are not configured");
  }

  const shippingConfig = decodeFirestoreDocument(shippingDoc);
  const zones = Array.isArray(shippingConfig.zones) ? shippingConfig.zones : [];
  const zone = zones
    .filter((entry) => entry && typeof entry === "object" && !Array.isArray(entry))
    .map((entry) => /** @type {Record<string, unknown>} */(entry))
    .find((entry) => zoneCodeOf(entry) === requestedCode);

  if (!zone) {
    throw createApiError(400, "Delivery is not available for this area", {
      shippingZoneCode: requestedCode,
    });
  }
  if (zone.enabled !== true) {
    throw createApiError(400, "Delivery is currently disabled for this area", {
      shippingZoneCode: requestedCode,
    });
  }

  const fee = Number(zone.fee);
  if (!Number.isFinite(fee) || fee < 0) {
    throw createApiError(409, "Shipping zone has an invalid fee", {
      shippingZoneCode: requestedCode,
    });
  }

  return {
    code: requestedCode,
    governorate:
      typeof zone.governorate === "string" && zone.governorate.trim()
        ? zone.governorate.trim()
        : null,
    governorateEn:
      typeof zone.governorateEn === "string" && zone.governorateEn.trim()
        ? zone.governorateEn.trim()
        : null,
    fee,
  };
}

/**
 * @param {WorkerEnv} env
 * @param {string} adminUid
 * @param {string} orderId
 * @param {string} fromStatus
 * @param {string} toStatus
 * @param {string | null | undefined} cancelReason
 * @param {string | null | undefined} traceId
 */
export async function updateOrderStatusByAdminAtomically(
  env,
  adminUid,
  orderId,
  fromStatus,
  toStatus,
  cancelReason,
  traceId,
) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const resolvedTraceId = normalizeTraceId(traceId);
  const orderDocName = firestoreDocName(projectId, "orders", orderId);
  const auditDocName = firestoreDocName(
    projectId,
    "admin_audit_logs",
    resolvedTraceId,
  );

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;

    try {
      transaction = await beginTransaction(env);

      const orderDocs = await batchGetDocuments(env, [orderDocName], transaction);
      const orderDoc = orderDocs.found.get(orderDocName);
      if (!orderDoc) {
        throw createApiError(404, `Order '${orderId}' not found`);
      }

      const orderData = decodeFirestoreDocument(orderDoc);
      const currentStatus = String(orderData.status || "");

      if (!isOrderStatus(currentStatus)) {
        throw createApiError(409, "Order has invalid current status");
      }
      if (currentStatus !== fromStatus) {
        throw createApiError(
          409,
          `Order status mismatch. Expected '${fromStatus}' but found '${currentStatus}'`,
          { currentStatus },
        );
      }
      if (!canTransition(currentStatus, toStatus)) {
        const allowedForCurrent = Object.prototype.hasOwnProperty.call(
          allowedTransitions,
          currentStatus,
        )
          ? allowedTransitions[
            /** @type {keyof typeof allowedTransitions} */ (currentStatus)
          ]
          : [];
        throw createApiError(
          409,
          `Illegal transition from '${currentStatus}' to '${toStatus}'`,
          { allowed: allowedForCurrent },
        );
      }

      const writes = [];
      const items = Array.isArray(orderData.items) ? orderData.items : [];
      const stockWasDeducted = orderData.stockDeducted === true;
      const shouldRestock = toStatus === "cancelled" && stockWasDeducted;
      let restocked = false;

      if (shouldRestock && items.length > 0) {
        const productDocNames = [
          ...new Set(items.map((item) => firestoreDocName(projectId, "products", item.productId))),
        ];
        const productDocs = await batchGetDocuments(env, productDocNames, transaction);
        const productDataByDocName = new Map();
        const stockPatchesByDocName = new Map();

        for (const item of items) {
          const docName = firestoreDocName(projectId, "products", item.productId);
          const pDoc = productDocs.found.get(docName);
          if (!pDoc) {
            throw createApiError(
              409,
              `Failed to restock: Product '${item.productId}' no longer exists`,
            );
          }

          const productData =
            productDataByDocName.get(docName) || decodeFirestoreDocument(pDoc);
          const quantity = Number(item.quantity || 0);

          if (!Number.isFinite(quantity) || quantity <= 0) {
            throw createApiError(409, `Invalid item quantity for '${item.productId}'`);
          }

          const patch = buildProductStockPatch(
            productData,
            String(item.productId || ""),
            normaliseVariantId(item.variantId),
            quantity,
          );
          productDataByDocName.set(docName, patch.nextProductData);
          stockPatchesByDocName.set(docName, patch);
          restocked = true;
        }

        for (const [docName, patch] of stockPatchesByDocName.entries()) {
          writes.push({
            update: {
              name: docName,
              fields: toFirestoreFields(patch.fields),
            },
            updateMask: { fieldPaths: patch.fieldPaths },
          });
        }
      }

      const orderUpdateFields = /** @type {{
        status: string,
        updatedBy: string,
        failureReason?: string,
        stockDeducted?: boolean
      }} */ ({
          status: toStatus,
          updatedBy: adminUid,
        });

      if (toStatus === "cancelled") {
        orderUpdateFields.failureReason =
          typeof cancelReason === "string" && cancelReason.trim().length > 0
            ? cancelReason.trim()
            : "Cancelled by store";
        if (stockWasDeducted) {
          orderUpdateFields.stockDeducted = false;
        }
      }

      const occurredAt = new Date().toISOString();
      const timelineValue = buildAdminTransitionTimelineValue({
        adminUid,
        fromStatus,
        toStatus,
        occurredAt,
      });

      writes.push({
        update: {
          name: orderDocName,
          fields: toFirestoreFields(orderUpdateFields),
        },
        updateMask: { fieldPaths: Object.keys(orderUpdateFields) },
      });

      writes.push({
        transform: {
          document: orderDocName,
          fieldTransforms: [
            { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
            {
              fieldPath: "timeline",
              appendMissingElements: { values: [timelineValue] },
            },
          ],
        },
      });

      writes.push({
        update: {
          name: auditDocName,
          fields: toFirestoreFields({
            traceId: resolvedTraceId,
            action: "order_status_transition",
            actorId: adminUid,
            actorRole: "admin",
            targetId: orderId,
            outcome: "success",
            details: `from=${fromStatus} to=${toStatus} restocked=${restocked}`,
          }),
        },
        currentDocument: { exists: false },
      });

      writes.push({
        transform: {
          document: auditDocName,
          fieldTransforms: [
            { fieldPath: "occurredAt", setToServerValue: "REQUEST_TIME" },
          ],
        },
      });

      if (toStatus === "delivered" && fromStatus !== "delivered") {
        writes.push(...buildDeliveredAggregateWrites(projectId, orderData, occurredAt, orderId));
      }

      if (restocked) {
        writes.push({
          transform: {
            document: orderDocName,
            fieldTransforms: [{ fieldPath: "restockedAt", setToServerValue: "REQUEST_TIME" }],
          },
        });
      }

      if (orderData.idempotencyKey) {
        const idempotencyDocName = firestoreDocName(
          projectId,
          "order_idempotency",
          `${orderData.userId}_${orderData.idempotencyKey}`,
        );
        const idempotencyDocs = await batchGetDocuments(env, [idempotencyDocName], transaction);
        if (idempotencyDocs.found.get(idempotencyDocName)) {
          const idemUpdate = /** @type {{ status: string, stockDeducted?: boolean }} */ ({
            status: toStatus,
          });
          if (toStatus === "cancelled" && stockWasDeducted) {
            idemUpdate.stockDeducted = false;
          }
          writes.push({
            update: {
              name: idempotencyDocName,
              fields: toFirestoreFields(idemUpdate),
            },
            updateMask: { fieldPaths: Object.keys(idemUpdate) },
            currentDocument: { exists: true },
          });
        }
      }

      await commitTransaction(env, transaction, writes);
      committed = true;

      return {
        ok: true,
        orderId,
        fromStatus,
        status: toStatus,
        restocked,
        traceId: resolvedTraceId,
      };
    } catch (error) {
      if (!committed) {
        await rollbackTransaction(env, transaction);
      }

      if (attempt < MAX_TRANSACTION_RETRIES && isRetryableTransactionError(error)) {
        await sleep(40 * attempt);
        continue;
      }

      throw error;
    }
  }

  throw createApiError(503, "Could not complete admin status transaction after retries");
}

/**
 * @param {WorkerEnv} env
 * @param {string} uid
 * @param {string} orderId
 */
export async function cancelOrderAtomically(env, uid, orderId) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const orderDocName = firestoreDocName(projectId, "orders", orderId);

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;

    try {
      transaction = await beginTransaction(env);

      const orderDocs = await batchGetDocuments(env, [orderDocName], transaction);
      const orderDoc = orderDocs.found.get(orderDocName);

      if (!orderDoc) {
        throw createApiError(404, `Order '${orderId}' not found`);
      }

      const orderData = decodeFirestoreDocument(orderDoc);

      if (orderData.userId !== uid) {
        throw createApiError(403, "You do not have permission to cancel this order");
      }

      if (orderData.status !== "pending") {
        throw createApiError(409, `Cannot cancel order in '${orderData.status}' status. Only 'pending' orders can be cancelled.`);
      }

      const items = Array.isArray(orderData.items)
        ? /** @type {Array<Record<string, unknown>>} */ (orderData.items)
        : [];
      const stockWasDeducted = orderData.stockDeducted === true;
      const productDocNames = [
        ...new Set(
          items.map((item) =>
            firestoreDocName(projectId, "products", String(item.productId || "")),
          ),
        ),
      ];

      let productDocs = { found: new Map() };
      if (stockWasDeducted && productDocNames.length > 0) {
        productDocs = await batchGetDocuments(env, productDocNames, transaction);
      }

      const writes = [];
      let idempotencyDocName = null;
      let idempotencyDocExists = false;
      if (orderData.idempotencyKey) {
        idempotencyDocName = firestoreDocName(
          projectId,
          "order_idempotency",
          `${uid}_${orderData.idempotencyKey}`,
        );
        const idempotencyDocs = await batchGetDocuments(env, [idempotencyDocName], transaction);
        idempotencyDocExists = Boolean(idempotencyDocs.found.get(idempotencyDocName));
      }

      if (stockWasDeducted) {
        const productDataByDocName = new Map();
        const stockPatchesByDocName = new Map();

        for (const item of items) {
          const itemProductId = String(item.productId || "");
          const docName = firestoreDocName(projectId, "products", itemProductId);
          const pDoc = productDocs.found.get(docName);

          if (!pDoc) {
            throw createApiError(409, `Failed to restock: Product '${itemProductId}' no longer exists in database`);
          }

          const productData =
            productDataByDocName.get(docName) || decodeFirestoreDocument(pDoc);
          const quantity = Number(item.quantity || 0);
          if (!Number.isFinite(quantity) || quantity <= 0) {
            throw createApiError(409, `Invalid item quantity for '${itemProductId}'`);
          }

          const patch = buildProductStockPatch(
            productData,
            itemProductId,
            normaliseVariantId(item.variantId),
            quantity,
          );
          productDataByDocName.set(docName, patch.nextProductData);
          stockPatchesByDocName.set(docName, patch);
        }

        for (const [docName, patch] of stockPatchesByDocName.entries()) {
          writes.push({
            update: {
              name: docName,
              fields: toFirestoreFields(patch.fields),
            },
            updateMask: {
              fieldPaths: patch.fieldPaths,
            },
          });
        }
      }

      const orderUpdateFields = /** @type {{ status: string, failureReason: string, stockDeducted?: boolean }} */ ({
        status: "cancelled",
        failureReason: "Cancelled by user",
      });

      if (stockWasDeducted) {
        orderUpdateFields.stockDeducted = false;
      }

      writes.push({
        update: {
          name: orderDocName,
          fields: toFirestoreFields(orderUpdateFields),
        },
        updateMask: {
          fieldPaths: Object.keys(orderUpdateFields),
        },
      });

      if (idempotencyDocName && idempotencyDocExists) {
        writes.push({
          update: {
            name: idempotencyDocName,
            fields: toFirestoreFields(orderUpdateFields),
          },
          updateMask: {
            fieldPaths: Object.keys(orderUpdateFields),
          },
          currentDocument: { exists: true },
        });
      }

      if (stockWasDeducted) {
        writes.push({
          transform: {
            document: orderDocName,
            fieldTransforms: [
              {
                fieldPath: "restockedAt",
                setToServerValue: "REQUEST_TIME",
              },
            ],
          },
        });
      }

      await commitTransaction(env, transaction, writes);
      committed = true;

      return {
        ok: true,
        orderId,
        status: "cancelled",
        restocked: stockWasDeducted,
      };
    } catch (error) {
      if (!committed) {
        await rollbackTransaction(env, transaction);
      }

      if (attempt < MAX_TRANSACTION_RETRIES && isRetryableTransactionError(error)) {
        await sleep(40 * attempt);
        continue;
      }

      throw error;
    }
  }

  throw createApiError(503, "Could not complete cancel transaction after retries");
}

/**
 * @param {WorkerEnv} env
 * @param {string} uid
 * @param {OrderPayload} payload
 */
export async function createOrderAtomically(env, uid, payload) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const idempotencyDocName = firestoreDocName(
    projectId,
    "order_idempotency",
    `${uid}_${payload.idempotencyKey}`,
  );

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;
    let orderCode = null;

    try {
      transaction = await beginTransaction(env);

      const requestedItems = [...payload.itemsByProductId.values()];
      const productIds = [...new Set(requestedItems.map((item) => item.productId))];
      const productDocNames = productIds.map((id) =>
        firestoreDocName(projectId, "products", id),
      );
      const restockRequestId =
        typeof payload.attributionMetadata?.restockRequestId === "string"
          ? payload.attributionMetadata.restockRequestId.trim()
          : "";
      const restockRequestDocName = restockRequestId
        ? firestoreDocName(projectId, "restock_requests", restockRequestId)
        : null;
      const docsToFetch = [idempotencyDocName, ...productDocNames];
      if (restockRequestDocName) {
        docsToFetch.push(restockRequestDocName);
      }

      const docs = await batchGetDocuments(env, docsToFetch, transaction);

      const existingIdempotency = docs.found.get(idempotencyDocName);
      if (existingIdempotency) {
        const idemData = decodeFirestoreDocument(existingIdempotency);
        if (idemData.payloadHash && idemData.payloadHash !== payload.payloadHash) {
          throw createApiError(
            409,
            "idempotencyKey already used with a different payload",
            {
              key: payload.idempotencyKey,
            },
          );
        }

        await rollbackTransaction(env, transaction);
        return {
          ok: true,
          idempotent: true,
          orderId: idemData.orderId || null,
          orderCode:
            typeof idemData.orderCode === "string" && idemData.orderCode.trim()
              ? idemData.orderCode.trim()
              : null,
          status: idemData.status || "pending",
          stockDeducted: idemData.stockDeducted === true,
        };
      }

      const shippingZone = await resolveEnabledShippingZone(
        env,
        projectId,
        payload.shippingZoneCode,
        transaction,
      );

      /** @type {OrderItemWrite[]} */
      const orderItems = [];
      const productDataByDocName = new Map();
      const stockPatchesByDocName = new Map();
      let orderSubtotal = 0;

      for (const requestedItem of requestedItems) {
        const { productId, variantId, quantity: requestedQty } = requestedItem;
        const docName = firestoreDocName(projectId, "products", productId);
        const productDoc = docs.found.get(docName);

        if (!productDoc) {
          throw createApiError(409, `Product '${productId}' no longer exists`, {
            productId,
          });
        }

        const productData =
          productDataByDocName.get(docName) || decodeFirestoreDocument(productDoc);
        const name = String(productData.name || "");
        const patch = buildProductStockPatch(
          productData,
          productId,
          variantId,
          -requestedQty,
        );
        const variantSnapshot = patch.snapshot;

        productDataByDocName.set(docName, patch.nextProductData);
        stockPatchesByDocName.set(docName, patch);

        orderItems.push({
          productId,
          variantId: variantSnapshot.variantId,
          variantLabel: variantSnapshot.variantLabel,
          name,
          quantity: requestedQty,
          priceSnapshot: variantSnapshot.priceSnapshot,
          productDocName: docName,
        });

        orderSubtotal += variantSnapshot.priceSnapshot * requestedQty;
      }

      const shippingFee = shippingZone.fee;
      const orderTotal = orderSubtotal + shippingFee;

      const orderId = crypto.randomUUID();
      orderCode = generateOrderCode();
      const orderDocName = firestoreDocName(projectId, "orders", orderId);
      const orderCodeDocName = firestoreDocName(projectId, "order_codes", orderCode);

      const writes = [];

      writes.push({
        update: {
          name: orderDocName,
          fields: toFirestoreFields({
            userId: uid,
            items: orderItems.map((item) => ({
              productId: item.productId,
              variantId: item.variantId,
              variantLabel: item.variantLabel,
              name: item.name,
              quantity: item.quantity,
              priceSnapshot: item.priceSnapshot,
            })),
            subtotal: orderSubtotal,
            shippingFee,
            discount: 0,
            total: orderTotal,
            status: "pending",
            stockDeducted: true,
            idempotencyKey: payload.idempotencyKey,
            orderCode,
            shippingZoneCode: shippingZone.code,
            shippingGovernorate:
              shippingZone.governorate || payload.shippingGovernorate || null,
            shippingGovernorateEn: shippingZone.governorateEn,
            clientShippingFee: payload.clientShippingFee,
            orderSource: payload.orderSource,
            attributionMetadata: payload.attributionMetadata,
            address: payload.address,
            phone: payload.phone,
            paymentMethod: payload.paymentMethod,
            notes: payload.notes,
          }),
        },
        currentDocument: { exists: false },
      });

      writes.push({
        transform: {
          document: orderDocName,
          fieldTransforms: [
            {
              fieldPath: "createdAt",
              setToServerValue: "REQUEST_TIME",
            },
          ],
        },
      });

      for (const [docName, patch] of stockPatchesByDocName.entries()) {
        writes.push({
          update: {
            name: docName,
            fields: toFirestoreFields(patch.fields),
          },
          updateMask: {
            fieldPaths: patch.fieldPaths,
          },
        });
      }

      writes.push({
        update: {
          name: idempotencyDocName,
          fields: toFirestoreFields({
            uid,
            key: payload.idempotencyKey,
            orderId,
            orderCode,
            status: "pending",
            stockDeducted: true,
            orderSource: payload.orderSource,
            attributionMetadata: payload.attributionMetadata,
            shippingZoneCode: shippingZone.code,
            payloadHash: payload.payloadHash,
          }),
        },
        currentDocument: { exists: false },
      });

      writes.push({
        update: {
          name: orderCodeDocName,
          fields: toFirestoreFields({
            orderId,
            uid,
            prefix: ORDER_CODE_PREFIX,
            source: ORDER_CODE_SOURCE,
          }),
        },
        currentDocument: { exists: false },
      });

      writes.push({
        transform: {
          document: orderCodeDocName,
          fieldTransforms: [
            {
              fieldPath: "createdAt",
              setToServerValue: "REQUEST_TIME",
            },
          ],
        },
      });

      writes.push({
        transform: {
          document: idempotencyDocName,
          fieldTransforms: [
            {
              fieldPath: "createdAt",
              setToServerValue: "REQUEST_TIME",
            },
          ],
        },
      });

      if (payload.orderSource === "restock_alert") {
        for (const item of orderItems) {
          const eventId = crypto.randomUUID();
          const eventDocName = firestoreDocName(projectId, "events", eventId);
          writes.push({
            update: {
              name: eventDocName,
              fields: toFirestoreFields({
                id: eventId,
                userId: uid,
                eventType: "restock_purchased",
                data: {
                  productId: item.productId,
                  variantId: item.variantId,
                  orderId,
                  revenue: item.priceSnapshot * item.quantity,
                },
              }),
            },
            currentDocument: { exists: false },
          });
          writes.push({
            transform: {
              document: eventDocName,
              fieldTransforms: [
                { fieldPath: "timestamp", setToServerValue: "REQUEST_TIME" },
              ],
            },
          });
        }
      }

      if (restockRequestDocName) {
        const requestDoc = docs.found.get(restockRequestDocName);
        const requestData = requestDoc ? decodeFirestoreDocument(requestDoc) : null;
        const conversionPatch = buildRestockConversionPatch({
          orderSource: payload.orderSource,
          attributionMetadata: payload.attributionMetadata,
          requestData,
          uid,
          orderId,
          requestedProductIds: new Set(productIds),
        });

        if (conversionPatch) {
          writes.push({
            update: {
              name: restockRequestDocName,
              fields: toFirestoreFields({
                status: "converted",
                orderId: conversionPatch.orderId,
              }),
            },
            updateMask: { fieldPaths: ["status", "orderId"] },
          });
          writes.push({
            transform: {
              document: restockRequestDocName,
              fieldTransforms: [
                { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
                { fieldPath: "convertedAt", setToServerValue: "REQUEST_TIME" },
              ],
            },
          });

          const conversionEventId = crypto.randomUUID();
          const conversionEventDocName = firestoreDocName(
            projectId,
            "events",
            conversionEventId,
          );
          const conversionEvent = buildRestockConversionSuccessEvent({
            eventId: conversionEventId,
            uid,
            conversionPatch,
          });
          writes.push({
            update: {
              name: conversionEventDocName,
              fields: toFirestoreFields(conversionEvent),
            },
            currentDocument: { exists: false },
          });
          writes.push({
            transform: {
              document: conversionEventDocName,
              fieldTransforms: [
                { fieldPath: "timestamp", setToServerValue: "REQUEST_TIME" },
              ],
            },
          });
        }
      }

      await commitTransaction(env, transaction, writes);
      committed = true;

      return {
        ok: true,
        idempotent: false,
        orderId,
        orderCode,
        status: "pending",
        stockDeducted: true,
      };
    } catch (error) {
      if (!committed) {
        await rollbackTransaction(env, transaction);
      }

      if (attempt < MAX_TRANSACTION_RETRIES && isRetryableCreateOrderError(error, orderCode)) {
        await sleep(40 * attempt);
        continue;
      }

      throw error;
    }
  }

  throw createApiError(503, "Could not complete order transaction after retries");
}
