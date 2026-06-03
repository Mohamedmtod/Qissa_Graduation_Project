import 'package:equatable/equatable.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

enum AIChatStatus {
  idle, // Waiting for user input
  loading, // Processing AI request or local parser
  ask, // Bot asked a clarifying question
  recommend, // Bot provided recommendations
  answer, // Bot provided a text answer (follow-up/comparison)
  noMatch, // No products matched the criteria (normal, not an error)
  error, // Something went wrong (network, parsing fail, exception)
}

/// The current state of an AI Chat session.
///
/// [AIChatState.preferences] is the **Source of Truth** for the user's
/// detected and explicitly stated preferences (gender, budget, etc.).
class AIChatState extends Equatable {
  final AIChatStatus status;
  final List<AIChatMessage> messages;

  /// The official source of truth for user preferences in this session.
  /// All AI and local logic must update this field to persist state.
  final SessionPreferences preferences;
  final RecommendationMemory recommendationMemory;
  final AvailabilityContext availabilityContext;
  final Set<String> notifiedProductIds;
  final AIChatLanguage language;
  final int cooldownSecondsRemaining;
  final String? errorMessage;
  final String? loadingPhase;

  const AIChatState({
    this.status = AIChatStatus.idle,
    this.messages = const [],
    this.preferences = const SessionPreferences(),
    this.recommendationMemory = const RecommendationMemory(),
    this.availabilityContext = const AvailabilityContext.empty(),
    this.notifiedProductIds = const {},
    this.language = AIChatLanguage.arabic,
    this.cooldownSecondsRemaining = 0,
    this.errorMessage,
    this.loadingPhase,
  });

  AIChatState copyWith({
    AIChatStatus? status,
    List<AIChatMessage>? messages,
    SessionPreferences? preferences,
    RecommendationMemory? recommendationMemory,
    AvailabilityContext? availabilityContext,
    Set<String>? notifiedProductIds,
    AIChatLanguage? language,
    int? cooldownSecondsRemaining,
    String? errorMessage,
    String? loadingPhase,
    bool clearLoadingPhase = false,
  }) {
    return AIChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      preferences: preferences ?? this.preferences,
      recommendationMemory: recommendationMemory ?? this.recommendationMemory,
      availabilityContext: availabilityContext ?? this.availabilityContext,
      notifiedProductIds: notifiedProductIds ?? this.notifiedProductIds,
      language: language ?? this.language,
      cooldownSecondsRemaining:
          cooldownSecondsRemaining ?? this.cooldownSecondsRemaining,
      errorMessage: errorMessage,
      loadingPhase: clearLoadingPhase
          ? null
          : loadingPhase ?? this.loadingPhase,
    );
  }

  bool get isInCooldown => cooldownSecondsRemaining > 0;

  @override
  List<Object?> get props => [
    status,
    messages,
    preferences,
    recommendationMemory,
    availabilityContext,
    notifiedProductIds,
    language,
    cooldownSecondsRemaining,
    errorMessage,
    loadingPhase,
  ];
}
