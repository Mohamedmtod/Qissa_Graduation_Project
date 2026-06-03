import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

enum AIChatStructuredType {
  message,
  ask,
  recommendation,
  noMatch,
  availability,
  comparison,
  refusal,
  error,
}

enum AIChatCommandAction {
  showRecommendationCards,
  showProductCard,
  keepVisibleCards,
  showNoMatch,
  unknown,
}

class AIChatCommand {
  final AIChatCommandAction action;
  final List<String> productIds;
  final String? displayMode;

  const AIChatCommand({
    required this.action,
    this.productIds = const [],
    this.displayMode,
  });

  factory AIChatCommand.fromJson(Map<String, dynamic> json) {
    return AIChatCommand(
      action: _actionFromWire(json['action']),
      productIds: AIChatStructuredReply._stringList(
        json['productIds'] ?? json['product_ids'],
      ).take(3).toList(),
      displayMode: json['displayMode']?.toString(),
    );
  }

  static AIChatCommandAction _actionFromWire(Object? raw) {
    final value = raw.toString().trim();
    switch (value) {
      case 'show_recommendation_cards':
        return AIChatCommandAction.showRecommendationCards;
      case 'show_product_card':
        return AIChatCommandAction.showProductCard;
      case 'keep_visible_cards':
        return AIChatCommandAction.keepVisibleCards;
      case 'show_no_match':
        return AIChatCommandAction.showNoMatch;
    }
    return AIChatCommandAction.unknown;
  }
}

class AIChatStructuredReply {
  final int schemaVersion;
  final AIChatStructuredType type;
  final String message;
  final PreferencePatch? preferencesPatch;
  final List<AIChatCommand> commands;
  final Map<String, String> recommendationReasons;
  final Map<String, dynamic> metadata;

  const AIChatStructuredReply({
    required this.schemaVersion,
    required this.type,
    required this.message,
    this.preferencesPatch,
    this.commands = const [],
    this.recommendationReasons = const {},
    this.metadata = const {},
  });

  factory AIChatStructuredReply.fromJson(Map<String, dynamic> json) {
    final patchRaw =
        json['preferencesPatch'] as Map<String, dynamic>? ??
        json['preferencePatch'] as Map<String, dynamic>? ??
        json['preference_patch'] as Map<String, dynamic>?;
    final commandsRaw = json['commands'];
    final metadataRaw = json['metadata'];
    return AIChatStructuredReply(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
      type: _typeFromWire(json['type']),
      message: (json['message'] ?? json['answer'] ?? json['question'] ?? '')
          .toString()
          .trim(),
      preferencesPatch: PreferencePatch.fromJson(patchRaw),
      commands: commandsRaw is Iterable
          ? commandsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      AIChatCommand.fromJson(Map<String, dynamic>.from(item)),
                )
                .where(
                  (command) => command.action != AIChatCommandAction.unknown,
                )
                .toList(growable: false)
          : const <AIChatCommand>[],
      recommendationReasons: _recommendationReasons(json['recommendations']),
      metadata: metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : const <String, dynamic>{},
    );
  }

  AIChatReply toAIChatReply({required AIChatLanguage language}) {
    final requestId = metadata['requestId'] as String?;
    final promptVersion =
        metadata['promptVersion'] as String? ??
        metadata['prompt_version'] as String? ??
        'chat_v2_structured_commands';
    final provider = metadata['provider'] as String?;
    final modelId = metadata['modelId'] as String?;
    final patch = preferencesPatch?.isEmpty == true ? null : preferencesPatch;
    final basePreferences = const SessionPreferences();

    AIChatCommand? cardsCommand;
    for (final command in commands) {
      if (command.action == AIChatCommandAction.showRecommendationCards ||
          command.action == AIChatCommandAction.showProductCard) {
        cardsCommand = command;
        break;
      }
    }
    if ((type == AIChatStructuredType.recommendation ||
            type == AIChatStructuredType.availability) &&
        cardsCommand != null &&
        cardsCommand.productIds.isNotEmpty) {
      final productIds = cardsCommand.productIds
          .take(3)
          .toList(growable: false);
      return AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final id in productIds)
            id: _normalizeReason(
              recommendationReasons[id] ?? _fallbackMatchReason(language),
              language,
            ),
        },
        updatedPreferences: basePreferences,
        answer: message.isEmpty ? null : message,
        preferencePatch: patch,
        requestId: requestId,
        promptVersion: promptVersion,
        provider: provider,
        modelId: modelId,
      );
    }

    if (type == AIChatStructuredType.ask) {
      return AIChatReply.ask(
        question: message.isEmpty ? _fallbackQuestion(language) : message,
        updatedPreferences: basePreferences,
        preferencePatch: patch,
        requestId: requestId,
        promptVersion: promptVersion,
        provider: provider,
        modelId: modelId,
      );
    }

    return AIChatReply.answer(
      answer: message.isEmpty ? _fallbackAnswer(language) : message,
      updatedPreferences: basePreferences,
      preferencePatch: patch,
      requestId: requestId,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
    );
  }

  static AIChatStructuredType _typeFromWire(Object? raw) {
    final value = raw.toString().trim();
    switch (value) {
      case 'message':
        return AIChatStructuredType.message;
      case 'ask':
        return AIChatStructuredType.ask;
      case 'recommendation':
      case 'recommend':
        return AIChatStructuredType.recommendation;
      case 'no_match':
      case 'noMatch':
        return AIChatStructuredType.noMatch;
      case 'availability':
        return AIChatStructuredType.availability;
      case 'comparison':
        return AIChatStructuredType.comparison;
      case 'refusal':
        return AIChatStructuredType.refusal;
      case 'error':
        return AIChatStructuredType.error;
    }
    return AIChatStructuredType.message;
  }

  static Map<String, String> _recommendationReasons(Object? raw) {
    if (raw is! Iterable) return const <String, String>{};
    final reasons = <String, String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final productId =
          item['productId']?.toString().trim() ??
          item['product_id']?.toString().trim() ??
          '';
      final reason = item['reason']?.toString().trim() ?? '';
      if (productId.isNotEmpty && reason.isNotEmpty) {
        reasons[productId] = reason;
      }
    }
    return reasons;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! Iterable) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _normalizeReason(String reason, AIChatLanguage language) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return _fallbackMatchReason(language);
    return trimmed;
  }

  static String _fallbackMatchReason(AIChatLanguage language) {
    return language.isArabic
        ? 'هذا الاختيار مناسب لتفضيلاتك الحالية.'
        : 'This option matches your current preferences.';
  }

  static String _fallbackQuestion(AIChatLanguage language) {
    return language.isArabic
        ? 'ممكن توضح تفضيل واحد إضافي؟'
        : 'Could you clarify one more preference?';
  }

  static String _fallbackAnswer(AIChatLanguage language) {
    return language.isArabic
        ? 'لا أقدر أعرض ترشيح آمن من البيانات الحالية.'
        : 'I cannot show a safe recommendation from the current data.';
  }
}
