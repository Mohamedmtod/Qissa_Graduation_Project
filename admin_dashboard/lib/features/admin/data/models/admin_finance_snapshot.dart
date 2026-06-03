import 'package:equatable/equatable.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

class AdminFinanceSnapshot extends Equatable {
  const AdminFinanceSnapshot({
    required this.projection,
    required this.ratios,
    required this.initialServerCosts,
    required this.initialOperatingCosts,
    required this.initialAverageOrderValue,
    required this.initialGrossMargin,
  });

  final List<FinancePoint> projection;
  final List<FinanceRatio> ratios;
  final double initialServerCosts;
  final double initialOperatingCosts;
  final double initialAverageOrderValue;
  final double initialGrossMargin;

  @override
  List<Object?> get props => [
    projection,
    ratios,
    initialServerCosts,
    initialOperatingCosts,
    initialAverageOrderValue,
    initialGrossMargin,
  ];
}
