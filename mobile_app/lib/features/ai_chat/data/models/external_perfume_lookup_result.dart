import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';

enum ExternalPerfumeLookupStatus { found, ambiguous, notFound }

class ExternalPerfumeLookupResult {
  final ExternalPerfumeLookupStatus status;
  final PerfumeKnowledgeProfile? profile;
  final List<ExternalPerfumeCandidate> candidates;
  final String? reason;

  const ExternalPerfumeLookupResult._({
    required this.status,
    this.profile,
    this.candidates = const [],
    this.reason,
  });

  const ExternalPerfumeLookupResult.found(PerfumeKnowledgeProfile profile)
    : this._(status: ExternalPerfumeLookupStatus.found, profile: profile);

  const ExternalPerfumeLookupResult.ambiguous(
    List<ExternalPerfumeCandidate> candidates,
  ) : this._(
        status: ExternalPerfumeLookupStatus.ambiguous,
        candidates: candidates,
      );

  const ExternalPerfumeLookupResult.notFound({String? reason})
    : this._(status: ExternalPerfumeLookupStatus.notFound, reason: reason);

  bool get isFound => status == ExternalPerfumeLookupStatus.found;

  bool get isAmbiguous => status == ExternalPerfumeLookupStatus.ambiguous;
}
