import 'package:cloud_firestore/cloud_firestore.dart';

class AIChatCollectionNames {
  static const String sessions = 'ai_chat_sessions';
  static const String messages = 'ai_chat_messages';
  static const String debugLogs = 'ai_chat_debug_logs';
  static const String feedback = 'ai_feedback';
  static const String feedbackAnalysis = 'ai_feedback_analysis';

  const AIChatCollectionNames._();
}

enum AIChatSessionStatus { active, ended }

enum AIChatMessageRole { user, assistant, system }

enum AIChatMessageType { text, recommendation, availability, loading, error }

enum AIUnifiedFeedbackScope { message, session }

enum AIFeedbackAnalysisStatus { pending, completed, failed, pendingRetry }

enum AIFeedbackSentiment { positive, neutral, negative }

Never _contractError(String message) {
  throw FormatException(message);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    _contractError('Missing required field "$key".');
  }
  return text;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    _contractError('Missing or invalid integer field "$key".');
  }
  return parsed;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    _contractError('Missing or invalid numeric field "$key".');
  }
  return parsed;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  _contractError('Missing or invalid boolean field "$key".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = _asDateTime(value);
  if (parsed == null) {
    _contractError('Missing or invalid timestamp field "$key".');
  }
  return parsed;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  return _asDateTime(json[key]);
}

