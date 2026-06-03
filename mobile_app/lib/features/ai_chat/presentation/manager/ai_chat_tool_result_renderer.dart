import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_no_match_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/final_recommendation_guard.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

typedef AIChatToolSuitabilityApplier =
    List<RecommendedProduct> Function(
      List<RecommendedProduct> products, {
      required SessionPreferences preferences,
      required bool hasExplicitBudget,
      required String sourcePath,
    });

class AIChatToolResultRenderer {
  const AIChatToolResultRenderer();

  bool render({
    required AIChatTurnContext incoming,
    required List<ProductModel> catalog,
    required AIChatToolExecutionResult result,
    required SessionPreferences fallbackPreferences,
    required AIChatReplyHandler replyHandler,
    required FinalRecommendationTranslator translate,
    required AIChatToolSuitabilityApplier applySuitabilityPolicy,
    required bool pruneHistoricalBotMessages,
  }) {
    final reply = result.reply;
    if (!result.handled || reply == null) {
      replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          fallbackPreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: result.reasonCode ?? 'tool_execution_failed',
        ),
        language: incoming.responseLanguage,
        source: result.source,
        updatedPreferences: fallbackPreferences,
        isNoMatch: true,
        issueCode: result.issueCode ?? 'tool_execution_failed',
        reasonCode: result.reasonCode ?? 'tool_execution_failed',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    if (reply.isAsk) {
      replyHandler.handleAskReply(
        reply,
        language: incoming.responseLanguage,
        source: result.source,
        issueCode: result.issueCode,
        reasonCode: result.reasonCode,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    if (reply.isAnswer) {
      replyHandler.handleAnswerReply(
        reply,
        language: incoming.responseLanguage,
        source: result.source,
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final guardResult = FinalRecommendationGuard(translate: translate).guard(
      reply: reply,
      catalog: catalog,
      recommendationContext: AIChatRecommendationContext(
        localCandidatesRefs: result.recommendations,
        candidatesList: result.recommendations
            .map((item) => item.product)
            .toList(growable: false),
        localFallbackAnswer: null,
        effectivePreferences: result.preferences,
      ),
      language: incoming.responseLanguage,
      responseSource: result.source,
    );
    final products = applySuitabilityPolicy(
      guardResult.safeProducts.isNotEmpty
          ? guardResult.safeProducts
          : guardResult.localRecoveryProducts,
      preferences: result.preferences,
      hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(
        incoming.trimmed,
      ),
      sourcePath: result.source,
    );

    if (products.isEmpty) {
      replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          result.preferences,
          catalog,
          incoming.responseLanguage,
          reasonCode:
              guardResult.reasonCode ??
              result.reasonCode ??
              'no_candidate_match',
        ),
        language: incoming.responseLanguage,
        source: '${result.source}_no_match',
        updatedPreferences: result.preferences,
        isNoMatch: true,
        issueCode:
            guardResult.issueCode ?? result.issueCode ?? 'no_candidate_match',
        reasonCode:
            guardResult.reasonCode ?? result.reasonCode ?? 'no_candidate_match',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final renderSource =
        BudgetAmountParser.containsBudgetNumber(incoming.trimmed)
        ? '${result.source}_explicit_budget'
        : result.source;
    replyHandler.handleRecommendationReply(
      reply,
      products,
      language: incoming.responseLanguage,
      source: renderSource,
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }
}
