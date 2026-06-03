import 'package:uuid/uuid.dart';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

enum AIChatTurnRejection { emptyOrLoading, tooLong, cooldown, rateLimit }

class AIChatTurnValidationResult {
  final AIChatTurnContext? context;
  final AIChatTurnRejection? rejection;
  final String trimmed;
  final AIChatLanguage responseLanguage;
  final int rateLimitWindowCount;

  const AIChatTurnValidationResult._({
    required this.context,
    required this.rejection,
    required this.trimmed,
    required this.responseLanguage,
    required this.rateLimitWindowCount,
  });

  bool get accepted => context != null;

  factory AIChatTurnValidationResult.accepted(AIChatTurnContext context) {
    return AIChatTurnValidationResult._(
      context: context,
      rejection: null,
      trimmed: context.trimmed,
      responseLanguage: context.responseLanguage,
      rateLimitWindowCount: 0,
    );
  }

  factory AIChatTurnValidationResult.rejected({
    required AIChatTurnRejection rejection,
    required String trimmed,
    required AIChatLanguage responseLanguage,
    int rateLimitWindowCount = 0,
  }) {
    return AIChatTurnValidationResult._(
      context: null,
      rejection: rejection,
      trimmed: trimmed,
      responseLanguage: responseLanguage,
      rateLimitWindowCount: rateLimitWindowCount,
    );
  }
}

class AIChatTurnService {
  const AIChatTurnService();

  AIChatTurnValidationResult validateAndBuildContext({
    required String text,
    required AIChatState state,
    required String sessionId,
    required RecommendationMemory effectiveRecommendationMemory,
    required List<int> requestTimestampsMs,
    required bool Function(String message, AIChatIntent intent)
    shouldContinueAvailabilityClarification,
    required int maxUserMessageLength,
    required int maxRequestsPerWindow,
    required Duration rateLimitWindow,
    int? nowMs,
  }) {
    final trimmed = text.trim();
    final responseLanguage = AIChatLanguageDetector.detect(trimmed);
    if (trimmed.isEmpty || state.status == AIChatStatus.loading) {
      return AIChatTurnValidationResult.rejected(
        rejection: AIChatTurnRejection.emptyOrLoading,
        trimmed: trimmed,
        responseLanguage: responseLanguage,
      );
    }

    final intent = LocalIntentParser.detectIntent(
      trimmed,
      hasRecommendationContext:
          effectiveRecommendationMemory.lastRecommendedProducts.isNotEmpty,
    );
    final isModifierPatchMessage =
        LocalIntentParser.detectModifierPatch(trimmed) != null;
    final isContextResetMessage =
        LocalIntentParser.shouldResetConversationContext(trimmed);
    final isAvailabilityClarificationReply =
        state.availabilityContext.availabilityStatus ==
            AvailabilityStatus.ambiguous &&
        state.availabilityContext.externalCandidates.isNotEmpty;

    if (trimmed.length > maxUserMessageLength) {
      return AIChatTurnValidationResult.rejected(
        rejection: AIChatTurnRejection.tooLong,
        trimmed: trimmed,
        responseLanguage: responseLanguage,
      );
    }

    if (state.isInCooldown &&
        !isModifierPatchMessage &&
        !isContextResetMessage &&
        !isAvailabilityClarificationReply) {
      return AIChatTurnValidationResult.rejected(
        rejection: AIChatTurnRejection.cooldown,
        trimmed: trimmed,
        responseLanguage: responseLanguage,
      );
    }

    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    pruneRequestWindow(requestTimestampsMs, currentMs, rateLimitWindow);
    if (requestTimestampsMs.length >= maxRequestsPerWindow) {
      return AIChatTurnValidationResult.rejected(
        rejection: AIChatTurnRejection.rateLimit,
        trimmed: trimmed,
        responseLanguage: responseLanguage,
        rateLimitWindowCount: requestTimestampsMs.length,
      );
    }
    requestTimestampsMs.add(currentMs);

    return AIChatTurnValidationResult.accepted(
      AIChatTurnContext(
        trimmed: trimmed,
        activeSessionId: sessionId,
        responseLanguage: responseLanguage,
        effectiveRecommendationMemory: effectiveRecommendationMemory,
        intent: intent,
        shouldContinueAvailabilityClarification:
            shouldContinueAvailabilityClarification(trimmed, intent),
        isGreetingOnly:
            intent == AIChatIntent.newRecommendation &&
            LocalIntentParser.isGreetingOnly(trimmed),
        requestId: const Uuid().v4(),
      ),
    );
  }
}
