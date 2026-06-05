import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';

enum AIChatInterceptKind {
  fantasyNoteLike,
  contradictionLike,
  gibberishLike,
  luxuryBudgetMismatch,
}

class AIChatInterceptResult {
  const AIChatInterceptResult({
    required this.kind,
    required this.issueCode,
    required this.reasonCode,
  });

  final AIChatInterceptKind kind;
  final String issueCode;
  final String reasonCode;
}

class AIChatInputInterceptor {
  static final RegExp _punctuation = RegExp(r'[^\w\s\u0600-\u06FF]');
  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _latinScript = RegExp(r'[A-Za-z]');
  static final RegExp _digitRegex = RegExp(r'\d');

  static const Set<String> _fantasyTerms = {
    'shawarma',
    'garlic',
    'salted watermelon',
    'watermelon',
    'showerma',
    'شاورما',
    'macbook',
    'laptop',
    'new laptop',
    'توم',
    'ثوم',
    'بطيخ مالح',
    'شاورمه',
  };

  static const Set<String> _compromiseTerms = {
    'balanced',
    'compromise',
    'middle ground',
    'versatile',
  };

  static const Set<String> _luxuryTerms = {
    'luxury',
    'premium',
    'royal',
    'king',
    'queen',
    'fancy',
    'opulent',
    'فخم',
    'افخم',
    'أفخم',
    'ملكي',
    'ملوك',
    'أمراء',
    'امراء',
    'امير',
  };

  static const Set<String> _knownPerfumeWords = {
    'perfume',
    'fragrance',
    'scent',
    'men',
    'women',
    'unisex',
    'budget',
    'office',
    'gym',
    'daily',
    'date',
    'night',
    'summer',
    'winter',
    'spring',
    'autumn',
    'vanilla',
    'amber',
    'musk',
    'oud',
    'rose',
    'citrus',
    'woody',
    'floral',
    'spicy',
    'aquatic',
    'sweet',
    'fresh',
    'clean',
    'عطر',
    'برفان',
    'رجالي',
    'نسائي',
    'للجنسين',
    'ميزانية',
    'جنيه',
    'جامعة',
    'شغل',
    'مكتب',
    'جيم',
    'صيفي',
    'شتوي',
    'فانيليا',
    'عنبر',
    'مسك',
    'عود',
    'ورد',
    'حمضيات',
    'خشب',
    'زهور',
    'حلو',
    'منعش',
    'نظيف',
    'مواعدة',
    'هدية',
  };

  static AIChatInterceptResult? detect(
    String message,
    SessionPreferences preferences,
  ) {
    final normalized = _normalizeInput(message);
    if (normalized.isEmpty) return null;

    if (_isFantasyLike(normalized)) {
      return const AIChatInterceptResult(
        kind: AIChatInterceptKind.fantasyNoteLike,
        issueCode: 'fantasy_note_like',
        reasonCode: 'fantasy_note_like',
      );
    }

    if (_isContradictionLike(normalized)) {
      return const AIChatInterceptResult(
        kind: AIChatInterceptKind.contradictionLike,
        issueCode: 'contradiction_like',
        reasonCode: 'contradiction_like',
      );
    }

    if (_isLuxuryBudgetMismatch(normalized, preferences)) {
      return const AIChatInterceptResult(
        kind: AIChatInterceptKind.luxuryBudgetMismatch,
        issueCode: 'luxury_budget_mismatch',
        reasonCode: 'luxury_budget_mismatch',
      );
    }

    if (_isGibberishLike(normalized)) {
      return const AIChatInterceptResult(
        kind: AIChatInterceptKind.gibberishLike,
        issueCode: 'gibberish_like',
        reasonCode: 'gibberish_like',
      );
    }

    return null;
  }

  static String _normalizeInput(String input) {
    final normalized = AIChatTextNormalizer.normalizeForParsing(input);
    if (normalized.length <= 240) return normalized;
    return normalized.substring(normalized.length - 240);
  }

  static bool _containsAny(String message, Set<String> terms) {
    return terms.any((term) => message.contains(_normalizeInput(term)));
  }

  static bool _isFantasyLike(String message) {
    return _containsAny(message, _fantasyTerms);
  }

  static bool _isLuxuryBudgetMismatch(
    String message,
    SessionPreferences preferences,
  ) {
    final budget = preferences.maxBudget;
    if (budget == null || budget > 300) return false;
    return _containsAny(message, _luxuryTerms);
  }

