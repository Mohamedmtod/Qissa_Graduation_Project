import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatRecommendationMemoryAnswerBuilder {
  const AIChatRecommendationMemoryAnswerBuilder();

  String buildSelectionAnswer(
    List<RecommendedProductRef> selected,
    AIChatLanguage language, {
    required bool wantsCart,
  }) {
    final names = selected
        .map((ref) => ref.name)
        .join(language.isArabic ? ' و' : ' and ');
    if (language.isArabic) {
      final subject = selected.length == 1 ? 'المنتج' : 'المنتجات';
      final cartText = wantsCart
          ? 'لو حابب تضيف $subject للسلة، افتح Details واضغط Add to cart من صفحة المنتج. الشات حاليًا بيوجهك للإضافة وما بيضيفش تلقائيًا.'
          : 'ولو حابب تضيفه للسلة، افتح Details واضغط Add to cart من صفحة المنتج.';
      return 'تمام، تقصد $names. ممكن تفتح Details وتشوف السعر والنوتات والمعلومات أكتر قبل الشراء. $cartText';
    }

    final subject = selected.length == 1 ? 'this product' : 'these products';
    final cartText = wantsCart
        ? 'To add $subject, open Details and tap Add to cart on the product page. The chat can guide you, but it does not add items automatically yet.'
        : 'To add it to the cart, open Details and tap Add to cart on the product page.';
    return 'Got it, you mean $names. You can open Details to check the price, notes, and more information before buying. $cartText';
  }

  String buildMemoryAnswer(
    RecommendedProductRef ref,
    AIChatLanguage language, {
    required bool includeNotes,
    required bool includeReason,
  }) {
    final notes = [
      ...ref.topNotes,
      ...ref.middleNotes,
      ...ref.baseNotes,
      ...ref.notes,
    ].where((note) => note.trim().isNotEmpty).toSet().take(5).join(', ');
    final cleanedReason = cleanUserFacingReason(ref.matchReason);
    final reason = cleanedReason.isNotEmpty
        ? cleanedReason
        : language.isArabic
        ? 'لأنه أقرب ترشيح متاح للتفضيلات التي ذكرتها.'
        : 'It was the closest available match for the preferences you shared.';
    if (language.isArabic) {
      final parts = <String>[
        '${ref.displayIndex}. ${ref.name} من ${ref.brand} بسعر ${ref.price.toStringAsFixed(0)} جنيه.',
      ];
      if (includeNotes || notes.isNotEmpty) {
        parts.add(
          notes.isEmpty
              ? 'لا توجد نوتات تفصيلية كافية لهذا المنتج في البيانات الحالية.'
              : 'أبرز النوتات: $notes.',
        );
      }
      if (includeReason || cleanedReason.isNotEmpty) {
        parts.add('سبب الترشيح: $reason');
      }
      return parts.join(' ');
    }
    final parts = <String>[
      '${ref.displayIndex}. ${ref.name} by ${ref.brand}, ${ref.price.toStringAsFixed(0)} EGP.',
    ];
    if (includeNotes || notes.isNotEmpty) {
      parts.add(
        notes.isEmpty
            ? 'Detailed notes are not available for this product yet.'
            : 'Main notes: $notes.',
      );
    }
    if (includeReason || cleanedReason.isNotEmpty) {
      parts.add('Why I picked it: $reason');
    }
    return parts.join(' ');
  }

  String cleanUserFacingReason(String reason) {
    var cleaned = reason.trim();
    if (cleaned.isEmpty) return '';
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*Suitability:\s*[^.]+\.?', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b[a-z]+(?:_[a-z0-9]+){1,}\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+([,.])'), r'$1').trim();
    return cleaned;
  }

  String buildCheapestAnswer(
    List<RecommendedProductRef> selected,
    AIChatLanguage language,
  ) {
    final cheapest = selected.reduce((a, b) => a.price <= b.price ? a : b);
    if (language.isArabic) {
      return 'الأرخص بين الاختيارات الظاهرة هو ${cheapest.name} من ${cheapest.brand} بسعر ${cheapest.price.toStringAsFixed(0)} جنيه. لو تحب أشرح مناسب لإيه، افتح Details أو اسألني عنه بالرقم.';
    }
    return 'The cheapest visible option is ${cheapest.name} by ${cheapest.brand} at ${cheapest.price.toStringAsFixed(0)} EGP. If you want, ask about it by number or open Details.';
  }

  String buildBestForContextAnswer(
    List<RecommendedProductRef> selected,
    String context,
    AIChatLanguage language,
  ) {
    final best = selectBestForContext(selected, context);
    final reasons = _contextFitReasons(best, context, language);
    final reasonText = reasons.isEmpty
        ? language.isArabic
              ? 'بياناته أقرب لاستخدام $context من الاختيارات الظاهرة'
              : 'its catalog profile is the closest fit among the visible options'
        : reasons.take(2).join(language.isArabic ? ' و' : ' and ');
    final price = best.price.toStringAsFixed(0);
    if (language.isArabic) {
      return '${best.name} هو الأنسب لـ $context من الاختيارات الظاهرة لأنه $reasonText. سعره $price جنيه وشدته ${best.intensity}.';
    }
    return '${best.name} is the better fit for $context among the visible options because $reasonText. It costs $price EGP and has ${best.intensity} intensity.';
  }

  RecommendedProductRef selectBestForContext(
    List<RecommendedProductRef> selected,
    String context,
  ) {
    final ranked =
        selected
            .map((ref) => _ContextFit(ref, _contextFitScore(ref, context)))
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            return a.ref.price.compareTo(b.ref.price);
          });
    return ranked.first.ref;
  }

  String buildComparisonAnswer(
    List<RecommendedProductRef> selected,
    AIChatLanguage language,
  ) {
    final first = selected[0];
    final second = selected[1];
    final firstWeight = _intensityWeight(first.intensity);
    final secondWeight = _intensityWeight(second.intensity);
    final verdict = firstWeight == secondWeight
        ? language.isArabic
              ? 'الاتنين قريبين في الثقل، فاختيارك يكون حسب النوتات والسعر.'
              : 'They are close in weight, so choose by notes and price.'
        : firstWeight > secondWeight
        ? language.isArabic
              ? '${first.name} أثقل من ${second.name}.'
              : '${first.name} is heavier than ${second.name}.'
        : language.isArabic
        ? '${first.name} أخف من ${second.name}.'
        : '${first.name} is lighter than ${second.name}.';
    if (language.isArabic) {
      final firstIntensity = _displayIntensity(first.intensity, language);
      final secondIntensity = _displayIntensity(second.intensity, language);
      return '$verdict ${first.name}: $firstIntensity, ${first.price.toStringAsFixed(0)} جنيه. ${second.name}: $secondIntensity, ${second.price.toStringAsFixed(0)} جنيه.';
    }
    return '$verdict ${first.name}: ${first.intensity}, ${first.price.toStringAsFixed(0)} EGP. ${second.name}: ${second.intensity}, ${second.price.toStringAsFixed(0)} EGP.';
  }

  String buildAmbiguousSelectionAnswer(
    List<RecommendedProductRef> matches,
    AIChatLanguage language,
  ) {
    final options = matches
        .take(3)
        .map((ref) {
          return '${ref.displayIndex}. ${ref.name}';
        })
        .join('\n');
    if (language.isArabic) {
      return 'تقصد أنهي منتج منهم؟\n$options';
    }
    return 'Which product do you mean?\n$options';
  }

  int _intensityWeight(String intensity) {
    switch (LocalIntentParser.normalizeInput(intensity)) {
      case 'strong':
      case 'high':
      case '\u0642\u0648\u064a':
        return 3;
      case 'light':
      case 'soft':
      case '\u062e\u0641\u064a\u0641':
        return 1;
      default:
        return 2;
    }
  }

  String _displayIntensity(String intensity, AIChatLanguage language) {
    if (!language.isArabic) return intensity;
    return switch (LocalIntentParser.normalizeInput(intensity)) {
      'light' => 'هادي',
      'medium' || 'moderate' => 'متوسط',
      'strong' || 'high' => 'قوي',
      _ => intensity,
    };
  }

  int _contextFitScore(RecommendedProductRef ref, String context) {
    final text = _contextText(ref);
    var score = 0;
    if (context == 'university') {
      if (_containsAny(text, const ['university', 'campus', 'student'])) {
        score += 5;
      }
      if (_containsAny(text, const ['daily', 'day', 'office', 'casual'])) {
        score += 3;
      }
      if (_containsAny(text, const [
        'fresh',
        'clean',
        'citrus',
        'aquatic',
        'musk',
      ])) {
        score += 3;
      }
      score += switch (_intensityWeight(ref.intensity)) {
        1 => 3,
        2 => 1,
        _ => -2,
      };
      if (_containsAny(text, const ['night', 'oud', 'heavy', 'loud'])) {
        score -= 2;
      }
    } else if (context == 'office') {
      if (_containsAny(text, const ['office', 'work', 'professional'])) {
        score += 5;
      }
      if (_containsAny(text, const [
        'day',
        'daily',
        'clean',
        'fresh',
        'musk',
      ])) {
        score += 3;
      }
      if (_intensityWeight(ref.intensity) == 3) score -= 2;
    } else if (context == 'gym') {
      if (_containsAny(text, const ['fresh', 'clean', 'citrus', 'aquatic'])) {
        score += 4;
      }
      if (_intensityWeight(ref.intensity) == 1) score += 3;
      if (_intensityWeight(ref.intensity) == 3) score -= 3;
    } else if (context == 'date') {
      if (_containsAny(text, const [
        'warm',
        'romantic',
        'sweet',
        'date',
        'evening',
      ])) {
        score += 4;
      }
      if (_containsAny(text, const ['clean', 'fresh'])) score += 1;
    } else {
      if (_containsAny(text, const ['daily', 'day', 'fresh', 'clean'])) {
        score += 3;
      }
    }
    if (ref.stock <= 0) score -= 10;
    return score;
  }

  List<String> _contextFitReasons(
    RecommendedProductRef ref,
    String context,
    AIChatLanguage language,
  ) {
    final text = _contextText(ref);
    final reasons = <String>[];
    void add(String en, String ar) => reasons.add(language.isArabic ? ar : en);

    if (context == 'university') {
      if (_intensityWeight(ref.intensity) == 1) {
        add('it is light enough for campus', 'شدته هادية ومناسبة للجامعة');
      }
      if (_containsAny(text, const [
        'fresh',
        'clean',
        'citrus',
        'aquatic',
        'musk',
      ])) {
        add('it has a fresh or clean profile', 'طابعه فريش أو نضيف');
      }
      if (_containsAny(text, const ['daily', 'day', 'office', 'casual'])) {
        add(
          'it leans practical for daytime use',
          'مناسب للاستخدام اليومي والنهاري',
        );
      }
    } else if (context == 'office') {
      if (_containsAny(text, const ['clean', 'fresh', 'musk'])) {
        add(
          'it has a clean office-friendly profile',
          'طابعه نضيف ومناسب للشغل',
        );
      }
      if (_intensityWeight(ref.intensity) <= 2) {
        add('it is not too loud', 'مش فواح زيادة');
      }
    } else if (context == 'gym') {
      if (_containsAny(text, const ['fresh', 'clean', 'citrus', 'aquatic'])) {
        add('it feels fresh for active use', 'فريش ومناسب للحركة');
      }
      if (_intensityWeight(ref.intensity) == 1) {
        add('it is light', 'شدته خفيفة');
      }
    } else if (context == 'date') {
      if (_containsAny(text, const ['warm', 'romantic', 'sweet', 'evening'])) {
        add('it has a warmer dressed-up profile', 'طابعه أدفى وأنسب للخروج');
      }
    }
    if (reasons.isEmpty && ref.notes.isNotEmpty) {
      add(
        'its notes include ${ref.notes.take(2).join(', ')}',
        'نوتاته فيها ${ref.notes.take(2).join(', ')}',
      );
    }
    return reasons;
  }

  String _contextText(RecommendedProductRef ref) {
    return [
      ref.season,
      ref.occasion,
      ref.intensity,
      ...ref.notes,
      ...ref.topNotes,
      ...ref.middleNotes,
      ...ref.baseNotes,
      ...ref.tags,
    ].map(LocalIntentParser.normalizeInput).join(' ');
  }

  bool _containsAny(String text, Iterable<String> terms) {
    return terms.any(text.contains);
  }
}

class _ContextFit {
  const _ContextFit(this.ref, this.score);

  final RecommendedProductRef ref;
  final int score;
}
