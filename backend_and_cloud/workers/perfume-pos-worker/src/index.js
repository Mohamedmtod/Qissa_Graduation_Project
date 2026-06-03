import { handlePosRoutes } from "./routes.js";
import { mapErrorToResponse } from "./http/errors.js";
import { corsPreflight, json, resolveCorsOrigin } from "./http/responses.js";

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

      if (method === "OPTIONS") {
        return corsPreflight(origin);
      }

      if (method === "GET" && path === "/health") {
        return json(
          {
            ok: true,
            service: "perfume-pos-worker",
            version: "1.0.0",
          },
          200,
          origin,
        );
      }

      const response = await handlePosRoutes(request, env, origin);
      if (response) {
        return response;
      }

      return json({ error: "Not Found" }, 404, origin);
    } catch (error) {
      const typedError = /** @type {{ status?: unknown } | null | undefined } */ (error);
      console.error("pos_request_failed", {
        path: new URL(request.url).pathname,
        method: request.method.toUpperCase(),
        traceId: request.headers.get("x-trace-id") || "",
        status: typeof typedError?.status === "number" ? typedError.status : null,
        message: error instanceof Error ? error.message : String(error),
      });
      return mapErrorToResponse(error, origin);
    }
  },
};
