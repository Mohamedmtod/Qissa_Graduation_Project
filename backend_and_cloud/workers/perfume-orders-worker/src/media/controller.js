import { requireUser } from "../auth/require-user.js";
import { createApiError } from "../http/errors.js";
import { json } from "../http/responses.js";
import { enforceRateLimit } from "../rate-limit.js";

const DEFAULT_MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/avif",
]);

const ALLOWED_FOLDERS = new Set([
  "products",
  "banners",
  "categories",
  "general",
]);

/**
 * @typedef {{
 *   key: string,
 *   uploaded?: Date,
 *   size: number,
 *   etag?: string,
 *   httpEtag?: string,
 *   httpMetadata?: { contentType?: string },
 *   customMetadata?: Record<string, string>
 * }} R2ObjectLike
 */

/**
 * @typedef {{
 *   objects: R2ObjectLike[],
 *   truncated: boolean,
 *   cursor?: string
 * }} R2ListResultLike
 */

/**
 * @typedef {{
 *   list: (opts?: { limit?: number, cursor?: string, prefix?: string }) => Promise<R2ListResultLike>,
 *   get: (key: string) => Promise<{
 *     body: ReadableStream<Uint8Array> | null,
 *     writeHttpMetadata: (headers: Headers) => void,
 *     httpEtag?: string,
 *     etag?: string
 *   } | null>,
 *   put: (
 *     key: string,
 *     value: ArrayBuffer,
 *     opts?: {
 *       httpMetadata?: { contentType?: string, cacheControl?: string },
 *       customMetadata?: Record<string, string>
 *     },
 *   ) => Promise<unknown>,
 *   delete: (key: string) => Promise<void>
 * }} R2BucketLike
 */

/**
 * @typedef {{
 *   BUCKET?: unknown,
 *   MEDIA_PUBLIC_BASE_URL?: string,
 *   MEDIA_MAX_UPLOAD_BYTES?: string
 * }} MediaEnv
 */

/**
 * @param {Request} request
 * @param {Record<string, unknown>} env
 * @param {string} origin
 * @returns {Promise<Response | null>}
 */
export async function handleMediaRoutes(request, env, origin) {
  const mediaEnv = /** @type {MediaEnv} */ (env);
  const bucket = getBucket(mediaEnv);
  const url = new URL(request.url);
  const path = normalizePath(url.pathname);
  const method = request.method.toUpperCase();

  const publicMatch = path.match(/^\/media\/public\/(.+)$/);
  if (method === "GET" && publicMatch) {
    const key = validateExistingObjectKey(decodeURIComponent(publicMatch[1]));
    const object = await bucket.get(key);
    if (!object || !object.body) {
      return json({ error: "Not Found" }, 404, origin);
    }

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("ETag", object.httpEtag || object.etag || "");
    headers.set("Access-Control-Allow-Origin", "*");
    headers.set("Vary", "Origin");
    if (!headers.get("Cache-Control")) {
      headers.set("Cache-Control", "public, max-age=31536000, immutable");
    }
    return new Response(object.body, {
      status: 200,
      headers,
    });
  }

  if (method === "GET" && path === "/admin/media") {
    const adminAuth = await requireAdmin(request, env, origin);
    if (adminAuth.response) return adminAuth.response;
    await enforceMediaAdminRateLimit(env, adminAuth.auth.uid);

    const limit = clampNumber(url.searchParams.get("limit"), 50, 1, 1000);
    const cursor = sanitizeOptional(url.searchParams.get("cursor"));
    const prefix = normalizeListPrefix(url.searchParams.get("prefix"));

    const result = await bucket.list({
      limit,
      cursor: cursor || undefined,
      prefix: prefix || undefined,
    });

    return json(
      {
        ok: true,
        items: result.objects.map((object) => serializeObject(object, mediaEnv)),
        truncated: result.truncated,
        cursor: result.truncated ? result.cursor || null : null,
      },
      200,
      origin,
    );
  }

  if (method === "POST" && path === "/admin/media/upload") {
    const adminAuth = await requireAdmin(request, env, origin);
    if (adminAuth.response) return adminAuth.response;
    await enforceMediaAdminRateLimit(env, adminAuth.auth.uid);

    const upload = await parseUploadRequest(request, mediaEnv);
    await bucket.put(upload.key, upload.body, {
      httpMetadata: {
        contentType: upload.contentType,
        cacheControl: "public, max-age=31536000, immutable",
      },
      customMetadata: {
        uploadedBy: adminAuth.auth.uid,
        originalName: upload.originalName,
      },
    });

    return json(
      {
        ok: true,
        key: upload.key,
        url: buildPublicMediaUrl(mediaEnv, upload.key),
        size: upload.size,
        contentType: upload.contentType,
      },
      201,
      origin,
    );
  }

  const deleteMatch = path.match(/^\/admin\/media\/(.+)$/);
  if (method === "DELETE" && deleteMatch) {
    const adminAuth = await requireAdmin(request, env, origin);
    if (adminAuth.response) return adminAuth.response;
    await enforceMediaAdminRateLimit(env, adminAuth.auth.uid);

    const key = validateExistingObjectKey(decodeURIComponent(deleteMatch[1]));
    await bucket.delete(key);

    return json(
      {
        ok: true,
        key,
        deleted: true,
      },
      200,
      origin,
    );
  }

  return null;
}