  static bool _isContradictionLike(String message) {
    if (_containsAny(message, _compromiseTerms)) {
      return false;
    }
    if (_hasSameNoteIncludeExclude(message)) {
      return true;
    }
    if (_isNaturalExcludeThenPreferRequest(message)) {
      return false;
    }
    if (_isMultiScentPairRequest(message)) {
      return false;
    }

    final wantsVeryLight =
        message.contains('light') ||
        message.contains('lighter') ||
        message.contains('invisible') ||
        message.contains('barely noticeable') ||
        message.contains('close to skin') ||
        message.contains('skin scent') ||
        message.contains('خفيف') ||
        message.contains('اهدي') ||
        message.contains('هادي');
    final wantsVeryStrong =
        message.contains('strong') ||
        message.contains('fills the room') ||
        message.contains('fills the whole room') ||
        message.contains('room filling') ||
        message.contains('fills room') ||
        message.contains('lasts forever') ||
        message.contains('beast mode') ||
        message.contains('project') ||
        message.contains('قوي') ||
        message.contains('فواح') ||
        message.contains('بيملي المكان') ||
        message.contains('يملي المكان');
    final wantsUnnoticed =
        message.contains('not noticeable') ||
        message.contains('barely smell') ||
        message.contains('barely noticeable') ||
        message.contains('invisible') ||
        message.contains('close to skin') ||
        message.contains('skin scent') ||
        message.contains('مابيتشمش') ||
        message.contains('ما بيتشمش');

    return (wantsVeryLight && wantsVeryStrong) ||
        (wantsUnnoticed && wantsVeryStrong);
  }

  static bool _hasSameNoteIncludeExclude(String message) {
    const notes = {
      'oud': ['oud', '\u0639\u0648\u062f'],
      'vanilla': ['vanilla', '\u0641\u0627\u0646\u064a\u0644\u064a\u0627'],
    };
    final hasExcludeCue =
        message.contains('without ') ||
        message.contains('avoid ') ||
        message.contains('no ') ||
        message.contains('\u0628\u062f\u0648\u0646 ') ||
        message.contains('\u0645\u0634 ');
    final hasIncludeCue =
        message.contains('with ') ||
        message.contains('and ') ||
        message.contains('\u0645\u0639 ') ||
        message.contains('\u0648\u0645\u0639 ') ||
        message.contains('\u0648\u0641\u064a\u0647 ');
    if (!hasExcludeCue || !hasIncludeCue) return false;

    for (final aliases in notes.values) {
      final hasNote = aliases.any(message.contains);
      if (!hasNote) continue;
      final excludes = aliases.any(
        (note) =>
            message.contains('without $note') ||
            message.contains('avoid $note') ||
            message.contains('no $note') ||
            message.contains('\u0628\u062f\u0648\u0646 $note') ||
            message.contains('\u0645\u0634 $note'),
      );
      final includes = aliases.any(
        (note) =>
            message.contains('with $note') ||
            message.contains('and $note') ||
            message.contains('\u0645\u0639 $note') ||
            message.contains('\u0648\u0645\u0639 $note') ||
            message.contains('\u0648\u0641\u064a\u0647 $note'),
      );
      if (excludes && includes) return true;
    }
    return false;
  }

  static bool _isNaturalExcludeThenPreferRequest(String message) {
    final excludesStrong =
        message.contains("don't like strong") ||
        message.contains('do not like strong') ||
        message.contains('not strong') ||
        message.contains('not too strong') ||
        message.contains('\u0645\u0634 \u0628\u062d\u0628') &&
            (message.contains('\u0642\u0648\u064a') ||
                message.contains('\u0642\u0648\u064a\u0629')) ||
        message.contains('\u0645\u0634 \u0642\u0648\u064a') ||
        message.contains('\u0645\u0634 \u0642\u0648\u064a\u0629');
    final prefersCalm =
        message.contains('soft') ||
        message.contains('calm') ||
        message.contains('quiet') ||
        message.contains('light') ||
        message.contains('\u0647\u0627\u062f\u064a') ||
        message.contains('\u0647\u0627\u062f\u064a\u0629') ||
        message.contains('\u062e\u0641\u064a\u0641');
    if (excludesStrong && prefersCalm) return true;

    final excludesSweet =
        message.contains('not sweet') ||
        message.contains('not sugary') ||
        message.contains('\u0645\u0634 \u0633\u0648\u064a\u062a') ||
        message.contains('\u0645\u0634 \u0645\u0633\u0643\u0631');
    final prefersFresh =
        message.contains('fresh') ||
        message.contains('\u0641\u0631\u064a\u0634') ||
        message.contains('\u0645\u0646\u0639\u0634');
    if (excludesSweet && prefersFresh) return true;

    final excludesOud =
        message.contains('without oud') ||
        message.contains('avoid oud') ||
        message.contains('\u0628\u062f\u0648\u0646 \u0639\u0648\u062f') ||
        message.contains('\u0645\u0634 \u0639\u0648\u062f');
    final prefersDifferentNote =
        message.contains('vanilla') ||
        message.contains('\u0641\u0627\u0646\u064a\u0644\u064a\u0627') ||
        message.contains('musk') ||
        message.contains('\u0645\u0633\u0643');
    return excludesOud && prefersDifferentNote;
  }

