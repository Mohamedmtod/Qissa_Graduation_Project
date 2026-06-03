import { MAX_TRANSACTION_RETRIES } from "../constants/index.js";
import { createApiError } from "../http/errors.js";
import { decodeFirestoreDocument, toFirestoreFields } from "../firestore/codec.js";
import {
  batchGetDocuments,
  firestoreDocName,
  queryDocuments,
} from "../firestore/queries.js";
import {
  beginTransaction,
  commitTransaction,
  rollbackTransaction,
  isRetryableTransactionError,
  sleep,
} from "../firestore/transactions.js";
import {
  buildRestockCancellationPatch,
  buildRestockLostOpportunityMarkedEvent,
  isLostOpportunityCandidate,
} from "./events.js";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

/** @typedef {import("../firestore/codec.js").FirestoreDocumentLike & { name?: string }} FirestoreDocumentLike */

/**
 * @param {WorkerEnv} env
 * @param {string} adminUid
 * @param {string} productId
 * @param {number} delta
 * @param {string} traceId
 * @param {string[]} [requestIds=[]]
 */
export async function restockProductByAdminAtomically(
  env,
  adminUid,
  productId,
  delta,
  traceId,
  requestIds = [],
) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }
  if (!Number.isInteger(delta) || delta === 0) {
    throw createApiError(400, "delta must be a non-zero integer");
  }

  const productDocName = firestoreDocName(projectId, "products", productId);
  const normalizedRequestIds = [...new Set(
    (Array.isArray(requestIds) ? requestIds : [])
      .map((value) => String(value || "").trim())
      .filter((value) => value.length > 0),
  )];

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;

    try {
      transaction = await beginTransaction(env);

      const productDocs = await batchGetDocuments(env, [productDocName], transaction);
      const productDoc = productDocs.found.get(productDocName);
      if (!productDoc) {
        throw createApiError(404, `Product '${productId}' not found`);
      }

      const productData = decodeFirestoreDocument(productDoc);
      const currentStock = Number(productData.stock || 0);
      const nextStock = currentStock + delta;
      if (nextStock < 0) {
        throw createApiError(
          409,
          `Inventory adjustment would make stock negative for product '${productId}'`,
        );
      }

      /** @type {any[]} */
      const writes = [
        {
          update: {
            name: productDocName,
            fields: toFirestoreFields({
              stock: nextStock,
            }),
          },
          updateMask: { fieldPaths: ["stock"] },
        },
        {
          transform: {
            document: productDocName,
            fieldTransforms: [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }],
          },
        },
      ];

      let notifiedCount = 0;
      /** @type {FirestoreDocumentLike[]} */
      let requestDocs = [];

      if (delta > 0) {
        if (normalizedRequestIds.length > 0) {
          const requestDocNames = normalizedRequestIds.map((requestId) =>
            firestoreDocName(projectId, "restock_requests", requestId),
          );
          const requestBatch = await batchGetDocuments(env, requestDocNames, transaction);
          requestDocs = /** @type {FirestoreDocumentLike[]} */ (
            requestDocNames
              .map((docName) => requestBatch.found.get(docName))
              .filter((doc) => Boolean(doc))
              .filter((doc) => {
                const requestDoc = /** @type {FirestoreDocumentLike} */ (doc);
                const data = decodeFirestoreDocument(requestDoc);
                return data.productId === productId && data.status === "pending";
              })
          );
        } else {
          requestDocs = await queryDocuments(
            env,
            {
              from: [{ collectionId: "restock_requests" }],
              where: {
                compositeFilter: {
                  op: "AND",
                  filters: [
                    {
                      fieldFilter: {
                        field: { fieldPath: "productId" },
                        op: "EQUAL",
                        value: { stringValue: productId },
                      },
                    },
                    {
                      fieldFilter: {
                        field: { fieldPath: "status" },
                        op: "EQUAL",
                        value: { stringValue: "pending" },
                      },
                    },
                  ],
                },
              },
            },
            transaction,
          );
        }

        for (const requestDoc of requestDocs) {
          const requestData = decodeFirestoreDocument(requestDoc);
          if (requestData.productId !== productId || requestData.status !== "pending") {
            continue;
          }

          const requestDocName = String(requestDoc.name || "");
          if (!requestDocName) {
            continue;
          }

          writes.push({
            update: {
              name: requestDocName,
              fields: toFirestoreFields({
                status: "notified",
              }),
            },
            updateMask: { fieldPaths: ["status"] },
          });
          writes.push({
            transform: {
              document: requestDocName,
              fieldTransforms: [
                { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
                { fieldPath: "notifiedAt", setToServerValue: "REQUEST_TIME" },
              ],
            },
          });
          notifiedCount += 1;
        }

        const eventId = crypto.randomUUID();
        const eventDocName = firestoreDocName(projectId, "events", eventId);
        writes.push({
          update: {
            name: eventDocName,
            fields: toFirestoreFields({
              id: eventId,
              userId: adminUid,
              eventType: "restock_notified",
              data: {
                productId,
                usersNotifiedCount: notifiedCount,
                traceId,
              },
            }),
          },
          currentDocument: { exists: false },
        });
        writes.push({
          transform: {
            document: eventDocName,
            fieldTransforms: [{ fieldPath: "timestamp", setToServerValue: "REQUEST_TIME" }],
          },
        });
      }

      await commitTransaction(env, transaction, writes);
      committed = true;

      return {
        ok: true,
        productId,
        stock: nextStock,
        delta,
        notifiedCount,
        updatedBy: adminUid,
      };
    } catch (error) {
      console.error("admin_restock_transaction_attempt_failed", {
        traceId,
        productId,
        adminUid,
        attempt,
        maxRetries: MAX_TRANSACTION_RETRIES,
        retryable: isRetryableTransactionError(error),
        message: error instanceof Error ? error.message : String(error),
      });
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

  throw createApiError(503, "Could not complete restock transaction after retries");
}

