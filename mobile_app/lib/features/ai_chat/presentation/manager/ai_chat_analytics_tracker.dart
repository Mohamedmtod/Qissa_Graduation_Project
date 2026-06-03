import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';

class AIChatAnalyticsEvent {
  AIChatAnalyticsEvent({
    required this.eventType,
    required this.requestId,
    this.turnId,
    this.chatDebugId,
    required String sessionId,
    required this.language,
    required this.messageLength,
    this.route,
    this.action,
    this.source,
    this.questionType,
    this.toolName,
    this.toolStatus,
    this.renderIntent,
    this.workerUsed,
    this.fallbackUsed,
    this.workerLatencyMs,
    this.turnDurationMs,
    this.productCount,
    List<String> finalProductIds = const <String>[],
    this.guardBlockedCount,
    this.clarificationType,
    this.noMatchReason,
    this.failureReason,
    this.oldRoute,
    this.oldAction,
    this.oldSource,
    this.shadowGateResult,
    this.shadowGateRoute,
    this.wouldSendToLlm,
    this.shouldRenderCards,
    this.proofLevel,
    this.shadowGateProofReasons = const <String>[],
    this.ambiguityReasons = const <String>[],
  }) : sessionIdHash = hashSessionId(sessionId),
       finalProductIds = finalProductIds.take(5).toList(growable: false);

  static const Set<String> allowedEventTypes = {
    'turn_completed',
    'tool_executed',
    'fallback_used',
    'clarification_asked',
    'no_match',
    'local_gate_shadow_decision',
  };

  static const Set<String> allowedToolStatuses = {
    'success',
    'needs_clarification',
    'no_results',
    'blocked_by_guard',
    'validation_failed',
    'not_handled',
  };

  final String eventType;
  final String? requestId;
  final String? turnId;
  final String? chatDebugId;
  final String sessionIdHash;
  final AIChatLanguage language;
  final int messageLength;
  final String? route;
  final String? action;
  final String? source;
  final String? questionType;
  final String? toolName;
  final String? toolStatus;
  final String? renderIntent;
  final bool? workerUsed;
  final bool? fallbackUsed;
  final int? workerLatencyMs;
  final int? turnDurationMs;
  final int? productCount;
  final List<String> finalProductIds;
  final int? guardBlockedCount;
  final String? clarificationType;
  final String? noMatchReason;
  final String? failureReason;
  final String? oldRoute;
  final String? oldAction;
  final String? oldSource;
  final String? shadowGateResult;
  final String? shadowGateRoute;
  final bool? wouldSendToLlm;
  final bool? shouldRenderCards;
  final String? proofLevel;
  final List<String> shadowGateProofReasons;
  final List<String> ambiguityReasons;

