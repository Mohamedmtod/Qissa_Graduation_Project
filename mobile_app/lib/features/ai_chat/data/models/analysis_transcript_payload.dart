class AnalysisTranscriptEntry {
  const AnalysisTranscriptEntry({
    required this.role,
    required this.messageType,
    this.content,
    this.productIds = const <String>[],
    this.matchSummary,
  });

  final String role;
  final String messageType;
  final String? content;
  final List<String> productIds;
  final String? matchSummary;

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'messageType': messageType,
      'content': content,
      'productIds': productIds,
      'matchSummary': matchSummary,
    };
  }
}

class AnalysisTranscriptPayload {
  const AnalysisTranscriptPayload({
    required this.sessionId,
    required this.preferences,
    required this.entries,
    required this.originalMessageCount,
    required this.compactedMessageCount,
    required this.finalRecommendationProductIds,
    this.finalRecommendationMessageId,
  });

  final String sessionId;
  final Map<String, dynamic> preferences;
  final List<AnalysisTranscriptEntry> entries;
  final int originalMessageCount;
  final int compactedMessageCount;
  final String? finalRecommendationMessageId;
  final List<String> finalRecommendationProductIds;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'preferences': preferences,
      'transcript': entries.map((entry) => entry.toJson()).toList(),
      'originalMessageCount': originalMessageCount,
      'compactedMessageCount': compactedMessageCount,
      'finalRecommendationMessageId': finalRecommendationMessageId,
      'finalRecommendationProductIds': finalRecommendationProductIds,
    };
  }
}