/**
 * @param {Record<string, unknown>} env
 * @param {string} uid
 */
async function enforceMediaAdminRateLimit(env, uid) {
  await enforceRateLimit(env, `orders:media-admin:uid:${uid}`, 20, 60);
}

/**
 * Accept both "/admin/media" and "/admin/media/".
 * @param {string} pathname
 */
function normalizePath(pathname) {
  if (pathname.length > 1 && pathname.endsWith("/")) {
    return pathname.slice(0, -1);
  }
  return pathname;
}

/**
 * @param {Request} request
 * @param {Record<string, unknown>} env
 * @param {string} origin
 */
async function requireAdmin(request, env, origin) {
  const userAuth = await requireUser(request, env, origin);
  if (userAuth.response) return userAuth;

  if (!userAuth.auth?.isAdmin) {
    return {
      response: json({ error: "Forbidden: admin role required" }, 403, origin),
    };
  }

  return userAuth;
}

/**
 * @param {Request} request
 * @param {MediaEnv} env
 */
async function parseUploadRequest(request, env) {
  const contentTypeHeader = request.headers.get("content-type") || "";
  if (!contentTypeHeader.toLowerCase().includes("multipart/form-data")) {
    throw createApiError(415, "Content-Type must be multipart/form-data");
  }

  const form = await request.formData();
  const file = form.get("file");

  if (!(file instanceof File)) {
    throw createApiError(400, "Form field 'file' is required");
  }

  if (file.size <= 0) {
    throw createApiError(400, "Uploaded file is empty");
  }

  const normalizedContentType = String(file.type || "").trim().toLowerCase();
  if (!ALLOWED_IMAGE_TYPES.has(normalizedContentType)) {
    throw createApiError(
      415,
      `Unsupported image type: ${normalizedContentType || "unknown"}`,
    );
  }

  const maxUploadBytes = clampNumber(
    env.MEDIA_MAX_UPLOAD_BYTES,
    DEFAULT_MAX_UPLOAD_BYTES,
    1,
    50 * 1024 * 1024,
  );

  if (file.size > maxUploadBytes) {
    throw createApiError(413, `Image exceeds max allowed size of ${maxUploadBytes} bytes`);
  }

  const folder = normalizeFolder(form.get("folder"));
  const originalName = sanitizeOriginalName(
    String(form.get("filename") || file.name || "upload"),
  );
  const extension = resolveExtension(originalName, normalizedContentType);
  const stem = sanitizeFileStem(stripExtension(originalName)) || "image";
  const key = `${folder}/${new Date().toISOString().slice(0, 10)}/${crypto.randomUUID()}-${stem}${extension}`;

  return {
    key,
    body: await file.arrayBuffer(),
    contentType: normalizedContentType,
    originalName,
    size: file.size,
  };
}

