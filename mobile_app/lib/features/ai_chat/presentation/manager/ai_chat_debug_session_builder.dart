import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_analytics_tracker.dart';

class AIChatDebugSessionTurn {
  const AIChatDebugSessionTurn({
    required this.index,
    required this.chatDebugId,
    this.turnId,
    this.requestId,
    this.sessionIdHash,
    this.userMessageRedacted,
    this.assistantReplyRedacted,
    this.replyType,
    this.route,
    this.action,
    this.source,
    this.toolName,
    this.toolStatus,
    this.renderIntent,
    this.workerUsed,
    this.fallbackUsed,
    this.workerLatencyMs,
    this.turnDurationMs,
    this.productCount,
    this.finalProductIds = const <String>[],
    this.noMatchReason,
    this.failureReason,
    this.retargetAllowed,
    this.retargetProofSource,
    this.retargetBlockedReason,
    this.feedbackReason,
  });

  final int index;
  final String chatDebugId;
  final String? turnId;
  final String? requestId;
  final String? sessionIdHash;
  final String? userMessageRedacted;
  final String? assistantReplyRedacted;
  final String? replyType;
  final String? route;
  final String? action;
  final String? source;
  final String? toolName;
  final String? toolStatus;
  final String? renderIntent;
  final bool? workerUsed;
  final bool? fallbackUsed;
  final int? workerLatencyMs;
  final int? turnDurationMs;
  final int? productCount;
  final List<String> finalProductIds;
  final String? noMatchReason;
  final String? failureReason;
  final bool? retargetAllowed;
  final String? retargetProofSource;
  final String? retargetBlockedReason;
  final String? feedbackReason;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{
      'index': index,
      'chatDebugId': chatDebugId,
      'turnId': turnId,
      'requestId': requestId,
      'sessionIdHash': sessionIdHash,
      'userMessageRedacted': userMessageRedacted,
      'assistantReplyRedacted': assistantReplyRedacted,
      'replyType': replyType,
      'route': route,
      'action': action,
      'source': source,
      'toolName': toolName,
      'toolStatus': toolStatus,
      'renderIntent': renderIntent,
      'workerUsed': workerUsed,
      'fallbackUsed': fallbackUsed,
      'workerLatencyMs': workerLatencyMs,
      'turnDurationMs': turnDurationMs,
      'productCount': productCount,
      'finalProductIds': finalProductIds.take(5).toList(growable: false),
      'noMatchReason': noMatchReason,
      'failureReason': failureReason,
      'retargetAllowed': retargetAllowed,
      'retargetProofSource': retargetProofSource,
      'retargetBlockedReason': retargetBlockedReason,
      'feedbackReason': feedbackReason,
    }..removeWhere((_, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        if (value is Iterable && value.isEmpty) return true;
        return false;
      });
    return data;
  }
}

class AIChatDebugSession {
  const AIChatDebugSession({
    required this.chatDebugId,
    required this.turns,
  });

  final String chatDebugId;
  final List<AIChatDebugSessionTurn> turns;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'eventType': 'ai_chat_debug_session',
      'chatDebugId': chatDebugId,
      'turnCount': turns.length,
      'turns': turns.map((turn) => turn.toJson()).toList(growable: false),
    };
  }
}

class AIChatDebugSessionBuilder {
  const AIChatDebugSessionBuilder();

  AIChatDebugSession build({
    required String chatDebugId,
    required List<AIChatMessage> messages,
    required List<AIChatTurnTrace> traces,
  }) {
    final traceQueue = traces.toList(growable: false);
    var traceIndex = 0;
    final turns = <AIChatDebugSessionTurn>[];
    AIChatMessage? pendingUser;

    for (final message in messages.where((item) => !item.isLoading)) {
      if (message.isFromUser) {
        pendingUser = message;
        continue;
      }
      if (!message.isFromBot) continue;
      if (pendingUser == null) {
        continue;
      }

      final trace = traceIndex < traceQueue.length
          ? traceQueue[traceIndex++]
          : null;
      final products = message.recommendedProducts
          .map((item) => item.product.id)
          .where((id) => id.trim().isNotEmpty)
          .take(5)
          .toList(growable: false);

      turns.add(
        AIChatDebugSessionTurn(
          index: turns.length + 1,
          chatDebugId: chatDebugId,
          turnId: trace?.turnId,
          requestId: trace?.requestId,
          sessionIdHash: trace?.sessionIdHash,
          userMessageRedacted: AIChatDebugSanitizer.sanitizeTextPreview(
            pendingUser.content,
            maxLength: 300,
          ),
          assistantReplyRedacted: AIChatDebugSanitizer.sanitizeTextPreview(
            message.content,
            maxLength: 700,
          ),
          replyType: message.type.name,
          route: trace?.route,
          action: trace?.action,
          source: trace?.source ?? message.responseSource,
          toolName: trace?.toolName,
          toolStatus: trace?.toolStatus,
          renderIntent: trace?.renderIntent,
          workerUsed: trace?.workerUsed,
          fallbackUsed: trace?.fallbackUsed,
          workerLatencyMs: trace?.workerLatencyMs,
          turnDurationMs: trace?.turnDurationMs,
          productCount: trace?.productCount ?? products.length,
          finalProductIds: trace?.finalProductIds.isNotEmpty == true
              ? trace!.finalProductIds
              : products,
          noMatchReason: trace?.noMatchReason,
          failureReason: trace?.failureReason ?? message.workerFailureReason,
          retargetAllowed: trace?.retargetAllowed,
          retargetProofSource: trace?.retargetProofSource,
          retargetBlockedReason: trace?.retargetBlockedReason,
        ),
      );
      pendingUser = null;
    }

    return AIChatDebugSession(chatDebugId: chatDebugId, turns: turns);
  }
}
