// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import '../cubit/pos_cubit.dart';

class PosSalesHistoryDialog extends StatefulWidget {
  const PosSalesHistoryDialog({super.key});

  static void show(BuildContext context, PosCubit posCubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: posCubit,
        child: const PosSalesHistoryDialog(),
      ),
    );
  }

  @override
  State<PosSalesHistoryDialog> createState() => _PosSalesHistoryDialogState();
}

class _PosSalesHistoryDialogState extends State<PosSalesHistoryDialog> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedSale;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<PosCubit>().loadSalesHistory();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _printReceipt(Map<String, dynamic> sale) {
    if (!kIsWeb) return;

    final items = sale['items'] as List? ?? [];
    final itemsHtml = items.map((it) {
      final name = it['productName'] ?? it['productId'] ?? 'Unknown Item';
      final variant = it['variantLabel'] != null && it['variantLabel'].toString().isNotEmpty
          ? ' (${it['variantLabel']})'
          : '';
      final qty = it['quantity'] ?? 1;
      final price = (it['unitPrice'] ?? 0.0) as num;
      final total = (it['lineTotal'] ?? 0.0) as num;
      return '''
        <tr>
          <td style="padding: 6px 0;">$name$variant</td>
          <td style="text-align: center; padding: 6px 0;">$qty</td>
          <td style="text-align: right; padding: 6px 0;">${price.toStringAsFixed(2)}</td>
          <td style="text-align: right; padding: 6px 0;">${total.toStringAsFixed(2)}</td>
        </tr>
      ''';
    }).join('\n');

    final createdAtStr = sale['createdAt'] != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(sale['createdAt'].toString()))
        : '';

    // Create a new print window and inject styled invoice HTML
    final printWindow = html.window.open('', '_blank') as dynamic;
    if (printWindow == null) return;

    final invoiceHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>Receipt ${sale['saleCode']}</title>
        <style>
          body {
            font-family: 'Courier New', Courier, monospace;
            width: 80mm;
            margin: 0 auto;
            padding: 10px;
            color: #000;
            font-size: 12px;
          }
          .header {
            text-align: center;
            margin-bottom: 15px;
          }
          .header h2 {
            margin: 0 0 5px 0;
            font-size: 16px;
            text-transform: uppercase;
          }
          .info {
            margin-bottom: 10px;
            border-bottom: 1px dashed #000;
            padding-bottom: 5px;
          }
          .info p {
            margin: 3px 0;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 10px;
          }
          th {
            border-bottom: 1px dashed #000;
            padding: 4px 0;
            text-align: left;
          }
          .totals {
            border-top: 1px dashed #000;
            padding-top: 5px;
            margin-bottom: 15px;
          }
          .totals p {
            margin: 4px 0;
            display: flex;
            justify-content: space-between;
          }
          .footer {
            text-align: center;
            margin-top: 20px;
            font-size: 10px;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h2>Qissa Perfumes</h2>
          <p>Point Of Sale</p>
        </div>
        <div class="info">
          <p><strong>Receipt:</strong> ${sale['saleCode']}</p>
          <p><strong>Date:</strong> $createdAtStr</p>
          <p><strong>Cashier:</strong> ${sale['cashierUid']?.toString().substring(0, min(8, sale['cashierUid']?.toString().length ?? 0))}</p>
          <p><strong>Shift Code:</strong> ${sale['sessionId']}</p>
        </div>
        <table>
          <thead>
            <tr>
              <th style="width: 45%;">Item</th>
              <th style="width: 15%; text-align: center;">Qty</th>
              <th style="width: 20%; text-align: right;">Price</th>
              <th style="width: 20%; text-align: right;">Total</th>
            </tr>
          </thead>
          <tbody>
            $itemsHtml
          </tbody>
        </table>
        <div class="totals">
          <p><span>Subtotal:</span> <strong>${((sale['totalAmount'] ?? 0.0) as num).toStringAsFixed(2)} EGP</strong></p>
          <p><span>Total:</span> <strong>${((sale['totalAmount'] ?? 0.0) as num).toStringAsFixed(2)} EGP</strong></p>
          <p><span>Payment:</span> <strong>${sale['paymentMethod']?.toString().toUpperCase()}</strong></p>
        </div>
        <div class="footer">
          <p>Thank you for shopping with us!</p>
          <p>Qissa Graduation Project 2026</p>
        </div>
        <script>
          window.onload = function() {
            window.print();
            setTimeout(function() { window.close(); }, 500);
          }
        </script>
      </body>
      </html>
    ''';

    printWindow.document.open();
    printWindow.document.write(invoiceHtml);
    printWindow.document.close();
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final filteredSales = state.salesHistory.where((sale) {
          final code = sale['saleCode']?.toString().toLowerCase() ?? '';
          return code.contains(_searchQuery);
        }).toList();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 900,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sales History',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: List of Sales
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by receipt code (e.g. POS-2026)...',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: state.isLoadingHistory
                                  ? const Center(child: CircularProgressIndicator())
                                  : filteredSales.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No sales found',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: filteredSales.length,
                                          separatorBuilder: (context, index) => const Divider(),
                                          itemBuilder: (context, index) {
                                            final sale = filteredSales[index];
                                            final isSelected = _selectedSale != null &&
                                                _selectedSale!['id'] == sale['id'];
                                            final total = (sale['totalAmount'] ?? 0.0) as num;
                                            final dateStr = sale['createdAt'] != null
                                                ? DateFormat('MM-dd HH:mm').format(
                                                    DateTime.parse(sale['createdAt'].toString()),
                                                  )
                                                : '';

                                            return ListTile(
                                              selected: isSelected,
                                              selectedTileColor: AppTheme.primary.withValues(alpha: 0.05),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              title: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    sale['saleCode'] ?? 'Unknown Code',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    '${total.toStringAsFixed(2)} EGP',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              subtitle: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(dateStr),
                                                  Text(
                                                    sale['paymentMethod']?.toString().toUpperCase() ?? '',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _selectedSale = sale;
                                                });
                                              },
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 32),
                      // Right Column: Details & Printing
                      Expanded(
                        flex: 5,
                        child: _selectedSale == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text(
                                      'Select a sale from the list to view receipt details.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.grey.shade50,
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedSale!['saleCode'] ?? 'Sale Details',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.print, color: AppTheme.primary),
                                          onPressed: () => _printReceipt(_selectedSale!),
                                          tooltip: 'Print Receipt',
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(_selectedSale!['createdAt'].toString()))}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      'Payment: ${_selectedSale!['paymentMethod']?.toString().toUpperCase()}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Items:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: (_selectedSale!['items'] as List? ?? []).length,
                                        itemBuilder: (context, idx) {
                                          final item = _selectedSale!['items'][idx] as Map;
                                          final name = item['productName'] ?? item['productId'] ?? 'Unknown Item';
                                          final variant = item['variantLabel'] != null &&
                                                  item['variantLabel'].toString().isNotEmpty
                                              ? ' (${item['variantLabel']})'
                                              : '';
                                          final qty = item['quantity'] ?? 1;
                                          final lineTotal = (item['lineTotal'] ?? 0.0) as num;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$name$variant x$qty',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                Text(
                                                  '${lineTotal.toStringAsFixed(2)} EGP',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Amount',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          '${((_selectedSale!['totalAmount'] ?? 0.0) as num).toStringAsFixed(2)} EGP',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
