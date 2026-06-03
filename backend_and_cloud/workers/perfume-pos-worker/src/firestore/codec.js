/**
 * @typedef {{ fields?: Record<string, FirestoreValue> }} FirestoreMapValue
 */

/**
 * @typedef {{ values?: FirestoreValue[] }} FirestoreArrayValue
 */

/**
 * @typedef {{
 *   stringValue?: string,
 *   integerValue?: string | number,
 *   doubleValue?: number,
 *   booleanValue?: boolean,
 *   nullValue?: null,
 *   timestampValue?: string,
 *   mapValue?: FirestoreMapValue,
 *   arrayValue?: FirestoreArrayValue
 * }} FirestoreValue
 */

/**
 * @typedef {{ fields?: Record<string, FirestoreValue> }} FirestoreDocumentLike
 */

/**
 * @param {FirestoreValue | null | undefined} value
 * @returns {unknown}
 */
export function fromFirestoreValue(value) {
  if (!value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return Boolean(value.booleanValue);
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return value.timestampValue;
  if ("mapValue" in value) {
    /** @type {Record<string, unknown>} */
    const out = {};
    const fields = value.mapValue?.fields || {};
    for (const [k, v] of Object.entries(fields)) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  if ("arrayValue" in value) {
    /** @type {FirestoreValue[]} */
    const values = value.arrayValue?.values || [];
    return values.map((v) => fromFirestoreValue(v));
  }
  return null;
}

/**
 * @param {unknown} value
 * @returns {FirestoreValue}
 */
export function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isFinite(value)) return { nullValue: null };
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((v) => toFirestoreValue(v)),
      },
    };
  }
  if (typeof value === "object") {
    /** @type {Record<string, FirestoreValue>} */
    const fields = {};
    for (const [k, v] of Object.entries(/** @type {Record<string, unknown>} */ (value))) {
      if (v !== undefined) {
        fields[k] = toFirestoreValue(v);
      }
    }
    return { mapValue: { fields } };
  }

  return { nullValue: null };
}

/**
 * @param {Record<string, unknown>} obj
 * @returns {Record<string, FirestoreValue>}
 */
export function toFirestoreFields(obj) {
  /** @type {Record<string, FirestoreValue>} */
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) {
      out[k] = toFirestoreValue(v);
    }
  }
  return out;
}

/**
 * @param {FirestoreDocumentLike | null | undefined} document
 * @returns {Record<string, unknown>}
 */
export function decodeFirestoreDocument(document) {
  const fields = document?.fields || {};
  /** @type {Record<string, unknown>} */
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] = fromFirestoreValue(v);
  }
  return out;
}
