import 'dart:async';
import 'dart:developer';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_feedback_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_persistence_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

class AIChatSessionActions {
  final AIChatState Function() _getState;
  final void Function(AIChatState state) _emitState;
  final AIChatRepo _aiChatRepo;
  final AIChatFeedbackHelper _feedbackHelper;
  final AIChatSessionPersistenceHelper _sessionPersistenceHelper;
  final UserTasteRepo? _userTasteRepo;
  final String Function() _getSessionId;
  final void Function(String sessionId) _setSessionId;
  final void Function() _cancelCooldown;
  final void Function() _resetTransientConversationState;
  final Future<void> Function(String sessionId) _saveLastSessionId;
  final Future<void> Function() _clearLastSessionId;
  final String Function() _newSessionId;
  final String _logName;
  final String Function(
    AIChatLanguage language, {
    required String ar,
    required String en,
  })
  _translate;

  bool _isClearingSession = false;
  Future<void>? _activeClearSession;

  AIChatSessionActions({
    required AIChatState Function() getState,
    required void Function(AIChatState state) emitState,
    required AIChatRepo aiChatRepo,
    required AIChatFeedbackHelper feedbackHelper,
    required AIChatSessionPersistenceHelper sessionPersistenceHelper,
    required UserTasteRepo? userTasteRepo,
    required String Function() getSessionId,
    required void Function(String sessionId) setSessionId,
    required void Function() cancelCooldown,
    required void Function() resetTransientConversationState,
    required Future<void> Function(String sessionId) saveLastSessionId,
    required Future<void> Function() clearLastSessionId,
    required String Function() newSessionId,
    required String Function(
      AIChatLanguage language, {
      required String ar,
      required String en,
    })
    translate,
    String logName = 'AIChatCubit',
  }) : _getState = getState,
       _emitState = emitState,
       _aiChatRepo = aiChatRepo,
       _feedbackHelper = feedbackHelper,
       _sessionPersistenceHelper = sessionPersistenceHelper,
       _userTasteRepo = userTasteRepo,
       _getSessionId = getSessionId,
       _setSessionId = setSessionId,
       _cancelCooldown = cancelCooldown,
       _resetTransientConversationState = resetTransientConversationState,
       _saveLastSessionId = saveLastSessionId,
       _clearLastSessionId = clearLastSessionId,
       _newSessionId = newSessionId,
       _translate = translate,
       _logName = logName;

  Future<void> clearSession() async {
    if (_isClearingSession) {
      return _activeClearSession ?? Future.value();
    }

    final clearCompleter = Completer<void>();
    _isClearingSession = true;
    _activeClearSession = clearCompleter.future;

    final closingSessionId = _getSessionId();
    _cancelCooldown();
    try {
      await _sessionPersistenceHelper.completeSessionById(closingSessionId);
      await _clearLastSessionId();
      _resetTransientConversationState();

      final nextSessionId = _newSessionId();
      _setSessionId(nextSessionId);
      _aiChatRepo.setSessionId(nextSessionId);
      _aiChatRepo.invalidateCatalogCache();

      final currentLanguage = _getState().language;
      _emitState(AIChatState(language: currentLanguage));
      sendWelcomeMessage(getState: _getState, emitState: _emitState);
      final created = await _sessionPersistenceHelper.startSessionPersistence(
        sessionId: nextSessionId,
        language: _getState().language,
        seedMessages: _getState().messages,
      );
      if (created) {
        await _saveLastSessionId(nextSessionId);
      }
      clearCompleter.complete();
    } catch (e, st) {
      if (!clearCompleter.isCompleted) {
        clearCompleter.completeError(e, st);
      }
      rethrow;
    } finally {
      _isClearingSession = false;
      _activeClearSession = null;
    }
  }

  Future<bool> submitSessionFeedback({
    required int rating,
    required bool isHelpful,
    String? comment,
  }) async {
    final currentState = _getState();
    final saved = await _feedbackHelper.submitSessionFeedback(
      sessionId: _getSessionId(),
      rating: rating,
      isHelpful: isHelpful,
      comment: comment,
      preferencesSnapshot: currentState.preferences,
      languageSnapshot: currentState.language,
    );
    if (!saved) {
      _emitState(
        currentState.copyWith(
          errorMessage: _translate(
            currentState.language,
            ar: 'تعذر حفظ تقييم الجلسة الآن. حاول مرة أخرى.',
            en: 'Could not save session feedback right now. Please try again.',
          ),
        ),
      );
    }
    return saved;
  }

