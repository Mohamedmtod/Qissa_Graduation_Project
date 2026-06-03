import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';

void main() {
  group('AI Chat capability audit', () {
    late String audit;

    setUpAll(() {
      final auditFile = File(
        '../docs/capabilities/ai-chat-capability-audit.md',
      );
      expect(auditFile.existsSync(), isTrue);
      audit = auditFile.readAsStringSync();
    });

    test('summary counts match capability matrix statuses', () {
      final rows = _capabilityRows(audit);
      expect(rows, hasLength(102));

      final statusCounts = <String, int>{};
      for (final row in rows) {
        statusCounts.update(
          row.status,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      expect(_summaryCount(audit, 'Total capabilities'), rows.length);
      expect(_summaryCount(audit, 'Verified'), statusCounts['verified']);
      expect(_summaryCount(audit, 'Partial'), statusCounts['partial'] ?? 0);
      expect(
        _summaryCount(audit, 'Unverified'),
        statusCounts['unverified'] ?? 0,
      );
      expect(_summaryCount(audit, 'Deferred'), statusCounts['deferred'] ?? 0);
      expect(statusCounts.keys, unorderedEquals(['verified']));
    });

    test('verified capabilities have direct test or e2e evidence', () {
      final rows = _capabilityRows(audit);
      for (final row in rows.where((row) => row.status == 'verified')) {
        expect(row.evidence, isNotEmpty, reason: row.id);
        expect(
          row.evidence,
          anyOf(contains('test/'), contains('integration_test/')),
          reason: '${row.id} must cite an executable test path',
        );
      }
    });

    test('allowed tools are fully represented in the audit', () {
      const expectedAllowedTools = <String>[
        'search_products',
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
      ];

      expect(
        AIChatCompactConversationContext.defaultAllowedTools,
        expectedAllowedTools,
      );
      expect(
        _summaryCount(audit, 'Allowed tools'),
        expectedAllowedTools.length,
      );

      for (final tool in expectedAllowedTools) {
        expect(audit, contains('| `$tool` | verified |'), reason: tool);
      }
    });

    test('referenced e2e files in verified audit entries exist', () {
      final e2ePaths = <String>{
        for (final row in _capabilityRows(
          audit,
        ).where((row) => row.status == 'verified'))
          ...RegExp(
            r'mobile_app/integration_test/[A-Za-z0-9_\-]+\.dart',
          ).allMatches(row.evidence).map((match) => match.group(0)!),
      };

      expect(e2ePaths, isNotEmpty);
      for (final path in e2ePaths) {
        expect(File(path.replaceFirst('mobile_app/', '')).existsSync(), isTrue);
      }
    });
  });
}

List<_AuditRow> _capabilityRows(String audit) {
  return audit
      .split('\n')
      .where((line) => RegExp(r'^\| C\d{3} \|').hasMatch(line.trim()))
      .map(_AuditRow.parse)
      .toList(growable: false);
}

int _summaryCount(String audit, String label) {
  final match = RegExp(
    r'^\| ' + RegExp.escape(label) + r' \| (\d+) \|$',
    multiLine: true,
  ).firstMatch(audit);
  expect(match, isNotNull, reason: 'Missing count for $label');
  return int.parse(match!.group(1)!);
}

class _AuditRow {
  final String id;
  final String evidence;
  final String status;

  const _AuditRow({
    required this.id,
    required this.evidence,
    required this.status,
  });

  factory _AuditRow.parse(String line) {
    final cells = line
        .split('|')
        .skip(1)
        .take(7)
        .map((cell) => cell.trim())
        .toList(growable: false);
    expect(cells, hasLength(7), reason: line);
    return _AuditRow(id: cells[0], evidence: cells[4], status: cells[6]);
  }
}
