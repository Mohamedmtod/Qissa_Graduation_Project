import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';

class TermMatch {
  final int start;
  final int end;

  const TermMatch({required this.start, required this.end});
}

String normalizeInput(String input) {
  return AIChatTextNormalizer.normalizeForParsing(input);
}

bool containsAny(String message, Set<String> terms) {
  for (final term in terms) {
    if (findTermMatches(message, term).isNotEmpty) return true;
  }
  return false;
}

List<TermMatch> findTermMatches(String message, String term) {
  final t = normalizeInput(term);
  if (t.isEmpty) return const [];

  final results = <TermMatch>[];
  var idx = message.indexOf(t);
  while (idx != -1) {
    final start = idx;
    final end = idx + t.length;

    var beforeOk = true;
    if (start > 0) {
      if (isWordChar(message[start - 1])) {
        beforeOk = false;
        if (arabicChar(t)) {
          final prefixStr = message.substring(0, start);
          if (RegExp(
            r'(^|\s)(ال|و|ف|ب|ك|ل|وال|فال|بال|كال|لل)$',
          ).hasMatch(prefixStr)) {
            beforeOk = true;
          }
        }
      }
    }

    var afterOk = true;
    if (end < message.length) {
      if (isWordChar(message[end])) {
        afterOk = false;
        if (arabicChar(t)) {
          final suffixStr = message.substring(end);
          if (RegExp(
            r'^(ها|ه|ي|ك|كم|نا|ة|ين|ون|ات)(\s|$)',
          ).hasMatch(suffixStr)) {
            afterOk = true;
          }
        }
      }
    }

    if (beforeOk && afterOk) {
      results.add(TermMatch(start: start, end: end));
    }

    idx = message.indexOf(t, idx + 1);
  }

  if (results.isNotEmpty || t.contains(' ') || t.length < 4) {
    return results;
  }

  for (final token in tokenMatches(message)) {
    final candidate = message.substring(token.start, token.end);
    if (!canUseFuzzyTokenMatch(candidate, t)) continue;
    if (isWithinEditDistance(candidate, t, maxTyposAllowedForTerm(t))) {
      results.add(token);
    }
  }

  return results;
}

List<TermMatch> tokenMatches(String message) {
  final matches = <TermMatch>[];
  var tokenStart = -1;

  for (var i = 0; i < message.length; i++) {
    final isWord = isWordChar(message[i]);
    if (isWord) {
      tokenStart = tokenStart == -1 ? i : tokenStart;
      continue;
    }
    if (tokenStart != -1) {
      matches.add(TermMatch(start: tokenStart, end: i));
      tokenStart = -1;
    }
  }

  if (tokenStart != -1) {
    matches.add(TermMatch(start: tokenStart, end: message.length));
  }

  return matches;
}

bool canUseFuzzyTokenMatch(String candidate, String term) {
  if (candidate == term) return true;
  if (arabicChar(candidate) != arabicChar(term)) return false;
  if ((candidate.length - term.length).abs() > maxTyposAllowedForTerm(term)) {
    return false;
  }
  if (!arabicChar(term) && candidate[0] != term[0]) return false;
  return true;
}

int maxTyposAllowedForTerm(String term) {
  if (term.length >= 8) return 2;
  return 1;
}

bool isWithinEditDistance(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) return false;
  if (a == b) return true;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    var rowMin = current[0];

    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = min3(prev[j] + 1, current[j - 1] + 1, prev[j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        current[j] = current[j] < prev[j - 2] + 1
            ? current[j]
            : prev[j - 2] + 1;
      }
      if (current[j] < rowMin) rowMin = current[j];
    }

    if (rowMin > maxDistance) return false;
    for (var j = 0; j <= b.length; j++) {
      prev[j] = current[j];
    }
  }

  return prev[b.length] <= maxDistance;
}

int min3(int a, int b, int c) {
  var min = a;
  if (b < min) min = b;
  if (c < min) min = c;
  return min;
}

bool isWordChar(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  if ((code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code == 95)) {
    return true;
  }
  if ((code >= 0x0621 && code <= 0x063A) ||
      (code >= 0x0641 && code <= 0x064A)) {
    return true;
  }
  return false;
}

bool arabicChar(String value) {
  return value.codeUnits.any((unit) => unit >= 0x0600 && unit <= 0x06FF);
}
