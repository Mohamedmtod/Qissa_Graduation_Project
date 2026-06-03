#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';

const TAXONOMY_VERSION = 1;
const DEFAULT_COLLECTION = 'products';

const GROUPS = {
  useCase: ['office', 'university', 'wedding', 'daily', 'gift', 'date'],
  vibe: [
    'clean',
    'fresh',
    'elegant',
    'luxury',
    'youthful',
    'classic',
    'masculine',
    'feminine',
  ],
  comfort: ['soft_on_nose', 'non_offensive', 'not_headachey', 'not_cloying'],
  performance: [
    'long_lasting',
    'moderate_projection',
    'loud_projection',
    'soft_projection',
  ],
  risk: ['safe_blind_buy', 'medium_risk', 'polarizing', 'crowd_pleaser'],
  famousDna: [
    'sauvage_like',
    'acqua_di_gio_like',
    'aventus_like',
    'good_girl_like',
    'baccarat_like',
  ],
  warnings: [
    'too_sweet_for_some',
    'not_for_hot_weather',
    'too_loud_for_sensitive_nose',
  ],
};

const SCORING_TAGS = new Set(
  Object.entries(GROUPS)
    .filter(([group]) => group !== 'warnings')
    .flatMap(([, tags]) => tags),
);
const WARNING_TAGS = new Set(GROUPS.warnings);
const FAMOUS_DNA_TAGS = new Set(GROUPS.famousDna);

const GROUP_BY_TAG = new Map(
  Object.entries(GROUPS).flatMap(([group, tags]) =>
    tags.map((tag) => [tag, group]),
  ),
);

const GROUP_PRIORITY = {
  useCase: 0,
  vibe: 1,
  comfort: 2,
  risk: 3,
  performance: 4,
  famousDna: 5,
};

