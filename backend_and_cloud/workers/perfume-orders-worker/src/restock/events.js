/**
 * @typedef {{
 *   productId?: string,
 *   userId?: string,
 *   status?: string,
 *   notifiedAt?: string,
 *   lostOpportunityAt?: unknown,
 *   [key: string]: unknown
 * }} RestockRequestData
 */

/**
 * @typedef {{ restockRequestId?: string }} AttributionMetadata
 */

/**
 * @typedef {{
 *   restockRequestId: string,
 *   orderId: string,
 *   productId: string
 * }} RestockConversionPatch
 */

/**
 * @param {{
 *   orderSource?: string,
 *   attributionMetadata?: AttributionMetadata | null,
 *   requestData?: RestockRequestData | null,
 *   uid: string,
 *   orderId: string,
 *   requestedProductIds: Set<string>
 * }} params
 * @returns {RestockConversionPatch | null}
 */
export function buildRestockConversionPatch({
  orderSource,
  attributionMetadata,
  requestData,
  uid,
  orderId,
  requestedProductIds,
}) {
  if (orderSource !== "restock_alert") return null;
  const restockRequestId = attributionMetadata?.restockRequestId;
  if (!restockRequestId) return null;
  if (!requestData || typeof requestData !== "object") return null;

  const requestProductId = String(requestData.productId || "").trim();
  if (!requestProductId || !requestedProductIds.has(requestProductId)) {
    return null;
  }

  const requestOwner = String(requestData.userId || "").trim();
  if (requestOwner && requestOwner !== uid) {
    return null;
  }

  if (String(requestData.status || "").trim().toLowerCase() !== "notified") {
    return null;
  }

  return {
    restockRequestId,
    orderId,
    productId: requestProductId,
  };
}

/**
 * @param {{
 *   requestData?: RestockRequestData | null,
 *   uid: string,
 *   requestId: string
 * }} params
 * @returns {{ requestId: string, uid: string } | null}
 */
export function buildRestockCancellationPatch({ requestData, uid, requestId }) {
  if (!requestData || typeof requestData !== "object") return null;
  const owner = String(requestData.userId || "").trim();
  if (!owner || owner !== uid) return null;
  const status = String(requestData.status || "").trim().toLowerCase();
  if (status !== "pending") return null;
  return {
    requestId,
    uid,
  };
}

/**
 * @param {{ requestData?: RestockRequestData | null, cutoffDate: Date }} params
 * @returns {boolean}
 */
export function isLostOpportunityCandidate({ requestData, cutoffDate }) {
  if (!requestData || typeof requestData !== "object") return false;
  if (String(requestData.status || "").trim().toLowerCase() !== "notified") {
    return false;
  }
  if (requestData.lostOpportunityAt) return false;
  const notifiedAt = requestData.notifiedAt ? new Date(requestData.notifiedAt) : null;
  if (!notifiedAt || Number.isNaN(notifiedAt.getTime())) {
    return false;
  }
  return notifiedAt <= cutoffDate;
}

/**
 * @param {{
 *   eventId: string,
 *   uid: string,
 *   conversionPatch: RestockConversionPatch
 * }} params
 */
export function buildRestockConversionSuccessEvent({
  eventId,
  uid,
  conversionPatch,
}) {
  return {
    id: eventId,
    userId: uid,
    eventType: "restock_conversion_success",
    data: {
      restockRequestId: conversionPatch.restockRequestId,
      orderId: conversionPatch.orderId,
      productId: conversionPatch.productId,
    },
  };
}

/**
 * @param {{
 *   eventId: string,
 *   markedCount: number,
 *   inspectedCount: number,
 *   cutoffHours: number
 * }} params
 */
export function buildRestockLostOpportunityMarkedEvent({
  eventId,
  markedCount,
  inspectedCount,
  cutoffHours,
}) {
  return {
    id: eventId,
    userId: "system_cron",
    eventType: "restock_lost_opportunity_marked",
    data: {
      markedCount,
      inspectedCount,
      cutoffHours,
    },
  };
}
