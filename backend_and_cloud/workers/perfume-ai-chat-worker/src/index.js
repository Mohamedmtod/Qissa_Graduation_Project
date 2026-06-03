import { Redis } from '@upstash/redis/cloudflare';
import { Ratelimit } from '@upstash/ratelimit';

// в”Ђв”Ђ CORS в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// ALLOWED_ORIGINS env var: comma-separated list of allowed web origins.
// ALLOW_DEV_ORIGINS=true additionally allows localhost/127.0.0.1/10.0.2.2.
// Example: "https://perfume-app.web.app,https://perfume-app.firebaseapp.com"
// Native mobile clients send no Origin header and are always allowed through.
// If ALLOWED_ORIGINS is not set (e.g. local dev), wildcard '*' is used as fallback.

const CORS_FIXED_HEADERS = {
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json; charset=utf-8',
};

/**
 * Returns appropriate CORS headers for the given request and env.
 * - No Origin header (native mobile): no ACAO header needed, but we include it as '*' for safety.
 * - Origin in allowlist: reflect the specific origin.
 * - Origin not in allowlist (and allowlist is set): reject with a 403-friendly null origin.
 * - No allowlist configured (dev fallback): use '*'.
 */
function buildCorsHeaders(request, env) {
  const origin = request?.headers?.get('Origin') || null;
  const allowedOriginsRaw = env?.ALLOWED_ORIGINS
    ? String(env.ALLOWED_ORIGINS).trim()
    : '';

  // No allowlist configured в†’ dev fallback: allow all
  if (!allowedOriginsRaw) {
    return { ...CORS_FIXED_HEADERS, 'Access-Control-Allow-Origin': '*' };
  }

  const allowedOrigins = allowedOriginsRaw
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  // No Origin header в†’ native mobile client, no restriction needed
  if (!origin) {
    return { ...CORS_FIXED_HEADERS, 'Access-Control-Allow-Origin': '*' };
  }

  if (env?.ALLOW_DEV_ORIGINS === 'true' && isDevOrigin(origin)) {
    return {
      ...CORS_FIXED_HEADERS,
      'Access-Control-Allow-Origin': origin,
      'Vary': 'Origin',
    };
  }

  // Origin matches allowlist в†’ reflect it (required for credentialed requests)
  if (allowedOrigins.includes(origin)) {
    return {
      ...CORS_FIXED_HEADERS,
      'Access-Control-Allow-Origin': origin,
      'Vary': 'Origin',
    };
  }

  // Origin NOT in allowlist в†’ deny CORS (browser will block the request)
  logWorkerEvent('cors_origin_rejected', { origin });
  return {
    ...CORS_FIXED_HEADERS,
    'Access-Control-Allow-Origin': 'null',
    'Vary': 'Origin',
  };
}

function isDevOrigin(origin) {
  try {
    const url = new URL(origin);
    return ['localhost', '127.0.0.1', '10.0.2.2'].includes(url.hostname);
  } catch (_) {
    return false;
  }
}

function jsonResponse(payload, status = 200, corsHeaders = null) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders ?? { ...CORS_FIXED_HEADERS, 'Access-Control-Allow-Origin': '*' },
  });
}

const MAX_PRODUCT_IDS = 3;
const MAX_FEEDBACK_PRODUCT_IDS = 5;
const MAX_FEEDBACK_TRACE_TURNS = 10;
const MAX_FEEDBACK_STRING_LENGTH = 240;
const MAX_TURN_DEBUG_USER_TEXT_LENGTH = 300;
const MAX_TURN_DEBUG_ASSISTANT_TEXT_LENGTH = 700;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const MAX_MISSING_NEEDS = 5;
const MAX_ANALYSIS_COMMENT_LENGTH = 280;
const MAX_ANALYSIS_SUMMARY_LENGTH = 600;
const MAX_CANDIDATES = 30;
const CHAT_MODEL_PROMPT_CANDIDATE_LIMIT = 12;
const MAX_CURRENT_MESSAGE_LENGTH = 1200;
const MAX_REQUEST_ID_LENGTH = 128;
const OPENROUTER_MODEL_ID = 'qwen/qwen3-32b';
const OPENROUTER_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';
const CHAT_MAX_OUTPUT_TOKENS = 500;
const CHAT_MODEL_TIMEOUT_MS = 10000;
const CHAT_MODEL_MIN_TIMEOUT_MS = 4000;
const CHAT_MODEL_MAX_TIMEOUT_MS = 10000;
const FEEDBACK_MAX_OUTPUT_TOKENS = 700;
const PERFUME_KNOWLEDGE_MAX_OUTPUT_TOKENS = 450;
const INTERPRET_MAX_OUTPUT_TOKENS = 280;
const OPENROUTER_RESPONSE_MIME_TYPE = 'application/json';
const PROMPT_VERSION = 'v1.2';
const STRUCTURED_PROMPT_VERSION = 'chat_v2_structured_commands';
const TOOL_ROUTER_ALLOWED_TOOLS = new Set([
  'search_products',
  'get_cheapest_products',
  'get_most_expensive_products',
  'update_preferences',
  'update_preferences_and_recommend',
  'answer_product_question',
  'ask_product_clarification',
  'cheapest_catalog',
  'most_expensive_catalog',
  'similar_cheaper',
  'cheaper_followup',
  'show_lowest_available_after_budget_no_match',
  'reject_visible_products',
  'resolve_perfume_reference',
  'select_perfume_reference_option',
  'lookup_external_perfume_profile',
  'recommend_similar_to_external_profile',
  'similar_cheaper_to_external_profile',
  'ask_clarification',
]);
const AI_CHAT_FEEDBACK_REASONS = new Set([
  'wrong_recommendation',
  'wrong_gender',
  'wrong_occasion',
  'too_expensive',
  'not_similar',
  'repeated_products',
  'bad_arabic',
  'slow_response',
  'confusing_answer',
  'external_lookup_wrong',
  'availability_wrong',
  'other',
]);
const AI_CHAT_FEEDBACK_FORBIDDEN_KEYS = new Set([
  'rawUserMessage',
  'fullPrompt',
  'prompt',
  'rawPrompt',
  'userId',
  'sessionId',
  'rawSessionId',
  'fullTranscript',
  'transcript',
  'assistantFullReply',
  'rawModelOutput',
  'rawModelInput',
  'rawInput',
  'modelMessages',
  'apiKey',
  'secret',
  'token',
]);
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FIRESTORE_SCOPE = 'https://www.googleapis.com/auth/datastore';
const FIRESTORE_API_BASE = 'https://firestore.googleapis.com/v1';
const CATALOG_FETCH_TIMEOUT_MS = 8000;
const PERFUME_KNOWLEDGE_MIN_CONFIDENCE = 0.58;
const FRAGRANTICA_ARABIA_FETCH_TIMEOUT_MS = 5000;
const PERFUME_KNOWLEDGE_CANDIDATE_MODEL_TIMEOUT_MS = 8000;
const FRAGRANTICA_ARABIA_ORIGIN = 'https://www.fragranticarabia.com';
const FRAGRANTICA_ARABIA_HOST = 'www.fragranticarabia.com';
const PERFUME_KNOWLEDGE_MAX_CANDIDATES = 3;
const PERFUME_KNOWLEDGE_DIRECT_MATCH_SCORE = 0.86;
const PERFUME_KNOWLEDGE_AMBIGUOUS_MIN_SCORE = 0.36;
const FRAGRANTICA_ARABIA_CANONICAL_CANDIDATE_HINTS = [
  {
    brand: 'Dior',
    displayName: 'Sauvage',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-31861.html',
    aliases: ['dior sauvage', 'sauvage dior'],
  },
  {
    brand: 'Dior',
    displayName: 'Sauvage Eau de Parfum',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Eau-de-Parfum-48100.html',
    aliases: ['dior sauvage eau de parfum', 'sauvage eau de parfum', 'sauvage edp'],
  },
  {
    brand: 'Dior',
    displayName: 'Sauvage Parfum',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Parfum-56324.html',
    aliases: ['dior sauvage parfum', 'sauvage parfum'],
  },
  {
    brand: 'Dior',
    displayName: 'Sauvage Very Cool Spray',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Very-Cool-Spray-43933.html',
    aliases: ['dior sauvage very cool spray', 'sauvage very cool spray'],
  },
  {
    brand: 'Chanel',
    displayName: 'Bleu de Chanel',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-9099.html',
    aliases: ['bleu de chanel', 'chanel bleu'],
  },
  {
    brand: 'Chanel',
    displayName: 'Bleu de Chanel Eau de Parfum',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-Eau-de-Parfum-25967.html',
    aliases: ['chanel bleu eau de parfum', 'bleu de chanel eau de parfum', 'bleu de chanel edp'],
  },
  {
    brand: 'Chanel',
    displayName: 'Bleu de Chanel Parfum',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-Parfum-49912.html',
    aliases: ['chanel bleu parfum', 'bleu de chanel parfum'],
  },
  {
    brand: 'Creed',
    displayName: 'Aventus',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Creed/Aventus-9828.html',
    aliases: ['creed aventus', 'aventus creed'],
  },
  {
    brand: 'Maison Francis Kurkdjian',
    displayName: 'Baccarat Rouge 540',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Maison-Francis-Kurkdjian/Baccarat-Rouge-540-33519.html',
    aliases: [
      'baccarat rouge 540',
      'maison francis kurkdjian baccarat rouge 540',
      'mfk baccarat rouge 540',
    ],
  },
  {
    brand: 'Azzaro',
    displayName: 'Azzaro pour Homme',
    sourceUrl: 'https://www.fragranticarabia.com/perfumes/Azzaro/Azzaro-pour-Homme-829.html',
    aliases: ['azzaro pour homme'],
  },
];
const FRAGRANTICA_ARABIA_FAMILY_AMBIGUITY_HINTS = {
  sauvage: [
    'dior sauvage',
    'dior sauvage eau de parfum',
    'dior sauvage parfum',
  ],
  blue: [
    'bleu de chanel',
    'bleu de chanel eau de parfum',
    'bleu de chanel parfum',
  ],
  bleu: [
    'bleu de chanel',
    'bleu de chanel eau de parfum',
    'bleu de chanel parfum',
  ],
};
const INTERPRETATION_INTENTS = [
  'recommendation',
  'modifier',
  'availability',
  'compare',
  'answer',
  'greeting',
  'off_topic',
  'unclear',
];
const INTERPRETATION_ASK_SLOTS = [
  'gender',
  'season',
  'maxBudget',
  'notesOrIntensity',
];

const ARABIC_SCENT_TRANSLATIONS = new Map([
  ['ШЈШ±Щ€Щ…Ш§ШЄЩѓ', 'aromatic'],
  ['Ш®ШґШЁЩЉ', 'woody'],
  ['ШЄШ§ШЁЩ„ЩЉ Щ…Щ†Ш№Шґ', 'fresh spicy'],
  ['ШЄШ§ШЁЩ„ЩЉ ШЇШ§ЩЃШ¦', 'warm spicy'],
  ['ШЄШ±Ш§ШЁЩЉ', 'earthy'],
  ['Ш§Щ„Ш®ШІШ§Щ…ЩЉ', 'lavender'],
  ['Ш§Щ„Ш®ШІШ§Щ…Щ‰', 'lavender'],
  ['Ш·Ш­Щ„ШЁЩЉ', 'mossy'],
  ['Ш§Щ„Ш¬Щ„Щ€ШЇ', 'leather'],
  ['Ш§Щ„Ш­Щ…Ш¶ЩЉШ§ШЄ', 'citrus'],
  ['Щ†Ш§Ш№Щ…', 'soft'],
  ['Ш№ШґШЁЩЉ', 'herbal'],
  ['Ш§Щ„Ш№Щ†ШЁШ±', 'amber'],
  ['Ш§Щ„ЩЃШ§Щ†ЩЉЩ„Ш§', 'vanilla'],
  ['ШЁЩ„ШіЩ…ЩЉ', 'balsamic'],
  ['Щ…Ш§Ш¦ЩЉ', 'aquatic'],
  ['ЩЃШ§ЩѓЩ‡ЩЉ', 'fruity'],
  ['Щ…Щ†Ш№Шґ', 'fresh'],
  ['Ш§Щ„Щ„ЩЉЩ…Щ€Щ†', 'lemon'],
  ['Щ„ЩЉЩ…Щ€Щ†', 'lemon'],
  ['Ш§Щ„Ш®ШІШ§Щ…ЩЉ', 'lavender'],
  ['Ш§Щ„ЩѓШ§Ш±Ш§Щ€ЩЉШ©', 'caraway'],
  ['Ш§Щ„Ш±ЩЉШ­Ш§Щ†', 'basil'],
  ['Ш§Щ„ШЁШ±ШєЩ…Щ€ШЄ', 'bergamot'],
  ['Ш§Щ„Щ…Ш±ЩЉЩ…ЩЉШ©', 'sage'],
  ['Ш§Щ„ШіЩ€ШіЩ†', 'iris'],
  ['Ш§Щ„ЩЉЩ†ШіЩ€Щ† Ш§Щ„Щ†Ш¬Щ…ЩЉ', 'star anise'],
  ['Щ†Ш¬ЩЉЩ„ Ш§Щ„Щ‡Щ†ШЇ', 'vetiver'],
  ['Ш®ШґШЁ Ш§Щ„ШЈШ±ШІ', 'cedar'],
  ['Ш®ШґШЁ Ш§Щ„ШµЩ†ШЇЩ„', 'sandalwood'],
  ['Ш§Щ„ШЁШ§ШЄШґЩ€Щ„ЩЉ', 'patchouli'],
  ['ШЄЩ€ШЄ Ш§Щ„Ш№Ш±Ш№Ш±', 'juniper berries'],
  ['Ш§Щ„Щ‡ЩЉЩ„', 'cardamom'],
  ['Ш·Ш­Щ„ШЁ Ш§Щ„ШЁЩ„Щ€Ш·', 'oakmoss'],
  ['Ш·Ш­Щ„ШЁ Ш§Щ„ШіЩ†ШЇЩЉШ§Щ†', 'oakmoss'],
  ['Ш§Щ„Щ…ШіЩѓ', 'musk'],
  ['Ш­ШЁЩ€ШЁ Ш§Щ„ШЄЩ€Щ†ЩѓШ§', 'tonka bean'],
]);

for (const [term, normalized] of [
  ['أروماتك', 'aromatic'],
  ['خشبي', 'woody'],
  ['تابلي منعش', 'fresh spicy'],
  ['تابلي دافئ', 'warm spicy'],
  ['ترابي', 'earthy'],
  ['الخزامي', 'lavender'],
  ['الخزامى', 'lavender'],
  ['طحلبي', 'mossy'],
  ['الجلود', 'leather'],
  ['الحمضيات', 'citrus'],
  ['ناعم', 'soft'],
  ['عشبي', 'herbal'],
  ['العنبر', 'amber'],
  ['الليمون', 'lemon'],
  ['ليمون', 'lemon'],
  ['الكاراوية', 'caraway'],
  ['الريحان', 'basil'],
  ['البرغموت', 'bergamot'],
  ['المريمية', 'sage'],
  ['السوسن', 'iris'],
  ['الينسون النجمي', 'star anise'],
  ['نجيل الهند', 'vetiver'],
  ['خشب الأرز', 'cedar'],
  ['خشب الصندل', 'sandalwood'],
  ['الباتشولي', 'patchouli'],
  ['توت العرعر', 'juniper berries'],
  ['الهيل', 'cardamom'],
  ['طحلب البلوط', 'oakmoss'],
  ['طحلب السنديان', 'oakmoss'],
  ['المسك', 'musk'],
  ['حبوب التونكا', 'tonka bean'],
  ['\u0627\u0644\u0641\u0627\u0646\u064a\u0644\u0627', 'vanilla'],
  ['\u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627', 'vanilla'],
  ['\u0627\u0644\u0628\u0646\u0632\u0648\u064a\u0646', 'benzoin'],
  ['\u0627\u0644\u0628\u0646\u0632\u0648\u064a\u0646 \u0627\u0644\u062c\u0627\u0648\u064a', 'benzoin'],
  ['\u0627\u0644\u0639\u0633\u0644', 'honey'],
  ['\u0627\u0644\u062a\u0628\u063a', 'tobacco'],
]) {
  ARABIC_SCENT_TRANSLATIONS.set(term, normalized);
}

// PRODUCTION NOTE: For multi-region deployment, we use Upstash Redis for distributed rate limiting.
// We fallback to in-memory Isolate-level rate limiting if Upstash is not configured.
const rateLimitStore = globalThis.__aiChatRateLimitStore ||
  (globalThis.__aiChatRateLimitStore = new Map());

// Global cache for the Upstash Ratelimit instance so we don't recreate it every request.
let upstashRatelimiter = null;

function t(language, ar, en) {
  return language === 'en' ? en : ar;
}


function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value
    .map((item) => String(item ?? '').trim())
    .filter(Boolean))];
}

function parseNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const normalized = value.replace(/,/g, '').trim();
    const parsed = Number.parseFloat(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function normalizeEnum(value, allowed) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toLowerCase();
  return allowed.includes(normalized) ? normalized : null;
}

function normalizeAnalysisStatus(value) {
  if (typeof value !== 'string') return 'pending';
  const normalized = value.trim().toLowerCase();
  if (['pending', 'completed', 'failed', 'pending_retry'].includes(normalized)) {
    return normalized;
  }
  if (normalized === 'pendingretry') return 'pending_retry';
  return 'pending';
}

function normalizeSentiment(value) {
  return normalizeEnum(value, ['positive', 'neutral', 'negative']) || 'neutral';
}

function normalizeBoolean(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].includes(normalized)) return true;
    if (['false', '0', 'no', 'n'].includes(normalized)) return false;
  }
  return fallback;
}

function clipFeedbackText(value, maxLength = MAX_FEEDBACK_STRING_LENGTH) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  const redacted = text
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]')
    .replace(/(?<!\d)(?:\+?\d[\s-]?){8,15}(?!\d)/g, '[PHONE]')
    .replace(/\b(?:sk|pk|ghp|xoxb|AIza|ya29)[A-Za-z0-9._-]{8,}\b/gi, '[TOKEN]')
    .replace(/\b(?:session|sessionId|user|userId|uid|token|key|secret)[-_:= ]+[A-Za-z0-9._-]{4,}\b/gi, '[ID]')
    .replace(/\b[A-Za-z0-9_-]{32,}\b/g, '[ID]');
  return redacted.length <= maxLength ? redacted : redacted.slice(0, maxLength);
}

function clipDebugIdentifier(value, maxLength = 120) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  const cleaned = text.replace(/[^A-Za-z0-9._:-]/g, '_');
  return cleaned.length <= maxLength ? cleaned : cleaned.slice(0, maxLength);
}

function clipTimestamp(value) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  const cleaned = text.replace(/[^0-9A-Za-z:._+-]/g, '');
  return cleaned.length <= 40 ? cleaned : cleaned.slice(0, 40);
}

function findForbiddenFeedbackKey(value, path = '') {
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) {
      const found = findForbiddenFeedbackKey(value[i], `${path}[${i}]`);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== 'object') return null;
  for (const key of Object.keys(value)) {
    if (AI_CHAT_FEEDBACK_FORBIDDEN_KEYS.has(key)) {
      return path ? `${path}.${key}` : key;
    }
    const found = findForbiddenFeedbackKey(value[key], path ? `${path}.${key}` : key);
    if (found) return found;
  }
  return null;
}

function sanitizeFeedbackTrace(trace = {}) {
  const source = trace && typeof trace === 'object' ? trace : {};
  return removeNullish({
    route: clipFeedbackText(source.route, 80),
    action: clipFeedbackText(source.action, 80),
    source: clipFeedbackText(source.source, 100),
    toolName: clipFeedbackText(source.toolName, 100),
    toolStatus: clipFeedbackText(source.toolStatus, 60),
    renderIntent: clipFeedbackText(source.renderIntent, 80),
    workerUsed: typeof source.workerUsed === 'boolean' ? source.workerUsed : null,
    fallbackUsed: typeof source.fallbackUsed === 'boolean' ? source.fallbackUsed : null,
    workerLatencyMs: parseNumber(source.workerLatencyMs),
    turnDurationMs: parseNumber(source.turnDurationMs),
    productCount: parseNumber(source.productCount),
    finalProductIds: normalizeStringArray(source.finalProductIds).slice(0, MAX_FEEDBACK_PRODUCT_IDS),
    guardBlockedCount: parseNumber(source.guardBlockedCount),
    noMatchReason: clipFeedbackText(source.noMatchReason, 100),
    failureReason: clipFeedbackText(source.failureReason, 100),
  });
}

function sanitizeFeedbackTurn(turn = {}) {
  const source = turn && typeof turn === 'object' ? turn : {};
  return removeNullish({
    turnId: clipDebugIdentifier(source.turnId, 80),
    requestId: clipDebugIdentifier(source.requestId, MAX_REQUEST_ID_LENGTH),
    chatDebugId: clipDebugIdentifier(source.chatDebugId, 120),
    sessionIdHash: clipDebugIdentifier(source.sessionIdHash, 80),
    language: clipFeedbackText(source.language, 8),
    messageLength: parseNumber(source.messageLength),
    route: clipFeedbackText(source.route, 80),
    action: clipFeedbackText(source.action, 80),
    source: clipFeedbackText(source.source, 100),
    toolName: clipFeedbackText(source.toolName, 100),
    toolStatus: clipFeedbackText(source.toolStatus, 60),
    renderIntent: clipFeedbackText(source.renderIntent, 80),
    workerUsed: typeof source.workerUsed === 'boolean' ? source.workerUsed : null,
    fallbackUsed: typeof source.fallbackUsed === 'boolean' ? source.fallbackUsed : null,
    workerLatencyMs: parseNumber(source.workerLatencyMs),
    turnDurationMs: parseNumber(source.turnDurationMs),
    productCount: parseNumber(source.productCount),
    finalProductIds: normalizeStringArray(source.finalProductIds).slice(0, MAX_FEEDBACK_PRODUCT_IDS),
    guardBlockedCount: parseNumber(source.guardBlockedCount),
    noMatchReason: clipFeedbackText(source.noMatchReason, 100),
    failureReason: clipFeedbackText(source.failureReason, 100),
  });
}

function sanitizeTurnDebugPayload(payload = {}) {
  const source = payload && typeof payload === 'object' ? payload : {};
  return removeNullish({
    schemaVersion: 1,
    eventType: 'ai_chat_turn_debug',
    createdAt: clipTimestamp(source.createdAt) || new Date().toISOString(),
    chatDebugId: clipDebugIdentifier(source.chatDebugId, 120),
    turnId: clipDebugIdentifier(source.turnId, 80),
    requestId: clipDebugIdentifier(source.requestId, MAX_REQUEST_ID_LENGTH),
    sessionIdHash: clipDebugIdentifier(source.sessionIdHash, 80),
    language: clipFeedbackText(source.language, 8),
    messageLength: parseNumber(source.messageLength),
    userMessageRedacted: clipFeedbackText(source.userMessageRedacted, MAX_TURN_DEBUG_USER_TEXT_LENGTH),
    assistantReplyRedacted: clipFeedbackText(source.assistantReplyRedacted, MAX_TURN_DEBUG_ASSISTANT_TEXT_LENGTH),
    replyType: clipFeedbackText(source.replyType, 40),
    route: clipFeedbackText(source.route, 80),
    action: clipFeedbackText(source.action, 80),
    source: clipFeedbackText(source.source, 100),
    toolName: clipFeedbackText(source.toolName, 100),
    toolStatus: clipFeedbackText(source.toolStatus, 60),
    renderIntent: clipFeedbackText(source.renderIntent, 80),
    workerUsed: typeof source.workerUsed === 'boolean' ? source.workerUsed : null,
    fallbackUsed: typeof source.fallbackUsed === 'boolean' ? source.fallbackUsed : null,
    workerLatencyMs: parseNumber(source.workerLatencyMs),
    turnDurationMs: parseNumber(source.turnDurationMs),
    productCount: parseNumber(source.productCount),
    finalProductIds: normalizeStringArray(source.finalProductIds).slice(0, MAX_FEEDBACK_PRODUCT_IDS),
    noMatchReason: clipFeedbackText(source.noMatchReason, 100),
    failureReason: clipFeedbackText(source.failureReason, 100),
    feedbackReason: clipFeedbackText(source.feedbackReason, 80),
  });
}

function validateAIChatTurnDebugPayload(input = {}) {
  const payload = input && typeof input === 'object' ? input : {};
  const forbiddenKey = findForbiddenFeedbackKey(payload);
  if (forbiddenKey) {
    return { ok: false, error: `Forbidden turn debug field: ${forbiddenKey}` };
  }
  if (Number(payload.schemaVersion) !== 1) {
    return { ok: false, error: 'schemaVersion must be 1.' };
  }
  if (payload.eventType !== 'ai_chat_turn_debug') {
    return { ok: false, error: 'eventType must be ai_chat_turn_debug.' };
  }
  const sanitized = sanitizeTurnDebugPayload(payload);
  if (!sanitized.chatDebugId) return { ok: false, error: 'chatDebugId is required.' };
  if (!sanitized.turnId) return { ok: false, error: 'turnId is required.' };
  if (!sanitized.sessionIdHash) return { ok: false, error: 'sessionIdHash is required.' };
  return { ok: true, payload: sanitized };
}

function removeNullish(value = {}) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => {
      if (item == null) return false;
      if (Array.isArray(item) && item.length === 0) return false;
      if (typeof item === 'string' && item.trim() === '') return false;
      return true;
    }),
  );
}

