import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_chat_live_result_schema.dart';

Future<void> main(List<String> args) async {
  final failOnNeedsFix = args.contains('--fail-on-needs-fix');
  final device = _argValue(args, '--device') ?? 'emulator-5554';
  final scenarioId = _argValue(args, '--scenario') ?? '';
  final artifactDir = Directory('test_artifacts/ai_chat_business_info_run')
    ..createSync(recursive: true);
  final logsDir = Directory('logs')..createSync(recursive: true);
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '');

  final eventsFile = File(
    '${artifactDir.path}/ai_chat_business_info_events.jsonl',
  );
  final resultsFile = File(
    '${artifactDir.path}/ai_chat_business_info_results.json',
  );
  final summaryFile = File(
    '${artifactDir.path}/ai_chat_business_info_summary.md',
  );
  final failuresFile = File(
    '${artifactDir.path}/ai_chat_business_info_failures.md',
  );
  final rawLogsFile = File(
    '${artifactDir.path}/ai_chat_business_info_raw_logs.txt',
  );
  final legacyJsonlFile = File(
    '${logsDir.path}/ai_chat_business_info_live_$timestamp.jsonl',
  );
  final legacyConsoleFile = File(
    '${logsDir.path}/ai_chat_business_info_console_utf8_$timestamp.log',
  );

  for (final file in <File>[
    eventsFile,
    resultsFile,
    summaryFile,
    failuresFile,
    rawLogsFile,
    legacyJsonlFile,
    legacyConsoleFile,
  ]) {
    file.writeAsStringSync('', encoding: utf8, flush: true);
  }

  final events = <Map<String, Object?>>[];
  final results = <Map<String, Object?>>[];
  final matcher = RegExp(r'\[AI-100\]\s+(\{.*\})');

  Future<void> persistReports({required bool finalWrite}) async {
    final statusCounts = <String, int>{};
    final semanticCounts = <String, int>{};
    final severityCounts = <String, int>{};
    final reasonCodeCounts = <String, int>{};
    final failuresByType = <String, int>{};
    final failuresByCategory = <String, int>{};
    for (final result in results) {
      final status = result['status']?.toString() ?? 'unknown';
      statusCounts.update(status, (count) => count + 1, ifAbsent: () => 1);
      final semanticVerdict =
          result['semanticVerdict']?.toString() ?? 'unknown';
      semanticCounts.update(
        semanticVerdict,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final severity =
          result['semanticFailureSeverity']?.toString() ?? 'unknown';
      severityCounts.update(severity, (count) => count + 1, ifAbsent: () => 1);
      for (final code in stringList(result['failureReasonCodes'])) {
        reasonCodeCounts.update(code, (count) => count + 1, ifAbsent: () => 1);
      }
      if (semanticVerdict == 'needs_fix') {
        final failureType =
            result['failureTypeIfFails']?.toString() ?? 'unknown';
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

    final suiteStart = events.lastWhere(
      (event) => event['type'] == 'suite_start',
      orElse: () => <String, Object?>{},
    );
    final suiteEnd = events.lastWhere(
      (event) => event['type'] == 'suite_end',
      orElse: () => <String, Object?>{},
    );

    resultsFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'suiteName': suiteStart['suiteName'] ?? suiteEnd['suiteName'],
        'mode': suiteStart['mode'],
        'device': device,
        'scenarioCount': results.length,
        'eventCount': events.length,
        'isFinal': finalWrite,
        'counts': statusCounts,
        'runnerVerdictCounts': statusCounts,
        'semanticVerdictCounts': semanticCounts,
        'semanticFailureSeverityCounts': severityCounts,
        'failureReasonCodeCounts': reasonCodeCounts,
        'failuresByType': failuresByType,
        'failuresByCategory': failuresByCategory,
        'eventsPath': eventsFile.path,
        'rawLogsPath': rawLogsFile.path,
        'legacyJsonlPath': legacyJsonlFile.path,
        'legacyConsolePath': legacyConsoleFile.path,
        'results': results,
      }),
      encoding: utf8,
      flush: true,
    );

    final categories =
        results
            .map((result) => result['category']?.toString() ?? 'unknown')
            .toSet()
            .toList()
          ..sort();
    final summary = StringBuffer()
      ..writeln('# AI Chat Business Info Summary')
      ..writeln()
      ..writeln('- Live update: ${finalWrite ? 'complete' : 'running'}')
      ..writeln('- Device: `$device`')
      ..writeln(
        '- Suite: `${suiteStart['suiteName'] ?? suiteEnd['suiteName'] ?? 'starting'}`',
      )
      ..writeln(
        '- Mode: `${suiteStart['mode'] ?? 'business_info_live_observational'}`',
      )
      ..writeln('- Completed scenarios: ${results.length}')
      ..writeln('- Passed strongly: ${statusCounts['passed_strongly'] ?? 0}')
      ..writeln(
        '- Passed with caveat: ${statusCounts['passed_with_caveat'] ?? 0}',
      )
      ..writeln('- Needs fix: ${statusCounts['needs_fix'] ?? 0}')
      ..writeln('- Semantic strong: ${semanticCounts['strong'] ?? 0}')
      ..writeln('- Semantic weak: ${semanticCounts['weak'] ?? 0}')
      ..writeln('- Semantic needs fix: ${semanticCounts['needs_fix'] ?? 0}')
      ..writeln('- JSONL is written incrementally as UTF-8')
      ..writeln()
      ..writeln('## Output Files')
      ..writeln()
      ..writeln('- Events JSONL: `${eventsFile.path}`')
      ..writeln('- Results JSON: `${resultsFile.path}`')
      ..writeln('- Summary: `${summaryFile.path}`')
      ..writeln('- Failures: `${failuresFile.path}`')
      ..writeln('- Raw console: `${rawLogsFile.path}`')
      ..writeln('- Timestamped JSONL: `${legacyJsonlFile.path}`')
      ..writeln('- Timestamped console: `${legacyConsoleFile.path}`')
      ..writeln()
      ..writeln('## Category Breakdown')
      ..writeln()
      ..writeln('| Category | Strong | Caveat | Needs fix |')
      ..writeln('| --- | ---: | ---: | ---: |');

    for (final category in categories) {
      final categoryResults = results
          .where(
            (result) =>
                (result['category']?.toString() ?? 'unknown') == category,
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
      ..writeln('## Last Completed Scenarios')
      ..writeln();
    for (final result in results.reversed.take(10).toList().reversed) {
      summary.writeln(
        '- `${result['scenarioId']}` ${result['name']} => '
        '`runner=${result['runnerVerdict']}` '
        '`semantic=${result['semanticVerdict']}`',
      );
    }

    summaryFile.writeAsStringSync(
      summary.toString(),
      encoding: utf8,
      flush: true,
    );

    final failures = StringBuffer()
      ..writeln('# AI Chat Business Info Failures\n');
    final failedResults = results.where(hasSemanticNeedsFix);
    if (failedResults.isEmpty) {
      failures.writeln('No hard failures classified so far.');
    } else {
      for (final result in failedResults) {
        failures
          ..writeln('## ${result['scenarioId']} - ${result['name']}')
          ..writeln()
          ..writeln('- Category: ${result['category']}')
          ..writeln('- Failure type: ${result['failureTypeIfFails']}')
          ..writeln('- Runner verdict: ${result['runnerVerdict']}')
          ..writeln('- Semantic verdict: ${result['semanticVerdict']}')
          ..writeln('- Severity: ${result['semanticFailureSeverity']}')
          ..writeln(
            '- Reason codes: ${stringList(result['failureReasonCodes']).join(', ')}',
          )
          ..writeln('- Final status: ${result['finalStatus']}')
          ..writeln('- Final message type: ${result['finalMessageType']}')
          ..writeln('- Issues: ${result['issues']}')
          ..writeln('- Products: ${result['productNames']}')
          ..writeln();
      }
    }
    failuresFile.writeAsStringSync(
      failures.toString(),
      encoding: utf8,
      flush: true,
    );
  }

  Future<void> handleLine(String line) async {
    _appendUtf8Line(rawLogsFile, line);
    _appendUtf8Line(legacyConsoleFile, line);
    final match = matcher.firstMatch(line);
    if (match == null) return;
    final jsonText = match.group(1);
    if (jsonText == null) return;
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) return;
    var event = _normalizeUtf8B64Fields(Map<String, Object?>.from(decoded));
    if (event['type'] == 'scenario_result') {
      event = normalizeLiveScenarioResultSchema(
        event,
        suiteName: event['suite']?.toString(),
        mode: event['mode']?.toString() ?? 'business_info_live_observational',
      );
    }
    events.add(event);
    final encoded = jsonEncode(event);
    _appendUtf8Line(eventsFile, encoded);
    _appendUtf8Line(legacyJsonlFile, encoded);

    if (event['type'] == 'scenario_result') {
      results.add(event);
      await persistReports(finalWrite: false);
      stdout.writeln(
        '[AI-BIZ-LIVE] completed ${event['scenarioId']} => '
        'runner=${event['runnerVerdict']} semantic=${event['semanticVerdict']} '
        '(total ${results.length})',
      );
    } else if (event['type'] == 'suite_start' || event['type'] == 'suite_end') {
      await persistReports(finalWrite: event['type'] == 'suite_end');
    }
  }

  stdout.writeln('Starting AI Chat business info run...');
  stdout.writeln('Fail on needs_fix: $failOnNeedsFix');
  stdout.writeln('Events: ${eventsFile.path}');
  stdout.writeln('Summary: ${summaryFile.path}');
  stdout.writeln('Console UTF-8: ${legacyConsoleFile.path}');

  var finalExitCode = 0;

  final flutterArgs = <String>[
    'test',
    r'integration_test\ai_chat_100_ultra_scenarios_test.dart',
    '-d',
    device,
    '--dart-define=AI_CHAT_100_SCENARIO_GROUP=business_info_14',
    '--dart-define=AI_CHAT_100_FAIL_ON_NEEDS_FIX=${failOnNeedsFix ? 'true' : 'false'}',
    if (scenarioId.trim().isNotEmpty)
      '--dart-define=AI_CHAT_100_SCENARIO_ID=${scenarioId.trim()}',
  ];

  final process = await Process.start('flutter', flutterArgs, runInShell: true);

  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(handleLine);
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) async {
        _appendUtf8Line(rawLogsFile, '[stderr] $line');
        _appendUtf8Line(legacyConsoleFile, '[stderr] $line');
      });

  final exitCode = await process.exitCode;
  await stdoutDone.cancel();
  await stderrDone.cancel();
  finalExitCode = exitCode;

  await persistReports(finalWrite: true);

  if (failOnNeedsFix && results.any(hasSemanticNeedsFix)) {
    finalExitCode = 1;
  }

  stdout.writeln(
    'AI Chat business info run finished with exit code $finalExitCode.',
  );
  stdout.writeln('Summary: ${summaryFile.path}');
  stdout.writeln('Results: ${resultsFile.path}');
  stdout.writeln('Failures: ${failuresFile.path}');
  if (finalExitCode != 0) {
    exit(finalExitCode);
  }
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

int _count(List<Map<String, Object?>> results, String status) {
  return results.where((result) => result['status'] == status).length;
}

void _appendUtf8Line(File file, String line) {
  file.writeAsStringSync(
    '$line\n',
    mode: FileMode.append,
    encoding: utf8,
    flush: true,
  );
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
