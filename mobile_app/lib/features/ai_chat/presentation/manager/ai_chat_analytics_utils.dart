import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';

String availabilityQueryForAnalytics(String? query) {
  final normalized = (query ?? '').trim();
  return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
}

String availabilityStatusToAnalytics(AvailabilityStatus status) {
  switch (status) {
    case AvailabilityStatus.found:
      return 'found';
    case AvailabilityStatus.outOfStock:
      return 'out_of_stock';
    case AvailabilityStatus.notFoundKnownProfile:
      return 'not_found_known_profile';
    case AvailabilityStatus.notFoundUnknown:
      return 'not_found_unknown';
    case AvailabilityStatus.ambiguous:
      return 'ambiguous';
  }
}

String confidenceBucket(double score) {
  if (score >= 0.75) return 'high';
  if (score >= 0.58) return 'medium';
  if (score > 0) return 'low';
  return 'none';
}

Map<String, dynamic> buildAvailabilityAnalyticsMetadata({
  required String query,
  required AvailabilityStatus status,
  String? matchedProductId,
  String? referenceProfileKey,
  List<String> substituteProductIds = const [],
  double? confidence,
}) {
  return {
    'query': availabilityQueryForAnalytics(query),
    'status': availabilityStatusToAnalytics(status),
    'matchedProductId': matchedProductId,
    'referenceProfileKey': referenceProfileKey,
    'substituteProductIds': substituteProductIds,
    'confidenceBucket': confidence == null
        ? 'none'
        : confidenceBucket(confidence),
  };
}