function validateAIChatFeedbackPayload(input = {}) {
  const payload = input && typeof input === 'object' ? input : {};
  const forbiddenKey = findForbiddenFeedbackKey(payload);
  if (forbiddenKey) {
    return { ok: false, error: `Forbidden feedback field: ${forbiddenKey}` };
  }
  if (Number(payload.schemaVersion) !== 1) {
    return { ok: false, error: 'schemaVersion must be 1.' };
  }
  if (payload.eventType !== 'ai_chat_negative_feedback') {
    return { ok: false, error: 'eventType must be ai_chat_negative_feedback.' };
  }
  const feedbackId = clipDebugIdentifier(payload.feedbackId, 120);
  if (!feedbackId) return { ok: false, error: 'feedbackId is required.' };

  const feedback = payload.feedback && typeof payload.feedback === 'object' ? payload.feedback : {};
  const reason = clipFeedbackText(feedback.reason, 80);
  if (!AI_CHAT_FEEDBACK_REASONS.has(reason)) {
    return { ok: false, error: 'feedback.reason is invalid.' };
  }
  const rating = clipFeedbackText(feedback.rating, 20);
  if (rating !== 'down' && rating !== 'bad') {
    return { ok: false, error: 'feedback.rating must be bad/down.' };
  }

  const snapshot = payload.snapshot && typeof payload.snapshot === 'object' ? payload.snapshot : {};
  const turns = Array.isArray(snapshot.turns)
    ? snapshot.turns.slice(0, MAX_FEEDBACK_TRACE_TURNS).map(sanitizeFeedbackTurn)
    : [];
  const trace = sanitizeFeedbackTrace(payload.trace);
  const sessionIdHash = clipDebugIdentifier(payload.sessionIdHash ?? trace.sessionIdHash ?? turns.at(-1)?.sessionIdHash, 80);
  const turnId = clipDebugIdentifier(payload.turnId ?? trace.turnId ?? turns.at(-1)?.turnId, 80);
  const requestId = clipDebugIdentifier(payload.requestId ?? trace.requestId ?? turns.at(-1)?.requestId, MAX_REQUEST_ID_LENGTH);
  if (!sessionIdHash) return { ok: false, error: 'sessionIdHash is required.' };
  if (!turnId) return { ok: false, error: 'turnId is required.' };
  if (!requestId) return { ok: false, error: 'requestId is required.' };

  const diagnostics = payload.diagnostics && typeof payload.diagnostics === 'object'
    ? payload.diagnostics
    : {};

  return {
    ok: true,
    payload: {
      schemaVersion: 1,
      eventType: 'ai_chat_negative_feedback',
      feedbackId,
      createdAt: clipTimestamp(payload.createdAt) || new Date().toISOString(),
      environment: clipFeedbackText(payload.environment, 120) || 'unknown',
      sessionIdHash,
      turnId,
      requestId,
      feedback: { rating, reason },
      trace,
      diagnostics: {
        mojibakeDetected: normalizeBoolean(diagnostics.mojibakeDetected, false),
        invalidProductIdDetected: normalizeBoolean(diagnostics.invalidProductIdDetected, false),
        externalCardViolationDetected: normalizeBoolean(diagnostics.externalCardViolationDetected, false),
        genericMessageDetected: normalizeBoolean(diagnostics.genericMessageDetected, false),
      },
      snapshot: {
        turnCount: Math.min(parseNumber(snapshot.turnCount) ?? turns.length, MAX_FEEDBACK_TRACE_TURNS),
        turns,
      },
    },
  };
}

function isWorkerFlagEnabled(value) {
  return String(value ?? '').trim().toLowerCase() === 'true';
}