function parseArgs(argv) {
  const args = {
    collection: DEFAULT_COLLECTION,
    limit: 80,
    status: 'reviewed',
    confidence: 2,
    overwrite: false,
    write: false,
    out: null,
    input: null,
    restRead: false,
    restWrite: false,
    useGcloudAdc: false,
    useFirebaseCliAuth: false,
    useFirebaseCliListAuth: false,
    apiKey: process.env.FIREBASE_WEB_API_KEY,
    accessToken: process.env.GOOGLE_OAUTH_ACCESS_TOKEN,
    projectId: process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => argv[++i];
    if (arg === '--help' || arg === '-h') args.help = true;
    else if (arg === '--input') args.input = next();
    else if (arg === '--out') args.out = next();
    else if (arg === '--project-id') args.projectId = next();
    else if (arg === '--api-key') args.apiKey = next();
    else if (arg === '--access-token') args.accessToken = next();
    else if (arg === '--collection') args.collection = next();
    else if (arg === '--limit') args.limit = Number.parseInt(next(), 10);
    else if (arg === '--status') args.status = next();
    else if (arg === '--confidence') args.confidence = Number.parseInt(next(), 10);
    else if (arg === '--overwrite') args.overwrite = true;
    else if (arg === '--rest-read') args.restRead = true;
    else if (arg === '--rest-write') args.restWrite = true;
    else if (arg === '--use-gcloud-adc') args.useGcloudAdc = true;
    else if (arg === '--use-firebase-cli-auth') args.useFirebaseCliAuth = true;
    else if (arg === '--use-firebase-cli-list-auth') args.useFirebaseCliListAuth = true;
    else if (arg === '--write') args.write = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return args;
}

function printHelp() {
  console.log(`Staff Taste Firestore Patch Tool

Safe defaults:
  - dry-run unless --write is passed
  - skips products that already have staffTagScores unless --overwrite is passed
  - writes only PR11 staff intelligence fields
  - does not read .env, service accounts, logs, or dumps

Input modes:
  1) JSON export:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --input products.json --out staff_patch_preview.json

     Accepted JSON shapes:
       [{ "id": "productId", "name": "...", ... }]
       { "products": [{ "id": "productId", ... }] }
       { "docs": [{ "id": "productId", "data": { ... } }] }

  2) Firestore fetch through firebase-admin + local ADC:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --project-id YOUR_PROJECT --out staff_patch_preview.json

  3) Public Firestore REST read for products rules with allow read:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --rest-read --project-id YOUR_PROJECT --api-key WEB_API_KEY --out staff_patch_preview.json

  4) Firestore write, explicit:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --project-id YOUR_PROJECT --write --limit 80

  5) Firestore REST write using local gcloud ADC, explicit:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --rest-read --rest-write --use-gcloud-adc --project-id YOUR_PROJECT --api-key WEB_API_KEY --write --limit 80

  6) Firestore REST write using current firebase login, explicit:
     node testing_tools/tool/staff_taste_firestore_patch.mjs --rest-read --rest-write --use-firebase-cli-auth --project-id YOUR_PROJECT --api-key WEB_API_KEY --write --limit 80

Options:
  --collection products        Firestore collection name
  --limit 80                  Max products to patch
  --status reviewed           draft | reviewed | trusted
  --confidence 2              1 | 2 | 3
  --overwrite                 Replace existing staffTagScores
  --rest-read                 Read Firestore via REST/API key instead of firebase-admin
  --rest-write                Write Firestore via REST/OAuth instead of firebase-admin
  --use-gcloud-adc            Read OAuth token from gcloud application-default without printing it
  --use-firebase-cli-auth     Read OAuth token from current Firebase CLI login without printing it
  --use-firebase-cli-list-auth Read OAuth token from firebase login:list --json without printing it
  --api-key KEY               Firebase Web API key for --rest-read
  --access-token TOKEN        OAuth token for --rest-write, or set GOOGLE_OAUTH_ACCESS_TOKEN
  --write                     Commit to Firestore
`);
}

function readProductsFromJson(filePath) {
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
  const rows = Array.isArray(raw) ? raw : raw.products || raw.docs;
  if (!Array.isArray(rows)) {
    throw new Error('Input JSON must be an array, {products: []}, or {docs: []}.');
  }
  return rows.map((row, index) => {
    if (row.data && typeof row.data === 'object') {
      return { id: row.id || row.documentId || `row_${index}`, data: row.data };
    }
    return { id: row.id || row.documentId || row.productId || `row_${index}`, data: row };
  });
}

async function readProductsFromFirestore({ projectId, collection, limit }) {
  const admin = loadFirebaseAdmin();
  if (!projectId) {
    throw new Error('Missing --project-id or GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.');
  }
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  }
  const snapshot = await admin
    .firestore()
    .collection(collection)
    .limit(limit)
    .get();
  return snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
}

async function readProductsFromFirestoreRest({
  projectId,
  apiKey,
  collection,
  limit,
}) {
  if (!projectId) {
    throw new Error('Missing --project-id for --rest-read.');
  }
  if (!apiKey) {
    throw new Error('Missing --api-key or FIREBASE_WEB_API_KEY for --rest-read.');
  }

  const products = [];
  let pageToken = '';
  while (products.length < limit) {
    const pageSize = Math.min(300, limit - products.length);
    const url = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}`,
    );
    url.searchParams.set('pageSize', String(pageSize));
    url.searchParams.set('key', apiKey);
    if (pageToken) url.searchParams.set('pageToken', pageToken);

    const response = await fetch(url);
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Firestore REST read failed ${response.status}: ${body}`);
    }

    const payload = await response.json();
    for (const doc of payload.documents || []) {
      products.push({
        id: String(doc.name || '').split('/').pop(),
        data: decodeFirestoreFields(doc.fields || {}),
      });
    }
    pageToken = payload.nextPageToken || '';
    if (!pageToken || !payload.documents?.length) break;
  }
  return products;
}

function decodeFirestoreFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeFirestoreValue(value)]),
  );
}

function decodeFirestoreValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number.parseInt(value.integerValue, 10);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return Boolean(value.booleanValue);
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  if ('mapValue' in value) {
    return decodeFirestoreFields(value.mapValue.fields || {});
  }
  return null;
}

function loadFirebaseAdmin() {
  const localRequire = createRequire(import.meta.url);
  const candidates = [
    'firebase-admin',
    path.resolve('backend_and_cloud/functions/node_modules/firebase-admin'),
    path.resolve('backend_and_cloud/workers/perfume-orders-worker/node_modules/firebase-admin'),
  ];
  for (const candidate of candidates) {
    try {
      return localRequire(candidate);
    } catch (_) {
      // Try the next known local install location.
    }
  }
  throw new Error(
    'firebase-admin is not available. Run from a workspace with existing node_modules, for example backend_and_cloud/functions after npm install.',
  );
}

