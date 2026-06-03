import {
  ORDER_STATUSES,
  allowedTransitions,
} from "./constants/index.js";
import { requireUser } from "./auth/require-user.js";
import { listMyOrders } from "./firestore/queries.js";
import { mapErrorToResponse } from "./http/errors.js";
import { corsPreflight, json, resolveCorsOrigin, safeJsonBody } from "./http/responses.js";
import {
  cancelOrderAtomically,
  createOrderAtomically,
  updateOrderStatusByAdminAtomically,
} from "./orders/operations.js";
import {
  buildOrderPayloadHash,
  canTransition,
  isOrderStatus,
  normalizeOrderPayload,
} from "./orders/validation.js";
import {
  cancelRestockRequestByUserAtomically,
  markLostRestockOpportunities,
  restockProductByAdminAtomically,
} from "./restock/operations.js";
import { backfillFinanceAggregates } from "./admin/finance-backfill.js";
import { changeUserRoleByAdmin } from "./admin/users.js";
import { handleMediaRoutes } from "./media/controller.js";
import { enforceRateLimit } from "./rate-limit.js";

export {
  buildRestockCancellationPatch,
  buildRestockConversionPatch,
  buildRestockConversionSuccessEvent,
  buildRestockLostOpportunityMarkedEvent,
  isLostOpportunityCandidate,
} from "./restock/events.js";

