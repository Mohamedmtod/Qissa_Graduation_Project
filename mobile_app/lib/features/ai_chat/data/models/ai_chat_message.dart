import 'package:perfume_app/features/products/data/models/product_model.dart';

enum RecommendedBudgetStatus { withinBudget, slightlyAboveBudget }

enum RecommendedCandidateSource { strict, upsell, relaxed }

/// Who sent the message.
enum MessageSender { user, bot }

/// What kind of content the message carries.
enum MessageType {
  /// Plain text (user input or bot question/fallback).
  text,

  /// Bot message that contains product recommendations.
  recommendation,

  /// Bot message that contains a single availability product card.
  availability,

  /// Temporary placeholder while waiting for a response.
  loading,

  /// An error / fallback message.
  error,
}

/// A single message in the AI chat conversation.
class AIChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final MessageType type;
  final DateTime timestamp;

  /// Only populated when [type] is [MessageType.recommendation].
  final List<RecommendedProduct> recommendedProducts;
  final String? responseSource;
  final String? promptVersion;
  final String? provider;
  final String? modelId;
  final String? workerFailureReason;

  const AIChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    this.type = MessageType.text,
    required this.timestamp,
    this.recommendedProducts = const [],
    this.responseSource,
    this.promptVersion,
    this.provider,
    this.modelId,
    this.workerFailureReason,
  });

  /// Convenience factory for user messages.
  factory AIChatMessage.user(String content) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.user,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );
  }

  /// Convenience factory for bot text messages (questions, fallbacks).
  factory AIChatMessage.botText(
    String content, {
    String? responseSource,
    String? promptVersion,
    String? provider,
    String? modelId,
    String? workerFailureReason,
  }) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.bot,
      type: MessageType.text,
      timestamp: DateTime.now(),
      responseSource: responseSource,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
      workerFailureReason: workerFailureReason,
    );
  }

  /// Convenience factory for bot recommendation messages.
  factory AIChatMessage.botRecommendation({
    required String content,
    required List<RecommendedProduct> products,
    String? responseSource,
    String? promptVersion,
    String? provider,
    String? modelId,
    String? workerFailureReason,
  }) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.bot,
      type: MessageType.recommendation,
      timestamp: DateTime.now(),
      recommendedProducts: products,
      responseSource: responseSource,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
      workerFailureReason: workerFailureReason,
    );
  }

  /// Convenience factory for availability replies that need a product card.
  factory AIChatMessage.botAvailability({
    required String content,
    required List<RecommendedProduct> products,
    String? responseSource,
    String? promptVersion,
    String? provider,
    String? modelId,
    String? workerFailureReason,
  }) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.bot,
      type: MessageType.availability,
      timestamp: DateTime.now(),
      recommendedProducts: products,
      responseSource: responseSource,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
      workerFailureReason: workerFailureReason,
    );
  }

  /// Convenience factory for the loading indicator message.
  factory AIChatMessage.loading() {
    return AIChatMessage(
      id: 'loading',
      content: '',
      sender: MessageSender.bot,
      type: MessageType.loading,
      timestamp: DateTime.now(),
    );
  }

  /// Convenience factory for error/fallback messages.
  factory AIChatMessage.error(
    String content, {
    String? responseSource,
    String? promptVersion,
    String? provider,
    String? modelId,
    String? workerFailureReason,
  }) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.bot,
      type: MessageType.error,
      timestamp: DateTime.now(),
      responseSource: responseSource,
      promptVersion: promptVersion,
      provider: provider,
      modelId: modelId,
      workerFailureReason: workerFailureReason,
    );
  }

  AIChatMessage copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    MessageType? type,
    DateTime? timestamp,
    List<RecommendedProduct>? recommendedProducts,
    String? responseSource,
    String? promptVersion,
    String? provider,
    String? modelId,
    String? workerFailureReason,
  }) {
    return AIChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      recommendedProducts: recommendedProducts ?? this.recommendedProducts,
      responseSource: responseSource ?? this.responseSource,
      promptVersion: promptVersion ?? this.promptVersion,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      workerFailureReason: workerFailureReason ?? this.workerFailureReason,
    );
  }

  bool get isLoading => type == MessageType.loading;
  bool get isRecommendation => type == MessageType.recommendation;
  bool get isAvailability => type == MessageType.availability;
  bool get isFromUser => sender == MessageSender.user;
  bool get isFromBot => sender == MessageSender.bot;
}

/// A product bundled with its AI-computed match score and reason.
class RecommendedProduct {
  final ProductModel product;
  final double matchScore;
  final String matchLabel;
  final String matchReason;
  final RecommendedBudgetStatus budgetStatus;
  final double? exactBudget;
  final RecommendedCandidateSource candidateSource;

  const RecommendedProduct({
    required this.product,
    required this.matchScore,
    required this.matchLabel,
    required this.matchReason,
    this.budgetStatus = RecommendedBudgetStatus.withinBudget,
    this.exactBudget,
    this.candidateSource = RecommendedCandidateSource.strict,
  });

  double? get overBudgetAmount {
    if (budgetStatus != RecommendedBudgetStatus.slightlyAboveBudget ||
        exactBudget == null) {
      return null;
    }
    return product.effectivePrice - exactBudget!;
  }

  double? get overBudgetPercent {
    final amount = overBudgetAmount;
    if (amount == null || exactBudget == null || exactBudget == 0) {
      return null;
    }
    return (amount / exactBudget!) * 100;
  }
}
