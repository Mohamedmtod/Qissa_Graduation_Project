import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath = args.isNotEmpty
      ? args.first
      : 'test_artifacts/ai_chat_100_run/ai_chat_100_events.jsonl';
  final outputPath = args.length > 1
      ? args[1]
      : 'test_artifacts/ai_chat_100_run/ai_chat_100_events_decoded.jsonl';
  final resultsPath = args.length > 2
      ? args[2]
      : 'test_artifacts/ai_chat_100_run/ai_chat_100_results_decoded.json';

  final input = File(inputPath);
  if (!input.existsSync()) {
    stderr.writeln('Input JSONL not found: $inputPath');
    exitCode = 66;
    return;
  }

  final events = <Map<String, Object?>>[];
  for (final line in input.readAsLinesSync(encoding: utf8)) {
    if (line.trim().isEmpty) continue;
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        events.add(_normalizeUtf8B64Fields(Map<String, Object?>.from(decoded)));
      }
    } on FormatException {
      stderr.writeln('Skipping invalid or partially-written JSONL row.');
    }
  }

  final output = File(outputPath)..parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${events.map(jsonEncode).join('\n')}\n',
    encoding: utf8,
    flush: true,
  );

  final results = events
      .where((event) => event['type'] == 'scenario_result')
      .toList();
  File(resultsPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'sourceEventsPath': inputPath,
      'decodedEventsPath': outputPath,
      'scenarioCount': results.length,
      'eventCount': events.length,
      'results': results,
    }),
    encoding: utf8,
    flush: true,
  );

  stdout.writeln('Decoded events: $outputPath');
  stdout.writeln('Decoded results: $resultsPath');
  stdout.writeln('Scenarios decoded: ${results.length}');
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
