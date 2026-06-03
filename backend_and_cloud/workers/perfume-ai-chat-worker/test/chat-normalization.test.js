import test from 'node:test';
import assert from 'node:assert/strict';
import { __testables } from '../src/index.js';

const {
  buildChatSystemPrompt,
  buildStructuredChatSystemPrompt,
  normalizeModelResponse,
  normalizeModelResponseV2,
  normalizeInterpretationResponse,
  buildDeterministicStructuredChatResponse,
  buildHeuristicInterpretation,
  sanitizeCandidates,
  selectChatModelCandidates,
  sanitizeConversationContext,
  sanitizePreferencePatch,
  applyPreferencePatch,
  defaultAsk,
  normalizeTimeoutMs,
  buildCandidateTimeoutFallbackResponse,
  isClearRecommendationRefinement,
  resolveCatalogCandidates,
  productToCandidate,
  isSafeFirestoreDocumentId,
  normalizePerfumeKnowledgeProfile,
  extractFragranticaArabiaProfileFromHtml,
  getCanonicalFragranticaArabiaCandidates,
  getFragranticaArabiaFamilyAmbiguityCandidates,
  searchFragranticaArabiaCandidates,
  lookupFragranticaArabia,
  resolveFragranticaArabiaProfile,
  isAllowedFragranticaArabiaPerfumeUrl,
  validateAIChatFeedbackPayload,
  validateAIChatTurnDebugPayload,
  storeAIChatTurnDebug,
} = __testables;

const baseCandidate = {
  id: 'p1',
  name: 'Candidate 1',
  price: 1000,
  gender: 'men',
  notes: ['citrus'],
  topNotes: ['bergamot'],
  middleNotes: ['lavender'],
  baseNotes: ['musk'],
  tags: ['fresh', 'clean'],
};

test('interpret heuristic recognizes typo recommendation requests', () => {
  const result = buildHeuristicInterpretation(
    'reccomend somthing very good',
    'en',
    {},
  );

  assert.equal(result.intent, 'recommendation');
  assert.ok(result.confidence >= 0.85);
  assert.equal(result.askSlot, 'gender');
});

test('interpret heuristic maps Arabic both-genders phrase to unisex', () => {
  const result = buildHeuristicInterpretation(
    'أفضل يكون للأثنين',
    'ar',
    {},
  );

  assert.equal(result.intent, 'recommendation');
  assert.equal(result.preferencePatch.gender, 'unisex');
  assert.ok(result.confidence >= 0.85);
});

test('interpret heuristic maps Arabic strength phrasing to intensity', () => {
  const result = buildHeuristicInterpretation(
    'هل تستطيع اعطائي ترشيحات من حيث قوة الرواح',
    'ar',
    {},
  );

  assert.equal(result.intent, 'recommendation');
  assert.equal(result.preferencePatch.intensity, 'strong');
  assert.equal(result.askSlot, 'maxBudget');
});

test('interpret normalizer ignores product ids and invalid values', () => {
  const result = normalizeInterpretationResponse({
    intent: 'availability',
    confidence: 1.5,
    product_ids: ['p1'],
    preferencePatch: {
      gender: 'invalid',
      season: 'winter',
      maxBudget: '1,200',
    },
    askSlot: 'bad_slot',
    reasonCode: 'Bad Reason!!',
  });

  assert.equal(result.intent, 'availability');
  assert.equal(result.confidence, 1);
  assert.equal(result.preferencePatch.gender, null);
  assert.equal(result.preferencePatch.season, 'winter');
  assert.equal(result.preferencePatch.maxBudget, 1200);
  assert.equal(result.askSlot, null);
  assert.equal(result.productQueryCandidate, null);
  assert.equal(result.product_ids, undefined);
  assert.equal(result.reasonCode, 'bad_reason');
});

test('interpret normalizer accepts product query candidate only as plain text', () => {
  const result = normalizeInterpretationResponse({
    intent: 'availability',
    confidence: 0.88,
    productQueryCandidate: '  Rosendo   Mateu  ',
    preferencePatch: {},
    askSlot: null,
    reasonCode: 'availability_candidate',
  });

  assert.equal(result.intent, 'availability');
  assert.equal(result.productQueryCandidate, 'Rosendo Mateu');
});

test('structured prompt tells the model to use compact conversation context', () => {
  const prompt = buildStructuredChatSystemPrompt('en');

  assert.match(prompt, /schemaVersion=2/);
  assert.match(prompt, /recentMessages/);
  assert.match(prompt, /lastAssistantQuestion/);
  assert.match(prompt, /show_recommendation_cards/);
  assert.doesNotMatch(prompt, /type="tool_call"/);
});

test('structured prompt forbids no-match when safe candidates are available', () => {
  const prompt = buildStructuredChatSystemPrompt('en');

  assert.match(prompt, /filtered by the app for catalog validity and basic safety/i);
  assert.match(prompt, /do not return no_match if at least one candidate/i);
  assert.match(prompt, /closest candidate cards with a concise caveat/i);
});

test('structured prompt includes tool router instructions only when enabled', () => {
  const prompt = buildStructuredChatSystemPrompt('en', true);

  assert.match(prompt, /type="tool_call"/);
  assert.match(prompt, /search_products/);
  assert.match(prompt, /similar_cheaper/);
  assert.match(prompt, /show_lowest_available_after_budget_no_match/);
  assert.match(prompt, /resolve language ambiguity first/);
  assert.match(prompt, /ask_clarification/);
  assert.match(prompt, /sweet\/sugary or nice\/beautiful\/pleasant/);
  assert.match(prompt, /The app will validate and execute the tool/);
});

test('chat context sanitizer caps messages and redacts sensitive values', () => {
  const context = sanitizeConversationContext({
    recentMessages: [
      { role: 'user', text: 'one' },
      { role: 'assistant', text: 'two' },
      { role: 'user', text: 'three' },
      { role: 'assistant', text: 'four' },
      { role: 'user', text: 'five' },
      { role: 'assistant', text: 'six' },
      { role: 'user', text: 'email user@example.com 01012345678' },
    ],
    lastAssistantQuestion: 'Season?',
    lastAskSlot: 'season',
    lastVisibleProductIds: ['p1', '../bad'],
    conversationContext: {
      hasRecommendationContext: true,
      lastTurnWasAsk: true,
    },
  });

  assert.equal(context.recentMessages.length, 6);
  assert.equal(context.lastAskSlot, 'season');
  assert.deepEqual(context.lastVisibleProductIds, ['p1']);
  assert.match(context.recentMessages.at(-1).text, /\[redacted_email\]/);
  assert.match(context.recentMessages.at(-1).text, /\[redacted_phone\]/);
});

