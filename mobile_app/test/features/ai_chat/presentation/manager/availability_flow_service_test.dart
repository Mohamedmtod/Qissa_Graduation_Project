import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_flow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_followup_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_route_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

AIChatTurnContext _incoming() {
  return const AIChatTurnContext(
    trimmed: 'do you have Sauvage?',
    activeSessionId: 'session',
    responseLanguage: AIChatLanguage.english,
    effectiveRecommendationMemory: RecommendationMemory(),
    intent: AIChatIntent.availabilityCheck,
    shouldContinueAvailabilityClarification: false,
    isGreetingOnly: false,
    requestId: 'request',
  );
}

AvailabilityRouteResult _route(AvailabilityRoute route, String reasonCode) {
  return AvailabilityRouteResult(
    decisions: [
      AvailabilityRouteDecision(route: route, reasonCode: reasonCode),
    ],
    followUpSignal: const AvailabilityFollowUpSignal(
      hasSimilarityTerm: false,
      hasCheaperTerm: false,
      hasContextRef: false,
      hasExplicitAvailabilityProduct: false,
    ),
  );
}

void main() {
  group('AvailabilityFlowService', () {
    const service = AvailabilityFlowService();

    test('returns false for none route', () async {
      final calls = <String>[];

      final handled = await service.handleRoutes(
        routeResult: _route(AvailabilityRoute.none, 'none'),
        incoming: _incoming(),
        pruneHistoricalBotMessages: false,
        handleSimilarCheaperPivot:
            (_, {required pruneHistoricalBotMessages}) async {
              calls.add('pivot');
              return true;
            },
        handleFollowUp:
            ({required message, required language, required sessionId}) async {
              calls.add('follow_up');
            },
        handleDirect:
            ({required message, required language, required sessionId}) async {
              calls.add('direct');
            },
      );

      expect(handled, isFalse);
      expect(calls, isEmpty);
    });

    test('routes direct and clarification to direct handler', () async {
      final calls = <String>[];

      for (final route in [
        AvailabilityRoute.direct,
        AvailabilityRoute.clarification,
      ]) {
        final handled = await service.handleRoutes(
          routeResult: _route(route, route.name),
          incoming: _incoming(),
          pruneHistoricalBotMessages: false,
          handleSimilarCheaperPivot:
              (_, {required pruneHistoricalBotMessages}) async => false,
          handleFollowUp:
              ({
                required message,
                required language,
                required sessionId,
              }) async {
                calls.add('follow_up');
              },
          handleDirect:
              ({
                required message,
                required language,
                required sessionId,
              }) async {
                calls.add('direct:${language.code}:$sessionId');
              },
        );

        expect(handled, isTrue);
      }

      expect(calls, ['direct:en:session', 'direct:en:session']);
    });

    test(
      'falls through pivot to follow-up when pivot declines handling',
      () async {
        final calls = <String>[];
        final handled = await service.handleRoutes(
          routeResult: const AvailabilityRouteResult(
            decisions: [
              AvailabilityRouteDecision(
                route: AvailabilityRoute.similarCheaperPivot,
                reasonCode: 'pivot',
              ),
              AvailabilityRouteDecision(
                route: AvailabilityRoute.followUp,
                reasonCode: 'follow_up',
              ),
            ],
            followUpSignal: AvailabilityFollowUpSignal(
              hasSimilarityTerm: false,
              hasCheaperTerm: false,
              hasContextRef: false,
              hasExplicitAvailabilityProduct: false,
            ),
          ),
          incoming: _incoming(),
          pruneHistoricalBotMessages: true,
          handleSimilarCheaperPivot:
              (_, {required pruneHistoricalBotMessages}) async {
                calls.add('pivot:$pruneHistoricalBotMessages');
                return false;
              },
          handleFollowUp:
              ({
                required message,
                required language,
                required sessionId,
              }) async {
                calls.add('follow_up:$message');
              },
          handleDirect:
              ({
                required message,
                required language,
                required sessionId,
              }) async {
                calls.add('direct');
              },
        );

        expect(handled, isTrue);
        expect(calls, ['pivot:true', 'follow_up:do you have Sauvage?']);
      },
    );
  });
}