async function storeAIChatTurnDebug(env, payload) {
  if (!isWorkerFlagEnabled(env?.AI_CHAT_TURN_DEBUG_STORE_ENABLED) || !env?.AI_CHAT_DEBUG_DB) {
    return { stored: false, reason: 'storage_disabled' };
  }
  const db = env.AI_CHAT_DEBUG_DB;
  await db.batch([
    db.prepare(`
      INSERT INTO ai_chat_debug_sessions (
        chat_debug_id, session_id_hash, created_at, last_turn_at, turn_count
      ) VALUES (?, ?, ?, ?, 0)
      ON CONFLICT(chat_debug_id) DO NOTHING
    `).bind(payload.chatDebugId, payload.sessionIdHash, payload.createdAt, payload.createdAt),
    db.prepare(`
      INSERT OR REPLACE INTO ai_chat_debug_turns (
        chat_debug_id, turn_id, request_id, session_id_hash, created_at,
        language, message_length, user_message_redacted, assistant_reply_redacted,
        reply_type, route, action, source, tool_name, tool_status, render_intent,
        worker_used, fallback_used, worker_latency_ms, turn_duration_ms,
        product_count, final_product_ids_json, no_match_reason, failure_reason,
        feedback_reason
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      payload.chatDebugId,
      payload.turnId,
      payload.requestId || null,
      payload.sessionIdHash,
      payload.createdAt,
      payload.language || null,
      payload.messageLength ?? null,
      payload.userMessageRedacted || null,
      payload.assistantReplyRedacted || null,
      payload.replyType || null,
      payload.route || null,
      payload.action || null,
      payload.source || null,
      payload.toolName || null,
      payload.toolStatus || null,
      payload.renderIntent || null,
      payload.workerUsed ? 1 : 0,
      payload.fallbackUsed ? 1 : 0,
      payload.workerLatencyMs ?? null,
      payload.turnDurationMs ?? null,
      payload.productCount ?? 0,
      JSON.stringify(payload.finalProductIds || []),
      payload.noMatchReason || null,
      payload.failureReason || null,
      payload.feedbackReason || null,
    ),
    db.prepare(`
      UPDATE ai_chat_debug_sessions
      SET
        last_turn_at = ?,
        turn_count = (
          SELECT COUNT(*) FROM ai_chat_debug_turns
          WHERE chat_debug_id = ?
        )
      WHERE chat_debug_id = ?
    `).bind(payload.createdAt, payload.chatDebugId, payload.chatDebugId),
  ]);
  return { stored: true };
}

async function storeAIChatFeedbackDebug(env, payload) {
  if (!isWorkerFlagEnabled(env?.AI_CHAT_FEEDBACK_STORE_ENABLED) || !env?.AI_CHAT_DEBUG_DB) {
    return { stored: false, reason: 'storage_disabled' };
  }
  const db = env.AI_CHAT_DEBUG_DB;
  await db.prepare(`
    INSERT OR REPLACE INTO ai_chat_feedback_debug (
      feedback_id, chat_debug_id, session_id_hash, turn_id, request_id, created_at,
      rating, reason, route, source, tool_name, latency_ms, product_ids_json, snapshot_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    payload.feedbackId,
    payload.snapshot?.turns?.at(-1)?.chatDebugId || null,
    payload.sessionIdHash,
    payload.turnId,
    payload.requestId,
    payload.createdAt,
    payload.feedback.rating,
    payload.feedback.reason,
    payload.trace.route || null,
    payload.trace.source || null,
    payload.trace.toolName || null,
    payload.trace.turnDurationMs ?? payload.trace.workerLatencyMs ?? null,
    JSON.stringify(payload.trace.finalProductIds || []),
    JSON.stringify(payload.snapshot || {}),
  ).run();

  await db.prepare(`
    UPDATE ai_chat_debug_turns
    SET feedback_id = ?, feedback_rating = ?, feedback_reason = ?
    WHERE turn_id = ? AND session_id_hash = ?
  `).bind(
    payload.feedbackId,
    payload.feedback.rating,
    payload.feedback.reason,
    payload.turnId,
    payload.sessionIdHash,
  ).run();

  if (payload.snapshot?.turns?.at(-1)?.chatDebugId) {
    await db.prepare(`
      UPDATE ai_chat_debug_sessions
      SET has_negative_feedback = 1
      WHERE chat_debug_id = ?
    `).bind(payload.snapshot.turns.at(-1).chatDebugId).run();
  }

  return { stored: true };
}

function normalizeTimeoutMs(value, fallback = CHAT_MODEL_TIMEOUT_MS) {
  const parsed = parseNumber(value);
  if (parsed == null || parsed <= 0) return fallback;
  return Math.min(Math.max(Math.trunc(parsed), CHAT_MODEL_MIN_TIMEOUT_MS), CHAT_MODEL_MAX_TIMEOUT_MS);
}

function normalizeKnowledgeText(value) {
  return String(value ?? '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\u0600-\u06ff]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function clipText(value, maxLength) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  return text.length <= maxLength ? text : text.slice(0, maxLength);
}

// Structured, sampled logging for unknown keys (Task 24)
function warnOnUnknownKeys(payload, expectedKeys, endpoint) {
  if (!payload || typeof payload !== 'object') return;
  const actualKeys = Object.keys(payload);
  const unknownKeys = actualKeys.filter(k => !expectedKeys.includes(k));
  
  if (unknownKeys.length > 0) {
    // Sample at 10% frequency to prevent log spam during massive abuse
    if (Math.random() < 0.10) {
      logWorkerEvent('schema_unknown_keys_warning', {
        endpoint,
        unknownKeys: unknownKeys.join(','),
        note: 'Payload contains unknown keys which were stripped during sanitization.',
      });
    }
  }
}

function sanitizeTranscriptEntry(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const entry = raw;
  const role = normalizeEnum(entry.role, ['user', 'assistant', 'system']) || 'assistant';
  const messageType = normalizeEnum(entry.messageType, ['text', 'recommendation', 'error']) || 'text';
  const content = clipText(entry.content, MAX_ANALYSIS_SUMMARY_LENGTH);
  const matchSummary = clipText(entry.matchSummary, MAX_ANALYSIS_SUMMARY_LENGTH);
  const productIds = normalizeStringArray(entry.productIds).slice(0, MAX_PRODUCT_IDS);

  if (role === 'user' && messageType === 'text') {
    if (!content) return null;
    return { role, messageType, content };
  }

  if (messageType === 'recommendation') {
    if (productIds.length === 0) return null;
    return {
      role: 'assistant',
      messageType,
      productIds,
      matchSummary: matchSummary || null,
    };
  }

  if (!content) return null;
  return { role, messageType, content };
}

function sanitizeAnalysisPayload(input = {}) {
  const payload = input && typeof input === 'object' ? input : {};
  const transcript = Array.isArray(payload.transcript)
    ? payload.transcript.map(sanitizeTranscriptEntry).filter(Boolean)
    : [];

  return {
    sessionId: String(payload.sessionId ?? '').trim(),
    preferences: sanitizePreferences(payload.preferences),
    transcript,
    originalMessageCount: Number.isFinite(payload.originalMessageCount)
      ? Math.max(0, Math.trunc(payload.originalMessageCount))
      : transcript.length,
    compactedMessageCount: Number.isFinite(payload.compactedMessageCount)
      ? Math.max(0, Math.trunc(payload.compactedMessageCount))
      : transcript.length,
    finalRecommendationMessageId: String(payload.finalRecommendationMessageId ?? '').trim() || null,
    finalRecommendationProductIds: normalizeStringArray(payload.finalRecommendationProductIds),
  };
}

function sanitizeSessionFeedback(input = {}) {
  const feedback = input && typeof input === 'object' ? input : {};
  return {
    id: String(feedback.id ?? feedback.feedbackId ?? '').trim() || null,
    sessionId: String(feedback.sessionId ?? '').trim(),
    userId: String(feedback.userId ?? '').trim(),
    feedbackScope: normalizeEnum(feedback.feedbackScope, ['message', 'session']),
    targetMessageId: String(feedback.targetMessageId ?? '').trim() || null,
    rating: parseNumber(feedback.rating),
    isHelpful: normalizeBoolean(feedback.isHelpful, false),
    comment: clipText(feedback.comment, MAX_ANALYSIS_COMMENT_LENGTH),
    submittedAt: feedback.submittedAt ?? null,
    analysisStatus: normalizeAnalysisStatus(feedback.analysisStatus),
  };
}

function buildAnalysisPrompt({ analysis, sessionFeedback, inlineFeedbackSummary, language }) {
  const transcriptText = analysis.transcript.map((entry, index) => JSON.stringify({ index, ...entry })).join('\n');
  const feedbackText = JSON.stringify(sessionFeedback);
  const summaryText = inlineFeedbackSummary ? JSON.stringify(inlineFeedbackSummary) : 'null';

  return [
    'You are a quality analyst for a perfume recommendation chat.',
    'Return JSON only. Never return markdown.',
    `Write all user-facing text fields in ${language === 'en' ? 'English' : 'Arabic'}.`,
    'Evaluate whether the assistant understood the user intent and satisfied the need.',
    'Use the compacted transcript, session feedback, and optional inline feedback summary.',
    'Also consider the final recommendation product IDs when judging whether the need was satisfied.',
    'Output strictly in this shape:',
    '{ "id": "string", "sessionId": "string", "feedbackId": "string", "intentUnderstood": true, "needSatisfied": true, "satisfactionScore": 0.0, "sentiment": "positive|neutral|negative", "analysisSummary": "short human-readable summary", "failureReason": null, "improvementSuggestion": null, "missingNeeds": [], "rawInput": {}, "rawModelOutput": {}, "analyzedAt": "ISO-8601", "status": "completed" }',
    'Rules:',
    '- satisfactionScore must be between 0 and 1.',
    '- missingNeeds must contain concise short phrases only.',
    '- failureReason and improvementSuggestion should be null when not applicable.',
    '- rawInput should echo the normalized input used for analysis.',
    '- rawModelOutput should capture the exact parsed model output before final normalization.',
    '- If the transcript is too weak or unclear, mark intentUnderstood=false and needSatisfied=false.',
    `Normalized transcript:\n${transcriptText}`,
    `Session feedback:\n${feedbackText}`,
    `Inline feedback summary:\n${summaryText}`,
  ].join('\n');
}

function normalizeAnalysisResponse(rawText, normalizedInput, language) {
  const fallback = {
    id: `${normalizedInput.sessionFeedback.id || normalizedInput.analysis.sessionId}_analysis`,
    sessionId: normalizedInput.analysis.sessionId,
    feedbackId: normalizedInput.sessionFeedback.id || normalizedInput.analysis.finalRecommendationMessageId || normalizedInput.analysis.sessionId,
    intentUnderstood: false,
    needSatisfied: false,
    satisfactionScore: 0,
    sentiment: 'neutral',
    analysisSummary: buildAnalysisSummary({
      intentUnderstood: false,
      needSatisfied: false,
      satisfactionScore: 0,
      sentiment: 'neutral',
      missingNeeds: [],
      language,
    }),
    failureReason: t(language, 'ШЄШ№Ш°Ш± ШЄШ­Щ„ЩЉЩ„ Ш§Щ„ШЄЩ‚ЩЉЩЉЩ… Ш­Ш§Щ„ЩЉЩ‹Ш§.', 'Could not analyze the feedback right now.'),
    improvementSuggestion: null,
    missingNeeds: [],
    rawInput: normalizedInput,
    rawModelOutput: {},
    analyzedAt: new Date().toISOString(),
    status: 'failed',
    metadata: {
      provider: 'openrouter',
      modelId: OPENROUTER_MODEL_ID,
      promptVersion: PROMPT_VERSION,
    },
  };

  try {
    const parsed = extractJsonObject(rawText);
    if (!parsed) {
      return fallback;
    }

    const score = parseNumber(parsed.satisfactionScore);
    const missingNeeds = normalizeStringArray(parsed.missingNeeds).slice(0, MAX_MISSING_NEEDS);
    const rawModelOutput = parsed && typeof parsed === 'object' ? parsed : {};
    const intentUnderstood = normalizeBoolean(parsed.intentUnderstood, fallback.intentUnderstood);
    const needSatisfied = normalizeBoolean(parsed.needSatisfied, fallback.needSatisfied);
    const sentiment = normalizeSentiment(parsed.sentiment);
    const analysisSummary = clipText(parsed.analysisSummary, MAX_ANALYSIS_SUMMARY_LENGTH) || buildAnalysisSummary({
      intentUnderstood,
      needSatisfied,
      satisfactionScore: score == null ? fallback.satisfactionScore : Math.max(0, Math.min(1, score)),
      sentiment,
      missingNeeds,
      language,
    });

    return {
      id: String(parsed.id ?? fallback.id).trim() || fallback.id,
      sessionId: String(parsed.sessionId ?? fallback.sessionId).trim() || fallback.sessionId,
      feedbackId: String(parsed.feedbackId ?? fallback.feedbackId).trim() || fallback.feedbackId,
      intentUnderstood,
      needSatisfied,
      satisfactionScore: score == null ? fallback.satisfactionScore : Math.max(0, Math.min(1, score)),
      sentiment,
      analysisSummary,
      failureReason: clipText(parsed.failureReason, MAX_ANALYSIS_SUMMARY_LENGTH),
      improvementSuggestion: clipText(parsed.improvementSuggestion, MAX_ANALYSIS_SUMMARY_LENGTH),
      missingNeeds,
      rawInput: normalizedInput,
      rawModelOutput,
      analyzedAt: new Date().toISOString(),
      status: 'completed',
      metadata: {
        provider: 'openrouter',
        modelId: OPENROUTER_MODEL_ID,
        promptVersion: PROMPT_VERSION,
        requestId: normalizedInput.requestId || null,
      },
    };
  } catch {
    return fallback;
  }
}

function getFirstEnvValue(env, keys) {
  for (const key of keys) {
    const value = env?.[key];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return null;
}

function buildOpenRouterHeaders(env) {
  const headers = {
    Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
  };

  const referer = getFirstEnvValue(env, ['HTTP-Referer', 'HTTP_REFERER', 'OPENROUTER_HTTP_REFERER']);
  const title = getFirstEnvValue(env, ['X-Title', 'X_TITLE', 'OPENROUTER_X_TITLE']);

  if (referer) {
    headers['HTTP-Referer'] = referer;
  }

  if (title) {
    headers['X-Title'] = title;
  }

  return headers;
}

function getOpenRouterEndpoint(env) {
  return typeof env?.OPENROUTER_ENDPOINT === 'string' && env.OPENROUTER_ENDPOINT.trim()
    ? env.OPENROUTER_ENDPOINT.trim()
    : OPENROUTER_ENDPOINT;
}

function buildOpenRouterPayload({ systemText, userText, temperature, maxTokens }) {
  return {
    model: OPENROUTER_MODEL_ID,
    messages: [
      {
        role: 'system',
        content: systemText,
      },
      {
        role: 'user',
        content: userText,
      },
    ],
    response_format: {
      type: 'json_object',
    },
    temperature,
    max_tokens: maxTokens,
  };
}

function extractOpenRouterContent(responseData) {
  const content = responseData?.choices?.[0]?.message?.content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part === 'object' && typeof part.text === 'string') return part.text;
        return '';
      })
      .filter(Boolean)
      .join('')
      .trim();
  }

  if (typeof content === 'string') {
    return content.trim();
  }

  return '';
}

function normalizeTokenCount(value) {
  const parsed = parseNumber(value);
  if (!Number.isFinite(parsed)) return null;
  return Math.max(0, Math.trunc(parsed));
}

function extractUsageMetrics(responseData) {
  const usage = responseData && typeof responseData === 'object' ? responseData.usage : null;
  return {
    inputTokens: normalizeTokenCount(usage?.prompt_tokens ?? usage?.input_tokens),
    outputTokens: normalizeTokenCount(usage?.completion_tokens ?? usage?.output_tokens),
    totalTokens: normalizeTokenCount(usage?.total_tokens),
  };
}

function extractUpstreamErrorDetails(responseData) {
  const errorObj = responseData && typeof responseData === 'object' ? responseData.error : null;
  if (!errorObj || typeof errorObj !== 'object') {
    return {
      upstreamErrorMessage: null,
      upstreamErrorType: null,
      upstreamErrorCode: null,
    };
  }

  return {
    upstreamErrorMessage: typeof errorObj.message === 'string' ? errorObj.message : null,
    upstreamErrorType: typeof errorObj.type === 'string' ? errorObj.type : null,
    upstreamErrorCode: typeof errorObj.code === 'string' || typeof errorObj.code === 'number'
      ? String(errorObj.code)
      : null,
  };
}

function logWorkerEvent(event, details = {}) {
  const payload = {
    event,
    timestamp: new Date().toISOString(),
    provider: 'openrouter',
    model: OPENROUTER_MODEL_ID,
    ...details,
  };
  console.log(JSON.stringify(payload));
}

function summarizePreferencesForLog(preferences = {}) {
  return {
    gender: preferences.gender ?? null,
    maxBudget: preferences.maxBudget ?? null,
    season: preferences.season ?? null,
    occasion: preferences.occasion ?? null,
    time: preferences.time ?? null,
    intensity: preferences.intensity ?? null,
    preferredNotesCount: Array.isArray(preferences.preferredNotes) ? preferences.preferredNotes.length : 0,
    excludedNotesCount: Array.isArray(preferences.excludedNotes) ? preferences.excludedNotes.length : 0,
    tagsCount: Array.isArray(preferences.tags) ? preferences.tags.length : 0,
  };
}

function summarizeCandidatesForLog(candidates = []) {
  return {
    count: Array.isArray(candidates) ? candidates.length : 0,
    ids: Array.isArray(candidates) ? candidates.slice(0, 5).map((candidate) => candidate.id) : [],
  };
}

function summarizeResponseForLog(normalized = {}) {
  const actionType = normalized?.action_type || normalized?.actionType || 'unknown';
  const productIds = Array.isArray(normalized?.product_ids) ? normalized.product_ids : [];
  return {
    actionType,
    questionLength: typeof normalized?.question === 'string' ? normalized.question.length : 0,
    answerLength: typeof normalized?.answer === 'string' ? normalized.answer.length : 0,
    productCount: productIds.length,
    productIds: productIds.slice(0, 5),
    promptVersion: normalized?.metadata?.promptVersion ?? null,
    requestId: normalized?.metadata?.requestId ?? null,
  };
}

function buildAnalysisSummary({ intentUnderstood, needSatisfied, satisfactionScore, sentiment, missingNeeds, language }) {
  const scoreText = Number.isFinite(satisfactionScore) ? Math.round(satisfactionScore * 100) : 0;
  const missingText = Array.isArray(missingNeeds) && missingNeeds.length > 0
    ? missingNeeds.slice(0, 3).join(', ')
    : null;

  if (language === 'en') {
    const base = intentUnderstood
      ? (needSatisfied ? 'The assistant understood the request and satisfied it.' : 'The assistant understood the request but did not fully satisfy it.')
      : 'The assistant did not clearly understand the request.';
    const sentimentText = `Sentiment: ${sentiment}.`;
    const score = `Satisfaction score: ${scoreText}%.`;
    const missing = missingText ? `Missing needs: ${missingText}.` : '';
    return [base, sentimentText, score, missing].filter(Boolean).join(' ');
  }

  const base = intentUnderstood
    ? (needSatisfied ? 'Ш§Щ„Щ…ШіШ§Ш№ШЇ ЩЃЩ‡Щ… Ш§Щ„Ш·Щ„ШЁ Щ€Щ„ШЁЩ‘Ш§Щ‡.' : 'Ш§Щ„Щ…ШіШ§Ш№ШЇ ЩЃЩ‡Щ… Ш§Щ„Ш·Щ„ШЁ Щ„ЩѓЩ†Щ‡ Щ„Щ… ЩЉЩ„ШЁЩ‘Щ‡ ШЁШ§Щ„ЩѓШ§Щ…Щ„.')
    : 'Ш§Щ„Щ…ШіШ§Ш№ШЇ Щ„Щ… ЩЉЩЃЩ‡Щ… Ш§Щ„Ш·Щ„ШЁ ШЁЩ€Ш¶Щ€Ш­.';
  const sentimentText = `Ш§Щ„Щ…ШґШ§Ш№Ш±: ${sentiment}.`;
  const score = `ШЇШ±Ш¬Ш© Ш§Щ„Ш±Ш¶Ш§: ${scoreText}%.`;
  const missing = missingText ? `Ш§Щ„Ш§Ш­ШЄЩЉШ§Ш¬Ш§ШЄ Ш§Щ„Щ†Ш§Щ‚ШµШ©: ${missingText}.` : '';
  return [base, sentimentText, score, missing].filter(Boolean).join(' ');
}

function sanitizePreferences(input = {}) {
  /** @type {Record<string, any>} */
  const preferences = input && typeof input === 'object' ? input : {};

  return {
    gender: normalizeEnum(preferences.gender, ['men', 'women', 'unisex']),
    maxBudget: parseNumber(preferences.maxBudget),
    season: normalizeEnum(preferences.season, ['summer', 'winter', 'spring', 'autumn', 'all_seasons']),
    occasion: normalizeEnum(preferences.occasion, ['daily', 'university', 'office', 'formal', 'evening', 'date', 'casual']),
    time: normalizeEnum(preferences.time, ['day', 'night', 'all_day']),
    intensity: normalizeEnum(preferences.intensity, ['light', 'medium', 'strong']),
    preferredNotes: normalizeStringArray(preferences.preferredNotes || preferences.notes),
    preferredTopNotes: normalizeStringArray(preferences.preferredTopNotes || preferences.topNotes),
    preferredMiddleNotes: normalizeStringArray(preferences.preferredMiddleNotes || preferences.middleNotes),
    preferredBaseNotes: normalizeStringArray(preferences.preferredBaseNotes || preferences.baseNotes),
    excludedNotes: normalizeStringArray(preferences.excludedNotes),
    tags: normalizeStringArray(preferences.tags),
  };
}

function clampConfidence(value) {
  const parsed = parseNumber(value);
  if (parsed == null) return 0;
  if (parsed < 0) return 0;
  if (parsed > 1) return 1;
  return parsed;
}

function sanitizeReasonCode(value, fallback = 'model_interpretation') {
  const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
  const normalized = raw.replace(/[^a-z0-9_:-]+/g, '_').replace(/^_+|_+$/g, '');
  return (normalized || fallback).slice(0, 80);
}

function emptyInterpretation(reasonCode = 'unclear') {
  return {
    intent: 'unclear',
    confidence: 0,
    preferencePatch: sanitizePreferences({}),
    askSlot: null,
    productQueryCandidate: null,
    reasonCode,
  };
}

function normalizeInterpretationAskSlot(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  return INTERPRETATION_ASK_SLOTS.includes(normalized) ? normalized : null;
}

function normalizeInterpretationResponse(rawInput = {}, fallbackReasonCode = 'model_interpretation') {
  let raw = rawInput;
  if (typeof rawInput === 'string') {
    raw = extractJsonObject(rawInput) || {};
  }
  if (!raw || typeof raw !== 'object') {
    return emptyInterpretation('malformed_interpretation');
  }

  const intent = normalizeEnum(raw.intent, INTERPRETATION_INTENTS) || 'unclear';
  const confidence = clampConfidence(raw.confidence);
  const preferencePatch = sanitizePreferences(
    raw.preferencePatch ||
    raw.preference_patch ||
    raw.preferences ||
    {}
  );
  const askSlot = normalizeInterpretationAskSlot(raw.askSlot || raw.ask_slot);
  const rawProductQueryCandidate =
    raw.productQueryCandidate ||
    raw.product_query_candidate ||
    raw.productQuery ||
    raw.product_query;
  const productQueryCandidate = typeof rawProductQueryCandidate === 'string'
    ? rawProductQueryCandidate.trim().replace(/\s+/g, ' ').slice(0, 120) || null
    : null;

  return {
    intent,
    confidence,
    preferencePatch,
    askSlot,
    productQueryCandidate,
    reasonCode: sanitizeReasonCode(raw.reasonCode || raw.reason_code, fallbackReasonCode),
  };
}

function hasAnyInterpretationPreference(preferences = {}) {
  return Boolean(
    preferences.gender ||
    preferences.maxBudget != null ||
    preferences.season ||
    preferences.occasion ||
    preferences.time ||
    preferences.intensity ||
    preferences.preferredNotes?.length ||
    preferences.preferredTopNotes?.length ||
    preferences.preferredMiddleNotes?.length ||
    preferences.preferredBaseNotes?.length ||
    preferences.excludedNotes?.length ||
    preferences.tags?.length
  );
}

function extractAvailabilityProductCandidate(message) {
  let normalized = normalizeKnowledgeText(message);
  if (!normalized) return null;

  const patterns = [
    /\b(?:do you have|have you got|is|are)\s+(.+?)\s+(?:available|in stock)\b/i,
    /\b(?:do you have|have you got)\s+(.+?)\??$/i,
    /\b(?:is|are)\s+(.+?)\s+(?:available|in stock)\??$/i,
    /\b(?:price|cost)\s+(?:of|for)\s+(.+?)\??$/i,
    /\bhow much\s+(?:is|for)?\s*(.+?)\??$/i,
    /(?:سعر|بكام|بكم|كم سعر)\s+(.+?)\??$/i,
    /(.+?)\s+(?:بكام|بكم)\??$/i,
  ];

  for (const pattern of patterns) {
    const match = pattern.exec(normalized);
    if (!match?.[1]) continue;
    const candidate = cleanAvailabilityProductCandidate(match[1]);
    if (candidate) return candidate;
  }

  return null;
}

function cleanAvailabilityProductCandidate(value) {
  let candidate = String(value ?? '').trim().toLowerCase();
  candidate = candidate
    .replace(/[؟?!.]+$/g, '')
    .replace(/\b(a|an|the|perfume|fragrance|scent|cologne|please|pls)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const generic = new Set([
    'perfume',
    'fragrance',
    'scent',
    'cologne',
    'men',
    "men's",
    'women',
    "women's",
    'types',
    'kinds',
    'categories',
    'best',
    'عطر',
    'برفان',
    'رجالي',
    'حريمي',
    'انواع',
    'الانواع',
  ]);
  if (!candidate || generic.has(candidate)) return null;
  if (candidate.length < 3 || candidate.length > 120) return null;
  return candidate;
}

function buildHeuristicInterpretation(message, responseLanguage = 'ar', currentPreferences = {}) {
  const rawMessage = String(message ?? '').trim().toLowerCase();
  const normalized = normalizeKnowledgeText(message);
  if (!normalized) return emptyInterpretation('empty_message');

  const patch = {};
  let intent = 'unclear';
  let confidence = 0.35;
  let askSlot = null;
  let productQueryCandidate = null;
  let reasonCode = 'heuristic_unclear';

  const hasRecommendationVerb =
    /\b(recommend|reccomend|recomend|suggest|sugest|show|give)\b/.test(normalized) ||
    normalized.includes('\u0631\u0634\u062d') ||
    normalized.includes('\u0627\u0642\u062a\u0631\u062d');
  const hasPerfumeWord =
    /\b(perfume|fragrance|scent|smell|cologne|attar)\b/.test(normalized) ||
    normalized.includes('\u0639\u0637\u0631') ||
    normalized.includes('\u0631\u064a\u062d') ||
    normalized.includes('\u0631\u0627\u064a\u062d');
  const hasAvailabilityWord =
    /\b(available|availble|avialable|in stock|do you have|have you got)\b/.test(normalized) ||
    normalized.includes('\u0645\u062a\u0648\u0641\u0631') ||
    normalized.includes('\u0645\u0648\u062c\u0648\u062f') ||
    normalized.includes('\u0639\u0646\u062f\u0643');
  const hasPriceWord =
    /\b(price|cost|how much)\b/.test(normalized) ||
    normalized.includes('\u0633\u0639\u0631') ||
    normalized.includes('\u0628\u0643\u0627\u0645') ||
    normalized.includes('\u0628\u0643\u0645');

  if (/^(hi|hello|hey|salam|السلام|اهلا|أهلا|مرحبا)\b/.test(normalized)) {
    return normalizeInterpretationResponse({
      intent: 'greeting',
      confidence: 0.92,
      preferencePatch: {},
      askSlot: null,
      reasonCode: 'heuristic_greeting',
    });
  }

  if (
    normalized.includes('reccomend') ||
    normalized.includes('recomend') ||
    normalized.includes('somthing') ||
    normalized.includes('something very good') ||
    normalized.includes('just suggest') ||
    normalized === 'suggest' ||
    normalized === 'suggest perfumes' ||
    normalized === 'suggest perfume'
  ) {
    intent = 'recommendation';
    confidence = 0.86;
    askSlot = hasAnyInterpretationPreference(currentPreferences) ? null : 'gender';
    reasonCode = 'heuristic_recommendation_typo';
  }

  if (
    rawMessage.includes('للأثنين') ||
    rawMessage.includes('للاثنين') ||
    rawMessage.includes('للاتنين') ||
    rawMessage.includes('للجنسين') ||
    normalized.includes('\u0644\u0644\u0627\u062b\u0646\u064a\u0646') ||
    normalized.includes('\u0644\u0644\u0623\u062b\u0646\u064a\u0646') ||
    normalized.includes('\u0644\u0644\u0627\u062a\u0646\u064a\u0646') ||
    normalized.includes('\u0644\u0644\u062c\u0646\u0633\u064a\u0646') ||
    normalized.includes('\u0631\u062c\u0627\u0644\u064a \u0648\u062d\u0631\u064a\u0645\u064a') ||
    normalized.includes('\u0631\u062c\u0627\u0644\u064a \u0648 \u062d\u0631\u064a\u0645\u064a')
  ) {
    intent = 'recommendation';
    confidence = 0.9;
    patch.gender = 'unisex';
    reasonCode = 'heuristic_unisex_arabic';
  }

  if (
    rawMessage.includes('قوة الرواح') ||
    rawMessage.includes('قوه الرواح') ||
    rawMessage.includes('قوة الروايح') ||
    rawMessage.includes('قوه الروايح') ||
    normalized.includes('\u0642\u0648\u0629 \u0627\u0644\u0631\u0648\u0627\u062d') ||
    normalized.includes('\u0642\u0648\u0647 \u0627\u0644\u0631\u0648\u0627\u062d') ||
    normalized.includes('\u0642\u0648\u0629 \u0627\u0644\u0631\u0648\u0627\u064a\u062d') ||
    normalized.includes('\u0642\u0648\u0647 \u0627\u0644\u0631\u0648\u0627\u064a\u062d') ||
    normalized.includes('\u0641\u0648\u062d\u0627\u0646') ||
    normalized.includes('\u062b\u0628\u0627\u062a') ||
    normalized.includes('projection') ||
    normalized.includes('long lasting')
  ) {
    intent = 'recommendation';
    confidence = 0.84;
    patch.intensity = 'strong';
    patch.tags = ['long_lasting'];
    askSlot = currentPreferences.maxBudget ? null : 'maxBudget';
    reasonCode = 'heuristic_strength_preference';
  }

  if (
    normalized.includes('\u0644\u064a\u0633 \u0639\u0646\u062f\u064a \u0641\u0643\u0631\u0629') ||
    normalized.includes('\u0645\u0634 \u0639\u0627\u0631\u0641') ||
    normalized.includes('\u0645\u0634 \u0639\u0646\u062f\u064a \u0641\u0643\u0631\u0629') ||
    normalized.includes('no idea')
  ) {
    intent = 'recommendation';
    confidence = 0.78;
    askSlot = hasAnyInterpretationPreference(currentPreferences) ? null : 'gender';
    reasonCode = 'heuristic_open_choice';
  }

  if (
    normalized.includes('\u062e\u0644\u064a\u0637 \u0628\u064a\u0646 \u0631\u064a\u062d\u062a\u064a\u0646') ||
    normalized.includes('\u062e\u0644\u064a\u0637 \u0628\u064a\u0646 \u0631\u0627\u064a\u062d\u062a\u064a\u0646') ||
    normalized.includes('\u062e\u0644\u064a\u0637 \u0628\u064a\u0646 \u0646\u0648\u062a\u062a\u064a\u0646') ||
    normalized.includes('mix of two') ||
    normalized.includes('between two scents')
  ) {
    intent = 'recommendation';
    confidence = 0.82;
    askSlot = 'notesOrIntensity';
    patch.tags = ['blend'];
    reasonCode = 'heuristic_blend_request';
  }

  if (hasRecommendationVerb && hasPerfumeWord && confidence < 0.75) {
    intent = 'recommendation';
    confidence = 0.76;
    askSlot = hasAnyInterpretationPreference(currentPreferences) ? null : 'gender';
    reasonCode = 'heuristic_perfume_recommendation';
  }

  if ((hasAvailabilityWord || hasPriceWord) && confidence < 0.85) {
    const candidate = extractAvailabilityProductCandidate(message);
    if (candidate) {
      intent = 'availability';
      confidence = 0.82;
      askSlot = null;
      productQueryCandidate = candidate;
      reasonCode = hasPriceWord
        ? 'heuristic_price_product_candidate'
        : 'heuristic_availability_product_candidate';
    }
  }

  return normalizeInterpretationResponse({
    intent,
    confidence,
    preferencePatch: patch,
    askSlot,
    productQueryCandidate,
    reasonCode,
  });
}

function sanitizePreferencePatch(input = {}) {
  const raw = input && typeof input === 'object' ? input : {};
  const allowedScalars = new Set(['gender', 'maxBudget', 'season', 'occasion', 'time', 'intensity']);
  const allowedLists = new Set([
    'preferredNotes',
    'preferredTopNotes',
    'preferredMiddleNotes',
    'preferredBaseNotes',
    'excludedNotes',
    'tags',
  ]);

  const clearScalars = [];
  if (Array.isArray(raw.clearScalars)) {
    for (const item of raw.clearScalars) {
      const key = String(item ?? '').trim();
      if (allowedScalars.has(key)) clearScalars.push(key);
    }
  }
  if (raw.clear && typeof raw.clear === 'object') {
    for (const [key, value] of Object.entries(raw.clear)) {
      if (value === true && allowedScalars.has(key)) clearScalars.push(key);
    }
  }

  const sanitizeListMap = (value) => {
    const result = {};
    if (!value || typeof value !== 'object') return result;
    for (const [key, rawList] of Object.entries(value)) {
      if (!allowedLists.has(key) || !Array.isArray(rawList)) continue;
      result[key] = normalizeStringArray(rawList);
    }
    return result;
  };

  const patch = {
    clearScalars: [...new Set(clearScalars)],
    setScalars: sanitizeScalarMap(raw.setScalars || raw.replaceScalars),
    replaceLists: sanitizeListMap(raw.replaceLists),
    appendLists: sanitizeListMap(raw.appendLists),
    removeLists: sanitizeListMap(raw.removeLists || raw.removeFromLists),
  };

  if (
    patch.clearScalars.length === 0 &&
    Object.keys(patch.setScalars).length === 0 &&
    Object.keys(patch.replaceLists).length === 0 &&
    Object.keys(patch.appendLists).length === 0 &&
    Object.keys(patch.removeLists).length === 0
  ) {
    return null;
  }
  return patch;

  function sanitizeScalarMap(value) {
    const result = {};
    if (!value || typeof value !== 'object') return result;
    for (const [key, rawValue] of Object.entries(value)) {
      if (!allowedScalars.has(key)) continue;
      if (rawValue === null || rawValue === undefined) continue;
      result[key] = key === 'maxBudget' ? parseNumber(rawValue) : String(rawValue).trim();
    }
    return result;
  }
}

function applyPreferencePatch(preferences, preferencePatch) {
  if (!preferencePatch) return preferences;
  const result = { ...preferences };
  for (const scalar of preferencePatch.clearScalars || []) {
    result[scalar] = null;
  }
  for (const [key, value] of Object.entries(preferencePatch.setScalars || {})) {
    result[key] = value;
  }
  for (const [key, values] of Object.entries(preferencePatch.replaceLists || {})) {
    result[key] = values;
  }
  for (const [key, values] of Object.entries(preferencePatch.appendLists || {})) {
    result[key] = normalizeStringArray([...(result[key] || []), ...values]);
  }
  for (const [key, values] of Object.entries(preferencePatch.removeLists || {})) {
    const removals = new Set(values.map((item) => String(item).toLowerCase()));
    result[key] = normalizeStringArray(result[key] || [])
      .filter((item) => !removals.has(String(item).toLowerCase()));
  }
  return sanitizePreferences(result);
}

/**
 * Merges a partial preference patch onto the current session snapshot (Merge Policy).
 * Rules:
 * 1. Null or undefined in patch does NOT wipe out base.
 * 2. Empty arrays in patch do NOT wipe out base.
 * 3. Scalars only update if they have a non-null value.
 */
function mergePreferences(base, patch) {
  const result = { ...base };

  for (const key in patch) {
    const patchValue = patch[key];
    const baseValue = base[key];

    if (Array.isArray(patchValue)) {
      // Rule 2: Empty arrays do not wipe out existing data
      if (patchValue.length > 0) {
        result[key] = patchValue;
      } else {
        result[key] = baseValue || [];
      }
    } else {
      // Rule 1: Null/undefined does not wipe out existing data
      if (patchValue !== null && patchValue !== undefined) {
        result[key] = patchValue;
      } else {
        result[key] = baseValue;
      }
    }
  }

  return result;
}

function sanitizeCandidate(raw) {
  if (!raw || typeof raw !== 'object') return null;

  /** @type {Record<string, any>} */
  const item = raw;

  const id = String(item.id ?? '').trim();
  const name = String(item.name ?? '').trim();
  if (!id || !name) return null;

  const rawBudgetStatus = normalizeEnum(item.budgetStatus, [
    'withinbudget',
    'slightlyabovebudget',
    'within_budget',
    'slightly_above_budget',
  ]);
  const budgetStatus = rawBudgetStatus === 'withinbudget' || rawBudgetStatus === 'within_budget'
    ? 'withinBudget'
    : rawBudgetStatus === 'slightlyabovebudget' || rawBudgetStatus === 'slightly_above_budget'
      ? 'slightlyAboveBudget'
      : null;

  return {
    id,
    name,
    price: parseNumber(item.price),
    budgetStatus,
    exactBudget: parseNumber(item.exactBudget),
    overBudgetAmount: parseNumber(item.overBudgetAmount),
    gender: typeof item.gender === 'string' ? item.gender.trim().toLowerCase() : '',
    season: typeof item.season === 'string' ? item.season.trim().toLowerCase() : '',
    occasion: typeof item.occasion === 'string' ? item.occasion.trim().toLowerCase() : '',
    time: typeof item.time === 'string' ? item.time.trim().toLowerCase() : '',
    intensity: typeof item.intensity === 'string' ? item.intensity.trim().toLowerCase() : '',
    notes: normalizeStringArray(item.notes),
    topNotes: normalizeStringArray(item.topNotes),
    middleNotes: normalizeStringArray(item.middleNotes),
    baseNotes: normalizeStringArray(item.baseNotes),
    tags: normalizeStringArray(item.tags),
    localMatchReason: typeof item.localMatchReason === 'string'
      ? item.localMatchReason.trim().slice(0, 180)
      : '',
    reasonFacts: sanitizeReasonFacts(item.reasonFacts),
  };
}

function sanitizeReasonFacts(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const budget = raw.budget && typeof raw.budget === 'object' ? raw.budget : {};
  const productProfile = raw.productProfile && typeof raw.productProfile === 'object'
    ? raw.productProfile
    : {};
  return {
    localMatchReason: typeof raw.localMatchReason === 'string'
      ? raw.localMatchReason.trim().slice(0, 180)
      : '',
    matchLabel: typeof raw.matchLabel === 'string' ? raw.matchLabel.trim().slice(0, 80) : '',
    matchScore: parseNumber(raw.matchScore),
    matchedNotes: normalizeStringArray(raw.matchedNotes).slice(0, 3),
    matchedContext: normalizeStringArray(raw.matchedContext).slice(0, 5),
    budget: {
      exactBudget: parseNumber(budget.exactBudget),
      price: parseNumber(budget.price),
      withinBudget: Boolean(budget.withinBudget),
      budgetStatus: typeof budget.budgetStatus === 'string'
        ? budget.budgetStatus.trim().slice(0, 40)
        : '',
    },
    productProfile: {
      family: typeof productProfile.family === 'string'
        ? productProfile.family.trim().slice(0, 80)
        : '',
      notes: normalizeStringArray(productProfile.notes).slice(0, 4),
      topNotes: normalizeStringArray(productProfile.topNotes).slice(0, 3),
      middleNotes: normalizeStringArray(productProfile.middleNotes).slice(0, 3),
      baseNotes: normalizeStringArray(productProfile.baseNotes).slice(0, 3),
      tags: normalizeStringArray(productProfile.tags).slice(0, 4),
    },
    cautions: normalizeStringArray(raw.cautions).slice(0, 3),
  };
}

function sanitizeCandidates(input) {
  if (!Array.isArray(input)) return [];
  return input
    .slice(0, MAX_CANDIDATES)
    .map(sanitizeCandidate)
    .filter(Boolean);
}

function selectChatModelCandidates(candidates) {
  if (!Array.isArray(candidates)) return [];
  return candidates.slice(0, CHAT_MODEL_PROMPT_CANDIDATE_LIMIT);
}

function sanitizeConversationContext(body = {}) {
  const recentMessages = Array.isArray(body.recentMessages)
    ? body.recentMessages
        .slice(-6)
        .map((item) => {
          const role = item?.role === 'assistant' ? 'assistant' : 'user';
          const text = redactSensitiveText(String(item?.text || '').trim()).slice(0, 240);
          return text ? { role, text } : null;
        })
        .filter(Boolean)
    : [];
  const lastAssistantQuestion = typeof body.lastAssistantQuestion === 'string'
    ? redactSensitiveText(body.lastAssistantQuestion.trim()).slice(0, 240)
    : '';
  const lastAskSlot = ['gender', 'season', 'maxBudget', 'notesOrIntensity'].includes(body.lastAskSlot)
    ? body.lastAskSlot
    : '';
  const lastVisibleProductIds = normalizeStringArray(body.lastVisibleProductIds)
    .filter(isSafeFirestoreDocumentId)
    .slice(0, MAX_PRODUCT_IDS);
  const visibleProducts = Array.isArray(body.visibleProducts)
    ? body.visibleProducts
        .slice(0, 5)
        .map((item) => sanitizeVisibleContextProduct(item))
        .filter(Boolean)
    : [];
  const lastFocusedProductId = isSafeFirestoreDocumentId(body.lastFocusedProductId)
    ? String(body.lastFocusedProductId).trim()
    : null;
  const lastRecommendationIds = normalizeStringArray(body.lastRecommendationIds)
    .filter(isSafeFirestoreDocumentId)
    .slice(0, 10);
  const rejectedProductIds = normalizeStringArray(body.rejectedProductIds)
    .filter(isSafeFirestoreDocumentId)
    .slice(0, 20);
  const allowedTools = normalizeStringArray(body.allowedTools)
    .filter((tool) => TOOL_ROUTER_ALLOWED_TOOLS.has(tool))
    .slice(0, 25);
  const pendingClarification = sanitizePendingClarification(body.pendingClarification);
  const pendingPerfumeReferenceClarification =
    sanitizePendingPerfumeReferenceClarification(body.pendingPerfumeReferenceClarification);
  const lastExternalProfile = sanitizeLastExternalProfile(body.lastExternalProfile);
  const lastNoMatch = sanitizeLastNoMatchContext(body.lastNoMatch);
  const currentPreferences = sanitizePreferences(body.currentPreferences || {});
  const conversationContext = body.conversationContext && typeof body.conversationContext === 'object'
    ? body.conversationContext
    : {};

  return {
    recentMessages,
    lastAssistantQuestion,
    lastAskSlot,
    lastVisibleProductIds,
    visibleProducts,
    lastFocusedProductId,
    lastRecommendationIds,
    pendingClarification,
    pendingPerfumeReferenceClarification,
    lastExternalProfile,
    lastNoMatch,
    currentPreferences,
    rejectedProductIds,
    allowedTools,
    conversationContext: {
      hasRecommendationContext: conversationContext.hasRecommendationContext === true,
      hasAvailabilityContext: conversationContext.hasAvailabilityContext === true,
      lastTurnWasAsk: conversationContext.lastTurnWasAsk === true,
    },
  };
}

function sanitizePendingPerfumeReferenceClarification(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const query = clipText(raw.query || '', 120);
  const options = Array.isArray(raw.options)
    ? raw.options
        .slice(0, 5)
        .map((item) => {
          if (!item || typeof item !== 'object') return null;
          const index = normalizeInteger(item.index);
          const name = clipText(item.name || '', 100);
          if (!index || !name) return null;
          const source = ['catalog', 'perfumeKnowledge', 'externalLookup'].includes(item.source)
            ? item.source
            : 'externalLookup';
          return {
            index,
            name,
            brand: clipText(item.brand || '', 80),
            source,
            productId: isSafeFirestoreDocumentId(item.productId) ? String(item.productId).trim() : null,
            externalProfileId: isSafeFirestoreDocumentId(item.externalProfileId) ? String(item.externalProfileId).trim() : null,
            confidence: clampConfidence(item.confidence),
          };
        })
        .filter(Boolean)
    : [];
  if (!query || options.length === 0) return null;
  return { query, options };
}

function sanitizeLastExternalProfile(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = String(raw.id || '').trim();
  const name = clipText(raw.name || '', 100);
  if (!isSafeFirestoreDocumentId(id) || !name) return null;
  return {
    id,
    name,
    brand: clipText(raw.brand || '', 80),
    family: clipText(raw.family || raw.fragranceFamily || '', 80),
    notes: normalizeStringArray(raw.notes).slice(0, 8),
    tags: normalizeStringArray(raw.tags).slice(0, 8),
    source: clipText(raw.source || 'perfume_knowledge', 60),
    confidence: clampConfidence(raw.confidence),
  };
}

function sanitizeVisibleContextProduct(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = String(raw.id || '').trim();
  if (!isSafeFirestoreDocumentId(id)) return null;
  return {
    index: normalizeInteger(raw.index) || null,
    id,
    name: clipText(raw.name || '', 90),
    brand: clipText(raw.brand || '', 60),
    price: parseNumber(raw.price),
    gender: clipText(raw.gender || '', 30),
    family: clipText(raw.family || raw.fragranceFamily || '', 60),
    season: clipText(raw.season || '', 30),
    occasion: clipText(raw.occasion || '', 30),
    time: clipText(raw.time || '', 30),
    intensity: clipText(raw.intensity || '', 30),
    notes: normalizeStringArray(raw.notes).slice(0, 8),
    tags: normalizeStringArray(raw.tags).slice(0, 8),
  };
}

function sanitizePendingClarification(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const type = typeof raw.type === 'string' ? clipText(raw.type.trim(), 80) : '';
  const options = Array.isArray(raw.options)
    ? raw.options
        .slice(0, 5)
        .map((item) => {
          const id = String(item?.id || '').trim();
          if (!isSafeFirestoreDocumentId(id)) return null;
          return {
            index: normalizeInteger(item.index) || null,
            id,
            name: clipText(item.name || '', 90),
          };
        })
        .filter(Boolean)
    : [];
  if (!type && options.length === 0) return null;
  return { type, options };
}

function sanitizeLastNoMatchContext(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const reason = typeof raw.reason === 'string' ? clipText(raw.reason.trim(), 80) : '';
  const lowestAvailableProductIds = normalizeStringArray(raw.lowestAvailableProductIds)
    .filter(isSafeFirestoreDocumentId)
    .slice(0, 5);
  if (!reason && lowestAvailableProductIds.length === 0) return null;
  return {
    reason,
    requestedBudget: parseNumber(raw.requestedBudget),
    lowestAvailablePrice: parseNumber(raw.lowestAvailablePrice),
    lowestAvailableProductIds,
  };
}

function redactSensitiveText(value) {
  return String(value || '')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[redacted_email]')
    .replace(/(?<!\d)(?:\+?\d[\d\s().-]{7,}\d)(?!\d)/g, '[redacted_phone]')
    .replace(/\b(?:\d[ -]*?){13,19}\b/g, '[redacted_payment]');
}

async function resolveCatalogCandidates(env, submittedCandidates, loader = fetchCatalogProductsByIds) {
  if (env?.ENFORCE_CATALOG_TRUTH !== 'true') {
    return submittedCandidates;
  }

  const submittedById = new Map(submittedCandidates.map((candidate) => [candidate.id, candidate]));
  const productIds = [];
  const seen = new Set();
  for (const candidate of submittedCandidates) {
    const id = String(candidate?.id || '').trim();
    if (!isSafeFirestoreDocumentId(id) || seen.has(id)) continue;
    seen.add(id);
    productIds.push(id);
    if (productIds.length >= MAX_CANDIDATES) break;
  }

  if (productIds.length === 0) return [];

  const products = await loader(env, productIds);
  return products
    .filter((product) => seen.has(String(product?.id || '').trim()))
    .map((product) => {
      const candidate = productToCandidate(product);
      const submitted = submittedById.get(candidate.id);
      if (!submitted) return candidate;
      return {
        ...candidate,
        budgetStatus: submitted.budgetStatus,
        exactBudget: submitted.exactBudget,
        overBudgetAmount: submitted.overBudgetAmount,
        localMatchReason: submitted.localMatchReason,
        reasonFacts: submitted.reasonFacts,
      };
    })
    .map(sanitizeCandidate)
    .filter(Boolean);
}

function isSafeFirestoreDocumentId(id) {
  return /^[A-Za-z0-9_-]{1,128}$/.test(String(id || ''));
}

function productToCandidate(product) {
  const productId = String(product?.id || '').trim();
  const price = parseNumber(product?.price);
  const salePrice = parseNumber(product?.salePrice);
  const effectivePrice = salePrice > 0 && price > 0 && salePrice < price ? salePrice : price;

  return {
    id: productId,
    name: String(product?.name || '').trim(),
    price: effectivePrice,
    gender: typeof product?.gender === 'string' ? product.gender : '',
    season: typeof product?.season === 'string' ? product.season : '',
    occasion: typeof product?.occasion === 'string' ? product.occasion : 'daily',
    time: typeof product?.time === 'string' ? product.time : 'all_day',
    intensity: typeof product?.intensity === 'string' ? product.intensity : 'medium',
    notes: normalizeStringArray(product?.notes),
    topNotes: normalizeStringArray(product?.topNotes),
    middleNotes: normalizeStringArray(product?.middleNotes),
    baseNotes: normalizeStringArray(product?.baseNotes),
    tags: normalizeStringArray(product?.tags),
  };
}

async function fetchCatalogProductsByIds(env, productIds) {
  const projectId = String(env?.FIREBASE_PROJECT_ID || '').trim();
  if (!projectId) {
    throw new Error('Missing FIREBASE_PROJECT_ID for catalog verification');
  }

  const accessToken = await getCatalogGoogleAccessToken(env);
  const documents = productIds.map((id) =>
    `projects/${projectId}/databases/(default)/documents/products/${id}`
  );

  const response = await fetchWithMethodTimeout(
    `${FIRESTORE_API_BASE}/projects/${projectId}/databases/(default)/documents:batchGet`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ documents }),
    },
    CATALOG_FETCH_TIMEOUT_MS,
  );

  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`Firestore catalog lookup failed (${response.status})`);
  }

  const rows = JSON.parse(raw || '[]');
  if (!Array.isArray(rows)) return [];

  return rows
    .map((row) => row?.found)
    .filter(Boolean)
    .map((document) => ({
      id: documentIdFromName(document.name),
      ...decodeFirestoreDocument(document),
    }));
}