  static String hashSessionId(String sessionId) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    var hash = fnvOffset;
    for (final codeUnit in sessionId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Map<String, Object?> toJson() {
    final normalizedToolStatus = toolStatus == null
        ? null
        : allowedToolStatuses.contains(toolStatus)
        ? toolStatus
        : 'validation_failed';
    final data =
        <String, Object?>{
          'eventType': allowedEventTypes.contains(eventType)
              ? eventType
              : 'turn_completed',
          'requestId': requestId,
          'turnId': _normalizeNullable(turnId),
          'chatDebugId': _normalizeNullable(chatDebugId),
          'sessionIdHash': sessionIdHash,
          'language': language.code,
          'messageLength': messageLength,
          'route': route,
          'action': action,
          'source': source,
          'questionType': questionType,
          'toolName': toolName,
          'toolStatus': normalizedToolStatus,
          'renderIntent': renderIntent,
          'workerUsed': workerUsed,
          'fallbackUsed': fallbackUsed,
          'workerLatencyMs': workerLatencyMs,
          'turnDurationMs': turnDurationMs,
          'productCount': productCount,
          'finalProductIds': finalProductIds,
          'guardBlockedCount': guardBlockedCount,
          'clarificationType': clarificationType,
          'noMatchReason': noMatchReason,
          'failureReason': failureReason,
          'oldRoute': oldRoute,
          'oldAction': oldAction,
          'oldSource': oldSource,
          'shadowGateResult': shadowGateResult,
          'shadowGateRoute': shadowGateRoute,
          'wouldSendToLlm': wouldSendToLlm,
          'shouldRenderCards': shouldRenderCards,
          'proofLevel': proofLevel,
          'shadowGateProofReasons': shadowGateProofReasons,
          'ambiguityReasons': ambiguityReasons,
        }..removeWhere((_, value) {
          if (value == null) return true;
          if (value is Iterable && value.isEmpty) return true;
          return false;
        });
    return data;
  }

  static String? _normalizeNullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class AIChatTurnTrace {
  AIChatTurnTrace({
    required this.turnId,
    required this.requestId,
    this.chatDebugId,
    required String sessionIdHash,
    required this.language,
    required this.messageLength,
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
    List<String> finalProductIds = const <String>[],
    this.guardBlockedCount,
    this.noMatchReason,
    this.failureReason,
  }) : sessionIdHash = sessionIdHash.trim(),
       finalProductIds = finalProductIds.take(5).toList(growable: false);

  factory AIChatTurnTrace.fromEvent(AIChatAnalyticsEvent event) {
    return AIChatTurnTrace(
      turnId: event.turnId ?? '',
      requestId: event.requestId ?? '',
      chatDebugId: event.chatDebugId,
      sessionIdHash: event.sessionIdHash,
      language: event.language,
      messageLength: event.messageLength,
      route: event.route,
      action: event.action,
      source: event.source,
      toolName: event.toolName,
      toolStatus: event.toolStatus,
      renderIntent: event.renderIntent,
      workerUsed: event.workerUsed,
      fallbackUsed: event.fallbackUsed,
      workerLatencyMs: event.workerLatencyMs,
      turnDurationMs: event.turnDurationMs,
      productCount: event.productCount,
      finalProductIds: event.finalProductIds,
      guardBlockedCount: event.guardBlockedCount,
      noMatchReason: event.noMatchReason,
      failureReason: event.failureReason,
    );
  }

  final String turnId;
  final String requestId;
  final String? chatDebugId;
  final String sessionIdHash;
  final AIChatLanguage language;
  final int messageLength;
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
  final int? guardBlockedCount;
  final String? noMatchReason;
  final String? failureReason;

  Map<String, Object?> toJson() {
    final data =
        <String, Object?>{
          'turnId': turnId,
          'requestId': requestId,
          'chatDebugId': chatDebugId,
          'sessionIdHash': sessionIdHash,
          'language': language.code,
          'messageLength': messageLength,
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
          'finalProductIds': finalProductIds,
          'guardBlockedCount': guardBlockedCount,
          'noMatchReason': noMatchReason,
          'failureReason': failureReason,
        }..removeWhere((_, value) {
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
          if (value is Iterable && value.isEmpty) return true;
          return false;
        });
    return data;
  }
}

class AIChatDebugSnapshot {
  AIChatDebugSnapshot({
    required this.feedbackId,
    required this.feedbackValue,
    required this.feedbackReason,
    required List<AIChatTurnTrace> recentTurns,
    this.sanitizedNotePreview,
  }) : recentTurns = recentTurns.take(10).toList(growable: false);

  final String feedbackId;
  final String feedbackValue;
  final AIChatFeedbackReason feedbackReason;
  final List<AIChatTurnTrace> recentTurns;
  final String? sanitizedNotePreview;

  Map<String, Object?> toJson() {
    final data =
        <String, Object?>{
          'feedbackId': feedbackId,
          'feedbackValue': feedbackValue,
          'feedbackReason': feedbackReason.value,
          'recentTurns': recentTurns
              .map((turn) => turn.toJson())
              .toList(growable: false),
          'sanitizedNotePreview': AIChatDebugSanitizer.sanitizeTextPreview(
            sanitizedNotePreview,
          ),
        }..removeWhere((_, value) {
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
          if (value is Iterable && value.isEmpty) return true;
          return false;
        });
    return data;
  }
}

class AIChatDebugSanitizer {
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<!\d)(?:\+?\d[\s-]?){8,15}(?!\d)',
  );
  static final RegExp _sessionLikePattern = RegExp(
    r'\b(?:session|sessionId|user|userId|uid|token|key|secret)[-_:= ]+[A-Za-z0-9._-]{4,}\b',
    caseSensitive: false,
  );
  static final RegExp _tokenLikePattern = RegExp(
    r'\b(?:sk|pk|ghp|xoxb|AIza|ya29)[A-Za-z0-9._-]{8,}\b',
    caseSensitive: false,
  );
  static final RegExp _longIdPattern = RegExp(r'\b[A-Za-z0-9_-]{32,}\b');

