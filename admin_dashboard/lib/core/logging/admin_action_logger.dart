import 'dart:developer' as developer;

import 'package:perfume_app_admin_dashboard/core/config/app_config.dart';

class AdminActionLogger {
  const AdminActionLogger(this._config);

  final AppConfig _config;

  void debug(String message, {Map<String, Object?> context = const {}}) {
    _log(
      level: AppLogLevel.debug,
      event: 'debug',
      message: message,
      context: context,
    );
  }

  void info(String message, {Map<String, Object?> context = const {}}) {
    _log(
      level: AppLogLevel.info,
      event: 'info',
      message: message,
      context: context,
    );
  }

  void warning(String message, {Map<String, Object?> context = const {}}) {
    _log(
      level: AppLogLevel.warning,
      event: 'warning',
      message: message,
      context: context,
    );
  }

  void error(String message, {Map<String, Object?> context = const {}}) {
    _log(
      level: AppLogLevel.error,
      event: 'error',
      message: message,
      context: context,
    );
  }

  bool _isEnabledFor(AppLogLevel level) {
    return _config.logLevel.index >= level.index;
  }

  void _log({
    required AppLogLevel level,
    required String event,
    required String message,
    required Map<String, Object?> context,
  }) {
    if (!_isEnabledFor(level)) {
      return;
    }
    final serializedContext = context.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final suffix = serializedContext.isEmpty ? '' : ' | $serializedContext';
    developer.log(
      '[admin][$event] $message$suffix',
      name: 'perfume_app_admin_dashboard',
      level: _developerLevel(level),
    );
  }
}

int _developerLevel(AppLogLevel level) {
  return switch (level) {
    AppLogLevel.off => 0,
    AppLogLevel.error => 1000,
    AppLogLevel.warning => 900,
    AppLogLevel.info => 800,
    AppLogLevel.debug => 700,
  };
}
