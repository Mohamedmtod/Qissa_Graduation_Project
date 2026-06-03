const int aiChatAuditSchemaVersion = 1;

const List<String> aiChatAuditSchemaV1RequiredFields = <String>[
  'schemaVersion',
  'scenarioId',
  'suite',
  'mode',
  'userMessages',
  'finalMessageType',
  'rawFinalMessageType',
  'finalText',
  'productIds',
  'productNames',
  'prices',
  'matchReasons',
  'intent',
  'route',
  'guardBlocks',
  'fallbackReason',
  'failureReasonCodes',
  'semanticFailureSeverity',
  'language',
  'durationMs',
  'runnerVerdict',
  'semanticVerdict',
  'authMode',
  'responseSource',
  'workerSchemaVersion',
  'replyPromptVersion',
  'replyProvider',
  'replyModelId',
  'workerFailureReason',
  'usedLocalFallback',
];

enum AiChatExpectedAction {
  recommend('recommend'),
  clarify('clarify'),
  availability('availability'),
  refuse('refuse'),
  info('info'),
  compare('compare');

  const AiChatExpectedAction(this.wireName);

  final String wireName;
}

class AiChatScenarioExpectation {
  const AiChatScenarioExpectation({
    required this.expectedAction,
    required this.allowClarifyingAsk,
    this.requiredAcks = const <String>[],
    this.forbidCards = false,
  });

  factory AiChatScenarioExpectation.infer({
    required String scenarioId,
    required String category,
    required String name,
    required String expectedBehavior,
    required List<String> mustPassChecks,
    required int minRecommendationCount,
    required bool forbidRecommendation,
  }) {
    final haystack = <String>[
      scenarioId,
      category,
      name,
      expectedBehavior,
      ...mustPassChecks,
    ].join(' ').toLowerCase();
    final requiredAcks = <String>{};

    final isAllergy =
        haystack.contains('allergy') ||
        haystack.contains('medical') ||
        haystack.contains('safety') ||
        haystack.contains('headache') ||
        haystack.contains('choking');
    if (isAllergy) requiredAcks.add('allergy');

    final availabilityCategory =
        category.toLowerCase().contains('availability') ||
        category.toLowerCase().contains('grounding');
    final asksAvailability =
        availabilityCategory ||
        haystack.contains('availability/stock only') ||
        haystack.contains('stock only') ||
        haystack.contains('not in the catalog') ||
        haystack.contains('not found') ||
        haystack.contains('catalog truth') ||
        haystack.contains('exact name was not found');
    if (asksAvailability) requiredAcks.add('availability_not_found');

    final asksComparison =
        haystack.contains('compare') ||
        haystack.contains('comparison') ||
        haystack.contains('between ');
    if (asksComparison && haystack.contains('not in catalog')) {
      requiredAcks.add('availability_not_found');
    }

    final isAdviceOnly =
        haystack.contains('advice only') ||
        haystack.contains('educational') ||
        haystack.contains('answer-only') ||
        haystack.contains('no product cards') ||
        haystack.contains('no recommendation cards');
    final asksRecommendation =
        minRecommendationCount > 0 ||
        haystack.contains('recommend') ||
        haystack.contains('suggest') ||
        haystack.contains('alternative') ||
        haystack.contains('best match') ||
        haystack.contains('show best');
    final shouldClarify =
        haystack.contains('ask for missing') ||
        haystack.contains('clarify') ||
        haystack.contains('which one do you mean');

    final AiChatExpectedAction action;
    if (asksComparison) {
      action = AiChatExpectedAction.compare;
    } else if (asksAvailability) {
      action = AiChatExpectedAction.availability;
    } else if (forbidRecommendation && !isAdviceOnly) {
      action = AiChatExpectedAction.refuse;
    } else if (shouldClarify && minRecommendationCount == 0) {
      action = AiChatExpectedAction.clarify;
    } else if (asksRecommendation) {
      action = AiChatExpectedAction.recommend;
    } else {
      action = AiChatExpectedAction.info;
    }

    return AiChatScenarioExpectation(
      expectedAction: action,
      allowClarifyingAsk: action == AiChatExpectedAction.clarify,
      requiredAcks: requiredAcks.toList()..sort(),
      forbidCards: forbidRecommendation || isAdviceOnly,
    );
  }

