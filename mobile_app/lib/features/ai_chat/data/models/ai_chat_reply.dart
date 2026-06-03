import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';

/// The type of action the AI decides to take.
enum ActionType {
  /// Ask the user a clarifying question (not enough info to recommend).
  ask,

  /// Recommend products based on sufficient preferences.
  recommend,

  /// Provide a text-only answer (follow-up/comparison).
  answer,

  /// Ask the app to execute a deterministic tool locally.
  toolCall,
}

/// Structured reply from the AI (local parser in MVP, AI Worker in Phase 2).
///
/// In MVP, this is produced by the local intent parser + ranking logic.
/// In Phase 2, it will be parsed from the AI Worker's JSON response.
class AIChatReply {
  final ActionType actionType;

  /// The clarifying question to ask (only when [actionType] is [ActionType.ask]).
  final String? question;

  /// Selected product IDs (only when [actionType] is [ActionType.recommend]).
  final List<String> productIds;

  /// Map of product ID → short reason for recommending it.
  final Map<String, String> matchReasons;

  /// The text response for [ActionType.answer].
  final String? answer;

  /// Updated preferences after processing the user's message.
  final SessionPreferences updatedPreferences;

  final AIChatToolCall? toolCall;

  /// Explicit preference operations that cannot be represented safely by
  /// nullable/empty values in [updatedPreferences].
  final PreferencePatch? preferencePatch;

  /// The unique identifier for the request that generated this reply.
  final String? requestId;

  /// The version of the prompt used to generate this reply.
  final String? promptVersion;

  /// The provider used to generate this reply (e.g. gemini, anthropic).
  final String? provider;

  /// The specific model ID used to generate this reply.
  final String? modelId;

  const AIChatReply({
    required this.actionType,
    this.question,
    this.productIds = const [],
    this.matchReasons = const {},
    this.answer,
    required this.updatedPreferences,
    this.toolCall,
    this.preferencePatch,
    this.requestId,
    this.promptVersion,
    this.provider,
    this.modelId,
  });

  /// Creates an "ask" reply with a clarifying question.
  factory AIChatReply.ask({
    required String question,
    required SessionPreferences updatedPreferences,
    String? requestId,
    String? promptVersion,
    String? provider,
    String? modelId,
    PreferencePatch? preferencePatch,
  }) {
    return AIChatReply(
      actionType: ActionType.ask,
      question: question,
      updatedPreferences: updatedPreferences,
      preferencePatch: preferencePatch,
      requestId: requestId,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
    );
  }

  /// Creates a "recommend" reply with product IDs and reasons.
  factory AIChatReply.recommend({
    required List<String> productIds,
    required Map<String, String> matchReasons,
    required SessionPreferences updatedPreferences,
    String? answer,
    String? requestId,
    String? promptVersion,
    String? provider,
    String? modelId,
    PreferencePatch? preferencePatch,
  }) {
    return AIChatReply(
      actionType: ActionType.recommend,
      productIds: productIds,
      matchReasons: matchReasons,
      answer: answer,
      updatedPreferences: updatedPreferences,
      preferencePatch: preferencePatch,
      requestId: requestId,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
    );
  }

  /// Creates an "answer" reply with text-only response.
  factory AIChatReply.answer({
    required String answer,
    required SessionPreferences updatedPreferences,
    String? requestId,
    String? promptVersion,
    String? provider,
    String? modelId,
    PreferencePatch? preferencePatch,
  }) {
    return AIChatReply(
      actionType: ActionType.answer,
      answer: answer,
      updatedPreferences: updatedPreferences,
      preferencePatch: preferencePatch,
      requestId: requestId,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
    );
  }

  factory AIChatReply.toolCall({
    required AIChatToolCall toolCall,
    required SessionPreferences updatedPreferences,
    String? answer,
    String? requestId,
    String? promptVersion,
    String? provider,
    String? modelId,
    PreferencePatch? preferencePatch,
  }) {
    return AIChatReply(
      actionType: ActionType.toolCall,
      toolCall: toolCall,
      answer: answer,
      updatedPreferences: updatedPreferences,
      preferencePatch: preferencePatch,
      requestId: requestId,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
    );
  }

  bool get isAsk => actionType == ActionType.ask;
  bool get isRecommend => actionType == ActionType.recommend;
  bool get isAnswer => actionType == ActionType.answer;
  bool get isToolCall => actionType == ActionType.toolCall;
}