test('chat context sanitizer preserves bounded commerce context v2', () => {
  const context = sanitizeConversationContext({
    visibleProducts: [
      {
        index: 1,
        id: 'p1',
        name: 'Light Blue',
        brand: 'Dolce',
        price: 3250,
        notes: ['citrus', 'fresh'],
      },
      { index: 2, id: '../bad', name: 'Bad' },
    ],
    lastFocusedProductId: 'p1',
    lastRecommendationIds: ['p1', '../bad'],
    pendingClarification: {
      type: 'product_reference',
      options: [{ index: 1, id: 'p1', name: 'Light Blue' }],
    },
    lastNoMatch: {
      reason: 'budget_no_match',
      requestedBudget: 600,
      lowestAvailablePrice: 790,
      lowestAvailableProductIds: ['floor', '../bad'],
    },
    currentPreferences: { gender: 'men', maxBudget: 600 },
    rejectedProductIds: ['old1', '../bad'],
    allowedTools: ['similar_cheaper', 'delete_products'],
  });

  assert.equal(context.visibleProducts.length, 1);
  assert.equal(context.visibleProducts[0].id, 'p1');
  assert.equal(context.lastFocusedProductId, 'p1');
  assert.deepEqual(context.lastRecommendationIds, ['p1']);
  assert.equal(context.pendingClarification.options[0].id, 'p1');
  assert.equal(context.lastNoMatch.reason, 'budget_no_match');
  assert.deepEqual(context.lastNoMatch.lowestAvailableProductIds, ['floor']);
  assert.equal(context.currentPreferences.gender, 'men');
  assert.deepEqual(context.rejectedProductIds, ['old1']);
  assert.deepEqual(context.allowedTools, ['similar_cheaper']);
});

test('structured v2 normalizer returns bounded recommendation commands', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'These fit.',
      preferencesPatch: {
        replaceScalars: { season: 'all_seasons' },
      },
      commands: [
        {
          action: 'show_recommendation_cards',
          productIds: ['p1', 'missing'],
        },
      ],
      recommendations: [
        { productId: 'p1', reason: 'Matches citrus notes.' },
      ],
    }),
    [baseCandidate],
    { gender: 'men', maxBudget: 1200 },
    'en',
    'req-1',
  );

  assert.equal(result.schemaVersion, 2);
  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.equal(result.recommendations[0].productId, 'p1');
  assert.equal(result.preferencesPatch.setScalars.season, 'all_seasons');
  assert.equal(result.metadata.requestId, 'req-1');
});

test('structured v2 normalizer overrides no-match when valid candidates exist', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'no_match',
      message: 'No safe match.',
      commands: [{ action: 'show_no_match', productIds: [] }],
    }),
    [baseCandidate],
    { gender: 'men', intensity: 'light' },
    'en',
    'req-no-match-candidates',
  );

  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.equal(result.message, 'I found the closest safe catalog matches based on your request.');
});

test('structured v2 normalizer recommends closest candidates for vague recommendation with candidates', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'no_match',
      message: 'Cannot recommend.',
      commands: [{ action: 'show_no_match', productIds: [] }],
    }),
    [baseCandidate],
    {},
    'en',
    'req-vague-recommend',
  );

  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
});

test('structured v2 normalizer fills recommendation from candidates when model gives only fake ids', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'Try these.',
      commands: [
        { action: 'show_recommendation_cards', productIds: ['fake'] },
      ],
      recommendations: [
        { productId: 'fake', reason: 'Fake reason.' },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-fake-ids',
  );

  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.equal(result.recommendations[0].productId, 'p1');
});

test('structured v2 normalizer keeps valid ids and drops fake ids', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'These fit your request well.',
      commands: [
        { action: 'show_recommendation_cards', productIds: ['p1', 'fake'] },
      ],
      recommendations: [
        { productId: 'p1', reason: 'Matches citrus notes.' },
        { productId: 'fake', reason: 'Fake reason.' },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-mixed-ids',
  );

  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.deepEqual(result.recommendations.map((item) => item.productId), ['p1']);
});

test('structured v2 normalizer does not invent fallback cards when candidates are empty', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'Try these.',
      commands: [
        { action: 'show_recommendation_cards', productIds: ['fake'] },
      ],
    }),
    [],
    { gender: 'men' },
    'en',
    'req-empty-candidates',
  );

  assert.equal(result.type, 'no_match');
  assert.equal(result.commands[0].action, 'show_no_match');
});

test('structured v2 normalizer replaces generic English recommendation copy', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'Understood.',
      commands: [
        { action: 'show_recommendation_cards', productIds: ['p1'] },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-generic-en',
  );

  assert.equal(result.type, 'recommendation');
  assert.notEqual(result.message, 'Understood.');
  assert.equal(result.message, 'I found the closest safe catalog matches based on your request.');
});

test('structured v2 normalizer replaces generic Arabic recommendation copy', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      language: 'ar',
      message: 'تمام.',
      commands: [
        { action: 'show_recommendation_cards', productIds: ['p1'] },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'ar',
    'req-generic-ar',
  );

  assert.equal(result.type, 'recommendation');
  assert.notEqual(result.message, 'تمام.');
  assert.doesNotMatch(result.message, /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/);
});

test('structured v2 normalizer handles availability without turning it into recommendation', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'availability',
      message: 'Understood.',
      commands: [],
    }),
    [baseCandidate],
    {},
    'en',
    'req-availability-card',
  );

  assert.equal(result.type, 'availability');
  assert.equal(result.commands[0].action, 'show_product_card');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.notEqual(result.message, 'Understood.');
});

test('structured v2 normalizer does not pick arbitrary availability card from multiple candidates', () => {
  const secondCandidate = { ...baseCandidate, id: 'p2', name: 'Candidate 2' };
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'availability',
      message: 'Understood.',
      commands: [],
    }),
    [baseCandidate, secondCandidate],
    {},
    'en',
    'req-availability-ambiguous',
  );

  assert.equal(result.type, 'no_match');
  assert.equal(result.commands[0].action, 'show_no_match');
});

test('structured v2 normalizer accepts valid tool_call only when flag is on', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      message: 'Searching catalog.',
      toolCall: {
        name: 'search_products',
        arguments: {
          gender: 'men',
          occasion: 'university',
          intensity: 'light',
          tags: ['fresh', 'clean'],
          limit: 9,
        },
      },
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-tool',
    true,
  );

  assert.equal(result.schemaVersion, 2);
  assert.equal(result.type, 'tool_call');
  assert.equal(result.toolCall.name, 'search_products');
  assert.deepEqual(result.toolCall.arguments.tags, ['fresh', 'clean']);
  assert.equal(result.toolCall.arguments.limit, 5);
  assert.deepEqual(result.commands, []);
  assert.deepEqual(result.recommendations, []);
  assert.equal(result.metadata.requestId, 'req-tool');
});

test('structured v2 normalizer accepts semantic commerce tool calls', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      message: 'Finding a similar lower-priced option.',
      toolCall: {
        name: 'similar_cheaper',
        confidence: 0.91,
        arguments: {
          anchorRef: 'last_focused_product',
          limit: 3,
        },
      },
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-similar-tool',
    true,
  );

  assert.equal(result.type, 'tool_call');
  assert.equal(result.toolCall.name, 'similar_cheaper');
  assert.equal(result.toolCall.confidence, 0.91);
  assert.equal(result.toolCall.arguments.anchorRef, 'last_focused_product');
  assert.equal(result.toolCall.arguments.limit, 3);
  assert.deepEqual(result.commands, []);
});

