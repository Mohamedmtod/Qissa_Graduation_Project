import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';

void main() {
  group('AIChatExperimentConfig runtime defaults', () {
    tearDown(AIChatExperimentConfig.resetTestOverrides);

    test('defaults enable guarded tool router paths', () {
      const expectedLlmLedRouterV2 = bool.fromEnvironment(
        'AI_CHAT_LLM_LED_ROUTER_V2',
        defaultValue: false,
      );
      AIChatExperimentConfig.resetTestOverrides();

      expect(AIChatExperimentConfig.toolRouterV1, isTrue);
      expect(AIChatExperimentConfig.useCatalogSearchEngine, isTrue);
      expect(AIChatExperimentConfig.useSuitabilityPolicy, isTrue);
      expect(AIChatExperimentConfig.catalogSearchShadow, isFalse);
      expect(AIChatExperimentConfig.traceRemoteSinkEnabled, isFalse);
      expect(AIChatExperimentConfig.turnDebugRemoteEnabled, isTrue);
      expect(AIChatExperimentConfig.debugCaptureMode, 'all');
      expect(AIChatExperimentConfig.deterministicGateShadowEnabled, isFalse);
      expect(AIChatExperimentConfig.deterministicGateV1, isTrue);
      expect(AIChatExperimentConfig.llmLedRouterV2, expectedLlmLedRouterV2);
    });

    test('test overrides remain explicit and resettable', () {
      const expectedLlmLedRouterV2 = bool.fromEnvironment(
        'AI_CHAT_LLM_LED_ROUTER_V2',
        defaultValue: false,
      );
      AIChatExperimentConfig.setTestOverrides(
        toolRouterV1: true,
        useCatalogSearchEngine: true,
        useSuitabilityPolicy: true,
        catalogSearchShadow: true,
        traceRemoteSinkEnabled: true,
        turnDebugRemoteEnabled: true,
        debugCaptureMode: 'all',
        deterministicGateShadowEnabled: true,
        deterministicGateV1: true,
        llmLedRouterV2: true,
      );

      expect(AIChatExperimentConfig.toolRouterV1, isTrue);
      expect(AIChatExperimentConfig.useCatalogSearchEngine, isTrue);
      expect(AIChatExperimentConfig.useSuitabilityPolicy, isTrue);
      expect(AIChatExperimentConfig.catalogSearchShadow, isTrue);
      expect(AIChatExperimentConfig.traceRemoteSinkEnabled, isTrue);
      expect(AIChatExperimentConfig.turnDebugRemoteEnabled, isTrue);
      expect(AIChatExperimentConfig.debugCaptureMode, 'all');
      expect(AIChatExperimentConfig.deterministicGateShadowEnabled, isTrue);
      expect(AIChatExperimentConfig.deterministicGateV1, isTrue);
      expect(AIChatExperimentConfig.llmLedRouterV2, isTrue);

      AIChatExperimentConfig.resetTestOverrides();

      expect(AIChatExperimentConfig.toolRouterV1, isTrue);
      expect(AIChatExperimentConfig.useCatalogSearchEngine, isTrue);
      expect(AIChatExperimentConfig.useSuitabilityPolicy, isTrue);
      expect(AIChatExperimentConfig.catalogSearchShadow, isFalse);
      expect(AIChatExperimentConfig.traceRemoteSinkEnabled, isFalse);
      expect(AIChatExperimentConfig.turnDebugRemoteEnabled, isTrue);
      expect(AIChatExperimentConfig.debugCaptureMode, 'all');
      expect(AIChatExperimentConfig.deterministicGateShadowEnabled, isFalse);
      expect(AIChatExperimentConfig.deterministicGateV1, isTrue);
      expect(AIChatExperimentConfig.llmLedRouterV2, expectedLlmLedRouterV2);
    });
  });
}
