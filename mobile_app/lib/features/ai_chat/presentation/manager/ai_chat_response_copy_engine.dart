import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';

class AIChatResponseCopyEngine {
  const AIChatResponseCopyEngine();

  String socialAnswer(AIChatLanguage language) {
    return language.isArabic
        ? 'أهلاً! قلّي تفضيلاتك مثل النوع أو النوتات أو الميزانية، وسأرشح لك الأنسب. أنا جاهز أساعدك تختار عطر مناسب.'
        : 'Hello! I am doing well and ready to help you choose a perfume. Tell me your preferences, scent style, occasion, budget, or a perfume you like.';
  }

  String fallbackAsk(AIChatLanguage language) {
    return language.isArabic
        ? 'تمام، عشان أرشحلك صح: تحب العطر رجالي ولا حريمي ولا للجنسين؟'
        : 'To recommend properly, should I keep it men, women, or unisex?';
  }

  String askQuestion(
    AIChatResponseFacts facts,
    AIChatLanguage language, {
    String? llmQuestion,
  }) {
    final question = _clean(llmQuestion ?? facts.question ?? '');
    if (question.isNotEmpty && !_isGenericAsk(question)) return question;
    final nextConstraint = facts.constraints
        .map(_clean)
        .where((item) => item.isNotEmpty)
        .firstOrNull;
    if (nextConstraint != null) {
      return language.isArabic
          ? 'تمام، عشان أرشح بدقة: $nextConstraint؟'
          : 'To narrow it down, $nextConstraint?';
    }
    return fallbackAsk(language);
  }

  String noMatch(
    AIChatResponseFacts facts,
    AIChatLanguage language, {
    String? llmText,
  }) {
    final text = _clean(llmText ?? facts.answer ?? '');
    if (text.isNotEmpty && !_isGenericNoMatch(text)) return text;
    if (facts.disclosures.isNotEmpty) return facts.disclosures.first;
    return language.isArabic
        ? 'مش لاقي اختيار آمن مطابق للقيود الحالية من الكتالوج. أقدر أوسع السعر أو أغيّر الطابع لناحية أهدى أو أفخم.'
        : 'I could not find an exact catalog match for that request. I can broaden the search a bit or try a different scent direction.';
  }

  String recommendationIntro(
    AIChatResponseFacts facts,
    AIChatLanguage language, {
    String? llmIntro,
  }) {
    if (_isUsableLlmIntro(llmIntro, facts)) return llmIntro!.trim();
    if (facts.disclosures.isNotEmpty) return facts.disclosures.first;

    final first = facts.products.isEmpty ? null : facts.products.first;
    final count = facts.products.length;
    final intent = facts.renderIntent ?? '';

    if (intent == 'rejectionRecovery') {
      return language.isArabic
          ? 'استبعدت الاختيارات السابقة وجبتلك بدائل مختلفة من الكتالوج.'
          : 'I excluded the previous options and found different catalog alternatives.';
    }
    if (intent == 'cheaperFollowup') {
      return language.isArabic
          ? 'جبتلك اختيارات أرخص، مع الحفاظ قدر الإمكان على نفس الطابع.'
          : 'I found cheaper options while keeping the same scent direction as much as possible.';
    }
    if (intent == 'similarCheaper') {
      return language.isArabic
          ? 'دي بدائل شبيهة من الكتالوج وبسعر أقل.'
          : 'These are similar catalog options at a lower price.';
    }
    if (intent == 'alternativeRecommendation') {
      return language.isArabic
          ? 'جبتلك اختيارات مختلفة من الكتالوج بدل آخر ترشيحات ظهرتلك.'
          : 'I found different catalog options instead of the last recommendations shown.';
    }
    if (intent == 'externalProfileSimilar') {
      return language.isArabic
          ? 'العطر المرجعي مش كارت بيع عندنا، لكن دي أقرب بدائل متاحة من الكتالوج لطابعه.'
          : 'The reference perfume is not a sale card here, but these are the closest available catalog alternatives to its profile.';
    }
    if (intent == 'externalProfileCheaper') {
      return language.isArabic
          ? 'دي بدائل من الكتالوج قريبة من الطابع وبسعر أقل حسب المرجع المتاح.'
          : 'These are catalog alternatives close to that scent profile and priced below the verified reference.';
    }
    if (intent == 'budgetFloor') {
      final product = first;
      if (product != null) {
        return language.isArabic
            ? 'ده أقل اختيار متاح حاليًا، لكنه أعلى من ميزانيتك الأصلية وسعره ${product.price.toStringAsFixed(0)} جنيه.'
            : 'This is the lowest available option right now, but it is above your original budget at ${product.price.toStringAsFixed(0)} EGP.';
      }
    }

    if (first != null) {
      final family = _clean(first.family);
      final reason = _cleanReason(first.reason);
      if (language.isArabic) {
        final reasonText = reason.isEmpty
            ? 'لأنه أقرب اختيار آمن من الكتالوج لطلبك'
            : 'لأن $reason';
        return count <= 1
            ? 'رشحتلك ${first.name}: $reasonText.'
            : 'رشحتلك $count اختيارات من الكتالوج، وأقوى بداية هي ${first.name}: $reasonText.';
      }
      if (_isStandaloneReason(reason)) {
        final standaloneReason = _ensureSentence(reason);
        return count <= 1
            ? 'I picked ${first.name}. $standaloneReason'
            : 'I found $count catalog options. The strongest starting point is ${first.name}. $standaloneReason';
      }
      final reasonText = reason.isEmpty
          ? 'it is the closest safe catalog match for your request'
          : _sentenceFragment(reason);
      final familyText = family.isEmpty ? '' : ', with a $family profile';
      return count <= 1
          ? 'I picked ${first.name} because $reasonText$familyText.'
          : 'I found $count catalog options. The strongest starting point is ${first.name} because $reasonText$familyText.';
    }

    return language.isArabic
        ? 'دي أقرب اختيارات متاحة من الكتالوج حسب طلبك.'
        : 'These are the closest available catalog options for your request.';
  }

