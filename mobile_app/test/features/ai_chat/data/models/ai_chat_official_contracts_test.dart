import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/analysis_transcript_payload.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';

void main() {
  group('AIUnifiedFeedback', () {
    test('message factory trims comment and keeps message invariants', () {
      final feedback = AIUnifiedFeedback.message(
        id: 'fb_1',
        sessionId: 'session_1',
        userId: 'user_1',
        targetMessageId: 'message_1',
        isHelpful: true,
        submittedAt: DateTime.utc(2026, 4, 17, 12),
        comment: '  Helpful answer  ',
      );

      expect(feedback.feedbackScope, AIUnifiedFeedbackScope.message);
      expect(feedback.targetMessageId, 'message_1');
      expect(feedback.rating, isNull);
      expect(feedback.comment, 'Helpful answer');
    });

    test('session factory rejects out-of-range rating', () {
      expect(
        () => AIUnifiedFeedback.session(
          id: 'fb_2',
          sessionId: 'session_1',
          userId: 'user_1',
          rating: 6,
          isHelpful: false,
          submittedAt: DateTime.utc(2026, 4, 17, 12),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson rejects message feedback with rating present', () {
      expect(
        () => AIUnifiedFeedback.fromJson({
          '_schemaVersion': 1,
          'id': 'fb_3',
          'sessionId': 'session_1',
          'userId': 'user_1',
          'feedbackScope': 'message',
          'targetMessageId': 'message_1',
          'rating': 4,
          'isHelpful': true,
          'comment': null,
          'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 4, 17, 12)),
          'analysisStatus': null,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AIFeedbackAnalysis', () {
    test('round-trips analysisSummary and raw payloads', () {
      final analysis = AIFeedbackAnalysis(
        id: 'analysis_1',
        sessionId: 'session_1',
        feedbackId: 'feedback_1',
        intentUnderstood: true,
        needSatisfied: false,
        satisfactionScore: 0.64,
        sentiment: AIFeedbackSentiment.neutral,
        analysisSummary:
            'The user intent was understood but only partially satisfied.',
        failureReason: 'Budget too restrictive',
        improvementSuggestion: 'Ask one more follow-up about note family.',
        missingNeeds: const ['more note specificity'],
        rawInput: const {'sessionId': 'session_1', 'transcriptCount': 4},
        rawModelOutput: const {'status': 'completed', 'confidence': 0.81},
        metadata: const {
          'provider': 'gemini',
          'modelId': 'gemini-1.5-flash',
          'promptVersion': 'v2',
          'requestId': 'req_123',
        },
        analyzedAt: DateTime.utc(2026, 4, 17, 13),
        status: AIFeedbackAnalysisStatus.completed,
      );

      final restored = AIFeedbackAnalysis.fromJson(analysis.toJson());

      expect(restored.analysisSummary, analysis.analysisSummary);
      expect(restored.failureReason, 'Budget too restrictive');
      expect(restored.rawInput['transcriptCount'], 4);
      expect(restored.rawModelOutput['confidence'], 0.81);
      expect(restored.metadata['provider'], 'gemini');
      expect(restored.metadata['modelId'], 'gemini-1.5-flash');
      expect(restored.status, AIFeedbackAnalysisStatus.completed);
    });
  });

  group('AnalysisTranscriptPayload', () {
    test('toJson emits compact transcript contract', () {
      const payload = AnalysisTranscriptPayload(
        sessionId: 'session_1',
        preferences: {'gender': 'men', 'maxBudget': 1200},
        entries: [
          AnalysisTranscriptEntry(
            role: 'user',
            messageType: 'text',
            content: 'I need a fresh summer perfume.',
          ),
          AnalysisTranscriptEntry(
            role: 'assistant',
            messageType: 'recommendation',
            productIds: ['p1', 'p2'],
            matchSummary: 'Fresh citrus options under budget.',
          ),
        ],
        originalMessageCount: 6,
        compactedMessageCount: 2,
        finalRecommendationMessageId: 'msg_9',
        finalRecommendationProductIds: ['p1', 'p2'],
      );

      final json = payload.toJson();

      expect(json['sessionId'], 'session_1');
      expect(json['originalMessageCount'], 6);
      expect(json['compactedMessageCount'], 2);
      expect(json['finalRecommendationMessageId'], 'msg_9');
      expect((json['transcript'] as List).length, 2);
      expect((json['transcript'] as List).last['productIds'], ['p1', 'p2']);
    });
  });
}
