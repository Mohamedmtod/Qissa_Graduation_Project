import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_ai_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';

abstract class AdminAiInsightsService {
  Future<AdminAiInsightsSnapshot> fetchInsightsSnapshot();
  Future<void> queueModelTraining();
  Future<void> saveSessionAnnotation({
    required String sessionId,
    required String note,
    required String actorId,
  });
}

class FirestoreAdminAiInsightsService implements AdminAiInsightsService {
  FirestoreAdminAiInsightsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _window = Duration(days: 30);
  static const int _eventFetchLimit = 2000;
  static const int _sessionFetchLimit = 1200;
  static const int _messageFetchLimit = 2500;
  static const int _analysisFetchLimit = 1200;
  static const int _feedbackFetchLimit = 1200;
  static const int _conversionFetchLimit = 1200;

  @override
  Future<AdminAiInsightsSnapshot> fetchInsightsSnapshot() async {
    final now = DateTime.now();
    final windowStart = now.subtract(_window);

    final results = await Future.wait<Object>([
      _fetchEventDocs(windowStart),
      _fetchSessionDocs(windowStart),
      _fetchMessageDocs(windowStart),
      _fetchAnalysisAggregate(windowStart),
      _fetchFeedbackSummary(windowStart),
      _fetchFeedbackAnalytics(windowStart),
      _fetchFeedbackBySession(windowStart),
      _fetchConversionContext(windowStart),
    ]);

    final events =
        results[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final sessionDocs =
        results[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final messageDocs =
        results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
    final analysisAggregate = results[3] as _AnalysisAggregate;
    final feedbackSummary = results[4] as AdminAiFeedbackSummary;
    final feedbackAnalytics = results[5] as AdminAiFeedbackAnalytics;
    final sessionFeedback = results[6] as Map<String, String>;
    final conversionContext = results[7] as _ConversionContext;

    final sessions = _buildSessions(events);
    _mergePersistedSessions(sessions, sessionDocs);
    _mergePersistedMessages(sessions, messageDocs);

    for (final aggregate in sessions.values) {
      aggregate.feedbackValue = sessionFeedback[aggregate.sessionId] ?? 'none';
      aggregate.hasOrderConversion = aggregate.userId.isNotEmpty
          ? conversionContext.convertedUserIds.contains(aggregate.userId)
          : false;
    }

    final sessionList = sessions.values.toList();
    final kpiSummary = _buildKpiSummary(
      sessions: sessionList,
      analysisAggregate: analysisAggregate,
      feedbackSummary: feedbackSummary,
      conversionContext: conversionContext,
    );
    final recurringIssues = _buildRecurringIssues(
      sessionList,
      analysisAggregate: analysisAggregate,
    );
    final sessionLogs = _buildSessionLogs(sessionList);
    final vocabularyTags = _buildVocabularyTags(events);
    final themes = _buildInsightThemes(
      analysisAggregate: analysisAggregate,
      recurringIssues: recurringIssues,
    );
    final dialogueTurns = _buildDialogueTurns(sessionList);
    final annotations = _buildAnnotations(recurringIssues);
    final healthMetrics = _buildHealthMetrics(kpiSummary);

    return AdminAiInsightsSnapshot(
      gaugeMetrics: [
        AdminAiGaugeMetric(
          title: 'ai.kpi.intentUnderstood',
          score: kpiSummary.intentUnderstoodRate,
          scoreLabel: _percentLabel(kpiSummary.intentUnderstoodRate),
          subtitle: 'ai.kpi.intentUnderstoodSubtitle',
          description: 'ai.kpi.intentUnderstoodDescription',
          color: AppTheme.primary,
        ),
        AdminAiGaugeMetric(
          title: 'ai.kpi.needSatisfied',
          score: kpiSummary.needSatisfiedRate,
          scoreLabel: _percentLabel(kpiSummary.needSatisfiedRate),
          subtitle: 'ai.kpi.needSatisfiedSubtitle',
          description: 'ai.kpi.needSatisfiedDescription',
          color: AppTheme.secondary,
        ),
        AdminAiGaugeMetric(
          title: 'ai.kpi.fallbackNoMatch',
          score: 1 - kpiSummary.fallbackNoMatchRate,
          scoreLabel: _percentLabel(kpiSummary.fallbackNoMatchRate),
          subtitle: 'ai.kpi.fallbackNoMatchSubtitle',
          description: 'ai.kpi.fallbackNoMatchDescription',
          color: AppTheme.onSurfaceVariant,
        ),
      ],
      feedbackSummary: feedbackSummary,
      feedbackAnalytics: feedbackAnalytics,
      kpiSummary: kpiSummary,
      recurringIssues: recurringIssues,
      sessionLogs: sessionLogs,
      themes: themes,
      dialogueTurns: dialogueTurns,
      annotations: annotations,
      vocabularyTags: vocabularyTags,
      healthMetrics: healthMetrics,
      lastSyncLabel: 'ai.justNow',
    );
  }

  @override
  Future<void> queueModelTraining() async {
    await _firestore.collection('ai_model_training_jobs').add({
      'status': 'queued',
      'source': 'admin_dashboard',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveSessionAnnotation({
    required String sessionId,
    required String note,
    required String actorId,
  }) async {
    await _firestore.collection('ai_session_annotations').add({
      'sessionId': sessionId,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': actorId,
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchEventDocs(
    DateTime windowStart,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ai_chat_events')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .limit(_eventFetchLimit)
          .get();
      return snapshot.docs;
    } catch (_) {
      final fallback = await _firestore
          .collection('ai_chat_events')
          .limit(_eventFetchLimit)
          .get();
      return fallback.docs;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchSessionDocs(
    DateTime windowStart,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ai_chat_sessions')
          .where(
            'startedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .limit(_sessionFetchLimit)
          .get();
      return snapshot.docs;
    } catch (_) {
      final fallback = await _firestore
          .collection('ai_chat_sessions')
          .limit(_sessionFetchLimit)
          .get();
      return fallback.docs;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchMessageDocs(
    DateTime windowStart,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ai_chat_messages')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .limit(_messageFetchLimit)
          .get();
      return snapshot.docs;
    } catch (_) {
      final fallback = await _firestore
          .collection('ai_chat_messages')
          .limit(_messageFetchLimit)
          .get();
      return fallback.docs;
    }
  }

  Map<String, _SessionAggregate> _buildSessions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sessions = <String, _SessionAggregate>{};

    for (final doc in docs) {
      final data = doc.data();
      final sessionId = (data['sessionId'] ?? '').toString().trim();
      if (sessionId.isEmpty) continue;

      final aggregate = sessions.putIfAbsent(
        sessionId,
        () => _SessionAggregate(sessionId: sessionId),
      );
      final createdAt = _timestampToDate(data['createdAt']);
      final eventType = (data['eventType'] ?? '').toString();
      final metadata = _asMap(data['metadata']);
      final userId = (data['userId'] ?? '').toString().trim();
      if (userId.isNotEmpty && aggregate.userId.isEmpty) {
        aggregate.userId = userId;
      }
      aggregate.registerEvent(
        eventType: eventType,
        createdAt: createdAt,
        metadata: metadata,
      );
    }

    return sessions;
  }

  void _mergePersistedSessions(
    Map<String, _SessionAggregate> sessions,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    for (final doc in docs) {
      final data = doc.data();
      final sessionId = (data['id'] ?? doc.id).toString().trim();
      if (sessionId.isEmpty) continue;

      final aggregate = sessions.putIfAbsent(
        sessionId,
        () => _SessionAggregate(sessionId: sessionId),
      );
      aggregate.registerSessionDocument(data);
    }
  }

  void _mergePersistedMessages(
    Map<String, _SessionAggregate> sessions,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final messagesBySession = <String, List<Map<String, dynamic>>>{};

    for (final doc in docs) {
      final data = doc.data();
      final sessionId = (data['sessionId'] ?? '').toString().trim();
      if (sessionId.isEmpty) continue;
      final bucket = messagesBySession.putIfAbsent(
        sessionId,
        () => <Map<String, dynamic>>[],
      );
      bucket.add(data);
    }

    for (final entry in messagesBySession.entries) {
      final aggregate = sessions.putIfAbsent(
        entry.key,
        () => _SessionAggregate(sessionId: entry.key),
      );
      final ordered = entry.value.toList()
        ..sort((a, b) {
          final aDate = _timestampToDate(a['createdAt']) ?? DateTime(1970);
          final bDate = _timestampToDate(b['createdAt']) ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
      for (final data in ordered) {
        aggregate.registerMessage(data);
      }
    }
  }

  Future<AdminAiFeedbackSummary> _fetchFeedbackSummary(
    DateTime windowStart,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ai_feedback')
          .limit(_feedbackFetchLimit)
          .get();
      final docs = snapshot.docs.map((doc) => doc.data()).where((data) {
        final submittedAt = data['submittedAt'];
        if (submittedAt is Timestamp) {
          return submittedAt.toDate().isAfter(windowStart);
        }
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          return createdAt.toDate().isAfter(windowStart);
        }
        return true;
      }).toList();

      var positive = 0;
      var negative = 0;
      var withNotes = 0;
      final notesWithTime = <MapEntry<DateTime, String>>[];

      for (final data in docs) {
        final isHelpful = _resolveFeedbackHelpful(data);
        if (isHelpful) {
          positive += 1;
        } else {
          negative += 1;
        }

        final note = (data['comment'] ?? data['note'] ?? '').toString().trim();
        if (note.isNotEmpty) {
          withNotes += 1;
          notesWithTime.add(
            MapEntry(
              _timestampToDate(data['submittedAt']) ??
                  _timestampToDate(data['createdAt']) ??
                  DateTime(1970),
              note,
            ),
          );
        }
      }

      notesWithTime.sort((a, b) => b.key.compareTo(a.key));
      final total = positive + negative;
      final rate = total == 0 ? 0.0 : positive / total;

      return AdminAiFeedbackSummary(
        totalResponses: total,
        positiveResponses: positive,
        negativeResponses: negative,
        withNotes: withNotes,
        satisfactionRate: rate.clamp(0.0, 1.0),
        recentNotes: notesWithTime.take(3).map((e) => e.value).toList(),
        windowLabel: '30d',
      );
    } catch (_) {
      return const AdminAiFeedbackSummary(
        totalResponses: 0,
        positiveResponses: 0,
        negativeResponses: 0,
        withNotes: 0,
        satisfactionRate: 0,
        recentNotes: <String>[],
        windowLabel: '30d',
      );
    }
  }

  Future<AdminAiFeedbackAnalytics> _fetchFeedbackAnalytics(
    DateTime windowStart,
  ) async {
    try {
      final results = await Future.wait([
        _firestore.collection('ai_feedback').limit(_feedbackFetchLimit).get(),
        _firestore
            .collection('ai_feedback_analysis')
            .limit(_analysisFetchLimit)
            .get(),
      ]);
      final feedbackDocs = results[0].docs.map((doc) => doc.data()).where((
        data,
      ) {
        final submittedAt =
            _timestampToDate(data['submittedAt']) ??
            _timestampToDate(data['createdAt']);
        return submittedAt == null || submittedAt.isAfter(windowStart);
      });
      final analysisDocs = results[1].docs.map((doc) => doc.data()).where((
        data,
      ) {
        final analyzedAt =
            _timestampToDate(data['analyzedAt']) ??
            _timestampToDate(data['createdAt']);
        return analyzedAt == null || analyzedAt.isAfter(windowStart);
      });
      return buildFeedbackAnalyticsFromMaps(
        feedbackDocs: feedbackDocs,
        analysisDocs: analysisDocs,
      );
    } catch (_) {
      return const AdminAiFeedbackAnalytics(
        totalFeedback: 0,
        positiveFeedback: 0,
        negativeFeedback: 0,
        neutralFeedback: 0,
        topReasons: <AdminAiFeedbackReasonStat>[],
        recentNegativePreviews: <String>[],
        analysisStatusCounts: <String, int>{},
      );
    }
  }

  @visibleForTesting
  static AdminAiFeedbackAnalytics buildFeedbackAnalyticsFromMaps({
    required Iterable<Map<String, dynamic>> feedbackDocs,
    required Iterable<Map<String, dynamic>> analysisDocs,
  }) {
    var positive = 0;
    var negative = 0;
    var neutral = 0;
    final reasonCounts = <String, int>{};
    final negativePreviews = <String>[];
    final statusCounts = <String, int>{};

    for (final data in feedbackDocs) {
      final bucket = _feedbackBucket(data);
      if (bucket == 'positive') {
        positive += 1;
      } else if (bucket == 'negative') {
        negative += 1;
      } else {
        neutral += 1;
      }

      final reason = _feedbackReason(data);
      if (reason.isNotEmpty) {
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }

      if (bucket == 'negative' && negativePreviews.length < 5) {
        final preview = _sanitizeFeedbackPreview(
          (data['comment'] ?? data['note'] ?? data['message'] ?? '').toString(),
        );
        if (preview.isNotEmpty) {
          negativePreviews.add(preview);
        }
      }
    }

    for (final data in analysisDocs) {
      final status = (data['status'] ?? 'unknown')
          .toString()
          .trim()
          .toLowerCase();
      final normalizedStatus = status.isEmpty ? 'unknown' : status;
      statusCounts[normalizedStatus] =
          (statusCounts[normalizedStatus] ?? 0) + 1;
    }

    final topReasons = reasonCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return AdminAiFeedbackAnalytics(
      totalFeedback: positive + negative + neutral,
      positiveFeedback: positive,
      negativeFeedback: negative,
      neutralFeedback: neutral,
      topReasons: topReasons
          .take(5)
          .map(
            (entry) => AdminAiFeedbackReasonStat(
              reason: entry.key,
              count: entry.value,
            ),
          )
          .toList(),
      recentNegativePreviews: negativePreviews,
      analysisStatusCounts: Map.unmodifiable(statusCounts),
    );
  }

  Future<Map<String, String>> _fetchFeedbackBySession(
    DateTime windowStart,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ai_feedback')
          .limit(_feedbackFetchLimit)
          .get();
      final ordered = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate =
              _timestampToDate(a.data()['submittedAt']) ??
              _timestampToDate(a.data()['updatedAt']) ??
              DateTime(1970);
          final bDate =
              _timestampToDate(b.data()['submittedAt']) ??
              _timestampToDate(b.data()['updatedAt']) ??
              DateTime(1970);
          return bDate.compareTo(aDate);
        });
      final result = <String, String>{};
      for (final doc in ordered) {
        final data = doc.data();
        final createdAt =
            _timestampToDate(data['submittedAt']) ??
            _timestampToDate(data['createdAt']);
        if (createdAt != null && createdAt.isBefore(windowStart)) continue;
        final sessionId = (data['sessionId'] ?? '').toString().trim();
        if (sessionId.isEmpty || result.containsKey(sessionId)) continue;
        final scope = (data['feedbackScope'] ?? '').toString().trim();
        if (scope.isNotEmpty && scope != 'session') continue;
        result[sessionId] = _resolveFeedbackHelpful(data) ? 'up' : 'down';
      }
      return result;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<_AnalysisAggregate> _fetchAnalysisAggregate(
    DateTime windowStart,
  ) async {
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    queryWithWindow() async {
      final query = await _firestore
          .collection('ai_feedback_analysis')
          .where(
            'analyzedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .limit(_analysisFetchLimit)
          .get();
      return query.docs;
    }

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    queryFallback() async {
      final query = await _firestore
          .collection('ai_feedback_analysis')
          .limit(_analysisFetchLimit)
          .get();
      return query.docs;
    }

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
    try {
      docs = await queryWithWindow();
    } catch (_) {
      docs = await queryFallback();
    }

    final aggregate = _AnalysisAggregate();
    for (final doc in docs) {
      final data = doc.data();
      final analyzedAt = _timestampToDate(data['analyzedAt']);
      if (analyzedAt != null && analyzedAt.isBefore(windowStart)) {
        continue;
      }

      // Quality KPIs must only reflect successful analysis outputs.
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status != 'completed') {
        continue;
      }

      aggregate.total += 1;
      if (_asBool(data['intentUnderstood'])) {
        aggregate.intentUnderstood += 1;
      }
      if (_asBool(data['needSatisfied'])) {
        aggregate.needSatisfied += 1;
      }

      final score = _asDouble(data['satisfactionScore']);
      if (score != null) {
        aggregate.satisfactionScoreTotal += score.clamp(0.0, 1.0);
        aggregate.satisfactionScoreCount += 1;
      }

      final sentiment = (data['sentiment'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (sentiment == 'positive') {
        aggregate.positiveSentiment += 1;
      } else if (sentiment == 'negative') {
        aggregate.negativeSentiment += 1;
      } else if (sentiment == 'neutral') {
        aggregate.neutralSentiment += 1;
      }

      final failureReason = (data['failureReason'] ?? '').toString().trim();
      if (failureReason.isNotEmpty) {
        aggregate.failureReasons[failureReason] =
            (aggregate.failureReasons[failureReason] ?? 0) + 1;
      }

      final missingNeedsRaw = data['missingNeeds'];
      if (missingNeedsRaw is Iterable) {
        for (final need in missingNeedsRaw) {
          final cleanNeed = need.toString().trim();
          if (cleanNeed.isEmpty) continue;
          aggregate.missingNeeds[cleanNeed] =
              (aggregate.missingNeeds[cleanNeed] ?? 0) + 1;
        }
      }
    }

    return aggregate;
  }

  Future<_ConversionContext> _fetchConversionContext(
    DateTime windowStart,
  ) async {
    final convertedUserIds = <String>{};
    final engagedUserIds = <String>{};

    try {
      final ordersQuery = await _firestore
          .collection('orders')
          .where('orderSource', isEqualTo: 'ai_chat')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .limit(_conversionFetchLimit)
          .get();
      for (final doc in ordersQuery.docs) {
        final uid = (doc.data()['userId'] ?? '').toString().trim();
        if (uid.isNotEmpty) convertedUserIds.add(uid);
      }
    } catch (_) {}

    try {
      final events = await _firestore
          .collection('ai_chat_events')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(windowStart),
          )
          .where('eventType', isEqualTo: 'message_sent')
          .limit(_conversionFetchLimit)
          .get();
      for (final doc in events.docs) {
        final uid = (doc.data()['userId'] ?? '').toString().trim();
        if (uid.isNotEmpty) engagedUserIds.add(uid);
      }
    } catch (_) {}

    return _ConversionContext(
      convertedUserIds: convertedUserIds,
      engagedUserIds: engagedUserIds,
    );
  }

  AdminAiKpiSummary _buildKpiSummary({
    required List<_SessionAggregate> sessions,
    required _AnalysisAggregate analysisAggregate,
    required AdminAiFeedbackSummary feedbackSummary,
    required _ConversionContext conversionContext,
  }) {
    final totalSessions = sessions.length;
    final sessionsWithFallback = sessions
        .where((s) => s.hasFallbackShown)
        .length;
    final sessionsWithNoMatch = sessions.where((s) => s.hasNoMatchShown).length;
    final sessionsWithFallbackOrNoMatch = sessions
        .where((s) => s.hasFallbackShown || s.hasNoMatchShown)
        .length;
    final sessionsWithRecommendations = sessions
        .where((s) => s.hasRecommendationsShown)
        .length;
    final sessionsWithAnswers = sessions.where((s) => s.hasAnswerShown).length;
    final sessionsWithResolution = sessions
        .where((s) => s.hasRecommendationsShown || s.hasAnswerShown)
        .length;
    final sessionsWithFeedback = sessions
        .where((s) => s.feedbackValue != 'none')
        .length;
    final sessionsWithConversion = sessions
        .where((s) => s.hasOrderConversion)
        .length;
    final sessionsWithNotifyMe = sessions
        .where((s) => s.hasNotifyMeRequest)
        .length;
    final activeSessions = sessions
        .where((s) => s.status.trim().toLowerCase() == 'active')
        .length;
    final endedSessions = sessions
        .where((s) => s.status.trim().toLowerCase() == 'ended')
        .length;
    final uniqueUsers = sessions
        .map((s) => s.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final totalMessages = sessions.fold<int>(
      0,
      (totalCount, s) => totalCount + s.persistedMessages,
    );
    final userMessages = sessions.fold<int>(
      0,
      (totalCount, s) => totalCount + s.userMessages,
    );
    final assistantMessages = sessions.fold<int>(
      0,
      (totalCount, s) => totalCount + s.assistantMessages,
    );
    final fallbackNoMatchRate = totalSessions == 0
        ? 0.0
        : (sessionsWithFallbackOrNoMatch / totalSessions).clamp(0.0, 1.0);

    final feedbackUpRate = feedbackSummary.totalResponses == 0
        ? 0.0
        : (feedbackSummary.positiveResponses / feedbackSummary.totalResponses)
              .clamp(0.0, 1.0);

    if (!analysisAggregate.hasData && sessions.isEmpty) {
      return AdminAiKpiSummary(
        windowLabel: '30d',
        totalSessions: 0,
        activeSessions: 0,
        endedSessions: 0,
        uniqueUsers: 0,
        totalMessages: 0,
        userMessages: 0,
        assistantMessages: 0,
        intentUnderstoodRate: 0,
        needSatisfiedRate: conversionContext.engagedUserIds.isEmpty
            ? 0
            : conversionContext.convertedUserIds.length /
                  conversionContext.engagedUserIds.length,
        hasAnalysisMetrics: false,
        averageSatisfactionScore: 0,
        positiveSentimentRate: 0,
        neutralSentimentRate: 0,
        negativeSentimentRate: 0,
        feedbackUpRate: feedbackUpRate,
        fallbackNoMatchRate: 0,
        recommendationRate: 0,
        answerRate: 0,
        resolutionRate: 0,
        fallbackRate: 0,
        noMatchRate: 0,
        conversionRate: 0,
        feedbackCoverageRate: 0,
        notifyMeRate: 0,
        avgTurnsPerSession: 0,
        avgMessagesPerSession: 0,
        avgSessionDurationMinutes: 0,
        avgAssistantResponseSeconds: 0,
        avgUserMessageLength: 0,
        avgAssistantMessageLength: 0,
        sessionsWithRecommendations: 0,
        sessionsWithAnswers: 0,
        sessionsWithFallback: 0,
        sessionsWithNoMatch: 0,
        sessionsWithFeedback: 0,
        sessionsWithConversion: 0,
        sessionsWithNotifyMe: 0,
      );
    }

    final scores = sessions.map(_intentConfidenceScore).toList();
    final understoodFallback = sessions.isEmpty
        ? 0.0
        : scores.where((score) => score >= 0.60).length / sessions.length;
    final needSatisfiedFallback = conversionContext.engagedUserIds.isEmpty
        ? 0.0
        : conversionContext.convertedUserIds.length /
              conversionContext.engagedUserIds.length;

    final intentUnderstoodRate = analysisAggregate.hasData
        ? analysisAggregate.intentUnderstoodRate
        : understoodFallback;
    final needSatisfiedRate = analysisAggregate.hasData
        ? analysisAggregate.needSatisfiedRate
        : needSatisfiedFallback;
    final sessionDenominator = totalSessions == 0 ? 1 : totalSessions;

    return AdminAiKpiSummary(
      windowLabel: '30d',
      totalSessions: totalSessions,
      activeSessions: activeSessions,
      endedSessions: endedSessions,
      uniqueUsers: uniqueUsers,
      totalMessages: totalMessages,
      userMessages: userMessages,
      assistantMessages: assistantMessages,
      intentUnderstoodRate: intentUnderstoodRate.clamp(0.0, 1.0),
      needSatisfiedRate: needSatisfiedRate.clamp(0.0, 1.0),
      hasAnalysisMetrics: analysisAggregate.hasData,
      averageSatisfactionScore: analysisAggregate.averageSatisfactionScore,
      positiveSentimentRate: analysisAggregate.positiveSentimentRate,
      neutralSentimentRate: analysisAggregate.neutralSentimentRate,
      negativeSentimentRate: analysisAggregate.negativeSentimentRate,
      feedbackUpRate: feedbackUpRate,
      fallbackNoMatchRate: fallbackNoMatchRate,
      recommendationRate: (sessionsWithRecommendations / sessionDenominator)
          .clamp(0.0, 1.0),
      answerRate: (sessionsWithAnswers / sessionDenominator).clamp(0.0, 1.0),
      resolutionRate: (sessionsWithResolution / sessionDenominator).clamp(
        0.0,
        1.0,
      ),
      fallbackRate: (sessionsWithFallback / sessionDenominator).clamp(0.0, 1.0),
      noMatchRate: (sessionsWithNoMatch / sessionDenominator).clamp(0.0, 1.0),
      conversionRate: (sessionsWithConversion / sessionDenominator).clamp(
        0.0,
        1.0,
      ),
      feedbackCoverageRate: (sessionsWithFeedback / sessionDenominator).clamp(
        0.0,
        1.0,
      ),
      notifyMeRate: (sessionsWithNotifyMe / sessionDenominator).clamp(0.0, 1.0),
      avgTurnsPerSession:
          sessions.fold<int>(0, (totalCount, s) => totalCount + s.turns) /
          sessionDenominator,
      avgMessagesPerSession: totalMessages / sessionDenominator,
      avgSessionDurationMinutes: _averageNonZero(
        sessions.map((s) => s.durationMinutes),
      ),
      avgAssistantResponseSeconds: _averageNonZero(
        sessions.map((s) => s.averageAssistantResponseSeconds),
      ),
      avgUserMessageLength: _averageNonZero(
        sessions.map((s) => s.averageUserMessageLength),
      ),
      avgAssistantMessageLength: _averageNonZero(
        sessions.map((s) => s.averageAssistantMessageLength),
      ),
      sessionsWithRecommendations: sessionsWithRecommendations,
      sessionsWithAnswers: sessionsWithAnswers,
      sessionsWithFallback: sessionsWithFallback,
      sessionsWithNoMatch: sessionsWithNoMatch,
      sessionsWithFeedback: sessionsWithFeedback,
      sessionsWithConversion: sessionsWithConversion,
      sessionsWithNotifyMe: sessionsWithNotifyMe,
    );
  }

  List<AdminAiIssueStat> _buildRecurringIssues(
    List<_SessionAggregate> sessions, {
    required _AnalysisAggregate analysisAggregate,
  }) {
    if (analysisAggregate.hasData) {
      final issueCounts = <String, int>{};

      final topFailures = analysisAggregate.failureReasons.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in topFailures.take(3)) {
        issueCounts['failure: ${entry.key}'] = entry.value;
      }

      final topMissing = analysisAggregate.missingNeeds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in topMissing.take(3)) {
        issueCounts['missing: ${entry.key}'] = entry.value;
      }

      if (issueCounts.isNotEmpty) {
        final ordered = issueCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ordered
            .take(5)
            .map(
              (entry) => AdminAiIssueStat(
                code: entry.key,
                count: entry.value,
                ratio: (entry.value / analysisAggregate.total).clamp(0.0, 1.0),
              ),
            )
            .toList();
      }
    }

    if (sessions.isEmpty) return const <AdminAiIssueStat>[];

    final counts = <String, int>{};
    for (final session in sessions) {
      final uniqueIssues = session.issueCodes.toSet();
      for (final code in uniqueIssues) {
        counts[code] = (counts[code] ?? 0) + 1;
      }
    }
    final total = sessions.length;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(5)
        .map(
          (entry) => AdminAiIssueStat(
            code: entry.key,
            count: entry.value,
            ratio: (entry.value / total).clamp(0.0, 1.0),
          ),
        )
        .toList();
  }

  List<AdminAiSessionLog> _buildSessionLogs(List<_SessionAggregate> sessions) {
    final ordered = sessions.toList()
      ..sort((a, b) {
        final aDate = a.endedAt ?? a.startedAt ?? DateTime(1970);
        final bDate = b.endedAt ?? b.startedAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    return ordered.take(12).map((session) {
      final score = _intentConfidenceScore(session);
      return AdminAiSessionLog(
        shortSessionId: session.sessionId.length > 8
            ? session.sessionId.substring(session.sessionId.length - 8)
            : session.sessionId,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        turns: session.turns,
        messages: session.persistedMessages,
        durationMinutes: session.durationMinutes,
        outcome: session.outcome,
        intentConfidenceScore: score,
        issueTags: session.issueCodes.toSet().toList()..sort(),
        feedbackValue: session.feedbackValue,
        hasOrderConversion: session.hasOrderConversion,
      );
    }).toList();
  }

  List<InsightTheme> _buildInsightThemes({
    required _AnalysisAggregate analysisAggregate,
    required List<AdminAiIssueStat> recurringIssues,
  }) {
    final themes = <InsightTheme>[];
    final failures = analysisAggregate.failureReasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in failures.take(2)) {
      themes.add(
        InsightTheme(
          icon: Icons.report_problem_outlined,
          title: entry.key,
          description:
              'Observed in ${entry.value} analyzed AI conversation(s).',
        ),
      );
    }

    final missingNeeds = analysisAggregate.missingNeeds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in missingNeeds.take(2)) {
      themes.add(
        InsightTheme(
          icon: Icons.search_off_outlined,
          title: entry.key,
          description: 'Missing need detected ${entry.value} time(s).',
        ),
      );
    }

    if (themes.isNotEmpty) return themes.take(4).toList();

    return recurringIssues
        .take(3)
        .map(
          (issue) => InsightTheme(
            icon: Icons.insights_outlined,
            title: issue.code,
            description:
                'Observed in ${issue.count} session(s), ${(issue.ratio * 100).toStringAsFixed(0)}% of the current window.',
          ),
        )
        .toList();
  }

  List<DialogueTurn> _buildDialogueTurns(List<_SessionAggregate> sessions) {
    final sessionsWithMessages =
        sessions
            .where((session) => session.dialogueMessages.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final aDate = a.endedAt ?? a.startedAt ?? DateTime(1970);
            final bDate = b.endedAt ?? b.startedAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });
    if (sessionsWithMessages.isEmpty) return const <DialogueTurn>[];

    final session = sessionsWithMessages.first;
    return session.dialogueMessages.take(8).map((message) {
      return DialogueTurn(
        speaker: message.isAi ? 'Qissa AI' : 'User ${session.shortId}',
        time: message.createdAt == null
            ? 'Unknown time'
            : _formatTimeAgo(DateTime.now().difference(message.createdAt!)),
        message: message.content,
        isAi: message.isAi,
      );
    }).toList();
  }

  List<InsightAnnotation> _buildAnnotations(List<AdminAiIssueStat> issues) {
    return issues.take(4).map((issue) {
      final highRatio = issue.ratio >= 0.25;
      return InsightAnnotation(
        title: issue.code,
        description:
            'Appeared in ${issue.count} session(s) in the current analytics window.',
        tags: [
          '${(issue.ratio * 100).toStringAsFixed(0)}%',
          highRatio ? 'needs review' : 'monitor',
        ],
        color: highRatio ? const Color(0xFF8C4F10) : AppTheme.secondary,
      );
    }).toList();
  }

  List<String> _buildVocabularyTags(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    final counts = <String, int>{};
    void collectValue(dynamic value) {
      if (value is Iterable) {
        for (final item in value) {
          collectValue(item);
        }
        return;
      }
      if (value is Map) {
        for (final item in value.values) {
          collectValue(item);
        }
        return;
      }
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.length < 2 || normalized.length > 32) return;
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }

    const vocabularyKeys = {
      'note',
      'notes',
      'preferrednotes',
      'excludednotes',
      'includednotes',
      'families',
      'family',
      'fragrancefamily',
      'fragrancefamilies',
      'scenttags',
      'tags',
    };

    for (final doc in events) {
      final metadata = _asMap(doc.data()['metadata']);
      for (final entry in metadata.entries) {
        final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (vocabularyKeys.contains(key)) {
          collectValue(entry.value);
        }
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.take(10).map((entry) => entry.key).toList();
  }

  List<AdminAiHealthMetric> _buildHealthMetrics(AdminAiKpiSummary summary) {
    if (summary.totalSessions == 0 &&
        summary.totalMessages == 0 &&
        !summary.hasAnalysisMetrics) {
      return const <AdminAiHealthMetric>[];
    }

    final responseHealth = summary.avgAssistantResponseSeconds <= 0
        ? 0.0
        : (1 - (summary.avgAssistantResponseSeconds / 30)).clamp(0.0, 1.0);
    return [
      AdminAiHealthMetric(
        label: 'Resolution Rate',
        value: _percentLabel(summary.resolutionRate),
        progress: summary.resolutionRate.clamp(0.0, 1.0),
        color: AppTheme.primary,
      ),
      AdminAiHealthMetric(
        label: 'Fallback Control',
        value: _percentLabel(1 - summary.fallbackNoMatchRate),
        progress: (1 - summary.fallbackNoMatchRate).clamp(0.0, 1.0),
        color: AppTheme.secondary,
      ),
      AdminAiHealthMetric(
        label: 'Response Speed',
        value: '${summary.avgAssistantResponseSeconds.toStringAsFixed(1)}s',
        progress: responseHealth,
        color: AppTheme.onSurfaceVariant,
      ),
    ];
  }

  static String _percentLabel(double value) =>
      '${(value * 100).toStringAsFixed(0)}%';

  static String _formatTimeAgo(Duration diff) {
    if (diff.inMinutes < 1) return 'ai.justNow';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  static bool _resolveFeedbackHelpful(Map<String, dynamic> data) {
    final raw = data['isHelpful'];
    if (raw is bool) return raw;
    return (data['feedbackValue'] ?? '').toString() == 'up';
  }

  static String _feedbackBucket(Map<String, dynamic> data) {
    final helpful = data['isHelpful'];
    if (helpful is bool) return helpful ? 'positive' : 'negative';
    final raw = (data['feedbackValue'] ?? data['sentiment'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'up' || raw == 'positive' || raw == 'helpful') {
      return 'positive';
    }
    if (raw == 'down' || raw == 'negative' || raw == 'not_helpful') {
      return 'negative';
    }
    return 'neutral';
  }

  static String _feedbackReason(Map<String, dynamic> data) {
    for (final key in const [
      'rejectionReason',
      'feedbackReason',
      'reason',
      'issueCode',
      'failureReason',
    ]) {
      final value = (data[key] ?? '').toString().trim().toLowerCase();
      if (value.isNotEmpty && value.length <= 64) return value;
    }
    return '';
  }

  static String _sanitizeFeedbackPreview(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return '';
    value = value.replaceAll(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      '[email]',
    );
    value = value.replaceAll(RegExp(r'\+?\d[\d\s\-]{7,}\d'), '[number]');
    if (value.length > 140) {
      value = '${value.substring(0, 137).trimRight()}...';
    }
    return value;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static double _averageNonZero(Iterable<double> values) {
    final filtered = values.where((value) => value > 0).toList();
    if (filtered.isEmpty) return 0.0;
    final total = filtered.fold<double>(
      0.0,
      (runningTotal, value) => runningTotal + value,
    );
    return total / filtered.length;
  }
}

class _AnalysisAggregate {
  int total = 0;
  int intentUnderstood = 0;
  int needSatisfied = 0;
  int positiveSentiment = 0;
  int neutralSentiment = 0;
  int negativeSentiment = 0;
  int satisfactionScoreCount = 0;
  double satisfactionScoreTotal = 0;
  final Map<String, int> failureReasons = <String, int>{};
  final Map<String, int> missingNeeds = <String, int>{};

  bool get hasData => total > 0;

  double get intentUnderstoodRate =>
      total == 0 ? 0.0 : (intentUnderstood / total).clamp(0.0, 1.0);

  double get needSatisfiedRate =>
      total == 0 ? 0.0 : (needSatisfied / total).clamp(0.0, 1.0);

  double get averageSatisfactionScore => satisfactionScoreCount == 0
      ? 0.0
      : (satisfactionScoreTotal / satisfactionScoreCount).clamp(0.0, 1.0);

  double get positiveSentimentRate =>
      total == 0 ? 0.0 : (positiveSentiment / total).clamp(0.0, 1.0);

  double get neutralSentimentRate =>
      total == 0 ? 0.0 : (neutralSentiment / total).clamp(0.0, 1.0);

  double get negativeSentimentRate =>
      total == 0 ? 0.0 : (negativeSentiment / total).clamp(0.0, 1.0);
}

class AdminAiInsightsMath {
  static double scoreFromSignals({
    required bool hasSufficientCriteria,
    required bool hasResolution,
    required bool hasFallbackShown,
    required int clarifyingQuestions,
  }) {
    var score = 0.0;
    if (hasSufficientCriteria) {
      score += 0.55;
    }
    if (hasResolution) {
      score += 0.20;
    }
    if (!hasFallbackShown) {
      score += 0.15;
    }
    if (clarifyingQuestions <= 1) {
      score += 0.10;
    }
    return score.clamp(0.0, 1.0);
  }
}

double _intentConfidenceScore(_SessionAggregate session) {
  return AdminAiInsightsMath.scoreFromSignals(
    hasSufficientCriteria: session.hasSufficientCriteria,
    hasResolution: session.hasRecommendationsShown || session.hasAnswerShown,
    hasFallbackShown: session.hasFallbackShown,
    clarifyingQuestions: session.clarifyingQuestions,
  );
}

class _ConversionContext {
  const _ConversionContext({
    required this.convertedUserIds,
    required this.engagedUserIds,
  });

  final Set<String> convertedUserIds;
  final Set<String> engagedUserIds;
}

class _DialogueMessage {
  const _DialogueMessage({
    required this.content,
    required this.isAi,
    required this.createdAt,
  });

  final String content;
  final bool isAi;
  final DateTime? createdAt;
}

class _SessionAggregate {
  _SessionAggregate({required this.sessionId});

  final String sessionId;
  String userId = '';
  String status = '';
  DateTime? startedAt;
  DateTime? endedAt;
  int turns = 0;
  int clarifyingQuestions = 0;
  int persistedMessages = 0;
  int userMessages = 0;
  int assistantMessages = 0;
  int systemMessages = 0;
  int notifyMeRequests = 0;
  bool hasSufficientCriteria = false;
  bool hasFallbackShown = false;
  bool hasNoMatchShown = false;
  bool hasRecommendationsShown = false;
  bool hasAnswerShown = false;
  int totalUserCharacters = 0;
  int totalAssistantCharacters = 0;
  double totalAssistantResponseSeconds = 0;
  int assistantResponseSamples = 0;
  DateTime? _pendingUserMessageAt;
  final List<String> issueCodes = <String>[];
  final List<_DialogueMessage> dialogueMessages = <_DialogueMessage>[];
  String feedbackValue = 'none';
  bool hasOrderConversion = false;

  bool get hasNotifyMeRequest => notifyMeRequests > 0;

  String get shortId => sessionId.length > 8
      ? sessionId.substring(sessionId.length - 8)
      : sessionId;

  double get durationMinutes {
    if (startedAt == null || endedAt == null) return 0.0;
    final diff = endedAt!.difference(startedAt!);
    if (diff.isNegative) return 0.0;
    return diff.inSeconds / 60;
  }

  double get averageAssistantResponseSeconds => assistantResponseSamples == 0
      ? 0.0
      : totalAssistantResponseSeconds / assistantResponseSamples;

  double get averageUserMessageLength =>
      userMessages == 0 ? 0.0 : totalUserCharacters / userMessages;

  double get averageAssistantMessageLength => assistantMessages == 0
      ? 0.0
      : totalAssistantCharacters / assistantMessages;

  String get outcome {
    if (hasRecommendationsShown) return 'recommendations';
    if (hasAnswerShown) return 'answer';
    if (hasNoMatchShown) return 'no_match';
    if (hasFallbackShown) return 'fallback';
    return 'in_progress';
  }

  void registerEvent({
    required String eventType,
    required DateTime? createdAt,
    required Map<String, dynamic> metadata,
  }) {
    if (createdAt != null) {
      if (startedAt == null || createdAt.isBefore(startedAt!)) {
        startedAt = createdAt;
      }
      if (endedAt == null || createdAt.isAfter(endedAt!)) {
        endedAt = createdAt;
      }
    }

    if (eventType == 'message_sent') {
      turns += 1;
    } else if (eventType == 'recommendation_clarifying_question_shown' ||
        eventType == 'clarifying_question_shown') {
      clarifyingQuestions += 1;
    } else if (eventType == 'recommendation_shown' ||
        eventType == 'recommendations_shown') {
      hasRecommendationsShown = true;
    } else if (eventType == 'recommendation_answer_shown' ||
        eventType == 'answer_shown') {
      hasAnswerShown = true;
    } else if (eventType == 'request_fallback_local' ||
        eventType == 'fallback_shown') {
      hasFallbackShown = true;
    } else if (eventType == 'recommendation_no_match_shown' ||
        eventType == 'no_match_shown') {
      hasNoMatchShown = true;
    } else if (eventType == 'availability_notify_me_requested' ||
        eventType == 'notify_me_requested') {
      notifyMeRequests += 1;
    } else if (eventType == 'request_model_error') {
      issueCodes.add('model_timeout_or_error');
    } else if (eventType == 'recommendation_hard_filter_blocked') {
      issueCodes.add('parse_failure_or_filter_blocked');
    } else if (eventType == 'conversion_product_clicked' ||
        eventType == 'conversion_upsell_product_clicked') {
      issueCodes.add('click_through_recorded');
    }

    final hasSufficient = metadata['hasSufficientCriteria'];
    if (hasSufficient is bool && hasSufficient) {
      hasSufficientCriteria = true;
    }

    final issueCode = (metadata['issueCode'] ?? '').toString().trim();
    if (issueCode.isNotEmpty) {
      issueCodes.add(issueCode);
    }
  }

  void registerSessionDocument(Map<String, dynamic> data) {
    final docUserId = (data['userId'] ?? '').toString().trim();
    if (docUserId.isNotEmpty) {
      userId = docUserId;
    }

    final docStatus = (data['status'] ?? '').toString().trim();
    if (docStatus.isNotEmpty) {
      status = docStatus;
    }

    final docStartedAt = FirestoreAdminAiInsightsService._timestampToDate(
      data['startedAt'],
    );
    final docEndedAt = FirestoreAdminAiInsightsService._timestampToDate(
      data['endedAt'],
    );
    if (docStartedAt != null &&
        (startedAt == null || docStartedAt.isBefore(startedAt!))) {
      startedAt = docStartedAt;
    }
    if (docEndedAt != null &&
        (endedAt == null || docEndedAt.isAfter(endedAt!))) {
      endedAt = docEndedAt;
    }

    final finalRecommendationMessageId =
        (data['finalRecommendationMessageId'] ?? '').toString().trim();
    if (finalRecommendationMessageId.isNotEmpty) {
      hasRecommendationsShown = true;
    }
  }

  void registerMessage(Map<String, dynamic> data) {
    persistedMessages += 1;
    final createdAt = FirestoreAdminAiInsightsService._timestampToDate(
      data['createdAt'],
    );
    if (createdAt != null) {
      if (startedAt == null || createdAt.isBefore(startedAt!)) {
        startedAt = createdAt;
      }
      if (endedAt == null || createdAt.isAfter(endedAt!)) {
        endedAt = createdAt;
      }
    }

    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final content = (data['content'] ?? '').toString();
    final messageType = (data['messageType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (role == 'user') {
      userMessages += 1;
      turns += 1;
      totalUserCharacters += content.trim().length;
      _pendingUserMessageAt = createdAt;
      if (content.trim().isNotEmpty) {
        dialogueMessages.add(
          _DialogueMessage(
            content: content.trim(),
            isAi: false,
            createdAt: createdAt,
          ),
        );
      }
    } else if (role == 'assistant') {
      assistantMessages += 1;
      totalAssistantCharacters += content.trim().length;
      if (content.trim().isNotEmpty) {
        dialogueMessages.add(
          _DialogueMessage(
            content: content.trim(),
            isAi: true,
            createdAt: createdAt,
          ),
        );
      }
      if (messageType == 'recommendation') {
        hasRecommendationsShown = true;
      } else if (messageType == 'text') {
        hasAnswerShown = true;
      }
      if (_pendingUserMessageAt != null && createdAt != null) {
        final seconds = createdAt.difference(_pendingUserMessageAt!).inSeconds;
        if (seconds >= 0) {
          totalAssistantResponseSeconds += seconds;
          assistantResponseSamples += 1;
        }
        _pendingUserMessageAt = null;
      }
    } else if (role == 'system') {
      systemMessages += 1;
    }
  }
}