class AIChatSession {
  const AIChatSession({
    required this.id,
    required this.userId,
    required this.language,
    required this.status,
    required this.startedAt,
    required this.messageCount,
    this.endedAt,
    this.finalRecommendationMessageId,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String userId;
  final String language;
  final AIChatSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final String? finalRecommendationMessageId;

  factory AIChatSession.fromJson(Map<String, dynamic> json) {
    return AIChatSession(
      schemaVersion: _asInt(json['_schemaVersion']) ?? 1,
      id: _requiredString(json, 'id'),
      userId: _requiredString(json, 'userId'),
      language: _requiredString(json, 'language'),
      status: _parseSessionStatus(json['status']),
      startedAt: _requiredDateTime(json, 'startedAt'),
      endedAt: _optionalDateTime(json, 'endedAt'),
      messageCount: _requiredInt(json, 'messageCount'),
      finalRecommendationMessageId: _asNullableString(
        json['finalRecommendationMessageId'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_schemaVersion': schemaVersion,
      'id': id,
      'userId': userId,
      'language': language,
      'status': _sessionStatusToString(status),
      'startedAt': Timestamp.fromDate(startedAt.toUtc()),
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!.toUtc()),
      'messageCount': messageCount,
      'finalRecommendationMessageId': finalRecommendationMessageId,
    };
  }
}

class AIChatStoredMessage {
  const AIChatStoredMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.messageType,
    required this.productIds,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String sessionId;
  final AIChatMessageRole role;
  final String content;
  final AIChatMessageType messageType;
  final List<String> productIds;
  final DateTime createdAt;

  factory AIChatStoredMessage.fromJson(Map<String, dynamic> json) {
    return AIChatStoredMessage(
      schemaVersion: _asInt(json['_schemaVersion']) ?? 1,
      id: _requiredString(json, 'id'),
      sessionId: _requiredString(json, 'sessionId'),
      role: _parseMessageRole(json['role']),
      content: _requiredString(json, 'content'),
      messageType: _parseMessageType(json['messageType']),
      productIds: _asStringList(json['productIds']),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_schemaVersion': schemaVersion,
      'id': id,
      'sessionId': sessionId,
      'role': _messageRoleToString(role),
      'content': content,
      'messageType': _messageTypeToString(messageType),
      'productIds': productIds,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    };
  }
}

class AIUnifiedFeedback {
  const AIUnifiedFeedback._({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.feedbackScope,
    required this.isHelpful,
    required this.submittedAt,
    required this.targetMessageId,
    required this.rating,
    required this.comment,
    required this.analysisStatus,
    this.schemaVersion = 1,
  }) : assert(
         feedbackScope == AIUnifiedFeedbackScope.message
             ? targetMessageId != null && rating == null
             : targetMessageId == null && rating != null,
         'AIUnifiedFeedback invariants are violated.',
       );

  factory AIUnifiedFeedback.message({
    required String id,
    required String sessionId,
    required String userId,
    required String targetMessageId,
    required bool isHelpful,
    required DateTime submittedAt,
    String? comment,
    AIFeedbackAnalysisStatus? analysisStatus,
    int schemaVersion = 1,
  }) {
    final cleanTargetMessageId = targetMessageId.trim();
    if (cleanTargetMessageId.isEmpty) {
      _contractError('targetMessageId is required for message feedback.');
    }
    return AIUnifiedFeedback._(
      schemaVersion: schemaVersion,
      id: id.trim(),
      sessionId: sessionId.trim(),
      userId: userId.trim(),
      feedbackScope: AIUnifiedFeedbackScope.message,
      targetMessageId: cleanTargetMessageId,
      rating: null,
      isHelpful: isHelpful,
      comment: _normalizeComment(comment),
      submittedAt: submittedAt,
      analysisStatus: analysisStatus,
    );
  }

  factory AIUnifiedFeedback.session({
    required String id,
    required String sessionId,
    required String userId,
    required int rating,
    required bool isHelpful,
    required DateTime submittedAt,
    String? comment,
    AIFeedbackAnalysisStatus? analysisStatus,
    int schemaVersion = 1,
  }) {
    if (rating < 1 || rating > 5) {
      _contractError('rating must be between 1 and 5 for session feedback.');
    }
    return AIUnifiedFeedback._(
      schemaVersion: schemaVersion,
      id: id.trim(),
      sessionId: sessionId.trim(),
      userId: userId.trim(),
      feedbackScope: AIUnifiedFeedbackScope.session,
      targetMessageId: null,
      rating: rating,
      isHelpful: isHelpful,
      comment: _normalizeComment(comment),
      submittedAt: submittedAt,
      analysisStatus: analysisStatus,
    );
  }

  final int schemaVersion;
  final String id;
  final String sessionId;
  final String userId;
  final AIUnifiedFeedbackScope feedbackScope;
  final String? targetMessageId;
  final int? rating;
  final bool isHelpful;
  final String? comment;
  final DateTime submittedAt;
  final AIFeedbackAnalysisStatus? analysisStatus;

  factory AIUnifiedFeedback.fromJson(Map<String, dynamic> json) {
    final feedbackScope = _parseFeedbackScope(json['feedbackScope']);
    final id = _requiredString(json, 'id');
    final sessionId = _requiredString(json, 'sessionId');
    final userId = _requiredString(json, 'userId');
    final isHelpful = _requiredBool(json, 'isHelpful');
    final submittedAt = _requiredDateTime(json, 'submittedAt');
    final comment = _normalizeComment(_asNullableString(json['comment']));
    final analysisStatus = _parseNullableAnalysisStatus(json['analysisStatus']);

    if (feedbackScope == AIUnifiedFeedbackScope.message) {
      final targetMessageId = _asNullableString(json['targetMessageId']);
      if (targetMessageId == null) {
        _contractError(
          'targetMessageId is required when feedbackScope is message.',
        );
      }
      if (json['rating'] != null) {
        _contractError('rating must be null when feedbackScope is message.');
      }
      return AIUnifiedFeedback.message(
        id: id,
        sessionId: sessionId,
        userId: userId,
        targetMessageId: targetMessageId,
        isHelpful: isHelpful,
        submittedAt: submittedAt,
        comment: comment,
        analysisStatus: analysisStatus,
        schemaVersion: _asInt(json['_schemaVersion']) ?? 1,
      );
    }

    final rating = _requiredInt(json, 'rating');
    if (json['targetMessageId'] != null) {
      _contractError(
        'targetMessageId must be null when feedbackScope is session.',
      );
    }
    return AIUnifiedFeedback.session(
      id: id,
      sessionId: sessionId,
      userId: userId,
      rating: rating,
      isHelpful: isHelpful,
      submittedAt: submittedAt,
      comment: comment,
      analysisStatus: analysisStatus,
      schemaVersion: _asInt(json['_schemaVersion']) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_schemaVersion': schemaVersion,
      'id': id,
      'sessionId': sessionId,
      'userId': userId,
      'feedbackScope': _feedbackScopeToString(feedbackScope),
      'targetMessageId': targetMessageId,
      'rating': rating,
      'isHelpful': isHelpful,
      'comment': comment,
      'submittedAt': Timestamp.fromDate(submittedAt.toUtc()),
      'analysisStatus': analysisStatus == null
          ? null
          : _analysisStatusToString(analysisStatus!),
    };
  }
}

class AIFeedbackAnalysis {
  const AIFeedbackAnalysis({
    required this.id,
    required this.sessionId,
    required this.feedbackId,
    required this.intentUnderstood,
    required this.needSatisfied,
    required this.satisfactionScore,
    required this.sentiment,
    required this.analysisSummary,
    required this.missingNeeds,
    required this.rawInput,
    required this.rawModelOutput,
    required this.metadata,
    required this.analyzedAt,
    required this.status,
    this.failureReason,
    this.improvementSuggestion,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String sessionId;
  final String feedbackId;
  final bool intentUnderstood;
  final bool needSatisfied;
  final double satisfactionScore;
  final AIFeedbackSentiment sentiment;
  final String? analysisSummary;
  final String? failureReason;
  final String? improvementSuggestion;
  final List<String> missingNeeds;
  final Map<String, dynamic> rawInput;
  final Map<String, dynamic> rawModelOutput;
  final Map<String, dynamic> metadata;
  final DateTime analyzedAt;
  final AIFeedbackAnalysisStatus status;

  factory AIFeedbackAnalysis.fromJson(Map<String, dynamic> json) {
    return AIFeedbackAnalysis(
      schemaVersion: _asInt(json['_schemaVersion']) ?? 1,
      id: _requiredString(json, 'id'),
      sessionId: _requiredString(json, 'sessionId'),
      feedbackId: _requiredString(json, 'feedbackId'),
      intentUnderstood: _requiredBool(json, 'intentUnderstood'),
      needSatisfied: _requiredBool(json, 'needSatisfied'),
      satisfactionScore: _requiredDouble(json, 'satisfactionScore'),
      sentiment: _parseSentiment(json['sentiment']),
      analysisSummary: _asNullableString(json['analysisSummary']),
      failureReason: _asNullableString(json['failureReason']),
      improvementSuggestion: _asNullableString(json['improvementSuggestion']),
      missingNeeds: _asStringList(json['missingNeeds']),
      rawInput: _asMap(json['rawInput']),
      rawModelOutput: _asMap(json['rawModelOutput']),
      metadata: _asMap(json['metadata']),
      analyzedAt: _requiredDateTime(json, 'analyzedAt'),
      status: _parseAnalysisStatus(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_schemaVersion': schemaVersion,
      'id': id,
      'sessionId': sessionId,
      'feedbackId': feedbackId,
      'intentUnderstood': intentUnderstood,
      'needSatisfied': needSatisfied,
      'satisfactionScore': satisfactionScore,
      'sentiment': _sentimentToString(sentiment),
      'analysisSummary': analysisSummary,
      'failureReason': failureReason,
      'improvementSuggestion': improvementSuggestion,
      'missingNeeds': missingNeeds,
      'rawInput': rawInput,
      'rawModelOutput': rawModelOutput,
      'metadata': metadata,
      'analyzedAt': Timestamp.fromDate(analyzedAt.toUtc()),
      'status': _analysisStatusToString(status),
    };
  }
}

String? _asNullableString(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString());
}

String? _normalizeComment(String? comment) {
  final text = comment?.trim();
  if (text == null || text.isEmpty) return null;
  return text.length <= 280 ? text : text.substring(0, 280);
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  if (value is Map) {
    return value.map(
      (key, dynamic nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

AIChatSessionStatus _parseSessionStatus(dynamic value) {
  final normalized = (value ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'active':
      return AIChatSessionStatus.active;
    case 'ended':
      return AIChatSessionStatus.ended;
    default:
      _contractError('Invalid AIChatSessionStatus value: "$normalized".');
  }
}

String _sessionStatusToString(AIChatSessionStatus status) {
  return status == AIChatSessionStatus.ended ? 'ended' : 'active';
}

AIChatMessageRole _parseMessageRole(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'user':
      return AIChatMessageRole.user;
    case 'assistant':
      return AIChatMessageRole.assistant;
    case 'system':
      return AIChatMessageRole.system;
    default:
      _contractError('Invalid AIChatMessageRole value: "${value ?? ''}".');
  }
}

String _messageRoleToString(AIChatMessageRole role) {
  switch (role) {
    case AIChatMessageRole.assistant:
      return 'assistant';
    case AIChatMessageRole.system:
      return 'system';
    case AIChatMessageRole.user:
      return 'user';
  }
}

AIChatMessageType _parseMessageType(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'text':
      return AIChatMessageType.text;
    case 'recommendation':
      return AIChatMessageType.recommendation;
    case 'availability':
      return AIChatMessageType.availability;
    case 'loading':
      return AIChatMessageType.loading;
    case 'error':
      return AIChatMessageType.error;
    default:
      _contractError('Invalid AIChatMessageType value: "${value ?? ''}".');
  }
}

String _messageTypeToString(AIChatMessageType messageType) {
  switch (messageType) {
    case AIChatMessageType.recommendation:
      return 'recommendation';
    case AIChatMessageType.availability:
      return 'availability';
    case AIChatMessageType.loading:
      return 'loading';
    case AIChatMessageType.error:
      return 'error';
    case AIChatMessageType.text:
      return 'text';
  }
}

AIUnifiedFeedbackScope _parseFeedbackScope(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'message':
      return AIUnifiedFeedbackScope.message;
    case 'session':
      return AIUnifiedFeedbackScope.session;
    default:
      _contractError('Invalid AIUnifiedFeedbackScope value: "${value ?? ''}".');
  }
}

String _feedbackScopeToString(AIUnifiedFeedbackScope feedbackScope) {
  return feedbackScope == AIUnifiedFeedbackScope.session
      ? 'session'
      : 'message';
}

AIFeedbackAnalysisStatus _parseAnalysisStatus(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'pending':
      return AIFeedbackAnalysisStatus.pending;
    case 'completed':
      return AIFeedbackAnalysisStatus.completed;
    case 'failed':
      return AIFeedbackAnalysisStatus.failed;
    case 'pending_retry':
      return AIFeedbackAnalysisStatus.pendingRetry;
    default:
      _contractError(
        'Invalid AIFeedbackAnalysisStatus value: "${value ?? ''}".',
      );
  }
}

AIFeedbackAnalysisStatus? _parseNullableAnalysisStatus(dynamic value) {
  if (value == null) return null;
  return _parseAnalysisStatus(value);
}

String _analysisStatusToString(AIFeedbackAnalysisStatus status) {
  switch (status) {
    case AIFeedbackAnalysisStatus.completed:
      return 'completed';
    case AIFeedbackAnalysisStatus.failed:
      return 'failed';
    case AIFeedbackAnalysisStatus.pendingRetry:
      return 'pending_retry';
    case AIFeedbackAnalysisStatus.pending:
      return 'pending';
  }
}

AIFeedbackSentiment _parseSentiment(dynamic value) {
  switch ((value ?? '').toString().trim().toLowerCase()) {
    case 'positive':
      return AIFeedbackSentiment.positive;
    case 'negative':
      return AIFeedbackSentiment.negative;
    case 'neutral':
      return AIFeedbackSentiment.neutral;
    default:
      _contractError('Invalid AIFeedbackSentiment value: "${value ?? ''}".');
  }
}

String _sentimentToString(AIFeedbackSentiment sentiment) {
  switch (sentiment) {
    case AIFeedbackSentiment.negative:
      return 'negative';
    case AIFeedbackSentiment.neutral:
      return 'neutral';
    case AIFeedbackSentiment.positive:
      return 'positive';
  }
}
