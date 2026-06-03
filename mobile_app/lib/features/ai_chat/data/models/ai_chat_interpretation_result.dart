import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class AIChatInterpretationResult {
  static const Set<String> allowedIntents = {
    'recommendation',
    'modifier',
    'availability',
    'compare',
    'answer',
    'greeting',
    'off_topic',
    'unclear',
  };

  static const Set<String> allowedAskSlots = {
    'gender',
    'season',
    'maxBudget',
    'notesOrIntensity',
  };

  final String intent;
  final double confidence;
  final SessionPreferences preferencePatch;
  final String? askSlot;
  final String? productQueryCandidate;
  final String reasonCode;
  final bool hasForbiddenFields;

  const AIChatInterpretationResult({
    required this.intent,
    required this.confidence,
    required this.preferencePatch,
    required this.askSlot,
    required this.productQueryCandidate,
    required this.reasonCode,
    this.hasForbiddenFields = false,
  });

  bool get hasPreferencePatch =>
      preferencePatch.activeCriteriaCount > 0 ||
      preferencePatch.excludedNotes.isNotEmpty ||
      preferencePatch.rankingStrategy != null;

  factory AIChatInterpretationResult.fromJson(Map<String, dynamic> json) {
    final rawIntent = json['intent'];
    final intent =
        rawIntent is String && allowedIntents.contains(rawIntent.trim())
        ? rawIntent.trim()
        : 'unclear';

    final rawConfidence = json['confidence'];
    final parsedConfidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : rawConfidence is String
        ? double.tryParse(rawConfidence)
        : null;
    final confidence = (parsedConfidence ?? 0).clamp(0, 1).toDouble();

    final rawPatch = json['preferencePatch'] ?? json['preference_patch'];
    final preferencePatch = rawPatch is Map
        ? SessionPreferences.fromJson(Map<String, dynamic>.from(rawPatch))
        : SessionPreferences.empty();

    final rawAskSlot = json['askSlot'] ?? json['ask_slot'];
    final askSlot =
        rawAskSlot is String && allowedAskSlots.contains(rawAskSlot.trim())
        ? rawAskSlot.trim()
        : null;

    final rawProductQueryCandidate =
        json['productQueryCandidate'] ??
        json['product_query_candidate'] ??
        json['productQuery'];
    final productQueryCandidate =
        rawProductQueryCandidate is String &&
            rawProductQueryCandidate.trim().isNotEmpty
        ? rawProductQueryCandidate.trim()
        : null;

    final rawReasonCode = json['reasonCode'] ?? json['reason_code'];
    final reasonCode =
        rawReasonCode is String && rawReasonCode.trim().isNotEmpty
        ? rawReasonCode.trim()
        : 'unknown';

    final forbiddenKeys = {
      'product_ids',
      'productIds',
      'products',
      'recommendations',
      'answer',
      'message',
      'cards',
    };
    final hasForbiddenFields = json.keys.any(forbiddenKeys.contains);

    return AIChatInterpretationResult(
      intent: intent,
      confidence: confidence,
      preferencePatch: preferencePatch.sanitize(),
      askSlot: askSlot,
      productQueryCandidate: productQueryCandidate,
      reasonCode: reasonCode,
      hasForbiddenFields: hasForbiddenFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'confidence': confidence,
      'preferencePatch': preferencePatch.toJson(),
      'askSlot': askSlot,
      'productQueryCandidate': productQueryCandidate,
      'reasonCode': reasonCode,
      'hasForbiddenFields': hasForbiddenFields,
    };
  }
}