  final AiChatExpectedAction expectedAction;
  final bool allowClarifyingAsk;
  final List<String> requiredAcks;
  final bool forbidCards;
}

class AiChatSemanticInput {
  const AiChatSemanticInput({
    required this.scenarioId,
    required this.suite,
    required this.mode,
    required this.category,
    required this.name,
    required this.language,
    required this.userMessages,
    required this.expectedBehavior,
    required this.mustPassChecks,
    required this.runnerVerdict,
    required this.rawFinalMessageType,
    required this.finalStatus,
    required this.finalText,
    required this.productIds,
    required this.productNames,
    required this.prices,
    required this.matchReasons,
    required this.visibleTextsSample,
    required this.issues,
    required this.caveats,
    required this.durationMs,
    required this.minRecommendationCount,
    required this.forbidRecommendation,
    required this.fallbackUsed,
    required this.noMatchUsed,
    required this.availabilityStatus,
  });

  final String scenarioId;
  final String suite;
  final String mode;
  final String category;
  final String name;
  final String language;
  final List<String> userMessages;
  final String expectedBehavior;
  final List<String> mustPassChecks;
  final String runnerVerdict;
  final String rawFinalMessageType;
  final String finalStatus;
  final String finalText;
  final List<String> productIds;
  final List<String> productNames;
  final List<num> prices;
  final List<String> matchReasons;
  final List<String> visibleTextsSample;
  final List<String> issues;
  final List<String> caveats;
  final int durationMs;
  final int minRecommendationCount;
  final bool forbidRecommendation;
  final bool fallbackUsed;
  final bool noMatchUsed;
  final String? availabilityStatus;
}

class AiChatSemanticAudit {
  const AiChatSemanticAudit({
    required this.finalMessageType,
    required this.intent,
    required this.route,
    required this.failureReasonCodes,
    required this.semanticFailureSeverity,
    required this.semanticVerdict,
    required this.guardBlocks,
    required this.fallbackReason,
    required this.schemaValidationErrors,
  });

  final String finalMessageType;
  final String intent;
  final String route;
  final List<String> failureReasonCodes;
  final String semanticFailureSeverity;
  final String semanticVerdict;
  final List<String> guardBlocks;
  final String? fallbackReason;
  final List<String> schemaValidationErrors;
}

Map<String, Object?> buildAiChatAuditScenarioJson({
  required Map<String, Object?> legacyFields,
  required AiChatSemanticInput input,
}) {
  final audit = evaluateAiChatSemanticResult(input);
  final responseSource = legacyFields['responseSource'] as String? ??
      _firstString(legacyFields['responseSources']) ??
      'unknown';
  final replyPromptVersion =
      legacyFields['replyPromptVersion'] as String? ??
      legacyFields['promptVersion'] as String?;
  final replyProvider =
      legacyFields['replyProvider'] as String? ??
      legacyFields['provider'] as String?;
  final replyModelId =
      legacyFields['replyModelId'] as String? ??
      legacyFields['modelId'] as String?;
  final usedLocalFallback =
      legacyFields['usedLocalFallback'] as bool? ??
      input.fallbackUsed ||
          responseSource.contains('local_fallback') ||
          (replyPromptVersion?.contains('local_v1') ?? false) ||
          replyProvider == 'local';
  final row = <String, Object?>{
    ...legacyFields,
    'schemaVersion': aiChatAuditSchemaVersion,
    'scenarioId': input.scenarioId,
    'suite': input.suite,
    'mode': input.mode,
    'userMessages': input.userMessages,
    'rawFinalMessageType': input.rawFinalMessageType,
    'finalMessageType': audit.finalMessageType,
    'finalText': input.finalText,
    'productIds': input.productIds,
    'productNames': input.productNames,
    'prices': input.prices,
    'matchReasons': input.matchReasons,
    'intent': audit.intent,
    'route': audit.route,
    'guardBlocks': audit.guardBlocks,
    'fallbackReason': audit.fallbackReason,
    'failureReasonCodes': audit.failureReasonCodes,
    'semanticFailureSeverity': audit.semanticFailureSeverity,
    'language': input.language,
    'durationMs': input.durationMs,
    'runnerVerdict': input.runnerVerdict,
    'semanticVerdict': audit.semanticVerdict,
    'schemaValidationErrors': audit.schemaValidationErrors,
    'authMode': legacyFields['authMode'] ?? 'unknown',
    'responseSource': responseSource,
    'workerSchemaVersion':
        legacyFields['workerSchemaVersion'] ??
        _inferWorkerSchemaVersion(replyPromptVersion),
    'replyPromptVersion': replyPromptVersion,
    'replyProvider': replyProvider,
    'replyModelId': replyModelId,
    'workerFailureReason': legacyFields['workerFailureReason'],
    'usedLocalFallback': usedLocalFallback,
  };

  final schemaErrors = validateAiChatAuditSchemaV1(row);
  if (schemaErrors.isEmpty) return row;

  final failureReasonCodes = <String>{
    ..._stringList(row['failureReasonCodes']),
    'schema_validation_failed',
  }.toList()..sort();
  return <String, Object?>{
    ...row,
    'failureReasonCodes': failureReasonCodes,
    'semanticFailureSeverity': 'blocking',
    'semanticVerdict': 'needs_fix',
    'schemaValidationErrors': schemaErrors,
  };
}

