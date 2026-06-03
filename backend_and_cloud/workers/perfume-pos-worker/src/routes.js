import { requireUser } from "./auth/require-user.js";
import { json } from "./http/responses.js";
import { createApiError } from "./http/errors.js";
import { firestoreRequest } from "./firestore/client.js";
import { decodeFirestoreDocument, toFirestoreFields } from "./firestore/codec.js";
import { beginTransaction, commitTransaction, rollbackTransaction } from "./firestore/transactions.js";
import { getNextSequenceCode } from "./shared/saleCode.js";
import { createPosSaleAtomically } from "./sales/createPosSale.js";

const firestoreDocName = (projectId, collection, id) =>
  `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;

function FirebaseFirestoreId() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let autoId = "";
  for (let i = 0; i < 20; i++) {
    autoId += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return autoId;
}

/**
 * Handle incoming POS routes.
 * @param {Request} request
 * @param {any} env
 * @param {string} origin
 */
export async function handlePosRoutes(request, env, origin) {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method.toUpperCase();

  // Authentication routes check
  if (path.startsWith("/pos/")) {
    const authContext = await requireUser(request, env, origin);
    if (authContext.response) return authContext.response;

    const { uid, isCashier, isAdmin } = authContext.auth;

    if (!isCashier && !isAdmin) {
      return json({ error: "Forbidden: Cashier or Admin privileges required" }, 403, origin);
    }

    // 1. POST /pos/cash-sessions/open
    if (method === "POST" && path === "/pos/cash-sessions/open") {
      const body = await request.json().catch(() => ({}));
      const openingCash = Number(body.openingCash || 0);
      const notes = String(body.notes || "").trim();

      let transaction = null;
      try {
        transaction = await beginTransaction(env);

        // Check if there is already an active session for this cashier
        const currentQuery = {
          structuredQuery: {
            from: [{ collectionId: "pos_cash_sessions" }],
            where: {
              compositeFilter: {
                op: "AND",
                filters: [
                  {
                    fieldFilter: {
                      field: { fieldPath: "openedBy" },
                      op: "EQUAL",
                      value: { stringValue: uid },
                    },
                  },
                  {
                    fieldFilter: {
                      field: { fieldPath: "status" },
                      op: "EQUAL",
                      value: { stringValue: "open" },
                    },
                  },
                ],
              },
            },
            limit: 1,
          },
        };

        const existing = await firestoreRequest(env, "documents:runQuery", {
          method: "POST",
          body: currentQuery,
        });

        const activeDoc = Array.isArray(existing) ? existing.find(d => d.document) : null;
        if (activeDoc) {
          throw createApiError(400, "You already have an open cash session. Please close it first.");
        }

        const { code: shiftCode, writeDescriptor: seqWrite } = await getNextSequenceCode(env, transaction, "shift");
        const sessionId = FirebaseFirestoreId();
        
        const sessionDoc = {
          id: sessionId,
          shiftCode,
          openedBy: uid,
          openedAt: new Date().toISOString(),
          status: "open",
          openingCash,
          expectedCash: openingCash,
          expectedCard: 0,
          totalSalesCount: 0,
          notes,
        };

        const writes = [
          // Counter update (must be inside the commit, not a standalone PATCH)
          seqWrite,
          {
            update: {
              name: firestoreDocName(env.FIREBASE_PROJECT_ID, "pos_cash_sessions", sessionId),
              fields: toFirestoreFields(sessionDoc),
            },
          },
        ];

        await commitTransaction(env, transaction, writes);
        return json({ ok: true, sessionId, shiftCode, status: "open" }, 200, origin);
      } catch (error) {
        if (transaction) await rollbackTransaction(env, transaction);
        throw error;
      }
    }

    // 2. GET /pos/cash-sessions/current
    if (method === "GET" && path === "/pos/cash-sessions/current") {
      const currentQuery = {
        structuredQuery: {
          from: [{ collectionId: "pos_cash_sessions" }],
          where: {
            compositeFilter: {
              op: "AND",
              filters: [
                {
                  fieldFilter: {
                    field: { fieldPath: "openedBy" },
                    op: "EQUAL",
                    value: { stringValue: uid },
                  },
                },
                {
                  fieldFilter: {
                    field: { fieldPath: "status" },
                    op: "EQUAL",
                    value: { stringValue: "open" },
                  },
                },
              ],
            },
          },
          limit: 1,
        },
      };

      const result = await firestoreRequest(env, "documents:runQuery", {
        method: "POST",
        body: currentQuery,
      });

      const activeDoc = Array.isArray(result) ? result.find(d => d.document) : null;
      if (!activeDoc || !activeDoc.document) {
        return json({ active: false }, 200, origin);
      }

      const decoded = decodeFirestoreDocument(activeDoc.document);
      const nameParts = activeDoc.document.name.split("/");
      const id = nameParts[nameParts.length - 1];

      return json({ active: true, session: { id, ...decoded } }, 200, origin);
    }

    // 3. POST /pos/cash-sessions/:id/close
    const closeMatch = path.match(/^\/pos\/cash-sessions\/([^/]+)\/close$/);
    if (method === "POST" && closeMatch) {
      const sessionId = closeMatch[1];
      const body = await request.json().catch(() => ({}));
      const actualCash = Number(body.actualCash || 0);
      const notes = String(body.notes || "").trim();

      let transaction = null;
      try {
        transaction = await beginTransaction(env);

        let sessionData;
        const sessionDocPath = `documents/pos_cash_sessions/${sessionId}`;
        try {
          const rawDoc = await firestoreRequest(env, `${sessionDocPath}?transaction=${encodeURIComponent(transaction)}`);
          sessionData = decodeFirestoreDocument(rawDoc);
        } catch (e) {
          if (e.status === 404) throw createApiError(404, "Cash session not found");
          throw e;
        }

        if (sessionData.status !== "open") {
          throw createApiError(400, "Cash session is already closed");
        }

        // P0: session ownership — cashier can only close their own session
        if (sessionData.openedBy !== uid) {
          throw createApiError(403, "You can only close your own cash session");
        }

        const discrepancy = actualCash - Number(sessionData.expectedCash || 0);

        const updatedSession = {
          ...sessionData,
          status: "closed",
          closedAt: new Date().toISOString(),
          actualCash,
          discrepancy,
          closeNotes: notes,
        };

        const writes = [
          {
            update: {
              name: firestoreDocName(env.FIREBASE_PROJECT_ID, "pos_cash_sessions", sessionId),
              fields: toFirestoreFields(updatedSession),
            },
          },
        ];

        await commitTransaction(env, transaction, writes);
        return json({ ok: true, sessionId, status: "closed", discrepancy }, 200, origin);
      } catch (error) {
        if (transaction) await rollbackTransaction(env, transaction);
        throw error;
      }
    }

    // 4. GET /pos/products/search
    if (method === "GET" && path === "/pos/products/search") {
      const limit = Number(url.searchParams.get("limit") || 100);
      
      const query = {
        structuredQuery: {
          from: [{ collectionId: "products" }],
          limit,
        },
      };

      const result = await firestoreRequest(env, "documents:runQuery", {
        method: "POST",
        body: query,
      });

      const list = Array.isArray(result)
        ? result
            .filter(d => d.document)
            .map(d => {
              const decoded = decodeFirestoreDocument(d.document);
              const parts = d.document.name.split("/");
              return { id: parts[parts.length - 1], ...decoded };
            })
            .filter(p => p.isSellable !== false)
        : [];

      return json(list, 200, origin);
    }

    // 5. GET /pos/perfume-oils/search
    if (method === "GET" && path === "/pos/perfume-oils/search") {
      const query = {
        structuredQuery: {
          from: [{ collectionId: "products" }],
          where: {
            fieldFilter: {
              field: { fieldPath: "productType" },
              op: "EQUAL",
              value: { stringValue: "raw_material" },
            },
          },
        },
      };

      const result = await firestoreRequest(env, "documents:runQuery", {
        method: "POST",
        body: query,
      });

      const list = Array.isArray(result)
        ? result
            .filter(d => d.document)
            .map(d => {
              const decoded = decodeFirestoreDocument(d.document);
              const parts = d.document.name.split("/");
              return { id: parts[parts.length - 1], ...decoded };
            })
        : [];

      return json(list, 200, origin);
    }

    // 6. GET /pos/recipes/:recipeId
    const recipeMatch = path.match(/^\/pos\/recipes\/([^/]+)$/);
    if (method === "GET" && recipeMatch) {
      const recipeId = recipeMatch[1];
      try {
        const rawDoc = await firestoreRequest(env, `documents/recipes/${recipeId}`);
        const decoded = decodeFirestoreDocument(rawDoc);
        return json({ id: recipeId, ...decoded }, 200, origin);
      } catch (error) {
        if (error.status === 404) return json({ error: "Recipe not found" }, 404, origin);
        throw error;
      }
    }

    // 7. POST /pos/sales
    if (method === "POST" && path === "/pos/sales") {
      const body = await request.json().catch(() => ({}));
      const result = await createPosSaleAtomically(env, uid, body);
      return json(result, 200, origin);
    }

    // 8. GET /pos/sales/:id
    const saleMatch = path.match(/^\/pos\/sales\/([^/]+)$/);
    if (method === "GET" && saleMatch) {
      const saleId = saleMatch[1];
      try {
        const rawDoc = await firestoreRequest(env, `documents/pos_sales/${saleId}`);
        const decoded = decodeFirestoreDocument(rawDoc);
        return json({ id: saleId, ...decoded }, 200, origin);
      } catch (error) {
        if (error.status === 404) return json({ error: "Sale not found" }, 404, origin);
        throw error;
      }
    }

    // 9. GET /pos/sales
    if (method === "GET" && path === "/pos/sales") {
      const query = {
        structuredQuery: {
          from: [{ collectionId: "pos_sales" }],
          orderBy: [{ field: { fieldPath: "createdAt" }, direction: "DESCENDING" }],
          limit: 100,
        },
      };

      // Filter by cashier if not admin
      if (!isAdmin) {
        query.structuredQuery.where = {
          fieldFilter: {
            field: { fieldPath: "cashierUid" },
            op: "EQUAL",
            value: { stringValue: uid },
          },
        };
      }

      const result = await firestoreRequest(env, "documents:runQuery", {
        method: "POST",
        body: query,
      });

      const list = Array.isArray(result)
        ? result
            .filter(d => d.document)
            .map(d => {
              const decoded = decodeFirestoreDocument(d.document);
              const parts = d.document.name.split("/");
              return { id: parts[parts.length - 1], ...decoded };
            })
        : [];

      return json(list, 200, origin);
    }
  }

  return null;
}