/**
 * @param {WorkerEnv} env
 * @param {string} uid
 * @param {string} requestId
 */
export async function cancelRestockRequestByUserAtomically(env, uid, requestId) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const restockRequestDocName = firestoreDocName(projectId, "restock_requests", requestId);

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;

    try {
      transaction = await beginTransaction(env);
      const docs = await batchGetDocuments(env, [restockRequestDocName], transaction);
      const requestDoc = docs.found.get(restockRequestDocName);
      if (!requestDoc) {
        throw createApiError(404, `Restock request '${requestId}' not found`);
      }

      const requestData = decodeFirestoreDocument(requestDoc);
      const cancellationPatch = buildRestockCancellationPatch({
        requestData,
        uid,
        requestId,
      });

      if (!cancellationPatch) {
        throw createApiError(
          409,
          "Restock request is not cancellable (must be owned by user and still pending)",
        );
      }

      const writes = [
        {
          update: {
            name: restockRequestDocName,
            fields: toFirestoreFields({
              status: "cancelled",
            }),
          },
          updateMask: { fieldPaths: ["status"] },
        },
        {
          transform: {
            document: restockRequestDocName,
            fieldTransforms: [
              { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
              { fieldPath: "cancelledAt", setToServerValue: "REQUEST_TIME" },
            ],
          },
        },
      ];

      await commitTransaction(env, transaction, writes);
      committed = true;

      return {
        ok: true,
        requestId,
        status: "cancelled",
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

  throw createApiError(503, "Could not complete restock cancel transaction after retries");
}

/**
 * @param {WorkerEnv} env
 * @param {{ cutoffHours?: number, limit?: number }} [options]
 */
export async function markLostRestockOpportunities(
  env,
  { cutoffHours = 48, limit = 400 } = {},
) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const safeHours = Number.isFinite(Number(cutoffHours))
    ? Math.max(1, Math.floor(Number(cutoffHours)))
    : 48;
  const safeLimit = Number.isFinite(Number(limit))
    ? Math.max(1, Math.min(Math.floor(Number(limit)), 400))
    : 400;

  const cutoffDate = new Date(Date.now() - safeHours * 60 * 60 * 1000);

  const staleNotifiedDocs = await queryDocuments(env, {
    from: [{ collectionId: "restock_requests" }],
    where: {
      compositeFilter: {
        op: "AND",
        filters: [
          {
            fieldFilter: {
              field: { fieldPath: "status" },
              op: "EQUAL",
              value: { stringValue: "notified" },
            },
          },
          {
            fieldFilter: {
              field: { fieldPath: "notifiedAt" },
              op: "LESS_THAN_OR_EQUAL",
              value: { timestampValue: cutoffDate.toISOString() },
            },
          },
        ],
      },
    },
    orderBy: [
      {
        field: { fieldPath: "notifiedAt" },
        direction: "ASCENDING",
      },
    ],
    limit: safeLimit,
  });

  /** @type {any[]} */
  const writes = [];
  let markedCount = 0;

  for (const doc of staleNotifiedDocs) {
    const data = decodeFirestoreDocument(doc);
    if (!isLostOpportunityCandidate({ requestData: data, cutoffDate })) continue;

    writes.push({
      update: {
        name: doc.name,
        fields: toFirestoreFields({
          cohortLabel: "lost_opportunity",
        }),
      },
      updateMask: { fieldPaths: ["cohortLabel"] },
    });
    writes.push({
      transform: {
        document: doc.name,
        fieldTransforms: [
          { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
          { fieldPath: "lostOpportunityAt", setToServerValue: "REQUEST_TIME" },
        ],
      },
    });

    markedCount += 1;
  }

  if (markedCount > 0) {
    const eventId = crypto.randomUUID();
    const eventDocName = firestoreDocName(projectId, "events", eventId);
    const eventData = buildRestockLostOpportunityMarkedEvent({
      eventId,
      markedCount,
      inspectedCount: staleNotifiedDocs.length,
      cutoffHours: safeHours,
    });
    writes.push({
      update: {
        name: eventDocName,
        fields: toFirestoreFields(eventData),
      },
      currentDocument: { exists: false },
    });
    writes.push({
      transform: {
        document: eventDocName,
        fieldTransforms: [{ fieldPath: "timestamp", setToServerValue: "REQUEST_TIME" }],
      },
    });
  }

  if (writes.length > 0) {
    await commitTransaction(env, null, writes);
  }

  return {
    ok: true,
    cutoffHours: safeHours,
    inspectedCount: staleNotifiedDocs.length,
    markedCount,
  };
}
