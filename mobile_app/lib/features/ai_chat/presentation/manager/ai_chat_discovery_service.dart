import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_slot_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatDiscoveryResult {
  final AIChatDiscoveryContext context;
  final bool shouldClearBaselinePreferences;
  final bool isVague;

  const AIChatDiscoveryResult({
    required this.context,
    required this.shouldClearBaselinePreferences,
    required this.isVague,
  });
}

class AIChatDiscoveryService {
  const AIChatDiscoveryService();

  AIChatDiscoveryResult resolve({
    required AIChatTurnContext incoming,
    required SessionPreferences currentPreferences,
    required String? lastAskQuestion,
  }) {
    final hasRecommendationContext = incoming
        .effectiveRecommendationMemory
        .lastRecommendedProducts
        .isNotEmpty;
    final isFollowUpOrCompare =
        (incoming.intent == AIChatIntent.followUpProduct &&
            hasRecommendationContext) ||
        incoming.intent == AIChatIntent.compareProducts;
    final shouldResetConversationContext =
        incoming.intent == AIChatIntent.newRecommendation &&
        (LocalIntentParser.shouldResetConversationContext(incoming.trimmed) ||
            _looksLikeFreshProfilePivot(
              incoming.trimmed,
              currentPreferences,
              hasRecommendationContext: hasRecommendationContext,
            ));

    final basePreferences = shouldResetConversationContext
        ? SessionPreferences.empty()
        : currentPreferences;
    final parsingBasePreferences = basePreferences.mergePatch(
      incoming.interpretationPreferences,
    );
    final effectiveHasRecommendationContext =
        hasRecommendationContext && !shouldResetConversationContext;
    final isBestMatchContinuation =
        _looksLikeBestMatchContinuationCommand(incoming.trimmed) &&
        incoming.intent == AIChatIntent.newRecommendation &&
        !shouldResetConversationContext &&
        currentPreferences.activeCriteriaCount >= 3;

    var localPreferences = isBestMatchContinuation
        ? parsingBasePreferences
        : isFollowUpOrCompare
        ? parsingBasePreferences
        : LocalIntentParser.parse(incoming.trimmed, parsingBasePreferences);
    if (shouldResetConversationContext &&
        LocalIntentParser.shouldResetConversationContext(incoming.trimmed) &&
        currentPreferences.activeCriteriaCount > 0) {
      localPreferences = currentPreferences.mergePatch(localPreferences);
    }
    final lastAskedSlot = lastAskQuestion == null
        ? null
        : inferAskedSlot(lastAskQuestion);
    final isOpenChoiceReply = LocalIntentParser.isOpenChoiceReply(
      incoming.trimmed,
    );
    final normalizedIncoming = AIChatTextNormalizer.normalizeForParsing(
      incoming.trimmed,
    );
    final isOpenBudgetClearCommand =
        LocalIntentParser.isOpenBudgetClearCommand(incoming.trimmed) ||
        (incoming.trimmed.contains('ميزاني') &&
            incoming.trimmed.contains('مفت'));
    if (!isFollowUpOrCompare &&
        isOpenChoiceReply &&
        lastAskedSlot == 'season' &&
        localPreferences.season == null) {
      localPreferences = localPreferences.copyWith(season: 'all_seasons');
    }
    if (!isFollowUpOrCompare &&
        (isOpenBudgetClearCommand ||
            (incoming.trimmed.contains(
                  '\u0429\u2026\u0429\u0409\u0428\u0406\u0428\u00A7\u0429\u2020\u0429\u0409',
                ) &&
                incoming.trimmed.contains(
                  '\u0429\u2026\u0429\u0403\u0428\u0404',
                )) ||
            (incoming.trimmed.codeUnits.contains(1033) &&
                incoming.trimmed.codeUnits.contains(1027)) ||
            (normalizedIncoming.contains('ميزاني') &&
                normalizedIncoming.contains('مفت')) ||
            (isOpenChoiceReply && lastAskedSlot == 'maxBudget'))) {
      localPreferences = localPreferences.copyWith(
        clearBudget: true,
        tags: {...localPreferences.tags, 'open_budget'}.toList(),
      );
    }
    if (!isFollowUpOrCompare &&
        LocalIntentParser.isRelaxExcludedNotesCommand(incoming.trimmed)) {
      localPreferences = localPreferences.copyWith(excludedNotes: const []);
    }

    final localMissingSlots = localPreferences.missingSlotsForNextQuestion(
      hasRecommendationContext: effectiveHasRecommendationContext,
    );
    final budgetPolicy = LocalIntentParser.detectBudgetPolicy(incoming.trimmed);
    final readinessReason = _readinessReason(
      localPreferences,
      hasRecommendationContext: effectiveHasRecommendationContext,
    );
    final localReadyForRecommendation =
        !localPreferences.shouldAskBudgetBeforeInitialRecommendation &&
        !_hasMissingFoundationalDiscoverySlots(
          localPreferences,
          hasRecommendationContext: effectiveHasRecommendationContext,
        ) &&
        readinessReason != null;

    return AIChatDiscoveryResult(
      context: AIChatDiscoveryContext(
        hasRecommendationContext: hasRecommendationContext,
        effectiveHasRecommendationContext: effectiveHasRecommendationContext,
        isFollowUpOrCompare: isFollowUpOrCompare,
        shouldPruneBotHistory: shouldResetConversationContext,
        localPreferences: localPreferences,
        localMissingSlots: localMissingSlots,
        localReadyForRecommendation: localReadyForRecommendation,
        readinessReason: localReadyForRecommendation ? readinessReason : null,
        budgetPolicy: budgetPolicy,
      ),
      shouldClearBaselinePreferences: shouldResetConversationContext,
      isVague: LocalIntentParser.isVague(incoming.trimmed),
    );
  }

