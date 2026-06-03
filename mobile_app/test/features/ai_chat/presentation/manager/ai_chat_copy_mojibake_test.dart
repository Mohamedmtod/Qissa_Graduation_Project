import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-facing AI Chat copy files do not contain mojibake markers', () {
    final root = Directory('lib/features/ai_chat/presentation/manager');
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where(
              (file) => !file.path.endsWith('ai_chat_text_normalizer.dart'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final mojibake = RegExp(r'[ЩШРØÙÃÂ�]');
    final repeatedQuestionMarks = RegExp(r'\?{3,}');

    expect(files, isNotEmpty);
    for (final file in files) {
      final content = file.readAsStringSync();
      expect(
        mojibake.hasMatch(content),
        isFalse,
        reason: '${file.path} contains mojibake-like characters',
      );
      expect(
        repeatedQuestionMarks.hasMatch(content),
        isFalse,
        reason: '${file.path} contains triple-question-mark copy',
      );
    }
  });

  test('pressure v2 prompts do not contain question-mark corrupted Arabic', () {
    final file = File(
      'integration_test/ai_chat_50_pressure_v2_scenarios_test.dart',
    );
    final content = file.readAsStringSync();

    expect(
      RegExp(r'\?{3,}').hasMatch(content),
      isFalse,
      reason: '${file.path} contains question-mark corrupted scenario text',
    );
  });
}
