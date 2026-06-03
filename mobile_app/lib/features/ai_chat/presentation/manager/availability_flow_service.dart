import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_route_resolver.dart';

typedef AvailabilityPivotHandler =
    Future<bool> Function(
      AIChatTurnContext incoming, {
      required bool pruneHistoricalBotMessages,
    });

typedef AvailabilityFollowUpHandler =
    Future<void> Function({
      required String message,
      required AIChatLanguage language,
      required String sessionId,
    });

typedef AvailabilityDirectHandler =
    Future<void> Function({
      required String message,
      required AIChatLanguage language,
      required String sessionId,
    });

class AvailabilityFlowService {
  const AvailabilityFlowService();

  Future<bool> handleRoutes({
    required AvailabilityRouteResult routeResult,
    required AIChatTurnContext incoming,
    required bool pruneHistoricalBotMessages,
    required AvailabilityPivotHandler handleSimilarCheaperPivot,
    required AvailabilityFollowUpHandler handleFollowUp,
    required AvailabilityDirectHandler handleDirect,
  }) async {
    if (routeResult.shouldSkip) return false;

    for (final route in routeResult.routes) {
      switch (route) {
        case AvailabilityRoute.none:
          return false;
        case AvailabilityRoute.similarCheaperPivot:
          final handled = await handleSimilarCheaperPivot(
            incoming,
            pruneHistoricalBotMessages: pruneHistoricalBotMessages,
          );
          if (handled) return true;
        case AvailabilityRoute.followUp:
          await handleFollowUp(
            message: incoming.trimmed,
            language: incoming.responseLanguage,
            sessionId: incoming.activeSessionId,
          );
          return true;
        case AvailabilityRoute.direct:
        case AvailabilityRoute.clarification:
          await handleDirect(
            message: incoming.availabilityProductQuery ?? incoming.trimmed,
            language: incoming.responseLanguage,
            sessionId: incoming.activeSessionId,
          );
          return true;
      }
    }

    return false;
  }
}