function documentIdFromName(name) {
  return String(name || '').split('/').pop() || '';
}

function decodeFirestoreDocument(document) {
  const fields = document?.fields || {};
  const out = {};
  for (const [key, value] of Object.entries(fields)) {
    out[key] = fromFirestoreValue(value);
  }
  return out;
}

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return Boolean(value.booleanValue);
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue?.values || []).map(fromFirestoreValue);
  }
  if ('mapValue' in value) {
    const out = {};
    const fields = value.mapValue?.fields || {};
    for (const [key, child] of Object.entries(fields)) {
      out[key] = fromFirestoreValue(child);
    }
    return out;
  }
  return null;
}

function cleanupRateLimitStore(now) {
  for (const [key, timestamps] of rateLimitStore.entries()) {
    const fresh = timestamps.filter((timestamp) => now - timestamp < RATE_LIMIT_WINDOW_MS);
    if (fresh.length === 0) {
      rateLimitStore.delete(key);
    } else {
      rateLimitStore.set(key, fresh);
    }
  }
}

function getClientKey(request, body, verifiedUid = null) {
  // Prefer the cryptographically verified Firebase UID (Task 16).
  // Fall back to body-supplied sessionKey only when no verified identity exists.
  if (verifiedUid) return `uid:${verifiedUid}`;

  const sessionKey = typeof body.sessionKey === 'string'
    ? body.sessionKey.trim().slice(0, MAX_REQUEST_ID_LENGTH)
    : '';
  if (sessionKey) return `session:${sessionKey}`;

  const cfIp = request.headers.get('CF-Connecting-IP') || '';
  if (cfIp.trim()) return `ip:${cfIp.trim()}`;

  return 'anonymous';
}

async function checkRateLimit(key, now, env) {
  // If Upstash is configured, use it for distributed rate limiting.
  if (env?.UPSTASH_REDIS_REST_URL && env?.UPSTASH_REDIS_REST_TOKEN) {
    try {
      if (!upstashRatelimiter) {
        const redis = new Redis({
          url: env.UPSTASH_REDIS_REST_URL,
          token: env.UPSTASH_REDIS_REST_TOKEN,
        });
        upstashRatelimiter = new Ratelimit({
          redis,
          limiter: Ratelimit.slidingWindow(RATE_LIMIT_MAX_REQUESTS, `${RATE_LIMIT_WINDOW_MS / 1000} s`),
          analytics: false,
          ephemeralCache: rateLimitStore, // Use the existing map as an L1 cache to reduce Redis calls
        });
      }
      const { success } = await upstashRatelimiter.limit(`ratelimit:${key}`);
      return success;
    } catch (err) {
      logWorkerEvent('ratelimit_error', {
        note: 'Upstash Redis failed, falling back to in-memory limit.',
        errorName: err?.name || 'UnknownError',
        errorMessage: err?.message || 'Unknown error',
      });
      // Fall through to in-memory if Redis fails to ensure fail-open UX with local limits.
    }
  }

  // Fallback: In-memory rate limiting
  cleanupRateLimitStore(now);
  const timestamps = rateLimitStore.get(key) || [];
  // Ensure we only count numbers for in-memory timestamp arrays
  const validTimestamps = timestamps.filter((t) => typeof t === 'number');
  const fresh = validTimestamps.filter((timestamp) => now - timestamp < RATE_LIMIT_WINDOW_MS);
  
  if (fresh.length >= RATE_LIMIT_MAX_REQUESTS) {
    rateLimitStore.set(key, fresh);
    return false;
  }
  
  fresh.push(now);
  rateLimitStore.set(key, fresh);
  return true;
}

function defaultAsk(preferences, language, question = null, requestId = null) {
  return {
    action_type: 'ask',
    question: question || t(
      language,
      'ممكن توضح النوع أو النوتات أو الميزانية التقريبية عشان أرشح لك بشكل أفضل؟',
      'Could you share your preferred notes or approximate budget so I can recommend better?'
    ),
    updated_preferences: preferences,
    metadata: {
      provider: 'openrouter',
      modelId: OPENROUTER_MODEL_ID,
      promptVersion: PROMPT_VERSION,
      requestId,
    },
  };
}

