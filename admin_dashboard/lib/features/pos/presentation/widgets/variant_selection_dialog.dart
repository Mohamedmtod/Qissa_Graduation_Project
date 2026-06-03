import 'package:flutter/material.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';

class VariantSelectionDialog extends StatelessWidget {
  final InventoryItem product;

  const VariantSelectionDialog({super.key, required this.product});

  static Future<ProductVariant?> show(BuildContext context, InventoryItem product) {
    return showDialog<ProductVariant>(
      context: context,
      builder: (context) => VariantSelectionDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter active variants
    final activeVariants = product.variants.where((v) => v.isActive).toList();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Select Size for ${product.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: activeVariants.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No active variants available for this product.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: activeVariants.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final variant = activeVariants[index];
                  final isOutOfStock = variant.stock <= 0;
                  final price = variant.salePrice != null && variant.salePrice! > 0
                      ? variant.salePrice!
                      : variant.price;
                  final hasDiscount = variant.salePrice != null && variant.salePrice! > 0;

                  return InkWell(
                    onTap: isOutOfStock
                        ? null
                        : () => Navigator.of(context).pop(variant),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isOutOfStock
                              ? Colors.grey.shade300
                              : AppTheme.primary.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        color: isOutOfStock
                            ? Colors.grey.shade50
                            : AppTheme.primary.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.label.isNotEmpty ? variant.label : 'Default Size',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isOutOfStock ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (hasDiscount) ...[
                                      Text(
                                        '${variant.price.toStringAsFixed(2)} EGP',
                                        style: const TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      '${price.toStringAsFixed(2)} EGP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isOutOfStock ? Colors.grey : AppTheme.primary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isOutOfStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    border: Border.all(color: Colors.red.shade200),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Out of stock',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else ...[
                                Text(
                                  'Stock: ${variant.stock.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: variant.stock < 5 ? Colors.orange.shade800 : Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  variant.unitType,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