export default {
  /**
   * @param {Request} request
   * @param {Record<string, unknown>} env
   */
  async fetch(request, env) {
    const origin = resolveCorsOrigin(request, env);
    try {
      const url = new URL(request.url);
      const path = url.pathname;
      const method = request.method.toUpperCase();
      const traceId = request.headers.get("x-trace-id") || "";

      if (method === "OPTIONS") {
        return corsPreflight(origin);
      }

      if (method === "GET" && path === "/health") {
        return json(
          {
            ok: true,
            service: "perfume-orders-worker",
            version: "1.2.0",
          },
          200,
          origin,
        );
      }

      if (method === "GET" && path === "/contract") {
        return json(
          {
            endpoints: [
              "POST /orders",
              "POST /orders/:id/cancel",
              "POST /user/restock-requests/:id/cancel",
              "POST /admin/orders/:id/status",
              "POST /admin/products/:id/restock",
              "POST /admin/users/:uid/role",
              "POST /admin/finance/aggregates/backfill",
              "POST /admin/restock/lost-opportunities/reconcile",
              "GET /orders/my",
              "GET /admin/media",
              "POST /admin/media/upload",
              "DELETE /admin/media/:key",
              "GET /media/public/:key",
            ],
            statuses: ORDER_STATUSES,
            auth: {
              orders: "user token required",
              adminStatus: "admin token required",
              adminRestock: "admin token required",
              adminUsers: "admin token required",
              adminFinanceBackfill: "admin token required",
              adminMedia: "admin token required",
            },
            allowedTransitions,
          },
          200,
          origin,
        );
      }

      const mediaResponse = await handleMediaRoutes(request, env, origin);
      if (mediaResponse) {
        return mediaResponse;
      }

      if (method === "POST" && path === "/orders") {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        const ip = request.headers.get("CF-Connecting-IP") || "unknown";
        await enforceRateLimit(env, `orders:create:uid:${userAuth.auth.uid}`, 10, 3600);
        await enforceRateLimit(env, `orders:create:ip:${ip}`, 30, 3600);

        const body = await safeJsonBody(request);
        const normalizedPayload = normalizeOrderPayload(body);
        const payload = {
          ...normalizedPayload,
          payloadHash: await buildOrderPayloadHash(normalizedPayload),
        };
        const result = await createOrderAtomically(env, userAuth.auth.uid, payload);

        return json(
          {
            ok: true,
            message: "Order placed successfully, Awaiting store processing",
            orderId: result.orderId,
            orderCode: result.orderCode ?? null,
            status: result.status,
            stockDeducted: result.stockDeducted,
            idempotent: result.idempotent,
          },
          200,
          origin,
        );
      }

      if (method === "GET" && path === "/orders/my") {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);
        const limit = Number(url.searchParams.get("limit") || 20);
        const result = await listMyOrders(env, userAuth.auth.uid, { limit });
        return json(result, 200, origin);
      }

      const cancelMatch = path.match(/^\/orders\/([^/]+)\/cancel$/);
      if (method === "POST" && cancelMatch) {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);

        const orderId = cancelMatch[1];
        const result = await cancelOrderAtomically(env, userAuth.auth.uid, orderId);

        const message = result.restocked
          ? "Order successfully cancelled and stock restored."
          : "Order successfully cancelled.";

        return json(
          {
            ok: true,
            message,
            orderId: result.orderId,
            status: result.status,
            restocked: result.restocked,
          },
          200,
          origin,
        );
      }

      const userRestockCancelMatch = path.match(/^\/user\/restock-requests\/([^/]+)\/cancel$/);
      if (method === "POST" && userRestockCancelMatch) {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);

        const result = await cancelRestockRequestByUserAtomically(
          env,
          userAuth.auth.uid,
          userRestockCancelMatch[1],
        );
        return json(result, 200, origin);
      }

      const adminStatusMatch = path.match(/^\/admin\/orders\/([^/]+)\/status$/);
      if (method === "POST" && adminStatusMatch) {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);
        if (!userAuth.auth.isAdmin) {
          console.log("admin_status_forbidden", {
            traceId,
            path,
            uid: userAuth.auth.uid,
          });
          return json({ error: "Forbidden: admin role required" }, 403, origin);
        }

        const body = await safeJsonBody(request);
        const fromStatus = String(body.fromStatus || "").trim();
        const toStatus = String(body.toStatus || "").trim();

        if (!isOrderStatus(fromStatus) || !isOrderStatus(toStatus)) {
          return json(
            { error: "fromStatus and toStatus are required and must be valid" },
            400,
            origin,
          );
        }

        const allowedForFromStatus = Object.prototype.hasOwnProperty.call(
          allowedTransitions,
          fromStatus,
        )
          ? allowedTransitions[/** @type {keyof typeof allowedTransitions} */ (fromStatus)]
          : [];

        if (!canTransition(fromStatus, toStatus)) {
          return json(
            {
              error: `Illegal transition from '${fromStatus}' to '${toStatus}'`,
              allowed: allowedForFromStatus,
            },
            409,
            origin,
          );
        }
        const reason =
          typeof body.reason === "string" && body.reason.trim().length > 0
            ? body.reason.trim()
            : null;
        const result = await updateOrderStatusByAdminAtomically(
          env,
          userAuth.auth.uid,
          adminStatusMatch[1],
          fromStatus,
          toStatus,
          reason,
          traceId,
        );
        return json(
          {
            ok: true,
            orderId: result.orderId,
            transition: { from: result.fromStatus, to: result.status },
            restocked: result.restocked,
          },
          200,
          origin,
        );
      }

      const adminRestockMatch = path.match(/^\/admin\/products\/([^/]+)\/restock$/);
      if (method === "POST" && adminRestockMatch) {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);
        if (!userAuth.auth.isAdmin) {
          console.log("admin_restock_forbidden", {
            traceId,
            path,
            uid: userAuth.auth.uid,
          });
          return json({ error: "Forbidden: admin role required" }, 403, origin);
        }

        const body = await safeJsonBody(request);
        const delta = Number(body.delta);
        if (!Number.isInteger(delta) || delta === 0) {
          return json(
            { error: "delta is required and must be a non-zero integer" },
            400,
            origin,
          );
        }
        console.log("admin_restock_request", {
          traceId,
          path,
          uid: userAuth.auth.uid,
          productId: adminRestockMatch[1],
          delta,
          requestIdsCount: Array.isArray(body.requestIds) ? body.requestIds.length : 0,
        });

        const requestIds = Array.isArray(body.requestIds)
          ? body.requestIds.map((id) => String(id || "").trim()).filter((id) => id.length > 0)
          : [];
        const result = await restockProductByAdminAtomically(
          env,
          userAuth.auth.uid,
          adminRestockMatch[1],
          delta,
          request.headers.get("x-trace-id") || "",
          requestIds,
        );
        console.log("admin_restock_success", {
          traceId,
          path,
          uid: userAuth.auth.uid,
          productId: result.productId,
          delta: result.delta,
          notifiedCount: result.notifiedCount,
          stock: result.stock,
        });

        return json(
          {
            ok: true,
            productId: result.productId,
            stock: result.stock,
            delta: result.delta,
            notifiedCount: result.notifiedCount,
            traceId: request.headers.get("x-trace-id") || "",
          },
          200,
          origin,
        );
      }

      const adminUserRoleMatch = path.match(/^\/admin\/users\/([^/]+)\/role$/);
      if (method === "POST" && adminUserRoleMatch) {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);
        if (!userAuth.auth.isAdmin) {
          console.log("admin_user_role_forbidden", {
            traceId,
            path,
            uid: userAuth.auth.uid,
          });
          return json({ error: "Forbidden: admin role required" }, 403, origin);
        }

        const body = await safeJsonBody(request);
        console.log("admin_user_role_request", {
          traceId,
          path,
          actorUid: userAuth.auth.uid,
          targetUid: adminUserRoleMatch[1],
          requestedRole: String(body.role || "").trim().toLowerCase(),
        });
        const result = await changeUserRoleByAdmin(
          env,
          userAuth.auth.uid,
          adminUserRoleMatch[1],
          body.role,
          traceId,
        );
        console.log("admin_user_role_success", {
          traceId: result.traceId,
          path,
          actorUid: userAuth.auth.uid,
          targetUid: result.uid,
          role: result.role,
          oldRole: result.oldRole,
        });
        return json(result, 200, origin);
      }

      if (method === "POST" && path === "/admin/finance/aggregates/backfill") {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:finance-backfill:uid:${userAuth.auth.uid}`, 6, 60);
        if (!userAuth.auth.isAdmin) {
          console.log("admin_finance_backfill_forbidden", {
            traceId,
            path,
            uid: userAuth.auth.uid,
          });
          return json({ error: "Forbidden: admin role required" }, 403, origin);
        }

        const body = await safeJsonBody(request);
        const result = await backfillFinanceAggregates(env, {
          limit: body.limit,
          cursor: body.cursor,
        });
        console.log("admin_finance_backfill_done", {
          traceId,
          path,
          uid: userAuth.auth.uid,
          scanned: result.scanned,
          aggregated: result.aggregated,
          skipped: result.skipped,
          nextCursor: result.nextCursor,
          hasMore: result.hasMore,
        });
        return json({ ...result, traceId }, 200, origin);
      }

      if (method === "POST" && path === "/admin/restock/lost-opportunities/reconcile") {
        const userAuth = await requireUser(request, env, origin);
        if (userAuth.response) return userAuth.response;
        await enforceRateLimit(env, `orders:user-action:uid:${userAuth.auth.uid}`, 20, 60);
        if (!userAuth.auth.isAdmin) {
          console.log("admin_reconcile_forbidden", {
            traceId,
            path,
            uid: userAuth.auth.uid,
          });
          return json({ error: "Forbidden: admin role required" }, 403, origin);
        }

        const body = await safeJsonBody(request);
        const cutoffHours = Number(body.cutoffHours);
        const limit = Number(body.limit);
        const result = await markLostRestockOpportunities(env, {
          cutoffHours: Number.isFinite(cutoffHours) ? cutoffHours : 48,
          limit: Number.isFinite(limit) ? limit : 400,
        });
        return json(result, 200, origin);
      }

      return json({ error: "Not Found" }, 404, origin);
    } catch (error) {
      const typedError = /** @type {{ status?: unknown } | null | undefined } */ (error);
      console.error("request_failed", {
        path: new URL(request.url).pathname,
        method: request.method.toUpperCase(),
        traceId: request.headers.get("x-trace-id") || "",
        status: typeof typedError?.status === "number" ? typedError.status : null,
        message: error instanceof Error ? error.message : String(error),
      });
      return mapErrorToResponse(error, origin);
    }
  },

  /**
   * @param {{ cron?: string } | undefined} controller
   * @param {Record<string, unknown>} env
    * @param {{ waitUntil: (promise: Promise<unknown>) => void }} ctx
   */
  async scheduled(controller, env, ctx) {
    try {
      const cutoffHours = Number(env.RESTOCK_LOST_OPPORTUNITY_HOURS || 48);
      const limit = Number(env.RESTOCK_LOST_OPPORTUNITY_LIMIT || 400);
      const result = await markLostRestockOpportunities(env, {
        cutoffHours,
        limit,
      });
      ctx.waitUntil(
        Promise.resolve(
          console.log("restock_lost_opportunity_job", {
            cron: controller?.cron || null,
            ...result,
          }),
        ),
      );
    } catch (error) {
      ctx.waitUntil(
        Promise.resolve(
          console.error("restock_lost_opportunity_job_failed", {
            message: error instanceof Error ? error.message : String(error),
          }),
        ),
      );
    }
  },
};