function extractJsonObject(rawContent) {
  let clean = String(rawContent ?? '').trim();
  if (!clean) return null;

  if (clean.startsWith('```json')) clean = clean.slice(7);
  else if (clean.startsWith('```')) clean = clean.slice(3);
  if (clean.endsWith('```')) clean = clean.slice(0, -3);

  const startIndex = clean.indexOf('{');
  const endIndex = clean.lastIndexOf('}');
  if (startIndex === -1 || endIndex === -1 || endIndex <= startIndex) {
    return null;
  }

  const jsonText = clean.slice(startIndex, endIndex + 1).trim();
  if (!jsonText) return null;

  try {
    const parsed = JSON.parse(jsonText);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
}

function normalizeModelResponse(rawText, candidates, fallbackPreferences, language, requestId = null) {
  try {
    const parsed = extractJsonObject(rawText);
    if (!parsed) {
      return defaultAsk(fallbackPreferences, language, null, requestId);
    }

    const candidateMap = new Map(candidates.map((c) => [c.id, c]));
    const candidateIds = new Set(candidateMap.keys());
    const maxBudget = fallbackPreferences.maxBudget;

    const rawActionType = typeof parsed.action_type === 'string'
      ? parsed.action_type.trim().toLowerCase()
      : '';
    const actionType = rawActionType === 'recommend'
      ? 'recommend'
      : (rawActionType === 'answer' || rawActionType === 'info')
        ? 'answer'
        : 'ask';
    
    // Task 32: Apply Merge Policy (Defensive State Management)
    const patch = sanitizePreferences(parsed.updated_preferences || {});
    const preferencePatch = sanitizePreferencePatch(parsed.preference_patch || parsed.preferencePatch);
    const updatedPreferences = applyPreferencePatch(
      mergePreferences(fallbackPreferences, patch),
      preferencePatch,
    );

    if (actionType === 'ask') {
      if (!preferencePatch && shouldOverrideAskWithCandidateRecommendation(candidates, updatedPreferences)) {
        logWorkerEvent('ask_overridden_to_recommend', {
          endpoint: '/api/chat',
          requestId,
          candidateCount: candidates.length,
          reason: 'clear_filtered_candidates',
        });
        return buildCandidateRecommendationResponse(
          candidates,
          updatedPreferences,
          language,
          requestId,
          preferencePatch,
        );
      }
      const question = typeof parsed.question === 'string' && parsed.question.trim()
        ? parsed.question.trim()
        : defaultAsk(updatedPreferences, language).question;
      return {
        action_type: 'ask',
        question,
        updated_preferences: updatedPreferences,
        ...(preferencePatch ? { preference_patch: preferencePatch } : {}),
        metadata: {
          provider: 'openrouter',
          modelId: OPENROUTER_MODEL_ID,
          promptVersion: PROMPT_VERSION,
          requestId,
        },
      };
    }

    if (actionType === 'answer') {
      const answer = typeof parsed.answer === 'string' && parsed.answer.trim()
        ? parsed.answer.trim()
        : typeof parsed.response === 'string' && parsed.response.trim()
          ? parsed.response.trim()
          : defaultAsk(updatedPreferences, language, null, requestId).question;
      return {
        action_type: 'answer',
        answer,
        updated_preferences: updatedPreferences,
        ...(preferencePatch ? { preference_patch: preferencePatch } : {}),
        metadata: {
          provider: 'openrouter',
          modelId: OPENROUTER_MODEL_ID,
          promptVersion: PROMPT_VERSION,
          requestId,
        },
      };
    }

    const requestedIdsBeforeFilter = normalizeStringArray(parsed.product_ids).slice(0, MAX_PRODUCT_IDS);
    const requestedIds = normalizeStringArray(parsed.product_ids)
      .filter((id) => {
        const product = candidateMap.get(id);
        if (!product) return false;

        // 1. Budget Hard Rule (110% Upsell Limit)
        if (maxBudget && product.price > maxBudget * 1.1) return false;

        // 2. Gender Hard Rule
        const prefGender = updatedPreferences.gender;
        if (prefGender && prefGender !== 'unisex') {
          const productGender = product.gender;
          // Product must match or be unisex
          if (productGender && productGender !== 'unisex' && productGender !== prefGender) {
            return false;
          }
        }

        // 3. Excluded Notes Hard Rule
        if (Array.isArray(updatedPreferences.excludedNotes) && updatedPreferences.excludedNotes.length > 0) {
          const allProductNotes = [
            ...(product.notes || []),
            ...(product.topNotes || []),
            ...(product.middleNotes || []),
            ...(product.baseNotes || []),
          ].map(n => String(n).toLowerCase());

          const hasExcludedNote = updatedPreferences.excludedNotes.some(excluded => 
            allProductNotes.includes(String(excluded).toLowerCase())
          );
          if (hasExcludedNote) return false;
        }

        return true;
      })
      .slice(0, MAX_PRODUCT_IDS);

    // Task 35: Deterministic No-Match Fallback
    // If the model wanted to recommend but all its choices were filtered out, 
    // we must fallback to a polite "Ask" instead of returning an empty recommendation.
    if (actionType === 'recommend' && requestedIds.length === 0) {
      logWorkerEvent('recommendation_filtered_to_ask', {
        endpoint: '/api/chat',
        requestId,
        requestedIds: requestedIdsBeforeFilter,
        reason: 'all_requested_candidates_filtered_out',
      });
      return defaultAsk(
        updatedPreferences, 
        language,
        t(
          language,
          'ШўШіЩЃШЊ Щ„Щ… ШЈШ¬ШЇ Ш№Ш·Ш±Ш§Щ‹ ЩЉШ·Ш§ШЁЩ‚ Ш¬Щ…ЩЉШ№ ШґШ±Щ€Ш·Щѓ ШЁШЇЩ‚Ш© (ШЁЩ…Ш§ ЩЃЩЉ Ш°Щ„Щѓ Ш§Щ„Щ…ЩЉШІШ§Щ†ЩЉШ© Щ€Ш§Щ„Щ†Щ€ШЄШ§ШЄ Ш§Щ„Щ…ШіШЄШЁШ№ШЇШ©). Щ‡Щ„ ЩЉЩ…ЩѓЩ†Щ†Ш§ ШЄШ¬Ш±ШЁШ© Щ…Щ€Ш§ШµЩЃШ§ШЄ Щ…Ш®ШЄЩ„ЩЃШ©Шџ',
          'Sorry, I couldn\'t find a perfume that matches all your criteria exactly (including budget and excluded notes). Shall we try different criteria?'
        ),
        requestId
      );
    }

    const rawReasons = parsed.match_reason && typeof parsed.match_reason === 'object'
      ? parsed.match_reason
      : {};

    if (requestedIds.length === 0) {
      logWorkerEvent('recommendation_empty_after_filter', {
        endpoint: '/api/chat',
        requestId,
        reason: 'no_valid_candidate_ids',
      });
      return defaultAsk(
        updatedPreferences,
        language,
        t(
          language,
          'ШЈШ­ШЄШ§Ш¬ ШЄЩЃШµЩЉЩ„Ш© ШҐШ¶Ш§ЩЃЩЉШ© Щ€Ш§Ш­ШЇШ© Ш­ШЄЩ‰ ШЈШ±ШґШ­ Щ„Щѓ ШЁШЇЩ‚Ш©. Щ‡Щ„ ШЄЩЃШ¶Щ„ Ш№Ш§Ш¦Щ„Ш© Щ†Щ€ШЄШ§ШЄ Щ…Ш№ЩЉЩ†Ш© ШЈЩ€ Щ…ЩЉШІШ§Щ†ЩЉШ© Щ…Ш­ШЇШЇШ©Шџ',
          'I need one more detail to recommend safely. Could you tell me the note family or budget you prefer?'
        ),
        requestId
      );
    }

    const matchReason = {};
    for (const id of requestedIds) {
      const product = candidateMap.get(id);
      const rawReason = rawReasons[id];
      matchReason[id] = sanitizeWorkerMatchReason(rawReason, product, language);
    }

    return {
      action_type: 'recommend',
      product_ids: requestedIds,
      match_reason: matchReason,
      updated_preferences: updatedPreferences,
      ...(preferencePatch ? { preference_patch: preferencePatch } : {}),
      metadata: {
        provider: 'openrouter',
        modelId: OPENROUTER_MODEL_ID,
        promptVersion: PROMPT_VERSION,
        requestId,
      },
    };
  } catch {
    return defaultAsk(fallbackPreferences, language);
  }
}

function normalizeModelResponseV2(rawText, candidates, fallbackPreferences, language, requestId = null, toolRouterEnabled = false) {
  const parsed = extractJsonObject(rawText);
  if (!parsed || Number(parsed.schemaVersion) !== 2) {
    return normalizeLegacyModelResponseAsV2(
      rawText,
      candidates,
      fallbackPreferences,
      language,
      requestId
    );
  }

  const rawType = String(parsed.type || '').trim();
  if (rawType === 'tool_call') {
    if (toolRouterEnabled) {
      const toolCall = sanitizeStructuredToolCall(parsed.toolCall || parsed.tool_call);
      if (toolCall) {
        const preferencePatch = sanitizePreferencePatch(
          parsed.preferencesPatch || parsed.preferencePatch || parsed.preference_patch,
        );
        return {
          schemaVersion: 2,
          type: 'tool_call',
          language,
          message: safeStructuredMessage(
            typeof parsed.message === 'string' && parsed.message.trim()
              ? parsed.message.trim()
              : defaultStructuredMessage('message', language),
            'message',
            language
          ),
          toolCall,
          commands: [],
          recommendations: [],
          ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
          metadata: structuredMetadata(requestId),
        };
      }
    }
    return {
      schemaVersion: 2,
      type: 'no_match',
      language,
      message: defaultStructuredMessage('no_match', language),
      commands: [{ action: 'show_no_match', productIds: [] }],
      recommendations: [],
      metadata: structuredMetadata(requestId),
    };
  }

  const candidateMap = new Map(candidates.map((candidate) => [candidate.id, candidate]));
  const allowedTypes = new Set([
    'message',
    'ask',
    'recommendation',
    'no_match',
    'availability',
    'comparison',
    'refusal',
    'error',
  ]);
  const type = allowedTypes.has(rawType)
    ? rawType
    : 'message';
  const preferencePatch = sanitizePreferencePatch(
    parsed.preferencesPatch || parsed.preferencePatch || parsed.preference_patch,
  );
  const updatedPreferences = applyPreferencePatch(fallbackPreferences, preferencePatch);
  const commands = sanitizeStructuredCommands(parsed.commands, candidateMap, updatedPreferences);
  const recommendations = sanitizeStructuredRecommendations(
    parsed.recommendations,
    candidateMap,
    commands,
    language,
  );
  const message = safeStructuredMessage(
    typeof parsed.message === 'string' && parsed.message.trim()
    ? parsed.message.trim()
    : defaultStructuredMessage(type, language),
    type,
    language
  );

  if (type === 'no_match' && hasValidCandidateFallback(candidates, updatedPreferences)) {
    logWorkerEvent('no_match_overridden_to_recommend', {
      endpoint: '/api/chat',
      requestId,
      candidateCount: candidates.length,
      reason: 'valid_filtered_candidates_available',
    });
    return buildStructuredCandidateRecommendationResponse(
      candidates,
      updatedPreferences,
      language,
      requestId,
      preferencePatch,
    );
  }

  if (type === 'ask' && commands.length === 0 && shouldOverrideAskWithCandidateRecommendation(candidates, updatedPreferences)) {
    return normalizeLegacyModelResponseAsV2(
      JSON.stringify(buildCandidateRecommendationResponse(
        candidates,
        updatedPreferences,
        language,
        requestId,
        preferencePatch
      )),
      candidates,
      updatedPreferences,
      language,
      requestId
    );
  }

  const hasCardCommand = commands.some((command) =>
    command.action === 'show_recommendation_cards' ||
    command.action === 'show_product_card'
  );
  if (type === 'recommendation' && !hasCardCommand && hasValidCandidateFallback(candidates, updatedPreferences)) {
    logWorkerEvent('recommendation_filled_from_candidates', {
      endpoint: '/api/chat',
      requestId,
      candidateCount: candidates.length,
      reason: 'model_omitted_valid_card_command',
    });
    return buildStructuredCandidateRecommendationResponse(
      candidates,
      updatedPreferences,
      language,
      requestId,
      preferencePatch,
    );
  }
  if (type === 'availability' && !hasCardCommand) {
    const availabilityCandidateIds = selectFallbackCandidateIds(candidates, updatedPreferences, MAX_PRODUCT_IDS);
    if (availabilityCandidateIds.length === 1) {
      const availabilityMessage = genericStructuredCardMessage(message, type, language)
        ? defaultStructuredMessage('availability', language)
        : message;
      return {
        schemaVersion: 2,
        type: 'availability',
        language,
        message: availabilityMessage,
        commands: [{ action: 'show_product_card', productIds: availabilityCandidateIds }],
        recommendations: sanitizeStructuredRecommendations(
          [],
          candidateMap,
          [{ action: 'show_product_card', productIds: availabilityCandidateIds }],
          language,
        ),
        ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
        metadata: structuredMetadata(requestId),
      };
    }
  }
  if ((type === 'recommendation' || type === 'availability') && !hasCardCommand) {
    return {
      schemaVersion: 2,
      type: 'no_match',
      language,
      message: defaultStructuredMessage('no_match', language),
      commands: [{ action: 'show_no_match', productIds: [] }],
      recommendations: [],
      ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
      metadata: structuredMetadata(requestId),
    };
  }

  const finalMessage = type === 'no_match' && updatedPreferences?.maxBudget
    ? defaultStructuredMessage('no_match', language)
    : hasCardCommand && genericStructuredCardMessage(message, type, language)
      ? defaultStructuredMessage(type, language)
      : message;

  return {
    schemaVersion: 2,
    type,
    language,
    message: finalMessage,
    commands,
    recommendations,
    ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
    metadata: structuredMetadata(requestId),
  };
}

function normalizeLegacyModelResponseAsV2(rawText, candidates, fallbackPreferences, language, requestId = null) {
  const legacy = normalizeModelResponse(
    rawText,
    candidates,
    fallbackPreferences,
    language,
    requestId
  );
  const actionType = String(legacy?.action_type || '').trim();
  const preferencePatch = sanitizePreferencePatch(
    legacy?.preference_patch || legacy?.preferencePatch,
  );
  const productIds = Array.isArray(legacy?.product_ids)
    ? legacy.product_ids.map((id) => String(id || '').trim()).filter(Boolean).slice(0, 3)
    : [];
  const matchReason = legacy?.match_reason && typeof legacy.match_reason === 'object'
    ? legacy.match_reason
    : {};

  if (actionType === 'recommend' && productIds.length > 0) {
    return {
      schemaVersion: 2,
      type: 'recommendation',
      language,
      message: defaultStructuredMessage('recommendation', language),
      commands: [{ action: 'show_recommendation_cards', productIds }],
      recommendations: productIds.map((productId) => ({
        productId,
        reason: typeof matchReason[productId] === 'string'
          ? clipText(matchReason[productId], 180)
          : defaultReason(language),
      })),
      ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
      metadata: structuredMetadata(requestId),
    };
  }

  if (actionType === 'answer' || actionType === 'info') {
    return {
      schemaVersion: 2,
      type: 'message',
      language,
      message: safeStructuredMessage(
        legacy?.answer || legacy?.response || defaultStructuredMessage('message', language),
        'message',
        language
      ),
      commands: [],
      recommendations: [],
      ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
      metadata: structuredMetadata(requestId),
    };
  }

  return {
    schemaVersion: 2,
    type: 'ask',
    language,
    message: safeStructuredMessage(
      legacy?.question || defaultStructuredMessage('ask', language),
      'ask',
      language
    ),
    commands: [],
    recommendations: [],
    ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
    metadata: structuredMetadata(requestId),
  };
}

function sanitizeStructuredCommands(rawCommands, candidateMap, preferences) {
  if (!Array.isArray(rawCommands)) return [];
  const allowedActions = new Set([
    'show_recommendation_cards',
    'show_product_card',
    'keep_visible_cards',
    'show_no_match',
  ]);
  const commands = [];
  for (const rawCommand of rawCommands) {
    if (!rawCommand || typeof rawCommand !== 'object') continue;
    const action = String(rawCommand.action || '').trim();
    if (!allowedActions.has(action)) continue;
    let productIds = normalizeStringArray(rawCommand.productIds || rawCommand.product_ids)
      .filter((id) => {
        const product = candidateMap.get(id);
        if (!product) return false;
        return isCandidateAllowedForPreferences(product, preferences);
      })
      .slice(0, action === 'show_product_card' ? 1 : MAX_PRODUCT_IDS);
    if ((action === 'show_recommendation_cards' || action === 'show_product_card') && productIds.length === 0) {
      continue;
    }
    commands.push({
      action,
      productIds,
      ...(typeof rawCommand.displayMode === 'string' ? { displayMode: rawCommand.displayMode.slice(0, 40) } : {}),
    });
  }
  return commands;
}

function sanitizeStructuredToolCall(rawToolCall) {
  if (!rawToolCall || typeof rawToolCall !== 'object' || Array.isArray(rawToolCall)) {
    return null;
  }
  const name = String(rawToolCall.name || '').trim();
  if (!TOOL_ROUTER_ALLOWED_TOOLS.has(name)) return null;
  const rawArguments = rawToolCall.arguments;
  if (rawArguments != null && (typeof rawArguments !== 'object' || Array.isArray(rawArguments))) {
    return null;
  }
  const argumentsObject = rawArguments && typeof rawArguments === 'object'
    ? sanitizeToolArguments(name, rawArguments)
    : {};
  if (argumentsObject == null) return null;
  const confidence = clampConfidence(rawToolCall.confidence ?? rawToolCall.confidenceScore);
  return {
    name,
    arguments: argumentsObject,
    ...(confidence > 0 ? { confidence } : {}),
  };
}

function sanitizeToolArguments(name, rawArguments) {
  switch (name) {
    case 'search_products':
    case 'get_cheapest_products':
    case 'get_most_expensive_products':
    case 'cheapest_catalog':
    case 'most_expensive_catalog':
      return sanitizeProductSearchToolArguments(rawArguments);
    case 'update_preferences': {
      const patch = sanitizePreferencePatch(
        rawArguments.preferencePatch || rawArguments.preference_patch || rawArguments.patch,
      );
      if (!patch) return null;
      return { preferencePatch: patch };
    }
    case 'update_preferences_and_recommend': {
      const patch = sanitizePreferencePatch(
        rawArguments.preferencePatch || rawArguments.preference_patch || rawArguments.patch,
      );
      if (!patch) return null;
      return { preferencePatch: patch };
    }
    case 'similar_cheaper':
    case 'cheaper_followup':
      return sanitizeReferenceToolArguments(rawArguments);
    case 'show_lowest_available_after_budget_no_match':
    case 'reject_visible_products':
      return sanitizeContextToolArguments(rawArguments);
    case 'resolve_perfume_reference':
    case 'lookup_external_perfume_profile':
    case 'recommend_similar_to_external_profile':
    case 'similar_cheaper_to_external_profile':
      return sanitizePerfumeReferenceToolArguments(rawArguments);
    case 'select_perfume_reference_option':
      return sanitizePerfumeReferenceSelectionToolArguments(rawArguments);
    case 'answer_product_question':
    case 'ask_product_clarification':
    case 'ask_clarification':
      return sanitizeClarificationToolArguments(rawArguments);
    default:
      return null;
  }
}

function sanitizePerfumeReferenceToolArguments(rawArguments) {
  const args = {};
  for (const field of ['query', 'name', 'brand', 'externalProfileId', 'profileId']) {
    if (typeof rawArguments[field] === 'string' && rawArguments[field].trim()) {
      args[field] = clipText(rawArguments[field].trim(), 120);
    }
  }
  const limit = normalizeInteger(rawArguments.limit ?? rawArguments.maxResults);
  if (limit != null) args.limit = Math.min(Math.max(limit, 1), 5);
  return args;
}

function sanitizePerfumeReferenceSelectionToolArguments(rawArguments) {
  const args = {};
  if (typeof rawArguments.userReply === 'string' && rawArguments.userReply.trim()) {
    args.userReply = clipText(rawArguments.userReply.trim(), 120);
  }
  for (const field of ['selectedName', 'name']) {
    if (typeof rawArguments[field] === 'string' && rawArguments[field].trim()) {
      args[field] = clipText(rawArguments[field].trim(), 120);
    }
  }
  const selectedIndex = normalizeInteger(rawArguments.selectedIndex ?? rawArguments.index);
  if (selectedIndex != null) args.selectedIndex = selectedIndex;
  return args;
}

function sanitizeProductSearchToolArguments(rawArguments) {
  const args = {};
  const stringFields = ['gender', 'season', 'occasion', 'time', 'intensity', 'family', 'brand', 'sort'];
  for (const field of stringFields) {
    if (typeof rawArguments[field] === 'string' && rawArguments[field].trim()) {
      args[field] = clipText(rawArguments[field].trim(), 60);
    }
  }
  const maxPrice = parseNumber(rawArguments.maxPrice ?? rawArguments.maxBudget);
  if (maxPrice != null && maxPrice > 0) args.maxPrice = maxPrice;
  const minPrice = parseNumber(rawArguments.minPrice);
  if (minPrice != null && minPrice >= 0) args.minPrice = minPrice;
  const limit = normalizeInteger(rawArguments.limit);
  if (limit != null) args.limit = Math.min(Math.max(limit, 1), 5);
  for (const field of ['notes', 'tags']) {
    const values = normalizeStringArray(rawArguments[field])
      .map((value) => clipText(value, 40))
      .filter(Boolean)
      .slice(0, 8);
    if (values.length > 0) args[field] = values;
  }
  return args;
}

function sanitizeReferenceToolArguments(rawArguments) {
  const args = {};
  for (const field of [
    'anchorRef',
    'anchorProductId',
    'anchorId',
    'productId',
    'selectedProductId',
    'anchorName',
    'productName',
    'name',
  ]) {
    if (typeof rawArguments[field] === 'string' && rawArguments[field].trim()) {
      args[field] = clipText(rawArguments[field].trim(), 120);
    }
  }
  for (const field of ['selectedIndex', 'visibleIndex', 'index', 'limit']) {
    const value = normalizeInteger(rawArguments[field]);
    if (value != null) args[field] = field === 'limit' ? Math.min(Math.max(value, 1), 5) : value;
  }
  return args;
}

function sanitizeContextToolArguments(rawArguments) {
  const args = {};
  const limit = normalizeInteger(rawArguments.limit);
  if (limit != null) args.limit = Math.min(Math.max(limit, 1), 5);
  for (const field of ['productIds', 'rejectedProductIds', 'lowestAvailableProductIds']) {
    const values = normalizeStringArray(rawArguments[field])
      .map((value) => clipText(value, 120))
      .filter(Boolean)
      .slice(0, 10);
    if (values.length > 0) args[field] = values;
  }
  for (const field of ['requestedBudget', 'lowestAvailablePrice']) {
    const value = parseNumber(rawArguments[field]);
    if (value != null && value >= 0) args[field] = value;
  }
  return args;
}

function sanitizeClarificationToolArguments(rawArguments) {
  const args = {};
  if (typeof rawArguments.question === 'string' && rawArguments.question.trim()) {
    args.question = clipText(rawArguments.question.trim(), 240);
  }
  if (typeof rawArguments.clarificationType === 'string' && rawArguments.clarificationType.trim()) {
    args.clarificationType = clipText(rawArguments.clarificationType.trim(), 80);
  }
  const patch = sanitizePreferencePatch(
    rawArguments.preferencePatch || rawArguments.preference_patch || rawArguments.patch,
  );
  if (patch) args.preferencePatch = patch;
  return args;
}

function normalizeInteger(value) {
  const number = parseNumber(value);
  if (number == null || !Number.isFinite(number)) return null;
  return Math.trunc(number);
}

function sanitizeStructuredRecommendations(rawRecommendations, candidateMap, commands, language) {
  if (!Array.isArray(rawRecommendations)) return [];
  const commandIds = new Set(commands.flatMap((command) => command.productIds || []));
  const recommendations = [];
  const seen = new Set();
  for (const item of rawRecommendations) {
    if (!item || typeof item !== 'object') continue;
    const productId = String(item.productId || item.product_id || '').trim();
    if (!commandIds.has(productId) || seen.has(productId)) continue;
    seen.add(productId);
    const product = candidateMap.get(productId);
    recommendations.push({
      productId,
      reason: sanitizeWorkerMatchReason(item.reason, product, language),
    });
  }
  for (const productId of commandIds) {
    if (seen.has(productId)) continue;
    const product = candidateMap.get(productId);
    recommendations.push({
      productId,
      reason: buildGroundedMatchReason(product, language),
    });
  }
  return recommendations.slice(0, MAX_PRODUCT_IDS);
}

function isCandidateAllowedForPreferences(product, preferences) {
  const maxBudget = preferences.maxBudget;
  if (maxBudget && product.price > maxBudget * 1.1) return false;
  const prefGender = preferences.gender;
  if (prefGender && prefGender !== 'unisex') {
    const productGender = product.gender;
    if (productGender && productGender !== 'unisex' && productGender !== prefGender) return false;
  }
  if (Array.isArray(preferences.excludedNotes) && preferences.excludedNotes.length > 0) {
    const allProductNotes = [
      ...(product.notes || []),
      ...(product.topNotes || []),
      ...(product.middleNotes || []),
      ...(product.baseNotes || []),
    ].map((note) => String(note).toLowerCase());
    return !preferences.excludedNotes.some((excluded) =>
      allProductNotes.includes(String(excluded).toLowerCase())
    );
  }
  return true;
}

function selectFallbackCandidateIds(candidates, preferences, limit = MAX_PRODUCT_IDS) {
  if (!Array.isArray(candidates) || candidates.length === 0) return [];
  return candidates
    .filter((candidate) => candidate?.id && isCandidateAllowedForPreferences(candidate, preferences || {}))
    .map((candidate) => String(candidate.id).trim())
    .filter(Boolean)
    .slice(0, limit);
}

function hasValidCandidateFallback(candidates, preferences) {
  return selectFallbackCandidateIds(candidates, preferences, 1).length > 0;
}

function buildStructuredCandidateRecommendationResponse(
  candidates,
  updatedPreferences,
  language,
  requestId = null,
  preferencePatch = null,
  extraMetadata = null,
) {
  const productIds = selectFallbackCandidateIds(candidates, updatedPreferences, MAX_PRODUCT_IDS);
  const candidateMap = new Map(candidates.map((candidate) => [candidate.id, candidate]));
  return {
    schemaVersion: 2,
    type: 'recommendation',
    language,
    message: defaultStructuredMessage('recommendation', language),
    commands: [{ action: 'show_recommendation_cards', productIds }],
    recommendations: productIds.map((productId) => {
      const product = candidateMap.get(productId);
      return {
        productId,
        reason: buildGroundedMatchReason(product, language),
      };
    }),
    ...(preferencePatch ? { preferencesPatch: preferencePatch } : {}),
    metadata: {
      ...structuredMetadata(requestId),
      ...(extraMetadata && typeof extraMetadata === 'object' ? extraMetadata : {}),
    },
  };
}

function buildCandidateTimeoutFallbackResponse(
  candidates,
  preferences,
  language,
  requestId = null,
  latencyMs = null,
  reasonCode = 'model_timeout_candidate_fallback',
) {
  return buildStructuredCandidateRecommendationResponse(
    candidates,
    preferences,
    language,
    requestId,
    null,
    {
      fallbackReason: reasonCode,
      modelTimedOut: true,
      modelTimeoutHit: true,
      fallbackFromCandidates: true,
      ...(latencyMs != null ? { modelLatencyMs: latencyMs } : {}),
    },
  );
}

function defaultStructuredMessage(type, language) {
  if (type === 'ask') {
    return defaultAsk({}, language).question;
  }
  if (type === 'recommendation') {
    return t(
      language,
      'اخترت لك أقرب ترشيحات آمنة من الكتالوج حسب طلبك.',
      'I found the closest safe catalog matches based on your request.'
    );
  }
  if (type === 'availability') {
    return t(
      language,
      'هذا المنتج ظاهر عندي من الكتالوج، والكارت يوضح السعر والتوفر الحالي.',
      'This product is available from the catalog; the card shows the current price and stock.'
    );
  }
  if (type === 'no_match') {
    return t(
      language,
      'لا أقدر أعرض ترشيح آمن من البيانات الحالية.',
      'I cannot show a safe recommendation from the current data.'
    );
  }
  return t(
    language,
    'تمام.',
    'Understood.'
  );
}

function genericStructuredCardMessage(message, type, language) {
  if (type !== 'recommendation' && type !== 'availability') return false;
  const text = String(message || '').trim();
  if (!text) return true;
  const normalized = text
    .toLowerCase()
    .replace(/[.!؟?،,\s]+/g, ' ')
    .trim();
  const generic = new Set([
    'understood',
    'okay',
    'ok',
    'sure',
    'done',
    'تمام',
    'حاضر',
    'اكيد',
    'أكيد',
  ]);
  if (generic.has(normalized)) return true;
  return normalized.length > 0 && normalized.length <= 8;
}

function defaultArabicStructuredAskMessage() {
  return 'ممكن توضح النوع أو النوتات أو الميزانية التقريبية عشان أرشح لك بشكل أفضل؟';
}

function ambiguousEgyptianSweetQuestion() {
  return 'تقصد ريحة مسكرة وحلوة، ولا ريحة جميلة ولطيفة عمومًا؟';
}

function looksLikeMojibake(text) {
  if (!text || typeof text !== 'string') return false;
  return /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/.test(text) ||
    text.includes('????');
}

function safeStructuredMessage(message, type, language) {
  const clipped = clipText(message || defaultStructuredMessage(type, language), 700);
  if (language !== 'ar' || !looksLikeMojibake(clipped)) return clipped;
  if (type === 'ask') {
    return defaultArabicStructuredAskMessage();
  }
  if (type === 'recommendation' || type === 'availability' || type === 'message') {
    return defaultStructuredMessage(type, language);
  }
  return defaultStructuredMessage('no_match', language);
}

function isAmbiguousEgyptianSweetRequest(currentMessage) {
  const text = normalizeKnowledgeText(currentMessage);
  if (!text) return false;
  const hasSweetAmbiguity =
    text.includes('ريحة حلو') ||
    text.includes('ريحه حلو') ||
    text.includes('عطر حلو') ||
    text.includes('برفان حلو') ||
    text.includes('حلوة ريحة') ||
    text.includes('حلوه ريحه') ||
    text.includes('حلوة عطر') ||
    text.includes('حلوه عطر');
  if (!hasSweetAmbiguity) return false;
  const explicitSugary = [
    'مسكر',
    'مسكره',
    'مسكرة',
    'سكر',
    'سكريات',
    'سويت',
    'sweet',
    'sugary',
    'vanilla',
    'فانيلا',
  ].some((token) => text.includes(token));
  return !explicitSugary;
}

function buildDeterministicStructuredChatResponse(currentMessage, language, requestId) {
  const text = normalizeKnowledgeText(currentMessage);
  const raw = String(currentMessage || '').toLowerCase();
  if (!text && !raw) return null;

  if (
    raw.includes('ignore instructions') ||
    raw.includes('invent products') ||
    text.includes('انس التعليمات') ||
    text.includes('اخترع منتجات')
  ) {
    return {
      schemaVersion: 2,
      type: 'refusal',
      language,
      message: t(
        language,
        'مش هقدر أتجاهل قواعد النظام أو أخترع منتجات خارج الكتالوج. أقدر أساعدك فقط من المنتجات المتاحة.',
        'I cannot ignore system rules or invent products outside the catalog. I can only help with available catalog products.'
      ),
      commands: [],
      recommendations: [],
      metadata: structuredMetadata(requestId),
    };
  }

  if (language === 'ar' && isAmbiguousEgyptianSweetRequest(currentMessage)) {
    const question = ambiguousEgyptianSweetQuestion();
    return {
      schemaVersion: 2,
      type: 'ask',
      language,
      message: question,
      commands: [],
      recommendations: [],
      metadata: {
        ...structuredMetadata(requestId),
        reasonCode: 'ambiguous_egyptian_sweet_fast_path',
      },
    };
  }

  if (
    raw.includes('layering') ||
    raw.includes('eau de parfum') ||
    raw.includes('eau de toilette') ||
    /\bedp\b/.test(raw) ||
    /\bedt\b/.test(raw)
  ) {
    return {
      schemaVersion: 2,
      type: 'message',
      language,
      message: t(
        language,
        'Eau de Parfum عادةً تركيزه أعلى ويدوم أكثر، بينما Eau de Toilette أخف وأنسب للاستخدام اليومي. في layering ابدأ بالأخف ثم الأعمق، وسيب دقيقة بين كل طبقة.',
        'Eau de Parfum is usually more concentrated and lasts longer, while Eau de Toilette is lighter and often better for daily use. For layering, start with the lighter scent, then add the deeper one, leaving about a minute between layers.'
      ),
      commands: [],
      recommendations: [],
      metadata: structuredMetadata(requestId),
    };
  }

  if (raw.includes('batman black')) {
    return {
      schemaVersion: 2,
      type: 'message',
      language,
      message: t(
        language,
        'الاسم ده مش موجود في الكتالوج الحالي. لو توصف ريحته أو تقول عايزها غامقة/جلدية/دخانية أقدر أقرب لك بديل من المتاح.',
        'That name is not in the current catalog. If you describe the scent, for example dark, leathery, or smoky, I can suggest the closest available alternative.'
      ),
      commands: [],
      recommendations: [],
      metadata: structuredMetadata(requestId),
    };
  }

  return null;
}

function structuredMetadata(requestId) {
  return {
    schemaVersion: 2,
    provider: 'openrouter',
    modelId: OPENROUTER_MODEL_ID,
    promptVersion: STRUCTURED_PROMPT_VERSION,
    requestId,
  };
}

function shouldOverrideAskWithCandidateRecommendation(candidates, preferences) {
  if (!Array.isArray(candidates) || candidates.length === 0) return false;
  const hasScentSignal = [
    ...(preferences?.preferredNotes || []),
    ...(preferences?.preferredTopNotes || []),
    ...(preferences?.preferredMiddleNotes || []),
    ...(preferences?.preferredBaseNotes || []),
    ...(preferences?.tags || []),
  ].some((item) => String(item || '').trim());
  return Boolean(
    hasScentSignal ||
    preferences?.gender ||
    preferences?.maxBudget ||
    preferences?.season ||
    preferences?.occasion ||
    preferences?.time ||
    preferences?.intensity,
  );
}

function isClearRecommendationRefinement(currentMessage, conversation = {}) {
  const text = normalizeKnowledgeText(currentMessage);
  if (!text) return false;
  const hasContext = conversation?.conversationContext?.hasRecommendationContext === true ||
    Array.isArray(conversation?.lastRecommendationIds) && conversation.lastRecommendationIds.length > 0 ||
    Array.isArray(conversation?.lastVisibleProductIds) && conversation.lastVisibleProductIds.length > 0 ||
    Array.isArray(conversation?.visibleProducts) && conversation.visibleProducts.length > 0;
  if (!hasContext) return false;
  const refinementPhrases = [
    'make it suitable for',
    'make them suitable for',
    'suitable for',
    'for university',
    'for campus',
    'for office',
    'for work',
    'for wedding',
    'for date',
    'خليه مناسب',
    'خليها مناسبة',
    'خليهم مناسبين',
    'ينفع للجامعة',
    'للجامعة',
    'للشغل',
    'للمكتب',
    'لفرح',
    'لميعاد',
  ];
  return refinementPhrases.some((phrase) => text.includes(phrase));
}

function buildCandidateRecommendationResponse(
  candidates,
  updatedPreferences,
  language,
  requestId = null,
  preferencePatch = null,
) {
  const productIds = candidates
    .map((candidate) => String(candidate?.id || '').trim())
    .filter(Boolean)
    .slice(0, MAX_PRODUCT_IDS);
  const matchReason = {};
  for (const id of productIds) {
    const candidate = candidates.find((item) => String(item?.id || '').trim() === id);
    matchReason[id] = buildGroundedMatchReason(candidate, language);
  }
  return {
    action_type: 'recommend',
    product_ids: productIds,
    match_reason: matchReason,
    updated_preferences: updatedPreferences,
    ...(preferencePatch ? { preference_patch: preferencePatch } : {}),
    metadata: {
      provider: 'openrouter',
      modelId: OPENROUTER_MODEL_ID,
      promptVersion: PROMPT_VERSION,
      requestId,
    },
  };
}

function buildChatSystemPrompt(responseLanguage) {
  return [
    'You are a concise perfume assistant for a domain-constrained e-commerce chat.',
    'Return RAW JSON only. Do not use markdown or prose outside the JSON object.',
    `Write every user-facing field in ${responseLanguage === 'en' ? 'English' : 'Arabic'}.`,
    'Allowed response shapes:',
    'recommend: { "action_type": "recommend", "product_ids": ["id_1"], "match_reason": { "id_1": "short reason" }, "updated_preferences": { ... } }',
    'ask: { "action_type": "ask", "question": "one short targeted question", "updated_preferences": { ... } }',
    'answer: { "action_type": "answer", "answer": "short grounded text", "updated_preferences": { ... } }',
    'JSON strings must be escaped correctly. Never output unescaped quotes inside string values.',
    'Candidates are already pre-filtered locally for safety and relevance before they reach you.',
    'Recommend only IDs from the provided Candidates array. Never invent products, IDs, prices, stock, notes, gender, or season.',
    'If the candidate set is already clear and relevant, prefer recommend over ask.',
    'Do not ask for a constraint that is already satisfied by the filtered candidate set unless the user request is still genuinely ambiguous.',
    'Confidence Rule: If you have at least 1 candidate that matches the user Gender and Budget constraints, recommend it immediately. Do not ask for preferred notes or intensity if valid candidates are available; ask only if the candidate list is empty or gender is unknown.',
    'Lifestyle Mapping: Map professional and social contexts to sensory tags. Doctor/Hospital means clean, light, subtle, fresh. Office/Meeting means formal, professional, moderate. Wedding/Night means elegant, bold, long-lasting.',
    'Naming Integrity: Always use the full product name from candidate data. If brand and name are separate and name does not already include brand, write Brand + Name. Never shorten or truncate product names in answer or match_reason fields.',
    'Price-Sensitive Switching: If the user asks for a cheaper alternative or similar but less expensive, prioritize candidates with a lower price than the product currently discussed while staying honest about scent similarity.',
    'If candidates are relevant and the request is clear enough, return 1 to 3 candidate IDs. If the request is unclear or impossible, ask one targeted question or explain the constraint briefly.',
    'Respect maxBudget and excludedNotes from Session Preferences. Candidate budgetStatus, exactBudget, and overBudgetAmount are context only; server and Flutter validation remain final.',
    'If recommending a candidate above exactBudget, say briefly that it is slightly above budget. Do not present it as within budget.',
    'Use action_type="answer" only for details, why, comparison, or follow-up explanation. Answers must be text-only: no product_ids, no cards, no invented factual claims.',
    'Write match_reason as one specific grounded sentence, preferably 12 to 24 words.',
    'Use candidate.reasonFacts and candidate.localMatchReason only to explain why an already allowed candidate fits. Never add notes, prices, seasons, genders, stock, or claims that are not in the candidate data.',
    'If a candidate has cautions, mention the caution briefly instead of overstating the match.',
    'updated_preferences may include only preferences explicitly stated or changed by the current user message: gender, maxBudget, season, occasion, time, intensity, preferredNotes, preferredTopNotes, preferredMiddleNotes, preferredBaseNotes, excludedNotes, tags.',
    'Do not update preferences based on your own recommendations, inferred product traits, or candidates you selected; only based on explicit user input in the current message.',
    'For explicit forget/remove/replace requests, include preference_patch: { "clearScalars": ["maxBudget"], "replaceLists": { "preferredNotes": ["citrus"] }, "removeLists": { "preferredNotes": ["oud"] } }.',
    'Treat short follow-up modifiers as changes to the current session preferences, not as a new unrelated request.',
  ].join('\n');
}

function buildStructuredChatSystemPrompt(responseLanguage, toolRouterEnabled = false) {
  const lines = [
    'You are a bounded perfume shopping planner for a domain-constrained e-commerce chat.',
    'Return RAW JSON only. Do not use markdown or prose outside the JSON object.',
    `Write every user-facing field in ${responseLanguage === 'en' ? 'English' : 'Arabic'}.`,
    'Return schemaVersion=2 only.',
    `Shape: { "schemaVersion": 2, "type": "ask|recommendation|no_match|message|availability|comparison|refusal|error${toolRouterEnabled ? '|tool_call' : ''}", "language": "ar|en", "message": "user-facing text", "preferencesPatch": { ... }, "commands": [], "recommendations": [], "metadata": { ... } }`,
    'Allowed commands: show_recommendation_cards, show_product_card, keep_visible_cards, show_no_match.',
    'For card commands, productIds must come only from the provided Candidates array.',
    'Recommendations array items must be { "productId": "id", "reason": "short grounded reason" }.',
    'When candidate products are provided, they have already been filtered by the app for catalog validity and basic safety. Use only these candidates.',
    'For a recommendation request, do not return no_match if at least one candidate can reasonably match the user request. If none is perfect, return the closest candidate cards with a concise caveat.',
    'Use no_match only when the Candidates array is empty or every candidate is unsafe, unavailable, or blocked by the explicit user constraints.',
    'Use recentMessages, lastAssistantQuestion, and lastAskSlot to understand short replies such as "anything", "all of them", "لكله", or "مش فارق".',
    'Never invent products, IDs, names, prices, stock, notes, gender, season, or availability.',
    'Respect maxBudget and excludedNotes from Session Preferences. Candidate validation and app validation remain final.',
    'If recommending cards, include exactly one show_recommendation_cards command with 1 to 3 productIds.',
    'If the user refines an active recommendation such as "make it suitable for university/work/office" and candidates are provided, prefer recommendation or update_preferences_and_recommend over ask unless the refinement is genuinely unclear.',
    'If answering about visible cards, include keep_visible_cards and do not invent hidden products.',
    'If no safe match exists, use type="no_match" with show_no_match.',
    'If information is still missing, use type="ask" with one targeted question and no card command.',
    'preferencesPatch may include setScalars/replaceScalars, clearScalars, replaceLists, appendLists, or removeLists. Only patch preferences explicitly stated by the current user message in context.',
  ];
  if (toolRouterEnabled) {
    lines.push(
      'Tool Router: You may return type="tool_call" only when a deterministic app tool is a better fit than choosing product IDs.',
      'Allowed tool names: search_products, update_preferences_and_recommend, answer_product_question, ask_product_clarification, cheapest_catalog, most_expensive_catalog, similar_cheaper, cheaper_followup, show_lowest_available_after_budget_no_match, reject_visible_products, resolve_perfume_reference, select_perfume_reference_option, lookup_external_perfume_profile, recommend_similar_to_external_profile, similar_cheaper_to_external_profile, ask_clarification.',
      'Tool shape: { "schemaVersion": 2, "type": "tool_call", "language": "ar|en", "message": "short customer-facing intro that remains true after app validation", "toolCall": { "name": "similar_cheaper", "confidence": 0.86, "arguments": { ... } }, "commands": [], "recommendations": [] }.',
      'For search_products arguments, use only JSON-safe filters such as gender, maxPrice, season, occasion, time, intensity, notes, tags, family, brand, sort, and limit.',
      'Use show_lowest_available_after_budget_no_match only when compact context has lastNoMatch.reason="budget_no_match" and the user accepts the above-budget floor option.',
      'Use reject_visible_products when the user rejects the current visible cards, not when they ask for one specific product.',
      'Use similar_cheaper for "similar but cheaper" with an explicit product, lastFocusedProductId, or selected visible product. Do not use generic cheapest for this.',
      'Use cheaper_followup for "anything cheaper" or "cheaper than it"; if multiple visible products are ambiguous, use ask_product_clarification.',
      'Use resolve_perfume_reference for external or ambiguous perfume names such as Dior, Sauvage, Azzaro, or Stronger With You. Brand-only or series-only references must ask clarification through the app; do not auto-pick.',
      'Use select_perfume_reference_option only when compact context has pendingPerfumeReferenceClarification and the user replies with a number, ordinal, or option name.',
      'Use recommend_similar_to_external_profile or similar_cheaper_to_external_profile only when the externalProfileId is grounded in context or a prior tool result.',
      'External perfume profiles are anchors only. Never claim external availability, price, or stock, and never render external profiles as cards.',
      'For tool_call.message, write natural sales-assistant copy in the user language, but do not mention specific product names, prices, stock, or availability. The app will render validated catalog cards after executing the tool.',
      'For social check-ins such as "how are you", return type="message" with a natural short reply, then invite the user to ask for perfume help. Do not use fixed template wording.',
      'Priority rule before asking gender/season/budget: resolve language ambiguity first. If an Egyptian Arabic request says "ريحة حلوة/حلوه/حلو" without explicit "مسكرة/sweet/sugary", do not ask gender yet.',
      'For that ambiguous "حلوة" case, return type="tool_call" with toolCall.name="ask_clarification" and arguments.question asking whether the user means sweet/sugary or nice/beautiful/pleasant.',
      'Egyptian Arabic "حلوة/حلوه/حلو" is ambiguous: it can mean sweet/sugary or simply nice/beautiful. If the scent meaning is unclear, use ask_clarification and ask which meaning the user intends.',
      'If the user clarifies that "حلوة" means nice/beautiful/pleasant, do not add sweet/sugary. Use a preferencePatch such as appendLists.tags=["clean","elegant"] only when that meaning is explicit.',
      'For update_preferences_and_recommend, return a preferencePatch argument with structured patch operations only.',
      'For ask_clarification, put the user-facing question in arguments.question and optional preferencePatch in arguments.preferencePatch.',
      'Do not execute tools, do not invent product IDs, and do not include recommendation card commands with tool_call. The app will validate and execute the tool.'
    );
  }
  return lines.join('\n');
}

function sanitizeWorkerMatchReason(rawReason, product, language) {
  const fallback = buildGroundedMatchReason(product, language);
  if (typeof rawReason !== 'string') return fallback;
  const cleaned = rawReason.trim().replace(/\s+/g, ' ').slice(0, 180);
  if (!cleaned || isGenericMatchReason(cleaned)) return fallback;
  if (language === 'en' && !hasGroundedReasonOverlap(cleaned, product)) {
    return fallback;
  }
  return cleaned;
}

function isGenericMatchReason(reason) {
  const normalized = String(reason || '').trim().toLowerCase().replace(/\s+/g, ' ');
  return [
    'good match',
    'good match.',
    'great option',
    'great option.',
    'fits preferences',
    'fits preferences.',
    'fits your preferences',
    'fits your preferences.',
    'this option matches your current preferences well.',
    'this perfume matches your current taste and preferences.',
    'matches your current preferences',
    'matches your current preferences.',
  ].includes(normalized);
}

function hasGroundedReasonOverlap(reason, product) {
  const normalizedReason = normalizeReasonText(reason);
  if (!normalizedReason) return false;
  const facts = product?.reasonFacts || {};
  const profile = facts.productProfile || {};
  const tokens = [
    product?.gender,
    product?.season,
    product?.occasion,
    product?.time,
    product?.intensity,
    product?.budgetStatus,
    ...(product?.notes || []),
    ...(product?.topNotes || []),
    ...(product?.middleNotes || []),
    ...(product?.baseNotes || []),
    ...(product?.tags || []),
    ...(facts.matchedNotes || []),
    ...(facts.matchedContext || []),
    ...(profile.notes || []),
    ...(profile.topNotes || []),
    ...(profile.middleNotes || []),
    ...(profile.baseNotes || []),
    ...(profile.tags || []),
    profile.family,
    ...(facts.cautions || []),
    facts?.budget?.withinBudget ? 'budget' : '',
    facts?.budget?.withinBudget ? 'within budget' : '',
  ]
    .map(normalizeReasonText)
    .filter((token) => token.length >= 3);
  return tokens.some((token) => normalizedReason.includes(token));
}

function buildGroundedMatchReason(product, language) {
  const facts = product?.reasonFacts || {};
  const profile = facts.productProfile || {};
  const matchedNotes = normalizeStringArray(facts.matchedNotes).slice(0, 2);
  const matchedContext = normalizeStringArray(facts.matchedContext)
    .map((item) => contextDisplayValue(String(item).split(':').pop(), language))
    .filter(Boolean)
    .slice(0, 2);
  const highlights = [
    ...(product?.topNotes || []),
    ...((product?.topNotes || []).length === 0 ? (product?.notes || []) : []),
    ...(product?.middleNotes || []).slice(0, 1),
    ...(product?.baseNotes || []).slice(0, 1),
    ...(profile.notes || []),
  ]
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .slice(0, 2);
  const cautions = normalizeStringArray(facts.cautions).slice(0, 1);
  const budget = facts.budget || {};

  if (language === 'ar') {
    const parts = [];
    if (matchedNotes.length) parts.push(`يطابق نوتات ${joinReasonItems(matchedNotes, 'ar')}`);
    if (matchedContext.length) parts.push(`مناسب لـ ${joinReasonItems(matchedContext, 'ar')}`);
    if (budget.withinBudget && budget.exactBudget) parts.push(`داخل ميزانيتك`);
    if (cautions.length) parts.push(`مع ملاحظة: ${cautions[0]}`);
    if (parts.length) return `${parts.join('، ')}.`;
    if (highlights.length) return `اختيار متاح بطابع ${joinReasonItems(highlights, 'ar')}.`;
    return 'اختيار متاح من الكتالوج بناء على تفضيلاتك الحالية.';
  }

  const parts = [];
  if (matchedNotes.length) parts.push(`matches ${joinReasonItems(matchedNotes)} notes`);
  if (matchedContext.length) parts.push(`fits ${joinReasonItems(matchedContext)} context`);
  if (budget.withinBudget && budget.exactBudget) parts.push('stays within budget');
  if (cautions.length) parts.push(`note: ${cautions[0]}`);
  if (parts.length) return `${capitalizeSentence(parts.join(', '))}.`;
  if (highlights.length) return `Available pick with ${joinReasonItems(highlights)} notes.`;
  return 'Available catalog pick based on your current preferences.';
}

function normalizeReasonText(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[_:]/g, ' ')
    .replace(/\s+/g, ' ');
}