async function writePatchesToFirestore({ projectId, collection, patches }) {
  const admin = loadFirebaseAdmin();
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  }

  const db = admin.firestore();
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  let batch = db.batch();
  let count = 0;
  for (const patch of patches) {
    const ref = db.collection(collection).doc(patch.id);
    batch.set(
      ref,
      {
        ...patch.staffFields,
        staffUpdatedAt: timestamp,
      },
      { merge: true },
    );
    count += 1;
    if (count % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (count % 400 !== 0) {
    await batch.commit();
  }
  return count;
}

async function writePatchesToFirestoreRest({
  projectId,
  collection,
  patches,
  accessToken,
  useGcloudAdc,
  useFirebaseCliAuth,
  useFirebaseCliListAuth,
}) {
  const token =
    accessToken ||
    (useGcloudAdc ? readGcloudAccessToken() : null) ||
    (useFirebaseCliAuth ? await readFirebaseCliAccessToken() : null) ||
    (useFirebaseCliListAuth ? readFirebaseCliListAccessToken() : null);
  if (!projectId) {
    throw new Error('Missing --project-id for --rest-write.');
  }
  if (!token) {
    throw new Error(
      'Missing OAuth token for --rest-write. Use --use-gcloud-adc or GOOGLE_OAUTH_ACCESS_TOKEN.',
    );
  }

  let written = 0;
  for (const patch of patches) {
    const fields = encodeFirestoreFields({
      ...patch.staffFields,
      staffUpdatedAt: new Date().toISOString(),
    });
    const fieldPaths = Object.keys(fields);
    const url = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${patch.id}`,
    );
    for (const field of fieldPaths) {
      url.searchParams.append('updateMask.fieldPaths', field);
    }

    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fields }),
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Firestore REST write failed for ${patch.id} ${response.status}: ${body}`);
    }
    written += 1;
  }
  return written;
}

function readFirebaseCliListAccessToken() {
  const result = spawnSync('firebase', ['login:list', '--json'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    shell: process.platform === 'win32',
  });
  if (result.status !== 0) {
    throw new Error(
      `firebase login:list failed. stderr: ${String(result.stderr || '').trim()}`,
    );
  }
  const parsed = JSON.parse(String(result.stdout || '{}'));
  const accounts = Array.isArray(parsed.result) ? parsed.result : [];
  const first = accounts.find((account) => account?.tokens?.access_token);
  const token = first?.tokens?.access_token;
  if (!token || typeof token !== 'string') {
    throw new Error('Firebase CLI login:list did not return an access token.');
  }
  return token;
}

async function readFirebaseCliAccessToken() {
  const firebaseAuth = loadFirebaseToolsAuth();
  const account = firebaseAuth.getGlobalDefaultAccount?.();
  const refreshToken = account?.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('Firebase CLI is not logged in or has no refresh token.');
  }
  const token = await firebaseAuth.getAccessToken(refreshToken, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/datastore',
    'https://www.googleapis.com/auth/firebase',
  ]);
  const accessToken = token?.access_token || token;
  if (!accessToken || typeof accessToken !== 'string') {
    throw new Error('Firebase CLI did not return an access token.');
  }
  return accessToken;
}

function loadFirebaseToolsAuth() {
  const localRequire = createRequire(import.meta.url);
  const candidates = [
    'firebase-tools/lib/auth',
    path.resolve(
      process.env.APPDATA || '',
      'npm/node_modules/firebase-tools/lib/auth.js',
    ),
  ];
  for (const candidate of candidates) {
    try {
      return localRequire(candidate);
    } catch (_) {
      // Try the next known local install location.
    }
  }
  throw new Error('firebase-tools auth module is not available.');
}

