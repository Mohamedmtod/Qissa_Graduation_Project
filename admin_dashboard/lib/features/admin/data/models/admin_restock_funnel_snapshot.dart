import 'package:equatable/equatable.dart';

class AdminRestockFunnelSnapshot extends Equatable {
  const AdminRestockFunnelSnapshot({
    required this.totalNotifyRequests,
    required this.totalNotificationsSent,
    required this.totalRestockConversions,
    required this.averageTimeToConversionHours,
    required this.repeatRestockPurchaseRatePercent,
    required this.restockRevenueContributionPercent,
  });

  final int totalNotifyRequests;
  final int totalNotificationsSent;
  final int totalRestockConversions;
  final double averageTimeToConversionHours;
  final double repeatRestockPurchaseRatePercent;
  final double restockRevenueContributionPercent;

  double get restockConversionRate {
    if (totalNotificationsSent <= 0) {
      return 0.0;
    }
    return (totalRestockConversions / totalNotificationsSent) * 100;
  }

  @override
  List<Object?> get props => [
    totalNotifyRequests,
    totalNotificationsSent,
    totalRestockConversions,
    averageTimeToConversionHours,
    repeatRestockPurchaseRatePercent,
    restockRevenueContributionPercent,
    restockConversionRate,
  ];
}
