import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatRetargetProofDecision {
  const AIChatRetargetProofDecision.allowed(this.proofSource)
    : allowed = true,
      blockedReason = null;

  const AIChatRetargetProofDecision.blocked(this.blockedReason)
    : allowed = false,
      proofSource = null;

  final bool allowed;
  final String? proofSource;
  final String? blockedReason;
}

class AIChatRetargetProofGate {
  const AIChatRetargetProofGate();

  static const String noProofReason = 'no_perfume_intent_proof';

  AIChatRetargetProofDecision evaluate({
    required AIChatTurnContext incoming,
    required AIChatDiscoveryContext discovery,
    String? semanticIntent,
    String? workerIntent,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (normalized.isEmpty) {
      return const AIChatRetargetProofDecision.blocked(noProofReason);
    }

    if (incoming.shouldContinueAvailabilityClarification) {
      return const AIChatRetargetProofDecision.allowed(
        'pending_clarification_context',
      );
    }

    if (incoming.availabilityProductQuery?.trim().isNotEmpty == true) {
      return const AIChatRetargetProofDecision.allowed(
        'product_availability_context',
      );
    }

    if (discovery.effectiveHasRecommendationContext ||
        discovery.isFollowUpOrCompare ||
        incoming.effectiveRecommendationMemory.lastFocusedProductId != null ||
        incoming
            .effectiveRecommendationMemory
            .lastRecommendedProducts
            .isNotEmpty) {
      return const AIChatRetargetProofDecision.allowed(
        'recommendation_context',
      );
    }

    final intent = (semanticIntent ?? workerIntent ?? '').trim().toLowerCase();
    if (const {
      'recommendation',
      'recommend',
      'product_availability',
      'availability',
      'note_search',
      'vibe_search',
      'external_reference',
      'recommendation_refinement',
    }.contains(intent)) {
      return AIChatRetargetProofDecision.allowed('semantic_intent_$intent');
    }

    if (_looksLikeExternalReference(normalized)) {
      return const AIChatRetargetProofDecision.allowed(
        'external_perfume_reference',
      );
    }

    if (_looksLikeSensitiveChoice(normalized)) {
      return const AIChatRetargetProofDecision.allowed(
        'sensitive_skin_choice',
      );
    }

    if (LocalIntentParser.looksLikePerfumeRequest(
      incoming.trimmed,
      currentPreferences: discovery.localPreferences,
    )) {
      return const AIChatRetargetProofDecision.allowed(
        'explicit_perfume_request',
      );
    }

    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return const AIChatRetargetProofDecision.allowed(
        'recommendation_command',
      );
    }

    return const AIChatRetargetProofDecision.blocked(noProofReason);
  }

  bool _looksLikeExternalReference(String normalized) {
    if (normalized.contains('something like ') ||
        normalized.contains('similar to ') ||
        normalized.contains('like dior') ||
        normalized.contains('dior sauvage') ||
        normalized.contains('bleu de chanel') ||
        normalized.contains('creed aventus') ||
        normalized.contains('baccarat rouge')) {
      return true;
    }
    return normalized.contains('زي ') || normalized.contains('شبه ');
  }

  bool _looksLikeSensitiveChoice(String normalized) {
    final hasSensitiveCue =
        normalized.contains('sensitive skin') ||
        normalized.contains('skin sensitive') ||
        normalized.contains('\u0628\u0634\u0631\u062a\u064a \u062d\u0633\u0627\u0633\u0629') ||
        normalized.contains('\u0628\u0634\u0631\u0629 \u062d\u0633\u0627\u0633\u0629') ||
        normalized.contains('\u062d\u0633\u0627\u0633\u064a\u0629') ||
        normalized.contains('\u062d\u0633\u0627\u0633');
    if (!hasSensitiveCue) return false;
    return normalized.contains('choose') ||
        normalized.contains('pick') ||
        normalized.contains('recommend') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0631\u0634\u062d');
  }
}