function readGcloudAccessToken() {
  const result = spawnSync('gcloud', ['auth', 'application-default', 'print-access-token'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.status !== 0) {
    throw new Error(
      `gcloud application-default token failed. stderr: ${String(result.stderr || '').trim()}`,
    );
  }
  const token = String(result.stdout || '').trim();
  if (!token) throw new Error('gcloud returned an empty access token.');
  return token;
}

function encodeFirestoreFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeFirestoreValue(value)]),
  );
}

function encodeFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') {
    if (/^\d{4}-\d{2}-\d{2}T/.test(value)) return { timestampValue: value };
    return { stringValue: value };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeFirestoreValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFirestoreFields(value) } };
  }
  return { stringValue: String(value) };
}

function buildPatch({ id, data }, options) {
  const existingScores = objectValue(data.staffTagScores);
  if (!options.overwrite && Object.keys(existingScores).length > 0) {
    return { id, skipped: true, reason: 'already_has_staffTagScores' };
  }

  const tags = generateStaffTaste(data);
  const staffTagScores = sanitizeScores(tags.scores);
  const staffWarnings = sanitizeWarnings(tags.warnings);
  const staffDataCoverage = calculateCoverage(staffTagScores);
  const staffIntelligenceStatus = normalizeStatus(options.status);
  const staffConfidence = clampInt(options.confidence, 1, 3);
  const staffSalesNotes = buildStaffSalesNotes(data, staffTagScores, staffWarnings);
  const similarFamousDna = Object.keys(staffTagScores).filter((tag) =>
    FAMOUS_DNA_TAGS.has(tag),
  );

  return {
    id,
    skipped: false,
    staffFields: {
      staffTagScores,
      staffWarnings,
      staffSalesNotes,
      similarFamousDna,
      staffIntelligenceStatus,
      reviewNeeded: staffIntelligenceStatus === 'draft',
      staffConfidence,
      staffDataCoverage,
      staffTaxonomyVersion: TAXONOMY_VERSION,
      staffUpdatedBy: 'staff_taste_patch_tool',
      staffReviewCount: staffIntelligenceStatus === 'draft' ? 0 : 1,
    },
  };
}

