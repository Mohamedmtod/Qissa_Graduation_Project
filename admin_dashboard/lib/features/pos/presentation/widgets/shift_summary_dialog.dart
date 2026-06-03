import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';

class ShiftSummaryDialog extends StatelessWidget {
  final Map<String, dynamic> sessionSummary;

  const ShiftSummaryDialog({super.key, required this.sessionSummary});

  static Future<void> show(BuildContext context, Map<String, dynamic> sessionSummary) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShiftSummaryDialog(sessionSummary: sessionSummary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = sessionSummary['shiftCode'] ?? sessionSummary['sessionId'] ?? 'Unknown Shift';
    final opening = (sessionSummary['openingCash'] ?? 0.0) as num;
    final expected = (sessionSummary['expectedCash'] ?? 0.0) as num;
    final actual = (sessionSummary['countedCash'] ?? 0.0) as num;
    final discrepancy = (sessionSummary['discrepancy'] ?? 0.0) as num;
    final cardAmount = (sessionSummary['expectedCard'] ?? 0.0) as num;
    final salesCount = sessionSummary['totalSalesCount'] ?? sessionSummary['salesCount'] ?? 0;
    
    final notes = sessionSummary['closeNotes'] ?? sessionSummary['notes'] ?? '';
    final openedAt = sessionSummary['openedAt'] != null 
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(sessionSummary['openedAt'].toString()))
        : '';
    final closedAt = sessionSummary['closedAt'] != null 
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(sessionSummary['closedAt'].toString()))
        : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    Color discrepancyColor = Colors.green.shade700;
    IconData discrepancyIcon = Icons.check_circle_outline;
    String discrepancyText = 'Matched';

    if (discrepancy < 0) {
      discrepancyColor = Colors.red.shade700;
      discrepancyIcon = Icons.remove_circle_outline;
      discrepancyText = 'Shortage';
    } else if (discrepancy > 0) {
      discrepancyColor = Colors.orange.shade700;
      discrepancyIcon = Icons.add_circle_outline;
      discrepancyText = 'Overage';
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.summarize_outlined, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text(
            'Shift Summary',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shift Code:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Opened At:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(openedAt, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Closed At:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(closedAt, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cash Reconciliation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opening Cash:'),
                Text('${opening.toStringAsFixed(2)} EGP'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expected Cash in Drawer:'),
                Text('${expected.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Actual Counted Cash:'),
                Text('${actual.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(discrepancyIcon, color: discrepancyColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Discrepancy ($discrepancyText):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: discrepancyColor),
                    ),
                  ],
                ),
                Text(
                  '${discrepancy >= 0 ? "+" : ""}${discrepancy.toStringAsFixed(2)} EGP',
                  style: TextStyle(fontWeight: FontWeight.bold, color: discrepancyColor, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Shift Aggregates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expected Card Sales:'),
                Text('${cardAmount.toStringAsFixed(2)} EGP'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Transactions:'),
                Text('$salesCount sales'),
              ],
            ),
            if (notes.toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Closing Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notes,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
