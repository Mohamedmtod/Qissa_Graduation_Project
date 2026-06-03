import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_executor.dart';

class AIChatModifierResolution {
  final ModifierPatch? modifierPatch;
  final SessionPreferences? modifiedPreferences;
  final SessionPreferences? updatedBaselinePreferences;

  bool get shouldHandle => modifierPatch != null && modifiedPreferences != null;

  const AIChatModifierResolution.notHandled()
    : modifierPatch = null,
      modifiedPreferences = null,
      updatedBaselinePreferences = null;

  const AIChatModifierResolution.handled({
    required this.modifierPatch,
    required this.modifiedPreferences,
    required this.updatedBaselinePreferences,
  });
}

class AIChatModifierService {
  const AIChatModifierService();

  AIChatModifierResolution resolve({
    required String message,
    required SessionPreferences currentPreferences,
    required AIChatDiscoveryContext discovery,
    required SessionPreferences? baselinePreferences,
    required bool hasNoteSignalDelta,
  }) {
    if (discovery.isFollowUpOrCompare) {
      return const AIChatModifierResolution.notHandled();
    }
    if (AvailabilityIntentUtils.looksLikePersonaOrPreferenceStatement(
      message,
    )) {
      return const AIChatModifierResolution.notHandled();
    }

    final modifierPatch = LocalIntentParser.detectModifierPatch(message);
    final hasSessionContext =
        currentPreferences.activeCriteriaCount > 0 ||
        discovery.hasRecommendationContext;
    if (modifierPatch == null || !hasSessionContext) {
      return const AIChatModifierResolution.notHandled();
    }

    if (hasNoteSignalDelta) {
      return const AIChatModifierResolution.notHandled();
    }

    if (modifierPatch.type == ModifierPatchType.revert) {
      return AIChatModifierResolution.handled(
        modifierPatch: modifierPatch,
        modifiedPreferences: baselinePreferences ?? currentPreferences,
        updatedBaselinePreferences: null,
      );
    }
    final hasExplicitBudgetNumber = BudgetAmountParser.containsBudgetNumber(
      LocalIntentParser.normalizeInput(message),
    );
    if (modifierPatch.type == ModifierPatchType.cheaper &&
        hasExplicitBudgetNumber) {
      return const AIChatModifierResolution.notHandled();
    }

    final patch = PreferencePatch();
    switch (modifierPatch.type) {
      case ModifierPatchType.stronger:
        patch.setScalar(PreferenceScalar.intensity, 'strong');
        break;
      case ModifierPatchType.lighter:
        patch.setScalar(PreferenceScalar.intensity, 'light');
        break;
      case ModifierPatchType.cheaper:
        final currentBudget = discovery.localPreferences.maxBudget;
        patch.setScalar(
          PreferenceScalar.maxBudget,
          currentBudget != null ? (currentBudget * 0.85) : 1200,
        );
        break;
      case ModifierPatchType.sweeter:
        patch.appendList(PreferenceListField.tags, const ['sweet']);
        break;
      case ModifierPatchType.revert:
        break;
    }

    final mutation = const PreferenceMutationExecutor().applyPatch(
      current: discovery.localPreferences,
      patch: patch,
      source: 'local_modifier_${modifierPatch.type.name}',
    );

    return AIChatModifierResolution.handled(
      modifierPatch: modifierPatch,
      modifiedPreferences: mutation.preferences,
      updatedBaselinePreferences: baselinePreferences ?? currentPreferences,
    );
  }
}
