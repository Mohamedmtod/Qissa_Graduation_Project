import 'package:flutter/foundation.dart';

class AIChatExperimentConfig {
  static const String aiModeTelemetryValue = 'worker_first_experiment';

  static const bool _sendCompactContextFromEnvironment = bool.fromEnvironment(
    'AI_CHAT_SEND_COMPACT_CONTEXT',
    defaultValue: true,
  );

  static const bool _delegateMicroTurnsFromEnvironment = bool.fromEnvironment(
    'AI_CHAT_DELEGATE_MICRO_TURNS',
    defaultValue: true,
  );

  static const bool _useSuitabilityPolicyFromEnvironment = bool.fromEnvironment(
    'AI_CHAT_USE_SUITABILITY_POLICY',
    defaultValue: !kReleaseMode,
  );

  static const bool _useCatalogSearchEngineFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_USE_CATALOG_SEARCH_ENGINE',
        defaultValue: !kReleaseMode,
      );

  static const bool _catalogSearchShadowFromEnvironment = bool.fromEnvironment(
    'AI_CHAT_CATALOG_SEARCH_SHADOW',
    defaultValue: false,
  );

  static const bool _toolRouterV1FromEnvironment = bool.fromEnvironment(
    'AI_CHAT_TOOL_ROUTER_V1',
    defaultValue: true,
  );

  static const bool _staffTasteScoringEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_STAFF_TASTE_SCORING_ENABLED',
        defaultValue: true,
      );

  static final double _staffTasteWeightFromEnvironment =
      double.tryParse(
        const String.fromEnvironment(
          'AI_CHAT_STAFF_TASTE_WEIGHT',
          defaultValue: '0.10',
        ),
      ) ??
      0.10;

  static const bool _analyticsEventsEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_ANALYTICS_EVENTS_ENABLED',
        defaultValue: true,
      );

  static const bool _analyticsDebugSinkEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_ANALYTICS_DEBUG_SINK_ENABLED',
        defaultValue: !kReleaseMode,
      );

  static const bool _analyticsRemoteSinkEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_ANALYTICS_REMOTE_SINK_ENABLED',
        defaultValue: false,
      );

  static const bool _traceRemoteSinkEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_TRACE_REMOTE_SINK_ENABLED',
        defaultValue: false,
      );

  static const bool _turnDebugRemoteEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_TURN_DEBUG_REMOTE_ENABLED',
        defaultValue: true,
      );

  static const String _debugCaptureModeFromEnvironment = String.fromEnvironment(
    'AI_CHAT_DEBUG_CAPTURE_MODE',
    defaultValue: 'all',
  );

  static const bool _deterministicGateShadowEnabledFromEnvironment =
      bool.fromEnvironment(
        'AI_CHAT_DETERMINISTIC_GATE_SHADOW_ENABLED',
        defaultValue: false,
      );

  static const bool _deterministicGateV1FromEnvironment = bool.fromEnvironment(
    'AI_CHAT_DETERMINISTIC_GATE_V1',
    defaultValue: true,
  );

  static const bool _llmLedRouterV2FromEnvironment = bool.fromEnvironment(
    'AI_CHAT_LLM_LED_ROUTER_V2',
    defaultValue: false,
  );

  static bool? _sendCompactContextOverride;
  static bool? _delegateMicroTurnsOverride;
  static bool? _useSuitabilityPolicyOverride;
  static bool? _useCatalogSearchEngineOverride;
  static bool? _catalogSearchShadowOverride;
  static bool? _toolRouterV1Override;
  static bool? _staffTasteScoringEnabledOverride;
  static double? _staffTasteWeightOverride;
  static bool? _analyticsEventsEnabledOverride;
  static bool? _analyticsDebugSinkEnabledOverride;
  static bool? _analyticsRemoteSinkEnabledOverride;
  static bool? _traceRemoteSinkEnabledOverride;
  static bool? _turnDebugRemoteEnabledOverride;
  static String? _debugCaptureModeOverride;
  static bool? _deterministicGateShadowEnabledOverride;
  static bool? _deterministicGateV1Override;
  static bool? _llmLedRouterV2Override;

  static bool get sendCompactContext =>
      _sendCompactContextOverride ?? _sendCompactContextFromEnvironment;

  static bool get delegateMicroTurns =>
      _delegateMicroTurnsOverride ?? _delegateMicroTurnsFromEnvironment;

  static bool get useSuitabilityPolicy =>
      _useSuitabilityPolicyOverride ?? _useSuitabilityPolicyFromEnvironment;

  static bool get useCatalogSearchEngine =>
      _useCatalogSearchEngineOverride ?? _useCatalogSearchEngineFromEnvironment;

  static bool get catalogSearchShadow =>
      _catalogSearchShadowOverride ?? _catalogSearchShadowFromEnvironment;

  static bool get toolRouterV1 =>
      _toolRouterV1Override ?? _toolRouterV1FromEnvironment;

  static bool get staffTasteScoringEnabled =>
      _staffTasteScoringEnabledOverride ??
      _staffTasteScoringEnabledFromEnvironment;

  static double get staffTasteWeight =>
      (_staffTasteWeightOverride ?? _staffTasteWeightFromEnvironment).clamp(
        0.0,
        0.25,
      );

  static bool get analyticsEventsEnabled =>
      _analyticsEventsEnabledOverride ?? _analyticsEventsEnabledFromEnvironment;

  static bool get analyticsDebugSinkEnabled =>
      _analyticsDebugSinkEnabledOverride ??
      _analyticsDebugSinkEnabledFromEnvironment;

  static bool get analyticsRemoteSinkEnabled =>
      _analyticsRemoteSinkEnabledOverride ??
      _analyticsRemoteSinkEnabledFromEnvironment;

  static bool get traceRemoteSinkEnabled =>
      _traceRemoteSinkEnabledOverride ?? _traceRemoteSinkEnabledFromEnvironment;

  static bool get turnDebugRemoteEnabled =>
      _turnDebugRemoteEnabledOverride ?? _turnDebugRemoteEnabledFromEnvironment;

  static String get debugCaptureMode {
    final raw = (_debugCaptureModeOverride ?? _debugCaptureModeFromEnvironment)
        .trim()
        .toLowerCase();
    return switch (raw) {
      'all' => 'all',
      'feedback_only' => 'feedback_only',
      'sampled' => 'sampled',
      _ => 'off',
    };
  }

  static bool get deterministicGateShadowEnabled =>
      _deterministicGateShadowEnabledOverride ??
      _deterministicGateShadowEnabledFromEnvironment;

  static bool get deterministicGateV1 =>
      _deterministicGateV1Override ?? _deterministicGateV1FromEnvironment;

  static bool get llmLedRouterV2 =>
      _llmLedRouterV2Override ?? _llmLedRouterV2FromEnvironment;

  static void setTestOverrides({
    bool? sendCompactContext,
    bool? delegateMicroTurns,
    bool? useSuitabilityPolicy,
    bool? useCatalogSearchEngine,
    bool? catalogSearchShadow,
    bool? toolRouterV1,
    bool? staffTasteScoringEnabled,
    double? staffTasteWeight,
    bool? analyticsEventsEnabled,
    bool? analyticsDebugSinkEnabled,
    bool? analyticsRemoteSinkEnabled,
    bool? traceRemoteSinkEnabled,
    bool? turnDebugRemoteEnabled,
    String? debugCaptureMode,
    bool? deterministicGateShadowEnabled,
    bool? deterministicGateV1,
    bool? llmLedRouterV2,
  }) {
    _sendCompactContextOverride = sendCompactContext;
    _delegateMicroTurnsOverride = delegateMicroTurns;
    _useSuitabilityPolicyOverride = useSuitabilityPolicy;
    _useCatalogSearchEngineOverride = useCatalogSearchEngine;
    _catalogSearchShadowOverride = catalogSearchShadow;
    _toolRouterV1Override = toolRouterV1;
    _staffTasteScoringEnabledOverride = staffTasteScoringEnabled;
    _staffTasteWeightOverride = staffTasteWeight;
    _analyticsEventsEnabledOverride = analyticsEventsEnabled;
    _analyticsDebugSinkEnabledOverride = analyticsDebugSinkEnabled;
    _analyticsRemoteSinkEnabledOverride = analyticsRemoteSinkEnabled;
    _traceRemoteSinkEnabledOverride = traceRemoteSinkEnabled;
    _turnDebugRemoteEnabledOverride = turnDebugRemoteEnabled;
    _debugCaptureModeOverride = debugCaptureMode;
    _deterministicGateShadowEnabledOverride = deterministicGateShadowEnabled;
    _deterministicGateV1Override = deterministicGateV1;
    _llmLedRouterV2Override = llmLedRouterV2;
  }

  static void resetTestOverrides() {
    _sendCompactContextOverride = null;
    _delegateMicroTurnsOverride = null;
    _useSuitabilityPolicyOverride = null;
    _useCatalogSearchEngineOverride = null;
    _catalogSearchShadowOverride = null;
    _toolRouterV1Override = null;
    _staffTasteScoringEnabledOverride = null;
    _staffTasteWeightOverride = null;
    _analyticsEventsEnabledOverride = null;
    _analyticsDebugSinkEnabledOverride = null;
    _analyticsRemoteSinkEnabledOverride = null;
    _traceRemoteSinkEnabledOverride = null;
    _turnDebugRemoteEnabledOverride = null;
    _debugCaptureModeOverride = null;
    _deterministicGateShadowEnabledOverride = null;
    _deterministicGateV1Override = null;
    _llmLedRouterV2Override = null;
  }

  const AIChatExperimentConfig._();
}