  Future<bool> submitRecommendationFeedback({
    required String messageId,
    required bool isHelpful,
    String? note,
    String? requestId,
    AIChatFeedbackReason? reason,
  }) async {
    final currentState = _getState();
    final saved = await _feedbackHelper.submitRecommendationFeedback(
      sessionId: _getSessionId(),
      messageId: messageId,
      isHelpful: isHelpful,
      note: note,
      requestId: requestId,
      reason: reason,
    );
    if (!saved) {
      _emitState(
        currentState.copyWith(
          errorMessage: _translate(
            currentState.language,
            ar: 'تعذر حفظ التقييم الآن. حاول مرة أخرى.',
            en: 'Could not save feedback right now. Please try again.',
          ),
        ),
      );
    }
    return saved;
  }

  Future<void> onNotifyMeRequested(String productId, String userId) async {
    try {
      await _aiChatRepo.saveRestockRequest(
        productId: productId,
        userId: userId,
      );

      final currentState = _getState();
      final updatedNotified = Set<String>.from(currentState.notifiedProductIds)
        ..add(productId);
      _emitState(
        currentState.copyWith(
          notifiedProductIds: updatedNotified,
          errorMessage: null,
        ),
      );
    } catch (e) {
      log('Cubit error requesting notification: $e', name: _logName);
      final currentState = _getState();
      _emitState(
        currentState.copyWith(
          errorMessage: _translate(
            currentState.language,
            ar: 'تعذر حفظ طلب الإشعار الآن. حاول مرة أخرى.',
            en: 'Could not save your notify request right now. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> onRecommendedProductTapped(ProductModel product) async {
    Future<void>(() async {
      try {
        await _userTasteRepo?.recordEvent(
          eventType: EventType.aiClick,
          notes: <String>[...product.notes, ...product.tags],
        );
      } catch (_) {
        // Non-blocking local tracking.
      }
    });

    try {
      final currentState = _getState();
      final ref = currentState.recommendationMemory.lastRecommendedProducts
          .where((r) => r.productId == product.id)
          .firstOrNull;
      await _aiChatRepo.logAIChatEvent(
        eventType: 'conversion_product_clicked',
        sessionId: _getSessionId(),
        metadata: {
          'productId': product.id,
          'price': product.effectivePrice,
          if (ref?.requestId != null) 'requestId': ref!.requestId,
          if (ref?.promptVersion != null) 'promptVersion': ref!.promptVersion,
          if (ref?.provider != null) 'provider': ref!.provider,
          if (ref?.modelId != null) 'modelId': ref!.modelId,
        },
      );
    } catch (_) {
      // Non-blocking analytics.
    }
  }

  Future<void> onUpsellProductTapped(RecommendedProduct recommendation) async {
    if (recommendation.budgetStatus !=
        RecommendedBudgetStatus.slightlyAboveBudget) {
      return;
    }

    try {
      final currentState = _getState();
      final ref = currentState.recommendationMemory.lastRecommendedProducts
          .where((r) => r.productId == recommendation.product.id)
          .firstOrNull;
      await _aiChatRepo.logAIChatEvent(
        eventType: 'conversion_upsell_product_clicked',
        sessionId: _getSessionId(),
        metadata: {
          'productId': recommendation.product.id,
          'exactBudget': recommendation.exactBudget,
          'productPrice': recommendation.product.effectivePrice,
          'deltaAmount': recommendation.overBudgetAmount,
          'deltaPercent': recommendation.overBudgetPercent,
          if (ref?.requestId != null) 'requestId': ref!.requestId,
          if (ref?.promptVersion != null) 'promptVersion': ref!.promptVersion,
          if (ref?.provider != null) 'provider': ref!.provider,
          if (ref?.modelId != null) 'modelId': ref!.modelId,
        },
      );
    } catch (_) {
      // Non-blocking analytics.
    }
  }
}
