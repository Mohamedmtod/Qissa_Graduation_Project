import 'package:equatable/equatable.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

enum AvailabilityStatus {
  found,
  outOfStock,
  notFoundKnownProfile,
  notFoundUnknown,
  ambiguous,
}

class AvailabilityContext extends Equatable {
  final String lastQuery;
  final String? matchedProductId;
  final String? matchedProductName;
  final AvailabilityStatus availabilityStatus;
  final String? referenceProfileKey;
  final SessionPreferences hints;
  final List<String> candidateOptionIds;
  final List<ExternalPerfumeCandidate> externalCandidates;
  final String source;

  const AvailabilityContext({
    this.lastQuery = '',
    this.matchedProductId,
    this.matchedProductName,
    this.availabilityStatus = AvailabilityStatus.notFoundUnknown,
    this.referenceProfileKey,
    this.hints = const SessionPreferences(),
    this.candidateOptionIds = const [],
    this.externalCandidates = const [],
    this.source = '',
  });

  const AvailabilityContext.empty()
    : this(
        lastQuery: '',
        availabilityStatus: AvailabilityStatus.notFoundUnknown,
        source: '',
      );

  bool get hasContext => lastQuery.trim().isNotEmpty;

  AvailabilityContext copyWith({
    String? lastQuery,
    String? matchedProductId,
    String? matchedProductName,
    AvailabilityStatus? availabilityStatus,
    String? referenceProfileKey,
    SessionPreferences? hints,
    List<String>? candidateOptionIds,
    List<ExternalPerfumeCandidate>? externalCandidates,
    String? source,
    bool clearMatchedProductId = false,
    bool clearMatchedProductName = false,
    bool clearReferenceProfileKey = false,
  }) {
    return AvailabilityContext(
      lastQuery: lastQuery ?? this.lastQuery,
      matchedProductId: clearMatchedProductId
          ? null
          : (matchedProductId ?? this.matchedProductId),
      matchedProductName: clearMatchedProductName
          ? null
          : (matchedProductName ?? this.matchedProductName),
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      referenceProfileKey: clearReferenceProfileKey
          ? null
          : (referenceProfileKey ?? this.referenceProfileKey),
      hints: hints ?? this.hints,
      candidateOptionIds: candidateOptionIds ?? this.candidateOptionIds,
      externalCandidates: externalCandidates ?? this.externalCandidates,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
    lastQuery,
    matchedProductId,
    matchedProductName,
    availabilityStatus,
    referenceProfileKey,
    hints,
    candidateOptionIds,
    externalCandidates,
    source,
  ];
}
