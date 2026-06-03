import 'dart:async';

import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_debug_session_builder.dart';

abstract class AIChatFeedbackRemoteSink {
  Future<bool> sendNegativeFeedbackSnapshot(AIChatDebugSnapshot snapshot);
}

abstract class AIChatTurnDebugRemoteSink {
  Future<bool> sendTurnDebug(AIChatDebugSessionTurn turn);
}

class NoopAIChatTurnDebugRemoteSink implements AIChatTurnDebugRemoteSink {
  const NoopAIChatTurnDebugRemoteSink();

  @override
  Future<bool> sendTurnDebug(AIChatDebugSessionTurn turn) async => false;
}

class WorkerAIChatTurnDebugRemoteSink implements AIChatTurnDebugRemoteSink {
  WorkerAIChatTurnDebugRemoteSink({
    required AIChatRepo aiChatRepo,
    DateTime Function()? now,
  }) : _aiChatRepo = aiChatRepo,
       _now = now ?? DateTime.now;

  final AIChatRepo _aiChatRepo;
  final DateTime Function() _now;

  @override
  Future<bool> sendTurnDebug(AIChatDebugSessionTurn turn) {
    final payload = _buildPayload(turn);
    return _aiChatRepo.sendAIChatTurnDebug(
      payload: payload,
      requestId: turn.requestId,
    );
  }

  Map<String, Object?> _buildPayload(AIChatDebugSessionTurn turn) {
    return <String, Object?>{
      'schemaVersion': 1,
      'eventType': 'ai_chat_turn_debug',
      'createdAt': _now().toUtc().toIso8601String(),
      'chatDebugId': turn.chatDebugId,
      'turnId': turn.turnId,
      'requestId': turn.requestId,
      'sessionIdHash': turn.sessionIdHash,
      'language': null,
      'messageLength': turn.userMessageRedacted?.length,
      'userMessageRedacted': turn.userMessageRedacted,
      'assistantReplyRedacted': turn.assistantReplyRedacted,
      'replyType': turn.replyType,
      'route': turn.route,
      'action': turn.action,
      'source': turn.source,
      'toolName': turn.toolName,
      'toolStatus': turn.toolStatus,
      'renderIntent': turn.renderIntent,
      'workerUsed': turn.workerUsed,
      'fallbackUsed': turn.fallbackUsed,
      'workerLatencyMs': turn.workerLatencyMs,
      'turnDurationMs': turn.turnDurationMs,
      'productCount': turn.productCount,
      'finalProductIds': turn.finalProductIds,
      'noMatchReason': turn.noMatchReason,
      'failureReason': turn.failureReason,
      'feedbackReason': turn.feedbackReason,
    }..removeWhere((_, value) => value == null);
  }
}

class NoopAIChatFeedbackRemoteSink implements AIChatFeedbackRemoteSink {
  const NoopAIChatFeedbackRemoteSink();

  @override
  Future<bool> sendNegativeFeedbackSnapshot(
    AIChatDebugSnapshot snapshot,
  ) async {
    return false;
  }
}

class WorkerAIChatFeedbackRemoteSink implements AIChatFeedbackRemoteSink {
  WorkerAIChatFeedbackRemoteSink({
    required AIChatRepo aiChatRepo,
    DateTime Function()? now,
  }) : _aiChatRepo = aiChatRepo,
       _now = now ?? DateTime.now;

  final AIChatRepo _aiChatRepo;
  final DateTime Function() _now;

  @override
  Future<bool> sendNegativeFeedbackSnapshot(AIChatDebugSnapshot snapshot) {
    final payload = _buildPayload(snapshot);
    return _aiChatRepo.sendNegativeFeedbackDebugSnapshot(
      payload: payload,
      requestId: payload['requestId']?.toString(),
    );
  }

  Map<String, Object?> _buildPayload(AIChatDebugSnapshot snapshot) {
    final snapshotJson = snapshot.toJson();
    final turns = (snapshotJson['recentTurns'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .take(10)
        .toList(growable: false);
    final lastTurn = turns.isEmpty ? <String, Object?>{} : turns.last;

    return <String, Object?>{
      'schemaVersion': 1,
      'eventType': 'ai_chat_negative_feedback',
      'feedbackId': snapshotJson['feedbackId'],
      'createdAt': _now().toUtc().toIso8601String(),
      'environment': 'app',
      'sessionIdHash': lastTurn['sessionIdHash'],
      'turnId': lastTurn['turnId'],
      'requestId': lastTurn['requestId'],
      'feedback': <String, Object?>{
        'rating': snapshot.feedbackValue,
        'reason': snapshot.feedbackReason.value,
      },
      'trace': <String, Object?>{
        'route': lastTurn['route'],
        'action': lastTurn['action'],
        'source': lastTurn['source'],
        'toolName': lastTurn['toolName'],
        'toolStatus': lastTurn['toolStatus'],
        'renderIntent': lastTurn['renderIntent'],
        'workerUsed': lastTurn['workerUsed'],
        'fallbackUsed': lastTurn['fallbackUsed'],
        'workerLatencyMs': lastTurn['workerLatencyMs'],
        'turnDurationMs': lastTurn['turnDurationMs'],
        'productCount': lastTurn['productCount'],
        'finalProductIds': lastTurn['finalProductIds'],
        'guardBlockedCount': lastTurn['guardBlockedCount'],
        'noMatchReason': lastTurn['noMatchReason'],
        'failureReason': lastTurn['failureReason'],
      }..removeWhere((_, value) => value == null),
      'diagnostics': <String, Object?>{
        'mojibakeDetected': false,
        'invalidProductIdDetected': false,
        'externalCardViolationDetected': false,
        'genericMessageDetected': false,
      },
      'snapshot': <String, Object?>{'turnCount': turns.length, 'turns': turns},
    };
  }
}
