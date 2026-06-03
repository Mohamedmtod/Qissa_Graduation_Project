import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_ai_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_ai_insights_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_ai_insights_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/utils/admin_export_utils.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class AiInsightsPage extends StatelessWidget {
  const AiInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminAiInsightsCubit(context.read<AdminAiInsightsRepository>())
            ..loadInsights(),
      child: const _AiInsightsView(),
    );
  }
}

enum _AiTopTab { overview, analytics }

enum _DialogueFilter { all, aiOnly, userOnly }

class _AiInsightsView extends StatefulWidget {
  const _AiInsightsView();

  @override
  State<_AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<_AiInsightsView> {
  _AiTopTab _activeTab = _AiTopTab.analytics;
  _DialogueFilter _dialogueFilter = _DialogueFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Column(
      children: [
        SharedTopbar(
          title: l10n.t('ai.topbarTitle'),
          searchHint: l10n.t('ai.searchHint'),
          tabs: [
            TopbarTab(
              label: l10n.t('common.overview'),
              active: _activeTab == _AiTopTab.overview,
              onTap: () => setState(() => _activeTab = _AiTopTab.overview),
            ),
            TopbarTab(
              label: l10n.t('common.analytics'),
              active: _activeTab == _AiTopTab.analytics,
              onTap: () => setState(() => _activeTab = _AiTopTab.analytics),
            ),
          ],
        ),
        Expanded(
          child: BlocBuilder<AdminAiInsightsCubit, AdminAiInsightsState>(
            builder: (context, state) {
              final snapshot = state.snapshot;
              if (state.isLoading && snapshot == null) {
                return AdminLoadingState(title: l10n.t('ai.loadingTitle'));
              }

              if (state.errorMessage != null) {
                return AdminErrorState(
                  title: l10n.t('ai.errorTitle'),
                  message: state.errorMessage!,
                  onRetry: () =>
                      context.read<AdminAiInsightsCubit>().loadInsights(),
                );
              }

              if (snapshot == null) {
                return AdminEmptyState(
                  title: l10n.t('ai.emptyTitle'),
                  message: l10n.t('ai.emptyMessage'),
                  actionLabel: l10n.t('common.retry'),
                  onAction: () =>
                      context.read<AdminAiInsightsCubit>().loadInsights(),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
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
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('ai.heroTitle'),
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      color: AppTheme.onSurface,
                                      fontSize: 44,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.t('ai.heroDescription'),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            AdminSecondaryButton(
                              label: l10n.t('ai.downloadReport'),
                              onPressed: () async {
                                final exported = await _exportAiReportCsv(
                                  l10n: l10n,
                                  snapshot: snapshot,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                _showMessage(
                                  context,
                                  exported
                                      ? l10n.t('ai.downloadReportSuccess')
                                      : l10n.t('common.dismiss'),
                                );
                              },
                            ),
                            AdminPrimaryButton(
                              label: l10n.t('ai.trainModel'),
                              onPressed: state.isTraining
                                  ? null
                                  : () async {
                                      final queued = await context
                                          .read<AdminAiInsightsCubit>()
                                          .trainModel();
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _showMessage(
                                        context,
                                        queued
                                            ? l10n.t('ai.trainModelQueued')
                                            : l10n.t('common.retry'),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (_activeTab == _AiTopTab.overview) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumn = constraints.maxWidth >= 1100;
                          final cardWidth = twoColumn
                              ? (constraints.maxWidth - 48) / 3
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            children: [
                              ...snapshot.gaugeMetrics.map(
                                (metric) => SizedBox(
                                  width: cardWidth,
                                  child: _GaugeCard(metric: metric),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ThemesCard(
                                  themes: snapshot.themes,
                                  lastSyncLabel: snapshot.lastSyncLabel,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _AiFeedbackSection(summary: snapshot.feedbackSummary),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 1000;

                          if (stacked) {
                            return Column(
                              children: [
                                _VocabularyTrendsCard(
                                  vocabularyTags: snapshot.vocabularyTags,
                                ),
                                const SizedBox(height: 24),
                                _ModelHealthCard(
                                  healthMetrics: snapshot.healthMetrics,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _VocabularyTrendsCard(
                                  vocabularyTags: snapshot.vocabularyTags,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _ModelHealthCard(
                                  healthMetrics: snapshot.healthMetrics,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      _AiKpiSection(summary: snapshot.kpiSummary),
                      const SizedBox(height: 20),
                      _AiFeedbackAnalyticsSection(
                        analytics: snapshot.feedbackAnalytics,
                      ),
                      const SizedBox(height: 20),
                      _AiOperationalMetricsSection(
                        summary: snapshot.kpiSummary,
                      ),
                      const SizedBox(height: 20),
                      _AiRecurringIssuesSection(
                        issues: snapshot.recurringIssues,
                      ),
                      const SizedBox(height: 20),
                      _AiSessionLogsSection(logs: snapshot.sessionLogs),
                      const SizedBox(height: 28),
                      _DialogueAnalysisCard(
                        dialogueTurns: _filterDialogueTurns(
                          snapshot.dialogueTurns,
                        ),
                        annotations: snapshot.annotations,
                        onFilterTap: () => _showDialogueFilter(context),
                        onMoreTap: () => _showDialogueMoreMenu(
                          context,
                          _filterDialogueTurns(snapshot.dialogueTurns),
                        ),
                        onAnnotate: () => _showAnnotationDialog(
                          context,
                          snapshot.sessionLogs.isEmpty
                              ? 'latest-session'
                              : snapshot.sessionLogs.first.shortSessionId,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<DialogueTurn> _filterDialogueTurns(List<DialogueTurn> source) {
    return switch (_dialogueFilter) {
      _DialogueFilter.all => source,
      _DialogueFilter.aiOnly => source.where((t) => t.isAi).toList(),
      _DialogueFilter.userOnly => source.where((t) => !t.isAi).toList(),
    };
  }

  void _showDialogueFilter(BuildContext context) {
    final l10n = context.read<AdminLocaleController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.t('ai.filters.allTurns')),
                trailing: _dialogueFilter == _DialogueFilter.all
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _dialogueFilter = _DialogueFilter.all);
                },
              ),
              ListTile(
                title: Text(l10n.t('ai.filters.aiOnly')),
                trailing: _dialogueFilter == _DialogueFilter.aiOnly
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _dialogueFilter = _DialogueFilter.aiOnly);
                },
              ),
              ListTile(
                title: Text(l10n.t('ai.filters.userOnly')),
                trailing: _dialogueFilter == _DialogueFilter.userOnly
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _dialogueFilter = _DialogueFilter.userOnly);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDialogueMoreMenu(BuildContext context, List<DialogueTurn> turns) {
    final l10n = context.read<AdminLocaleController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(l10n.t('ai.copySessionSummary')),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(
                    ClipboardData(text: _buildDialogueSummary(turns)),
                  );
                  if (context.mounted) {
                    _showMessage(context, l10n.t('ai.copySessionSuccess'));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.t('ai.exportFilteredTurns')),
                enabled: turns.isNotEmpty,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final exported = await _exportFilteredTurnsCsv(turns);
                  if (context.mounted) {
                    _showMessage(
                      context,
                      exported
                          ? l10n.t('ai.exportFilteredTurnsSuccess')
                          : l10n.t('common.dismiss'),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiFeedbackSection extends StatelessWidget {
  const _AiFeedbackSection({required this.summary});

  final AdminAiFeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final satisfactionText =
        '${(summary.satisfactionRate * 100).toStringAsFixed(0)}%';

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(24),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.t('ai.feedback.sectionTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const Spacer(),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.windowLabel')} ${summary.windowLabel}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.satisfaction')}: $satisfactionText',
                backgroundColor: AppTheme.primaryContainer.withValues(
                  alpha: 0.30,
                ),
                foregroundColor: AppTheme.primary,
              ),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.totalResponses')}: ${summary.totalResponses}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.onSurface,
              ),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.positive')}: ${summary.positiveResponses}',
                backgroundColor: const Color(0xFFEAF8ED),
                foregroundColor: const Color(0xFF1A7F37),
              ),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.negative')}: ${summary.negativeResponses}',
                backgroundColor: const Color(0xFFFDECEC),
                foregroundColor: const Color(0xFFA61B1B),
              ),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.withNotes')}: ${summary.withNotes}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.onSurface,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('ai.feedback.recentNotes'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          if (summary.recentNotes.isEmpty)
            Text(
              l10n.t('ai.feedback.noNotes'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...summary.recentNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.subdirectory_arrow_right,
                        size: 16,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: Theme.of(context).textTheme.bodyMedium,
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

class _AiKpiSection extends StatelessWidget {
  const _AiKpiSection({required this.summary});

  final AdminAiKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.t('ai.kpi.sectionTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const Spacer(),
              AdminPill(
                label:
                    '${l10n.t('ai.feedback.windowLabel')} ${summary.windowLabel}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t(
              'ai.sampledDataNotice',
              fallback:
                  'AI insight KPIs are based on capped Firestore reads within the current window and should not be treated as complete historical metrics.',
            ),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.intentUnderstood')}: ${_percent(summary.intentUnderstoodRate)}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.needSatisfied')}: ${_percent(summary.needSatisfiedRate)}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.feedbackUp')}: ${_percent(summary.feedbackUpRate)}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.averageSatisfaction')}: ${summary.hasAnalysisMetrics ? _percent(summary.averageSatisfactionScore) : l10n.t('common.notAvailable')}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.sentimentDistribution')}: ${summary.hasAnalysisMetrics ? '${_percent(summary.positiveSentimentRate)} / ${_percent(summary.neutralSentimentRate)} / ${_percent(summary.negativeSentimentRate)}' : l10n.t('common.notAvailable')}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.fallbackNoMatch')}: ${_percent(summary.fallbackNoMatchRate)}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.totalSessions')}: ${summary.totalSessions}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.uniqueUsers')}: ${summary.uniqueUsers}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.recommendationRate')}: ${_percent(summary.recommendationRate)}',
              ),
              _kpiPill(
                context,
                '${l10n.t('ai.kpi.resolutionRate')}: ${_percent(summary.resolutionRate)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  AdminPill _kpiPill(BuildContext context, String label) {
    return AdminPill(
      label: label,
      backgroundColor: AppTheme.surfaceContainerHighest,
      foregroundColor: AppTheme.onSurface,
    );
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
}

class _AiFeedbackAnalyticsSection extends StatelessWidget {
  const _AiFeedbackAnalyticsSection({required this.analytics});

  final AdminAiFeedbackAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final statusEntries = analytics.analysisStatusCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI feedback analytics',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminPill(
                label: 'Total: ${analytics.totalFeedback}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.onSurface,
              ),
              AdminPill(
                label: 'Positive: ${analytics.positiveFeedback}',
                backgroundColor: const Color(0xFFEAF8ED),
                foregroundColor: const Color(0xFF1A7F37),
              ),
              AdminPill(
                label: 'Negative: ${analytics.negativeFeedback}',
                backgroundColor: const Color(0xFFFDECEC),
                foregroundColor: const Color(0xFFA61B1B),
              ),
              AdminPill(
                label: 'Neutral: ${analytics.neutralFeedback}',
                backgroundColor: AppTheme.surfaceContainerHighest,
                foregroundColor: AppTheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Top feedback reasons',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (analytics.topReasons.isEmpty)
            Text(
              'No feedback reasons yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: analytics.topReasons
                  .map(
                    (reason) => AdminPill(
                      label: '${reason.reason} (${reason.count})',
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.onSurface,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          Text(
            'Analysis status',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (statusEntries.isEmpty)
            Text(
              'No analyzed feedback yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: statusEntries
                  .map(
                    (entry) => AdminPill(
                      label: '${entry.key}: ${entry.value}',
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.onSurface,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          Text(
            'Recent negative feedback',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (analytics.recentNegativePreviews.isEmpty)
            Text(
              'No recent negative notes.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...analytics.recentNegativePreviews.map(
              (preview) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  preview,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiOperationalMetricsSection extends StatelessWidget {
  const _AiOperationalMetricsSection({required this.summary});

  final AdminAiKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final metrics = <_MetricTileData>[
      _MetricTileData(
        title: l10n.t('ai.ops.activeSessions'),
        value: '${summary.activeSessions}/${summary.totalSessions}',
        subtitle:
            '${_ratioPercent(summary.activeSessions, summary.totalSessions)} ${l10n.t('ai.ops.ofWindow')}',
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.endedSessions'),
        value: '${summary.endedSessions}/${summary.totalSessions}',
        subtitle:
            '${_ratioPercent(summary.endedSessions, summary.totalSessions)} ${l10n.t('ai.ops.ofWindow')}',
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.messages'),
        value:
            '${summary.totalMessages} (${summary.userMessages}/${summary.assistantMessages})',
        subtitle: l10n.t('ai.ops.messagesSplit'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgTurns'),
        value: _decimal(summary.avgTurnsPerSession),
        subtitle: l10n.t('ai.ops.avgTurnsSubtitle'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgMessages'),
        value: _decimal(summary.avgMessagesPerSession),
        subtitle: l10n.t('ai.ops.avgMessagesSubtitle'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgSessionDuration'),
        value: '${_decimal(summary.avgSessionDurationMinutes)}m',
        subtitle: l10n.t('ai.ops.avgSessionDurationSubtitle'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgAssistantResponse'),
        value: '${_decimal(summary.avgAssistantResponseSeconds)}s',
        subtitle: l10n.t('ai.ops.avgAssistantResponseSubtitle'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgUserMessageLength'),
        value: _decimal(summary.avgUserMessageLength),
        subtitle: l10n.t('ai.ops.characters'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.avgAssistantMessageLength'),
        value: _decimal(summary.avgAssistantMessageLength),
        subtitle: l10n.t('ai.ops.characters'),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.recommendations'),
        value: '${summary.sessionsWithRecommendations}',
        subtitle: _percent(summary.recommendationRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.answers'),
        value: '${summary.sessionsWithAnswers}',
        subtitle: _percent(summary.answerRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.fallbacks'),
        value: '${summary.sessionsWithFallback}',
        subtitle: _percent(summary.fallbackRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.noMatches'),
        value: '${summary.sessionsWithNoMatch}',
        subtitle: _percent(summary.noMatchRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.feedbackCoverage'),
        value: '${summary.sessionsWithFeedback}',
        subtitle: _percent(summary.feedbackCoverageRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.conversions'),
        value: '${summary.sessionsWithConversion}',
        subtitle: _percent(summary.conversionRate),
      ),
      _MetricTileData(
        title: l10n.t('ai.ops.notifyMe'),
        value: '${summary.sessionsWithNotifyMe}',
        subtitle: _percent(summary.notifyMeRate),
      ),
    ];

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ai.ops.sectionTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 800
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 2;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: _MetricTile(metric: metric),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(0)}%';

  String _decimal(double value) => value.toStringAsFixed(value >= 10 ? 1 : 2);

  String _ratioPercent(int part, int total) {
    if (total == 0) return '0%';
    return '${((part / total) * 100).toStringAsFixed(0)}%';
  }
}

class _AiRecurringIssuesSection extends StatelessWidget {
  const _AiRecurringIssuesSection({required this.issues});

  final List<AdminAiIssueStat> issues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ai.issues.sectionTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            Text(
              l10n.t('ai.issues.empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: issues
                  .map(
                    (issue) => AdminPill(
                      label:
                          '${issue.code} (${issue.count}, ${(issue.ratio * 100).toStringAsFixed(0)}%)',
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.onSurface,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AiSessionLogsSection extends StatefulWidget {
  const _AiSessionLogsSection({required this.logs});

  final List<AdminAiSessionLog> logs;

  @override
  State<_AiSessionLogsSection> createState() => _AiSessionLogsSectionState();
}

class _AiSessionLogsSectionState extends State<_AiSessionLogsSection> {
  static const int _pageSize = 25;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final logs = widget.logs;
    final totalPages = logs.isEmpty ? 1 : ((logs.length - 1) ~/ _pageSize) + 1;
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final start = (_page * _pageSize).clamp(0, logs.length);
    final end = (start + _pageSize).clamp(0, logs.length);
    final visibleLogs = logs.sublist(start, end);
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ai.logs.sectionTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Text(
              l10n.t('ai.logs.empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(l10n.t('ai.logs.session'))),
                  DataColumn(label: Text(l10n.t('ai.logs.turns'))),
                  DataColumn(label: Text(l10n.t('ai.logs.messages'))),
                  DataColumn(label: Text(l10n.t('ai.logs.duration'))),
                  DataColumn(label: Text(l10n.t('ai.logs.outcome'))),
                  DataColumn(label: Text(l10n.t('ai.logs.intentScore'))),
                  DataColumn(label: Text(l10n.t('ai.logs.issues'))),
                  DataColumn(label: Text(l10n.t('ai.logs.feedback'))),
                  DataColumn(label: Text(l10n.t('ai.logs.conversion'))),
                ],
                rows: visibleLogs
                    .map(
                      (log) => DataRow(
                        cells: [
                          DataCell(Text(log.shortSessionId)),
                          DataCell(Text(log.turns.toString())),
                          DataCell(Text(log.messages.toString())),
                          DataCell(
                            Text('${log.durationMinutes.toStringAsFixed(1)}m'),
                          ),
                          DataCell(Text(log.outcome)),
                          DataCell(
                            Text(
                              '${(log.intentConfidenceScore * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                          DataCell(Text(log.issueTags.join(', '))),
                          DataCell(Text(log.feedbackValue)),
                          DataCell(
                            Text(
                              log.hasOrderConversion
                                  ? l10n.t('common.yes')
                                  : l10n.t('common.no'),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          if (logs.length > _pageSize) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${_page + 1} / $totalPages'),
                const SizedBox(width: 12),
                AdminSecondaryButton(
                  label: l10n.t('common.back'),
                  onPressed: _page == 0
                      ? null
                      : () => setState(() => _page -= 1),
                ),
                const SizedBox(width: 8),
                AdminSecondaryButton(
                  label: l10n.t('common.next'),
                  onPressed: _page >= totalPages - 1
                      ? null
                      : () => setState(() => _page += 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.metric});

  final AdminAiGaugeMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Text(
            l10n.resolve(metric.title).toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: metric.score,
                  strokeWidth: 12,
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(metric.color),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.resolve(metric.scoreLabel),
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: AppTheme.onSurface, fontSize: 36),
                      ),
                      Text(
                        l10n.resolve(metric.subtitle),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.resolve(metric.description),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricTileData metric;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ThemesCard extends StatelessWidget {
  const _ThemesCard({required this.themes, required this.lastSyncLabel});

  final List<InsightTheme> themes;
  final String lastSyncLabel;

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
            l10n.t('ai.themesTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 22),
          if (themes.isEmpty)
            AdminEmptyState(
              title: l10n.t('ai.emptyTitle'),
              message: l10n.t('ai.emptyMessage'),
              icon: Icons.insights_outlined,
            )
          else
            ...themes.map((theme) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(theme.icon, color: AppTheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resolve(theme.title),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppTheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.resolve(theme.description)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                l10n.t('ai.lastSync'),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
              ),
              const Spacer(),
              Text(
                l10n.resolve(lastSyncLabel),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogueAnalysisCard extends StatelessWidget {
  const _DialogueAnalysisCard({
    required this.dialogueTurns,
    required this.annotations,
    required this.onFilterTap,
    required this.onMoreTap,
    required this.onAnnotate,
  });

  final List<DialogueTurn> dialogueTurns;
  final List<InsightAnnotation> annotations;
  final VoidCallback onFilterTap;
  final VoidCallback onMoreTap;
  final VoidCallback onAnnotate;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: EdgeInsets.zero,
      color: AppTheme.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1180;

          if (stacked) {
            return Column(
              children: [
                _DialogueCanvas(
                  dialogueTurns: dialogueTurns,
                  onFilterTap: onFilterTap,
                  onMoreTap: onMoreTap,
                ),
                const Divider(height: 1),
                _InsightSidebar(
                  annotations: annotations,
                  onAnnotate: onAnnotate,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 8,
                child: _DialogueCanvas(
                  dialogueTurns: dialogueTurns,
                  onFilterTap: onFilterTap,
                  onMoreTap: onMoreTap,
                ),
              ),
              Expanded(
                flex: 4,
                child: _InsightSidebar(
                  annotations: annotations,
                  onAnnotate: onAnnotate,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DialogueCanvas extends StatelessWidget {
  const _DialogueCanvas({
    required this.dialogueTurns,
    required this.onFilterTap,
    required this.onMoreTap,
  });

  final List<DialogueTurn> dialogueTurns;
  final VoidCallback onFilterTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Text(
                l10n.t('ai.dialogueAnalysis'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _MiniIconButton(icon: Icons.filter_list, onTap: onFilterTap),
                  _MiniIconButton(icon: Icons.more_vert, onTap: onMoreTap),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (dialogueTurns.isEmpty)
            AdminEmptyState(
              title: l10n.t('ai.emptyTitle'),
              message: l10n.t('ai.emptyMessage'),
              icon: Icons.forum_outlined,
            )
          else
            ...dialogueTurns.map((turn) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Align(
                  alignment: turn.isAi
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: turn.isAi
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.resolve(turn.speaker)} - ${l10n.resolve(turn.time)}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(letterSpacing: 1.3),
                        ),
                        const SizedBox(height: 8),
                        AdminSurfaceCard(
                          padding: const EdgeInsets.all(20),
                          color: turn.isAi
                              ? AppTheme.primary
                              : AppTheme.surfaceContainerLowest,
                          borderRadius: 20,
                          child: Text(
                            l10n.resolve(turn.message),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: turn.isAi
                                      ? Colors.white
                                      : AppTheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _InsightSidebar extends StatelessWidget {
  const _InsightSidebar({required this.annotations, required this.onAnnotate});

  final List<InsightAnnotation> annotations;
  final VoidCallback onAnnotate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Container(
      color: AppTheme.surfaceContainer,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (annotations.isEmpty)
            AdminEmptyState(
              title: l10n.t('ai.issues.sectionTitle'),
              message: l10n.t('ai.issues.empty'),
              icon: Icons.fact_check_outlined,
            )
          else
            ...annotations.map((annotation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: _AnnotationBlock(annotation: annotation),
              );
            }),
          SizedBox(
            width: double.infinity,
            child: AdminSecondaryButton(
              label: l10n.t('ai.annotateSession'),
              onPressed: onAnnotate,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationBlock extends StatelessWidget {
  const _AnnotationBlock({required this.annotation});

  final InsightAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 94,
          decoration: BoxDecoration(
            color: annotation.color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.resolve(annotation.title).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: annotation.color,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.resolve(annotation.description),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: annotation.tags
                    .map(
                      (tag) => AdminPill(
                        label: l10n.resolve(tag),
                        backgroundColor: AppTheme.surfaceContainerHighest,
                        foregroundColor: AppTheme.primary,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VocabularyTrendsCard extends StatelessWidget {
  const _VocabularyTrendsCard({required this.vocabularyTags});

  final List<String> vocabularyTags;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ai.vocabularyTrendsTitle'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('ai.vocabularyTrendsDescription'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (vocabularyTags.isEmpty)
            AdminEmptyState(
              title: l10n.t('ai.emptyTitle'),
              message: l10n.t('ai.emptyMessage'),
              icon: Icons.sell_outlined,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vocabularyTags
                  .map(
                    (tag) => AdminPill(
                      label: l10n.resolve(tag),
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.primary,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ModelHealthCard extends StatelessWidget {
  const _ModelHealthCard({required this.healthMetrics});

  final List<AdminAiHealthMetric> healthMetrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (healthMetrics.isEmpty)
            AdminEmptyState(
              title: l10n.t('ai.emptyTitle'),
              message: l10n.t('ai.emptyMessage'),
              icon: Icons.monitor_heart_outlined,
            )
          else
            for (var i = 0; i < healthMetrics.length; i++) ...[
              _HealthRow(metric: healthMetrics[i]),
              if (i != healthMetrics.length - 1) const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.metric});

  final AdminAiHealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Column(
      children: [
        Row(
          children: [
            Text(
              l10n.resolve(metric.label),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
            ),
            const Spacer(),
            Text(
              l10n.resolve(metric.value),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: metric.progress,
            backgroundColor: AppTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(metric.color),
          ),
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

Future<bool> _exportAiReportCsv({
  required AdminLocaleController l10n,
  required AdminAiInsightsSnapshot snapshot,
}) async {
  final now = DateTime.now();
  final fileName = 'ai-insights-report-${now.year}-${now.month}.csv';
  final lines = <List<String>>[
    ['section', 'field1', 'field2', 'field3'],
    ['meta', 'generatedAt', now.toIso8601String(), ''],
    ...snapshot.gaugeMetrics.map(
      (m) => [
        'gauge',
        l10n.resolve(m.title),
        l10n.resolve(m.scoreLabel),
        l10n.resolve(m.subtitle),
      ],
    ),
    ...snapshot.sessionLogs.map(
      (log) => [
        'session',
        log.shortSessionId,
        log.outcome,
        (log.intentConfidenceScore * 100).toStringAsFixed(0),
      ],
    ),
    [
      'kpi',
      'recommendationRate',
      (snapshot.kpiSummary.recommendationRate * 100).toStringAsFixed(0),
      '',
    ],
    [
      'kpi',
      'resolutionRate',
      (snapshot.kpiSummary.resolutionRate * 100).toStringAsFixed(0),
      '',
    ],
    [
      'kpi',
      'avgAssistantResponseSeconds',
      snapshot.kpiSummary.avgAssistantResponseSeconds.toStringAsFixed(2),
      '',
    ],
  ];

  final csv = lines
      .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
      .join('\n');

  try {
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save AI insights report',
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

String _buildDialogueSummary(List<DialogueTurn> turns) {
  if (turns.isEmpty) {
    return 'No filtered dialogue turns available.';
  }
  return turns
      .map((turn) => '${turn.time} | ${turn.speaker}: ${turn.message}')
      .join('\n');
}

Future<bool> _exportFilteredTurnsCsv(List<DialogueTurn> turns) {
  final now = DateTime.now();
  final csv = buildCsv([
    ['speaker', 'time', 'isAi', 'message'],
    ...turns.map((turn) => [turn.speaker, turn.time, turn.isAi, turn.message]),
  ]);
  return saveTextFile(
    dialogTitle: 'Save filtered dialogue turns',
    fileName: 'ai-filtered-turns-${now.year}-${now.month}-${now.day}.csv',
    extension: 'csv',
    content: csv,
  );
}

Future<void> _showAnnotationDialog(
  BuildContext context,
  String sessionId,
) async {
  final l10n = context.read<AdminLocaleController>();
  final repository = context.read<AdminAiInsightsRepository>();
  final controller = TextEditingController();
  final note = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.t('ai.annotationDialogTitle')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.t('ai.annotationNoteLabel'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          AdminPrimaryButton(
            label: l10n.t('ai.saveAnnotation'),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
          ),
        ],
      );
    },
  );
  controller.dispose();

  if (note == null || note.isEmpty) {
    return;
  }

  try {
    await repository.saveSessionAnnotation(sessionId: sessionId, note: note);
    if (context.mounted) {
      _showMessage(context, l10n.t('ai.annotationSaved'));
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, l10n.t('ai.annotationFailed'));
    }
  }
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}
