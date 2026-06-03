import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

enum AIChatConversationIntent {
  social,
  advisory,
  clarification,
  catalogRecommendation,
  availability,
  productContextAnswer,
  visibleProductsQuestion,
  externalReference,
  businessInfo,
  noMatch,
  unknown,
}

enum AIChatCardPolicy {
  answerOnly,
  purchaseCtaCard,
  recommendationGrid,
  noCards,
}

class AIChatProductResponseFact {
  const AIChatProductResponseFact({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.stock,
    required this.family,
    required this.intensity,
    required this.reason,
  });

  final String id;
  final String name;
  final String brand;
  final double price;
  final int stock;
  final String family;
  final String intensity;
  final String reason;

  bool get isAvailable => stock > 0;
}

class AIChatResponseFacts {
  const AIChatResponseFacts({
    required this.intent,
    required this.cardPolicy,
    required this.source,
    required this.products,
    this.renderIntent,
    this.answer,
    this.question,
    this.disclosures = const <String>[],
    this.constraints = const <String>[],
    this.preferences = const SessionPreferences(),
  });

  final AIChatConversationIntent intent;
  final AIChatCardPolicy cardPolicy;
  final String source;
  final String? renderIntent;
  final String? answer;
  final String? question;
  final List<AIChatProductResponseFact> products;
  final List<String> disclosures;
  final List<String> constraints;
  final SessionPreferences preferences;

  bool get hasProducts => products.isNotEmpty;

  factory AIChatResponseFacts.fromRecommendations({
    required String source,
    required List<RecommendedProduct> recommendations,
    required SessionPreferences preferences,
    String? renderIntent,
    List<String> disclosures = const <String>[],
  }) {
    return AIChatResponseFacts(
      intent: _intentFromSource(source),
      cardPolicy: _cardPolicyFromSource(source),
      source: source,
      renderIntent: renderIntent ?? _renderIntentFromSource(source),
      disclosures: disclosures,
      preferences: preferences,
      products: recommendations
          .map(
            (item) => AIChatProductResponseFact(
              id: item.product.id,
              name: item.product.name,
              brand: item.product.brand,
              price: item.product.effectivePrice,
              stock: item.product.stock,
              family: item.product.fragranceFamily,
              intensity: item.product.intensity,
              reason: item.matchReason,
            ),
          )
          .toList(growable: false),
    );
  }

  factory AIChatResponseFacts.answer({
    required String source,
    required String answer,
    required AIChatConversationIntent intent,
    AIChatCardPolicy cardPolicy = AIChatCardPolicy.answerOnly,
    SessionPreferences preferences = const SessionPreferences(),
    List<String> disclosures = const <String>[],
    List<String> constraints = const <String>[],
  }) {
    return AIChatResponseFacts(
      intent: intent,
      cardPolicy: cardPolicy,
      source: source,
      answer: answer,
      products: const <AIChatProductResponseFact>[],
      disclosures: disclosures,
      constraints: constraints,
      preferences: preferences,
    );
  }

  factory AIChatResponseFacts.ask({
    required String source,
    required String question,
    SessionPreferences preferences = const SessionPreferences(),
    List<String> constraints = const <String>[],
  }) {
    return AIChatResponseFacts(
      intent: AIChatConversationIntent.clarification,
      cardPolicy: AIChatCardPolicy.noCards,
      source: source,
      question: question,
      products: const <AIChatProductResponseFact>[],
      constraints: constraints,
      preferences: preferences,
    );
  }

  factory AIChatResponseFacts.noMatch({
    required String source,
    required String answer,
    SessionPreferences preferences = const SessionPreferences(),
    List<String> disclosures = const <String>[],
    List<String> constraints = const <String>[],
  }) {
    return AIChatResponseFacts(
      intent: AIChatConversationIntent.noMatch,
      cardPolicy: AIChatCardPolicy.noCards,
      source: source,
      renderIntent: 'noMatch',
      answer: answer,
      products: const <AIChatProductResponseFact>[],
      disclosures: disclosures,
      constraints: constraints,
      preferences: preferences,
    );
  }

  static AIChatConversationIntent _intentFromSource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('availability')) {
      return AIChatConversationIntent.availability;
    }
    if (normalized.contains('external')) {
      return AIChatConversationIntent.externalReference;
    }
    if (normalized.contains('nomatch') || normalized.contains('no_match')) {
      return AIChatConversationIntent.noMatch;
    }
    if (normalized.contains('question') || normalized.contains('answer')) {
      return AIChatConversationIntent.productContextAnswer;
    }
    return AIChatConversationIntent.catalogRecommendation;
  }

  static AIChatCardPolicy _cardPolicyFromSource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('availability')) {
      return AIChatCardPolicy.purchaseCtaCard;
    }
    if (normalized.contains('question') || normalized.contains('answer')) {
      return AIChatCardPolicy.answerOnly;
    }
    if (normalized.contains('clarification') ||
        normalized.contains('nomatch') ||
        normalized.contains('no_match')) {
      return AIChatCardPolicy.noCards;
    }
    return AIChatCardPolicy.recommendationGrid;
  }

  static String _renderIntentFromSource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('rejectvisible')) return 'rejectionRecovery';
    if (normalized.contains('cheaperfollowup')) return 'cheaperFollowup';
    if (normalized.contains('similarcheapertoexternal')) {
      return 'externalProfileCheaper';
    }
    if (normalized.contains('externalprofile')) {
      return 'externalProfileSimilar';
    }
    if (normalized.contains('reference_cheaper')) return 'similarCheaper';
    if (normalized.contains('similarcheaper')) return 'similarCheaper';
    if (normalized.contains('any_other') ||
        normalized.contains('another') ||
        normalized.contains('alternative')) {
      return 'alternativeRecommendation';
    }
    if (normalized.contains('budget') ||
        normalized.contains('showlowestavailableafterbudgetnomatch')) {
      return 'budgetFloor';
    }
    if (normalized.contains('preference')) return 'preferenceRefinement';
    if (normalized.contains('availability')) return 'availability';
    return 'catalogRecommendation';
  }
}