function generateStaffTaste(product) {
  const scores = {};
  const warnings = new Set();
  const text = normalizeText([
    product.id,
    product.name,
    product.nameAr,
    product.brand,
    product.brandAr,
    product.fragranceFamily,
    product.family,
    product.gender,
    product.season,
    product.occasion,
    product.time,
    product.intensity,
    ...(arrayValue(product.notes)),
    ...(arrayValue(product.tags)),
    ...(arrayValue(product.topNotes)),
    ...(arrayValue(product.middleNotes)),
    ...(arrayValue(product.baseNotes)),
    ...(arrayValue(product.aliases)),
    ...(arrayValue(product.aliasesAr)),
  ].join(' '));
  const price = numberValue(product.effectivePrice ?? product.salePrice ?? product.price);
  const intensity = normalizeText(product.intensity || '');
  const gender = normalizeText(product.gender || '');
  const occasion = normalizeText(product.occasion || '');
  const season = normalizeText(product.season || '');

  const hasAny = (...needles) => needles.some((needle) => text.includes(needle));
  const add = (tag, score) => {
    if (!SCORING_TAGS.has(tag)) return;
    scores[tag] = Math.max(scores[tag] || 0, clampInt(score, 1, 3));
  };

  if (hasAny('office', 'work', 'شغل', 'مكتب')) add('office', 3);
  if (hasAny('university', 'college', 'campus', 'جامعة')) add('university', 3);
  if (hasAny('wedding', 'formal', 'فرح', 'مناسبة')) add('wedding', 3);
  if (hasAny('daily', 'day', 'everyday', 'يومي')) add('daily', 3);
  if (hasAny('gift', 'هدية', 'هديه')) add('gift', 3);
  if (hasAny('date', 'romantic', 'night', 'خروجة')) add('date', 2);

  if (hasAny('clean', 'musk', 'soap', 'نضيف')) add('clean', 3);
  if (hasAny('fresh', 'citrus', 'aquatic', 'bergamot', 'فريش')) add('fresh', 3);
  if (hasAny('elegant', 'classic', 'floral', 'rose', 'شيك')) add('elegant', 2);
  if (hasAny('luxury', 'premium', 'baccarat', 'oud', 'amber', 'فخم')) add('luxury', 2);
  if (hasAny('youthful', 'sweet', 'fruity', 'vanilla', 'شباب')) add('youthful', 2);
  if (hasAny('classic', 'كلاسيك')) add('classic', 3);
  if (gender.includes('men') || hasAny('masculine', 'رجالي')) add('masculine', 3);
  if (gender.includes('women') || hasAny('feminine', 'نسائي')) add('feminine', 3);

  if (hasAny('light', 'soft') || intensity.includes('light')) {
    add('soft_projection', 3);
    add('soft_on_nose', 3);
  }
  if (hasAny('clean', 'fresh', 'musk', 'aquatic')) {
    add('non_offensive', 2);
    add('not_cloying', 2);
  }
  if (!hasAny('oud', 'heavy') && !intensity.includes('strong')) {
    add('not_headachey', 2);
  }

  if (intensity.includes('strong') || hasAny('strong', 'loud', 'beast')) {
    add('loud_projection', 3);
    add('long_lasting', 3);
  } else if (intensity.includes('medium') || hasAny('medium')) {
    add('moderate_projection', 3);
  } else {
    add('moderate_projection', 2);
  }

  if (hasAny('fresh', 'clean', 'classic', 'musk') && !hasAny('polarizing', 'oud')) {
    add('safe_blind_buy', 2);
    add('crowd_pleaser', 2);
  }
  if (hasAny('oud', 'tobacco', 'leather', 'smoky') || intensity.includes('strong')) {
    add('medium_risk', 2);
  }
  if (hasAny('polarizing', 'animalic')) add('polarizing', 3);

  if (hasAny('sauvage', 'سوفاج')) add('sauvage_like', 3);
  if (hasAny('acqua di gio', 'acqua', 'gio', 'اكوا')) add('acqua_di_gio_like', 3);
  if (hasAny('aventus', 'افينتوس')) add('aventus_like', 3);
  if (hasAny('good girl', 'جود جيرل')) add('good_girl_like', 3);
  if (hasAny('baccarat', 'باكارات')) add('baccarat_like', 3);

  if (hasAny('sweet', 'vanilla', 'caramel')) warnings.add('too_sweet_for_some');
  if (hasAny('winter', 'oud', 'amber', 'tobacco') || intensity.includes('strong')) {
    warnings.add('not_for_hot_weather');
  }
  if (scores.loud_projection >= 3) warnings.add('too_loud_for_sensitive_nose');

  applyFallbacks({ scores, price, occasion, season, text });
  return {
    scores: pruneScores(scores),
    warnings: Array.from(warnings).filter((tag) => WARNING_TAGS.has(tag)),
  };
}

function applyFallbacks({ scores, price, occasion, season, text }) {
  const add = (tag, score) => {
    scores[tag] = Math.max(scores[tag] || 0, score);
  };
  if (!hasGroup(scores, 'useCase')) {
    if (price > 5000) add('wedding', 2);
    else if (season.includes('summer') || text.includes('fresh')) add('daily', 3);
    else add('daily', 2);
  }
  if (!hasGroup(scores, 'vibe')) {
    add(price > 5000 ? 'luxury' : 'clean', 2);
  }
  if (!hasGroup(scores, 'comfort')) {
    add('non_offensive', 2);
  }
  if (!hasGroup(scores, 'performance')) {
    add('moderate_projection', 2);
  }
  if (!hasGroup(scores, 'risk')) {
    add(occasion.includes('date') ? 'medium_risk' : 'safe_blind_buy', 2);
  }
}

function pruneScores(scores) {
  const entries = Object.entries(scores)
    .filter(([tag, score]) => SCORING_TAGS.has(tag) && score >= 1 && score <= 3)
    .sort(([tagA, scoreA], [tagB, scoreB]) => {
      const groupDelta =
        (GROUP_PRIORITY[GROUP_BY_TAG.get(tagA)] ?? 99) -
        (GROUP_PRIORITY[GROUP_BY_TAG.get(tagB)] ?? 99);
      if (groupDelta !== 0) return groupDelta;
      return scoreB - scoreA || tagA.localeCompare(tagB);
    });
  return Object.fromEntries(entries.slice(0, 15));
}

