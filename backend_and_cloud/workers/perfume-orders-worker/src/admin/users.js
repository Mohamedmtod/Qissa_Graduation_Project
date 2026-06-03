import { createApiError } from "../http/errors.js";
import { decodeFirestoreDocument, toFirestoreFields } from "../firestore/codec.js";
import { batchGetDocuments, firestoreDocName } from "../firestore/queries.js";
import {
  beginTransaction,
  commitTransaction,
  rollbackTransaction,
  isRetryableTransactionError,
  sleep,
} from "../firestore/transactions.js";
import { MAX_TRANSACTION_RETRIES } from "../constants/index.js";

/**
 * @typedef {{ FIREBASE_PROJECT_ID?: string }} WorkerEnv
 */

const ALLOWED_ROLES = new Set(["user", "employee", "admin"]);

/**
 * Changes the role of a Firestore user document atomically.
 * Only admins may call this endpoint (enforced at the router level).
 *
 * @param {WorkerEnv} env
 * @param {string} actorUid
 * @param {string} targetUid
 * @param {unknown} rawRole
 * @param {string} traceId
 */
export async function changeUserRoleByAdmin(env, actorUid, targetUid, rawRole, traceId) {
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw createApiError(500, "Missing FIREBASE_PROJECT_ID secret");
  }

  const role = String(rawRole || "").trim().toLowerCase();
  if (!ALLOWED_ROLES.has(role)) {
    throw createApiError(
      400,
      `Invalid role '${role}'. Allowed roles: ${[...ALLOWED_ROLES].join(", ")}`,
    );
  }

  if (actorUid === targetUid && role !== "admin") {
    throw createApiError(409, "Admin cannot demote themselves.");
  }

  const userDocName = firestoreDocName(projectId, "users", targetUid);

  for (let attempt = 1; attempt <= MAX_TRANSACTION_RETRIES; attempt++) {
    let transaction = null;
    let committed = false;

    try {
      transaction = await beginTransaction(env);

      const docs = await batchGetDocuments(env, [userDocName], transaction);
      const userDoc = docs.found.get(userDocName);
      if (!userDoc) {
        throw createApiError(404, `User '${targetUid}' not found`);
      }

      const userData = decodeFirestoreDocument(userDoc);
      const oldRole = String(userData.role || "");

      if (oldRole === role) {
        // No change needed — return early without writing.
        return { uid: targetUid, role, oldRole, traceId };
      }

      const writes = [
        {
          update: {
            name: userDocName,
            fields: toFirestoreFields({ role }),
          },
          updateMask: { fieldPaths: ["role"] },
        },
        {
          transform: {
            document: userDocName,
            fieldTransforms: [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }],
          },
        },
      ];

      await commitTransaction(env, transaction, writes);
      committed = true;

      console.log("admin_user_role_changed", {
        traceId,
        actorUid,
        targetUid,
        oldRole,
        newRole: role,
      });

      return { uid: targetUid, role, oldRole, traceId };
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

  throw createApiError(503, "Could not complete role change transaction after retries");
}
