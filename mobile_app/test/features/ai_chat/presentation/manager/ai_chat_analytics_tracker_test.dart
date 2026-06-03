import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_debug_session_builder.dart';

void main() {
  final originalDebugPrint = debugPrint;

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  group('AIChatAnalyticsEvent', () {
    test('serializes safe metadata without raw identifiers or prompts', () {
      final event = AIChatAnalyticsEvent(
        eventType: 'tool_executed',
        requestId: 'request-1',
        sessionId: 'session-raw-1',
        language: AIChatLanguage.english,
        messageLength: 42,
        toolName: 'search_products',
        toolStatus: 'success',
        finalProductIds: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
        productCount: 6,
      );

      final json = event.toJson();

      expect(json['sessionIdHash'], isNot('session-raw-1'));
      expect(json['finalProductIds'], const ['p1', 'p2', 'p3', 'p4', 'p5']);
      expect(json['productCount'], 6);
      expect(json.containsKey('rawUserMessage'), isFalse);
      expect(json.containsKey('fullPrompt'), isFalse);
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('sessionId'), isFalse);
    });

    test('serializes optional turn id without raw session data', () {
      final event = AIChatAnalyticsEvent(
        eventType: 'turn_completed',
        requestId: 'request-1',
        turnId: 'turn-1',
        sessionId: 'session-raw-1',
        language: AIChatLanguage.english,
        messageLength: 42,
      );

      final json = event.toJson();

      expect(json['turnId'], 'turn-1');
      expect(json['requestId'], 'request-1');
      expect(json['sessionIdHash'], isNot('session-raw-1'));
      expect(json.containsKey('sessionId'), isFalse);
      expect(json.containsKey('rawUserMessage'), isFalse);
    });

    test('normalizes unknown tool status to validation_failed', () {
      final event = AIChatAnalyticsEvent(
        eventType: 'tool_executed',
        requestId: 'request-1',
        sessionId: 'session-raw-1',
        language: AIChatLanguage.english,
        messageLength: 10,
        toolStatus: 'surprising_status',
      );

      expect(event.toJson()['toolStatus'], 'validation_failed');
    });
  });

  group('AIChatAnalyticsTracker', () {
    test('disabled tracker has no side effects', () {
      final sink = CapturingAIChatAnalyticsSink();
      final tracker = AIChatAnalyticsTracker(enabled: false, sink: sink);

      tracker.beginTurn(
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 12,
      );
      tracker.record(
        eventType: 'turn_completed',
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 12,
      );

      expect(sink.events, isEmpty);
    });

    test('adds turn duration from beginTurn baseline', () {
      final sink = CapturingAIChatAnalyticsSink();
      var now = DateTime(2026, 1, 1, 12);
      final tracker = AIChatAnalyticsTracker(
        enabled: true,
        sink: sink,
        now: () => now,
      );

      tracker.beginTurn(
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 12,
      );
      now = now.add(const Duration(milliseconds: 125));
      tracker.record(
        eventType: 'turn_completed',
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 0,
      );

      expect(sink.events.single.toJson()['turnDurationMs'], 125);
      expect(sink.events.single.toJson()['messageLength'], 12);
      expect(sink.events.single.toJson()['turnId'], 'turn_000001');
    });

    test('keeps explicit turn id from beginTurn', () {
      final sink = CapturingAIChatAnalyticsSink();
      final tracker = AIChatAnalyticsTracker(enabled: true, sink: sink);

      tracker.beginTurn(
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 12,
        turnId: 'explicit-turn-1',
      );
      tracker.record(
        eventType: 'turn_completed',
        requestId: 'request-1',
        sessionId: 'session-1',
        language: AIChatLanguage.english,
        messageLength: 0,
      );

      expect(sink.events.single.toJson()['turnId'], 'explicit-turn-1');
    });

    test('keeps recent sanitized turn traces for local debug snapshots', () {
      final sink = CapturingAIChatAnalyticsSink();
      final tracker = AIChatAnalyticsTracker(enabled: true, sink: sink);

      for (var i = 0; i < 12; i += 1) {
        final requestId = 'request-$i';
        tracker.beginTurn(
          requestId: requestId,
          sessionId: 'session-raw',
          language: AIChatLanguage.english,
          messageLength: 10 + i,
        );
        tracker.record(
          eventType: 'turn_completed',
          requestId: requestId,
          sessionId: 'session-raw',
          language: AIChatLanguage.english,
          messageLength: 0,
          route: 'recommendation',
          finalProductIds: const ['p1', 'p2'],
        );
      }

      expect(tracker.recentTurnTraces, hasLength(10));
      expect(tracker.recentTurnTraces.first.turnId, 'turn_000003');
      final snapshot = tracker.buildDebugSnapshot(
        feedbackId: 'feedback-1',
        feedbackValue: 'down',
        feedbackReason: AIChatFeedbackReason.confusingAnswer,
        notePreview: 'userId=abc12345',
      );
      final encoded = snapshot.toJson().toString();
      expect(encoded, contains('[redacted_identifier]'));
      expect(encoded, isNot(contains('session-raw')));
      expect(encoded, isNot(contains('userId=abc12345')));
    });

    test('records core PR13A event metadata safely', () {
      final sink = CapturingAIChatAnalyticsSink();
      final tracker = AIChatAnalyticsTracker(enabled: true, sink: sink);

      for (final eventType in AIChatAnalyticsEvent.allowedEventTypes) {
        tracker.record(
          eventType: eventType,
          requestId: 'request-$eventType',
          sessionId: 'session-$eventType',
          language: AIChatLanguage.english,
          messageLength: 5,
          route: 'route',
          action: 'action',
          source: 'source',
          toolName: eventType == 'tool_executed' ? 'search_products' : null,
          toolStatus: eventType == 'tool_executed' ? 'success' : null,
          productCount: 10,
          finalProductIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
          guardBlockedCount: 3,
          noMatchReason: eventType == 'no_match' ? 'budget_no_match' : null,
          failureReason: eventType == 'fallback_used' ? 'worker_timeout' : null,
        );
      }

      expect(
        sink.events,
        hasLength(AIChatAnalyticsEvent.allowedEventTypes.length),
      );
      final toolEvent = sink.events
          .map((event) => event.toJson())
          .singleWhere((json) => json['eventType'] == 'tool_executed');
      expect(toolEvent['toolName'], 'search_products');
      expect(toolEvent['toolStatus'], 'success');
      expect(toolEvent['guardBlockedCount'], 3);
      expect(toolEvent['finalProductIds'], const ['a', 'b', 'c', 'd', 'e']);
    });

    test(
      'records local gate shadow decision without confidence or raw text',
      () {
        final sink = CapturingAIChatAnalyticsSink();
        final tracker = AIChatAnalyticsTracker(enabled: true, sink: sink);

        tracker.record(
          eventType: 'local_gate_shadow_decision',
          requestId: 'request-1',
          sessionId: 'session-raw',
          language: AIChatLanguage.english,
          messageLength: 18,
          oldRoute: 'recommendation',
          oldAction: 'recommend',
          oldSource: 'turn_decision',
          shadowGateResult: 'localSafe',
          shadowGateRoute: 'exact_catalog_availability',
          wouldSendToLlm: false,
          shouldRenderCards: true,
          proofLevel: 'deterministic',
          shadowGateProofReasons: const [
            'availability_phrase',
            'single_exact_catalog_match',
          ],
          ambiguityReasons: const ['not_raw_text'],
        );

        final json = sink.events.single.toJson();
        expect(json['eventType'], 'local_gate_shadow_decision');
        expect(json['sessionIdHash'], isNot('session-raw'));
        expect(json['proofLevel'], 'deterministic');
        expect(json['shadowGateProofReasons'], contains('availability_phrase'));
        expect(json.containsKey('shadowConfidence'), isFalse);
        expect(json.containsKey('rawUserMessage'), isFalse);
        expect(json.containsKey('sessionId'), isFalse);
        expect(json.containsKey('userId'), isFalse);
        expect(json.containsKey('fullPrompt'), isFalse);
      },
    );

    test('debug sink emits only sanitized event data', () {
      final printed = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };

      const DebugConsoleAIChatAnalyticsSink().record(
        AIChatAnalyticsEvent(
          eventType: 'local_gate_shadow_decision',
          requestId: 'request-1',
          sessionId: 'raw-session',
          language: AIChatLanguage.english,
          messageLength: 22,
          oldRoute: 'recommendation',
          shadowGateResult: 'needsLlm',
          shadowGateRoute: 'needs_llm',
          proofLevel: 'insufficient',
        ),
      );

      expect(printed.single, contains('AIChatAnalyticsEvent'));
      expect(printed.single, isNot(contains('raw-session')));
      expect(printed.single, isNot(contains('rawUserMessage')));
      expect(printed.single, isNot(contains('fullPrompt')));
      expect(printed.single, isNot(contains('userId')));
      expect(printed.single, isNot(contains('shadowConfidence')));
    });
  });

  group('AIChatDebugSessionBuilder', () {
    test('exports ordered redacted visible transcript with trace metadata', () {
      final builder = AIChatDebugSessionBuilder();
      final session = builder.build(
        chatDebugId: 'chat_dbg_test',
        messages: <AIChatMessage>[
          AIChatMessage.botText('Welcome to the perfume assistant.'),
          AIChatMessage.user('hello test@example.com'),
          AIChatMessage.botText('Hi, I can help.'),
        ],
        traces: <AIChatTurnTrace>[
          AIChatTurnTrace(
            turnId: 'turn-1',
            requestId: 'req-1',
            chatDebugId: 'chat_dbg_test',
            sessionIdHash: 'hash-1',
            language: AIChatLanguage.english,
            messageLength: 22,
            route: 'social',
            source: 'local_social',
            turnDurationMs: 120,
          ),
        ],
      );

      final json = session.toJson();
      final turn = (json['turns'] as List).single as Map<String, Object?>;

      expect(json['chatDebugId'], 'chat_dbg_test');
      expect(turn['userMessageRedacted'], contains('[redacted_email]'));
      expect(turn['assistantReplyRedacted'], 'Hi, I can help.');
      expect(turn['route'], 'social');
      expect(turn['source'], 'local_social');
      expect(turn.containsKey('prompt'), isFalse);
      expect(turn.containsKey('sessionId'), isFalse);
    });
  });

  group('AIChatDebugSnapshot', () {
    test(
      'serializes sanitized feedback trace without raw sensitive fields',
      () {
        final trace = AIChatTurnTrace.fromEvent(
          AIChatAnalyticsEvent(
            eventType: 'turn_completed',
            requestId: 'request-1',
            turnId: 'turn-1',
            sessionId: 'raw-session-id',
            language: AIChatLanguage.english,
            messageLength: 31,
            route: 'recommendation',
            action: 'recommend',
            source: 'worker',
            toolName: 'search_products',
            toolStatus: 'success',
            productCount: 7,
            finalProductIds: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
          ),
        );

        final snapshot = AIChatDebugSnapshot(
          feedbackId: 'feedback-1',
          feedbackValue: 'down',
          feedbackReason: AIChatFeedbackReason.slowResponse,
          recentTurns: [trace],
          sanitizedNotePreview:
              'Call me at 01012345678 or test@example.com sessionId=abc12345',
        );

        final json = snapshot.toJson();
        final encoded = json.toString();

        expect(json['feedbackReason'], 'slow_response');
        expect(encoded, contains('[redacted_phone]'));
        expect(encoded, contains('[redacted_email]'));
        expect(encoded, contains('[redacted_identifier]'));
        expect(encoded, isNot(contains('01012345678')));
        expect(encoded, isNot(contains('test@example.com')));
        expect(encoded, isNot(contains('raw-session-id')));
        expect(encoded, isNot(contains('sessionId=abc12345')));
        final recentTurns = json['recentTurns'] as List<Object?>;
        final turnJson = recentTurns.single as Map<String, Object?>;
        expect(turnJson['finalProductIds'], const [
          'p1',
          'p2',
          'p3',
          'p4',
          'p5',
        ]);
        expect(turnJson.containsKey('sessionId'), isFalse);
        expect(turnJson.containsKey('rawUserMessage'), isFalse);
        expect(turnJson.containsKey('prompt'), isFalse);
      },
    );

    test('accepts only known feedback reason values', () {
      expect(
        AIChatFeedbackReason.fromValue('external_lookup_wrong'),
        AIChatFeedbackReason.externalLookupWrong,
      );
      expect(AIChatFeedbackReason.fromValue('unknown_reason'), isNull);
    });
  });
}
