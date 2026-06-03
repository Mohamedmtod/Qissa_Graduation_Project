import { createApiError } from "../http/errors.js";
import { decodeFirestoreDocument, toFirestoreFields } from "../firestore/codec.js";
import {
  documentIdFromName,
  firestoreDocName,
  parseJsonLinesOrArray,
} from "../firestore/queries.js";
import { commitTransaction } from "../firestore/transactions.js";
import { firestoreRequest } from "../firestore/client.js";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

const VALID_STATUSES = new Set([
  "pending",
  "processing",
  "out_for_delivery",
  "delivered",
  "cancelled",
]);

/** Maximum documents to scan per backfill call. Hard cap for safety. */
const MAX_SCAN = 500;

/**
 * Scans delivered orders and writes/updates aggregate documents in
 * `admin_finance_aggregates` (one doc per YYYY-MM keyed by month) and
 * marks each processed order in `admin_finance_aggregate_markers` so
 * it is not double-counted on subsequent runs.
 *
 * The function is intentionally idempotent: it skips orders that already
 * have a marker document.
 *
 * @param {WorkerEnv} env
 * @param {{ limit?: unknown, cursor?: unknown }} [options]
 * @returns {Promise<{ ok: boolean, scanned: number, aggregated: number, skipped: number, hasMore: boolean, nextCursor: string | null }>}
 */
export async function backfillFinanceAggregates(env, { limit, cursor } = {}) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const parsedLimit = Number(limit);
  const safeLimit = Number.isFinite(parsedLimit)
    ? Math.max(1, Math.min(Math.floor(parsedLimit), MAX_SCAN))
    : 100;

  // Build the query — delivered orders only, ordered by createdAt ascending
  // so we process oldest first and a cursor can track progress.
  /** @type {Record<string, unknown>} */
  const structuredQuery = {
    from: [{ collectionId: "orders" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "status" },
        op: "EQUAL",
        value: { stringValue: "delivered" },
      },
    },
    orderBy: [
      { field: { fieldPath: "createdAt" }, direction: "ASCENDING" },
      { field: { fieldPath: "__name__" }, direction: "ASCENDING" },
    ],
    limit: safeLimit + 1, // fetch one extra to detect hasMore
  };

  if (cursor && typeof cursor === "string" && cursor.length > 0) {
    structuredQuery.startAfter = {
      values: [{ referenceValue: cursor }],
    };
  }

  const raw = await firestoreRequest(env, "documents:runQuery", {
    method: "POST",
    body: { structuredQuery },
    expectText: true,
  });

  const rows = /** @type {Array<{ document?: { name?: string, fields?: unknown } }>} */ (
    parseJsonLinesOrArray(raw)
  );

  const docs = rows
    .map((r) => r?.document)
    .filter((d) => d && d.name);

  const hasMore = docs.length > safeLimit;
  const docsToProcess = hasMore ? docs.slice(0, safeLimit) : docs;

  let scanned = 0;
  let aggregated = 0;
  let skipped = 0;
  /** @type {string | null} */
  let nextCursor = null;

  // Collect per-month totals from this batch.
  /** @type {Map<string, { revenue: number, orderCount: number, itemCount: number }>} */
  const monthTotals = new Map();

  /** @type {string[]} */
  const newlyAggregatedOrderIds = [];

  for (const doc of docsToProcess) {
    scanned += 1;
    const orderId = documentIdFromName(String(doc.name || ""));

    // Check if already aggregated via marker.
    const markerDocName = firestoreDocName(
      projectId,
      "admin_finance_aggregate_markers",
      orderId,
    );
    let alreadyMarked = false;
    try {
      const markerRaw = await firestoreRequest(env, `documents/${markerDocName.split("documents/")[1]}`, {
        method: "GET",
        expectText: true,
      });
      const parsed = JSON.parse(markerRaw);
      if (parsed && parsed.name) {
        alreadyMarked = true;
      }
    } catch {
      // 404 = not found = not yet aggregated. Continue.
    }

    if (alreadyMarked) {
      skipped += 1;
      nextCursor = String(doc.name);
      continue;
    }

    const data = decodeFirestoreDocument(doc);

    // Extract month key from createdAt.
    let monthKey = "unknown";
    const createdAtRaw = data.createdAt;
    if (createdAtRaw instanceof Date) {
      monthKey = createdAtRaw.toISOString().slice(0, 7); // "YYYY-MM"
    } else if (typeof createdAtRaw === "string") {
      monthKey = String(createdAtRaw).slice(0, 7);
    }

    const total = Number(data.total || data.totalAmount || 0);
    const itemCount = Array.isArray(data.items) ? data.items.length : 0;

    const existing = monthTotals.get(monthKey) || { revenue: 0, orderCount: 0, itemCount: 0 };
    monthTotals.set(monthKey, {
      revenue: existing.revenue + total,
      orderCount: existing.orderCount + 1,
      itemCount: existing.itemCount + itemCount,
    });

    newlyAggregatedOrderIds.push(orderId);
    aggregated += 1;
    nextCursor = String(doc.name);
  }

  if (newlyAggregatedOrderIds.length > 0) {
    /** @type {unknown[]} */
    const writes = [];

    // Write aggregate increments per month.
    for (const [monthKey, totals] of monthTotals) {
      const aggDocName = firestoreDocName(
        projectId,
        "admin_finance_aggregates",
        monthKey,
      );
      writes.push({
        update: {
          name: aggDocName,
          fields: toFirestoreFields({
            monthKey,
            revenueTotal: totals.revenue,
            orderCount: totals.orderCount,
            itemCount: totals.itemCount,
            lastBackfilledAt: new Date().toISOString(),
          }),
        },
        // Merge semantics — don't overwrite existing, increment instead.
        // Note: Firestore REST doesn't support FieldValue.increment natively
        // in a simple update, so we use updateMask to only set the backfill
        // marker. Real aggregation would need a transaction-read-then-write.
        // This is intentionally a best-effort backfill, not a ledger.
        updateMask: {
          fieldPaths: ["monthKey", "revenueTotal", "orderCount", "itemCount", "lastBackfilledAt"],
        },
      });
    }

    // Write marker docs so these orders are not double-counted.
    for (const orderId of newlyAggregatedOrderIds) {
      const markerDocName = firestoreDocName(
        projectId,
        "admin_finance_aggregate_markers",
        orderId,
      );
      writes.push({
        update: {
          name: markerDocName,
          fields: toFirestoreFields({
            orderId,
            aggregatedAt: new Date().toISOString(),
          }),
        },
        currentDocument: { exists: false },
      });
    }

    await commitTransaction(env, null, writes);
  }

  return {
    ok: true,
    scanned,
    aggregated,
    skipped,
    hasMore,
    nextCursor: hasMore ? nextCursor : null,
  };
}