AiChatSemanticAudit evaluateAiChatSemanticResult(AiChatSemanticInput input) {
  final expectation = AiChatScenarioExpectation.infer(
    scenarioId: input.scenarioId,
    category: input.category,
    name: input.name,
    expectedBehavior: input.expectedBehavior,
    mustPassChecks: input.mustPassChecks,
    minRecommendationCount: input.minRecommendationCount,
    forbidRecommendation: input.forbidRecommendation,
  );
  final normalizedFinalType = normalizeAiChatFinalMessageType(
    rawFinalMessageType: input.rawFinalMessageType,
    finalStatus: input.finalStatus,
    finalText: input.finalText,
    productIds: input.productIds,
    fallbackUsed: input.fallbackUsed,
    noMatchUsed: input.noMatchUsed,
    availabilityStatus: input.availabilityStatus,
  );
  final codes = <String>{..._codesFromRunnerIssues(input.issues)};
  final blocking = <String>{};
  final weaknesses = <String>{};

  if (input.runnerVerdict == 'needs_fix' && codes.isEmpty) {
    codes.add('runner_needs_fix');
  }

  if (normalizedFinalType == 'error' ||
      _looksLikeUnexpectedError(input.finalText)) {
    codes.add('error_response');
    blocking.add('error_response');
  }

  if (_hasDuplicateIds(input.productIds)) {
    codes.add('duplicate_cards');
    blocking.add('duplicate_cards');
  }

  if (_promotesForbiddenUpsellBudget(input)) {
    codes.add('budget_forbidden_upsell_promoted');
    blocking.add('budget_forbidden_upsell_promoted');
  }

  final hasCards = input.productIds.isNotEmpty;
  if (hasCards && expectation.forbidCards) {
    final code = expectation.expectedAction == AiChatExpectedAction.availability
        ? 'availability_routed_to_recommendation'
        : 'wrong_intent';
    codes.add(code);
    blocking.add(code);
  }

  if (_looksLikeContactLeak(input.finalText) &&
      (expectation.expectedAction == AiChatExpectedAction.availability ||
          expectation.expectedAction == AiChatExpectedAction.refuse ||
          input.expectedBehavior.toLowerCase().contains(
            'not in the catalog',
          ))) {
    codes.add('ood_contact_leak');
    blocking.add('ood_contact_leak');
  }

  final genericEvasion = looksLikeGenericEvasion(
    finalText: input.finalText,
    finalMessageType: normalizedFinalType,
    productIds: input.productIds,
  );
  if (genericEvasion && !expectation.allowClarifyingAsk) {
    codes.add('generic_evasion');
    if (_genericEvasionIsBlocking(expectation)) {
      blocking.add('generic_evasion');
    } else {
      weaknesses.add('generic_evasion');
    }
  }

  for (final ack in expectation.requiredAcks) {
    if (!_hasRequiredAck(input.finalText, input.matchReasons, ack)) {
      codes.add('missing_expected_ack');
      if (expectation.expectedAction == AiChatExpectedAction.availability ||
          expectation.expectedAction == AiChatExpectedAction.compare ||
          expectation.expectedAction == AiChatExpectedAction.refuse ||
          ack == 'allergy') {
        blocking.add('missing_expected_ack');
      } else {
        weaknesses.add('missing_expected_ack');
      }
    }
  }

  if (expectation.expectedAction == AiChatExpectedAction.compare &&
      hasCards &&
      input.expectedBehavior.toLowerCase().contains('not in catalog') &&
      !_hasRequiredAck(
        input.finalText,
        input.matchReasons,
        'availability_not_found',
      )) {
    codes.add('wrong_intent');
    blocking.add('wrong_intent');
  }

  if (_hasLanguageLeak(input.language, <String>[
    input.finalText,
    ...input.matchReasons,
  ])) {
    codes.add('language_leak');
    if (input.category.toLowerCase().contains('language') ||
        input.category.toLowerCase().contains('localization')) {
      blocking.add('language_leak');
    } else {
      weaknesses.add('language_leak');
    }
  }

  final sortedCodes = codes.toList()..sort();
  final severity = blocking.isNotEmpty
      ? 'blocking'
      : weaknesses.isNotEmpty ||
            sortedCodes.isNotEmpty ||
            input.runnerVerdict == 'passed_with_caveat'
      ? 'weakness'
      : 'none';
  final verdict = input.runnerVerdict == 'needs_fix' || blocking.isNotEmpty
      ? 'needs_fix'
      : input.runnerVerdict == 'passed_with_caveat' ||
            weaknesses.isNotEmpty ||
            sortedCodes.isNotEmpty
      ? 'weak'
      : 'strong';

  return AiChatSemanticAudit(
    finalMessageType: normalizedFinalType,
    intent: expectation.expectedAction.wireName,
    route: _routeFor(
      normalizedFinalType: normalizedFinalType,
      finalStatus: input.finalStatus,
      availabilityStatus: input.availabilityStatus,
    ),
    failureReasonCodes: sortedCodes,
    semanticFailureSeverity: severity,
    semanticVerdict: verdict,
    guardBlocks: const <String>[],
    fallbackReason: input.fallbackUsed ? 'generic_fallback_detected' : null,
    schemaValidationErrors: const <String>[],
  );
}