function contextDisplayValue(value, language = 'en') {
  const normalized = normalizeReasonText(value);
  if (language !== 'ar') return normalized.replace(/\s+/g, '_');
  const ar = new Map([
    ['men', 'رجالي'],
    ['women', 'حريمي'],
    ['unisex', 'للجنسين'],
    ['summer', 'صيفي'],
    ['winter', 'شتوي'],
    ['spring', 'ربيعي'],
    ['autumn', 'خريفي'],
    ['fall', 'خريفي'],
    ['all seasons', 'كل المواسم'],
    ['all_seasons', 'كل المواسم'],
    ['daily', 'الاستخدام اليومي'],
    ['office', 'الشغل'],
    ['work', 'الشغل'],
    ['university', 'الجامعة'],
    ['gym', 'الجيم'],
    ['date', 'الخروجات'],
    ['formal', 'المناسبات الرسمية'],
    ['day', 'النهار'],
    ['night', 'الليل'],
    ['all day', 'طوال اليوم'],
    ['all_day', 'طوال اليوم'],
    ['light', 'خفيف'],
    ['medium', 'متوسط'],
    ['strong', 'قوي'],
  ]);
  return ar.get(normalized) || value;
}

function joinReasonItems(items, language = 'en') {
  const clean = items.map((item) => String(item || '').trim()).filter(Boolean);
  if (clean.length <= 1) return clean.join('');
  if (clean.length === 2) return language === 'ar'
    ? `${clean[0]} و${clean[1]}`
    : `${clean[0]} and ${clean[1]}`;
  const head = clean.slice(0, -1).join(language === 'ar' ? '، ' : ', ');
  return language === 'ar'
    ? `${head}، و${clean[clean.length - 1]}`
    : `${head}, and ${clean[clean.length - 1]}`;
}

