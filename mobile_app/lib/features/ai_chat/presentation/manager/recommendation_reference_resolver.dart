import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';

class RecommendationReferenceResolver {
  static final RegExp _numericReferenceRegex = RegExp(
    r'(?:^|[^\d])#?([1-9])(?=$|[^\d])',
  );

  static final Map<String, int> _arabicOrderMap = {
    'الاول': 1,
    'الأول': 1,
    'الثاني': 2,
    'التاني': 2,
    'الثالث': 3,
    'التالت': 3,
    'الرابع': 4,
    'الخامس': 5,
    'الاخير': -1,
    'الأخير': -1,
    'اخر واحد': -1,
    'آخر واحد': -1,
  };

  static final Map<String, int> _englishOrderMap = {
    'first': 1,
    'second': 2,
    'third': 3,
    'fourth': 4,
    'fifth': 5,
    'last': -1,
    'the last one': -1,
  };

  /// Resolves which products are being referred to in the [message].
  /// Returns a list of [RecommendedProductRef] matches.
  static List<RecommendedProductRef> resolve({
    required String message,
    required RecommendationMemory memory,
  }) {
    if (memory.lastRecommendedProducts.isEmpty) return [];

    final normalized = _normalizeArabic(
      AIChatTextNormalizer.normalizeForParsing(message),
    );
    final matches = <RecommendedProductRef>{};

    // 1. Resolve by Order (e.g. "الأول", "the second one")
    final orderIndices = _findOrderIndices(normalized);
    for (final orderIdx in orderIndices) {
      if (orderIdx == -1) {
        // Last one
        matches.add(memory.lastRecommendedProducts.last);
      } else if (orderIdx <= memory.lastRecommendedProducts.length) {
        matches.add(memory.lastRecommendedProducts[orderIdx - 1]);
      }
    }

    // 2. Resolve by Name (e.g. "Yara", "Asad")
    for (final product in memory.lastRecommendedProducts) {
      final prodName = _normalizeArabic(product.name.toLowerCase());
      if (normalized.contains(prodName)) {
        matches.add(product);
      }
    }

    // 3. Resolve by Focus / Pronouns (e.g. "ده", "this one")
    // Only if no explicit name or order is found, and we have a focused product.
    if (matches.isEmpty) {
      final containsPronoun = _hasPronoun(normalized);
      if (containsPronoun) {
        if (memory.lastFocusedProductId != null) {
          final focused = memory.lastRecommendedProducts.firstWhere(
            (p) => p.productId == memory.lastFocusedProductId,
            orElse: () => memory.lastRecommendedProducts.first,
          );
          matches.add(focused);
        } else {
          matches.add(memory.lastRecommendedProducts.first);
        }
      }
    }

    return matches.toList();
  }

  static Set<int> _findOrderIndices(String message) {
    final indices = <int>{};
    for (final entry in _arabicOrderMap.entries) {
      if (message.contains(entry.key)) indices.add(entry.value);
    }
    for (final entry in _englishOrderMap.entries) {
      if (message.contains(entry.key)) indices.add(entry.value);
    }

    for (final match in _numericReferenceRegex.allMatches(message)) {
      final rawIndex = int.tryParse(match.group(1) ?? '');
      if (rawIndex != null && rawIndex > 0) {
        indices.add(rawIndex);
      }
    }

    return indices;
  }

  static bool _hasPronoun(String message) {
    const pronouns = [
      'ده',
      'هذا',
      'هذه',
      'هذا العطر',
      'this one',
      'that one',
      'it',
    ];
    for (final p in pronouns) {
      // Match the pronoun if it's preceded/followed by space, punctuation, or string boundaries
      final regex = RegExp(r'(?:^|\s|[.,!؟?])' + p + r'(?:$|\s|[.,!؟?])');
      if (regex.hasMatch(message)) return true;
    }
    return false;
  }

  static String _normalizeArabic(String input) {
    return input
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // Remove Tashkeel
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }
}