test('structured v2 normalizer rejects tool_call when flag is off', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      message: 'Searching catalog.',
      toolCall: {
        name: 'search_products',
        arguments: { gender: 'men' },
      },
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-tool-off',
    false,
  );

  assert.equal(result.type, 'no_match');
  assert.equal(result.commands[0].action, 'show_no_match');
  assert.equal(result.toolCall, undefined);
});

test('structured v2 normalizer rejects unknown tool_call names and invalid args', () => {
  const unknown = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      toolCall: {
        name: 'delete_products',
        arguments: {},
      },
    }),
    [baseCandidate],
    {},
    'en',
    'req-bad-tool',
    true,
  );
  const invalidArgs = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      toolCall: {
        name: 'search_products',
        arguments: ['bad'],
      },
    }),
    [baseCandidate],
    {},
    'en',
    'req-bad-args',
    true,
  );

  assert.equal(unknown.type, 'no_match');
  assert.equal(invalidArgs.type, 'no_match');
});

test('structured v2 normalizer sanitizes update_preferences tool patch', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'tool_call',
      toolCall: {
        name: 'update_preferences',
        arguments: {
          preferencePatch: {
            clearScalars: ['intensity', 'bad'],
            appendLists: {
              tags: ['fresh'],
              unknown: ['x'],
            },
          },
        },
      },
    }),
    [baseCandidate],
    { intensity: 'strong' },
    'en',
    'req-patch-tool',
    true,
  );

  assert.equal(result.type, 'tool_call');
  assert.deepEqual(result.toolCall.arguments.preferencePatch.clearScalars, [
    'intensity',
  ]);
  assert.deepEqual(result.toolCall.arguments.preferencePatch.appendLists.tags, [
    'fresh',
  ]);
});

test('structured v2 normalizer drops unknown commands and fills invalid cards from candidates', () => {
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      message: 'Try these.',
      commands: [
        { action: 'clear_cards', productIds: ['p1'] },
        { action: 'show_recommendation_cards', productIds: ['missing'] },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-2',
  );

  assert.equal(result.type, 'recommendation');
  assert.equal(result.commands[0].action, 'show_recommendation_cards');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
});

test('structured v2 normalizer blocks mojibake Arabic message text', () => {
  const rawMojibake = '\u00D0\u00A9\u00E2\u0080\u00A1\u00D0\u00A9\u00E2\u0080\u009E';
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'ask',
      language: 'ar',
      message: rawMojibake,
      commands: [],
      recommendations: [],
    }),
    [baseCandidate],
    {},
    'ar',
    'req-mojibake',
  );

  assert.equal(result.schemaVersion, 2);
  assert.equal(result.type, 'ask');
  assert.notEqual(result.message, rawMojibake);
  assert.doesNotMatch(result.message, /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/);
});

test('structured v2 normalizer replaces mojibake Arabic recommendation message', () => {
  const rawMojibake = '\u00D0\u00A9\u00E2\u0080\u00A1\u00D0\u00A9\u00E2\u0080\u009E';
  const result = normalizeModelResponseV2(
    JSON.stringify({
      schemaVersion: 2,
      type: 'recommendation',
      language: 'ar',
      message: rawMojibake,
      commands: [
        { action: 'show_recommendation_cards', productIds: ['p1'] },
      ],
    }),
    [baseCandidate],
    { gender: 'men' },
    'ar',
    'req-mojibake-recommendation',
  );

  assert.equal(result.schemaVersion, 2);
  assert.equal(result.type, 'recommendation');
  assert.notEqual(result.message, rawMojibake);
  assert.doesNotMatch(result.message, /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/);
});

test('deterministic structured response asks clean Arabic sweet ambiguity question', () => {
  const result = buildDeterministicStructuredChatResponse(
    'رشحلي ريحة حلوة',
    'ar',
    'req-ar-sweet-fast',
  );

  assert.equal(result.type, 'ask');
  assert.equal(result.message, 'تقصد ريحة مسكرة وحلوة، ولا ريحة جميلة ولطيفة عمومًا؟');
  assert.equal(result.metadata.reasonCode, 'ambiguous_egyptian_sweet_fast_path');
  assert.doesNotMatch(result.message, /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/);
});

test('deterministic structured response does not intercept explicit sugary sweet request', () => {
  const result = buildDeterministicStructuredChatResponse(
    'عايز ريحة حلوة مسكرة',
    'ar',
    'req-ar-sugary',
  );

  assert.equal(result, null);
});

test('default Arabic ask fallback is clean Unicode', () => {
  const result = defaultAsk({}, 'ar', null, 'req-default-ar');

  assert.equal(result.action_type, 'ask');
  assert.doesNotMatch(result.question, /[\u00D0\u00D8\u00D9\u00C3\u00E2\u0400-\u04FF\uFFFD]/);
});

test('chat timeout configuration is clamped to safe bounds', () => {
  assert.equal(normalizeTimeoutMs(undefined), 10000);
  assert.equal(normalizeTimeoutMs(2000), 4000);
  assert.equal(normalizeTimeoutMs(45000), 10000);
  assert.equal(normalizeTimeoutMs('9000'), 9000);
});

test('timeout fallback returns bounded candidate recommendation metadata', () => {
  const result = buildCandidateTimeoutFallbackResponse(
    [baseCandidate],
    { gender: 'men' },
    'en',
    'req-timeout-fallback',
    12034,
  );

  assert.equal(result.type, 'recommendation');
  assert.deepEqual(result.commands[0].productIds, ['p1']);
  assert.equal(result.metadata.modelTimedOut, true);
  assert.equal(result.metadata.modelTimeoutHit, true);
  assert.equal(result.metadata.fallbackFromCandidates, true);
  assert.equal(result.metadata.fallbackReason, 'model_timeout_candidate_fallback');
  assert.equal(result.metadata.modelLatencyMs, 12034);
  assert.notEqual(result.message, 'Understood.');
});

test('chat model prompt candidates are capped without reordering', () => {
  const candidates = Array.from({ length: 20 }, (_, index) => ({
    ...baseCandidate,
    id: `p${index + 1}`,
  }));
  const result = selectChatModelCandidates(candidates);

  assert.equal(result.length, 12);
  assert.deepEqual(result.map((candidate) => candidate.id), [
    'p1',
    'p2',
    'p3',
    'p4',
    'p5',
    'p6',
    'p7',
    'p8',
    'p9',
    'p10',
    'p11',
    'p12',
  ]);
});

test('clear recommendation refinement is detected only with recommendation context', () => {
  assert.equal(
    isClearRecommendationRefinement(
      'make it suitable for university',
      { conversationContext: { hasRecommendationContext: true } },
    ),
    true,
  );
  assert.equal(
    isClearRecommendationRefinement(
      'make it suitable for university',
      { conversationContext: { hasRecommendationContext: false } },
    ),
    false,
  );
});

