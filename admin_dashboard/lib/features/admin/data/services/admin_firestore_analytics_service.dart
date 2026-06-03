import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_finance_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_restock_funnel_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/business_config_model.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_analytics_service.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';

class FirestoreAdminAnalyticsService implements AdminAnalyticsService {
  FirestoreAdminAnalyticsService({
    FirebaseFirestore? firestore,
    AdminObservabilityService? observability,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _realizedRevenueStatus = 'delivered';

  @override
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot() async {
    final now = DateTime.now();
    final orderSnapshot = await _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(1200)
        .get();
    final productSnapshot = await _firestore
        .collection('products')
        .limit(1200)
        .get();
    final pendingRestockSnapshot = await _firestore
        .collection('restock_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1500)
        .get();
    final notifiedRestockSnapshot = await _firestore
        .collection('restock_requests')
        .where('status', isEqualTo: 'notified')
        .limit(1500)
        .get();
    final convertedRestockSnapshot = await _firestore
        .collection('restock_requests')
        .where('status', isEqualTo: 'converted')
        .limit(1500)
        .get();
    final restockNotificationEvents = await _firestore
        .collection('events')
        .where('eventType', isEqualTo: 'restock_notified')
        .limit(1500)
        .get();
    final restockPurchaseEvents = await _firestore
        .collection('events')
        .where('eventType', isEqualTo: 'restock_purchased')
        .limit(1500)
        .get();

    final orders = orderSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    final products = productSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    final totalOrders = orders.length;
    final cancelledOrders = orders
        .where((order) => _status(order) == 'cancelled')
        .length;
    final cancellationRate = totalOrders > 0
        ? (cancelledOrders / totalOrders) * 100
        : 0.0;
    var totalDeliveredRevenue = 0.0;
    var restockDeliveredRevenue = 0.0;
    for (final order in orders) {
      if (_status(order) != _realizedRevenueStatus) {
        continue;
      }
      final total = _orderTotalMinor(order) / 100;
      totalDeliveredRevenue += total;
      final source = (order['orderSource'] ?? '').toString().trim();
      if (source == 'restock_alert') {
        restockDeliveredRevenue += total;
      }
    }
    final restockRevenueContributionPercent = totalDeliveredRevenue > 0
        ? (restockDeliveredRevenue / totalDeliveredRevenue) * 100
        : 0.0;

    final transitionDurationsHours = <double>[];
    for (final order in orders) {
      final duration = _extractTransitionDurationHours(order);
      if (duration != null && duration > 0) {
        transitionDurationsHours.add(duration);
      }
    }
    final averageTransitionHours = transitionDurationsHours.isEmpty
        ? 0.0
        : transitionDurationsHours.reduce((a, b) => a + b) /
              transitionDurationsHours.length;

    final totalProducts = products.length;
    final lowStockProducts = products.where((p) => _stockOf(p) < 10).toList();
    final outOfStockProducts = products.where((p) => _stockOf(p) <= 0).toList();
    final lowStockRatio = totalProducts > 0
        ? (lowStockProducts.length / totalProducts) * 100
        : 0.0;
    final healthyRatio = totalProducts > 0
        ? ((totalProducts - lowStockProducts.length) / totalProducts)
        : 1.0;

    final pendingByProduct = <String, int>{};
    final restockProductsByUser = <String, Set<String>>{};
    void collectRestockDemandByUser(Map<String, dynamic> data) {
      final userId = (data['userId'] ?? '').toString().trim();
      final productId = (data['productId'] ?? '').toString().trim();
      if (userId.isEmpty || productId.isEmpty) {
        return;
      }
      final productSet = restockProductsByUser.putIfAbsent(
        userId,
        () => <String>{},
      );
      productSet.add(productId);
    }

    for (final req in pendingRestockSnapshot.docs) {
      final data = req.data();
      final productId = (data['productId'] ?? '').toString();
      if (productId.isEmpty) continue;
      pendingByProduct[productId] = (pendingByProduct[productId] ?? 0) + 1;
      collectRestockDemandByUser(data);
    }
    for (final req in notifiedRestockSnapshot.docs) {
      final data = req.data();
      final productId = (data['productId'] ?? '').toString();
      if (productId.isEmpty) continue;
      pendingByProduct[productId] = (pendingByProduct[productId] ?? 0) + 1;
      collectRestockDemandByUser(data);
    }
    for (final req in convertedRestockSnapshot.docs) {
      final data = req.data();
      final productId = (data['productId'] ?? '').toString();
      if (productId.isEmpty) continue;
      pendingByProduct[productId] = (pendingByProduct[productId] ?? 0) + 1;
      collectRestockDemandByUser(data);
    }

    final restockRequesterUsers = restockProductsByUser.length;
    final repeatRestockUsers = restockProductsByUser.values
        .where((products) => products.length > 1)
        .length;
    final repeatRestockPurchaseRatePercent = restockRequesterUsers > 0
        ? (repeatRestockUsers / restockRequesterUsers) * 100
        : 0.0;

    final totalNotifyRequests =
        pendingRestockSnapshot.docs.length +
        notifiedRestockSnapshot.docs.length +
        convertedRestockSnapshot.docs.length;
    final totalNotificationsSent = restockNotificationEvents.docs.fold<int>(0, (
      total,
      doc,
    ) {
      final data = doc.data()['data'];
      if (data is Map<String, dynamic>) {
        final count = data['usersNotifiedCount'];
        return total + _asInt(count);
      }
      return total;
    });
    final totalRestockConversions = restockPurchaseEvents.docs.length;
    final conversionDurations = <double>[];
    for (final doc in convertedRestockSnapshot.docs) {
      final data = doc.data();
      final notifiedAt = _timestampOrNull(data['notifiedAt'])?.toDate();
      final convertedAt = _timestampOrNull(data['convertedAt'])?.toDate();
      if (notifiedAt == null || convertedAt == null) continue;
      final diffHours = convertedAt.difference(notifiedAt).inMinutes / 60.0;
      if (diffHours >= 0) {
        conversionDurations.add(diffHours);
      }
    }
    final averageTimeToConversionHours = conversionDurations.isEmpty
        ? 0.0
        : conversionDurations.reduce((a, b) => a + b) /
              conversionDurations.length;

    products.sort((a, b) {
      final restockA = pendingByProduct[(a['id'] ?? '').toString()] ?? 0;
      final restockB = pendingByProduct[(b['id'] ?? '').toString()] ?? 0;
      if (restockA != restockB) return restockB.compareTo(restockA);
      return _stockOf(a).compareTo(_stockOf(b));
    });

    final mostDepleted = products.isNotEmpty ? products.first : null;
    final mostDepletedName = _truncate(
      (_nameOf(mostDepleted) ?? 'N/A'),
      max: 22,
    );
    final mostDepletedRestockDemand = mostDepleted == null
        ? 0
        : (pendingByProduct[(mostDepleted['id'] ?? '').toString()] ?? 0);

    final metrics = <DashboardMetric>[
      DashboardMetric(
        icon: Icons.cancel_outlined,
        highlight: 'analytics.sampledOrdersHighlight',
        title: 'analytics.cancellationRate',
        value: '${cancellationRate.toStringAsFixed(1)}%',
        iconTint: const Color(0xFF9B1B1B),
        iconBackground: const Color(0xFFFDE2E1),
      ),
      DashboardMetric(
        icon: Icons.timer_outlined,
        highlight: 'analytics.sampledTransitionHighlight',
        title: 'analytics.transitionTime',
        value: '${averageTransitionHours.toStringAsFixed(1)}h',
        iconTint: const Color(0xFF155E99),
        iconBackground: const Color(0xFFEAF4FF),
      ),
      DashboardMetric(
        icon: Icons.inventory_2_outlined,
        highlight: AdminLocaleController.globalT(
          'analytics.mostDepletedHighlight',
          params: {'demand': '$mostDepletedRestockDemand'},
        ),
        title: 'analytics.mostDepletedSku',
        value: mostDepletedName,
        iconTint: const Color(0xFF8C4F10),
        iconBackground: const Color(0xFFFEF1E7),
        emphasizeValue: true,
      ),
      DashboardMetric(
        icon: Icons.warning_amber_rounded,
        highlight: AdminLocaleController.globalT(
          'analytics.lowStockHighlight',
          params: {
            'low': '${lowStockProducts.length}',
            'total': '$totalProducts',
          },
        ),
        title: 'analytics.lowStockRatio',
        value: '${lowStockRatio.toStringAsFixed(1)}%',
        iconTint: const Color(0xFF7D3042),
        iconBackground: const Color(0xFFFCE7EF),
      ),
      DashboardMetric(
        icon: Icons.repeat_rounded,
        highlight: AdminLocaleController.globalT(
          'analytics.repeatRestockHighlight',
          params: {
            'repeat': '$repeatRestockUsers',
            'total': '$restockRequesterUsers',
          },
        ),
        title: 'analytics.repeatRestockRate',
        value: '${repeatRestockPurchaseRatePercent.toStringAsFixed(1)}%',
        iconTint: const Color(0xFF114F2D),
        iconBackground: const Color(0xFFE4F4EA),
      ),
      DashboardMetric(
        icon: Icons.ssid_chart_rounded,
        highlight: AdminLocaleController.globalT(
          'analytics.restockRevenueHighlight',
          params: {
            'revenue': restockDeliveredRevenue.toStringAsFixed(0),
          },
        ),
        title: 'analytics.restockRevenueShare',
        value: '${restockRevenueContributionPercent.toStringAsFixed(1)}%',
        iconTint: const Color(0xFF155E99),
        iconBackground: const Color(0xFFEAF4FF),
      ),
    ];

    final salesTrend = _buildWeeklyOrderTrend(orders, now);
    final activityFeed = _buildActivityFeed(orders, now);
    final inventorySnapshots = <ProgressSnapshot>[
      ProgressSnapshot(
        label: 'Healthy stock',
        value: healthyRatio.clamp(0.0, 1.0),
        color: const Color(0xFF114F2D),
      ),
      ProgressSnapshot(
        label: 'Low stock',
        value:
            (totalProducts > 0 ? lowStockProducts.length / totalProducts : 0.0)
                .clamp(0.0, 1.0),
        color: const Color(0xFF8C4F10),
      ),
      ProgressSnapshot(
        label: 'Out of stock',
        value:
            (totalProducts > 0
                    ? outOfStockProducts.length / totalProducts
                    : 0.0)
                .clamp(0.0, 1.0),
        color: const Color(0xFF7A1C12),
      ),
    ];

    return AdminDashboardSnapshot(
      metrics: metrics,
      salesTrend: salesTrend,
      activityFeed: activityFeed,
      inventorySnapshots: inventorySnapshots,
      restockFunnel: AdminRestockFunnelSnapshot(
        totalNotifyRequests: totalNotifyRequests,
        totalNotificationsSent: totalNotificationsSent,
        totalRestockConversions: totalRestockConversions,
        averageTimeToConversionHours: averageTimeToConversionHours,
        repeatRestockPurchaseRatePercent: repeatRestockPurchaseRatePercent,
        restockRevenueContributionPercent: restockRevenueContributionPercent,
      ),
      featuredComposition: _buildFeaturedComposition(
        product: mostDepleted,
        outOfStockCount: outOfStockProducts.length,
        restockDemand: mostDepletedRestockDemand,
      ),
    );
  }

  @override
  Future<BusinessConfigModel> fetchBusinessConfig() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('business_config')
          .get();
      if (doc.exists && doc.data() != null) {
        return BusinessConfigModel.fromMap(doc.data()!);
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][analytics][fetch_business_config_failed] '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrint(
        '[admin][analytics][fetch_business_config_failed_stack] $stackTrace',
      );
      // Keep missing/inaccessible config empty-safe. Do not invent costs.
    }
    return BusinessConfigModel(
      serverCosts: 0,
      manufacturingCosts: 0,
      otherFixedCosts: 0,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> saveBusinessConfig(BusinessConfigModel config) async {
    validateBusinessConfig(config);
    await _firestore
        .collection('settings')
        .doc('business_config')
        .set(config.toMap(), SetOptions(merge: true));
  }

  @override
  Future<AdminFinanceSnapshot> fetchFinanceSnapshot() async {
    try {
      final businessConfig = await fetchBusinessConfig();
      final aggregateSnapshot = await _fetchAggregateFinanceSnapshot(
        businessConfig,
      );
      if (aggregateSnapshot != null) {
        return aggregateSnapshot;
      }

      final deliveredSnapshot = await _firestore
          .collection('orders')
          // Reviewed against Main App + Admin + orders worker state machine.
          // `delivered` is the terminal fulfilled status treated as realized revenue.
          .where('status', isEqualTo: _realizedRevenueStatus)
          .orderBy('createdAt', descending: true)
          .limit(1000)
          .get();

      final deliveredOrders = deliveredSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(days: 30));

      var totalRevenueMinor = 0;
      int totalOrdersCount = deliveredOrders.length;
      int aiChatOrdersCount = 0;
      final aiChatBuyerUserIds = <String>{};

      final productRevenuesMinor = <String, int>{};
      final productUnits = <String, int>{};
      final productNames = <String, String>{};
      int totalUnitsSold = 0;

      for (final order in deliveredOrders) {
        final orderCreatedAt = _timestampOrNull(order['createdAt'])?.toDate();
        final inWindow =
            orderCreatedAt != null && !orderCreatedAt.isBefore(windowStart);
        final orderTotalMinor = _orderTotalMinor(order);
        final source = (order['orderSource'] ?? 'app').toString();
        final userId = (order['userId'] ?? '').toString();

        totalRevenueMinor += orderTotalMinor;
        if (source == 'ai_chat') {
          aiChatOrdersCount++;
          if (inWindow && userId.isNotEmpty) {
            aiChatBuyerUserIds.add(userId);
          }
        }

        if (!inWindow) continue;

        final items = (order['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        for (final item in items) {
          final productId = (item['productId'] ?? item['sku'] ?? '').toString();
          if (productId.isEmpty) continue;
          final quantity = _asInt(item['quantity']).clamp(0, 999999);
          if (quantity <= 0) continue;
          final unitPriceMinor = _itemUnitPriceMinor(item);
          final itemRevenueMinor = unitPriceMinor * quantity;
          final name =
              (item['name'] ??
                      'SKU ${productId.substring(0, productId.length > 6 ? 6 : productId.length)}')
                  .toString();

          totalUnitsSold += quantity;
          productRevenuesMinor[productId] =
              (productRevenuesMinor[productId] ?? 0) + itemRevenueMinor;
          productUnits[productId] = (productUnits[productId] ?? 0) + quantity;
          productNames[productId] = name;
        }
      }

      final aovMinor = totalOrdersCount > 0
          ? (totalRevenueMinor / totalOrdersCount).round()
          : 0;
      final aov = aovMinor / 100;

      final aiEngagedUserIds = await _fetchAiEngagedUserIds(windowStart);
      final aiConversion = aiEngagedUserIds.isNotEmpty
          ? aiChatBuyerUserIds.length / aiEngagedUserIds.length
          : (totalOrdersCount > 0 ? aiChatOrdersCount / totalOrdersCount : 0.0);

      final productSnapshot = await _firestore
          .collection('products')
          .limit(1200)
          .get();
      final productCostByIdMinor = <String, int>{};
      for (final doc in productSnapshot.docs) {
        final extracted = _extractUnitCostMinor(doc.data());
        if (extracted != null && extracted > 0) {
          productCostByIdMinor[doc.id] = extracted;
        }
      }
      final hasDirectCogsData = productCostByIdMinor.isNotEmpty;

      final fallbackEstimatedUnitCostMinor = totalUnitsSold > 0
          ? (businessConfig.manufacturingCosts * 100 / totalUnitsSold).round()
          : 0;
      final marginRecords = <_ProductMarginRecord>[];
      double marginWeightedSum = 0.0;
      double marginWeight = 0.0;

      for (final entry in productRevenuesMinor.entries) {
        final productId = entry.key;
        final revenueMinor = entry.value;
        final units = productUnits[productId] ?? 0;
        if (revenueMinor <= 0 || units <= 0) continue;
        final avgUnitPrice = revenueMinor / units / 100;
        final unitCostMinor =
            productCostByIdMinor[productId] ?? fallbackEstimatedUnitCostMinor;
        final unitCost = unitCostMinor / 100;
        final margin = avgUnitPrice <= 0
            ? 0.0
            : ((avgUnitPrice - unitCost) / avgUnitPrice) * 100;
        final clampedMargin = margin.clamp(-200.0, 200.0);

        marginWeightedSum += clampedMargin * revenueMinor;
        marginWeight += revenueMinor;
        marginRecords.add(
          _ProductMarginRecord(
            productId: productId,
            name: productNames[productId] ?? 'SKU',
            marginPercent: clampedMargin,
            revenueMinor: revenueMinor,
          ),
        );
      }

      marginRecords.sort((a, b) => b.marginPercent.compareTo(a.marginPercent));
      final avgProductMargin = marginWeight > 0
          ? marginWeightedSum / marginWeight
          : 0.0;
      final topMarginProduct = marginRecords.isNotEmpty
          ? marginRecords.first
          : null;
      final isMarginEstimatedOnly =
          !hasDirectCogsData && fallbackEstimatedUnitCostMinor > 0;
      final hasInsufficientCostData =
          !hasDirectCogsData && fallbackEstimatedUnitCostMinor <= 0;

      final ratios = <FinanceRatio>[
        FinanceRatio(
          label: isMarginEstimatedOnly
              ? 'Product Margin (Estimated)'
              : 'Product Margin (Avg)',
          value: hasInsufficientCostData
              ? 'N/A'
              : '${avgProductMargin.toStringAsFixed(1)}%',
          change: hasInsufficientCostData
              ? 'COGS data unavailable'
              : isMarginEstimatedOnly
              ? 'Estimated from monthly manufacturing costs'
              : topMarginProduct == null
              ? 'Waiting for enough sales data'
              : 'Top: ${_truncate(topMarginProduct.name, max: 16)} ${topMarginProduct.marginPercent.toStringAsFixed(1)}%',
        ),
        FinanceRatio(
          label: 'AI Chat -> Purchase',
          value: '${(aiConversion * 100).toStringAsFixed(1)}%',
          change:
              '${aiChatBuyerUserIds.length} buyers / ${aiEngagedUserIds.length} engaged users (30d)',
        ),
        FinanceRatio(
          label: 'AOV (EGP)',
          value: aov.toStringAsFixed(2),
          change: 'Based on $totalOrdersCount $_realizedRevenueStatus orders',
        ),
      ];

      final monthlyRevenueMinor = <int, int>{for (int i = 0; i < 6; i++) i: 0};

      for (final order in deliveredOrders) {
        final ts = _timestampOrNull(order['createdAt']);
        if (ts == null) continue;

        final date = ts.toDate();
        final monthsAgo = (now.year - date.year) * 12 + now.month - date.month;

        if (monthsAgo >= 0 && monthsAgo < 6) {
          monthlyRevenueMinor[5 - monthsAgo] =
              (monthlyRevenueMinor[5 - monthsAgo] ?? 0) +
              _orderTotalMinor(order);
        }
      }

      double sumX = 0.0;
      double sumY = 0.0;
      double sumXY = 0.0;
      double sumX2 = 0.0;
      for (int x = 0; x < 6; x++) {
        final double y = monthlyRevenueMinor[x]!.toDouble();
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
      }

      double m = 0;
      double b = 0;
      final denominator = sumX2 - (sumX * sumX) / 6;
      if (denominator != 0) {
        m = (sumXY - (sumX * sumY) / 6) / denominator;
        b = (sumY - m * sumX) / 6;
      }

      final forecastRevenueMinor = (m * 6 + b).round();

      final List<FinancePoint> dynamicProjection = [];
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final fixedCostsPerMonth =
          businessConfig.serverCosts +
          businessConfig.manufacturingCosts +
          businessConfig.otherFixedCosts;

      for (int i = 0; i < 6; i++) {
        final dateForMonth = DateTime(now.year, now.month - 5 + i);
        final label = monthNames[dateForMonth.month - 1];
        dynamicProjection.add(
          FinancePoint(
            label: label,
            revenue: monthlyRevenueMinor[i]! / 100,
            cost: fixedCostsPerMonth,
          ),
        );
      }

      final forecastDate = DateTime(now.year, now.month + 1);
      dynamicProjection.add(
        FinancePoint(
          label: '${monthNames[forecastDate.month - 1]} (Est)',
          revenue: forecastRevenueMinor > 0 ? forecastRevenueMinor / 100 : 0,
          cost: fixedCostsPerMonth,
        ),
      );

      return AdminFinanceSnapshot(
        projection: dynamicProjection,
        ratios: ratios,
        initialServerCosts: businessConfig.serverCosts,
        initialOperatingCosts: businessConfig.manufacturingCosts,
        initialAverageOrderValue: aov,
        initialGrossMargin: avgProductMargin > 0
            ? (avgProductMargin / 100).clamp(0.0, 0.95)
            : 0.0,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][analytics][fetch_finance_snapshot_failed] '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrint(
        '[admin][analytics][fetch_finance_snapshot_failed_stack] $stackTrace',
      );
      rethrow;
    }
  }

  Future<AdminFinanceSnapshot?> _fetchAggregateFinanceSnapshot(
    BusinessConfigModel businessConfig,
  ) async {
    try {
      final summaryDoc = await _firestore
          .collection('admin_finance_aggregates')
          .doc('summary')
          .get();
      final summary = summaryDoc.data();
      if (summary == null || !summaryDoc.exists) {
        return null;
      }

      final deliveredOrders = _asInt(summary['totalDeliveredOrders']);
      final deliveredRevenueMinor = _asInt(
        summary['totalDeliveredRevenueMinor'],
      );
      if (deliveredOrders <= 0) {
        return null;
      }

      final monthlySnapshot = await _firestore
          .collection('admin_finance_monthly_rollups')
          .orderBy('monthStart', descending: true)
          .limit(6)
          .get();
      final now = DateTime.now();
      final fixedCostsPerMonth =
          businessConfig.serverCosts +
          businessConfig.manufacturingCosts +
          businessConfig.otherFixedCosts;
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final rollups = monthlySnapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) {
          final aStart = _dateTimeOrNull(a['monthStart']) ?? DateTime(1970);
          final bStart = _dateTimeOrNull(b['monthStart']) ?? DateTime(1970);
          return aStart.compareTo(bStart);
        });

      final projection = <FinancePoint>[];
      if (rollups.isEmpty) {
        projection.add(
          FinancePoint(
            label: monthNames[now.month - 1],
            revenue: deliveredRevenueMinor / 100,
            cost: fixedCostsPerMonth,
          ),
        );
      } else {
        for (final rollup in rollups) {
          final monthStart = _dateTimeOrNull(rollup['monthStart']);
          final label = monthStart == null
              ? (rollup['monthKey'] ?? 'Month').toString()
              : monthNames[monthStart.month - 1];
          projection.add(
            FinancePoint(
              label: label,
              revenue: _asInt(rollup['deliveredRevenueMinor']) / 100,
              cost: fixedCostsPerMonth,
            ),
          );
        }
      }

      final forecastRevenue = projection.isEmpty
          ? 0.0
          : projection.map((point) => point.revenue).reduce((a, b) => a + b) /
                projection.length;
      final forecastDate = DateTime(now.year, now.month + 1);
      projection.add(
        FinancePoint(
          label: '${monthNames[forecastDate.month - 1]} (Est)',
          revenue: forecastRevenue,
          cost: fixedCostsPerMonth,
        ),
      );

      final aiChatDeliveredOrders = _asInt(summary['aiChatDeliveredOrders']);
      final aov = deliveredRevenueMinor / deliveredOrders / 100;
      final ratios = <FinanceRatio>[
        const FinanceRatio(
          label: 'Product Margin',
          value: 'N/A',
          change: 'Waiting for aggregate COGS rollups',
        ),
        FinanceRatio(
          label: 'AI Chat -> Purchase',
          value: deliveredOrders > 0
              ? '${((aiChatDeliveredOrders / deliveredOrders) * 100).toStringAsFixed(1)}%'
              : '0.0%',
          change:
              '$aiChatDeliveredOrders AI-chat delivered orders / $deliveredOrders delivered orders',
        ),
        FinanceRatio(
          label: 'AOV (EGP)',
          value: aov.toStringAsFixed(2),
          change: 'Aggregate-backed delivered order rollup',
        ),
      ];

      return AdminFinanceSnapshot(
        projection: projection,
        ratios: ratios,
        initialServerCosts: businessConfig.serverCosts,
        initialOperatingCosts: businessConfig.manufacturingCosts,
        initialAverageOrderValue: aov,
        initialGrossMargin: 0,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][analytics][fetch_finance_aggregate_failed] '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrint(
        '[admin][analytics][fetch_finance_aggregate_failed_stack] $stackTrace',
      );
      return null;
    }
  }

  Future<Set<String>> _fetchAiEngagedUserIds(DateTime windowStart) async {
    try {
      final events = await _firestore
          .collection('ai_chat_events')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .where(
            'eventType',
            whereIn: const ['message_sent', 'recommendations_shown'],
          )
          .limit(2500)
          .get();
      return events.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  List<TrendPoint> _buildWeeklyOrderTrend(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    final labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final buckets = <int, double>{for (int i = 0; i < 7; i++) i: 0.0};

    for (final order in orders) {
      final ts = _timestampOrNull(order['createdAt']);
      if (ts == null) continue;
      final date = ts.toDate();
      if (now.difference(date).inDays >= 7) continue;
      final index = date.weekday - 1;
      buckets[index] = (buckets[index] ?? 0) + 1;
    }

    return List<TrendPoint>.generate(
      7,
      (index) => TrendPoint(labels[index], buckets[index] ?? 0),
    );
  }

  List<ActivityItem> _buildActivityFeed(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    final recent = orders.take(4).toList();
    if (recent.isEmpty) {
      return const <ActivityItem>[];
    }

    return recent.map((order) {
      final status = _status(order);
      final id = (order['id'] ?? order['orderId'] ?? '').toString();
      final ts =
          _timestampOrNull(order['updatedAt']) ??
          _timestampOrNull(order['createdAt']);
      final when = ts?.toDate();
      final timeAgo = when == null
          ? 'Unknown time'
          : _formatTimeAgo(now.difference(when));
      return ActivityItem(
        title: 'Order ${id.isEmpty ? 'N/A' : '#${_truncate(id, max: 8)}'}',
        subtitle: 'Status: $status',
        timeAgo: timeAgo,
        highlighted: status == 'cancelled',
      );
    }).toList();
  }

  static String _formatTimeAgo(Duration diff) {
    if (diff.inMinutes < 1) return 'common.justNow';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _status(Map<String, dynamic> order) {
    return (order['status'] ?? 'unknown').toString();
  }

  static Timestamp? _timestampOrNull(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    return null;
  }

  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int _stockOf(Map<String, dynamic>? product) {
    if (product == null) return 0;
    return _asInt(product['stock']);
  }

  static String? _nameOf(Map<String, dynamic>? product) {
    if (product == null) return null;
    final name = (product['name'] ?? '').toString().trim();
    return name.isEmpty ? null : name;
  }

  static String _truncate(String value, {required int max}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 3)}...';
  }

  static int _orderTotalMinor(Map<String, dynamic> order) {
    if (order.containsKey('totalAmount')) {
      return _moneyToMinorUnits(order['totalAmount'], preferMinorUnits: true);
    }
    return _moneyToMinorUnits(order['total'], preferMinorUnits: false);
  }

  static int _itemUnitPriceMinor(Map<String, dynamic> item) {
    if (item.containsKey('unitPrice')) {
      return _moneyToMinorUnits(item['unitPrice'], preferMinorUnits: true);
    }
    return _moneyToMinorUnits(
      item['priceSnapshot'] ?? item['price'],
      preferMinorUnits: false,
    );
  }

  static int? _extractUnitCostMinor(Map<String, dynamic> product) {
    const costCandidates = <String>[
      'unitCost',
      'costPrice',
      'cogs',
      'manufacturingCost',
      'cost',
    ];
    for (final key in costCandidates) {
      if (!product.containsKey(key)) continue;
      final raw = product[key];
      final minor = _moneyToMinorUnits(raw, preferMinorUnits: false);
      if (minor <= 0) continue;
      if (raw is num && raw.abs() > 5000) {
        return raw.round();
      }
      return minor;
    }
    return null;
  }

  static int _moneyToMinorUnits(dynamic raw, {required bool preferMinorUnits}) {
    if (raw == null) {
      return 0;
    }

    if (raw is int) {
      return preferMinorUnits ? raw : raw * 100;
    }

    if (raw is double) {
      if (preferMinorUnits && raw == raw.roundToDouble()) {
        return raw.toInt();
      }
      return (raw * 100).round();
    }

    if (raw is String) {
      final normalized = raw.replaceAll(',', '').trim();
      final parsed = double.tryParse(normalized);
      if (parsed == null) {
        return 0;
      }
      if (preferMinorUnits && parsed == parsed.roundToDouble()) {
        return parsed.toInt();
      }
      return (parsed * 100).round();
    }

    return 0;
  }

  static AdminFeatureHighlight? _buildFeaturedComposition({
    required Map<String, dynamic>? product,
    required int outOfStockCount,
    required int restockDemand,
  }) {
    if (product == null) return null;
    final imageUrl = _imageUrlOf(product);
    final name = _nameOf(product);
    if (imageUrl == null || name == null) return null;
    final stock = _stockOf(product);
    return AdminFeatureHighlight(
      title: name,
      description:
          'Stock: $stock units. Pending restock requests: $restockDemand. Out-of-stock SKUs: $outOfStockCount.',
      imageUrl: imageUrl,
    );
  }

  static String? _imageUrlOf(Map<String, dynamic> product) {
    final imageUrl = (product['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) return imageUrl;
    final imageUrls = product['imageUrls'];
    if (imageUrls is Iterable) {
      for (final value in imageUrls) {
        final candidate = value.toString().trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }

  static double? _extractTransitionDurationHours(Map<String, dynamic> order) {
    final timeline = order['timeline'];
    if (timeline is List && timeline.length >= 2) {
      final entries = timeline.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) {
          final at =
              _timestampOrNull(a['occurredAt'])?.millisecondsSinceEpoch ?? 0;
          final bt =
              _timestampOrNull(b['occurredAt'])?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        });
      final diffs = <double>[];
      for (int i = 1; i < entries.length; i++) {
        final prev = _timestampOrNull(entries[i - 1]['occurredAt'])?.toDate();
        final current = _timestampOrNull(entries[i]['occurredAt'])?.toDate();
        if (prev == null || current == null) continue;
        final hours = current.difference(prev).inMinutes / 60;
        if (hours > 0) {
          diffs.add(hours);
        }
      }
      if (diffs.isNotEmpty) {
        return diffs.reduce((a, b) => a + b) / diffs.length;
      }
    }

    final createdAt = _timestampOrNull(order['createdAt'])?.toDate();
    final updatedAt = _timestampOrNull(order['updatedAt'])?.toDate();
    if (createdAt == null || updatedAt == null) return null;
    final diff = updatedAt.difference(createdAt);
    if (diff.inMinutes <= 0) return null;
    return diff.inMinutes / 60;
  }
}

class _ProductMarginRecord {
  const _ProductMarginRecord({
    required this.productId,
    required this.name,
    required this.marginPercent,
    required this.revenueMinor,
  });

  final String productId;
  final String name;
  final double marginPercent;
  final int revenueMinor;
}
