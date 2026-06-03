import { firestoreRequest } from "../firestore/client.js";
import { decodeFirestoreDocument, toFirestoreFields } from "../firestore/codec.js";
import { getNextSequenceCode } from "../shared/saleCode.js";
import { beginTransaction, commitTransaction, rollbackTransaction } from "../firestore/transactions.js";
import { createApiError } from "../http/errors.js";
import { validateSalePayload, validateItemQuantity, validateSessionOwnership } from "./validateSalePayload.js";

const firestoreDocName = (projectId, collection, id) =>
  `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;

/**
 * Executes a POS sale transaction atomically.
 * @param {any} env
 * @param {string} cashierUid
 * @param {any} payload
 */
export async function createPosSaleAtomically(env, cashierUid, payload) {
  const { idempotencyKey, sessionId, items = [], paymentMethod = "cash", notes = "" } = payload;
  const projectId = env.FIREBASE_PROJECT_ID;

  // Validate payload before any Firestore work
  validateSalePayload({ idempotencyKey, sessionId, items, paymentMethod });

  // 1. Check idempotency cache first (outside transaction, fast path)
  try {
    const cachedDoc = await firestoreRequest(env, `documents/pos_idempotency/${idempotencyKey}`);
    const decoded = decodeFirestoreDocument(cachedDoc);
    if (decoded.response) {
      console.log("pos_sale_idempotency_hit", { idempotencyKey });
      return decoded.response;
    }
  } catch (error) {
    if (error.status !== 404) throw error;
  }

  let transaction = null;
  try {
    transaction = await beginTransaction(env);

    // Lock/Verify idempotency key again inside transaction
    let cacheExists = false;
    try {
      await firestoreRequest(env, `documents/pos_idempotency/${idempotencyKey}?transaction=${encodeURIComponent(transaction)}`);
      cacheExists = true;
    } catch (e) {
      if (e.status !== 404) throw e;
    }
    if (cacheExists) {
      throw createApiError(409, "Duplicate request in progress");
    }

    // 2. Fetch and validate cash session
    let sessionData;
    const sessionDocPath = `documents/pos_cash_sessions/${sessionId}`;
    try {
      const rawSession = await firestoreRequest(env, `${sessionDocPath}?transaction=${encodeURIComponent(transaction)}`);
      sessionData = decodeFirestoreDocument(rawSession);
    } catch (error) {
      if (error.status === 404) {
        throw createApiError(404, `Cash session ${sessionId} not found`);
      }
      throw error;
    }

    if (sessionData.status !== "open") {
      throw createApiError(400, `Cash session ${sessionId} is already closed`);
    }

    // P0: session ownership — cashier can only sell against their own session
    validateSessionOwnership(sessionData, cashierUid, sessionId);

    // 3. Process items, check stock, and compile sub-totals
    let totalAmount = 0;
    const productUpdates = new Map(); // productId -> updated doc payload
    const stockMovements = [];
    const conflicts = [];
    const fetchedProducts = new Map(); // productId -> productData

    // Group items by product + variant to validate combined quantity correctly
    const quantityMap = new Map();
    for (const cartItem of items) {
      const { productId, variantId, quantity } = cartItem;
      const qty = validateItemQuantity(productId, quantity);
      const key = `${productId}:${variantId}`;
      if (quantityMap.has(key)) {
        quantityMap.get(key).quantity += qty;
      } else {
        quantityMap.set(key, { productId, variantId, quantity: qty });
      }
    }

    // Pass 1: Fetch and validate stock for all unique items
    for (const [_, req] of quantityMap.entries()) {
      const { productId, variantId, quantity: qty } = req;

      let productDoc;
      try {
        productDoc = await firestoreRequest(env, `documents/products/${productId}?transaction=${encodeURIComponent(transaction)}`);
      } catch (error) {
        if (error.status === 404) {
          throw createApiError(404, `Product ${productId} not found`);
        }
        throw error;
      }
      const productData = decodeFirestoreDocument(productDoc);
      fetchedProducts.set(productId, productData);

      // Check if product is active
      if (productData.isActive === false) {
        throw createApiError(400, `Product ${productData.name} is inactive and cannot be sold`);
      }

      // Check if product is sellable
      if (productData.isSellable === false) {
        throw createApiError(400, `Product ${productData.name} is raw material and not sellable directly`);
      }

      // P0/P1: composite products — block until recipe resolver is fully implemented
      if (productData.productType === "composite") {
        throw createApiError(400, `COMPOSITE_NOT_SUPPORTED: Composite product "${productData.name}" cannot be sold at POS yet. Please contact your manager.`);
      }

      const hasVariants = Array.isArray(productData.variants) && productData.variants.length > 0;
      const variants = hasVariants
        ? productData.variants
        : [
            {
              id: "default",
              label: productData.size || "",
              price: Number(productData.price || 0),
              salePrice: productData.salePrice !== undefined ? Number(productData.salePrice) : undefined,
              costPrice: productData.costPrice !== undefined ? Number(productData.costPrice) : undefined,
              unitType: productData.unitType || "piece",
              stock: Number(productData.stock !== undefined ? productData.stock : (productData.units || 0)),
              isActive: productData.isActive !== false,
            }
          ];

      const varIndex = variants.findIndex(v => v.id === variantId);
      if (varIndex === -1) {
        throw createApiError(404, `Variant ${variantId} of product ${productData.name} not found`);
      }

      const variant = variants[varIndex];
      // Check if variant is active
      if (variant.isActive === false) {
        throw createApiError(400, `Variant ${variant.label || variantId} of product ${productData.name} is inactive and cannot be sold`);
      }
      if (variant.stock < qty) {
        conflicts.push({
          productId,
          variantId,
          requestedQuantity: qty,
          availableStock: variant.stock,
          unitType: variant.unitType || "piece",
          productName: productData.name,
          variantLabel: variant.label || "",
        });
      }
    }

    if (conflicts.length > 0) {
      throw createApiError(400, "STOCK_CONFLICT", conflicts);
    }

    // Pass 2: Deduct stock and prepare writes
    for (const cartItem of items) {
      const { productId, variantId, quantity } = cartItem;
      const qty = Number(quantity);

      const productData = fetchedProducts.get(productId);
      const hasVariants = Array.isArray(productData.variants) && productData.variants.length > 0;
      const variants = hasVariants
        ? productData.variants
        : [
            {
              id: "default",
              label: productData.size || "",
              price: Number(productData.price || 0),
              salePrice: productData.salePrice !== undefined ? Number(productData.salePrice) : undefined,
              costPrice: productData.costPrice !== undefined ? Number(productData.costPrice) : undefined,
              unitType: productData.unitType || "piece",
              stock: Number(productData.stock !== undefined ? productData.stock : (productData.units || 0)),
              isActive: productData.isActive !== false,
            }
          ];

      const varIndex = variants.findIndex(v => v.id === variantId);
      const variant = variants[varIndex];

      const unitPrice = variant.salePrice !== undefined && variant.salePrice > 0 ? variant.salePrice : variant.price;
      const itemSubtotal = unitPrice * qty;
      totalAmount += itemSubtotal;

      // Update variant stock
      variant.stock = Number((variant.stock - qty).toFixed(3));
      
      if (hasVariants) {
        productData.variants[varIndex] = variant;
        productData.stock = productData.variants.reduce((acc, v) => acc + v.stock, 0);
        productData.units = productData.stock;
      } else {
        productData.stock = variant.stock;
        productData.units = variant.stock;
      }

      productUpdates.set(productId, productData);

      stockMovements.push({
        id: FirebaseFirestoreId(),
        productId,
        variantId,
        type: "sale",
        quantityDelta: -qty,
        unitPrice,
        timestamp: new Date().toISOString(),
        cashierUid,
        sessionId,
      });
    }

    // 4. Generate Sale sequence code POS-YYYY-XXXXXX
    const { code: saleCode, writeDescriptor: seqWrite } = await getNextSequenceCode(env, transaction, "sale");

    // 5. Update cash session aggregates
    const nextSalesCount = Number(sessionData.totalSalesCount || 0) + 1;
    const nextExpectedCash = Number(sessionData.expectedCash || 0) + (paymentMethod === "cash" ? totalAmount : 0);
    const nextExpectedCard = Number(sessionData.expectedCard || 0) + (paymentMethod === "card" ? totalAmount : 0);

    const updatedSession = {
      ...sessionData,
      totalSalesCount: nextSalesCount,
      expectedCash: nextExpectedCash,
      expectedCard: nextExpectedCard,
      updatedAt: new Date().toISOString(),
    };

    // 6. Build the writes array for Firestore commit
    // Counter update must be part of the commit (not a standalone PATCH).
    const writes = [seqWrite];

    for (const [prodId, data] of productUpdates.entries()) {
      writes.push({
        update: {
          name: firestoreDocName(projectId, "products", prodId),
          fields: toFirestoreFields(data),
        },
      });
    }

    for (const mov of stockMovements) {
      writes.push({
        update: {
          name: firestoreDocName(projectId, "stock_movements", mov.id),
          fields: toFirestoreFields(mov),
        },
      });
    }

    writes.push({
      update: {
        name: firestoreDocName(projectId, "pos_cash_sessions", sessionId),
        fields: toFirestoreFields(updatedSession),
      },
    });

    const saleId = FirebaseFirestoreId();
    // Build server-calculated item snapshots (price always from server, never from client)
    const itemSnapshots = [];
    for (const cartItem of items) {
      const snapQty = Number(cartItem.quantity);
      const snapProd = productUpdates.get(cartItem.productId);
      // Retrieve the variant price from the update map if available
      const snapVariants = snapProd && Array.isArray(snapProd.variants) && snapProd.variants.length > 0
        ? snapProd.variants
        : snapProd ? [{ id: "default", price: Number(snapProd.price || 0), salePrice: snapProd.salePrice !== undefined ? Number(snapProd.salePrice) : undefined }] : [];
      const snapVariant = snapVariants.find(v => v.id === cartItem.variantId);
      const snapUnitPrice = snapVariant
        ? (snapVariant.salePrice !== undefined && snapVariant.salePrice > 0 ? snapVariant.salePrice : snapVariant.price)
        : 0;
      itemSnapshots.push({
        productId: cartItem.productId,
        variantId: cartItem.variantId,
        productName: snapProd ? snapProd.name : "Unknown Product",
        variantLabel: snapVariant ? snapVariant.label : "",
        quantity: snapQty,
        unitPrice: snapUnitPrice,
        lineTotal: Number((snapUnitPrice * snapQty).toFixed(2)),
      });
    }

    const saleDoc = {
      id: saleId,
      saleCode,
      sessionId,
      cashierUid,
      items: itemSnapshots,
      totalAmount,
      paymentMethod,
      notes,
      createdAt: new Date().toISOString(),
    };
    writes.push({
      update: {
        name: firestoreDocName(projectId, "pos_sales", saleId),
        fields: toFirestoreFields(saleDoc),
      },
    });

    const invoiceResponse = {
      ok: true,
      saleId,
      saleCode,
      totalAmount,
      paymentMethod,
    };
    const idempotencyDoc = {
      id: idempotencyKey,
      response: invoiceResponse,
      createdAt: new Date().toISOString(),
    };
    writes.push({
      update: {
        name: firestoreDocName(projectId, "pos_idempotency", idempotencyKey),
        fields: toFirestoreFields(idempotencyDoc),
      },
    });

    // Commit transaction
    await commitTransaction(env, transaction, writes);

    return invoiceResponse;
  } catch (error) {
    if (transaction) {
      await rollbackTransaction(env, transaction);
    }
    throw error;
  }
}

function FirebaseFirestoreId() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let autoId = "";
  for (let i = 0; i < 20; i++) {
    autoId += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return autoId;
}