test('interpret heuristic extracts availability product candidate', () => {
  const result = buildHeuristicInterpretation(
    'do you have Rosendo Mateu?',
    'en',
    {},
  );

  assert.equal(result.intent, 'availability');
  assert.equal(result.productQueryCandidate, 'rosendo mateu');
  assert.ok(result.confidence >= 0.75);
});

test('interpret heuristic does not use generic perfume as availability candidate', () => {
  const result = buildHeuristicInterpretation(
    'do you have perfume?',
    'en',
    {},
  );

  assert.notEqual(result.intent, 'availability');
  assert.equal(result.productQueryCandidate, null);
});

test('malformed model response falls back to ask', () => {
  const result = normalizeModelResponse(
    'not a json response',
    [baseCandidate],
    { maxBudget: 1000, gender: 'men' },
    'en',
    'req-malformed',
  );

  assert.equal(result.action_type, 'ask');
  assert.equal(result.updated_preferences.maxBudget, 1000);
  assert.equal(result.updated_preferences.gender, 'men');
  assert.ok(typeof result.question === 'string' && result.question.length > 0);
});

test('chat system prompt includes worker-first filtered candidate guidance', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /pre-filtered locally/i);
  assert.match(prompt, /prefer recommend over ask/i);
  assert.match(
    prompt,
    /do not ask for a constraint that is already satisfied/i,
  );
});

test('chat system prompt includes confidence rule', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /Confidence Rule/i);
  assert.match(prompt, /at least 1 candidate/i);
  assert.match(prompt, /Gender and Budget/i);
  assert.match(prompt, /Do not ask for preferred notes or intensity/i);
});

test('chat system prompt includes lifestyle mapping', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /Lifestyle Mapping/i);
  assert.match(prompt, /Doctor\/Hospital/i);
  assert.match(prompt, /Office\/Meeting/i);
  assert.match(prompt, /Wedding\/Night/i);
});

test('chat system prompt includes naming integrity', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /Naming Integrity/i);
  assert.match(prompt, /Brand \+ Name/i);
  assert.match(prompt, /Never shorten or truncate product names/i);
});

test('chat system prompt includes cheaper alternative priority', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /Price-Sensitive Switching/i);
  assert.match(prompt, /cheaper alternative/i);
  assert.match(prompt, /similar but less expensive/i);
  assert.match(prompt, /lower price than the product currently discussed/i);
});

test('chat system prompt forbids preference updates from recommendations', () => {
  const prompt = buildChatSystemPrompt('en');

  assert.match(prompt, /Do not update preferences based on your own recommendations/i);
  assert.match(prompt, /only based on explicit user input/i);
});

test('invalid product ids are dropped; all invalid falls back to ask', () => {
  const mixed = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['invalid-id', 'p1'],
      match_reason: {
        'invalid-id': 'bad',
        p1: 'good',
      },
      updated_preferences: {},
    }),
    [baseCandidate],
    { maxBudget: 1500 },
    'en',
    'req-mixed-ids',
  );

  assert.equal(mixed.action_type, 'recommend');
  assert.deepEqual(mixed.product_ids, ['p1']);

  const allInvalid = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['x1', 'x2'],
      match_reason: { x1: 'bad', x2: 'bad' },
      updated_preferences: {},
    }),
    [baseCandidate],
    { maxBudget: 1500 },
    'en',
    'req-all-invalid',
  );

  assert.equal(allInvalid.action_type, 'ask');
});

test('budget >10% is rejected by worker normalization filter', () => {
  const withinTenPercent = {
    ...baseCandidate,
    id: 'p-within',
    price: 1099,
  };
  const aboveTenPercent = {
    ...baseCandidate,
    id: 'p-over',
    price: 1101,
  };

  const mixedBudget = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['p-over', 'p-within'],
      match_reason: {
        'p-over': 'over',
        'p-within': 'within',
      },
      updated_preferences: {},
    }),
    [aboveTenPercent, withinTenPercent],
    { maxBudget: 1000, gender: 'men' },
    'en',
    'req-budget-mixed',
  );

  assert.equal(mixedBudget.action_type, 'recommend');
  assert.deepEqual(mixedBudget.product_ids, ['p-within']);

  const allOverBudget = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['p-over'],
      match_reason: { 'p-over': 'over' },
      updated_preferences: {},
    }),
    [aboveTenPercent],
    { maxBudget: 1000, gender: 'men' },
    'en',
    'req-budget-all-over',
  );

  assert.equal(allOverBudget.action_type, 'ask');
});

test('normalization enforces maximum three product ids', () => {
  const candidates = ['p1', 'p2', 'p3', 'p4'].map((id, index) => ({
    ...baseCandidate,
    id,
    name: `Candidate ${index + 1}`,
  }));

  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['p1', 'p2', 'p3', 'p4'],
      match_reason: {
        p1: 'good',
        p2: 'good',
        p3: 'good',
        p4: 'good',
      },
      updated_preferences: {},
    }),
    candidates,
    { maxBudget: 1500 },
    'en',
    'req-max-three',
  );

  assert.equal(result.action_type, 'recommend');
  assert.deepEqual(result.product_ids, ['p1', 'p2', 'p3']);
});

test('ask response with clear filtered candidates is normalized to top three recommendations', () => {
  const candidates = ['p1', 'p2', 'p3', 'p4'].map((id, index) => ({
    ...baseCandidate,
    id,
    name: `Candidate ${index + 1}`,
    reasonFacts: {
      matchedNotes: ['citrus'],
      matchedContext: ['gender:men'],
      budget: { price: 1000, withinBudget: true },
      productProfile: { notes: ['citrus', 'musk'] },
    },
  }));

  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'ask',
      question: 'What budget do you prefer?',
      updated_preferences: {},
    }),
    candidates,
    {
      gender: 'men',
      intensity: 'strong',
      preferredNotes: ['citrus', 'woody'],
      tags: ['fresh'],
    },
    'en',
    'req-ask-override',
  );

  assert.equal(result.action_type, 'recommend');
  assert.deepEqual(result.product_ids, ['p1', 'p2', 'p3']);
  assert.equal(result.metadata.requestId, 'req-ask-override');
  assert.match(result.match_reason.p1, /citrus|men/i);
});

test('candidate budget metadata is sanitized and preserved as context', () => {
  const candidates = sanitizeCandidates([
    {
      ...baseCandidate,
      budgetStatus: 'slightlyAboveBudget',
      exactBudget: 900,
      overBudgetAmount: 100,
      localMatchReason: 'Fits men and summer context.',
      reasonFacts: {
        matchedNotes: ['citrus'],
        matchedContext: ['gender:men', 'season:summer'],
        budget: { exactBudget: 900, price: 1000, withinBudget: false },
        productProfile: { notes: ['citrus', 'musk'] },
        cautions: ['slightly above budget'],
      },
    },
  ]);

  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].budgetStatus, 'slightlyAboveBudget');
  assert.equal(candidates[0].exactBudget, 900);
  assert.equal(candidates[0].overBudgetAmount, 100);
  assert.equal(candidates[0].localMatchReason, 'Fits men and summer context.');
  assert.deepEqual(candidates[0].reasonFacts.matchedNotes, ['citrus']);
  assert.deepEqual(candidates[0].reasonFacts.cautions, ['slightly above budget']);
});

