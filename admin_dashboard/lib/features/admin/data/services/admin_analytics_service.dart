import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_finance_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/business_config_model.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

abstract class AdminAnalyticsService {
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot();

  Future<AdminFinanceSnapshot> fetchFinanceSnapshot();
  Future<BusinessConfigModel> fetchBusinessConfig();
  Future<void> saveBusinessConfig(BusinessConfigModel config);
}

void validateBusinessConfig(BusinessConfigModel config) {
  const maxCostValue = 10000000.0;
  final values = <String, double>{
    'serverCosts': config.serverCosts,
    'manufacturingCosts': config.manufacturingCosts,
    'otherFixedCosts': config.otherFixedCosts,
  };

  for (final entry in values.entries) {
    final value = entry.value;
    if (!value.isFinite || value < 0 || value > maxCostValue) {
      throw AdminPolicyViolationException(
        'Business config ${entry.key} must be a finite value between 0 and $maxCostValue.',
      );
    }
  }
}
