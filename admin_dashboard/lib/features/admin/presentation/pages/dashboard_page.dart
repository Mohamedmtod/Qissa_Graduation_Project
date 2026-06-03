import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_analytics_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_analytics_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/utils/admin_export_utils.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminAnalyticsCubit(context.read<AdminAnalyticsRepository>())
            ..loadDashboard(),
      child: const _DashboardView(),
    );
  }
}

enum _DashboardTab { overview, analytics }

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  _DashboardTab _activeTab = _DashboardTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final observability = context.read<AdminObservabilityService>();
    return Column(
      children: [
        SharedTopbar(
          title: l10n.t('dashboard.topbarTitle'),
          searchHint: l10n.t('dashboard.searchHint'),
          tabs: [
            TopbarTab(
              label: l10n.t('common.overview'),
              active: _activeTab == _DashboardTab.overview,
              onTap: () => setState(() => _activeTab = _DashboardTab.overview),
            ),
            TopbarTab(
              label: l10n.t('common.analytics'),
              active: _activeTab == _DashboardTab.analytics,
              onTap: () => setState(() => _activeTab = _DashboardTab.analytics),
            ),
          ],
          onNotificationsTap: () => _showProductionIssuesSheet(
            context,
            observability.productionIssues.toList(),
          ),
        ),
        Expanded(
          child: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
            builder: (context, state) {
              final snapshot = state.dashboardSnapshot;
              if (state.isLoading && snapshot == null) {
                return AdminLoadingState(
                  title: l10n.t('dashboard.loadingTitle'),
                );
              }

              if (state.dashboardErrorMessage != null) {
                return AdminErrorState(
                  title: l10n.t('dashboard.errorTitle'),
                  message: state.dashboardErrorMessage!,
                  onRetry: () =>
                      context.read<AdminAnalyticsCubit>().loadDashboard(),
                );
              }

              if (snapshot == null) {
                return AdminEmptyState(
                  title: l10n.t('dashboard.emptyTitle'),
                  message: l10n.t('dashboard.emptyMessage'),
                  actionLabel: l10n.t('common.retry'),
                  onAction: () =>
                      context.read<AdminAnalyticsCubit>().loadDashboard(),
                );
              }

              if (_activeTab == _DashboardTab.analytics) {
                return _DashboardAnalyticsView(snapshot: snapshot);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final kpiColumns = constraints.maxWidth >= 1400
                        ? 4
                        : constraints.maxWidth >= 860
                        ? 2
                        : 1;
                    final kpiWidth =
                        (constraints.maxWidth - ((kpiColumns - 1) * 24)) /
                        kpiColumns;
                    final showWideSections = constraints.maxWidth >= 1200;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHero(
                          onExport: () async {
                            final format = await _chooseExportFormat(context);
                            if (format == null) {
                              return;
                            }

                            final exported = switch (format) {
                              _ExportFormat.csv => await _exportQuarterlyCsv(
                                l10n: l10n,
                                snapshot: snapshot,
                                observability: observability,
                              ),
                              _ExportFormat.pdf => await _exportQuarterlyPdf(
                                l10n: l10n,
                                snapshot: snapshot,
                                observability: observability,
                              ),
                            };
                            if (!context.mounted) {
                              return;
                            }
                            _showMessage(
                              context,
                              exported
                                  ? l10n.t('dashboard.exportSuccess')
                                  : l10n.t('common.dismiss'),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: snapshot.metrics
                              .map(
                                (metric) => SizedBox(
                                  width: kpiWidth,
                                  child: _KpiCard(metric: metric),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                        if (showWideSections)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _SalesTrendCard(
                                  salesTrend: snapshot.salesTrend,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _ActivityFeedCard(
                                  activityFeed: snapshot.activityFeed,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _SalesTrendCard(salesTrend: snapshot.salesTrend),
                              const SizedBox(height: 24),
                              _ActivityFeedCard(
                                activityFeed: snapshot.activityFeed,
                              ),
                            ],
                          ),
                        const SizedBox(height: 32),
                        if (showWideSections)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _FeaturedCompositionCard(
                                  featuredComposition:
                                      snapshot.featuredComposition,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _InventoryStatusCard(
                                  inventorySnapshots:
                                      snapshot.inventorySnapshots,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _FeaturedCompositionCard(
                                featuredComposition:
                                    snapshot.featuredComposition,
                              ),
                              const SizedBox(height: 24),
                              _InventoryStatusCard(
                                inventorySnapshots: snapshot.inventorySnapshots,
                              ),
                            ],
                          ),
                        const SizedBox(height: 32),
                        ListenableBuilder(
                          listenable: observability,
                          builder: (context, _) {
                            return _ObservabilityDeck(
                              auditEntries: observability.auditEntries
                                  .take(5)
                                  .toList(),
                              productionIssues: observability.productionIssues
                                  .take(5)
                                  .toList(),
                              warningCount: observability.warningOrHigherCount,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashboardAnalyticsView extends StatelessWidget {
  const _DashboardAnalyticsView({required this.snapshot});

  final dynamic snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SalesTrendCard(salesTrend: snapshot.salesTrend),
          const SizedBox(height: 24),
          _InventoryStatusCard(inventorySnapshots: snapshot.inventorySnapshots),
          const SizedBox(height: 24),
          _ActivityFeedCard(activityFeed: snapshot.activityFeed),
        ],
      ),
    );
  }
}

class _ObservabilityDeck extends StatelessWidget {
  const _ObservabilityDeck({
    required this.auditEntries,
    required this.productionIssues,
    required this.warningCount,
  });

  final List<AdminAuditEntry> auditEntries;
  final List<AdminProductionIssue> productionIssues;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1180;

        if (stacked) {
          return Column(
            children: [
              _ProductionIssuesCard(
                productionIssues: productionIssues,
                warningCount: warningCount,
              ),
              const SizedBox(height: 24),
              _AuditTrailCard(auditEntries: auditEntries),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ProductionIssuesCard(
                productionIssues: productionIssues,
                warningCount: warningCount,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: _AuditTrailCard(auditEntries: auditEntries)),
          ],
        );
      },
    );
  }
}

class _ProductionIssuesCard extends StatelessWidget {
  const _ProductionIssuesCard({
    required this.productionIssues,
    required this.warningCount,
  });

  final List<AdminProductionIssue> productionIssues;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('dashboard.productionMonitorTitle'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('dashboard.productionMonitorSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              AdminPill(
                label: warningCount == 0
                    ? l10n.t('dashboard.badgeStable')
                    : l10n.t('dashboard.badgeAttention'),
                backgroundColor: warningCount == 0
                    ? AppTheme.tertiaryFixed
                    : const Color(0xFFFDE2E1),
                foregroundColor: warningCount == 0
                    ? AppTheme.tertiary
                    : const Color(0xFF9B1B1B),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (productionIssues.isEmpty)
            AdminEmptyState(
              title: l10n.t('dashboard.productionEmptyTitle'),
              message: l10n.t('dashboard.productionEmptyMessage'),
              icon: Icons.health_and_safety_outlined,
            )
          else
            ...productionIssues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _IssueRow(issue: issue),
              );
            }),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final AdminProductionIssue issue;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (issue.severity) {
      AdminIssueSeverity.info => AppTheme.tertiary,
      AdminIssueSeverity.warning => const Color(0xFF8C4F10),
      AdminIssueSeverity.error => const Color(0xFF9B1B1B),
      AdminIssueSeverity.critical => const Color(0xFF7A1C12),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: severityColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                ),
              ),
              AdminPill(
                label: issue.severity.name.toUpperCase(),
                backgroundColor: severityColor.withValues(alpha: 0.12),
                foregroundColor: severityColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(issue.message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            '${issue.source} | ${formatTimelineDate(issue.occurredAt)} | ${issue.traceId}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _AuditTrailCard extends StatelessWidget {
  const _AuditTrailCard({required this.auditEntries});

  final List<AdminAuditEntry> auditEntries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('dashboard.auditTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('dashboard.auditSubtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (auditEntries.isEmpty)
            AdminEmptyState(
              title: l10n.t('dashboard.auditEmptyTitle'),
              message: l10n.t('dashboard.auditEmptyMessage'),
              icon: Icons.fact_check_outlined,
            )
          else
            ...auditEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _AuditRow(entry: entry),
              );
            }),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AdminAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final blocked = entry.outcome != 'success';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blocked ? const Color(0xFFFFF5F4) : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.action,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                ),
              ),
              AdminPill(
                label: entry.outcome.toUpperCase(),
                backgroundColor: blocked
                    ? const Color(0xFFFDE2E1)
                    : AppTheme.tertiaryFixed,
                foregroundColor: blocked
                    ? const Color(0xFF9B1B1B)
                    : AppTheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Actor: ${entry.actorId} (${entry.actorRole}) | Target: ${entry.targetId}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (entry.details != null && entry.details!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.details!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Text(
            '${formatTimelineDate(entry.occurredAt)} | ${entry.traceId}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final authState = context.watch<AdminAuthCubit>().state;
    final profileName = authState.profileName?.trim().isNotEmpty == true
        ? authState.profileName!.trim()
        : l10n.t('sidebar.profileName');

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 18,
      spacing: 18,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminSectionLabel(
              label: l10n.t(
                'dashboard.heroGreeting',
                params: {'name': profileName},
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('dashboard.heroTitle'),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppTheme.primary,
                fontSize: 42,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                l10n.t('dashboard.heroDescription'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        AdminPrimaryButton(
          label: l10n.t('dashboard.exportQuarterly'),
          icon: Icons.download_outlined,
          onPressed: onExport,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: Colors.white.withValues(alpha: 0.5),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: metric.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(metric.icon, color: metric.iconTint),
              ),
              const Spacer(),
              Text(
                l10n.resolve(metric.highlight),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: metric.iconTint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.resolve(metric.title).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.resolve(metric.value),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: metric.emphasizeValue
                  ? AppTheme.secondary
                  : AppTheme.primary,
              fontSize: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({required this.salesTrend});

  final List<TrendPoint> salesTrend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final maxPoint = salesTrend.isEmpty
        ? 0.0
        : salesTrend
              .map((point) => point.value)
              .reduce((a, b) => a > b ? a : b);
    final maxY = maxPoint <= 0 ? 6.0 : (maxPoint * 1.25);
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('dashboard.salesTrendsTitle'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('dashboard.salesTrendsSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              AdminPill(
                label: l10n.t('dashboard.weeklyBadge'),
                backgroundColor: Color(0xFFFCE7EF),
                foregroundColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.18),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= salesTrend.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            l10n.resolve(salesTrend[index].label),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < salesTrend.length; i++)
                        FlSpot(i.toDouble(), salesTrend[i].value),
                    ],
                    isCurved: true,
                    barWidth: 4,
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.secondary,
                        AppTheme.primary,
                      ],
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.22),
                          AppTheme.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot.x == 4,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: AppTheme.primary,
                            strokeWidth: 6,
                            strokeColor: AppTheme.primary.withValues(
                              alpha: 0.16,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard({required this.activityFeed});

  final List<ActivityItem> activityFeed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('dashboard.atelierFlowTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                onSelected: (value) async {
                  if (value == 'refresh') {
                    await context.read<AdminAnalyticsCubit>().loadDashboard();
                    if (context.mounted) {
                      _showMessage(
                        context,
                        l10n.t('dashboard.activityRefreshed'),
                      );
                    }
                    return;
                  }

                  if (value == 'export') {
                    final exported = await _exportActivityFeedCsv(activityFeed);
                    if (context.mounted) {
                      _showMessage(
                        context,
                        exported
                            ? l10n.t('dashboard.activityExported')
                            : l10n.t('common.dismiss'),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Text(l10n.t('dashboard.refreshActivity')),
                  ),
                  PopupMenuItem<String>(
                    value: 'export',
                    child: Text(l10n.t('dashboard.exportActivity')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (activityFeed.isEmpty)
            AdminEmptyState(
              title: l10n.t('dashboard.auditEmptyTitle'),
              message: l10n.t('dashboard.auditEmptyMessage'),
              icon: Icons.receipt_long_outlined,
            )
          else
            ...activityFeed.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: item.highlighted
                            ? AppTheme.primary
                            : AppTheme.outlineVariant,
                        shape: BoxShape.circle,
                        boxShadow: item.highlighted
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 10,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resolve(item.title),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppTheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.resolve(item.subtitle)),
                          const SizedBox(height: 4),
                          Text(
                            l10n.resolve(item.timeAgo),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showAuditTrailSheet(
              context,
              context.read<AdminObservabilityService>().auditEntries.toList(),
            ),
            child: Text(
              l10n.t('dashboard.viewFullAuditTrail'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCompositionCard extends StatelessWidget {
  const _FeaturedCompositionCard({required this.featuredComposition});

  final AdminFeatureHighlight? featuredComposition;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final item = featuredComposition;
    if (item == null) {
      return SizedBox(
        height: 320,
        child: AdminSurfaceCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_mosaic_outlined,
                color: AppTheme.onSurfaceVariant,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.t('dashboard.productionEmptyTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('dashboard.productionEmptyMessage'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: AdminNetworkImage(
              imageUrl: item.imageUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 28,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xF2171716),
                    Color(0x78171716),
                    Color(0x1A171716),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminSectionLabel(
                  label: l10n.t('dashboard.featuredComposition'),
                  color: AppTheme.primaryFixed,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.resolve(item.title),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    l10n.resolve(item.description),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryStatusCard extends StatelessWidget {
  const _InventoryStatusCard({required this.inventorySnapshots});

  final List<ProgressSnapshot> inventorySnapshots;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: AppTheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('dashboard.inventoryStatus'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          ...inventorySnapshots.map((snapshot) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(l10n.resolve(snapshot.label)),
                      const Spacer(),
                      Text(
                        '${(snapshot.value * 100).round()}%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: snapshot.value,
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(snapshot.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}

void _showAuditTrailSheet(BuildContext context, List<AdminAuditEntry> entries) {
  final l10n = context.read<AdminLocaleController>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('dashboard.auditTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Text(l10n.t('dashboard.auditEmptyMessage'))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, index) {
                      final entry = entries[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${entry.action} - ${entry.outcome}'),
                        subtitle: Text(
                          '${entry.traceId}\n${entry.actorRole}:${entry.actorId} -> ${entry.targetId}',
                        ),
                        trailing: Text(_shortDateTime(entry.occurredAt)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showProductionIssuesSheet(
  BuildContext context,
  List<AdminProductionIssue> issues,
) {
  final l10n = context.read<AdminLocaleController>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('dashboard.productionMonitorTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (issues.isEmpty)
                Text(l10n.t('dashboard.productionEmptyMessage'))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: issues.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, index) {
                      final issue = issues[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${issue.title} - ${issue.severity.name}'),
                        subtitle: Text('${issue.traceId}\n${issue.message}'),
                        trailing: Text(_shortDateTime(issue.occurredAt)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _exportActivityFeedCsv(List<ActivityItem> items) {
  final now = DateTime.now();
  final csv = buildCsv([
    ['title', 'subtitle', 'timeAgo', 'highlighted'],
    ...items.map(
      (item) => [item.title, item.subtitle, item.timeAgo, item.highlighted],
    ),
  ]);
  return saveTextFile(
    dialogTitle: 'Save dashboard activity',
    fileName: 'dashboard-activity-${now.year}-${now.month}-${now.day}.csv',
    extension: 'csv',
    content: csv,
  );
}

String _shortDateTime(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

enum _ExportFormat { csv, pdf }

Future<_ExportFormat?> _chooseExportFormat(BuildContext context) {
  return showModalBottomSheet<_ExportFormat>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              onTap: () => Navigator.of(sheetContext).pop(_ExportFormat.csv),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.of(sheetContext).pop(_ExportFormat.pdf),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _exportQuarterlyCsv({
  required AdminLocaleController l10n,
  required dynamic snapshot,
  required AdminObservabilityService observability,
}) async {
  final now = DateTime.now();
  final quarter = ((now.month - 1) ~/ 3) + 1;
  final fileName = 'dashboard-quarterly-Q$quarter-${now.year}.csv';
  final csv = _buildQuarterlyCsv(
    l10n: l10n,
    snapshot: snapshot,
    observability: observability,
    generatedAt: now,
  );

  try {
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save quarterly dashboard report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    return saveResult != null;
  } catch (_) {
    return false;
  }
}

Future<bool> _exportQuarterlyPdf({
  required AdminLocaleController l10n,
  required dynamic snapshot,
  required AdminObservabilityService observability,
}) async {
  final now = DateTime.now();
  final quarter = ((now.month - 1) ~/ 3) + 1;
  final fileName = 'dashboard-quarterly-Q$quarter-${now.year}.pdf';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text('Quarterly Dashboard Report'),
        pw.SizedBox(height: 8),
        pw.Text('Generated at: ${now.toIso8601String()}'),
        pw.SizedBox(height: 12),
        ...snapshot.metrics.map(
          (metric) => pw.Text(
            '${l10n.resolve(metric.title)}: ${l10n.resolve(metric.value)}',
          ),
        ),
      ],
    ),
  );

  try {
    final bytes = await doc.save();
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save quarterly dashboard report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    return saveResult != null;
  } catch (_) {
    return false;
  }
}

String _buildQuarterlyCsv({
  required AdminLocaleController l10n,
  required dynamic snapshot,
  required AdminObservabilityService observability,
  required DateTime generatedAt,
}) {
  final buffer = StringBuffer();
  void row(List<Object?> columns) {
    final encoded = columns
        .map((value) {
          final text = (value ?? '').toString().replaceAll('"', '""');
          return '"$text"';
        })
        .join(',');
    buffer.writeln(encoded);
  }

  row(['section', 'field1', 'field2', 'field3', 'field4']);
  row(['meta', 'generatedAt', generatedAt.toIso8601String(), '', '']);

  row(['metrics', '', '', '', '']);
  for (final metric in snapshot.metrics) {
    row([
      'metric',
      l10n.resolve(metric.title),
      l10n.resolve(metric.value),
      l10n.resolve(metric.highlight),
      metric.emphasizeValue,
    ]);
  }

  row(['salesTrend', '', '', '', '']);
  for (final point in snapshot.salesTrend) {
    row(['trend', l10n.resolve(point.label), point.value.toStringAsFixed(2)]);
  }

  row(['activityFeed', '', '', '', '']);
  for (final item in snapshot.activityFeed) {
    row([
      'activity',
      l10n.resolve(item.title),
      l10n.resolve(item.subtitle),
      l10n.resolve(item.timeAgo),
      item.highlighted,
    ]);
  }

  row(['inventoryStatus', '', '', '', '']);
  for (final status in snapshot.inventorySnapshots) {
    row([
      'inventory',
      l10n.resolve(status.label),
      '${(status.value * 100).toStringAsFixed(1)}%',
      '',
      '',
    ]);
  }

  row(['productionIssues', '', '', '', '']);
  for (final issue in observability.productionIssues) {
    row([
      'issue',
      issue.title,
      issue.severity.name,
      issue.traceId,
      issue.occurredAt.toIso8601String(),
    ]);
  }

  row(['auditTrail', '', '', '', '']);
  for (final entry in observability.auditEntries) {
    row([
      'audit',
      entry.action,
      entry.outcome,
      entry.traceId,
      entry.occurredAt.toIso8601String(),
    ]);
  }

  return buffer.toString();
}
