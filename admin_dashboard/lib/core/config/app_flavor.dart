enum AppFlavor {
  dev,
  staging,
  production;

  String get name => switch (this) {
    AppFlavor.dev => 'dev',
    AppFlavor.staging => 'staging',
    AppFlavor.production => 'production',
  };

  String get displayName => switch (this) {
    AppFlavor.dev => 'DEV',
    AppFlavor.staging => 'STAGING',
    AppFlavor.production => 'PROD',
  };

  bool get isProduction => this == AppFlavor.production;

  static AppFlavor fromValue(String value) {
    return switch (value.toLowerCase()) {
      'dev' => AppFlavor.dev,
      'staging' => AppFlavor.staging,
      'production' || 'prod' => AppFlavor.production,
      _ => AppFlavor.dev,
    };
  }
}