bool _promotesForbiddenUpsellBudget(AiChatSemanticInput input) {
  final userText = input.userMessages.join(' ').toLowerCase();
  final hasStrictLowerBudget =
      RegExp(r'\b600\b').hasMatch(userText) &&
      RegExp(r'\b900\b').hasMatch(userText) &&
      (userText.contains('do not show') ||
          userText.contains("don't show") ||
          userText.contains('dont show') ||
          userText.contains(
            '\u0645\u062a\u0637\u0644\u0639\u0647\u0627\u0634',
          ) ||
          userText.contains(
            '\u0645\u0627 \u062a\u0637\u0644\u0639\u0647\u0627\u0634',
          ));
  if (!hasStrictLowerBudget) return false;

  final outputText = <String>[
    input.finalText,
    ...input.visibleTextsSample,
  ].join(' ').toLowerCase();
  return outputText.contains('under 900') ||
      outputText.contains('within 900') ||
      outputText.contains('budget 900') ||
      outputText.contains('\u062d\u062f\u0648\u062f 900') ||
      outputText.contains(
        '\u0645\u064a\u0632\u0627\u0646\u064a\u062a\u0643 900',
      ) ||
      outputText.contains('\u0645\u064a\u0632\u0627\u0646\u064a\u0629 900');
}

