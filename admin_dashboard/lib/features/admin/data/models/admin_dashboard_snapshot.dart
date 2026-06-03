import 'package:equatable/equatable.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_funnel_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

class AdminDashboardSnapshot extends Equatable {
  const AdminDashboardSnapshot({
    required this.metrics,
    required this.salesTrend,
    required this.activityFeed,
    required this.inventorySnapshots,
    required this.restockFunnel,
    this.featuredComposition,
  });

  final List<DashboardMetric> metrics;
  final List<TrendPoint> salesTrend;
  final List<ActivityItem> activityFeed;
  final List<ProgressSnapshot> inventorySnapshots;
  final AdminRestockFunnelSnapshot restockFunnel;
  final AdminFeatureHighlight? featuredComposition;

  @override
  List<Object?> get props => [
    metrics,
    salesTrend,
    activityFeed,
    inventorySnapshots,
    restockFunnel,
    featuredComposition,
  ];
}