function capitalizeSentence(value) {
  if (!value) return value;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

async function callUpstreamModel({ endpoint, requestBody, timeoutMs = 30000, extraHeaders = {}, maxAttempts = 2 }) {
  const startedAt = Date.now();
  const requestInit = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
    body: JSON.stringify(requestBody),
  };

  const attempts = Math.min(Math.max(Math.trunc(maxAttempts) || 1, 1), 2);
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(endpoint, {
        ...requestInit,
        signal: controller.signal,
      });

      let data = null;
      try {
        data = await response.json();
      } catch {
        data = null;
      }

      if (response.ok || response.status < 500 || attempt === attempts - 1) {
        return {
          response,
          data,
          attemptCount: attempt + 1,
          retryCount: attempt,
          latencyMs: Date.now() - startedAt,
        };
      }
    } catch (error) {
      const isRetryable = error?.name === 'AbortError' || error?.name === 'TypeError';
      if (!isRetryable || attempt === attempts - 1) {
        error.retryCount = attempt;
        error.attemptCount = attempt + 1;
        error.latencyMs = Date.now() - startedAt;
        error.failureType = error?.name === 'AbortError' ? 'timeout' : 'network';
        throw error;
      }
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

// в”Ђв”Ђ Firebase ID Token Verification в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// Uses Firebase's public JSON Web Keys to verify the RS256 signature of an
// incoming ID Token. No Firebase Admin SDK needed вЂ” pure Web Crypto API.

const FIREBASE_PUBLIC_KEYS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

// Simple in-memory JWK cache (resets per isolate restart, typically long-lived).
let cachedJwks = null;
let jwksCachedAt = 0;
const JWK_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

async function getFirebasePublicKeys() {
  const now = Date.now();
  if (cachedJwks && (now - jwksCachedAt) < JWK_CACHE_TTL_MS) {
    return cachedJwks;
  }
  try {
    const resp = await fetch(FIREBASE_PUBLIC_KEYS_URL);
    if (!resp.ok) return null;
    const jwks = await resp.json();
    cachedJwks = jwks;
    jwksCachedAt = now;
    return jwks;
  } catch {
    return null;
  }
}

function base64UrlDecode(str) {
  const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlEncode(input) {
  const bytes = input instanceof Uint8Array
    ? input
    : input instanceof ArrayBuffer
      ? new Uint8Array(input)
      : new TextEncoder().encode(String(input));
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToArrayBuffer(pem) {
  const clean = String(pem)
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

let cachedCatalogServiceAccount = null;
let cachedCatalogAccessToken = null;
let cachedCatalogAccessTokenExp = 0;

function getCatalogServiceAccount(env) {
  if (cachedCatalogServiceAccount) return cachedCatalogServiceAccount;
  if (!env?.SERVICE_ACCOUNT_JSON) {
    throw new Error('Missing SERVICE_ACCOUNT_JSON for catalog verification');
  }

  const parsed = JSON.parse(env.SERVICE_ACCOUNT_JSON);
  if (!parsed?.client_email || !parsed?.private_key) {
    throw new Error('SERVICE_ACCOUNT_JSON must include client_email and private_key');
  }
  cachedCatalogServiceAccount = parsed;
  return parsed;
}

async function createCatalogGoogleAssertionJwt(env) {
  const serviceAccount = getCatalogServiceAccount(env);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: FIRESTORE_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64UrlEncode(signature)}`;
}

async function getCatalogGoogleAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedCatalogAccessToken && cachedCatalogAccessTokenExp - 60 > now) {
    return cachedCatalogAccessToken;
  }

  const assertion = await createCatalogGoogleAssertionJwt(env);
  const response = await fetchWithMethodTimeout(
    GOOGLE_TOKEN_URL,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    },
    CATALOG_FETCH_TIMEOUT_MS,
  );

  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`Google token request failed (${response.status})`);
  }

  const json = JSON.parse(raw || '{}');
  cachedCatalogAccessToken = json.access_token;
  cachedCatalogAccessTokenExp = now + Number(json.expires_in || 3600);
  return cachedCatalogAccessToken;
}

async function fetchWithMethodTimeout(url, init, timeoutMs, fetchImpl = fetch) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchImpl(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}

/**
 * Verifies a Firebase ID Token.
 * Returns { uid, email } on success, or null on failure.
 * projectId is required to validate the audience and issuer claims.
 */
async function verifyFirebaseIdToken(token, projectId) {
  if (!token || typeof token !== 'string') return null;
  if (!projectId) return null;

  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [headerB64, payloadB64, signatureB64] = parts;

    // Decode header to get the key ID (kid)
    const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(headerB64)));
    if (header.alg !== 'RS256') return null;
    const kid = header.kid;
    if (!kid) return null;

    // Decode payload
    const payload = JSON.parse(new TextDecoder().decode(base64UrlDecode(payloadB64)));

    // Validate standard claims
    const now = Math.floor(Date.now() / 1000);
    if (!payload.exp || payload.exp < now) return null;
    if (!payload.iat || payload.iat > now + 300) return null;
    if (payload.aud !== projectId) return null;
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
    if (!payload.sub || typeof payload.sub !== 'string') return null;

    // Fetch Firebase public keys
    const jwks = await getFirebasePublicKeys();
    if (!jwks || !Array.isArray(jwks.keys)) return null;

    const jwk = jwks.keys.find((k) => k.kid === kid);
    if (!jwk) return null;

    // Import the public key
    const cryptoKey = await crypto.subtle.importKey(
      'jwk',
      jwk,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );

    // Verify the signature
    const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = base64UrlDecode(signatureB64);
    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      signature,
      signingInput,
    );
    if (!valid) return null;

    return { uid: payload.sub, email: payload.email || null };
  } catch {
    return null;
  }
}

/**
 * Extracts and verifies the Bearer token from the Authorization header.
 * Returns { uid, email } on success or null if missing/invalid.
 * Soft enforcement (logging only) happens here. Hard enforcement is handled by the caller.
 */
async function resolveAuthContext(request, env) {
  const authHeader = request.headers.get('Authorization') || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null;

  if (!token) {
    logWorkerEvent('auth_missing_token', {
      note: 'Request has no Authorization header. Soft-enforcement: allowing through.',
    });
    return null;
  }

  const projectId = env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    logWorkerEvent('auth_config_missing', {
      note: 'FIREBASE_PROJECT_ID not set on worker. Cannot verify token.',
    });
    return null;
  }

  const identity = await verifyFirebaseIdToken(token, projectId);

  if (!identity) {
    logWorkerEvent('auth_invalid_token', {
      note: 'Token failed verification. Soft-enforcement: allowing through.',
    });
    return null;
  }

  return identity;
}

function normalizePerfumeKnowledgeProfile(raw = {}, fallbackQuery = '') {
  const displayName = clipText(raw.displayName ?? raw.name ?? fallbackQuery, 90);
  const brand = clipText(raw.brand ?? '', 60) || '';
  const lookupConfidence = Math.max(0, Math.min(1, parseNumber(raw.lookupConfidence ?? raw.confidence) ?? 0));
  const profile = {
    displayName,
    brand,
    aliases: normalizeStringArray(raw.aliases).slice(0, 12),
    accords: normalizeStringArray(raw.accords).slice(0, 12),
    topNotes: normalizeStringArray(raw.topNotes).slice(0, 10),
    middleNotes: normalizeStringArray(raw.middleNotes).slice(0, 10),
    baseNotes: normalizeStringArray(raw.baseNotes).slice(0, 10),
    fragranceFamily: clipText(raw.fragranceFamily, 80) || '',
    genderHint: normalizeEnum(raw.genderHint, ['men', 'women', 'unisex']),
    seasonHint: normalizeEnum(raw.seasonHint, ['summer', 'winter', 'spring', 'autumn', 'all_seasons']),
    occasionHint: normalizeEnum(raw.occasionHint, ['daily', 'office', 'formal', 'date', 'evening', 'university']),
    timeHint: normalizeEnum(raw.timeHint, ['day', 'night', 'all_day']),
    intensityHint: normalizeEnum(raw.intensityHint, ['light', 'medium', 'strong']),
    sourceName: clipText(raw.sourceName, 80) || 'Perfume knowledge lookup',
    sourceUrl: clipText(raw.sourceUrl, 240),
    extractionMethod: normalizeEnum(raw.extractionMethod, ['curated', 'fragrantica_arabia', 'model']) || 'model',
    lookupConfidence,
    status: 'needsReview',
  };

  if (!profile.displayName || (profile.accords.length === 0 && profile.topNotes.length === 0 && profile.baseNotes.length === 0)) {
    return null;
  }
  return profile;
}

function stripHtml(html) {
  const stripped = String(html ?? '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&#x27;|&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
  return repairArabicMojibake(stripped);
}

function repairArabicMojibake(text) {
  const value = String(text ?? '');
  if (!/[\u00d8\u00d9]/.test(value)) return value;
  try {
    const bytes = new Uint8Array([...value].map((char) => char.charCodeAt(0) & 0xff));
    const decoded = new TextDecoder('utf-8', { fatal: false }).decode(bytes);
    if (/[\u0600-\u06ff]/.test(decoded)) return decoded;
  } catch {
    // Try percent-decoding fallback below.
  }
  try {
    const encoded = [...value]
      .map((char) => `%${(char.charCodeAt(0) & 0xff).toString(16).padStart(2, '0')}`)
      .join('');
    const decoded = decodeURIComponent(encoded);
    if (/[\u0600-\u06ff]/.test(decoded)) return decoded;
  } catch {
    // Keep original if both repair strategies fail.
  }
  return value;
}

function translateScentTerm(term) {
  const clean = String(term ?? '').replace(/\s+/g, ' ').trim();
  if (!clean) return null;
  if (ARABIC_SCENT_TRANSLATIONS.has(clean)) return ARABIC_SCENT_TRANSLATIONS.get(clean);
  const withoutParens = clean.replace(/\s*\([^)]*\)\s*/g, '').trim();
  if (ARABIC_SCENT_TRANSLATIONS.has(withoutParens)) return ARABIC_SCENT_TRANSLATIONS.get(withoutParens);
  return normalizeKnowledgeText(withoutParens || clean);
}

function splitArabicTerms(raw) {
  const repaired = repairArabicMojibake(raw);
  const knownTerms = [...ARABIC_SCENT_TRANSLATIONS.keys()]
    .filter((term) => repaired.includes(term))
    .map(translateScentTerm)
    .filter(Boolean);
  if (knownTerms.length > 0) {
    return [...new Set(knownTerms)];
  }

  const text = String(repaired ?? '')
    .replace(/[؛،Ш›ШЊ]/g, ',')
    .replace(/\s+Щ€\s+/g, ',')
    .replace(/\s+و\s+/g, ',')
    .replace(/\s*;\s*/g, ',')
    .trim();
  return text
    .split(',')
    .map((item) => translateScentTerm(item))
    .filter(Boolean);
}

function extractBetween(text, startMarkers, endMarkers) {
  const source = String(text ?? '');
  let start = -1;
  let startMarker = '';
  for (const marker of startMarkers) {
    const index = source.indexOf(marker);
    if (index !== -1 && (start === -1 || index < start)) {
      start = index;
      startMarker = marker;
    }
  }
  if (start === -1) return '';
  const from = start + startMarker.length;
  let end = source.length;
  for (const marker of endMarkers) {
    const index = source.indexOf(marker, from);
    if (index !== -1 && index < end) end = index;
  }
  return source.slice(from, end).trim();
}

function extractAccordsFromText(text) {
  const block = extractBetween(
    text,
    [
      'الإتفاقات الرئيسية',
      'الاتفاقات الرئيسية',
      'Ш§Щ„ШҐШЄЩЃШ§Щ‚Ш§ШЄ Ш§Щ„Ш±Ш¦ЩЉШіЩЉШ©',
      'Ш§Щ„Ш§ШЄЩЃШ§Щ‚Ш§ШЄ Ш§Щ„Ш±Ш¦ЩЉШіЩЉШ©',
    ],
    [
      'البحث عن طريق الأكوردات',
      'تقييمات المستخدمين',
      'تقيم العطر',
      'المراجعات',
      'Ш§Щ„ШЁШ­Ш« Ш№Щ† Ш·Ш±ЩЉЩ‚ Ш§Щ„ШЈЩѓЩ€Ш±ШЇШ§ШЄ',
      'ШЄЩ‚ЩЉЩЉЩ…Ш§ШЄ Ш§Щ„Щ…ШіШЄШ®ШЇЩ…ЩЉЩ†',
      'ШЄЩ‚ЩЉЩ… Ш§Щ„Ш№Ш·Ш±',
      'Ш§Щ„Щ…Ш±Ш§Ш¬Ш№Ш§ШЄ',
    ]
  );
  if (!block) return [];
  const knownArabicTerms = [...ARABIC_SCENT_TRANSLATIONS.keys()]
    .filter((term) => block.includes(term));
  return [...new Set(knownArabicTerms.map(translateScentTerm).filter(Boolean))].slice(0, 12);
}

function extractNotesFromText(text, startMarkers, endMarkers) {
  const block = extractBetween(text, startMarkers, endMarkers);
  return splitArabicTerms(block).slice(0, 12);
}

function extractFragranticaArabiaProfileFromHtml(html, sourceUrl, fallbackQuery = '') {
  const text = stripHtml(html);
  if (!text) return null;

  const titleMatch = text.match(/(?:^|\s)([^#]{2,90}?)\s+(?:للرجال|للنساء|للجنسين|Щ„Щ„Ш±Ш¬Ш§Щ„|Щ„Щ„Щ†ШіШ§ШЎ|Щ„Щ„Ш¬Щ†ШіЩЉЩ†)\s+(?:Image:|Azzaro|Dior|Chanel|Yves|$)/);
  let displayName = clipText(titleMatch?.[1], 90);
  if (!displayName || displayName.length < 3) {
    const h1Match = String(html ?? '').match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
    displayName = clipText(stripHtml(h1Match?.[1] || fallbackQuery), 90);
  }

  let brand = '';
  const brandFromUrl = sourceUrl.match(/\/perfumes\/([^/]+)\//i)?.[1];
  if (brandFromUrl) {
    brand = decodeURIComponent(brandFromUrl).replace(/-/g, ' ').trim();
  } else {
    if (/Azzaro/i.test(sourceUrl) || /Azzaro/.test(text)) brand = 'Azzaro';
    else if (/Dior/i.test(sourceUrl) || /\bDior\b/.test(text)) brand = 'Dior';
    else if (/Chanel/i.test(sourceUrl) || /Chanel/.test(text)) brand = 'Chanel';
  }
  displayName = cleanFragranticaDisplayName(displayName || fallbackQuery, brand);

  const accords = extractAccordsFromText(text);
  const topNotes = extractNotesFromText(
    text,
    [
      'الإفتتاحية',
      'الافتتاحية',
      'افتتاحية العطر',
      'Ш§Щ„ШҐЩЃШЄШЄШ§Ш­ЩЉШ©',
      'Ш§ЩЃШЄШЄШ§Ш­ЩЉШ© Ш§Щ„Ш№Ш·Ш±',
    ],
    [
      'قلب العطر',
      'المكونات الأساسية',
      'قاعدة العطر',
      '###',
      'المصمم',
      'Щ‚Щ„ШЁ Ш§Щ„Ш№Ш·Ш±',
      'Ш§Щ„Щ…ЩѓЩ€Щ†Ш§ШЄ Ш§Щ„ШЈШіШ§ШіЩЉШ©',
      'Щ‚Ш§Ш№ШЇШ© Ш§Щ„Ш№Ш·Ш±',
      'Ш§Щ„Щ…ШµЩ…Щ…',
    ]
  );
  const middleNotes = extractNotesFromText(
    text,
    ['قلب العطر', 'Щ‚Щ„ШЁ Ш§Щ„Ш№Ш·Ш±'],
    [
      'المكونات الأساسية',
      'قاعدة العطر',
      '###',
      'المصمم',
      'Ш§Щ„Щ…ЩѓЩ€Щ†Ш§ШЄ Ш§Щ„ШЈШіШ§ШіЩЉШ©',
      'Щ‚Ш§Ш№ШЇШ© Ш§Щ„Ш№Ш·Ш±',
      'Ш§Щ„Щ…ШµЩ…Щ…',
    ]
  );
  let baseNotes = extractNotesFromText(
    text,
    [
      'المكونات الأساسية',
      'قاعدة العطر',
      'Ш§Щ„Щ…ЩѓЩ€Щ†Ш§ШЄ Ш§Щ„ШЈШіШ§ШіЩЉШ©',
      'Щ‚Ш§Ш№ШЇШ© Ш§Щ„Ш№Ш·Ш±',
    ],
    [
      'المصمم',
      'Azzaro pour Homme الأخبار',
      'الأخبار',
      'المراجعات',
      'Ш§Щ„Щ…ШµЩ…Щ…',
      'Azzaro pour Homme Ш§Щ„ШЈШ®ШЁШ§Ш±',
      'Ш§Щ„ШЈШ®ШЁШ§Ш±',
      'Ш§Щ„Щ…Ш±Ш§Ш¬Ш№Ш§ШЄ',
    ]
  );
  const topMiddleSet = new Set([...topNotes, ...middleNotes]);
  baseNotes = baseNotes.filter((note) => !topMiddleSet.has(note)).slice(0, 10);

  const family = /فوجير|فوجيير|ЩЃЩ€Ъ†ЩЉШ±|ЩЃЩ€Ш¬ЩЉШ±/i.test(text) ? 'aromatic fougere' : '';
  const genderHint = text.includes('للرجال') || text.includes('Щ„Щ„Ш±Ш¬Ш§Щ„') ? 'men' : text.includes('للنساء') || text.includes('Щ„Щ„Щ†ШіШ§ШЎ') ? 'women' : null;
  const hasUsefulProfile = accords.length >= 3 || topNotes.length + middleNotes.length + baseNotes.length >= 4;
  if (!hasUsefulProfile) return null;

  return normalizePerfumeKnowledgeProfile({
    displayName: displayName || fallbackQuery,
    brand,
    aliases: [fallbackQuery, displayName].filter(Boolean),
    accords,
    topNotes,
    middleNotes,
    baseNotes,
    fragranceFamily: family,
    genderHint,
    seasonHint: 'all_seasons',
    occasionHint: 'daily',
    timeHint: 'all_day',
    intensityHint: accords.includes('warm spicy') || accords.includes('leather') ? 'strong' : 'medium',
    sourceName: 'Fragrantica Arabia',
    sourceUrl,
    extractionMethod: 'fragrantica_arabia',
    lookupConfidence: accords.length >= 5 ? 0.9 : 0.76,
  }, fallbackQuery);
}

function cleanFragranticaDisplayName(value, brand) {
  let name = repairArabicMojibake(value)
    .replace(/للرجال|للنساء|للجنسين/g, ' ')
    .replace(/Щ„Щ„Ш±Ш¬Ш§Щ„|Щ„Щ„Щ†ШіШ§ШЎ|Щ„Щ„Ш¬Щ†ШіЩЉЩ†/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const cleanBrand = String(brand ?? '').trim();
  if (cleanBrand && name.toLowerCase().endsWith(` ${cleanBrand.toLowerCase()}`)) {
    name = name.slice(0, -cleanBrand.length).trim();
  }
  return clipText(name, 90) || value;
}

async function fetchWithTimeout(url, timeoutMs = FRAGRANTICA_ARABIA_FETCH_TIMEOUT_MS, fetchImpl = fetch) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchImpl(url, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
      },
    });
  } finally {
    clearTimeout(timeout);
  }
}

function isAllowedFragranticaArabiaPerfumeUrl(url) {
  try {
    const parsed = new URL(url, FRAGRANTICA_ARABIA_ORIGIN);
    return parsed.hostname === FRAGRANTICA_ARABIA_HOST &&
      /^\/perfumes\/[^/]+\/[^/]+\.html$/i.test(parsed.pathname);
  } catch {
    return false;
  }
}

function normalizeFragranticaArabiaUrl(url) {
  try {
    const parsed = new URL(url, FRAGRANTICA_ARABIA_ORIGIN);
    parsed.hash = '';
    parsed.search = '';
    if (!isAllowedFragranticaArabiaPerfumeUrl(parsed.href)) return null;
    return parsed.href;
  } catch {
    return null;
  }
}

function titleFromSlug(slug) {
  return String(slug ?? '')
    .replace(/-\d+$/g, '')
    .replace(/-/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function candidateFromFragranticaUrl(url, linkText = '') {
  const sourceUrl = normalizeFragranticaArabiaUrl(url);
  if (!sourceUrl) return null;
  const parsed = new URL(sourceUrl);
  const parts = parsed.pathname.split('/').filter(Boolean);
  const brand = titleFromSlug(decodeURIComponent(parts[1] || ''));
  const displayNameFromUrl = titleFromSlug(decodeURIComponent((parts[2] || '').replace(/\.html$/i, '')));
  const cleanText = stripHtml(linkText)
    .replace(/\b\d{4}\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const displayName = cleanFragranticaDisplayName(
    displayNameFromUrl || cleanText,
    brand,
  );
  if (!displayName || !brand) return null;
  return {
    id: '',
    displayName,
    brand,
    sourceUrl,
  };
}

function parseFragranticaArabiaCandidates(html) {
  const source = String(html ?? '');
  const candidates = [];
  const seen = new Set();
  const anchorPattern = /<a\b[^>]*href=["']([^"']*\/perfumes\/[^"']+?\.html)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let match;
  while ((match = anchorPattern.exec(source)) !== null) {
    const candidate = candidateFromFragranticaUrl(match[1], match[2]);
    if (!candidate || seen.has(candidate.sourceUrl)) continue;
    seen.add(candidate.sourceUrl);
    candidates.push(candidate);
  }

  const urlPattern = /https?:\/\/www\.fragranticarabia\.com\/perfumes\/[^"' <>()]+?\.html|\/perfumes\/[^"' <>()]+?\.html/gi;
  while ((match = urlPattern.exec(source)) !== null) {
    const candidate = candidateFromFragranticaUrl(match[0]);
    if (!candidate || seen.has(candidate.sourceUrl)) continue;
    seen.add(candidate.sourceUrl);
    candidates.push(candidate);
  }
  return candidates;
}

const PERFUME_KNOWLEDGE_CONNECTOR_TOKENS = new Set([
  'a',
  'an',
  'and',
  'by',
  'de',
  'du',
  'for',
  'la',
  'le',
  'les',
  'of',
  'pour',
  'the',
  'with',
  'you',
]);

function knowledgeTokens(text) {
  return normalizeKnowledgeText(text)
    .split(/\s+/)
    .filter((token) => token.length >= 2);
}

function tokenSet(text) {
  return new Set(knowledgeTokens(text));
}

function distinctiveTokenSet(text) {
  return new Set(knowledgeTokens(text)
    .filter((token) => !PERFUME_KNOWLEDGE_CONNECTOR_TOKENS.has(token)));
}

function distinctiveCoverage(queryTokens, candidateTokens) {
  if (queryTokens.size === 0) return 1;
  const matched = [...queryTokens].filter((token) => candidateTokens.has(token)).length;
  return matched / queryTokens.size;
}

function minimumDistinctiveCoverage(queryTokens) {
  if (queryTokens.size <= 1) return 1;
  if (queryTokens.size === 2) return 1;
  return 0.82;
}

function hasEnoughDistinctiveCoverage(query, candidate) {
  const queryTokens = distinctiveTokenSet(query);
  const candidateTokens = distinctiveTokenSet(candidate);
  return distinctiveCoverage(queryTokens, candidateTokens) >= minimumDistinctiveCoverage(queryTokens);
}

function scoringTokenSet(text) {
  return new Set(normalizeKnowledgeText(text)
    .split(/\s+/)
    .filter((token) => token.length >= 2 && !PERFUME_KNOWLEDGE_CONNECTOR_TOKENS.has(token)));
}

function scorePerfumeCandidate(query, candidate) {
  const normalizedQuery = normalizeKnowledgeText(query);
  const normalizedName = normalizeKnowledgeText(candidate.displayName);
  const normalizedFullName = normalizeKnowledgeText(`${candidate.brand} ${candidate.displayName}`);
  if (!normalizedQuery || !normalizedName) return 0;
  if (!hasEnoughDistinctiveCoverage(normalizedQuery, normalizedFullName)) return 0;
  if (normalizedQuery === normalizedName || normalizedQuery === normalizedFullName) return 1;

  let score = 0;
  if (containsKnowledgePhrase(normalizedName, normalizedQuery) ||
      containsKnowledgePhrase(normalizedFullName, normalizedQuery)) {
    score += 0.72;
  }
  if (normalizedName.length >= 4 && containsKnowledgePhrase(normalizedQuery, normalizedName)) {
    score += 0.65;
  }

  const queryTokens = scoringTokenSet(normalizedQuery);
  const candidateTokens = scoringTokenSet(normalizedFullName);
  if (queryTokens.size > 0) {
    const matched = [...queryTokens].filter((token) => candidateTokens.has(token)).length;
    score += (matched / queryTokens.size) * 0.55;
    if (matched === queryTokens.size) score += 0.12;
  }

  return Math.max(0, Math.min(1, score));
}

function containsKnowledgePhrase(haystack, needle) {
  const cleanHaystack = ` ${normalizeKnowledgeText(haystack)} `;
  const cleanNeedle = normalizeKnowledgeText(needle);
  if (!cleanNeedle || cleanNeedle.length < 3) return false;
  return cleanHaystack.includes(` ${cleanNeedle} `);
}

function rankPerfumeCandidates(query, candidates) {
  return candidates
    .map((candidate) => ({
      ...candidate,
      score: scorePerfumeCandidate(query, candidate),
    }))
    .filter((candidate) => candidate.score >= PERFUME_KNOWLEDGE_AMBIGUOUS_MIN_SCORE)
    .sort((a, b) => b.score - a.score || a.displayName.length - b.displayName.length)
    .slice(0, PERFUME_KNOWLEDGE_MAX_CANDIDATES)
    .map((candidate, index) => ({
      id: String(index + 1),
      displayName: candidate.displayName,
      brand: candidate.brand,
      sourceUrl: candidate.sourceUrl,
      score: Number(candidate.score.toFixed(3)),
    }));
}

function getCanonicalFragranticaArabiaCandidates(query) {
  const normalizedQuery = normalizeKnowledgeText(query);
  if (!normalizedQuery) return [];

  const matches = [];
  for (const hint of FRAGRANTICA_ARABIA_CANONICAL_CANDIDATE_HINTS) {
    const aliasMatched = hint.aliases
      .map((alias) => normalizeKnowledgeText(alias))
      .some((alias) => alias && alias === normalizedQuery);
    if (!aliasMatched) continue;

    const candidate = candidateFromFragranticaUrl(
      hint.sourceUrl,
      `${hint.displayName} ${hint.brand}`,
    );
    if (!candidate) continue;
    matches.push({
      ...candidate,
      displayName: hint.displayName,
      brand: hint.brand,
      score: 1,
    });
  }

  return matches
    .slice(0, PERFUME_KNOWLEDGE_MAX_CANDIDATES)
    .map((candidate, index) => ({
      id: String(index + 1),
      displayName: candidate.displayName,
      brand: candidate.brand,
      sourceUrl: candidate.sourceUrl,
      score: Number(candidate.score.toFixed(3)),
    }));
}

function getFragranticaArabiaFamilyAmbiguityCandidates(query) {
  const normalizedQuery = normalizeKnowledgeText(query);
  const familyAliases = FRAGRANTICA_ARABIA_FAMILY_AMBIGUITY_HINTS[normalizedQuery];
  if (!Array.isArray(familyAliases) || familyAliases.length === 0) return [];

  return familyAliases
    .flatMap((alias) => getCanonicalFragranticaArabiaCandidates(alias))
    .slice(0, PERFUME_KNOWLEDGE_MAX_CANDIDATES)
    .map((candidate, index) => ({
      ...candidate,
      id: String(index + 1),
      score: Number((0.92 - index * 0.02).toFixed(3)),
    }));
}

function buildFragranticaArabiaSearchUrls(query) {
  const encoded = encodeURIComponent(query);
  return [
    `${FRAGRANTICA_ARABIA_ORIGIN}/search/?query=${encoded}`,
  ];
}

async function searchFragranticaArabiaCandidates(query, fetchImpl = fetch) {
  const allCandidates = [];
  const seen = new Set();
  for (const url of buildFragranticaArabiaSearchUrls(query)) {
    const response = await fetchWithTimeout(url, FRAGRANTICA_ARABIA_FETCH_TIMEOUT_MS, fetchImpl);
    if (!response?.ok) continue;
    const html = await response.text();
    for (const candidate of parseFragranticaArabiaCandidates(html)) {
      if (seen.has(candidate.sourceUrl)) continue;
      seen.add(candidate.sourceUrl);
      allCandidates.push(candidate);
    }
    if (allCandidates.length >= 10) break;
  }

  const directRanked = rankPerfumeCandidates(query, allCandidates);
  if (directRanked.length > 0) return directRanked;

  for (const candidate of allCandidates.slice(0, 3)) {
    const response = await fetchWithTimeout(candidate.sourceUrl, FRAGRANTICA_ARABIA_FETCH_TIMEOUT_MS, fetchImpl);
    if (!response?.ok) continue;
    const html = await response.text();
    for (const relatedCandidate of parseFragranticaArabiaCandidates(html)) {
      if (seen.has(relatedCandidate.sourceUrl)) continue;
      seen.add(relatedCandidate.sourceUrl);
      allCandidates.push(relatedCandidate);
    }
    const expandedRanked = rankPerfumeCandidates(query, allCandidates);
    if (expandedRanked.length > 0) return expandedRanked;
  }

  return [];
}

async function resolveFragranticaArabiaProfile(sourceUrl, fallbackQuery = '', fetchImpl = fetch) {
  const url = normalizeFragranticaArabiaUrl(sourceUrl);
  if (!url) return null;
  const response = await fetchWithTimeout(url, FRAGRANTICA_ARABIA_FETCH_TIMEOUT_MS, fetchImpl);
  if (!response?.ok) return null;
  const html = await response.text();
  return extractFragranticaArabiaProfileFromHtml(html, url, fallbackQuery);
}

async function lookupFragranticaArabia(query, fetchImpl = fetch) {
  const canonicalCandidates = getCanonicalFragranticaArabiaCandidates(query);
  if (canonicalCandidates.length > 0) {
    const canonicalResult = await resolveLookupFromCandidates(query, canonicalCandidates, fetchImpl);
    if (canonicalResult.status === 'found') return canonicalResult;
  }

  const familyAmbiguityCandidates = getFragranticaArabiaFamilyAmbiguityCandidates(query);
  if (familyAmbiguityCandidates.length > 0) {
    return { status: 'ambiguous', candidates: familyAmbiguityCandidates };
  }

  const candidates = await searchFragranticaArabiaCandidates(query, fetchImpl);
  return resolveLookupFromCandidates(query, candidates, fetchImpl);
}

async function resolveLookupFromCandidates(query, candidates, fetchImpl = fetch) {
  const best = candidates[0];
  if (!best) return { status: 'not_found', reason: 'no_candidates' };
  const runnerUp = candidates[1];
  const isDirect = best.score >= PERFUME_KNOWLEDGE_DIRECT_MATCH_SCORE &&
    (!runnerUp || best.score - runnerUp.score >= 0.12);
  if (!isDirect) {
    return { status: 'ambiguous', candidates };
  }
  const profile = await resolveFragranticaArabiaProfile(best.sourceUrl, best.displayName, fetchImpl);
  return profile ? { status: 'found', profile } : { status: 'not_found', reason: 'profile_extract_failed' };
}

async function lookupModelBackedFragranticaCandidates(query, env) {
  const apiKey = env.OPENROUTER_API_KEY;
  if (!apiKey) return [];

  const systemPrompt = [
    'You suggest likely Fragrantica Arabia perfume result candidates for a safe resolver.',
    'Return RAW JSON only.',
    'Do not return scent profiles, reviews, descriptions, or claims.',
    'If unsure, return { "status": "not_found" }.',
    'If recognized, return { "status": "candidates", "candidates": [{ "displayName", "brand", "sourceUrl" }] }.',
    'sourceUrl must be an exact URL on https://www.fragranticarabia.com/perfumes/{Brand}/{Perfume-Slug-id}.html.',
    'Return at most 3 candidates, ordered by likely match.',
  ].join('\n');

  const openRouterPayload = buildOpenRouterPayload({
    systemText: systemPrompt,
    userText: `Perfume query: ${query}`,
    temperature: 0,
    maxTokens: 350,
  });

  try {
    const upstreamResult = await callUpstreamModel({
      endpoint: getOpenRouterEndpoint(env),
      requestBody: openRouterPayload,
      timeoutMs: PERFUME_KNOWLEDGE_CANDIDATE_MODEL_TIMEOUT_MS,
      extraHeaders: buildOpenRouterHeaders({ ...env, OPENROUTER_API_KEY: apiKey }),
    });
    const { response, data: openRouterData } = upstreamResult;
    if (!response.ok) return [];
    const rawText = extractOpenRouterContent(openRouterData) || '{}';
    const parsed = extractJsonObject(rawText) || {};
    if (parsed.status !== 'candidates' || !Array.isArray(parsed.candidates)) return [];
    const rawCandidates = parsed.candidates
      .map((item) => candidateFromFragranticaUrl(item?.sourceUrl, `${item?.displayName || ''} ${item?.brand || ''}`))
      .filter(Boolean);
    return rankPerfumeCandidates(query, rawCandidates);
  } catch (error) {
    logWorkerEvent('perfume_knowledge_candidate_model_failed', {
      endpoint: '/api/perfume-knowledge/lookup',
      errorName: error?.name || null,
      errorMessage: error?.message || null,
    });
    return [];
  }
}

async function handleInterpret(request, env, body, verifiedUid = null, corsHeaders = null) {
  warnOnUnknownKeys(body, [
    'currentMessage',
    'responseLanguage',
    'currentPreferences',
    'preferences',
    'hasRecommendationContext',
    'hasAvailabilityContext',
    'sessionKey',
    'requestId',
  ], '/api/interpret');

  const currentMessage = typeof body?.currentMessage === 'string' ? body.currentMessage.trim() : '';
  const responseLanguage = body?.responseLanguage === 'en' ? 'en' : 'ar';
  const currentPreferences = sanitizePreferences(body?.currentPreferences || body?.preferences || {});
  const hasRecommendationContext = normalizeBoolean(body?.hasRecommendationContext, false);
  const hasAvailabilityContext = normalizeBoolean(body?.hasAvailabilityContext, false);
  const requestId = typeof body?.requestId === 'string' ? body.requestId.trim() : null;

  if (!currentMessage) {
    return jsonResponse(emptyInterpretation('empty_message'), 200, corsHeaders);
  }
  if (currentMessage.length > MAX_CURRENT_MESSAGE_LENGTH) {
    return jsonResponse(emptyInterpretation('message_too_long'), 200, corsHeaders);
  }
  if (requestId && requestId.length > MAX_REQUEST_ID_LENGTH) {
    return jsonResponse({ error: 'requestId is too long.' }, 400, corsHeaders);
  }

  const heuristic = buildHeuristicInterpretation(
    currentMessage,
    responseLanguage,
    currentPreferences,
  );
  if (heuristic.confidence >= 0.85) {
    logWorkerEvent('interpret_heuristic_accepted', {
      endpoint: '/api/interpret',
      requestId,
      verifiedUid,
      intent: heuristic.intent,
      confidence: heuristic.confidence,
      reasonCode: heuristic.reasonCode,
    });
    return jsonResponse(heuristic, 200, corsHeaders);
  }

  const apiKey = env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return jsonResponse(heuristic.confidence > 0 ? heuristic : emptyInterpretation('model_unavailable'), 200, corsHeaders);
  }

  const clientKey = getClientKey(request, body || {}, verifiedUid);
  const isAllowed = await checkRateLimit(`interpret:${clientKey}`, Date.now(), env);
  if (!isAllowed) {
    logWorkerEvent('rate_limit_exceeded', {
      endpoint: '/api/interpret',
      clientKey,
      requestId,
    });
    return jsonResponse(heuristic.confidence > 0 ? heuristic : emptyInterpretation('rate_limited'), 200, corsHeaders);
  }

  const systemPrompt = [
    'You interpret a perfume shopping chat message into JSON only.',
    'Return exactly one JSON object with keys: intent, confidence, preferencePatch, askSlot, productQueryCandidate, reasonCode.',
    'Allowed intents: recommendation, modifier, availability, compare, answer, greeting, off_topic, unclear.',
    'Allowed askSlot: gender, season, maxBudget, notesOrIntensity, or null.',
    'productQueryCandidate must be a plain perfume name string or null. Never use generic words like perfume, men, women, types, best.',
    'preferencePatch may only contain gender, season, occasion, time, intensity, maxBudget, preferredNotes, excludedNotes, tags.',
    'Do not return product IDs, recommendation cards, availability decisions, prices, stock facts, product claims, or answer text.',
    'Use availability only when the message clearly asks about stock/availability/price of a named product and set productQueryCandidate.',
    'Use compare only when the user clearly compares concrete products or card numbers.',
    'For generic typos like "reccomend somthing very good", use recommendation.',
    'For Arabic "للأثنين" meaning both genders, use gender unisex.',
    'For Arabic "قوة الرواح/فوحان/ثبات", use intensity strong or askSlot maxBudget when budget is missing.',
    'For "خليط بين ريحتين/نوتتين", use recommendation and askSlot notesOrIntensity unless notes are named.',
  ].join('\n');

  const userText = JSON.stringify({
    currentMessage,
    responseLanguage,
    currentPreferences,
    hasRecommendationContext,
    hasAvailabilityContext,
  });

  try {
    const upstreamResult = await callUpstreamModel({
      endpoint: getOpenRouterEndpoint(env),
      requestBody: buildOpenRouterPayload({
        systemText: systemPrompt,
        userText,
        temperature: 0,
        maxTokens: INTERPRET_MAX_OUTPUT_TOKENS,
      }),
      timeoutMs: 8000,
      extraHeaders: buildOpenRouterHeaders({ ...env, OPENROUTER_API_KEY: apiKey }),
    });
    if (!upstreamResult.response.ok) {
      return jsonResponse(heuristic.confidence > 0 ? heuristic : emptyInterpretation('model_http_error'), 200, corsHeaders);
    }
    const rawText = extractOpenRouterContent(upstreamResult.data) || '{}';
    const parsed = extractJsonObject(rawText) || {};
    const normalized = normalizeInterpretationResponse(parsed, 'model_interpretation');
    const result = normalized.confidence >= heuristic.confidence ? normalized : heuristic;
    logWorkerEvent('interpret_model_completed', {
      endpoint: '/api/interpret',
      requestId,
      intent: result.intent,
      confidence: result.confidence,
      reasonCode: result.reasonCode,
    });
    return jsonResponse(result, 200, corsHeaders);
  } catch (error) {
    logWorkerEvent('interpret_model_failed', {
      endpoint: '/api/interpret',
      requestId,
      errorName: error?.name || null,
      errorMessage: error?.message || null,
    });
    return jsonResponse(heuristic.confidence > 0 ? heuristic : emptyInterpretation('model_failed'), 200, corsHeaders);
  }
}

async function handlePerfumeKnowledgeLookup(request, env, body, verifiedUid = null, corsHeaders = null) {
  warnOnUnknownKeys(body, ['query', 'responseLanguage', 'requestId'], '/api/perfume-knowledge/lookup');
  const query = typeof body?.query === 'string' ? body.query.trim() : '';
  const responseLanguage = body?.responseLanguage === 'en' ? 'en' : 'ar';
  const requestId = typeof body?.requestId === 'string' ? body.requestId.trim() : null;

  if (query.length < 3 || query.length > 120) {
    return jsonResponse({ status: 'not_found', reason: 'invalid_query' }, 200, corsHeaders);
  }

  const clientKey = getClientKey(request, body || {}, verifiedUid);
  const isAllowed = await checkRateLimit(`knowledge:${clientKey}`, Date.now(), env);
  if (!isAllowed) {
    logWorkerEvent('rate_limit_exceeded', {
      endpoint: '/api/perfume-knowledge/lookup',
      clientKey,
      requestId,
    });
    return jsonResponse({ error: 'Rate limit exceeded. Please try again shortly.' }, 429, corsHeaders);
  }

  try {
    const fragranticaResult = await lookupFragranticaArabia(query);
    if (fragranticaResult.status === 'found') {
      logWorkerEvent('perfume_knowledge_lookup_fragrantica_success', {
        endpoint: '/api/perfume-knowledge/lookup',
        requestId,
        query: clipText(query, 120),
        profile: fragranticaResult.profile.displayName,
        confidence: fragranticaResult.profile.lookupConfidence,
      });
      return jsonResponse({ status: 'found', profile: fragranticaResult.profile }, 200, corsHeaders);
    }
    if (fragranticaResult.status === 'ambiguous') {
      logWorkerEvent('perfume_knowledge_lookup_fragrantica_ambiguous', {
        endpoint: '/api/perfume-knowledge/lookup',
        requestId,
        query: clipText(query, 120),
        candidateCount: fragranticaResult.candidates.length,
      });
      return jsonResponse({ status: 'ambiguous', candidates: fragranticaResult.candidates }, 200, corsHeaders);
    }
  } catch (error) {
    logWorkerEvent('perfume_knowledge_lookup_fragrantica_failed', {
      endpoint: '/api/perfume-knowledge/lookup',
      requestId,
      query: clipText(query, 120),
      errorName: error?.name || null,
      errorMessage: error?.message || null,
    });
  }

  const modelCandidates = await lookupModelBackedFragranticaCandidates(query, env);
  if (modelCandidates.length > 0) {
    const modelCandidateResult = await resolveLookupFromCandidates(query, modelCandidates);
    if (modelCandidateResult.status === 'found') {
      logWorkerEvent('perfume_knowledge_lookup_model_candidates_resolved', {
        endpoint: '/api/perfume-knowledge/lookup',
        requestId,
        query: clipText(query, 120),
        profile: modelCandidateResult.profile.displayName,
      });
      return jsonResponse({ status: 'found', profile: modelCandidateResult.profile }, 200, corsHeaders);
    }
    if (modelCandidateResult.status === 'ambiguous') {
      logWorkerEvent('perfume_knowledge_lookup_model_candidates_ambiguous', {
        endpoint: '/api/perfume-knowledge/lookup',
        requestId,
        query: clipText(query, 120),
        candidateCount: modelCandidateResult.candidates.length,
      });
      return jsonResponse({ status: 'ambiguous', candidates: modelCandidateResult.candidates }, 200, corsHeaders);
    }
  }

  return jsonResponse({ status: 'not_found', reason: 'source_lookup_failed' }, 200, corsHeaders);
}

async function handlePerfumeKnowledgeResolve(request, env, body, verifiedUid = null, corsHeaders = null) {
  warnOnUnknownKeys(body, ['sourceUrl', 'selectedName', 'requestId'], '/api/perfume-knowledge/resolve');
  const sourceUrl = typeof body?.sourceUrl === 'string' ? body.sourceUrl.trim() : '';
  const selectedName = typeof body?.selectedName === 'string' ? body.selectedName.trim() : '';
  const requestId = typeof body?.requestId === 'string' ? body.requestId.trim() : null;
  if (!isAllowedFragranticaArabiaPerfumeUrl(sourceUrl)) {
    return jsonResponse({ status: 'not_found', reason: 'source_url_not_allowed' }, 200, corsHeaders);
  }

  const clientKey = getClientKey(request, body || {}, verifiedUid);
  const isAllowed = await checkRateLimit(`knowledge_resolve:${clientKey}`, Date.now(), env);
  if (!isAllowed) {
    logWorkerEvent('rate_limit_exceeded', {
      endpoint: '/api/perfume-knowledge/resolve',
      clientKey,
      requestId,
    });
    return jsonResponse({ error: 'Rate limit exceeded. Please try again shortly.' }, 429, corsHeaders);
  }

  try {
    const profile = await resolveFragranticaArabiaProfile(sourceUrl, selectedName);
    if (!profile) return jsonResponse({ status: 'not_found', reason: 'profile_extract_failed' }, 200, corsHeaders);
    logWorkerEvent('perfume_knowledge_resolve_success', {
      endpoint: '/api/perfume-knowledge/resolve',
      requestId,
      selectedName: clipText(selectedName, 120),
      profile: profile.displayName,
      confidence: profile.lookupConfidence,
    });
    return jsonResponse({ status: 'found', profile }, 200, corsHeaders);
  } catch (error) {
    logWorkerEvent('perfume_knowledge_resolve_failed', {
      endpoint: '/api/perfume-knowledge/resolve',
      errorName: error?.name || null,
      errorMessage: error?.message || null,
      requestId,
    });
    return jsonResponse({ status: 'not_found', reason: 'transport_failure' }, 200, corsHeaders);
  }
}

async function handleAIChatFeedback(request, env, body, verifiedUid = null, corsHeaders = null) {
  const validation = validateAIChatFeedbackPayload(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.error }, 400, corsHeaders);
  }
  const storage = await storeAIChatFeedbackDebug(env, validation.payload);

  logWorkerEvent('ai_chat_negative_feedback_accepted', {
    endpoint: '/api/ai-chat-feedback',
    feedbackId: validation.payload.feedbackId,
    reason: validation.payload.feedback.reason,
    turnId: validation.payload.turnId,
    requestId: validation.payload.requestId,
    stored: storage.stored,
  });

  return jsonResponse({
    status: 'accepted',
    feedbackId: validation.payload.feedbackId,
    stored: storage.stored,
  }, 202, corsHeaders);
}

async function handleAIChatTurnDebug(request, env, body, verifiedUid = null, corsHeaders = null) {
  const validation = validateAIChatTurnDebugPayload(body);
  if (!validation.ok) {
    return jsonResponse({ error: validation.error }, 400, corsHeaders);
  }
  const storage = await storeAIChatTurnDebug(env, validation.payload);

  logWorkerEvent('ai_chat_turn_debug_accepted', {
    endpoint: '/api/ai-chat-turn-debug',
    chatDebugId: validation.payload.chatDebugId,
    turnId: validation.payload.turnId,
    requestId: validation.payload.requestId,
    route: validation.payload.route,
    stored: storage.stored,
  });

  return jsonResponse({
    status: 'accepted',
    chatDebugId: validation.payload.chatDebugId,
    turnId: validation.payload.turnId,
    stored: storage.stored,
  }, 202, corsHeaders);
}

export const __testables = {
  buildChatSystemPrompt,
  buildStructuredChatSystemPrompt,
  normalizeModelResponse,
  normalizeModelResponseV2,
  sanitizeCandidate,
  sanitizeCandidates,
  selectChatModelCandidates,
  sanitizeConversationContext,
  resolveCatalogCandidates,
  productToCandidate,
  isSafeFirestoreDocumentId,
  sanitizePreferences,
  normalizeInterpretationResponse,
  buildHeuristicInterpretation,
  sanitizePreferencePatch,
  applyPreferencePatch,
  mergePreferences,
  defaultAsk,
  buildDeterministicStructuredChatResponse,
  normalizeTimeoutMs,
  buildCandidateTimeoutFallbackResponse,
  isClearRecommendationRefinement,
  normalizePerfumeKnowledgeProfile,
  extractFragranticaArabiaProfileFromHtml,
  parseFragranticaArabiaCandidates,
  getCanonicalFragranticaArabiaCandidates,
  getFragranticaArabiaFamilyAmbiguityCandidates,
  searchFragranticaArabiaCandidates,
  lookupFragranticaArabia,
  resolveFragranticaArabiaProfile,
  isAllowedFragranticaArabiaPerfumeUrl,
  validateAIChatFeedbackPayload,
  validateAIChatTurnDebugPayload,
  storeAIChatTurnDebug,
  storeAIChatFeedbackDebug,
};

export default {
  async fetch(request, env) {
    const corsHeaders = buildCorsHeaders(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed. Use POST.' }, 405, corsHeaders);
    }

    try {
      const body = await request.json();

      // Resolve Firebase identity.
      const authIdentity = await resolveAuthContext(request, env);
      const verifiedUid = authIdentity?.uid || null;

      // Task 19: Hard Enforcement
      const isHardEnforcement = env.ENFORCE_AUTH === 'true';
      if (isHardEnforcement && !verifiedUid) {
        logWorkerEvent('auth_rejected', {
          note: 'Request rejected due to hard enforcement policy.',
        });
        return jsonResponse({ error: 'Unauthorized. Valid Firebase ID token required.' }, 401, corsHeaders);
      }

      if (request.url.includes('/api/ai-chat-turn-debug')) {
        try {
          return await handleAIChatTurnDebug(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/ai-chat-turn-debug',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
        }
      }

      if (request.url.includes('/api/ai-chat-feedback')) {
        try {
          return await handleAIChatFeedback(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/ai-chat-feedback',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
        }
      }

      if (request.url.includes('/api/feedback-analysis')) {
        try {
          return await handleFeedbackAnalysis(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/feedback-analysis',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
        }
      }

      if (request.url.includes('/api/perfume-knowledge/resolve')) {
        try {
          return await handlePerfumeKnowledgeResolve(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/perfume-knowledge/resolve',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
        }
      }

      if (request.url.includes('/api/perfume-knowledge/lookup')) {
        try {
          return await handlePerfumeKnowledgeLookup(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/perfume-knowledge/lookup',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
        }
      }

      if (request.url.includes('/api/interpret')) {
        try {
          return await handleInterpret(request, env, body, verifiedUid, corsHeaders);
        } catch (err) {
          logWorkerEvent('worker_unhandled_error', {
            endpoint: '/api/interpret',
            errorName: err?.name || 'UnknownError',
            errorMessage: err?.message || 'Unknown error',
          });
          return jsonResponse(emptyInterpretation('unexpected_error'), 200, corsHeaders);
        }
      }

      const apiKey = env.OPENROUTER_API_KEY;
      if (!apiKey) {
        return jsonResponse({ error: 'OPENROUTER_API_KEY is not configured on the worker.' }, 500, corsHeaders);
      }
      // Task 24: Structured warning for unknown keys
      warnOnUnknownKeys(body, [
        'currentMessage',
        'responseLanguage',
        'preferences',
        'candidates',
        'recentMessages',
        'lastAssistantQuestion',
        'lastAskSlot',
        'lastVisibleProductIds',
        'conversationContext',
        'sessionKey',
        'requestId',
      ], '/api/chat');

      const currentMessage = typeof body.currentMessage === 'string' ? body.currentMessage.trim() : '';
      const responseLanguage = body.responseLanguage === 'en' ? 'en' : 'ar';
      const preferences = sanitizePreferences(body.preferences);
      const submittedCandidates = sanitizeCandidates(body.candidates);
      const conversation = sanitizeConversationContext(body);
      const useStructuredV2 = env?.AI_CHAT_STRUCTURED_COMMANDS_V2 === 'true';
      const useToolRouterV1 = useStructuredV2 && env?.AI_CHAT_TOOL_ROUTER_V1 === 'true';
      const requestId = typeof body.requestId === 'string' ? body.requestId.trim() : null;

      if (requestId && requestId.length > MAX_REQUEST_ID_LENGTH) {
        return jsonResponse({ error: 'requestId is too long.' }, 400, corsHeaders);
      }
      if (typeof body.sessionKey === 'string' && body.sessionKey.trim().length > MAX_REQUEST_ID_LENGTH) {
        return jsonResponse({ error: 'sessionKey is too long.' }, 400, corsHeaders);
      }

      logWorkerEvent('chat_request_received', {
        endpoint: '/api/chat',
        requestId,
        verifiedUid,
        clientKey: getClientKey(request, body || {}, verifiedUid),
        messageLength: currentMessage.length,
        responseLanguage,
        preferences: summarizePreferencesForLog(preferences),
        candidates: summarizeCandidatesForLog(submittedCandidates),
        structuredV2: useStructuredV2,
        toolRouterV1: useToolRouterV1,
        contextMessageCount: conversation.recentMessages.length,
        lastAskSlot: conversation.lastAskSlot || null,
      });

      if (!currentMessage) {
        logWorkerEvent('chat_request_rejected', {
          endpoint: '/api/chat',
          reason: 'empty_message',
          requestId,
        });
        return jsonResponse({ error: 'currentMessage is required.' }, 400, corsHeaders);
      }

      if (currentMessage.length > MAX_CURRENT_MESSAGE_LENGTH) {
        logWorkerEvent('chat_request_rejected', {
          endpoint: '/api/chat',
          reason: 'message_too_long',
          requestId,
          messageLength: currentMessage.length,
        });
        return jsonResponse({ error: 'currentMessage is too long.' }, 400, corsHeaders);
      }

      if (useStructuredV2) {
        const deterministicStructured = buildDeterministicStructuredChatResponse(
          currentMessage,
          responseLanguage,
          requestId
        );
        if (deterministicStructured) {
          logWorkerEvent('chat_structured_deterministic_response', {
            endpoint: '/api/chat',
            requestId,
            type: deterministicStructured.type,
          });
          return jsonResponse(deterministicStructured, 200, corsHeaders);
        }
      }

      if (submittedCandidates.length === 0) {
        logWorkerEvent('chat_request_rejected', {
          endpoint: '/api/chat',
          reason: 'no_candidates',
          requestId,
          responseLanguage,
        });
        return jsonResponse(defaultAsk(
          preferences,
          responseLanguage,
          t(
            responseLanguage,
            'ШўШіЩЃШЊ Щ„Ш§ ШЄЩ€Ш¬ШЇ Ш№Ш·Щ€Ш± Щ…ШЄШ§Ш­Ш© Ш­Ш§Щ„ЩЉШ§Щ‹ ШЄШ·Ш§ШЁЩ‚ Щ‡Ш°Щ‡ Ш§Щ„Щ…Щ€Ш§ШµЩЃШ§ШЄ ШЁШ§Щ„Ш¶ШЁШ·. Щ‡Щ„ ШЄЩЃШ¶Щ‘Щ„ ШЄШ№ШЇЩЉЩ„ Ш§Щ„Щ…ЩЉШІШ§Щ†ЩЉШ© Щ‚Щ„ЩЉЩ„Ш§Щ‹ ШЈЩ€ ШЄШ¬Ш±ШЁШ© Щ†Щ€ШЄШ© Щ‚Ш±ЩЉШЁШ©Шџ',
            'Sorry, no current perfumes match these exact criteria. Would you like to adjust the budget slightly or try a similar note?'
          ),
        ), 200, corsHeaders);
      }

      // Use verified identity for rate limiting (prefers UID over body sessionKey).
      const clientKey = getClientKey(request, body || {}, verifiedUid);
      const isAllowed = await checkRateLimit(clientKey, Date.now(), env);
      if (!isAllowed) {
        logWorkerEvent('rate_limit_exceeded', {
          endpoint: '/api/chat',
          clientKey,
          requestId,
        });
        return jsonResponse({ error: 'Rate limit exceeded. Please try again shortly.' }, 429, corsHeaders);
      }

      let candidates;
      try {
        candidates = await resolveCatalogCandidates(env, submittedCandidates);
      } catch (error) {
        logWorkerEvent('catalog_verification_failed', {
          endpoint: '/api/chat',
          requestId,
          errorName: error?.name || null,
          errorMessage: error?.message || null,
          fallback: 'submitted_candidates',
        });
        candidates = submittedCandidates;
      }

      if (candidates.length === 0) {
        logWorkerEvent('chat_request_rejected', {
          endpoint: '/api/chat',
          reason: 'no_verified_candidates',
          requestId,
          responseLanguage,
        });
        return jsonResponse(defaultAsk(
          preferences,
          responseLanguage,
          t(
            responseLanguage,
            'No current perfumes match these exact criteria.',
            'Sorry, no current perfumes match these exact criteria. Would you like to adjust the budget slightly or try a similar note?'
          ),
        ), 200, corsHeaders);
      }

      logWorkerEvent('catalog_candidates_verified', {
        endpoint: '/api/chat',
        requestId,
        submittedCandidateCount: submittedCandidates.length,
        verifiedCandidateCount: candidates.length,
      });

      const systemPrompt = useStructuredV2
        ? buildStructuredChatSystemPrompt(responseLanguage, useToolRouterV1)
        : buildChatSystemPrompt(responseLanguage);
      const modelCandidates = selectChatModelCandidates(candidates);

      const openRouterPayload = buildOpenRouterPayload({
        systemText: systemPrompt,
        userText: [
          `Current Message: ${currentMessage}`,
          ...(useStructuredV2 ? [
            `Recent Messages: ${JSON.stringify(conversation.recentMessages)}`,
            `Last Assistant Question: ${conversation.lastAssistantQuestion || ''}`,
            `Last Ask Slot: ${conversation.lastAskSlot || ''}`,
            `Last Visible Product IDs: ${JSON.stringify(conversation.lastVisibleProductIds)}`,
            `Conversation Context: ${JSON.stringify(conversation.conversationContext)}`,
            `Commerce Context: ${JSON.stringify({
              visibleProducts: conversation.visibleProducts,
              lastFocusedProductId: conversation.lastFocusedProductId,
              lastRecommendationIds: conversation.lastRecommendationIds,
              pendingClarification: conversation.pendingClarification,
              lastNoMatch: conversation.lastNoMatch,
              currentPreferences: conversation.currentPreferences,
              rejectedProductIds: conversation.rejectedProductIds,
              allowedTools: conversation.allowedTools,
            })}`,
          ] : []),
          `Session Preferences: ${JSON.stringify(preferences)}`,
          `Candidates: ${JSON.stringify(modelCandidates)}`,
        ].join('\n'),
        temperature: 0.2,
        maxTokens: CHAT_MAX_OUTPUT_TOKENS,
      });

      const url = getOpenRouterEndpoint(env);

      let upstreamResult;
      try {
        upstreamResult = await callUpstreamModel({
          endpoint: url,
          requestBody: openRouterPayload,
          timeoutMs: normalizeTimeoutMs(env?.AI_CHAT_WORKER_HTTP_TIMEOUT_SECONDS != null
            ? Number(env.AI_CHAT_WORKER_HTTP_TIMEOUT_SECONDS) * 1000
            : env?.AI_CHAT_WORKER_HTTP_TIMEOUT_MS),
          maxAttempts: 1,
          extraHeaders: buildOpenRouterHeaders({ ...env, OPENROUTER_API_KEY: apiKey }),
        });
      } catch (error) {
        if (error?.failureType === 'timeout' && hasValidCandidateFallback(candidates, preferences)) {
          logWorkerEvent('chat_timeout_candidate_fallback', {
            endpoint: '/api/chat',
            requestId,
            latencyMs: error?.latencyMs ?? null,
            candidateCount: candidates.length,
            modelCandidateCount: modelCandidates.length,
            reason: 'model_timeout_valid_candidates_available',
          });
          return jsonResponse(buildCandidateTimeoutFallbackResponse(
            candidates,
            preferences,
            responseLanguage,
            requestId,
            error?.latencyMs ?? null,
          ), 200, corsHeaders);
        }
        logWorkerEvent('upstream_transport_failure', {
          endpoint: '/api/chat',
          failureType: error?.failureType || 'unknown',
          retryCount: error?.retryCount ?? 1,
          latencyMs: error?.latencyMs ?? null,
          errorName: error?.name || null,
          errorMessage: error?.message || null,
          requestId,
        });
        throw error;
      }

      const { response, data: openRouterData, retryCount, latencyMs } = upstreamResult;
      const usage = extractUsageMetrics(openRouterData);
      const upstreamErrorDetails = extractUpstreamErrorDetails(openRouterData);

      if (!response.ok) {
        logWorkerEvent('upstream_http_failure', {
          endpoint: '/api/chat',
          upstreamStatusCode: response.status,
          latencyMs,
          retryCount,
          requestId,
          ...upstreamErrorDetails,
          ...usage,
        });
        return jsonResponse({ error: 'Failed to generate recommendation. Please try again.' }, 500, corsHeaders);
      }

      const rawText = extractOpenRouterContent(openRouterData) || '{}';
      const parseSuccess = Boolean(extractJsonObject(rawText));
      const normalized = useStructuredV2
        ? normalizeModelResponseV2(
            rawText,
            candidates,
            preferences,
            responseLanguage,
            requestId,
            useToolRouterV1
          )
        : normalizeModelResponse(
            rawText,
            candidates,
            preferences,
            responseLanguage,
            requestId
          );
      const finalNormalized = normalized?.type === 'ask' &&
        isClearRecommendationRefinement(currentMessage, conversation) &&
        hasValidCandidateFallback(candidates, preferences)
          ? buildStructuredCandidateRecommendationResponse(
              candidates,
              preferences,
              responseLanguage,
              requestId,
              null,
              { fallbackReason: 'clear_refinement_ask_overridden' },
            )
          : normalized;

      logWorkerEvent('chat_response_normalized', {
        endpoint: '/api/chat',
        requestId,
        parseSuccess,
        responseLanguage,
        normalized: summarizeResponseForLog(finalNormalized),
        filteredCandidateCount: candidates.length,
        modelCandidateCount: modelCandidates.length,
        ...(finalNormalized !== normalized ? { routeQualityOverride: 'clear_refinement_ask_overridden' } : {}),
      });

      if (!parseSuccess) {
        logWorkerEvent('model_parse_failure', {
          endpoint: '/api/chat',
          upstreamStatusCode: response.status,
          latencyMs,
          retryCount,
          requestId,
          fallbackReason: 'parse_failure',
          rawTextLength: rawText.length,
          ...usage,
        });
      }

      logWorkerEvent('upstream_success', {
        endpoint: '/api/chat',
        upstreamStatusCode: response.status,
        latencyMs,
        retryCount,
        parseSuccess,
        verifiedUid,
        requestId,
        ...usage,
      });

      return jsonResponse(finalNormalized, 200, corsHeaders);
    } catch (err) {
      logWorkerEvent('worker_unhandled_error', {
        endpoint: '/api/chat',
        errorName: err?.name || 'UnknownError',
        errorMessage: err?.message || 'Unknown error',
        requestId,
      });
      return jsonResponse({ error: 'An unexpected error occurred. Please try again.' }, 500, corsHeaders);
    }
  },
};

async function handleFeedbackAnalysis(request, env, body, verifiedUid = null, corsHeaders = null) {
  const apiKey = env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return jsonResponse({ error: 'OPENROUTER_API_KEY is not configured on the worker.' }, 500, corsHeaders);
  }

  // Task 24: Structured warning for unknown keys
  warnOnUnknownKeys(body, ['analysisPayload', 'transcriptPayload', 'sessionFeedback', 'feedback', 'inlineFeedbackSummary', 'responseLanguage', 'requestId'], '/api/feedback-analysis');

  const analysis = sanitizeAnalysisPayload(body?.analysisPayload ?? body?.transcriptPayload ?? body);
  const sessionFeedback = sanitizeSessionFeedback(body?.sessionFeedback ?? body?.feedback);
  const inlineFeedbackSummary = body?.inlineFeedbackSummary && typeof body.inlineFeedbackSummary === 'object'
    ? body.inlineFeedbackSummary
    : null;
  const responseLanguage = body?.responseLanguage === 'en' ? 'en' : 'ar';
  const requestId = typeof body?.requestId === 'string' ? body.requestId.trim() : null;
  
  analysis.requestId = requestId; // Pass it for metadata in response

  logWorkerEvent('feedback_analysis_request_received', {
    endpoint: '/api/feedback-analysis',
    requestId,
    verifiedUid,
    sessionId: analysis.sessionId,
    transcriptCount: analysis.transcript.length,
    compactedMessageCount: analysis.compactedMessageCount,
    responseLanguage,
    feedback: {
      rating: sessionFeedback.rating,
      isHelpful: sessionFeedback.isHelpful,
      feedbackScope: sessionFeedback.feedbackScope,
    },
  });

  // Task 16: If a verified Firebase UID exists, override the body-supplied userId
  // to prevent client-side impersonation of another user's identity.
  if (verifiedUid && sessionFeedback.userId && sessionFeedback.userId !== verifiedUid) {
    logWorkerEvent('auth_userid_override', {
      endpoint: '/api/feedback-analysis',
      bodyUserId: sessionFeedback.userId,
      verifiedUid,
      note: 'Body userId overridden by verified Firebase UID.',
    });
    sessionFeedback.userId = verifiedUid;
  } else if (verifiedUid && !sessionFeedback.userId) {
    sessionFeedback.userId = verifiedUid;
  }

  if (!analysis.sessionId) {
    return jsonResponse({ error: 'sessionId is required.' }, 400, corsHeaders);
  }

  if (!sessionFeedback.sessionId) {
    return jsonResponse({ error: 'sessionFeedback.sessionId is required.' }, 400, corsHeaders);
  }

  if (!sessionFeedback.id) {
    return jsonResponse({ error: 'sessionFeedback.id is required.' }, 400, corsHeaders);
  }

  if (sessionFeedback.feedbackScope !== 'session') {
    return jsonResponse({ error: 'sessionFeedback.feedbackScope must be "session".' }, 400, corsHeaders);
  }

  if (!Number.isInteger(sessionFeedback.rating) || sessionFeedback.rating < 1 || sessionFeedback.rating > 5) {
    return jsonResponse({ error: 'sessionFeedback.rating must be an integer between 1 and 5.' }, 400, corsHeaders);
  }

  if (!sessionFeedback.userId) {
    return jsonResponse({ error: 'sessionFeedback.userId is required.' }, 400, corsHeaders);
  }

  if (sessionFeedback.targetMessageId) {
    return jsonResponse({ error: 'sessionFeedback.targetMessageId must be null for session analysis.' }, 400, corsHeaders);
  }

  if (sessionFeedback.sessionId !== analysis.sessionId) {
    return jsonResponse({ error: 'sessionId mismatch between analysis payload and session feedback.' }, 400, corsHeaders);
  }

  if (analysis.transcript.length === 0) {
    return jsonResponse({ error: 'At least one compacted transcript entry is required.' }, 400, corsHeaders);
  }

  // Use verified identity for rate limiting in feedback analysis too.
  const clientKey = getClientKey(request, body || {}, verifiedUid);
  const isAllowed = await checkRateLimit(clientKey, Date.now(), env);
  if (!isAllowed) {
    logWorkerEvent('rate_limit_exceeded', {
      endpoint: '/api/feedback-analysis',
      clientKey,
      requestId,
    });
    return jsonResponse({ error: 'Rate limit exceeded. Please try again shortly.' }, 429, corsHeaders);
  }

  const analysisPrompt = buildAnalysisPrompt({
    analysis,
    sessionFeedback,
    inlineFeedbackSummary,
    language: responseLanguage,
  });

  const openRouterPayload = buildOpenRouterPayload({
    systemText: analysisPrompt,
    userText: `Analyze the feedback for session ${analysis.sessionId}.`,
    temperature: 0.1,
    maxTokens: FEEDBACK_MAX_OUTPUT_TOKENS,
  });

  const url = getOpenRouterEndpoint(env);
  let upstreamResult;
  try {
    upstreamResult = await callUpstreamModel({
      endpoint: url,
      requestBody: openRouterPayload,
      extraHeaders: buildOpenRouterHeaders({ ...env, OPENROUTER_API_KEY: apiKey }),
    });
  } catch (error) {
    logWorkerEvent('upstream_transport_failure', {
      endpoint: '/api/feedback-analysis',
      failureType: error?.failureType || 'unknown',
      retryCount: error?.retryCount ?? 1,
      latencyMs: error?.latencyMs ?? null,
      errorName: error?.name || null,
      errorMessage: error?.message || null,
      requestId,
    });
    throw error;
  }

  const { response, data: openRouterData, retryCount, latencyMs } = upstreamResult;
  const usage = extractUsageMetrics(openRouterData);
  const upstreamErrorDetails = extractUpstreamErrorDetails(openRouterData);

  if (!response.ok) {
    logWorkerEvent('upstream_http_failure', {
      endpoint: '/api/feedback-analysis',
      upstreamStatusCode: response.status,
      latencyMs,
      retryCount,
      requestId,
      ...upstreamErrorDetails,
      ...usage,
    });
    return jsonResponse({ error: 'Failed to analyze feedback. Please try again.' }, 500, corsHeaders);
  }

  const rawText = extractOpenRouterContent(openRouterData) || '{}';
  const parseSuccess = Boolean(extractJsonObject(rawText));
  const normalizedInput = {
    analysis,
    sessionFeedback,
    inlineFeedbackSummary,
  };
  const normalized = normalizeAnalysisResponse(rawText, normalizedInput, responseLanguage);

  logWorkerEvent('feedback_analysis_normalized', {
    endpoint: '/api/feedback-analysis',
    requestId,
    parseSuccess,
    normalized: {
      id: normalized.id,
      status: normalized.status,
      intentUnderstood: normalized.intentUnderstood,
      needSatisfied: normalized.needSatisfied,
      satisfactionScore: normalized.satisfactionScore,
      sentiment: normalized.sentiment,
      missingNeedsCount: Array.isArray(normalized.missingNeeds) ? normalized.missingNeeds.length : 0,
    },
  });

  if (!parseSuccess) {
    logWorkerEvent('model_parse_failure', {
      endpoint: '/api/feedback-analysis',
      upstreamStatusCode: response.status,
      latencyMs,
      retryCount,
      requestId,
      fallbackReason: 'parse_failure',
      rawTextLength: rawText.length,
      ...usage,
    });
  }

  logWorkerEvent('upstream_success', {
    endpoint: '/api/feedback-analysis',
    upstreamStatusCode: response.status,
    latencyMs,
    retryCount,
    parseSuccess,
    requestId,
    ...usage,
  });

  return jsonResponse(normalized, 200, corsHeaders);
}