  static String? sanitizeTextPreview(String? value, {int maxLength = 160}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final redacted = trimmed
        .replaceAll(_emailPattern, '[redacted_email]')
        .replaceAll(_phonePattern, '[redacted_phone]')
        .replaceAll(_sessionLikePattern, '[redacted_identifier]')
        .replaceAll(_tokenLikePattern, '[redacted_token]')
        .replaceAll(_longIdPattern, '[redacted_id]');
    return redacted.length <= maxLength
        ? redacted
        : redacted.substring(0, maxLength);
  }

  const AIChatDebugSanitizer._();
}

abstract class AIChatAnalyticsSink {
  void record(AIChatAnalyticsEvent event);
}

class NoopAIChatAnalyticsSink implements AIChatAnalyticsSink {
  const NoopAIChatAnalyticsSink();

  @override
  void record(AIChatAnalyticsEvent event) {}
}

class DebugConsoleAIChatAnalyticsSink implements AIChatAnalyticsSink {
  const DebugConsoleAIChatAnalyticsSink();

  @override
  void record(AIChatAnalyticsEvent event) {
    final serialized = 'AIChatAnalyticsEvent ${event.toJson()}';
    log(serialized, name: 'AIChatAnalytics');
    debugPrint(serialized);
  }
}

class CapturingAIChatAnalyticsSink implements AIChatAnalyticsSink {
  final List<AIChatAnalyticsEvent> events = <AIChatAnalyticsEvent>[];

  @override
  void record(AIChatAnalyticsEvent event) {
    events.add(event);
  }
}

class AIChatAnalyticsTracker {
  AIChatAnalyticsTracker({
    required bool enabled,
    required AIChatAnalyticsSink sink,
    String? chatDebugId,
    DateTime Function()? now,
  }) : _enabled = enabled,
       _sink = sink,
       _chatDebugId = chatDebugId?.trim(),
       _now = now ?? DateTime.now;

  factory AIChatAnalyticsTracker.fromConfig({String? chatDebugId}) {
    final enabled = AIChatExperimentConfig.analyticsEventsEnabled;
    final sink =
        enabled &&
            AIChatExperimentConfig.analyticsDebugSinkEnabled &&
            !kReleaseMode
        ? const DebugConsoleAIChatAnalyticsSink()
        : const NoopAIChatAnalyticsSink();
    return AIChatAnalyticsTracker(
      enabled: enabled,
      sink: sink,
      chatDebugId: chatDebugId,
    );
  }

  final bool _enabled;
  final AIChatAnalyticsSink _sink;
  final String? _chatDebugId;
  final DateTime Function() _now;
  final Map<String, _TurnStart> _turnStarts = <String, _TurnStart>{};
  final List<AIChatTurnTrace> _recentTurnTraces = <AIChatTurnTrace>[];
  int _turnSequence = 0;
  void Function(AIChatTurnTrace trace)? onTurnTraceRecorded;

  String? get chatDebugId => _chatDebugId;

  List<AIChatTurnTrace> get recentTurnTraces =>
      List<AIChatTurnTrace>.unmodifiable(_recentTurnTraces);

  AIChatDebugSnapshot buildDebugSnapshot({
    required String feedbackId,
    required String feedbackValue,
    required AIChatFeedbackReason feedbackReason,
    String? notePreview,
  }) {
    return AIChatDebugSnapshot(
      feedbackId: feedbackId,
      feedbackValue: feedbackValue,
      feedbackReason: feedbackReason,
      recentTurns: _recentTurnTraces,
      sanitizedNotePreview: notePreview,
    );
  }

