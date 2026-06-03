import 'package:perfume_app/features/ai_chat/core/ai_normalization_dictionary.dart';

/// Core normalizer layer to unify user inputs and product data values
/// into standard canonical representations for AI and ranking processes.
class AINormalizer {
  
  /// Flattens the grouped human-readable list `{ "canonical": ["alias1", "alias2"] }`
  /// into an O(1) lookup map `{ "alias1": "canonical", "alias2": "canonical" }`.
  static Map<String, String> _flatten(Map<String, List<String>> source) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      for (final alias in entry.value) {
        result[alias.trim().toLowerCase()] = entry.key;
      }
    }
    return result;
  }

  // ── Pre-computed O(1) Lookup Maps ─────────────────────────────────────
  static final Map<String, String> flatGenderAliases = _flatten(AINormalizationDictionary.genderAliases);
  static final Map<String, String> flatIntensityAliases = _flatten(AINormalizationDictionary.intensityAliases);
  static final Map<String, String> flatSeasonAliases = _flatten(AINormalizationDictionary.seasonAliases);
  static final Map<String, String> flatOccasionAliases = _flatten(AINormalizationDictionary.occasionAliases);
  static final Map<String, String> flatTimeAliases =
      _flatten(AINormalizationDictionary.timeAliases)..['all day'] = 'all_day';
  static final Map<String, String> flatNoteAliases = _flatten(AINormalizationDictionary.noteAliases);
  static final Map<String, String> flatTagAliases = _flatten(AINormalizationDictionary.tagAliases);
  static final Map<String, String> flatLayerAliases = _flatten(AINormalizationDictionary.layerAliases);

  /// Normalizes a single scalar string (like gender, occasion, intensity).
  ///
  /// Steps:
  /// 1. Trims and lowers case.
  /// 2. Checks local aliases/synonyms natively.
  /// 3. Returns the canonical value if valid, or null if unknown.
  static String? normalizeScalarValue(
    String? input,
    List<String> canonicalList,
    Map<String, String> aliases,
  ) {
    if (input == null || input.trim().isEmpty) return null;

    final cleaned = input.trim().toLowerCase();

    // 1. Direct match in canonical list
    if (canonicalList.contains(cleaned)) {
      return cleaned;
    }

    // 2. Exact alias match
    if (aliases.containsKey(cleaned)) {
      return aliases[cleaned];
    }

    // 3. Partial alias match (fallback)
    // E.g. "عطر رجالي" -> Contains "رجالي" -> resolves to "men"
    for (final entry in aliases.entries) {
      if (cleaned.contains(entry.key)) {
        return entry.value;
      }
    }

    for (final val in canonicalList) {
      if (cleaned.contains(val)) {
        return val;
      }
    }

    // If we reach here, we don't know this value. We return null.
    return null;
  }

  /// Normalizes a list of values (like tags, topNotes, etc).
  ///
  /// Removes duplicates, strips out unknowns, processes aliases.
  static List<String> normalizeListValues(
    List<String>? inputs,
    List<String> canonicalList,
    Map<String, String> aliases,
  ) {
    if (inputs == null || inputs.isEmpty) return [];

    final Set<String> normalizedSet = {};

    for (final input in inputs) {
      final normalized = normalizeScalarValue(input, canonicalList, aliases);
      if (normalized != null) {
        normalizedSet.add(normalized);
      }
    }

    return normalizedSet.toList();
  }

  // ── Convenience Methods for ProductModel & Parser ─────────────────

  static String? normalizeGender(String? value) =>
      normalizeScalarValue(value, AINormalizationDictionary.canonicalGenders, flatGenderAliases);

  static String? normalizeIntensity(String? value) =>
      normalizeScalarValue(value, AINormalizationDictionary.canonicalIntensities, flatIntensityAliases);

  static String? normalizeSeason(String? value) =>
      normalizeScalarValue(value, AINormalizationDictionary.canonicalSeasons, flatSeasonAliases);

  static String? normalizeOccasion(String? value) =>
      normalizeScalarValue(value, AINormalizationDictionary.canonicalOccasions, flatOccasionAliases);

  static String? normalizeTime(String? value) =>
      normalizeScalarValue(value, AINormalizationDictionary.canonicalTimes, flatTimeAliases);

  static List<String> normalizeNotes(List<String>? values) =>
      normalizeListValues(values, AINormalizationDictionary.canonicalNotes, flatNoteAliases);

  static List<String> normalizeTags(List<String>? values) =>
      normalizeListValues(values, AINormalizationDictionary.canonicalTags, flatTagAliases);
}