  bool _isUsableLlmIntro(String? value, AIChatResponseFacts facts) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    final normalized = text.toLowerCase();
    if (normalized.contains('based on your preferences')) return false;
    if (normalized.contains('closest available catalog options')) return false;
    if (normalized.contains('tell me your preferences')) return false;
    if (_containsInternalCopy(text)) return false;
    if (facts.cardPolicy == AIChatCardPolicy.recommendationGrid &&
        normalized.contains('i cannot')) {
      return false;
    }
    return text.length <= 260;
  }

  String _clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool _isGenericAsk(String value) {
    final normalized = _clean(value).toLowerCase();
    return normalized.contains('tell me your preferences like gender') ||
        normalized.contains('gender, notes, or budget') ||
        normalized.contains('do you have any extra preferences') ||
        normalized.contains('النوع أو النوتات أو الميزانية');
  }

  bool _isGenericNoMatch(String value) {
    final normalized = _clean(value).toLowerCase();
    return normalized.contains('could not find an in-stock catalog match') ||
        normalized.contains('no safe recommendation') ||
        normalized.contains('no matching products');
  }

  String _cleanReason(String value) {
    var cleaned = _clean(value);
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*و?داخل الميزانية\.?', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\s*and within budget\.?', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s*within budget\.?', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'\s*,?\s*مع ملاحظة:\s*intensity differs from request\.?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*,?\s*note:\s*intensity differs from request\.?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\s*intensity differs from request\.?', caseSensitive: false),
          '',
        );
    return _clean(cleaned).replaceAll(RegExp(r'\.{2,}$'), '.');
  }

  String _sentenceFragment(String value) {
    final cleaned = _clean(value).replaceAll(RegExp(r'[.،]+$'), '');
    if (cleaned.isEmpty) return cleaned;
    final first = cleaned.substring(0, 1).toLowerCase();
    return '$first${cleaned.substring(1)}';
  }

  bool _isStandaloneReason(String value) {
    final normalized = _clean(value).toLowerCase();
    return normalized.startsWith('strong pick because') ||
        normalized.startsWith('safe catalog pick because') ||
        normalized.startsWith('strong catalog pick because') ||
        normalized.startsWith('this is the best available match') ||
        normalized.startsWith('this is close to your request') ||
        normalized.startsWith('i could not find') ||
        normalized.startsWith('only note:');
  }

  bool _containsInternalCopy(String value) {
    final normalized = _clean(value).toLowerCase();
    return normalized.contains('intensity differs from request') ||
        normalized.contains('catalog note gap') ||
        normalized.contains('external lookup failed') ||
        normalized.contains('fallback from candidates') ||
        normalized.contains('staff_generated_seed_data') ||
        normalized.contains('guard_blocked') ||
        normalized.contains('no_match_reason');
  }

  String _ensureSentence(String value) {
    final cleaned = _clean(value);
    if (cleaned.isEmpty) return cleaned;
    if (RegExp(r'[.!?]$').hasMatch(cleaned)) return cleaned;
    return '$cleaned.';
  }
}