function buildStaffSalesNotes(product, scores, warnings) {
  const name = product.name || product.id || 'This product';
  const bestTags = Object.entries(scores)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([tag]) => tag.replaceAll('_', ' '));
  const watchOut = warnings.length > 0 ? ` Watch out: ${warnings.join(', ')}.` : '';
  return {
    en: `${name} is a ${bestTags.join(', ')} pick based on staff taste tags.${watchOut}`.trim(),
    ar: `${name} اختيار مناسب حسب تاجات الموظفين: ${bestTags.join('، ')}.${watchOut}`.trim(),
  };
}

function sanitizeScores(scores) {
  return Object.fromEntries(
    Object.entries(scores)
      .filter(([tag, score]) => SCORING_TAGS.has(tag) && score >= 1 && score <= 3)
      .map(([tag, score]) => [tag, clampInt(score, 1, 3)]),
  );
}

function sanitizeWarnings(warnings) {
  return Array.from(new Set(warnings)).filter((tag) => WARNING_TAGS.has(tag));
}

function calculateCoverage(scores) {
  const tags = Object.keys(scores);
  if (tags.length === 0) return 0;
  const groups = new Set(tags.map((tag) => GROUP_BY_TAG.get(tag)));
  let coverage = 0;
  if (tags.length >= 3) coverage += 0.4;
  if (groups.has('useCase')) coverage += 0.3;
  if (groups.has('vibe') || groups.has('comfort')) coverage += 0.3;
  return Math.max(0, Math.min(1, Number(coverage.toFixed(2))));
}

function hasGroup(scores, group) {
  return Object.keys(scores).some((tag) => GROUP_BY_TAG.get(tag) === group);
}

function normalizeStatus(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'trusted' || normalized === 'reviewed') return normalized;
  return 'draft';
}

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u064B-\u0652\u0670]/g, '')
    .replace(/\u0640/g, ' ')
    .replace(/[^\p{L}\p{N}\s_]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function arrayValue(value) {
  return Array.isArray(value) ? value.map(String) : [];
}

function objectValue(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function numberValue(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number.parseFloat(String(value || '').replaceAll(',', ''));
  return Number.isFinite(parsed) ? parsed : 0;
}

function clampInt(value, min, max) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return min;
  return Math.max(min, Math.min(max, parsed));
}

function writePreview(outPath, payload) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }

  if (!Number.isFinite(args.limit) || args.limit <= 0) {
    throw new Error('--limit must be a positive number.');
  }

  const products = args.input
    ? readProductsFromJson(args.input)
    : args.restRead
    ? await readProductsFromFirestoreRest(args)
    : await readProductsFromFirestore(args);

  const selected = products.slice(0, args.limit);
  const results = selected.map((product) => buildPatch(product, args));
  const patches = results.filter((item) => !item.skipped);
  const skipped = results.filter((item) => item.skipped);
  const preview = {
    mode: args.write ? 'write' : 'dry-run',
    collection: args.collection,
    taxonomyVersion: TAXONOMY_VERSION,
    selectedCount: selected.length,
    patchCount: patches.length,
    skippedCount: skipped.length,
    skipped,
    patches,
  };

  if (args.out) {
    writePreview(args.out, preview);
  }

  if (args.write) {
    if (!args.projectId) {
      throw new Error('Refusing write without --project-id.');
    }
    const written = args.restWrite
      ? await writePatchesToFirestoreRest({
          projectId: args.projectId,
          collection: args.collection,
          patches,
          accessToken: args.accessToken,
          useGcloudAdc: args.useGcloudAdc,
          useFirebaseCliAuth: args.useFirebaseCliAuth,
          useFirebaseCliListAuth: args.useFirebaseCliListAuth,
        })
      : await writePatchesToFirestore({
          projectId: args.projectId,
          collection: args.collection,
          patches,
        });
    console.log(`Wrote ${written} product staff-taste patches to ${args.collection}.`);
  } else {
    console.log(
      `Dry-run complete: ${patches.length} patches, ${skipped.length} skipped. ${
        args.out ? `Preview: ${args.out}` : 'Pass --out to save a preview.'
      }`,
    );
  }
}

main().catch((error) => {
  console.error(error?.stack || error?.message || error);
  process.exitCode = 1;
});
