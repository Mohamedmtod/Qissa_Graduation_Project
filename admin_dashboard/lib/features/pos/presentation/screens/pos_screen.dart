// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';
import '../cubit/pos_cubit.dart';
import '../cubit/cash_session_cubit.dart';
import '../../data/repos/pos_repository.dart';
import '../widgets/variant_selection_dialog.dart';
import '../widgets/stock_conflict_dialog.dart';
import '../widgets/pos_sales_history_dialog.dart';
import '../widgets/shift_summary_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _openingCashController = TextEditingController();
  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _searchQuery = '';
  String _paymentMethod = 'cash'; // 'cash' | 'card'
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    context.read<CashSessionCubit>().loadCurrentSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _openingCashController.dispose();
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _canCheckout(PosState posState) {
    if (!posState.isOnline) return false;
    if (posState.submitStatus == PosSubmitStatus.submitting) return false;
    if (posState.submitStatus == PosSubmitStatus.unknownResult) return true; // retry is always allowed
    if (posState.cartItems.isEmpty) return false;
    return true;
  }

  void _showOpenSessionDialog(BuildContext context) {
    _openingCashController.text = '0.00';
    _notesController.clear();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Open New Shift Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _openingCashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Opening Cash Amount (EGP)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Opening Shift Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final cash = double.tryParse(_openingCashController.text.trim()) ?? 0.0;
                context.read<CashSessionCubit>().openSession(cash, _notesController.text.trim());
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Start Shift'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseSessionDialog(BuildContext context, Map<String, dynamic> session) {
    _actualCashController.text = '${session['expectedCash'] ?? 0.0}';
    _notesController.clear();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Close Current Shift Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shift: ${session['shiftCode']}'),
              const SizedBox(height: 8),
              Text('Expected Cash in Drawer: ${session['expectedCash']} EGP'),
              Text('Expected Card Amount: ${session['expectedCard']} EGP'),
              Text('Total Checkout Sales: ${session['totalSalesCount']}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _actualCashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Actual Cash in Drawer (EGP)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Closing Shift Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final cash = double.tryParse(_actualCashController.text.trim()) ?? 0.0;
                final notes = _notesController.text.trim();
                Navigator.of(dialogContext).pop();

                final cubit = context.read<CashSessionCubit>();
                final activeSession = cubit.state.activeSession;
                if (activeSession != null) {
                  final sessionId = activeSession['id'] as String;
                  final repo = context.read<PosRepository>();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    final result = await repo.closeCashSession(
                      sessionId: sessionId,
                      actualCash: cash,
                      notes: notes,
                    );

                    if (mounted) {
                      navigator.pop();
                    }
                    await cubit.loadCurrentSession();

                    if (context.mounted) {
                      final summary = {
                        ...activeSession,
                        'countedCash': cash,
                        'discrepancy': result['discrepancy'] ?? (cash - ((activeSession['expectedCash'] as num?)?.toDouble() ?? 0.0)),
                        'closeNotes': notes,
                        'closedAt': DateTime.now().toIso8601String(),
                      };
                      await ShiftSummaryDialog.show(context, summary);
                    }
                  } catch (e) {
                    if (mounted) {
                      navigator.pop();
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to close session: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('End & Close Shift', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessReceipt(BuildContext context, Map<String, dynamic> invoice) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Sale Completed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice Code: ${invoice['saleCode']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Total Amount: ${invoice['totalAmount']} EGP'),
              Text('Payment Method: ${invoice['paymentMethod'].toString().toUpperCase()}'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
              onPressed: () async {
                final repo = context.read<PosRepository>();
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  final details = await repo.getSaleDetails(invoice['saleId']);

                  if (mounted) {
                    navigator.pop(); // Dismiss loading
                  }
                  _printReceiptFromDetails(details);
                } catch (e) {
                  if (mounted) {
                    navigator.pop(); // Dismiss loading
                  }
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to print receipt: $e')),
                    );
                  }
                }
              },
            ),
            ElevatedButton(
              onPressed: () {
                context.read<PosCubit>().dismissInvoice();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _printReceiptFromDetails(Map<String, dynamic> sale) {
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
        : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();

    return BlocBuilder<CashSessionCubit, CashSessionState>(
      builder: (context, sessionState) {
        if (sessionState.isLoading) {
          return const Scaffold(
            body: AdminLoadingState(title: 'Loading Shift Status'),
          );
        }

        final activeSession = sessionState.activeSession;

        if (activeSession == null) {
          // Display Shift Start overlay
          return Scaffold(
            body: Column(
              children: [
                SharedTopbar(
                  title: l10n.t('pos.topbarTitle', fallback: 'Point of Sale'),
                  searchHint: 'Search catalog...',
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: AdminSurfaceCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 64, color: AppTheme.primary),
                            const SizedBox(height: 16),
                            Text(
                              'Shift Session Locked',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'To begin checking out orders and registering sales, you must open a new cash drawer shift.',
                              textAlign: TextAlign.center,
                            ),
                            if (sessionState.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sessionState.errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            AdminPrimaryButton(
                              label: 'Start Cash Session',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () => _showOpenSessionDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Active Session UI
        return BlocConsumer<PosCubit, PosState>(
          listenWhen: (previous, current) {
            final justSucceeded = previous.successInvoice == null && current.successInvoice != null;
            final justValidationError = previous.submitStatus != PosSubmitStatus.validationError &&
                current.submitStatus == PosSubmitStatus.validationError &&
                current.stockConflicts.isNotEmpty;
            return justSucceeded || justValidationError;
          },
          listener: (context, posState) {
            if (posState.successInvoice != null) {
              _showSuccessReceipt(context, posState.successInvoice!);
            }
            if (posState.submitStatus == PosSubmitStatus.validationError &&
                posState.stockConflicts.isNotEmpty) {
              final conflicts = posState.stockConflicts;
              context.read<PosCubit>().clearError();
              StockConflictDialog.show(context, conflicts);
            }
          },
          builder: (context, posState) {
            final uniqueCollections = posState.products
                .map((p) => p.collection)
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList();

            final allLabel = l10n.t('pos.allCategories', fallback: 'All');
            final categories = [
              {'id': '', 'label': allLabel},
              ...uniqueCollections.map((c) => {'id': c, 'label': c}),
            ];

            final filteredProducts = posState.products.where((p) {
              if (!p.isSellable) return false;
              if (_selectedCategory.isNotEmpty && p.collection != _selectedCategory) {
                return false;
              }
              final query = _searchQuery.toLowerCase().trim();
              if (query.isEmpty) return true;
              return p.name.toLowerCase().contains(query) ||
                  p.collection.toLowerCase().contains(query);
            }).toList();

            return Scaffold(
              body: Column(
                children: [
                  SharedTopbar(
                    title: 'POS Shift: ${activeSession['shiftCode']}',
                    searchHint: 'Search catalog...',
                    onNotificationsTap: () => _showCloseSessionDialog(context, activeSession),
                    actions: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Sales History'),
                        onPressed: () {
                          PosSalesHistoryDialog.show(context, context.read<PosCubit>());
                        },
                      ),
                    ],
                  ),
                  if (!posState.isOnline)
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'OFFLINE — Checkout disabled until connection is restored.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (posState.errorMessage != null)
                    Container(
                      width: double.infinity,
                      color: posState.submitStatus == PosSubmitStatus.validationError ? Colors.orange.shade700 : Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(posState.submitStatus == PosSubmitStatus.validationError ? Icons.warning_amber_rounded : Icons.error_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              posState.errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            onPressed: () => context.read<PosCubit>().clearError(),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Search & Products
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search products by name or collection...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(16)),
                                    ),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () => _searchController.clear(),
                                          )
                                        : null,
                                  ),
                                ),
                                 const SizedBox(height: 16),
                                 if (categories.length > 1) ...[
                                   SizedBox(
                                     height: 40,
                                     child: ListView.separated(
                                       scrollDirection: Axis.horizontal,
                                       itemCount: categories.length,
                                       separatorBuilder: (context, index) => const SizedBox(width: 8),
                                       itemBuilder: (context, index) {
                                         final cat = categories[index];
                                         final catId = cat['id']!;
                                         final catLabel = cat['label']!;
                                         final isSelected = catId == _selectedCategory;
                                         return ChoiceChip(
                                           label: Text(catLabel),
                                           selected: isSelected,
                                           onSelected: (selected) {
                                             if (selected) {
                                               setState(() {
                                                 _selectedCategory = catId;
                                               });
                                             }
                                           },
                                         );
                                       },
                                     ),
                                   ),
                                   const SizedBox(height: 16),
                                 ],
                                 if (posState.isLoading && posState.products.isEmpty)
                                  const Expanded(
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: filteredProducts.length,
                                      itemBuilder: (context, index) {
                                        final prod = filteredProducts[index];
                                        return _buildCatalogItemCard(prod, posState.isCartLocked);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Right Panel: Cart & Checkout
                        Container(
                          width: 380,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppTheme.surfaceContainerHighest,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order Cart',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (posState.cartItems.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                                        onPressed: posState.isCartLocked
                                            ? null
                                            : () => context.read<PosCubit>().clearCart(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Unknown result — cart locked
                                if (posState.submitStatus == PosSubmitStatus.unknownResult) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      border: Border.all(color: Colors.red.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.lock_clock, color: Colors.red.shade800),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'النتيجة غير معروفة — تم قفل السلة لمنع التكرار.',
                                                style: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'اضغط "إعادة المحاولة" لإرسال نفس الطلب بنفس المفتاح. أو اضغط "إلغاء القفل" إذا أكدت يدوياً أن العملية فشلت.',
                                          style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                                                onPressed: posState.isOnline
                                                    ? () => context.read<PosCubit>().retryCheckout()
                                                    : null,
                                                label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () => context.read<PosCubit>().forceUnlock(),
                                              child: Text('إلغاء القفل', style: TextStyle(color: Colors.red.shade700)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Cart Items
                                Expanded(
                                  child: posState.cartItems.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.shopping_cart_outlined, size: 48, color: AppTheme.onSurfaceVariant),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Cart is empty',
                                                style: TextStyle(color: AppTheme.onSurfaceVariant),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: posState.cartItems.length,
                                          separatorBuilder: (context, index) => const Divider(),
                                          itemBuilder: (context, index) {
                                            final item = posState.cartItems[index];
                                            return _buildCartRow(item, posState.isCartLocked);
                                          },
                                        ),
                                ),
                                const Divider(height: 32),
                                // Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${posState.totalAmount.toStringAsFixed(2)} EGP',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Payment method selection
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Center(child: Text('Cash')),
                                        selected: _paymentMethod == 'cash',
                                        onSelected: posState.isCartLocked
                                            ? null
                                            : (selected) {
                                                if (selected) setState(() => _paymentMethod = 'cash');
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Center(child: Text('Card')),
                                        selected: _paymentMethod == 'card',
                                        onSelected: posState.isCartLocked
                                            ? null
                                            : (selected) {
                                                if (selected) setState(() => _paymentMethod = 'card');
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: AdminPrimaryButton(
                                    label: posState.submitStatus == PosSubmitStatus.submitting
                                        ? 'جارٍ المعالجة...'
                                        : posState.submitStatus == PosSubmitStatus.unknownResult
                                            ? 'إعادة المحاولة'
                                            : 'إتمام البيع',
                                    icon: posState.submitStatus == PosSubmitStatus.unknownResult
                                        ? Icons.refresh
                                        : Icons.check,
                                    onPressed: _canCheckout(posState)
                                        ? () {
                                            if (posState.submitStatus == PosSubmitStatus.unknownResult) {
                                              context.read<PosCubit>().retryCheckout();
                                            } else {
                                              context.read<PosCubit>().checkout(
                                                sessionId: activeSession['id'] as String,
                                                paymentMethod: _paymentMethod,
                                              );
                                            }
                                          }
                                        : null,
                                  ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogItemCard(InventoryItem prod, bool isLocked) {
    final variant = prod.variants.isNotEmpty ? prod.variants.first : null;
    final price = variant != null
        ? (variant.salePrice != null && variant.salePrice! > 0 ? variant.salePrice! : variant.price)
        : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              width: double.infinity,
              child: prod.imageUrl.isNotEmpty
                  ? Image.network(prod.imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 48, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  prod.collection,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2)} EGP',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      onPressed: isLocked || variant == null
                          ? null
                          : () async {
                              if (prod.variants.length > 1) {
                                final selected = await VariantSelectionDialog.show(context, prod);
                                if (selected != null && mounted) {
                                  context.read<PosCubit>().addToCart(prod, selected);
                                }
                              } else {
                                context.read<PosCubit>().addToCart(prod, variant);
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartRow(PosCartItem item, bool isLocked) {
    final price = item.variant.salePrice != null && item.variant.salePrice! > 0
        ? item.variant.salePrice!
        : item.variant.price;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name + (item.variant.label.isNotEmpty ? ' (${item.variant.label})' : ''),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${price.toStringAsFixed(2)} x ${item.quantity}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: isLocked ? null : () => context.read<PosCubit>().updateQuantity(item, -1),
              ),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: isLocked ? null : () => context.read<PosCubit>().updateQuantity(item, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
