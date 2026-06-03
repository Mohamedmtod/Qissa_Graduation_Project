import 'package:flutter/material.dart';

class StockConflictDialog extends StatelessWidget {
  final List<Map<String, dynamic>> conflicts;

  const StockConflictDialog({super.key, required this.conflicts});

  static Future<void> show(BuildContext context, List<Map<String, dynamic>> conflicts) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StockConflictDialog(conflicts: conflicts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text(
            'Stock Conflict',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The server detected insufficient stock for the following items. Please adjust the quantities in your cart before checking out.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conflicts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final conflict = conflicts[index];
                  final name = conflict['productName'] ?? 'Unknown Product';
                  final variantLabel = conflict['variantLabel'] ?? '';
                  final requested = conflict['requestedQuantity'] ?? 0;
                  final available = conflict['availableStock'] ?? 0;
                  final unitType = conflict['unitType'] ?? 'piece';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (variantLabel.toString().isNotEmpty)
                                Text(
                                  'Variant: $variantLabel',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Requested: $requested $unitType',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Available: $available $unitType',
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK, Got it'),
        ),
      ],
    );
  }
}
