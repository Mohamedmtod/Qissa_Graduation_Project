import { createApiError } from "../http/errors.js";
import { decodeFirestoreDocument } from "./codec.js";
import { firestoreRequest } from "./client.js";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

/** @typedef {import("./codec.js").FirestoreValue} FirestoreValue */

/**
 * @typedef {{ name?: string, fields?: Record<string, FirestoreValue> }} FirestoreDocumentLike
 */

/**
 * @typedef {{ found?: FirestoreDocumentLike, missing?: string }} BatchGetRow
 */

/**
 * @param {unknown} rawText
 * @returns {unknown[]}
 */
export function parseJsonLinesOrArray(rawText) {
  const trimmed = String(rawText || "").trim();
  if (!trimmed) return [];

  try {
    const parsed = JSON.parse(trimmed);
    if (Array.isArray(parsed)) return parsed;
    if (parsed && typeof parsed === "object") return [parsed];
  } catch {
    // Firestore streaming APIs may return JSON lines.
  }

  return trimmed
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => JSON.parse(line));
}

/**
 * @param {string} name
 */
export function documentIdFromName(name) {
  const segments = String(name || "").split("/");
  return segments[segments.length - 1] || "";
}

/**
 * @param {string} projectId
 * @param {...string} segments
 */
export function firestoreDocName(projectId, ...segments) {
  return `projects/${projectId}/databases/(default)/documents/${segments.join("/")}`;
}

/**
 * @param {unknown} rawText
 */
export function parseBatchGetResponse(rawText) {
  /** @type {Map<string, FirestoreDocumentLike>} */
  const found = new Map();
  /** @type {Set<string>} */
  const missing = new Set();

  const lines = /** @type {BatchGetRow[]} */ (parseJsonLinesOrArray(rawText));

  for (const row of lines) {
    if (row.found?.name) {
      found.set(row.found.name, row.found);
    } else if (row.missing) {
      missing.add(row.missing);
    }
  }

  return { found, missing };
}

/**
 * @param {WorkerEnv} env
 * @param {string[]} documentNames
 * @param {string | null | undefined} transaction
 */
export async function batchGetDocuments(env, documentNames, transaction) {
  const raw = await firestoreRequest(env, "documents:batchGet", {
    method: "POST",
    body: {
      documents: documentNames,
      transaction,
    },
    expectText: true,
  });
  return parseBatchGetResponse(raw);
}

/**
 * @param {WorkerEnv} env
 * @param {Record<string, unknown>} structuredQuery
 * @param {string | null} [transaction=null]
 * @returns {Promise<FirestoreDocumentLike[]>}
 */
export async function queryDocuments(env, structuredQuery, transaction = null) {
  /** @type {{ structuredQuery: Record<string, unknown>, transaction?: string }} */
  const body = { structuredQuery };
  if (transaction) {
    body.transaction = transaction;
  }

  const raw = await firestoreRequest(env, "documents:runQuery", {
    method: "POST",
    body,
    expectText: true,
  });

  const rows = /** @type {Array<{ document?: FirestoreDocumentLike }>} */ (parseJsonLinesOrArray(raw));
  /** @type {FirestoreDocumentLike[]} */
  const documents = [];
  for (const row of rows) {
    if (row?.document?.name) {
      documents.push(row.document);
    }
  }
  return documents;
}

/**
 * @param {WorkerEnv} env
 * @param {string} uid
 * @param {{ limit?: number }} [options]
 */
export async function listMyOrders(env, uid, { limit = 20 } = {}) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const parsedLimit = Number(limit);
  const safeLimit = Number.isFinite(parsedLimit)
    ? Math.max(1, Math.min(Math.floor(parsedLimit), 50))
    : 20;

  const raw = await firestoreRequest(env, "documents:runQuery", {
    method: "POST",
    body: {
      structuredQuery: {
        from: [{ collectionId: "orders" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "userId" },
            op: "EQUAL",
            value: { stringValue: uid },
          },
        },
        orderBy: [
          {
            field: { fieldPath: "createdAt" },
            direction: "DESCENDING",
          },
        ],
        limit: safeLimit,
      },
    },
    expectText: true,
  });

  const rows = /** @type {Array<{ document?: FirestoreDocumentLike }>} */ (parseJsonLinesOrArray(raw));
  /** @type {Array<Record<string, unknown>>} */
  const orders = [];

  for (const row of rows) {
    if (!row?.document?.name) continue;
    const doc = row.document;
    const decoded = decodeFirestoreDocument(doc);
    orders.push({
      id: documentIdFromName(String(doc.name || "")),
      ...decoded,
    });
  }

  return {
    ok: true,
    count: orders.length,
    limit: safeLimit,
    orders,
  };
}
