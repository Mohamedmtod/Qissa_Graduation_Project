import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_worker_first_experiment.dart';

AIChatTurnContext _turn(String message) {
  return AIChatTurnContext(
    trimmed: message,
    activeSessionId: 'session',
    responseLanguage: AIChatLanguage.arabic,
    effectiveRecommendationMemory: const RecommendationMemory(),
    intent: AIChatIntent.newRecommendation,
    shouldContinueAvailabilityClarification: false,
    isGreetingOnly: false,
    requestId: 'request',
  );
}

AIChatDiscoveryContext _discovery({
  required SessionPreferences preferences,
  bool ready = false,
  List<String> missingSlots = const [
    'gender',
    'season',
    'maxBudget',
    'notesOrIntensity',
  ],
}) {
  return AIChatDiscoveryContext(
    hasRecommendationContext: false,
    effectiveHasRecommendationContext: false,
    isFollowUpOrCompare: false,
    shouldPruneBotHistory: false,
    localPreferences: preferences,
    localMissingSlots: missingSlots,
    localReadyForRecommendation: ready,
    readinessReason: 'practical_initial',
    budgetPolicy: AIChatBudgetPolicy.flexible,
  );
}

void main() {
  test('asks for scent anchor when request has no meaningful scent signal', () {
    final resolver = const AIChatWorkerFirstExperimentResolver();
    final result = resolver.resolve(
      incoming: _turn('عطر بريحة البطيخ والسمك'),
      discovery: _discovery(preferences: const SessionPreferences()),
      catalog: const [],
      currentPreferences: const SessionPreferences(),
    );

    expect(result.handledResult, isNotNull);
    expect(result.handledResult.reply?.question, contains('نوتات'));
    expect(result.handledResult.reply?.question, isNot(contains('رجالي')));
    expect(
      result.trace.finalGuardDecision,
      'worker_first_missing_scent_anchor',
    );
  });
}
