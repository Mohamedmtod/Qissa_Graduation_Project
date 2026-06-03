import 'package:firebase_core/firebase_core.dart';

import 'package:perfume_app_admin_dashboard/core/config/app_flavor.dart';
import 'package:perfume_app_admin_dashboard/firebase_options.dart';

enum AppLogLevel { off, error, warning, info, debug }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.ordersWorkerBaseUrl,
    required this.aiChatWorkerBaseUrl,
    required this.workerApiKey,
    required this.useWorkerOrderTransitions,
    required this.logLevel,
    required this.firebaseOptions,
  });

  final AppFlavor flavor;
  final String appName;
  final String apiBaseUrl;
  final String ordersWorkerBaseUrl;
  final String aiChatWorkerBaseUrl;
  final String workerApiKey;
  final bool useWorkerOrderTransitions;
  final AppLogLevel logLevel;
  final FirebaseOptions firebaseOptions;

  bool get enableLogging => logLevel != AppLogLevel.off;
  bool get showFlavorBanner => !flavor.isProduction;

  static AppConfig forFlavor(AppFlavor flavor) {
    const apiBaseUrlOverride = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    const ordersWorkerBaseUrlOverride = String.fromEnvironment(
      'ORDERS_WORKER_BASE_URL',
      defaultValue: '',
    );
    const aiChatWorkerBaseUrlOverride = String.fromEnvironment(
      'AI_CHAT_WORKER_BASE_URL',
      defaultValue: '',
    );
    const workerApiKey = String.fromEnvironment('WORKER_API_KEY');
    const useWorkerTransitionsOverride = String.fromEnvironment(
      'ADMIN_USE_WORKER_ORDER_TRANSITIONS',
      defaultValue: '',
    );
    const adminLogLevelOverride = String.fromEnvironment(
      'ADMIN_LOG_LEVEL',
      defaultValue: '',
    );

    final defaultApiBaseUrl = switch (flavor) {
      AppFlavor.dev => 'https://dev-api.perfume-app.local',
      AppFlavor.staging => 'https://staging-api.perfume-app.local',
      AppFlavor.production => 'https://api.perfume-app.local',
    };
    final defaultOrdersWorkerBaseUrl = switch (flavor) {
      AppFlavor.dev =>
        'https://perfume-orders-worker.qessa-prefume.workers.dev',
      AppFlavor.staging => 'https://staging-orders-worker.perfume-app.local',
      AppFlavor.production => 'https://orders-worker.perfume-app.com',
    };
    final defaultAiChatWorkerBaseUrl = switch (flavor) {
      AppFlavor.dev => 'https://dev-ai-worker.perfume-app.local',
      AppFlavor.staging => 'https://staging-ai-worker.perfume-app.local',
      AppFlavor.production => 'https://ai-worker.perfume-app.com',
    };

    final defaultLogLevel = flavor == AppFlavor.production
        ? AppLogLevel.warning
        : AppLogLevel.debug;
    final defaultUseWorkerTransitions = true;
    final parsedLogLevel = _parseLogLevel(adminLogLevelOverride);
    final logLevel = switch (parsedLogLevel) {
      null => defaultLogLevel,
      final value => value,
    };

    return AppConfig(
      flavor: flavor,
      appName: switch (flavor) {
        AppFlavor.dev => 'Perfume Admin Dashboard [DEV]',
        AppFlavor.staging => 'Perfume Admin Dashboard [STAGING]',
        AppFlavor.production => 'Perfume Admin Dashboard',
      },
      apiBaseUrl: apiBaseUrlOverride.isNotEmpty
          ? _sanitizeUrl(apiBaseUrlOverride)
          : defaultApiBaseUrl,
      ordersWorkerBaseUrl: ordersWorkerBaseUrlOverride.isNotEmpty
          ? _sanitizeUrl(ordersWorkerBaseUrlOverride)
          : defaultOrdersWorkerBaseUrl,
      aiChatWorkerBaseUrl: aiChatWorkerBaseUrlOverride.isNotEmpty
          ? _sanitizeUrl(aiChatWorkerBaseUrlOverride)
          : defaultAiChatWorkerBaseUrl,
      workerApiKey: workerApiKey.trim(),
      useWorkerOrderTransitions: _parseBool(
        useWorkerTransitionsOverride,
        fallback: defaultUseWorkerTransitions,
      ),
      logLevel: logLevel,
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

AppLogLevel? _parseLogLevel(String value) {
  switch (value.toLowerCase().trim()) {
    case 'off':
      return AppLogLevel.off;
    case 'error':
      return AppLogLevel.error;
    case 'warn':
    case 'warning':
      return AppLogLevel.warning;
    case 'info':
      return AppLogLevel.info;
    case 'debug':
      return AppLogLevel.debug;
    default:
      return null;
  }
}

String _sanitizeUrl(String value) {
  return value.trim().replaceFirst(RegExp(r'/$'), '');
}

bool _parseBool(String raw, {required bool fallback}) {
  switch (raw.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return fallback;
  }
}