  bool _looksLikeBestMatchContinuationCommand(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (!AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return false;
    }

    // Budget modifiers such as "actually make it under 800" must still be
    // parsed as patches. Treat only low-content "best/recommend one" commands
    // as a request to use the accumulated profile unchanged.
    return normalized.contains('best match') ||
        normalized.contains('best option') ||
        normalized.contains('best recommendation') ||
        normalized.contains('show me the best') ||
        normalized.contains('give me the best') ||
        normalized.contains('give me your best') ||
        normalized.contains('give me best') ||
        normalized.contains('recommend one') ||
        normalized.contains('افضل اختيار') ||
        normalized.contains('أفضل اختيار') ||
        normalized.contains('رشحلي افضل') ||
        normalized.contains('رشحلي أفضل') ||
        normalized.contains('رشح افضل') ||
        normalized.contains('رشح أفضل') ||
        normalized.contains('اقترح افضل') ||
        normalized.contains('اقترح أفضل');
  }

  bool _looksLikeFreshProfilePivot(
    String message,
    SessionPreferences currentPreferences, {
    required bool hasRecommendationContext,
  }) {
    if (!hasRecommendationContext) return false;
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return false;
    }

    final freshPreferences = LocalIntentParser.parse(
      message,
      SessionPreferences.empty(),
    );
    final hasNewBudget =
        freshPreferences.maxBudget != null &&
        freshPreferences.maxBudget != currentPreferences.maxBudget;
    if (!hasNewBudget) return false;

    final hasNewAudience =
        freshPreferences.gender != null &&
        freshPreferences.gender != currentPreferences.gender;
    final hasGiftCue =
        normalized.contains('gift') ||
        normalized.contains('\u0647\u062f\u064a\u0629') ||
        normalized.contains('\u0647\u062f\u064a\u0647');
    return hasNewAudience || hasGiftCue;
  }

  bool _hasMissingFoundationalDiscoverySlots(
    SessionPreferences preferences, {
    required bool hasRecommendationContext,
  }) {
    if (hasRecommendationContext) return false;
    if (preferences.canRecommendPracticalInitial) return false;
    return preferences.gender == null || preferences.season == null;
  }

  String? _readinessReason(
    SessionPreferences preferences, {
    required bool hasRecommendationContext,
  }) {
    if (preferences.canRecommendPracticalInitial) {
      return 'practical_initial';
    }
    if (preferences.canRefineExistingRecommendation(
      hasRecommendationContext: hasRecommendationContext,
    )) {
      return 'refine_existing';
    }
    if (preferences.canRecommendInitial) {
      return 'initial';
    }
    return null;
  }
}
