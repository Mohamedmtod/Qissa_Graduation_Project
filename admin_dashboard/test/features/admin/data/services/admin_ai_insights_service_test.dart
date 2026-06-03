import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_ai_insights_service.dart';

void main() {
  group('FirestoreAdminAiInsightsService feedback analytics', () {
    test('summarizes feedback safely without exposing long sensitive text', () {
      final analytics =
          FirestoreAdminAiInsightsService.buildFeedbackAnalyticsFromMaps(
            feedbackDocs: const [
              {
                'isHelpful': true,
                'feedbackReason': 'good_match',
                'comment': 'Nice recommendation',
              },
              {
                'isHelpful': false,
                'rejectionReason': 'too_sweet',
                'comment':
                    'Bad fit, contact me at customer@example.com or +201001112222 because this message is intentionally long and should be shortened before it appears in the dashboard.',
              },
              {'feedbackValue': 'neutral', 'reason': 'not_enough_context'},
            ],
            analysisDocs: const [
              {'status': 'completed'},
              {'status': 'queued'},
              {'status': 'failed'},
              {'status': 'completed'},
            ],
          );

      expect(analytics.totalFeedback, 3);
      expect(analytics.positiveFeedback, 1);
      expect(analytics.negativeFeedback, 1);
      expect(analytics.neutralFeedback, 1);
      expect(
        analytics.topReasons.map((item) => item.reason),
        contains('too_sweet'),
      );
      expect(analytics.analysisStatusCounts['completed'], 2);
      expect(analytics.analysisStatusCounts['queued'], 1);
      expect(analytics.recentNegativePreviews, hasLength(1));
      expect(analytics.recentNegativePreviews.single, contains('[email]'));
      expect(analytics.recentNegativePreviews.single, contains('[number]'));
      expect(
        analytics.recentNegativePreviews.single.length,
        lessThanOrEqualTo(140),
      );
    });
  });
}