test('catalog verification uses server catalog data instead of client candidate price', async () => {
  const submitted = sanitizeCandidates([
    {
      ...baseCandidate,
      id: 'p1',
      price: 1,
      notes: ['fake-client-note'],
      reasonFacts: {
        matchedNotes: ['citrus'],
        matchedContext: ['gender:men'],
      },
    },
  ]);

  const verified = await resolveCatalogCandidates(
    { ENFORCE_CATALOG_TRUTH: 'true' },
    submitted,
    async () => [
      {
        id: 'p1',
        name: 'Server Product',
        price: 1000,
        salePrice: 800,
        gender: 'men',
        notes: ['server-note'],
      },
    ],
  );

  assert.equal(verified.length, 1);
  assert.equal(verified[0].name, 'Server Product');
  assert.equal(verified[0].price, 800);
  assert.deepEqual(verified[0].notes, ['server-note']);
  assert.deepEqual(verified[0].reasonFacts.matchedNotes, ['citrus']);
});

test('generic model match reason is replaced with grounded reason facts', () => {
  const candidate = {
    ...baseCandidate,
    reasonFacts: {
      matchedNotes: ['citrus'],
      matchedContext: ['gender:men', 'season:summer'],
      budget: { exactBudget: 1500, price: 1000, withinBudget: true },
      productProfile: { notes: ['citrus', 'musk'] },
    },
  };
  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['p1'],
      match_reason: { p1: 'Good match.' },
      updated_preferences: {},
    }),
    [candidate],
    { maxBudget: 1500, gender: 'men', season: 'summer' },
    'en',
    'req-grounded-reason',
  );

  assert.equal(result.action_type, 'recommend');
  assert.match(result.match_reason.p1, /citrus/i);
  assert.match(result.match_reason.p1, /men|summer/i);
  assert.notEqual(result.match_reason.p1, 'Good match.');
});

test('arabic grounded match reason localizes context values', () => {
  const candidate = {
    ...baseCandidate,
    reasonFacts: {
      matchedContext: ['gender:men', 'season:winter'],
      budget: { exactBudget: 3000, price: 1375, withinBudget: true },
      productProfile: { notes: ['musk'] },
    },
  };
  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'recommend',
      product_ids: ['p1'],
      match_reason: { p1: 'Good match.' },
      updated_preferences: {},
    }),
    [candidate],
    { maxBudget: 3000, gender: 'men', season: 'winter' },
    'ar',
    'req-ar-grounded-reason',
  );

  assert.equal(result.action_type, 'recommend');
  assert.match(result.match_reason.p1, /رجالي|شتوي/);
  assert.doesNotMatch(result.match_reason.p1, /\bmen\b|\bwinter\b/);
});

test('catalog truth rejects unsafe Firestore document ids', async () => {
  assert.equal(isSafeFirestoreDocumentId('safe_ID-123'), true);
  assert.equal(isSafeFirestoreDocumentId('../products/p1'), false);
  assert.equal(isSafeFirestoreDocumentId('products/p1'), false);

  const verified = await resolveCatalogCandidates(
    { ENFORCE_CATALOG_TRUTH: 'true' },
    sanitizeCandidates([{ ...baseCandidate, id: '../products/p1' }]),
    async () => {
      throw new Error('loader should not be called for unsafe IDs');
    },
  );

  assert.deepEqual(verified, []);
});

test('productToCandidate uses sale price only when it is a real discount', () => {
  const discounted = productToCandidate({
    id: 'p1',
    name: 'Discounted',
    price: 1000,
    salePrice: 900,
  });
  const invalidSale = productToCandidate({
    id: 'p2',
    name: 'Invalid Sale',
    price: 1000,
    salePrice: 1200,
  });

  assert.equal(discounted.price, 900);
  assert.equal(invalidSale.price, 1000);
});

test('answer action returns text only and drops product ids', () => {
  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'answer',
      answer: 'Candidate 1 is fresher because it has citrus and bergamot.',
      product_ids: ['p1'],
      match_reason: { p1: 'fresh' },
      updated_preferences: {},
    }),
    [baseCandidate],
    { maxBudget: 1500 },
    'en',
    'req-answer',
  );

  assert.equal(result.action_type, 'answer');
  assert.equal(result.answer, 'Candidate 1 is fresher because it has citrus and bergamot.');
  assert.equal(Object.hasOwn(result, 'product_ids'), false);
  assert.equal(Object.hasOwn(result, 'match_reason'), false);
});

test('explicit preference patch clears and removes stale values safely', () => {
  const rawPatch = sanitizePreferencePatch({
    clearScalars: ['maxBudget', 'unsafe'],
    replaceLists: {
      preferredNotes: ['citrus'],
      unknownList: ['bad'],
    },
    removeLists: {
      excludedNotes: ['oud'],
    },
  });

  assert.deepEqual(rawPatch.clearScalars, ['maxBudget']);
  assert.deepEqual(rawPatch.replaceLists.preferredNotes, ['citrus']);
  assert.equal(Object.hasOwn(rawPatch.replaceLists, 'unknownList'), false);

  const applied = applyPreferencePatch(
    {
      gender: 'men',
      maxBudget: 1500,
      preferredNotes: ['vanilla'],
      excludedNotes: ['oud', 'musk'],
    },
    rawPatch,
  );

  assert.equal(applied.maxBudget, null);
  assert.deepEqual(applied.preferredNotes, ['citrus']);
  assert.deepEqual(applied.excludedNotes, ['musk']);
});

test('model preference_patch is returned with normalized response', () => {
  const result = normalizeModelResponse(
    JSON.stringify({
      action_type: 'ask',
      question: 'Budget removed.',
      updated_preferences: {},
      preference_patch: {
        clearScalars: ['maxBudget'],
        removeLists: { preferredNotes: ['oud'] },
      },
    }),
    [baseCandidate],
    { maxBudget: 1500, preferredNotes: ['oud', 'citrus'] },
    'en',
    'req-preference-patch',
  );

  assert.equal(result.action_type, 'ask');
  assert.equal(result.updated_preferences.maxBudget, null);
  assert.deepEqual(result.updated_preferences.preferredNotes, ['citrus']);
  assert.deepEqual(result.preference_patch.clearScalars, ['maxBudget']);
});

test('fragrantica arabia URL allowlist accepts only perfume pages', () => {
  assert.equal(
    isAllowedFragranticaArabiaPerfumeUrl(
      'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Parfum-56324.html',
    ),
    true,
  );
  assert.equal(
    isAllowedFragranticaArabiaPerfumeUrl('https://example.com/perfumes/Dior/Sauvage-Parfum-56324.html'),
    false,
  );
  assert.equal(
    isAllowedFragranticaArabiaPerfumeUrl('https://www.fragranticarabia.com/search/?q=Sauvage'),
    false,
  );
});