String normalizeAiChatFinalMessageType({
  required String rawFinalMessageType,
  required String finalStatus,
  required String finalText,
  required List<String> productIds,
  required bool fallbackUsed,
  required bool noMatchUsed,
  required String? availabilityStatus,
}) {
  final raw = rawFinalMessageType.toLowerCase().trim();
  final status = finalStatus.toLowerCase().trim();
  if (raw == 'error' || status == 'error') return 'error';
  if (raw == 'availability' || availabilityStatus != null) {
    return 'availability';
  }
  if (noMatchUsed || status == 'nomatch' || _looksLikeNoMatch(finalText)) {
    return 'no_match';
  }
  if (productIds.isNotEmpty || status == 'recommend') return 'recommendation';
  if (_looksLikeRefusal(finalText)) return 'refusal';
  if (looksLikeGenericEvasion(
    finalText: finalText,
    finalMessageType: raw,
    productIds: productIds,
  )) {
    return 'ask';
  }
  if (fallbackUsed) return 'ask';
  return 'info';
}

bool looksLikeGenericEvasion({
  required String finalText,
  required String finalMessageType,
  required List<String> productIds,
}) {
  if (productIds.isNotEmpty) return false;
  final text = finalText.toLowerCase();
  final type = finalMessageType.toLowerCase();
  if (type == 'ask' || type == 'clarification') return true;
  const phrases = <String>[
    'could you share one more preference',
    'share one more preference',
    'tell me one more preference',
    'which notes do you prefer',
    'any notes you prefer',
    'what notes do you like',
    'men, women, or unisex',
    "men's, women's, or unisex",
    'men or women',
    'male or female',
    'budget, gender',
    'do you prefer a men',
    'could not understand your preferences clearly',
    'i need a bit more detail',
  ];
  if (phrases.any(text.contains)) return true;
  return _looksQuestionLike(text) &&
      (text.contains('prefer') ||
          text.contains('budget') ||
          text.contains('gender') ||
          text.contains('notes') ||
          text.contains('occasion') ||
          text.contains('intensity') ||
          text.contains('projection'));
}

List<String> validateAiChatAuditSchemaV1(Map<String, Object?> row) {
  final errors = <String>[];
  for (final field in aiChatAuditSchemaV1RequiredFields) {
    if (!row.containsKey(field)) errors.add('missing_$field');
  }
  if (row['schemaVersion'] != aiChatAuditSchemaVersion) {
    errors.add('invalid_schemaVersion');
  }
  final semanticVerdict = row['semanticVerdict']?.toString();
  final failureReasonCodes = row['failureReasonCodes'];
  if (semanticVerdict == 'needs_fix' &&
      (failureReasonCodes is! List || failureReasonCodes.isEmpty)) {
    errors.add('needs_fix_without_failureReasonCodes');
  }
  return errors;
}

Set<String> _codesFromRunnerIssues(List<String> issues) {
  final codes = <String>{};
  for (final issue in issues) {
    final lower = issue.toLowerCase();
    if (lower.contains('budget violation')) codes.add('budget_violation');
    if (lower.contains('duplicate')) codes.add('duplicate_cards');
    if (lower.contains('expected at least') ||
        lower.contains('below minimum')) {
      codes.add('missing_expected_recommendation');
    }
    if (lower.contains('error')) codes.add('error_response');
    if (lower.contains('forbidden fragment')) codes.add('forbidden_fragment');
    if (lower.contains('exception')) codes.add('runner_exception');
    if (lower.contains('chat input missing')) codes.add('ui_state_failure');
  }
  return codes;
}

bool _hasDuplicateIds(List<String> productIds) {
  final seen = <String>{};
  for (final id in productIds.where((id) => id.trim().isNotEmpty)) {
    if (!seen.add(id.trim())) return true;
  }
  return false;
}

bool _genericEvasionIsBlocking(AiChatScenarioExpectation expectation) {
  return expectation.requiredAcks.isNotEmpty ||
      expectation.expectedAction == AiChatExpectedAction.recommend ||
      expectation.expectedAction == AiChatExpectedAction.availability ||
      expectation.expectedAction == AiChatExpectedAction.compare ||
      expectation.expectedAction == AiChatExpectedAction.refuse;
}

