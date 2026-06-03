import 'package:equatable/equatable.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';

class AdminInventorySnapshot extends Equatable {
  const AdminInventorySnapshot({
    required this.items,
    required this.healthScore,
    required this.skuCount,
    required this.overstockCount,
    required this.aiPredictionMessage,
    required this.aiActionLabel,
  });

  final List<InventoryItem> items;
  final double healthScore;
  final int skuCount;
  final int overstockCount;
  final String aiPredictionMessage;
  final String aiActionLabel;

  @override
  List<Object?> get props => [
    items,
    healthScore,
    skuCount,
    overstockCount,
    aiPredictionMessage,
    aiActionLabel,
  ];
}
