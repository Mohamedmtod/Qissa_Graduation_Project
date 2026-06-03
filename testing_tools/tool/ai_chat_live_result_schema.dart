const int aiChatLiveSchemaVersion = 1;

const List<String> aiChatLiveRequiredFields = <String>[
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
];

Map<String, Object?> normalizeLiveScenarioResultSchema(
  Map<String, Object?> result, {
  String? suiteName,
  String? mode,
}) {
  final normalized = Map<String, Object?>.from(result);
  final missingBefore = aiChatLiveRequiredFields
      .where((field) => !normalized.containsKey(field))
      .toList();

  final runnerVerdict = _normalizeRunnerVerdict(
    normalized['runnerVerdict'] ?? normalized['status'],
  );
  normalized['runnerVerdict'] = runnerVerdict;
  normalized['status'] = runnerVerdict;
  normalized['schemaVersion'] ??= aiChatLiveSchemaVersion;
  normalized['suite'] ??= suiteName ?? normalized['suiteName'] ?? 'unknown';
  normalized['mode'] ??= mode ?? 'unknown';
  normalized['userMessages'] ??=
      normalized['messages'] ??
      normalized['scenarioMessages'] ??
      const <String>[];
  normalized['rawFinalMessageType'] ??=
      normalized['rawFinalMessageType'] ??
      normalized['finalMessageType'] ??
      'missing';
  normalized['finalMessageType'] ??= normalized['rawFinalMessageType'];
  normalized['finalText'] ??=
      normalized['finalText'] ?? normalized['finalMessageText'] ?? '';
  normalized['productIds'] ??= _fieldList(normalized, 'productId');
  normalized['productNames'] ??= _fieldList(normalized, 'name');
  normalized['prices'] ??= _fieldList(normalized, 'price');
  normalized['matchReasons'] ??= _fieldList(normalized, 'matchReason');
  normalized['intent'] ??= normalized['category'] ?? 'unknown';
  normalized['route'] ??=
      normalized['availabilityStatus'] ??
      normalized['finalStatus'] ??
      normalized['finalMessageType'] ??
      'unknown';
  normalized['guardBlocks'] ??= const <String>[];
  normalized['fallbackReason'] ??= normalized['fallbackUsed'] == true
      ? 'generic_fallback_detected'
      : null;
  normalized['failureReasonCodes'] ??= const <String>[];
  normalized['semanticFailureSeverity'] ??= _severityFromVerdict(
    normalized['semanticVerdict'] ?? runnerVerdict,
  );
  normalized['language'] ??= normalized['language'] ?? 'unknown';
  normalized['durationMs'] ??= 0;
  normalized['semanticVerdict'] ??= _semanticFromRunner(runnerVerdict);

  final codes = <String>{...stringList(normalized['failureReasonCodes'])};
  if (missingBefore.isNotEmpty ||
      normalized['schemaVersion'] != aiChatLiveSchemaVersion) {
    codes.add('schema_validation_failed');
    normalized['semanticVerdict'] = 'needs_fix';
    normalized['semanticFailureSeverity'] = 'blocking';
    normalized['schemaValidationErrors'] = <String>[
      for (final field in missingBefore) 'missing_$field',
      if (normalized['schemaVersion'] != aiChatLiveSchemaVersion)
        'invalid_schemaVersion',
    ];
  }
  if (normalized['semanticVerdict'] == 'needs_fix' && codes.isEmpty) {
    codes.add('schema_validation_failed');
    normalized['semanticFailureSeverity'] = 'blocking';
  }
  normalized['failureReasonCodes'] = codes.toList()..sort();
  return normalized;
}

Map<String, int> countByStringField(
  Iterable<Map<String, Object?>> results,
  String field, {
  String fallbackField = 'status',
}) {
  final counts = <String, int>{};
  for (final result in results) {
    final value =
        result[field]?.toString() ??
        result[fallbackField]?.toString() ??
        'unknown';
    counts.update(value, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

Map<String, int> countFailureReasonCodes(
  Iterable<Map<String, Object?>> results,
) {
  final counts = <String, int>{};
  for (final result in results) {
    for (final code in stringList(result['failureReasonCodes'])) {
      counts.update(code, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

bool hasSemanticNeedsFix(Map<String, Object?> result) {
  return result['semanticVerdict'] == 'needs_fix';
}

List<String> stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList();
}

String _normalizeRunnerVerdict(Object? value) {
  final raw = value?.toString() ?? 'unknown';
  switch (raw) {
    case 'passed':
      return 'passed_strongly';
    case 'failed':
      return 'needs_fix';
    default:
      return raw;
  }
}

String _semanticFromRunner(String runnerVerdict) {
  switch (runnerVerdict) {
    case 'needs_fix':
      return 'needs_fix';
    case 'passed_with_caveat':
      return 'weak';
    default:
      return 'strong';
  }
}

String _severityFromVerdict(Object? verdict) {
  if (verdict == 'needs_fix') return 'blocking';
  if (verdict == 'weak') return 'weakness';
  return 'none';
}

List<Object?> _fieldList(Map<String, Object?> result, String key) {
  final cards = result['recommendationCards'];
  if (cards is! List) return const <Object?>[];
  return cards
      .map((card) {
        if (card is Map<String, Object?>) return card[key];
        if (card is Map) return card[key];
        return null;
      })
      .where((value) => value != null)
      .toList();
}