test('canonical fragrantica hints cover known external perfumes without broad single-token autopick', () => {
  const expected = new Map([
    ['Dior Sauvage', 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-31861.html'],
    ['Dior Sauvage Eau de Parfum', 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Eau-de-Parfum-48100.html'],
    ['Dior Sauvage Parfum', 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-Parfum-56324.html'],
    ['Bleu de Chanel', 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-9099.html'],
    ['Bleu de Chanel Eau de Parfum', 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-Eau-de-Parfum-25967.html'],
    ['Bleu de Chanel Parfum', 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-Parfum-49912.html'],
    ['Creed Aventus', 'https://www.fragranticarabia.com/perfumes/Creed/Aventus-9828.html'],
    ['Baccarat Rouge 540', 'https://www.fragranticarabia.com/perfumes/Maison-Francis-Kurkdjian/Baccarat-Rouge-540-33519.html'],
    ['Azzaro Pour Homme', 'https://www.fragranticarabia.com/perfumes/Azzaro/Azzaro-pour-Homme-829.html'],
  ]);

  for (const [query, sourceUrl] of expected.entries()) {
    const candidates = getCanonicalFragranticaArabiaCandidates(query);
    assert.equal(candidates.length, 1);
    assert.equal(candidates[0].sourceUrl, sourceUrl);
    assert.equal(isAllowedFragranticaArabiaPerfumeUrl(candidates[0].sourceUrl), true);
    assert.equal(candidates[0].score, 1);
  }

  assert.equal(getCanonicalFragranticaArabiaCandidates('Sauvage').length, 0);
  assert.equal(getCanonicalFragranticaArabiaCandidates('Blue').length, 0);
});

test('single-token famous external families return top ambiguous options without fetch or autopick', async () => {
  const sauvageCandidates = getFragranticaArabiaFamilyAmbiguityCandidates('Sauvage');
  assert.equal(sauvageCandidates.length, 3);
  assert.deepEqual(
    sauvageCandidates.map((candidate) => candidate.displayName),
    ['Sauvage', 'Sauvage Eau de Parfum', 'Sauvage Parfum'],
  );

  const blueCandidates = getFragranticaArabiaFamilyAmbiguityCandidates('Blue');
  assert.equal(blueCandidates.length, 3);
  assert.deepEqual(
    blueCandidates.map((candidate) => candidate.displayName),
    ['Bleu de Chanel', 'Bleu de Chanel Eau de Parfum', 'Bleu de Chanel Parfum'],
  );

  let fetchCalled = false;
  const result = await lookupFragranticaArabia('Sauvage', async () => {
    fetchCalled = true;
    throw new Error('single-token family ambiguity should not fetch');
  });

  assert.equal(fetchCalled, false);
  assert.equal(result.status, 'ambiguous');
  assert.equal(result.candidates.length, 3);
  assert.equal(result.candidates[0].displayName, 'Sauvage');
});

test('perfume knowledge normalization rejects empty scent profiles', () => {
  const rejected = normalizePerfumeKnowledgeProfile(
    {
      displayName: 'Imaginary Perfume',
      brand: 'Unknown',
      lookupConfidence: 0.9,
    },
    'Imaginary Perfume',
  );

  assert.equal(rejected, null);

  const accepted = normalizePerfumeKnowledgeProfile(
    {
      displayName: 'Known Perfume',
      brand: 'Known',
      accords: ['Citrus', 'Woody', 'Citrus'],
      lookupConfidence: 1.5,
    },
    'Known Perfume',
  );

  assert.equal(accepted.lookupConfidence, 1);
  assert.deepEqual(accepted.accords, ['Citrus', 'Woody']);
});

test('fragrantica arabia parser extracts Azzaro profile from HTML', () => {
  const html = `
    <html><body>
      <h1>Azzaro pour Homme Azzaro للرجال</h1>
      <div>الإتفاقات الرئيسية أروماتك خشبي تابلي منعش ترابي الخزامي طحلبي الجلود الحمضيات ناعم تابلي دافئ البحث عن طريق الأكوردات</div>
      <h4>الإفتتاحية</h4><p>الخزامي, الليمون, الكاراوية, الريحان, البرغموت, المريمية, السوسن و الينسون النجمي</p>
      <h4>قلب العطر</h4><p>نجيل الهند, خشب الأرز, خشب الصندل, الباتشولي, توت العرعر و الهيل</p>
      <h4>المكونات الأساسية</h4><p>طحلب البلوط (طحلب السنديان), الجلود, العنبر, المسك و حبوب التونكا</p>
      <div>المصمم Azzaro</div>
    </body></html>`;

  const profile = extractFragranticaArabiaProfileFromHtml(
    html,
    'https://www.fragranticarabia.com/perfumes/Azzaro/Azzaro-pour-Homme-829.html',
    'Azzaro Pour Homme',
  );

  assert.equal(profile.status, 'needsReview');
  assert.equal(profile.sourceName, 'Fragrantica Arabia');
  assert.equal(profile.extractionMethod, 'fragrantica_arabia');
  assert.equal(profile.brand, 'Azzaro');
  assert.ok(profile.accords.includes('aromatic'));
  assert.ok(profile.accords.includes('woody'));
  assert.ok(profile.accords.includes('lavender'));
  assert.ok(profile.topNotes.includes('lemon'));
  assert.ok(profile.baseNotes.includes('musk'));
  assert.ok(profile.lookupConfidence >= 0.76);
});

test('fragrantica arabia parser removes Arabic gender suffixes from display names', () => {
  const profile = extractFragranticaArabiaProfileFromHtml(
    '<h1>Bleu de Chanel Chanel للرجال</h1><div>Ш§Щ„ШҐШЄЩЃШ§Щ‚Ш§ШЄ Ш§Щ„Ш±Ш¦ЩЉШіЩЉШ© Ш®ШґШЁЩЉ Ш§Щ„Ш­Щ…Ш¶ЩЉШ§ШЄ ШЈШ±Щ€Щ…Ш§ШЄЩѓ ШЄШ§ШЁЩ„ЩЉ Щ…Щ†Ш№Шґ Ш§Щ„ШЁШ­Ш« Ш№Щ† Ш·Ш±ЩЉЩ‚ Ш§Щ„ШЈЩѓЩ€Ш±ШЇШ§ШЄ</div>',
    'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-9099.html',
    'Bleu de Chanel',
  );

  assert.equal(profile.displayName, 'Bleu de Chanel');
  assert.equal(profile.brand, 'Chanel');
});

test('fragrantica arabia lookup resolves a canonical hint by fetching and extracting the source page', async () => {
  const fetchedUrls = [];
  const result = await lookupFragranticaArabia('Dior Sauvage', async (url) => {
    fetchedUrls.push(url);
    assert.equal(url, 'https://www.fragranticarabia.com/perfumes/Dior/Sauvage-31861.html');
    return {
      ok: true,
      async text() {
        return `
          <h1>Sauvage Dior Щ„Щ„Ш±Ш¬Ш§Щ„</h1>
          <div>Ш§Щ„ШҐШЄЩЃШ§Щ‚Ш§ШЄ Ш§Щ„Ш±Ш¦ЩЉШіЩЉШ© ШЈШ±Щ€Щ…Ш§ШЄЩѓ Ш®ШґШЁЩЉ ШЄШ§ШЁЩ„ЩЉ Щ…Щ†Ш№Шґ Ш§Щ„Ш­Щ…Ш¶ЩЉШ§ШЄ Ш§Щ„ШЁШ­Ш« Ш№Щ† Ш·Ш±ЩЉЩ‚ Ш§Щ„ШЈЩѓЩ€Ш±ШЇШ§ШЄ</div>
        `;
      },
    };
  });

  assert.equal(fetchedUrls.length, 1);
  assert.equal(result.status, 'found');
  assert.equal(result.profile.brand, 'Dior');
  assert.equal(result.profile.displayName, 'Sauvage');
  assert.equal(result.profile.sourceName, 'Fragrantica Arabia');
  assert.equal(result.profile.extractionMethod, 'fragrantica_arabia');
  assert.equal(result.profile.status, 'needsReview');
  assert.ok(result.profile.accords.includes('aromatic'));
});

test('fragrantica arabia canonical hints do not fabricate a profile when extraction fails', async () => {
  const fetchedUrls = [];
  const result = await lookupFragranticaArabia('Bleu de Chanel', async (url) => {
    fetchedUrls.push(url);
    if (url.includes('/search/')) {
      return {
        ok: true,
        async text() {
          return '<html><body>No useful search candidates.</body></html>';
        },
      };
    }
    assert.equal(url, 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-9099.html');
    return {
      ok: true,
      async text() {
        return '<html><body><h1>Bleu de Chanel</h1><p>No scent data.</p></body></html>';
      },
    };
  });

  assert.equal(fetchedUrls[0], 'https://www.fragranticarabia.com/perfumes/Chanel/Bleu-de-Chanel-9099.html');
  assert.equal(result.status, 'not_found');
  assert.equal(result.reason, 'no_candidates');
});

test('fragrantica arabia search can resolve a direct strong match', async () => {
  const result = await lookupFragranticaArabia('Azzaro Pour Homme', async (url) => {
    if (url.includes('/search/')) {
      return {
        ok: true,
        async text() {
          return '<a href="/perfumes/Azzaro/Azzaro-pour-Homme-829.html">Azzaro pour Homme Azzaro</a>';
        },
      };
    }
    assert.equal(url, 'https://www.fragranticarabia.com/perfumes/Azzaro/Azzaro-pour-Homme-829.html');
    return {
      ok: true,
      async text() {
        return '<h1>Azzaro pour Homme Azzaro للرجال</h1><div>الإتفاقات الرئيسية أروماتك خشبي تابلي منعش الحمضيات البحث عن طريق الأكوردات</div>';
      },
    };
  });

  const profile = result.profile;
  assert.equal(result.status, 'found');
  assert.equal(profile.displayName.includes('Azzaro'), true);
  assert.equal(profile.extractionMethod, 'fragrantica_arabia');
  assert.ok(profile.accords.includes('aromatic'));
});

test('fragrantica arabia search returns first three ambiguous candidates', async () => {
  const candidates = await searchFragranticaArabiaCandidates('Le Male', async () => ({
    ok: true,
    async text() {
      return `
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html">Le Male Elixir Jean Paul Gaultier</a>
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-Le-Parfum-72158.html">Le Male Le Parfum Jean Paul Gaultier</a>
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-430.html">Le Male Jean Paul Gaultier</a>
        <a href="/perfumes/Jean-Paul-Gaultier/Ultra-Male-30947.html">Ultra Male Jean Paul Gaultier</a>
      `;
    },
  }));

  assert.equal(candidates.length, 3);
  assert.equal(candidates[0].displayName, 'Le Male');
  assert.equal(candidates.some((candidate) => candidate.displayName === 'Le Male Elixir'), true);
});

test('fragrantica arabia candidates use clean URL slugs instead of noisy link text', async () => {
  const candidates = await searchFragranticaArabiaCandidates('Stronger With You Intensely', async () => ({
    ok: true,
    async text() {
      return `
        <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Intensely-52802.html">
          Giorgio Armani Emporio Armani Stronger With You Intensely بقلم tagbasra كما هوه سترونك مع كلام طويل
        </a>
      `;
    },
  }));

  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].displayName, 'Emporio Armani Stronger With You Intensely');
  assert.equal(candidates[0].brand, 'Giorgio Armani');
});

test('fragrantica arabia ranking rejects one-letter substring false matches', async () => {
  const candidates = await searchFragranticaArabiaCandidates('Stronger With You Intensely', async () => ({
    ok: true,
    async text() {
      return `
        <a href="/perfumes/Yves-Saint-Laurent/Y-100.html">Y Yves Saint Laurent</a>
        <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html">Emporio Armani Stronger With You Spices Giorgio Armani</a>
      `;
    },
  }));

  assert.equal(candidates.some((candidate) => candidate.displayName === 'Y'), false);
  assert.equal(candidates.some((candidate) => candidate.displayName === 'Emporio Armani Stronger With You Spices'), false);
});

test('fragrantica arabia ranking prefers exact Stronger With You variant over sibling variants', async () => {
  const candidates = await searchFragranticaArabiaCandidates('Stronger With You Intensely', async () => ({
    ok: true,
    async text() {
      return `
        <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html">Emporio Armani Stronger With You Spices Giorgio Armani</a>
        <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Intensely-52802.html">Emporio Armani Stronger With You Intensely Giorgio Armani</a>
      `;
    },
  }));

  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].displayName, 'Emporio Armani Stronger With You Intensely');
  assert.equal(candidates[0].brand, 'Giorgio Armani');
});

test('fragrantica arabia ranking requires distinctive variant tokens, not shared family words', async () => {
  const candidates = await searchFragranticaArabiaCandidates('Le Male Elixir', async () => ({
    ok: true,
    async text() {
      return `
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-430.html">Le Male Jean Paul Gaultier</a>
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-Le-Parfum-72158.html">Le Male Le Parfum Jean Paul Gaultier</a>
        <a href="/perfumes/Jean-Paul-Gaultier/Le-Male-Elixir-81642.html">Le Male Elixir Jean Paul Gaultier</a>
      `;
    },
  }));

  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].displayName, 'Le Male Elixir');
});

test('fragrantica arabia search expands sibling result pages to find the requested variant', async () => {
  const fetchedUrls = [];
  const candidates = await searchFragranticaArabiaCandidates('Stronger With You Intensely', async (url) => {
    fetchedUrls.push(url);
    if (url.includes('/search/')) {
      return {
        ok: true,
        async text() {
          return `
            <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html">Emporio Armani Stronger With You Spices Giorgio Armani</a>
          `;
        },
      };
    }
    assert.equal(url, 'https://www.fragranticarabia.com/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Spices-122057.html');
    return {
      ok: true,
      async text() {
        return `
          <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Intensely-52802.html">Emporio Armani Stronger With You Intensely Giorgio Armani</a>
          <a href="/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Absolutely-64501.html">Emporio Armani Stronger With You Absolutely Giorgio Armani</a>
        `;
      },
    };
  });

  assert.equal(fetchedUrls.length, 2);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].displayName, 'Emporio Armani Stronger With You Intensely');
  assert.equal(candidates[0].sourceUrl, 'https://www.fragranticarabia.com/perfumes/Giorgio-Armani/Emporio-Armani-Stronger-With-You-Intensely-52802.html');
});

