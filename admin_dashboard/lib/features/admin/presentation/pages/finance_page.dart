import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_analytics_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_analytics_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminAnalyticsCubit(context.read<AdminAnalyticsRepository>())
            ..loadFinance(),
      child: const _FinanceView(),
    );
  }
}

enum _FinanceTab { overview, analytics }

class _FinanceView extends StatefulWidget {
  const _FinanceView();

  @override
  State<_FinanceView> createState() => _FinanceViewState();
}

class _FinanceViewState extends State<_FinanceView> {
  _FinanceTab _activeTab = _FinanceTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Column(
      children: [
        SharedTopbar(
          title: l10n.t('finance.topbarTitle'),
          searchHint: l10n.t('finance.searchHint'),
          tabs: [
            TopbarTab(
              label: l10n.t('common.overview'),
              active: _activeTab == _FinanceTab.overview,
              onTap: () => setState(() => _activeTab = _FinanceTab.overview),
            ),
            TopbarTab(
              label: l10n.t('common.analytics'),
              active: _activeTab == _FinanceTab.analytics,
              onTap: () => setState(() => _activeTab = _FinanceTab.analytics),
            ),
          ],
        ),
        Expanded(
          child: BlocBuilder<AdminAnalyticsCubit, AdminAnalyticsState>(
            builder: (context, state) {
              final snapshot = state.financeSnapshot;
              if (state.isLoading && snapshot == null) {
                return AdminLoadingState(title: l10n.t('finance.loadingTitle'));
              }

              if (state.financeErrorMessage != null) {
                return AdminErrorState(
                  title: l10n.t('finance.errorTitle'),
                  message: state.financeErrorMessage!,
                  onRetry: () =>
                      context.read<AdminAnalyticsCubit>().loadFinance(),
                );
              }

              if (snapshot == null) {
                return AdminEmptyState(
                  title: l10n.t('finance.emptyTitle'),
                  message: l10n.t('finance.emptyMessage'),
                  actionLabel: l10n.t('common.retry'),
                  onAction: () =>
                      context.read<AdminAnalyticsCubit>().loadFinance(),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        runSpacing: 18,
                        spacing: 18,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AdminSectionLabel(
                                  label: l10n.t('finance.sectionLabel'),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.t('finance.heroTitle'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontSize: 40,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.t('finance.heroDescription'),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.t(
                                    'finance.sampledDataNotice',
                                    fallback:
                                        'Finance KPIs are based on capped Firestore reads and should not be treated as a complete accounting ledger.',
                                  ),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              AdminSecondaryButton(
                                label: l10n.t('finance.refreshForecast'),
                                icon: Icons.refresh,
                                onPressed: () => context
                                    .read<AdminAnalyticsCubit>()
                                    .loadFinance(),
                              ),
                              AdminSecondaryButton(
                                label: l10n.t(
                                  'finance.saveConfig',
                                  fallback: 'Save Config',
                                ),
                                icon: Icons.save,
                                onPressed: state.isSavingSettings
                                    ? null
                                    : () async {
                                        final saved = await context
                                            .read<AdminAnalyticsCubit>()
                                            .saveSettings();
                                        if (context.mounted) {
                                          _showMessage(
                                            context,
                                            saved
                                                ? l10n.t(
                                                    'finance.saveConfigSuccess',
                                                    fallback:
                                                        'Configuration Saved',
                                                  )
                                                : l10n.t(
                                                    'finance.saveConfigFailed',
                                                    fallback:
                                                        'Failed to save configuration.',
                                                  ),
                                          );
                                        }
                                      },
                              ),
                              AdminPrimaryButton(
                                label: l10n.t('finance.exportPack'),
                                icon: Icons.download_outlined,
                                onPressed: () async {
                                  final format =
                                      await _chooseFinanceExportFormat(context);
                                  if (format == null) {
                                    return;
                                  }

                                  final exported = switch (format) {
                                    _FinanceExportFormat.csv =>
                                      await _exportFinancePackCsv(
                                        l10n: l10n,
                                        state: state,
                                        snapshot: snapshot,
                                      ),
                                    _FinanceExportFormat.pdf =>
                                      await _exportFinancePackPdf(
                                        l10n: l10n,
                                        state: state,
                                        snapshot: snapshot,
                                      ),
                                  };

                                  if (!context.mounted) {
                                    return;
                                  }

                                  _showMessage(
                                    context,
                                    exported
                                        ? l10n.t('finance.exportPackSuccess')
                                        : l10n.t('common.dismiss'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (_activeTab == _FinanceTab.overview)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 1200;

                            if (stacked) {
                              return Column(
                                children: [
                                  _BreakEvenCalculator(state: state),
                                  const SizedBox(height: 24),
                                  _FinanceSummaryCard(state: state),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _BreakEvenCalculator(state: state),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: _FinanceSummaryCard(state: state),
                                ),
                              ],
                            );
                          },
                        )
                      else ...[
                        _ProFormaCard(projection: snapshot.projection),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: snapshot.ratios
                              .map(
                                (ratio) => SizedBox(
                                  width: 280,
                                  child: _RatioCard(ratio: ratio),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _FinanceExportFormat { csv, pdf }

Future<_FinanceExportFormat?> _chooseFinanceExportFormat(BuildContext context) {
  return showModalBottomSheet<_FinanceExportFormat>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(
                AdminLocaleController.globalT(
                  'finance.exportCsv',
                  fallback: 'CSV',
                ),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_FinanceExportFormat.csv),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(
                AdminLocaleController.globalT(
                  'finance.exportPdf',
                  fallback: 'PDF',
                ),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_FinanceExportFormat.pdf),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _exportFinancePackCsv({
  required AdminLocaleController l10n,
  required AdminAnalyticsState state,
  required dynamic snapshot,
}) async {
  final now = DateTime.now();
  final fileName = 'finance-pack-${now.year}-${now.month}.csv';
  final lines = <List<String>>[
    ['section', 'metric', 'value'],
    ['break_even', 'orders', '${state.breakEvenOrders}'],
    ['break_even', 'revenue', _formatEgp(state.breakEvenRevenue)],
    ['costs', 'server', state.serverCosts.toStringAsFixed(2)],
    ['costs', 'operating', state.operatingCosts.toStringAsFixed(2)],
    [
      'costs',
      'fixed_additional',
      state.additionalFixedCosts.toStringAsFixed(2),
    ],
    ['ratios', 'count', '${snapshot.ratios.length}'],
    ['projection', 'points', '${snapshot.projection.length}'],
  ];

  final csv = lines
      .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
      .join('\n');

  try {
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance export pack',
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

Future<bool> _exportFinancePackPdf({
  required AdminLocaleController l10n,
  required AdminAnalyticsState state,
  required dynamic snapshot,
}) async {
  final now = DateTime.now();
  final fileName = 'finance-pack-${now.year}-${now.month}.pdf';
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text('Finance Export Pack'),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${now.toIso8601String()}'),
        pw.SizedBox(height: 12),
        pw.Text('Break-even Orders: ${state.breakEvenOrders}'),
        pw.Text('Break-even Revenue: ${_formatEgp(state.breakEvenRevenue)}'),
        pw.Text('Server Costs: ${state.serverCosts.toStringAsFixed(2)}'),
        pw.Text('Operating Costs: ${state.operatingCosts.toStringAsFixed(2)}'),
        pw.Text(
          'Additional Fixed Costs: ${state.additionalFixedCosts.toStringAsFixed(2)}',
        ),
        pw.SizedBox(height: 12),
        pw.Text('Ratios: ${snapshot.ratios.length}'),
        pw.Text('Projection Points: ${snapshot.projection.length}'),
      ],
    ),
  );

  try {
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance export pack',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: await document.save(),
    );
    return saveResult != null;
  } catch (_) {
    return false;
  }
}

class _BreakEvenCalculator extends StatelessWidget {
  const _BreakEvenCalculator({required this.state});

  final AdminAnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminAnalyticsCubit>();
    final l10n = context.watch<AdminLocaleController>();
    final averageOrderMax = state.averageOrderValue <= 10000
        ? 10000.0
        : state.averageOrderValue * 1.25;

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('finance.breakEvenCalculatorTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('finance.breakEvenCalculatorDescription'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t(
              'finance.scenarioInputsNotice',
              fallback:
                  'Average order value and gross margin are local scenario inputs only. Save persists cost settings, not scenario sliders.',
            ),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _FinanceSlider(
            label: l10n.t('finance.serverCosts'),
            value: state.serverCosts,
            min: 0,
            max: state.serverCosts <= 12000 ? 12000 : state.serverCosts * 1.25,
            onChanged: cubit.updateServerCosts,
            suffix: AdminLocaleController.globalT('currency.symbol'),
          ),
          _FinanceSlider(
            label: l10n.t('finance.operatingCosts'),
            value: state.operatingCosts,
            min: 0,
            max: state.operatingCosts <= 24000
                ? 24000
                : state.operatingCosts * 1.25,
            onChanged: cubit.updateOperatingCosts,
            suffix: AdminLocaleController.globalT('currency.symbol'),
          ),
          _FinanceSlider(
            label: l10n.t(
              'finance.fixedCosts',
              fallback: 'Additional Fixed Costs',
            ),
            value: state.additionalFixedCosts,
            min: 0,
            max: state.additionalFixedCosts <= 24000
                ? 24000
                : state.additionalFixedCosts * 1.25,
            onChanged: cubit.updateAdditionalFixedCosts,
            suffix: AdminLocaleController.globalT('currency.symbol'),
          ),
          _FinanceSlider(
            label: l10n.t(
              'finance.averageOrderValueScenario',
              fallback: 'Average order value (scenario)',
            ),
            value: state.averageOrderValue,
            min: 0,
            max: averageOrderMax,
            onChanged: cubit.updateAverageOrderValue,
            suffix: AdminLocaleController.globalT('currency.symbol'),
          ),
          _FinanceSlider(
            label: l10n.t(
              'finance.grossMarginScenario',
              fallback: 'Gross margin (scenario)',
            ),
            value: state.grossMargin * 100,
            min: 0,
            max: 100,
            onChanged: (value) => cubit.updateGrossMargin(value / 100),
            suffix: '%',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _FinanceHighlight(
                label: l10n.t('finance.breakEvenOrders'),
                value: '${state.breakEvenOrders}',
              ),
              _FinanceHighlight(
                label: l10n.t('finance.revenueThreshold'),
                value: _formatEgp(state.breakEvenRevenue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceSlider extends StatefulWidget {
  const _FinanceSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.suffix,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String suffix;

  @override
  State<_FinanceSlider> createState() => _FinanceSliderState();
}

class _FinanceSliderState extends State<_FinanceSlider> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.round().toString());
  }

  @override
  void didUpdateWidget(covariant _FinanceSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !FocusScope.of(context).hasFocus) {
      _controller.text = widget.value.round().toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeValue = widget.value.clamp(widget.min, widget.max).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                widget.label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
              ),
              const Spacer(),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppTheme.secondary),
                  onSubmitted: (val) {
                    final parsed = double.tryParse(val);
                    final numVal = (parsed ?? safeValue)
                        .clamp(widget.min, widget.max)
                        .toDouble();
                    _controller.text = numVal.round().toString();
                    widget.onChanged(numVal);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.suffix,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.tertiary),
              ),
            ],
          ),
          Slider(
            value: safeValue,
            min: widget.min,
            max: widget.max,
            onChanged: (val) {
              _controller.text = val.round().toString();
              widget.onChanged(val);
            },
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _FinanceHighlight extends StatelessWidget {
  const _FinanceHighlight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 20,
      color: AppTheme.surfaceContainerLow,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({required this.state});

  final AdminAnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.primary, AppTheme.primaryContainer],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionLabel(
            label: l10n.t('finance.summaryLabel'),
            color: AppTheme.primaryFixed,
          ),
          const SizedBox(height: 12),
          Text(
            '${state.breakEvenOrders} ${l10n.t('finance.ordersWord')}',
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('finance.summaryDescription'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 20),
          AdminPill(
            label: l10n.t('finance.stableBadge'),
            backgroundColor: Color(0x33FFD9DD),
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _ProFormaCard extends StatelessWidget {
  const _ProFormaCard({required this.projection});

  final List<FinancePoint> projection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final maxSeriesValue = projection.isEmpty
        ? 0.0
        : projection
              .map(
                (point) =>
                    point.revenue > point.cost ? point.revenue : point.cost,
              )
              .reduce((a, b) => a > b ? a : b);
    final maxY = maxSeriesValue <= 0 ? 10.0 : maxSeriesValue * 1.2;
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('finance.proFormaTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('finance.proFormaDescription'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
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
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= projection.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.resolve(projection[index].label),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < projection.length; i++)
                        FlSpot(i.toDouble(), projection[i].revenue),
                    ],
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < projection.length; i++)
                        FlSpot(i.toDouble(), projection[i].cost),
                    ],
                    isCurved: true,
                    color: AppTheme.secondary,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
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

class _RatioCard extends StatelessWidget {
  const _RatioCard({required this.ratio});

  final FinanceRatio ratio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(24),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resolve(ratio.label).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.resolve(ratio.value),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppTheme.primary,
              fontSize: 38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.resolve(ratio.change),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.tertiary),
          ),
        ],
      ),
    );
  }
}

String _formatEgp(double value) {
  final locale = Intl.getCurrentLocale().toLowerCase();
  final isArabic = locale.startsWith('ar');
  final formatter = NumberFormat.currency(
    locale: isArabic ? 'ar_EG' : 'en_US',
    symbol: AdminLocaleController.globalT('currency.symbol'),
    decimalDigits: 0,
  );
  return formatter.format(value);
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}
