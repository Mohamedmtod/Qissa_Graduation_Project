import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_facet_index.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_engine.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

enum CatalogQueryType {
  mostExpensive,
  cheapest,
  rankedByPrice,
  noteSearch,
  facetSearch,
}

class CatalogQuery {
  final CatalogQueryType type;
  final CatalogSearchSort sort;
  final String? facetTerm;
  final int limit;

  const CatalogQuery({
    required this.type,
    required this.sort,
    this.facetTerm,
    this.limit = 3,
  });
}

class CatalogQueryDetector {
  const CatalogQueryDetector();

  CatalogQuery? detect(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;

    final limit = _extractLimit(normalized);
    if (_looksLikeRankedByPrice(normalized)) {
      return CatalogQuery(
        type: CatalogQueryType.rankedByPrice,
        sort: CatalogSearchSort.cheapest,
        limit: limit,
      );
    }

    if (_looksLikeMostExpensive(normalized)) {
      return CatalogQuery(
        type: CatalogQueryType.mostExpensive,
        sort: CatalogSearchSort.mostExpensive,
        limit: limit,
      );
    }

    if (_looksLikeCheapest(normalized)) {
      return CatalogQuery(
        type: CatalogQueryType.cheapest,
        sort: CatalogSearchSort.cheapest,
        limit: limit,
      );
    }

    final noteOnlyFacetTerm = _noteOnlyAvailabilityFacetTerm(normalized);
    if (noteOnlyFacetTerm != null) {
      return CatalogQuery(
        type: CatalogQueryType.noteSearch,
        sort: CatalogSearchSort.bestMatch,
        facetTerm: noteOnlyFacetTerm,
        limit: limit,
      );
    }

    final facetTerm = _explicitFacetTerm(normalized);
    if (facetTerm != null) {
      final isNoteSearch = _looksLikeScentFacetQuery(normalized);
      return CatalogQuery(
        type: isNoteSearch
            ? CatalogQueryType.noteSearch
            : CatalogQueryType.facetSearch,
        sort: CatalogSearchSort.bestMatch,
        facetTerm: facetTerm,
        limit: limit,
      );
    }

    return null;
  }

  bool _looksLikeMostExpensive(String normalized) {
    final hasPriceCue =
        normalized.contains('most expensive') ||
        normalized.contains('highest price') ||
        normalized.contains('premium option') ||
        normalized.contains('\u0627\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u063a\u0644\u064a') ||
        normalized.contains('\u0627\u0644\u0627\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u0644\u0627\u063a\u0644\u064a') ||
        normalized.contains('\u0627\u0639\u0644\u0649 \u0633\u0639\u0631');
    return hasPriceCue && _hasCatalogProductCue(normalized);
  }

  bool _looksLikeCheapest(String normalized) {
    final hasPriceCue =
        normalized.contains('cheapest') ||
        normalized.contains('lowest price') ||
        normalized.contains('budget option') ||
        normalized.contains('least expensive') ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u0644\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u0642\u0644 \u0633\u0639\u0631') ||
        normalized.contains('\u0627\u0648\u0641\u0631');
    return hasPriceCue && _hasCatalogProductCue(normalized);
  }

  bool _looksLikeRankedByPrice(String normalized) {
    final hasSortCue =
        normalized.contains('sort by price') ||
        normalized.contains('from cheapest to most expensive') ||
        normalized.contains('cheapest to most expensive') ||
        normalized.contains('\u0631\u062a\u0628') ||
        normalized.contains('\u0631\u062a\u0628\u0647\u0645');
    final hasPriceCue =
        normalized.contains('price') ||
        normalized.contains('cheapest') ||
        normalized.contains('expensive') ||
        normalized.contains('\u0633\u0639\u0631') ||
        normalized.contains('\u0627\u0631\u062e\u0635') ||
        normalized.contains('\u0627\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u063a\u0644\u064a');
    return hasSortCue && hasPriceCue;
  }

  bool _looksLikeScentFacetQuery(String normalized) {
    return normalized.contains('scent') ||
        normalized.contains('smell') ||
        normalized.contains('note') ||
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0631\u064a\u062d\u0647') ||
        normalized.contains('\u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0646\u0648\u062a\u0647') ||
        normalized.contains('\u0646\u0648\u062a\u0629') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646') ||
        normalized.contains('\u0641\u064a\u0647 ');
  }

  bool _hasCatalogProductCue(String normalized) {
    return normalized.contains('perfume') ||
        normalized.contains('perfumes') ||
        normalized.contains('fragrance') ||
        normalized.contains('fragrances') ||
        normalized.contains('catalog') ||
        normalized.contains('you have') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646') ||
        normalized.contains('\u0639\u0646\u062f\u0643');
  }

  String? _explicitFacetTerm(String normalized) {
    final terms = <String>[
      'strawberry',
      '\u0641\u0631\u0627\u0648\u0644\u0647',
      '\u0641\u0631\u0648\u0644\u0647',
      '\u0633\u062a\u0631\u0648\u0628\u0631\u064a',
      'powdery',
      '\u0628\u0648\u062f\u0631\u064a',
      'leather',
      '\u062c\u0644\u062f\u064a',
      'tropical',
      '\u062a\u0631\u0648\u0628\u064a\u0643\u0627\u0644',
      'aquatic',
      '\u0645\u0627\u064a\u064a',
      '\u0645\u0627\u0626\u064a',
    ];
    for (final term in terms) {
      final normalizedTerm = CatalogFacetIndex.normalizeText(term);
      if (_containsTerm(normalized, normalizedTerm)) {
        return term;
      }
    }
    return null;
  }

  String? _noteOnlyAvailabilityFacetTerm(String normalized) {
    if (!LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return null;
    }
    final parsed = LocalIntentParser.parse(
      normalized,
      const SessionPreferences(),
    );
    final notes = <String>[
      ...parsed.preferredNotes,
      ...parsed.preferredTopNotes,
      ...parsed.preferredMiddleNotes,
      ...parsed.preferredBaseNotes,
    ];
    for (final note in notes) {
      final normalizedNote = CatalogFacetIndex.normalizeText(note);
      if (normalizedNote.isNotEmpty) return normalizedNote;
    }
    return null;
  }

  bool _containsTerm(String normalized, String term) {
    if (term.isEmpty) return false;
    final escaped = RegExp.escape(term);
    return RegExp(
      '(^|[^a-z0-9\u0621-\u064A])$escaped([^a-z0-9\u0621-\u064A]|\$)',
    ).hasMatch(normalized);
  }

  int _extractLimit(String normalized) {
    final match = RegExp(r'\b([1-9])\b').firstMatch(normalized);
    if (match == null) return 3;
    return int.tryParse(match.group(1) ?? '')?.clamp(1, 5) ?? 3;
  }
}
