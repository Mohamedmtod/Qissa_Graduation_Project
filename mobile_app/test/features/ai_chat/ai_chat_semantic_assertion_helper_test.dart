import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/ai_chat_semantic_assertion_helper.dart';

void main() {
  group('AI chat semantic assertion helper', () {
    test('downgrades generic evasion when recommendation is expected', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          expectedBehavior: 'Recommend the best match.',
          minRecommendationCount: 1,
          finalText: 'Could you share one more preference?',
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(audit.semanticFailureSeverity, 'blocking');
      expect(audit.failureReasonCodes, contains('generic_evasion'));
    });

    test('allows clarifying ask for vague clarify scenarios', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          expectedBehavior: 'Ask for missing budget, gender, or occasion.',
          mustPassChecks: const <String>['clarify missing preference'],
          finalText: 'Could you share one more preference?',
        ),
      );

      expect(audit.semanticVerdict, 'strong');
      expect(audit.failureReasonCodes, isEmpty);
    });

    test('detects duplicate product cards as blocking', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          productIds: const <String>['p1', 'p2', 'p1'],
          productNames: const <String>['One', 'Two', 'One'],
          prices: const <num>[10, 20, 10],
          finalText: 'Here are the best matches.',
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(audit.semanticFailureSeverity, 'blocking');
      expect(audit.failureReasonCodes, contains('duplicate_cards'));
    });

    test('detects forbidden upsell amount promoted as strict budget', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          scenarioId: 'P50V2-013',
          userMessages: const <String>[
            '\u0645\u064a\u0632\u0627\u0646\u064a\u062a\u064a 600\u060c \u0648\u0644\u0648 \u0641\u064a \u062d\u0627\u062c\u0629 \u0623\u062d\u0633\u0646 \u0628\u0640900 \u0645\u062a\u0637\u0644\u0639\u0647\u0627\u0634',
          ],
          finalText:
              '\u062a\u0645\u0627\u0645\u060c \u0641\u0647\u0645\u062a \u0625\u0646\u0643 \u0639\u0627\u064a\u0632 \u0641\u064a \u062d\u062f\u0648\u062f 900 \u062c\u0646\u064a\u0647.',
          visibleTextsSample: const <String>['Under 900'],
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(
        audit.failureReasonCodes,
        contains('budget_forbidden_upsell_promoted'),
      );
    });

    test('detects OOD contact leakage', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          category: 'Availability & Grounding',
          expectedBehavior:
              'Say the product is not in the catalog and do not invent cards.',
          forbidRecommendation: true,
          finalText: 'Phone: 01068430400\nWhatsApp: 01068430400',
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(audit.failureReasonCodes, contains('ood_contact_leak'));
    });

    test(
      'accepts Arabic catalog-only OOD redirect as grounded acknowledgement',
      () {
        final audit = evaluateAiChatSemanticResult(
          _input(
            category: 'Availability & Grounding',
            expectedBehavior:
                'Say the product is not in the catalog and do not invent cards.',
            forbidRecommendation: true,
            finalStatus: 'answer_or_ask',
            finalText:
                'أنا أقدر أساعدك في العطور المتاحة في الكتالوج فقط. لو تحب، ابعتلي نوع العطر أو الميزانية أو المناسبة وهارشح لك اختيار مناسب.',
          ),
        );

        expect(audit.semanticVerdict, isNot('needs_fix'));
        expect(
          audit.failureReasonCodes,
          isNot(contains('missing_expected_ack')),
        );
      },
    );

    test('detects availability routed to recommendation cards', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          category: 'Availability & Grounding',
          expectedBehavior:
              'Answer availability/stock only and do not recommend alternatives unless explicitly needed.',
          forbidRecommendation: true,
          finalStatus: 'recommend',
          finalText: 'Here are alternatives.',
          productIds: const <String>['p1', 'p2'],
          productNames: const <String>['One', 'Two'],
          prices: const <num>[10, 20],
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(
        audit.failureReasonCodes,
        contains('availability_routed_to_recommendation'),
      );
    });

    test('detects comparison with missing imaginary-product acknowledgement', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          category: 'Comparison & Grounding',
          expectedBehavior:
              'Compare only grounded products and state Toyota Black Edition is not in catalog.',
          finalStatus: 'recommend',
          finalText: 'Sauvage is stronger, Toyota Black Edition is sweeter.',
          productIds: const <String>['sauvage'],
          productNames: const <String>['Sauvage'],
          prices: const <num>[4650],
        ),
      );

      expect(audit.semanticVerdict, 'needs_fix');
      expect(audit.failureReasonCodes, contains('wrong_intent'));
    });

    test('detects English language leak in match reasons', () {
      final audit = evaluateAiChatSemanticResult(
        _input(
          language: 'en',
          finalText: 'Here is the best option.',
          productIds: const <String>['p1'],
          productNames: const <String>['One'],
          prices: const <num>[10],
          matchReasons: const <String>['\u064a\u0646\u0627\u0633\u0628 budget'],
        ),
      );

      expect(audit.semanticVerdict, 'weak');
      expect(audit.semanticFailureSeverity, 'weakness');
      expect(audit.failureReasonCodes, contains('language_leak'));
    });

    test('schema validator fails loudly for missing fields', () {
      final errors = validateAiChatAuditSchemaV1(<String, Object?>{
        'schemaVersion': aiChatAuditSchemaVersion,
        'scenarioId': 'S1',
        'semanticVerdict': 'needs_fix',
        'failureReasonCodes': const <String>[],
      });

      expect(errors, contains('missing_suite'));
      expect(errors, contains('needs_fix_without_failureReasonCodes'));
    });

    test('schema builder preserves status as runner verdict', () {
      final input = _input(
        runnerVerdict: 'passed_strongly',
        finalText: 'Could you share one more preference?',
        expectedBehavior: 'Recommend the best match.',
        minRecommendationCount: 1,
      );
      final row = buildAiChatAuditScenarioJson(
        legacyFields: const <String, Object?>{
          'status': 'passed_strongly',
          'issues': <String>[],
          'caveats': <String>[],
        },
        input: input,
      );

      expect(row['status'], 'passed_strongly');
      expect(row['runnerVerdict'], 'passed_strongly');
      expect(row['semanticVerdict'], 'needs_fix');
      expect(row['failureReasonCodes'], contains('generic_evasion'));
    });
  });
}