  void beginTurn({
    required String requestId,
    required String sessionId,
    required AIChatLanguage language,
    required int messageLength,
    String? turnId,
  }) {
    if (!_enabled) return;
    _turnStarts[requestId] = _TurnStart(
      startedAt: _now(),
      turnId: _normalizeTurnId(turnId),
      sessionId: sessionId,
      language: language,
      messageLength: messageLength,
    );
  }

  void record({
    required String eventType,
    required String? requestId,
    required String sessionId,
    required AIChatLanguage language,
    required int messageLength,
    String? route,
    String? action,
    String? source,
    String? questionType,
    String? toolName,
    String? toolStatus,
    String? renderIntent,
    bool? workerUsed,
    bool? fallbackUsed,
    int? workerLatencyMs,
    int? turnDurationMs,
    int? productCount,
    List<String> finalProductIds = const <String>[],
    int? guardBlockedCount,
    String? clarificationType,
    String? noMatchReason,
    String? failureReason,
    String? oldRoute,
    String? oldAction,
    String? oldSource,
    String? shadowGateResult,
    String? shadowGateRoute,
    bool? wouldSendToLlm,
    bool? shouldRenderCards,
    String? proofLevel,
    List<String> shadowGateProofReasons = const <String>[],
    List<String> ambiguityReasons = const <String>[],
  }) {
    if (!_enabled) return;
    final started = requestId == null ? null : _turnStarts[requestId];
    final effectiveTurnId =
        started?.turnId ??
        (eventType == 'turn_completed' ? _nextSyntheticTurnId() : null);
    final effectiveDuration =
        turnDurationMs ??
        (started == null
            ? null
            : _now().difference(started.startedAt).inMilliseconds);
    final event = AIChatAnalyticsEvent(
      eventType: eventType,
      requestId: requestId,
      turnId: effectiveTurnId,
      chatDebugId: _chatDebugId,
      sessionId: started?.sessionId ?? sessionId,
      language: started?.language ?? language,
      messageLength: started?.messageLength ?? messageLength,
      route: route,
      action: action,
      source: source,
      questionType: questionType,
      toolName: toolName,
      toolStatus: toolStatus,
      renderIntent: renderIntent,
      workerUsed: workerUsed,
      fallbackUsed: fallbackUsed,
      workerLatencyMs: workerLatencyMs,
      turnDurationMs: effectiveDuration,
      productCount: productCount,
      finalProductIds: finalProductIds,
      guardBlockedCount: guardBlockedCount,
      clarificationType: clarificationType,
      noMatchReason: noMatchReason,
      failureReason: failureReason,
      oldRoute: oldRoute,
      oldAction: oldAction,
      oldSource: oldSource,
      shadowGateResult: shadowGateResult,
      shadowGateRoute: shadowGateRoute,
      wouldSendToLlm: wouldSendToLlm,
      shouldRenderCards: shouldRenderCards,
      proofLevel: proofLevel,
      shadowGateProofReasons: shadowGateProofReasons,
      ambiguityReasons: ambiguityReasons,
    );
    _rememberTrace(event);
    _sink.record(event);
  }

  String _nextSyntheticTurnId() {
    _turnSequence += 1;
    return 'turn_${_turnSequence.toString().padLeft(4, '0')}';
  }

  void _rememberTrace(AIChatAnalyticsEvent event) {
    if (event.turnId == null || event.turnId!.trim().isEmpty) return;
    _recentTurnTraces.add(AIChatTurnTrace.fromEvent(event));
    if (_recentTurnTraces.length > 10) {
      _recentTurnTraces.removeRange(0, _recentTurnTraces.length - 10);
    }
    onTurnTraceRecorded?.call(_recentTurnTraces.last);
  }

  String _normalizeTurnId(String? turnId) {
    final normalized = turnId?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
    _turnSequence += 1;
    return 'turn_${_turnSequence.toString().padLeft(6, '0')}';
  }
}

class _TurnStart {
  const _TurnStart({
    required this.startedAt,
    required this.turnId,
    required this.sessionId,
    required this.language,
    required this.messageLength,
  });

  final DateTime startedAt;
  final String turnId;
  final String sessionId;
  final AIChatLanguage language;
  final int messageLength;
}
