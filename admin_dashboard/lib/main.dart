import 'package:flutter/foundation.dart';
import 'package:perfume_app_admin_dashboard/bootstrap.dart';
import 'package:perfume_app_admin_dashboard/core/config/app_flavor.dart';

void main() {
  const flavorValue = String.fromEnvironment('APP_FLAVOR', defaultValue: '');
  final resolvedFlavor = flavorValue.trim().isNotEmpty
      ? flavorValue
      : kReleaseMode
      ? 'production'
      : 'dev';
  bootstrap(AppFlavor.fromValue(resolvedFlavor));
}
