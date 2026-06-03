import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/ai_chat/core/ai_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';

enum PerfumeKnowledgeStatus { needsReview, approved, rejected }

class PerfumeKnowledgeProfile {
  final String id;
  final String displayName;
  final String brand;
  final List<String> aliases;
  final List<String> searchKeys;
  final List<String> accords;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final String fragranceFamily;
  final String? genderHint;
  final String? seasonHint;
  final String? occasionHint;
  final String? timeHint;
  final String? intensityHint;
  final String? sourceName;
  final String? sourceUrl;
  final String extractionMethod;
  final double lookupConfidence;
  final PerfumeKnowledgeStatus status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? lastUsedAt;
  final int usageCount;

  const PerfumeKnowledgeProfile({
    required this.id,
    required this.displayName,
    required this.brand,
    this.aliases = const [],
    this.searchKeys = const [],
    this.accords = const [],
    this.topNotes = const [],
    this.middleNotes = const [],
    this.baseNotes = const [],
    this.fragranceFamily = '',
    this.genderHint,
    this.seasonHint,
    this.occasionHint,
    this.timeHint,
    this.intensityHint,
    this.sourceName,
    this.sourceUrl,
    this.extractionMethod = 'model',
    this.lookupConfidence = 0,
    this.status = PerfumeKnowledgeStatus.needsReview,
    this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  List<String> get preferredNotes => <String>{
    ...accords,
    ...topNotes,
    ...middleNotes,
    ...baseNotes,
  }.toList(growable: false);

  bool get isUsable => status != PerfumeKnowledgeStatus.rejected;

  factory PerfumeKnowledgeProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PerfumeKnowledgeProfile.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory PerfumeKnowledgeProfile.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final displayName = _asString(map['displayName']);
    final brand = _asString(map['brand']);
    final aliases = _asStringList(map['aliases']);
    final accords = AINormalizer.normalizeTags(_asStringList(map['accords']));
    final topNotes = AINormalizer.normalizeNotes(
      _asStringList(map['topNotes']),
    );
    final middleNotes = AINormalizer.normalizeNotes(
      _asStringList(map['middleNotes']),
    );
    final baseNotes = AINormalizer.normalizeNotes(
      _asStringList(map['baseNotes']),
    );

    return PerfumeKnowledgeProfile(
      id: id,
      displayName: displayName,
      brand: brand,
      aliases: aliases,
      searchKeys: _asStringList(map['searchKeys']),
      accords: accords,
      topNotes: topNotes,
      middleNotes: middleNotes,
      baseNotes: baseNotes,
      fragranceFamily: _asString(map['fragranceFamily']),
      genderHint: AINormalizer.normalizeGender(_asString(map['genderHint'])),
      seasonHint: AINormalizer.normalizeSeason(_asString(map['seasonHint'])),
      occasionHint: AINormalizer.normalizeOccasion(
        _asString(map['occasionHint']),
      ),
      timeHint: AINormalizer.normalizeTime(_asString(map['timeHint'])),
      intensityHint: AINormalizer.normalizeIntensity(
        _asString(map['intensityHint']),
      ),
      sourceName: _nullableString(map['sourceName']),
      sourceUrl: _nullableString(map['sourceUrl']),
      extractionMethod: _asString(map['extractionMethod']).isEmpty
          ? 'model'
          : _asString(map['extractionMethod']),
      lookupConfidence: _asDouble(map['lookupConfidence']),
      status: _statusFromString(_asString(map['status'])),
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
      updatedAt: map['updatedAt'] is Timestamp ? map['updatedAt'] : null,
      lastUsedAt: map['lastUsedAt'] is Timestamp ? map['lastUsedAt'] : null,
      usageCount: _asInt(map['usageCount']),
    );
  }

  Map<String, dynamic> toFirestoreCreateMap() {
    return {
      'displayName': displayName,
      'brand': brand,
      'aliases': aliases,
      'searchKeys': searchKeys.isNotEmpty
          ? searchKeys
          : buildPerfumeKnowledgeSearchKeys(
              displayName: displayName,
              brand: brand,
              aliases: aliases,
            ),
      'accords': accords,
      'topNotes': topNotes,
      'middleNotes': middleNotes,
      'baseNotes': baseNotes,
      'fragranceFamily': fragranceFamily,
      'genderHint': genderHint,
      'seasonHint': seasonHint,
      'occasionHint': occasionHint,
      'timeHint': timeHint,
      'intensityHint': intensityHint,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'extractionMethod': extractionMethod,
      'lookupConfidence': lookupConfidence,
      'status': _statusToString(status),
      'usageCount': usageCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUsedAt': FieldValue.serverTimestamp(),
    };
  }

  static String documentIdForQuery(String query) {
    final normalized = normalizeKnowledgeKey(query);
    final safe = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safe.isEmpty ? 'unknown_perfume' : safe;
  }
}

List<String> buildPerfumeKnowledgeSearchKeys({
  required String displayName,
  required String brand,
  Iterable<String> aliases = const [],
}) {
  final values = <String>{
    displayName,
    if (brand.trim().isNotEmpty) '$brand $displayName',
    ...aliases,
  };
  return values
      .map(normalizeKnowledgeKey)
      .where((item) => item.length >= 3)
      .toSet()
      .toList(growable: false);
}

String normalizeKnowledgeKey(String value) {
  return AIChatTextNormalizer.normalizeForParsing(
    value,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _asString(dynamic value) {
  return value?.toString().trim() ?? '';
}

String? _nullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

List<String> _asStringList(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

PerfumeKnowledgeStatus _statusFromString(String value) {
  switch (value) {
    case 'approved':
      return PerfumeKnowledgeStatus.approved;
    case 'rejected':
      return PerfumeKnowledgeStatus.rejected;
    case 'needsReview':
    case 'needs_review':
    default:
      return PerfumeKnowledgeStatus.needsReview;
  }
}

String _statusToString(PerfumeKnowledgeStatus status) {
  switch (status) {
    case PerfumeKnowledgeStatus.approved:
      return 'approved';
    case PerfumeKnowledgeStatus.rejected:
      return 'rejected';
    case PerfumeKnowledgeStatus.needsReview:
      return 'needsReview';
  }
}