test('fragrantica arabia resolve rejects non-allowlisted URLs', async () => {
  const profile = await resolveFragranticaArabiaProfile('https://example.com/not-allowed.html', 'Bad', async () => {
    throw new Error('Should not fetch');
  });
  assert.equal(profile, null);
});

test('ai chat feedback validation accepts sanitized negative feedback payload', () => {
  const result = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_123',
    createdAt: '2026-06-01T10:00:00.000Z',
    environment: 'test',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'down',
      reason: 'not_similar',
    },
    trace: {
      route: 'recommendation',
      action: 'recommend',
      source: 'worker',
      toolName: 'search_products',
      toolStatus: 'success',
      workerLatencyMs: 5300,
      turnDurationMs: 6100,
      productCount: 6,
      finalProductIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
    },
    diagnostics: {
      mojibakeDetected: false,
    },
    snapshot: {
      turnCount: 1,
      turns: [
        {
          turnId: 'turn_0001',
          requestId: 'req_123',
          sessionIdHash: 'hash_123',
          route: 'recommendation',
          source: 'worker',
          finalProductIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
        },
      ],
    },
  });

  assert.equal(result.ok, true);
  assert.equal(result.payload.feedback.reason, 'not_similar');
  assert.equal(result.payload.trace.finalProductIds.length, 5);
  assert.equal(result.payload.snapshot.turns[0].finalProductIds.length, 5);
  assert.equal(result.payload.snapshot.turns[0].sessionIdHash, 'hash_123');
});