AiChatSemanticInput _input({
  String scenarioId = 'S1',
  String suite = 'suite',
  String mode = 'worker_first',
  String category = 'recommendation',
  String name = 'scenario',
  String language = 'en',
  List<String> userMessages = const <String>['Recommend perfume.'],
  String expectedBehavior = 'Recommend the best match.',
  List<String> mustPassChecks = const <String>['recommendation cards'],
  String runnerVerdict = 'passed_strongly',
  String rawFinalMessageType = 'text',
  String finalStatus = 'answer_or_ask',
  String finalText = 'Here is the best match.',
  List<String> productIds = const <String>[],
  List<String> productNames = const <String>[],
  List<num> prices = const <num>[],
  List<String> matchReasons = const <String>[],
  List<String> visibleTextsSample = const <String>[],
  List<String> issues = const <String>[],
  List<String> caveats = const <String>[],
  int durationMs = 100,
  int minRecommendationCount = 0,
  bool forbidRecommendation = false,
  bool fallbackUsed = false,
  bool noMatchUsed = false,
  String? availabilityStatus,
}) {
  return AiChatSemanticInput(
    scenarioId: scenarioId,
    suite: suite,
    mode: mode,
    category: category,
    name: name,
    language: language,
    userMessages: userMessages,
    expectedBehavior: expectedBehavior,
    mustPassChecks: mustPassChecks,
    runnerVerdict: runnerVerdict,
    rawFinalMessageType: rawFinalMessageType,
    finalStatus: finalStatus,
    finalText: finalText,
    productIds: productIds,
    productNames: productNames,
    prices: prices,
    matchReasons: matchReasons,
    visibleTextsSample: visibleTextsSample,
    issues: issues,
    caveats: caveats,
    durationMs: durationMs,
    minRecommendationCount: minRecommendationCount,
    forbidRecommendation: forbidRecommendation,
    fallbackUsed: fallbackUsed,
    noMatchUsed: noMatchUsed,
    availabilityStatus: availabilityStatus,
  );
}