/**
 * @param {R2ObjectLike} object
 * @param {MediaEnv} env
 */
function serializeObject(object, env) {
  return {
    key: object.key,
    url: buildPublicMediaUrl(env, object.key),
    size: object.size,
    etag: object.httpEtag || object.etag || null,
    uploadedAt: object.uploaded instanceof Date ? object.uploaded.toISOString() : null,
    contentType: object.httpMetadata?.contentType || null,
    customMetadata: object.customMetadata || {},
  };
}

/**
 * @param {MediaEnv} env
 * @param {string} key
 */
function buildPublicMediaUrl(env, key) {
  const baseUrl = String(env.MEDIA_PUBLIC_BASE_URL || "").trim().replace(/\/+$/, "");
  if (!baseUrl) {
    throw createApiError(500, "MEDIA_PUBLIC_BASE_URL is not configured");
  }

  const encodedKey = key
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  return `${baseUrl}/${encodedKey}`;
}

/**
 * @param {FormDataEntryValue | null} value
 */
function normalizeFolder(value) {
  const folder = String(value || "general").trim().toLowerCase();
  if (!ALLOWED_FOLDERS.has(folder)) {
    throw createApiError(
      400,
      "folder must be one of: products, banners, categories, general",
    );
  }
  return folder;
}

/**
 * @param {string | null} value
 */
function normalizeListPrefix(value) {
  const prefix = sanitizeOptional(value);
  if (!prefix) return "";

  const normalized = prefix.replace(/^\/+/, "").trim();
  const rootFolder = normalized.split("/")[0]?.toLowerCase() || "";
  if (!ALLOWED_FOLDERS.has(rootFolder)) {
    throw createApiError(400, "Invalid media prefix");
  }
  return normalized.endsWith("/") ? normalized : `${normalized}/`;
}

/**
 * @param {string} rawKey
 */
function validateExistingObjectKey(rawKey) {
  const key = String(rawKey || "").trim().replace(/^\/+/, "");
  if (!key) {
    throw createApiError(400, "Media key is required");
  }
  if (key.includes("..") || !/^[A-Za-z0-9/_\-.]+$/.test(key)) {
    throw createApiError(400, "Invalid media key");
  }
  return key;
}

/**
 * @param {string} filename
 * @param {string} contentType
 */
function resolveExtension(filename, contentType) {
  const existing = filename.match(/\.[A-Za-z0-9]+$/)?.[0]?.toLowerCase();
  if (existing) return existing;

  switch (contentType) {
    case "image/jpeg":
      return ".jpg";
    case "image/png":
      return ".png";
    case "image/webp":
      return ".webp";
    case "image/gif":
      return ".gif";
    case "image/avif":
      return ".avif";
    default:
      return "";
  }
}

/**
 * @param {string} value
 */
function stripExtension(value) {
  return value.replace(/\.[A-Za-z0-9]+$/, "");
}

/**
 * @param {string} value
 */
function sanitizeOriginalName(value) {
  return value.trim().replace(/\s+/g, " ").slice(0, 120) || "upload";
}

/**
 * @param {string} value
 */
function sanitizeFileStem(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9-_]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}

/**
 * @param {string | null | undefined} value
 */
function sanitizeOptional(value) {
  const normalized = String(value || "").trim();
  return normalized.length > 0 ? normalized : "";
}

/**
 * @param {string | number | null | undefined} value
 * @param {number} fallback
 * @param {number} min
 * @param {number} max
 */
function clampNumber(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(parsed)));
}

/**
 * @param {MediaEnv} env
 * @returns {R2BucketLike}
 */
function getBucket(env) {
  const candidate = env.BUCKET;
  if (
    !candidate ||
    typeof candidate !== "object" ||
    !("list" in candidate) ||
    !("get" in candidate) ||
    !("put" in candidate) ||
    !("delete" in candidate)
  ) {
    throw createApiError(500, "R2 bucket binding is missing (expected env.BUCKET)");
  }
  return /** @type {R2BucketLike} */ (candidate);
}
