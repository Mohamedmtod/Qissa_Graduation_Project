import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

class AdminAiGaugeMetric extends Equatable {
  const AdminAiGaugeMetric({
    required this.title,
    required this.score,
    required this.scoreLabel,
    required this.subtitle,
    required this.description,
    required this.color,
  });

  final String title;
  final double score;
  final String scoreLabel;
  final String subtitle;
  final String description;
  final Color color;

  @override
  List<Object?> get props => [
    title,
    score,
    scoreLabel,
    subtitle,
    description,
    color,
  ];
}

class AdminAiHealthMetric extends Equatable {
  const AdminAiHealthMetric({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  List<Object?> get props => [label, value, progress, color];
}

class AdminAiFeedbackSummary extends Equatable {
  const AdminAiFeedbackSummary({
    required this.totalResponses,
    required this.positiveResponses,
    required this.negativeResponses,
    required this.withNotes,
    required this.satisfactionRate,
    required this.recentNotes,
    required this.windowLabel,
  });

  final int totalResponses;
  final int positiveResponses;
  final int negativeResponses;
  final int withNotes;
  final double satisfactionRate;
  final List<String> recentNotes;
  final String windowLabel;

  @override
  List<Object?> get props => [
    totalResponses,
    positiveResponses,
    negativeResponses,
    withNotes,
    satisfactionRate,
    recentNotes,
    windowLabel,
  ];
}

class AdminAiFeedbackReasonStat extends Equatable {
  const AdminAiFeedbackReasonStat({required this.reason, required this.count});

  final String reason;
  final int count;

  @override
  List<Object?> get props => [reason, count];
}

class AdminAiFeedbackAnalytics extends Equatable {
  const AdminAiFeedbackAnalytics({
    required this.totalFeedback,
    required this.positiveFeedback,
    required this.negativeFeedback,
    required this.neutralFeedback,
    required this.topReasons,
    required this.recentNegativePreviews,
    required this.analysisStatusCounts,
  });

  final int totalFeedback;
  final int positiveFeedback;
  final int negativeFeedback;
  final int neutralFeedback;
  final List<AdminAiFeedbackReasonStat> topReasons;
  final List<String> recentNegativePreviews;
  final Map<String, int> analysisStatusCounts;

  @override
  List<Object?> get props => [
    totalFeedback,
    positiveFeedback,
    negativeFeedback,
    neutralFeedback,
    topReasons,
    recentNegativePreviews,
    analysisStatusCounts,
  ];
}

class AdminAiKpiSummary extends Equatable {
  const AdminAiKpiSummary({
    required this.windowLabel,
    required this.totalSessions,
    required this.activeSessions,
    required this.endedSessions,
    required this.uniqueUsers,
    required this.totalMessages,
    required this.userMessages,
    required this.assistantMessages,
    required this.intentUnderstoodRate,
    required this.needSatisfiedRate,
    required this.hasAnalysisMetrics,
    required this.averageSatisfactionScore,
    required this.positiveSentimentRate,
    required this.neutralSentimentRate,
    required this.negativeSentimentRate,
    required this.feedbackUpRate,
    required this.fallbackNoMatchRate,
    required this.recommendationRate,
    required this.answerRate,
    required this.resolutionRate,
    required this.fallbackRate,
    required this.noMatchRate,
    required this.conversionRate,
    required this.feedbackCoverageRate,
    required this.notifyMeRate,
    required this.avgTurnsPerSession,
    required this.avgMessagesPerSession,
    required this.avgSessionDurationMinutes,
    required this.avgAssistantResponseSeconds,
    required this.avgUserMessageLength,
    required this.avgAssistantMessageLength,
    required this.sessionsWithRecommendations,
    required this.sessionsWithAnswers,
    required this.sessionsWithFallback,
    required this.sessionsWithNoMatch,
    required this.sessionsWithFeedback,
    required this.sessionsWithConversion,
    required this.sessionsWithNotifyMe,
  });

  final String windowLabel;
  final int totalSessions;
  final int activeSessions;
  final int endedSessions;
  final int uniqueUsers;
  final int totalMessages;
  final int userMessages;
  final int assistantMessages;
  final double intentUnderstoodRate;
  final double needSatisfiedRate;
  final bool hasAnalysisMetrics;
  final double averageSatisfactionScore;
  final double positiveSentimentRate;
  final double neutralSentimentRate;
  final double negativeSentimentRate;
  final double feedbackUpRate;
  final double fallbackNoMatchRate;
  final double recommendationRate;
  final double answerRate;
  final double resolutionRate;
  final double fallbackRate;
  final double noMatchRate;
  final double conversionRate;
  final double feedbackCoverageRate;
  final double notifyMeRate;
  final double avgTurnsPerSession;
  final double avgMessagesPerSession;
  final double avgSessionDurationMinutes;
  final double avgAssistantResponseSeconds;
  final double avgUserMessageLength;
  final double avgAssistantMessageLength;
  final int sessionsWithRecommendations;
  final int sessionsWithAnswers;
  final int sessionsWithFallback;
  final int sessionsWithNoMatch;
  final int sessionsWithFeedback;
  final int sessionsWithConversion;
  final int sessionsWithNotifyMe;

  @override
  List<Object?> get props => [
    windowLabel,
    totalSessions,
    activeSessions,
    endedSessions,
    uniqueUsers,
    totalMessages,
    userMessages,
    assistantMessages,
    intentUnderstoodRate,
    needSatisfiedRate,
    hasAnalysisMetrics,
    averageSatisfactionScore,
    positiveSentimentRate,
    neutralSentimentRate,
    negativeSentimentRate,
    feedbackUpRate,
    fallbackNoMatchRate,
    recommendationRate,
    answerRate,
    resolutionRate,
    fallbackRate,
    noMatchRate,
    conversionRate,
    feedbackCoverageRate,
    notifyMeRate,
    avgTurnsPerSession,
    avgMessagesPerSession,
    avgSessionDurationMinutes,
    avgAssistantResponseSeconds,
    avgUserMessageLength,
    avgAssistantMessageLength,
    sessionsWithRecommendations,
    sessionsWithAnswers,
    sessionsWithFallback,
    sessionsWithNoMatch,
    sessionsWithFeedback,
    sessionsWithConversion,
    sessionsWithNotifyMe,
  ];
}

class AdminAiIssueStat extends Equatable {
  const AdminAiIssueStat({
    required this.code,
    required this.count,
    required this.ratio,
  });

  final String code;
  final int count;
  final double ratio;

  @override
  List<Object?> get props => [code, count, ratio];
}

class AdminAiSessionLog extends Equatable {
  const AdminAiSessionLog({
    required this.shortSessionId,
    required this.startedAt,
    required this.endedAt,
    required this.turns,
    required this.messages,
    required this.durationMinutes,
    required this.outcome,
    required this.intentConfidenceScore,
    required this.issueTags,
    required this.feedbackValue,
    required this.hasOrderConversion,
  });

  final String shortSessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int turns;
  final int messages;
  final double durationMinutes;
  final String outcome;
  final double intentConfidenceScore;
  final List<String> issueTags;
  final String feedbackValue;
  final bool hasOrderConversion;

  @override
  List<Object?> get props => [
    shortSessionId,
    startedAt,
    endedAt,
    turns,
    messages,
    durationMinutes,
    outcome,
    intentConfidenceScore,
    issueTags,
    feedbackValue,
    hasOrderConversion,
  ];
}

class AdminAiInsightsSnapshot extends Equatable {
  const AdminAiInsightsSnapshot({
    required this.gaugeMetrics,
    required this.feedbackSummary,
    required this.feedbackAnalytics,
    required this.kpiSummary,
    required this.recurringIssues,
    required this.sessionLogs,
    required this.themes,
    required this.dialogueTurns,
    required this.annotations,
    required this.vocabularyTags,
    required this.healthMetrics,
    required this.lastSyncLabel,
  });

  final List<AdminAiGaugeMetric> gaugeMetrics;
  final AdminAiFeedbackSummary feedbackSummary;
  final AdminAiFeedbackAnalytics feedbackAnalytics;
  final AdminAiKpiSummary kpiSummary;
  final List<AdminAiIssueStat> recurringIssues;
  final List<AdminAiSessionLog> sessionLogs;
  final List<InsightTheme> themes;
  final List<DialogueTurn> dialogueTurns;
  final List<InsightAnnotation> annotations;
  final List<String> vocabularyTags;
  final List<AdminAiHealthMetric> healthMetrics;
  final String lastSyncLabel;

  @override
  List<Object?> get props => [
    gaugeMetrics,
    feedbackSummary,
    feedbackAnalytics,
    kpiSummary,
    recurringIssues,
    sessionLogs,
    themes,
    dialogueTurns,
    annotations,
    vocabularyTags,
    healthMetrics,
    lastSyncLabel,
  ];
}