  static bool _isMultiScentPairRequest(String message) {
    final asksForMultiple =
        message.contains('two perfumes') ||
        message.contains('two scents') ||
        message.contains('2 perfumes') ||
        message.contains('\u0639\u0637\u0631\u064a\u0646') ||
        message.contains('\u0639\u0637\u0631\u064a\u0646') ||
        message.contains('\u0627\u062a\u0646\u064a\u0646') ||
        message.contains('\u0627\u062b\u0646\u064a\u0646');
    if (!asksForMultiple) return false;
    final hasSplitUse =
        message.contains('one ') ||
        message.contains('\u0648\u0627\u062d\u062f') ||
        message.contains('\u0648\u0627\u062d\u062f\u0629');
    final hasLightAndStrong =
        (message.contains('soft') ||
            message.contains('calm') ||
            message.contains('\u0647\u0627\u062f\u064a') ||
            message.contains('\u0647\u0627\u062f\u064a\u0629')) &&
        (message.contains('strong') ||
            message.contains('\u0642\u0648\u064a') ||
            message.contains('\u0642\u0648\u064a\u0629'));
    return hasSplitUse && hasLightAndStrong;
  }

  static bool _isGibberishLike(String message) {
    final raw = message.trim();
    if (_isSymbolNoise(raw)) return true;

    final cleaned = raw.replaceAll(_punctuation, ' ').trim();
    if (cleaned.isEmpty) return false;

    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return false;

    final hasKnownWord = tokens.any(
      (token) => _knownPerfumeWords.any(
        (known) =>
            token.contains(_normalizeInput(known)) ||
            _normalizeInput(known).contains(token),
      ),
    );
    if (hasKnownWord) return false;

    final hasArabic = _arabicScript.hasMatch(cleaned);
    final hasLatin = _latinScript.hasMatch(cleaned);
    if (!hasArabic && !hasLatin) return false;
    if (_digitRegex.hasMatch(cleaned)) return false;

    if (tokens.length == 1 && _looksRandomToken(tokens.first)) {
      return true;
    }

    if (tokens.length <= 2 && cleaned.length <= 16) {
      return false;
    }

    return false;
  }

  static bool _isSymbolNoise(String message) {
    if (message.length < 4) return false;
    final nonSpaceChars = message.replaceAll(RegExp(r'\s+'), '');
    if (nonSpaceChars.length < 4) return false;
    final letterOrDigitCount = RegExp(
      r'[A-Za-z0-9\u0600-\u06FF]',
    ).allMatches(nonSpaceChars).length;
    return letterOrDigitCount == 0;
  }

  static bool _looksRandomToken(String token) {
    final normalized = _normalizeInput(token);
    if (normalized.length < 6) return false;
    if (_arabicScript.hasMatch(normalized)) {
      return _hasRepeatedCharacters(normalized, minRunLength: 6);
    }
    if (!_latinScript.hasMatch(normalized)) return false;

    const keyboardRuns = [
      'qwerty',
      'asdf',
      'zxcv',
      'hjkl',
      'uiop',
      'dfgh',
      'jkl',
    ];
    if (keyboardRuns.any(normalized.contains)) {
      return true;
    }

    final latinLetters = RegExp(r'[a-z]').allMatches(normalized).length;
    if (latinLetters < 6) return false;
    final vowels = RegExp(r'[aeiou]').allMatches(normalized).length;
    final consonantRatio = (latinLetters - vowels) / latinLetters;
    return consonantRatio >= 0.75;
  }

  static bool _hasRepeatedCharacters(
    String value, {
    required int minRunLength,
  }) {
    var currentRun = 0;
    String? previous;
    for (final codePoint in value.runes) {
      final char = String.fromCharCode(codePoint);
      if (char == previous) {
        currentRun += 1;
      } else {
        previous = char;
        currentRun = 1;
      }
      if (currentRun >= minRunLength) return true;
    }
    return false;
  }
}