bool _hasRequiredAck(String finalText, List<String> matchReasons, String ack) {
  final text = <String>[finalText, ...matchReasons].join('\n').toLowerCase();
  switch (ack) {
    case 'allergy':
      return text.contains('allergy') ||
          text.contains('allergic') ||
          text.contains('sensitive') ||
          text.contains('medical') ||
          text.contains('safety') ||
          text.contains('avoid') ||
          text.contains('headache') ||
          text.contains('choking') ||
          text.contains('\u062d\u0633\u0627\u0633') ||
          text.contains('\u062a\u062c\u0646\u0628') ||
          text.contains('\u0623\u0645\u0627\u0646') ||
          text.contains('\u0633\u0644\u0627\u0645');
    case 'availability_not_found':
      return text.contains('not in the catalog') ||
          text.contains('not found') ||
          text.contains('not available') ||
          text.contains("don't have") ||
          text.contains('do not have') ||
          text.contains('catalog') ||
          text.contains('\u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c') ||
          text.contains('\u063a\u064a\u0631 \u0645\u062a\u0627\u062d') ||
          text.contains('\u0645\u0634 \u0645\u062a\u0627\u062d') ||
          text.contains('\u0645\u0634 \u0645\u0648\u062c\u0648\u062f') ||
          text.contains('\u0644\u064a\u0633 \u0645\u0648\u062c\u0648\u062f');
    default:
      return false;
  }
}

bool _hasLanguageLeak(String language, List<String> texts) {
  final normalizedLanguage = language.toLowerCase();
  if (normalizedLanguage == 'mixed' || normalizedLanguage == 'franco') {
    return false;
  }
  final joined = texts.join('\n');
  if (normalizedLanguage == 'en') {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(joined) ||
        RegExp(r'[ШЩР]').hasMatch(joined);
  }
  if (normalizedLanguage == 'ar') {
    final text = joined.toLowerCase();
    return text.contains('could you share one more preference') ||
        text.contains('men, women, or unisex') ||
        text.contains('could not understand your preferences clearly');
  }
  return false;
}

bool _looksLikeContactLeak(String text) {
  final lower = text.toLowerCase();
  return lower.contains('whatsapp') ||
      lower.contains('phone:') ||
      lower.contains('contact') ||
      RegExp(r'\b01\d{8,}\b').hasMatch(lower);
}

bool _looksLikeUnexpectedError(String text) {
  final lower = text.toLowerCase();
  return lower.contains('something went wrong') ||
      lower.contains('try again later') ||
      lower.contains('error occurred') ||
      lower.contains('failed to') ||
      lower.contains('exception');
}

bool _looksLikeNoMatch(String text) {
  final lower = text.toLowerCase();
  return lower.contains('no matching') ||
      lower.contains('no exact match') ||
      lower.contains('not in the catalog') ||
      lower.contains('not found');
}

bool _looksLikeRefusal(String text) {
  final lower = text.toLowerCase();
  return lower.contains("can't help with that") ||
      lower.contains('cannot help with that') ||
      lower.contains('only help with perfumes') ||
      lower.contains('perfume-only') ||
      lower.contains('outside perfume');
}

bool _looksQuestionLike(String text) {
  return text.contains('?') || text.contains('\u061f');
}

String _routeFor({
  required String normalizedFinalType,
  required String finalStatus,
  required String? availabilityStatus,
}) {
  if (availabilityStatus != null) return availabilityStatus;
  if (finalStatus.trim().isNotEmpty) return finalStatus;
  return normalizedFinalType;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList();
}

String? _firstString(Object? value) {
  final list = _stringList(value);
  if (list.isEmpty) return null;
  final first = list.first.trim();
  return first.isEmpty ? null : first;
}

int? _inferWorkerSchemaVersion(String? promptVersion) {
  final normalized = promptVersion?.trim().toLowerCase() ?? '';
  if (normalized == 'chat_v2_structured_commands') return 2;
  if (normalized.isEmpty || normalized.contains('local')) return null;
  return 1;
}
