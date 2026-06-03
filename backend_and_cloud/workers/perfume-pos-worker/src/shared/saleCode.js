import { firestoreRequest } from "../firestore/client.js";
import { toFirestoreFields, decodeFirestoreDocument } from "../firestore/codec.js";

/**
 * Reads the current sequence counters (inside a Firestore transaction via
 * query param), increments the relevant counter, and returns both the new
 * human-readable code AND a Firestore write descriptor to be included in the
 * caller's commitTransaction writes array.
 *
 * WHY: Firestore REST API rules for transaction IDs:
 *   - GET  (document read) → pass as `?transaction=<encoded>` query param ✅
 *   - PATCH (standalone write) → does NOT accept `?transaction=` param ❌
 *   - Commit → the transaction token goes in the POST body of `documents:commit` ✅
 *
 * So instead of firing a standalone PATCH here (which was causing the
 * "Unknown name 'transaction'" 400 error), we return the write descriptor
 * and let the caller include it in the final commitTransaction call.
 *
 * @param {any} env
 * @param {string} transaction   Firestore transaction token from beginTransaction.
 * @param {'sale' | 'shift'} type
 * @returns {Promise<{ code: string, writeDescriptor: object }>}
 */
export async function getNextSequenceCode(env, transaction, type) {
  const docPath = `documents/counters/pos_sequences`;
  let saleVal = 0;
  let shiftVal = 0;

  // READ inside transaction: ?transaction= is valid on GET document reads.
  try {
    const rawDoc = await firestoreRequest(
      env,
      `${docPath}?transaction=${encodeURIComponent(transaction)}`,
    );
    const decoded = decodeFirestoreDocument(rawDoc);
    saleVal = Number(decoded.sale || 0);
    shiftVal = Number(decoded.shift || 0);
  } catch (error) {
    // Counter document doesn't exist yet — start from zero.
    if (error.status !== 404) {
      throw error;
    }
  }

  if (type === "sale") {
    saleVal += 1;
  } else if (type === "shift") {
    shiftVal += 1;
  }

  const nextVal = type === "sale" ? saleVal : shiftVal;
  const year = new Date().getFullYear();
  const seqStr = String(nextVal).padStart(6, "0");
  const prefix = type === "sale" ? "POS" : "SHIFT";
  const code = `${prefix}-${year}-${seqStr}`;

  // Return a write descriptor instead of firing a standalone PATCH.
  // The caller MUST include this in their commitTransaction writes array.
  const writeDescriptor = {
    update: {
      name: `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/counters/pos_sequences`,
      fields: toFirestoreFields({
        sale: saleVal,
        shift: shiftVal,
      }),
    },
  };

  return { code, writeDescriptor };
}
