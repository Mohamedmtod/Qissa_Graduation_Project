import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_remote_sink.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

class _MockFeedbackRemoteSink extends Mock
    implements AIChatFeedbackRemoteSink {}

void main() {
  late _MockAIChatRepo repo;

  setUpAll(() {
    registerFallbackValue(
      const AIChatFeedback(
        sessionId: 'session',
        messageId: 'message',
        isHelpful: false,
      ),
    );
    registerFallbackValue(
      AIChatDebugSnapshot(
        feedbackId: 'feedback',
        feedbackValue: 'down',
        feedbackReason: AIChatFeedbackReason.other,
        recentTurns: const [],
      ),
    );
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repo = _MockAIChatRepo();
    when(
      () => repo.saveRecommendationFeedback(feedback: any(named: 'feedback')),
    ).thenAnswer((_) async {});
    when(
      () => repo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'negative feedback exports selected reason in sanitized snapshot',
    () async {
      final tracker = AIChatAnalyticsTracker(
        enabled: true,
        sink: CapturingAIChatAnalyticsSink(),
      );
      tracker.beginTurn(
        requestId: 'request-1',
        sessionId: 'raw-session-1',
        language: AIChatLanguage.english,
        messageLength: 38,
        turnId: 'turn-1',
      );
      tracker.record(
        eventType: 'turn_completed',
        requestId: 'request-1',
        sessionId: 'raw-session-1',
        language: AIChatLanguage.english,
        messageLength: 0,
        route: 'recommendation',
        action: 'recommend',
        source: 'worker',
        toolName: 'search_products',
        toolStatus: 'success',
        workerLatencyMs: 321,
        productCount: 6,
        finalProductIds: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
      );

      final helper = AIChatFeedbackHelper(
        aiChatRepo: repo,
        analyticsTracker: tracker,
      );

      final saved = await helper.submitRecommendationFeedback(
        sessionId: 'raw-session-1',
        messageId: 'message-1',
        isHelpful: false,
        note: 'Phone 01012345678 token=abc12345',
        requestId: 'request-1',
        reason: AIChatFeedbackReason.notSimilar,
      );

      expect(saved, isTrue);
      final snapshot = helper.exportLatestDebugSnapshotJson();
      expect(snapshot, isNotNull);
      final encoded = snapshot.toString();
      expect(snapshot!['feedbackReason'], 'not_similar');
      expect(encoded, contains('turn-1'));
      expect(encoded, contains('request-1'));
      expect(encoded, contains('sessionIdHash'));
      expect(encoded, contains('[redacted_phone]'));
      expect(encoded, contains('[redacted_identifier]'));
      expect(encoded, isNot(contains('raw-session-1')));
      expect(encoded, isNot(contains('01012345678')));
      expect(encoded, isNot(contains('token=abc12345')));
      expect(encoded, isNot(contains('rawUserMessage')));
      expect(encoded, isNot(contains('prompt')));
      expect(encoded, isNot(contains('userId')));

      final captured =
          verify(
                () => repo.saveRecommendationFeedback(
                  feedback: captureAny(named: 'feedback'),
                ),
              ).captured.single
              as AIChatFeedback;
      expect(captured.reason, AIChatFeedbackReason.notSimilar);
      expect(captured.turnId, 'turn-1');
      expect(captured.requestId, 'request-1');
      expect(captured.sessionIdHash, isNot('raw-session-1'));
    },
  );

  test(
    'negative feedback sends sanitized snapshot only when remote sink is injected',
    () async {
      final remoteSink = _MockFeedbackRemoteSink();
      when(
        () => remoteSink.sendNegativeFeedbackSnapshot(any()),
      ).thenAnswer((_) async => true);
      final tracker = AIChatAnalyticsTracker(
        enabled: true,
        sink: CapturingAIChatAnalyticsSink(),
      );
      tracker.beginTurn(
        requestId: 'request-remote',
        sessionId: 'raw-session-remote',
        language: AIChatLanguage.english,
        messageLength: 18,
        turnId: 'turn-remote',
      );
      tracker.record(
        eventType: 'turn_completed',
        requestId: 'request-remote',
        sessionId: 'raw-session-remote',
        language: AIChatLanguage.english,
        messageLength: 0,
        route: 'recommendation',
      );
      final helper = AIChatFeedbackHelper(
        aiChatRepo: repo,
        analyticsTracker: tracker,
        remoteSink: remoteSink,
      );

      await helper.submitRecommendationFeedback(
        sessionId: 'raw-session-remote',
        messageId: 'message-remote',
        isHelpful: false,
        reason: AIChatFeedbackReason.slowResponse,
      );

      final snapshot =
          verify(
                () => remoteSink.sendNegativeFeedbackSnapshot(captureAny()),
              ).captured.single
              as AIChatDebugSnapshot;
      final encoded = snapshot.toJson().toString();
      expect(snapshot.feedbackReason, AIChatFeedbackReason.slowResponse);
      expect(encoded, contains('turn-remote'));
      expect(encoded, contains('request-remote'));
      expect(encoded, isNot(contains('raw-session-remote')));
      expect(encoded, isNot(contains('rawUserMessage')));
      expect(encoded, isNot(contains('prompt')));
    },
  );

  test(
    'worker remote sink builds sanitized negative feedback payload',
    () async {
      when(
        () => repo.sendNegativeFeedbackDebugSnapshot(
          payload: any(named: 'payload'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) async => true);
      final sink = WorkerAIChatFeedbackRemoteSink(
        aiChatRepo: repo,
        now: () => DateTime.utc(2026, 6, 1, 10),
      );
      final snapshot = AIChatDebugSnapshot(
        feedbackId: 'fb_hash_message',
        feedbackValue: 'down',
        feedbackReason: AIChatFeedbackReason.notSimilar,
        recentTurns: [
          AIChatTurnTrace(
            turnId: 'turn-1',
            requestId: 'request-1',
            sessionIdHash: 'hash-1',
            language: AIChatLanguage.english,
            messageLength: 24,
            route: 'recommendation',
            source: 'worker',
            toolName: 'search_products',
            workerLatencyMs: 5300,
            productCount: 6,
            finalProductIds: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
          ),
        ],
        sanitizedNotePreview: 'token=abc12345',
      );

      final sent = await sink.sendNegativeFeedbackSnapshot(snapshot);

      expect(sent, isTrue);
      final payload =
          verify(
                () => repo.sendNegativeFeedbackDebugSnapshot(
                  payload: captureAny(named: 'payload'),
                  requestId: any(named: 'requestId'),
                ),
              ).captured.single
              as Map<String, Object?>;
      final encoded = payload.toString();
      expect(payload['schemaVersion'], 1);
      expect(payload['eventType'], 'ai_chat_negative_feedback');
      expect(payload['sessionIdHash'], 'hash-1');
      expect(payload['turnId'], 'turn-1');
      expect(payload['requestId'], 'request-1');
      expect(encoded, contains('not_similar'));
      expect(encoded, isNot(contains('rawUserMessage')));
      expect(encoded, isNot(contains('prompt')));
      expect(encoded, isNot(contains('sessionId:')));
      expect(encoded, isNot(contains('token=abc12345')));
      final trace = payload['trace'] as Map<String, Object?>;
      expect(trace['finalProductIds'], const ['p1', 'p2', 'p3', 'p4', 'p5']);
    },
  );

  test(
    'positive feedback stays lightweight and does not create snapshot',
    () async {
      final remoteSink = _MockFeedbackRemoteSink();
      final helper = AIChatFeedbackHelper(
        aiChatRepo: repo,
        analyticsTracker: AIChatAnalyticsTracker(
          enabled: true,
          sink: CapturingAIChatAnalyticsSink(),
        ),
        remoteSink: remoteSink,
      );

      final saved = await helper.submitRecommendationFeedback(
        sessionId: 'session-1',
        messageId: 'message-1',
        isHelpful: true,
        note: 'good',
        requestId: 'request-1',
      );

      expect(saved, isTrue);
      expect(helper.lastDebugSnapshot, isNull);
      expect(helper.exportLatestDebugSnapshotJson(), isNull);
      verifyNever(() => remoteSink.sendNegativeFeedbackSnapshot(any()));
    },
  );
}
