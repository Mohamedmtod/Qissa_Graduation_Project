import 'dart:convert';
import 'dart:developer';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_structured_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

class AIChatReplyValidator {
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _latinRegex = RegExp(r'[A-Za-z]');

  /// Parses and validates the raw JSON response from the worker.
  /// Handles stripping markdown JSON blocks that models sometimes return.
  ///
  /// [onMissingReasonCount]: called with the number of products whose
  /// match_reason was absent. Use this for telemetry / drift detection.
  static AIChatReply? parseAndValidate(
    String rawString, {
    AIChatLanguage language = AIChatLanguage.arabic,
    void Function(int count)? onMissingReasonCount,
  }) {
    try {
      var cleanString = rawString.trim();
      if (cleanString.startsWith('```json')) {
        cleanString = cleanString.substring(7);
      } else if (cleanString.startsWith('```')) {
        cleanString = cleanString.substring(3);
      }
      if (cleanString.endsWith('```')) {
        cleanString = cleanString.substring(0, cleanString.length - 3);
      }
      cleanString = cleanString.trim();

      final map = jsonDecode(cleanString) as Map<String, dynamic>;
      log(
        '[AIChatReplyValidator] Parsed string response | rawLength=${rawString.length} | cleanedLength=${cleanString.length}',
        name: 'AIChatReplyValidator',
      );
      return parseMap(
        map,
        language: language,
        onMissingReasonCount: onMissingReasonCount,
      );
    } catch (error, stackTrace) {
      log(
        '[AIChatReplyValidator] Failed to parse string response | rawLength=${rawString.length}',
        name: 'AIChatReplyValidator',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Parses from a Map (used when Dio automatically decodes JSON).
  static AIChatReply? parseMap(
    Map<String, dynamic> map, {
    AIChatLanguage language = AIChatLanguage.arabic,
    void Function(int count)? onMissingReasonCount,
  }) {
    try {
      if (_looksLikeStructuredV2(map)) {
        final structured = AIChatStructuredReply.fromJson(map);
        final reply = structured.toAIChatReply(language: language);
        log(
          '[AIChatReplyValidator] Parsed structured v2 response | '
          'type=${structured.type.name} | commandCount=${structured.commands.length} | '
          'requestId=${reply.requestId}',
          name: 'AIChatReplyValidator',
        );
        return reply;
      }

      final actionStr = map['action_type'] as String? ?? 'ask';
      final isRecommend = actionStr == 'recommend';
      final isAnswer = actionStr == 'answer' || actionStr == 'info';
      final isToolCall = actionStr == 'tool_call' || map['type'] == 'tool_call';

      final question = map['question'] as String?;
      final answer =
          map['answer'] as String? ??
          map['response'] as String? ??
          (isToolCall ? map['message'] as String? : null);

      final updatedPrefsMap =
          map['updated_preferences'] as Map<String, dynamic>?;
      final updatedPreferences = updatedPrefsMap != null
          ? SessionPreferences.fromJson(updatedPrefsMap).sanitize()
          : const SessionPreferences();

      final productIdsRaw = map['product_ids'] as List<dynamic>?;
      final productIds =
          productIdsRaw?.map((e) => e.toString()).toList() ?? const <String>[];

      final matchReasonsRaw = map['match_reason'] as Map<String, dynamic>?;
      final matchReasons =
          matchReasonsRaw?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const <String, String>{};

      final metadata = map['metadata'] as Map<String, dynamic>?;
      final preferencePatchRaw =
          map['preference_patch'] as Map<String, dynamic>? ??
          map['preferencePatch'] as Map<String, dynamic>?;
      final preferencePatch = PreferencePatch.fromJson(preferencePatchRaw);
      final requestId = metadata?['requestId'] as String?;
      final promptVersion = metadata?['promptVersion'] as String?;
      final provider = metadata?['provider'] as String?;
      final modelId = metadata?['modelId'] as String?;

      log(
        '[AIChatReplyValidator] Parsed map response | action=$actionStr | requestId=$requestId | '
        'promptVersion=$promptVersion | provider=$provider | modelId=$modelId | '
        'productCount=${productIds.length} | answerLength=${answer?.length ?? 0} | questionLength=${question?.length ?? 0}',
        name: 'AIChatReplyValidator',
      );

      if (isToolCall) {
        try {
          final rawToolCall = map['toolCall'] ?? map['tool_call'];
          final toolCallMap = rawToolCall is Map
              ? rawToolCall.map((key, value) => MapEntry(key.toString(), value))
              : null;
          return AIChatReply.toolCall(
            toolCall: AIChatToolCall.fromJson(toolCallMap),
            answer: answer,
            updatedPreferences: updatedPreferences,
            requestId: requestId,
            promptVersion: promptVersion,
            provider: provider,
            modelId: modelId,
            preferencePatch: preferencePatch.isEmpty ? null : preferencePatch,
          );
        } on FormatException catch (error) {
          log(
            '[AIChatReplyValidator] Invalid tool_call ignored | reason=${error.message}',
            name: 'AIChatReplyValidator',
          );
          return null;
        }
      }

      if (isRecommend) {
        final validProductIds = productIds.take(3).toList();
        var fallbackReasonCount = 0;

        final validMatchReasons = <String, String>{
          for (final id in validProductIds)
            id: matchReasons.containsKey(id)
                ? matchReasons[id]!
                : () {
                    fallbackReasonCount++;
                    return _fallbackMatchReason(language);
                  }(),
        };

        if (fallbackReasonCount > 0) {
          log(
            '[AIChatReplyValidator] Worker omitted match_reason for '
            '$fallbackReasonCount/${validProductIds.length} product(s).',
            name: 'AIChatReplyValidator',
          );
          onMissingReasonCount?.call(fallbackReasonCount);
        }

        final normalizedMatchReasons = <String, String>{
          for (final entry in validMatchReasons.entries)
            entry.key: _normalizeMatchReason(entry.value, language),
        };

        return AIChatReply.recommend(
          productIds: validProductIds,
          matchReasons: normalizedMatchReasons,
          updatedPreferences: updatedPreferences,
          answer: _normalizeOptionalAnswer(answer, language),
          requestId: requestId,
          promptVersion: promptVersion,
          provider: provider,
          modelId: modelId,
          preferencePatch: preferencePatch.isEmpty ? null : preferencePatch,
        );
      }

      if (isAnswer) {
        return AIChatReply.answer(
          answer: _normalizeAnswer(answer, language),
          updatedPreferences: updatedPreferences,
          requestId: requestId,
          promptVersion: promptVersion,
          provider: provider,
          modelId: modelId,
          preferencePatch: preferencePatch.isEmpty ? null : preferencePatch,
        );
      }

      return AIChatReply.ask(
        question: _normalizeQuestion(question, language, updatedPreferences),
        updatedPreferences: updatedPreferences,
        requestId: requestId,
        promptVersion: promptVersion,
        provider: provider,
        modelId: modelId,
        preferencePatch: preferencePatch.isEmpty ? null : preferencePatch,
      );
    } catch (error, stackTrace) {
      log(
        '[AIChatReplyValidator] Failed to parse map response',
        name: 'AIChatReplyValidator',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static bool _looksLikeStructuredV2(Map<String, dynamic> map) {
    if (map['type'] == 'tool_call' || map['action_type'] == 'tool_call') {
      return false;
    }
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is num && schemaVersion.toInt() >= 2) return true;
    if (schemaVersion?.toString() == '2') return true;
    return map.containsKey('commands') &&
        (map.containsKey('type') || map.containsKey('recommendations'));
  }

  static bool _containsArabic(String text) => _arabicRegex.hasMatch(text);

  static bool _containsLatin(String text) => _latinRegex.hasMatch(text);

  static bool _violatesExpectedLanguage(String? text, AIChatLanguage language) {
    if (text == null || text.trim().isEmpty) return true;
    if (language.isArabic) {
      return !_containsArabic(text) && _containsLatin(text);
    }
    return _containsArabic(text);
  }

  static String _fallbackMatchReason(AIChatLanguage language) {
    return language.isArabic
        ? 'هذا العطر يتماشى مع تفضيلاتك الحالية.'
        : 'This perfume matches your current preferences.';
  }

  static String _fallbackAnswer(AIChatLanguage language) {
    return language.isArabic
        ? 'تفضل، هل لديك أي استفسار آخر؟'
        : 'Here is the information you requested. Do you have any other questions?';
  }

  static String _fallbackQuestion(
    AIChatLanguage language,
    SessionPreferences updatedPreferences,
  ) {
    if (updatedPreferences.intensity == 'strong') {
      return language.isArabic
          ? 'هل تريد حدة أقوى أم طابعًا أكثر فوحانًا؟'
          : 'Do you want a stronger intensity or a more intense scent profile?';
    }

    return language.isArabic
        ? 'أحتاج تفاصيل أكثر قليلًا حتى أقدر أرشح لك بدقة. هل يمكنك توضيح ما تفضله؟'
        : 'I need a bit more detail so I can refine the recommendation. Could you clarify what you prefer?';
  }

  static String _normalizeMatchReason(String reason, AIChatLanguage language) {
    if (_violatesExpectedLanguage(reason, language)) {
      return _fallbackMatchReason(language);
    }
    return reason.trim();
  }

  static String _normalizeAnswer(String? answer, AIChatLanguage language) {
    if (_violatesExpectedLanguage(answer, language)) {
      return _fallbackAnswer(language);
    }
    return answer!.trim();
  }

  static String? _normalizeOptionalAnswer(
    String? answer,
    AIChatLanguage language,
  ) {
    if (answer == null || answer.trim().isEmpty) return null;
    if (_violatesExpectedLanguage(answer, language)) return null;
    return answer.trim();
  }

  static String _normalizeQuestion(
    String? question,
    AIChatLanguage language,
    SessionPreferences updatedPreferences,
  ) {
    if (_violatesExpectedLanguage(question, language)) {
      return _fallbackQuestion(language, updatedPreferences);
    }
    return question!.trim();
  }
}
