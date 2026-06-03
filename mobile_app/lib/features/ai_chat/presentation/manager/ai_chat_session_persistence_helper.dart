import 'dart:async';
import 'dart:developer';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';

class AIChatSessionPersistenceHelper {
  final AIChatRepo _aiChatRepo;
  final String _logName;

  final Map<String, int> _persistedMessageCountBySession = <String, int>{};
  final Map<String, String?> _finalRecommendationMessageIdBySession =
      <String, String?>{};
  final Map<String, Set<String>> _persistedMessageIdsBySession =
      <String, Set<String>>{};
  final Map<String, Set<Future<void>>> _pendingPersistenceBySession =
      <String, Set<Future<void>>>{};
  final Set<String> _createdSessionIds = <String>{};
  final Map<String, Future<bool>> _sessionReadyBySession =
      <String, Future<bool>>{};

  AIChatSessionPersistenceHelper({
    required AIChatRepo aiChatRepo,
    String logName = 'AIChatCubit',
  }) : _aiChatRepo = aiChatRepo,
       _logName = logName;

  bool get _canPersistSession {
    try {
      return _aiChatRepo.canPersistSession;
    } catch (_) {
      return false;
    }
  }

  void _ensureSessionTracking(String sessionId) {
    _persistedMessageCountBySession.putIfAbsent(sessionId, () => 0);
    _finalRecommendationMessageIdBySession.putIfAbsent(sessionId, () => null);
    _persistedMessageIdsBySession.putIfAbsent(sessionId, () => <String>{});
    _pendingPersistenceBySession.putIfAbsent(sessionId, () => <Future<void>>{});
  }

  void _trackPendingWrite(String sessionId, Future<void> writeFuture) {
    _ensureSessionTracking(sessionId);
    final pending = _pendingPersistenceBySession[sessionId]!;
    pending.add(writeFuture);
    writeFuture.whenComplete(() {
      pending.remove(writeFuture);
    });
  }

  Future<void> _flushSessionWrites(String sessionId) async {
    _ensureSessionTracking(sessionId);
    while (true) {
      final pending = List<Future<void>>.from(
        _pendingPersistenceBySession[sessionId]!,
      );
      if (pending.isEmpty) return;
      await Future.wait(pending);
    }
  }

  Future<bool> startSessionPersistence({
    required String sessionId,
    required AIChatLanguage language,
    required List<AIChatMessage> seedMessages,
  }) async {
    if (!_canPersistSession) {
      _sessionReadyBySession[sessionId] = Future<bool>.value(false);
      log(
        'AI chat session persistence skipped: guest_local_session',
        name: _logName,
      );
      return false;
    }

    _persistedMessageCountBySession[sessionId] = 0;
    _finalRecommendationMessageIdBySession[sessionId] = null;
    _persistedMessageIdsBySession[sessionId] = <String>{};
    _pendingPersistenceBySession[sessionId] = <Future<void>>{};
    _createdSessionIds.remove(sessionId);

    final readyCompleter = Completer<bool>();
    _sessionReadyBySession[sessionId] = readyCompleter.future;

    try {
      await _aiChatRepo.createSession(sessionId: sessionId, language: language);
      _createdSessionIds.add(sessionId);
      readyCompleter.complete(true);

      for (final message in seedMessages) {
        await _persistMessage(message, sessionId: sessionId);
      }
      return true;
    } catch (e) {
      if (!readyCompleter.isCompleted) {
        readyCompleter.complete(false);
      }
      log(
        'Failed to create chat session persistence: firestore_denied_or_unavailable | $e',
        name: _logName,
      );
      return false;
    }
  }

  Future<void> completeSessionById(String sessionId) async {
    if (sessionId.trim().isEmpty) return;

    try {
      await _flushSessionWrites(sessionId);
      final sessionReady = await _waitForSessionReady(sessionId);
      if (!sessionReady) return;

      await _aiChatRepo.completeSession(
        sessionId: sessionId,
        messageCount: _persistedMessageCountBySession[sessionId] ?? 0,
        finalRecommendationMessageId:
            _finalRecommendationMessageIdBySession[sessionId],
      );
    } catch (e) {
      log('Failed to complete chat session persistence: $e', name: _logName);
    }
  }

  void enqueueMessagePersistence({
    required AIChatMessage message,
    required String sessionId,
  }) {
    if (!_canPersistSession) return;
    final writeFuture = _persistMessage(message, sessionId: sessionId);
    _trackPendingWrite(sessionId, writeFuture);
    unawaited(writeFuture);
  }

  Future<void> _persistMessage(
    AIChatMessage message, {
    required String sessionId,
  }) async {
    if (message.isLoading) return;
    if (!_canPersistSession) return;
    _ensureSessionTracking(sessionId);

    final sessionReady = await _waitForSessionReady(sessionId);
    if (!sessionReady) return;

    final persistedIds = _persistedMessageIdsBySession[sessionId]!;
    if (persistedIds.contains(message.id)) return;

    try {
      await _aiChatRepo.appendMessage(message: message, sessionId: sessionId);
      persistedIds.add(message.id);
      _persistedMessageCountBySession[sessionId] =
          (_persistedMessageCountBySession[sessionId] ?? 0) + 1;
      if (message.isRecommendation) {
        _finalRecommendationMessageIdBySession[sessionId] = message.id;
      }
    } catch (e) {
      log('Failed to persist chat message: $e', name: _logName);
    }
  }

  Future<bool> _waitForSessionReady(String sessionId) async {
    if (_createdSessionIds.contains(sessionId)) return true;
    final ready = _sessionReadyBySession[sessionId];
    if (ready == null) return false;
    return ready;
  }
}