test('ai chat feedback validation rejects forbidden raw fields', () => {
  const result = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_123',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'down',
      reason: 'not_similar',
    },
    rawUserMessage: 'I need a perfume',
  });

  assert.equal(result.ok, false);
  assert.match(result.error, /Forbidden feedback field/);
});

test('ai chat feedback validation rejects unknown reason and raw session id', () => {
  const unknownReason = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_123',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'down',
      reason: 'mystery',
    },
  });
  assert.equal(unknownReason.ok, false);
  assert.match(unknownReason.error, /reason/);

  const rawSession = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_123',
    sessionId: 'raw_session',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'down',
      reason: 'not_similar',
    },
  });
  assert.equal(rawSession.ok, false);
  assert.match(rawSession.error, /sessionId/);
});

test('ai chat feedback validation redacts token-like values in allowed text fields', () => {
  const result = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_123',
    environment: 'staging token=abc12345 test@example.com',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'bad',
      reason: 'slow_response',
    },
  });

  assert.equal(result.ok, true);
  assert.match(result.payload.environment, /\[ID\]/);
  assert.match(result.payload.environment, /\[EMAIL\]/);
});

test('ai chat turn debug validation accepts sanitized turn payload', () => {
  const result = validateAIChatTurnDebugPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_turn_debug',
    createdAt: '2026-06-01T10:00:00.000Z',
    chatDebugId: 'chat_dbg_abc123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    sessionIdHash: 'hash_123',
    userMessageRedacted: 'I need something like Sauvage test@example.com',
    assistantReplyRedacted: 'Here are catalog-only alternatives.',
    route: 'external_profile_recommendation',
    source: 'worker',
    toolName: 'lookup_external_perfume_profile',
    finalProductIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
  });

  assert.equal(result.ok, true);
  assert.equal(result.payload.chatDebugId, 'chat_dbg_abc123');
  assert.match(result.payload.userMessageRedacted, /\[EMAIL\]/);
  assert.equal(result.payload.finalProductIds.length, 5);
});

test('ai chat debug identifiers are not redacted as phone numbers', () => {
  const result = validateAIChatTurnDebugPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_turn_debug',
    chatDebugId: 'chat_dbg_smoke_20260601091530',
    turnId: 'turn_0001',
    requestId: 'req_20260601091530',
    sessionIdHash: '1234567890abcdef',
    userMessageRedacted: 'call me at 01012345678',
  });

  assert.equal(result.ok, true);
  assert.equal(result.payload.chatDebugId, 'chat_dbg_smoke_20260601091530');
  assert.equal(result.payload.requestId, 'req_20260601091530');
  assert.match(result.payload.userMessageRedacted, /\[PHONE\]/);
});

test('ai chat feedback id is not redacted as a phone number', () => {
  const result = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_smoke_chat_dbg_smoke_20260601091530',
    sessionIdHash: 'hash_20260601091530',
    turnId: 'turn_0001',
    requestId: 'req_20260601091530',
    feedback: {
      rating: 'down',
      reason: 'confusing_answer',
    },
  });

  assert.equal(result.ok, true);
  assert.equal(result.payload.feedbackId, 'fb_smoke_chat_dbg_smoke_20260601091530');
  assert.equal(result.payload.requestId, 'req_20260601091530');
});

test('ai chat debug timestamps are not redacted as phone numbers', () => {
  const turn = validateAIChatTurnDebugPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_turn_debug',
    createdAt: '2026-06-01T06:17:02.8953409Z',
    chatDebugId: 'chat_dbg_smoke_20260601091702',
    turnId: 'turn_0001',
    sessionIdHash: 'hash_123',
  });
  assert.equal(turn.ok, true);
  assert.equal(turn.payload.createdAt, '2026-06-01T06:17:02.8953409Z');

  const feedback = validateAIChatFeedbackPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_negative_feedback',
    feedbackId: 'fb_20260601091702',
    createdAt: '2026-06-01T06:17:02.8953409Z',
    sessionIdHash: 'hash_123',
    turnId: 'turn_0001',
    requestId: 'req_123',
    feedback: {
      rating: 'down',
      reason: 'confusing_answer',
    },
  });
  assert.equal(feedback.ok, true);
  assert.equal(feedback.payload.createdAt, '2026-06-01T06:17:02.8953409Z');
});

test('ai chat turn debug validation rejects forbidden raw fields', () => {
  const result = validateAIChatTurnDebugPayload({
    schemaVersion: 1,
    eventType: 'ai_chat_turn_debug',
    chatDebugId: 'chat_dbg_abc123',
    turnId: 'turn_0001',
    sessionIdHash: 'hash_123',
    prompt: 'system prompt',
  });

  assert.equal(result.ok, false);
  assert.match(result.error, /Forbidden turn debug field/);
});

test('ai chat turn debug storage disabled returns stored false', async () => {
  const result = await storeAIChatTurnDebug({}, {
    chatDebugId: 'chat_dbg_abc123',
    turnId: 'turn_0001',
    sessionIdHash: 'hash_123',
    createdAt: '2026-06-01T10:00:00.000Z',
  });

  assert.equal(result.stored, false);
});
