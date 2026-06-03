import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/ai_chat_100_console_report.dart <console-log-path>',
    );
    exitCode = 64;
    return;
  }

  final input = File(args.first);
  if (!input.existsSync()) {
    stderr.writeln('Console log not found: ${input.path}');
    exitCode = 66;
    return;
  }

  final events = <Map<String, Object?>>[];
  final matcher = RegExp(r'\[AI-100\]\s+(\{.*\})');
  final consoleText = _decodeConsoleLog(input.readAsBytesSync());
  for (final line in const LineSplitter().convert(consoleText)) {
    final match = matcher.firstMatch(line);
    if (match == null) continue;
    final jsonText = match.group(1);
    if (jsonText == null) continue;
    final decoded = jsonDecode(jsonText);
    if (decoded is Map<String, dynamic>) {
      events.add(_normalizeUtf8B64Fields(Map<String, Object?>.from(decoded)));
    }
  }

  if (events.isEmpty) {
    stderr.writeln('No [AI-100] JSON events found in ${input.path}');
    exitCode = 65;
    return;
  }

  final artifactDir = Directory('test_artifacts/ai_chat_100_run')
    ..createSync(recursive: true);
  final logsDir = Directory('logs')..createSync(recursive: true);
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '');

  final eventsFile = File('${artifactDir.path}/ai_chat_100_events.jsonl');
  final resultsFile = File('${artifactDir.path}/ai_chat_100_results.json');
  final summaryFile = File('${artifactDir.path}/ai_chat_100_summary.md');
  final failuresFile = File('${artifactDir.path}/ai_chat_100_failures.md');
  final rawLogsFile = File('${artifactDir.path}/ai_chat_100_raw_logs.txt');
  final legacyJsonlFile = File(
    '${logsDir.path}/ai_chat_100_ultra_$timestamp.jsonl',
  );

  final jsonl = events.map(jsonEncode).join('\n');
  eventsFile.writeAsStringSync('$jsonl\n', flush: true);
  legacyJsonlFile.writeAsStringSync('$jsonl\n', flush: true);
  rawLogsFile.writeAsStringSync(consoleText, flush: true);

  for (final line in eventsFile.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      stderr.writeln('Invalid JSONL row: $line');
      exitCode = 65;
      return;
    }
  }

  final suiteStart = events.lastWhere(
    (event) => event['type'] == 'suite_start',
    orElse: () => <String, Object?>{},
  );
  final suiteEnd = events.lastWhere(
    (event) => event['type'] == 'suite_end',
    orElse: () => <String, Object?>{},
  );
  final results = events
      .where((event) => event['type'] == 'scenario_result')
      .map((event) => Map<String, Object?>.from(event))
      .toList();

  final statusCounts = <String, int>{};
  final failuresByType = <String, int>{};
  final failuresByCategory = <String, int>{};
  for (final result in results) {
    final status = result['status']?.toString() ?? 'unknown';
    statusCounts.update(status, (count) => count + 1, ifAbsent: () => 1);
    if (status == 'needs_fix') {
      final failureType = result['failureTypeIfFails']?.toString() ?? 'unknown';
      final category = result['category']?.toString() ?? 'unknown';
      failuresByType.update(
        failureType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      failuresByCategory.update(
        category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final payload = <String, Object?>{
    'suiteName': suiteStart['suiteName'] ?? suiteEnd['suiteName'],
    'mode': suiteStart['mode'],
    'scenarioCount': results.length,
    'eventCount': events.length,
    'counts': statusCounts,
    'failuresByType': failuresByType,
    'failuresByCategory': failuresByCategory,
    'suiteStart': suiteStart,
    'suiteEnd': suiteEnd,
    'results': results,
    'sourceConsoleLog': input.path,
    'legacyJsonlPath': legacyJsonlFile.path,
  };
  resultsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
    flush: true,
  );

  final categories =
      results
          .map((result) => result['category']?.toString() ?? 'unknown')
          .toSet()
          .toList()
        ..sort();

  final summary = StringBuffer()
    ..writeln('# AI Chat 100 Evaluation Summary')
    ..writeln()
    ..writeln('- Source console log: `${input.path}`')
    ..writeln(
      '- Suite: `${suiteStart['suiteName'] ?? suiteEnd['suiteName'] ?? 'unknown'}`',
    )
    ..writeln('- Mode: `${suiteStart['mode'] ?? 'unknown'}`')
    ..writeln('- Total scenarios: ${results.length}')
    ..writeln('- Passed strongly: ${statusCounts['passed_strongly'] ?? 0}')
    ..writeln(
      '- Passed with caveat: ${statusCounts['passed_with_caveat'] ?? 0}',
    )
    ..writeln('- Needs fix: ${statusCounts['needs_fix'] ?? 0}')
    ..writeln('- JSONL valid: yes')
    ..writeln()
    ..writeln('## Category Breakdown')
    ..writeln()
    ..writeln('| Category | Strong | Caveat | Needs fix |')
    ..writeln('| --- | ---: | ---: | ---: |');

  for (final category in categories) {
    final categoryResults = results
        .where(
          (result) => (result['category']?.toString() ?? 'unknown') == category,
        )
        .toList();
    summary.writeln(
      '| $category | ${_count(categoryResults, 'passed_strongly')} | '
      '${_count(categoryResults, 'passed_with_caveat')} | '
      '${_count(categoryResults, 'needs_fix')} |',
    );
  }

  summary
    ..writeln()
    ..writeln('## Demo Safe')
    ..writeln();
  for (final result in results.where(
    (result) =>
        result['demoRelevance'] == 'high' && result['status'] != 'needs_fix',
  )) {
    summary.writeln('- `${result['scenarioId']}` ${result['name']}');
  }

  summary
    ..writeln()
    ..writeln('## Demo Risky')
    ..writeln();
  for (final result in results.where(
    (result) => result['status'] == 'needs_fix',
  )) {
    final issues = result['issues'];
    summary.writeln('- `${result['scenarioId']}` ${result['name']}: $issues');
  }
  summaryFile.writeAsStringSync(summary.toString(), flush: true);

  final failures = StringBuffer()..writeln('# AI Chat 100 Failures\n');
  final failedResults = results.where(
    (result) => result['status'] == 'needs_fix',
  );
  if (failedResults.isEmpty) {
    failures.writeln('No hard failures classified.');
  } else {
    for (final result in failedResults) {
      failures
        ..writeln('## ${result['scenarioId']} - ${result['name']}')
        ..writeln()
        ..writeln('- Category: ${result['category']}')
        ..writeln('- Failure type: ${result['failureTypeIfFails']}')
        ..writeln('- Final status: ${result['finalStatus']}')
        ..writeln('- Final message type: ${result['finalMessageType']}')
        ..writeln('- Issues: ${result['issues']}')
        ..writeln('- Products: ${result['productNames']}')
        ..writeln();
    }
  }
  failuresFile.writeAsStringSync(failures.toString(), flush: true);

  stdout.writeln(
    jsonEncode(<String, Object?>{
      'events': events.length,
      'scenarios': results.length,
      'passed_strongly': statusCounts['passed_strongly'] ?? 0,
      'passed_with_caveat': statusCounts['passed_with_caveat'] ?? 0,
      'needs_fix': statusCounts['needs_fix'] ?? 0,
      'eventsPath': eventsFile.path,
      'resultsPath': resultsFile.path,
      'summaryPath': summaryFile.path,
      'failuresPath': failuresFile.path,
      'rawLogsPath': rawLogsFile.path,
      'legacyJsonlPath': legacyJsonlFile.path,
    }),
  );
}

int _count(List<Map<String, Object?>> results, String status) {
  return results.where((result) => result['status'] == status).length;
}

Map<String, Object?> _normalizeUtf8B64Fields(Map<String, Object?> event) {
  final normalized = Map<String, Object?>.from(event);

  void replaceString(String encodedKey, String decodedKey) {
    final decoded = _decodeUtf8B64(normalized[encodedKey]);
    if (decoded != null) normalized[decodedKey] = decoded;
  }

  void replaceList(String encodedKey, String decodedKey) {
    final value = normalized[encodedKey];
    if (value is! List) return;
    final decoded = <String>[];
    for (final item in value) {
      final decodedItem = _decodeUtf8B64(item);
      if (decodedItem != null) decoded.add(decodedItem);
    }
    if (decoded.length == value.length) normalized[decodedKey] = decoded;
  }

  replaceString('textUtf8B64', 'text');
  replaceString('finalMessageTextUtf8B64', 'finalMessageText');
  replaceString('matchLabelUtf8B64', 'matchLabel');
  replaceString('matchReasonUtf8B64', 'matchReason');
  replaceList('messagesUtf8B64', 'messages');
  replaceList('visibleTextsSampleUtf8B64', 'visibleTextsSample');
  replaceList('matchLabelsUtf8B64', 'matchLabels');
  replaceList('matchReasonsUtf8B64', 'matchReasons');

  final cards = normalized['recommendationCards'];
  if (cards is List) {
    normalized['recommendationCards'] = cards.map((card) {
      if (card is Map<String, Object?>) return _normalizeUtf8B64Fields(card);
      if (card is Map) {
        return _normalizeUtf8B64Fields(Map<String, Object?>.from(card));
      }
      return card;
    }).toList();
  }

  return normalized;
}

String? _decodeUtf8B64(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return utf8.decode(base64Decode(value));
  } on FormatException {
    return null;
  }
}

String _decodeConsoleLog(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16Le(bytes.skip(2).toList());
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16Be(bytes.skip(2).toList());
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

String _decodeUtf16Le(List<int> bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

String _decodeUtf16Be(List<int> bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add((bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}
