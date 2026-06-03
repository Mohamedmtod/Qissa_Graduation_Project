import 'dart:async';
import 'dart:developer';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_remote_sink.dart';
import 'package:uuid/uuid.dart';

class AIChatFeedbackHelper {
  final AIChatRepo _aiChatRepo;
  final AIChatAnalyticsTracker? _analyticsTracker;
  final AIChatFeedbackRemoteSink _remoteSink;
  final String _logName;

  final Set<String> _submittedSessionFeedbackSessionIds = <String>{};
  final Set<String> _persistedSessionFeedbackSessionIds = <String>{};
  AIChatDebugSnapshot? _lastDebugSnapshot;

  AIChatFeedbackHelper({
    required AIChatRepo aiChatRepo,
    AIChatAnalyticsTracker? analyticsTracker,
    AIChatFeedbackRemoteSink remoteSink = const NoopAIChatFeedbackRemoteSink(),
    String logName = 'AIChatCubit',
  }) : _aiChatRepo = aiChatRepo,
       _analyticsTracker = analyticsTracker,
       _remoteSink = remoteSink,
       _logName = logName;

  AIChatDebugSnapshot? get lastDebugSnapshot => _lastDebugSnapshot;

  Map<String, Object?>? exportLatestDebugSnapshotJson() {
    return _lastDebugSnapshot?.toJson();
  }

  bool hasSessionFeedbackForSession(String sessionId) {
    final normalized = sessionId.trim();
    return _submittedSessionFeedbackSessionIds.contains(normalized) ||
        _persistedSessionFeedbackSessionIds.contains(normalized);
  }

  Future<bool> hasPersistedSessionFeedbackForSession(String sessionId) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) return false;

    if (hasSessionFeedbackForSession(normalized)) {
      return true;
    }

    try {
      final exists = await _aiChatRepo.hasSessionFeedback(
        sessionId: normalized,
      );
      if (exists) {
        _persistedSessionFeedbackSessionIds.add(normalized);
      }
      return exists;
    } catch (e) {
      log(
        'Session feedback existence check failed: $e',
        name: _logName,
        error: e,
      );
      return false;
    }
  }

  Future<bool> submitSessionFeedback({
    required String sessionId,
    required int rating,
    required bool isHelpful,
    String? comment,
    required SessionPreferences preferencesSnapshot,
    required AIChatLanguage languageSnapshot,
  }) async {
    if (await hasPersistedSessionFeedbackForSession(sessionId)) {
      _submittedSessionFeedbackSessionIds.add(sessionId);
      return true;
    }

    try {
      final savedFeedback = await _aiChatRepo.saveSessionFeedback(
        sessionId: sessionId,
        rating: rating,
        isHelpful: isHelpful,
        comment: comment,
      );

      _submittedSessionFeedbackSessionIds.add(sessionId);
      _persistedSessionFeedbackSessionIds.add(sessionId);
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'feedback_submitted',
          sessionId: sessionId,
          metadata: {
            'feedbackScope': 'session',
            'rating': rating,
            'isHelpful': isHelpful,
            'hasComment': comment != null && comment.trim().isNotEmpty,
          },
        ),
      );

      unawaited(
        _runSessionFeedbackAnalysis(
          feedback: savedFeedback,
          preferencesSnapshot: preferencesSnapshot,
          languageSnapshot: languageSnapshot,
          inlineFeedbackSummary: {
            'rating': rating,
            'isHelpful': isHelpful,
            'hasComment': comment != null && comment.trim().isNotEmpty,
          },
        ),
      );
      return true;
    } catch (e) {
      log('Session feedback save failed: $e', name: _logName, error: e);
      return false;
    }
  }

  Future<void> _runSessionFeedbackAnalysis({
    required AIUnifiedFeedback feedback,
    required SessionPreferences preferencesSnapshot,
    required AIChatLanguage languageSnapshot,
    required Map<String, dynamic> inlineFeedbackSummary,
  }) async {
    try {
      final analysisPayload = await _aiChatRepo.buildAnalysisPayload(
        sessionId: feedback.sessionId,
        preferences: preferencesSnapshot,
      );

      final requestId = const Uuid().v4();
      final analysis = await _aiChatRepo.triggerFeedbackAnalysis(
        analysisPayload: analysisPayload,
        sessionFeedback: feedback,
        inlineFeedbackSummary: inlineFeedbackSummary,
        responseLanguage: languageSnapshot.code,
        requestId: requestId,
      );

      if (analysis == null) {
        await _aiChatRepo.updateFeedbackAnalysisStatus(
          feedbackId: feedback.id,
          status: AIFeedbackAnalysisStatus.pendingRetry,
        );
        return;
      }

      await _aiChatRepo.saveFeedbackAnalysis(analysis: analysis);
      await _aiChatRepo.updateFeedbackAnalysisStatus(
        feedbackId: feedback.id,
        status: AIFeedbackAnalysisStatus.completed,
      );
    } catch (e, st) {
      log(
        'Session feedback analysis failed: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      try {
        await _aiChatRepo.updateFeedbackAnalysisStatus(
          feedbackId: feedback.id,
          status: AIFeedbackAnalysisStatus.failed,
        );
      } catch (innerError) {
        log(
          'Failed to mark feedback analysis status as failed: $innerError',
          name: _logName,
          error: innerError,
        );
      }
    }
  }

  Future<bool> submitRecommendationFeedback({
    required String sessionId,
    required String messageId,
    required bool isHelpful,
    String? note,
    String? requestId,
    AIChatFeedbackReason? reason,
  }) async {
    try {
      final effectiveReason = reason ?? AIChatFeedbackReason.other;
      AIChatDebugSnapshot? debugSnapshot;
      if (!isHelpful) {
        final feedbackSessionHash = AIChatAnalyticsEvent.hashSessionId(
          sessionId,
        );
        debugSnapshot = _analyticsTracker?.buildDebugSnapshot(
          feedbackId: '${feedbackSessionHash}_$messageId',
          feedbackValue: 'down',
          feedbackReason: effectiveReason,
          notePreview: note,
        );
        _lastDebugSnapshot = debugSnapshot;
        if (debugSnapshot != null) {
          unawaited(
            _remoteSink.sendNegativeFeedbackSnapshot(debugSnapshot).catchError((
              Object error,
              StackTrace stackTrace,
            ) {
              log(
                'Remote feedback snapshot send failed: $error',
                name: _logName,
                error: error,
                stackTrace: stackTrace,
              );
              return false;
            }),
          );
        }
      }
      await _aiChatRepo.saveRecommendationFeedback(
        feedback: AIChatFeedback(
          sessionId: sessionId,
          messageId: messageId,
          isHelpful: isHelpful,
          note: note,
          reason: reason,
          requestId: requestId,
          turnId: (debugSnapshot?.recentTurns.isEmpty ?? true)
              ? null
              : debugSnapshot!.recentTurns.last.turnId,
          sessionIdHash: (debugSnapshot?.recentTurns.isEmpty ?? true)
              ? null
              : debugSnapshot!.recentTurns.last.sessionIdHash,
        ),
      );

      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'feedback_submitted',
          sessionId: sessionId,
          metadata: {
            'feedbackScope': 'message',
            'targetMessageId': messageId,
            'isHelpful': isHelpful,
            'hasComment': note != null && note.trim().isNotEmpty,
            'feedbackReason': isHelpful ? null : effectiveReason.value,
            'hasDebugSnapshot': debugSnapshot != null,
            'requestId': requestId,
          },
        ),
      );
      return true;
    } catch (e) {
      log('Feedback save failed: $e', name: _logName, error: e);
      return false;
    }
  }
}
