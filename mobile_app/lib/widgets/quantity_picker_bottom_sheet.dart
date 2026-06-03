import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

Future<void> showQuantityPickerBottomSheet({
  required BuildContext context,
  required int currentQuantity,
  required int maxQuantity,
  required ValueChanged<int> onQuantitySelected,
  VoidCallback? onRemove,
  double bottomMargin = 0.0,
}) async {
  final l10n = AppLocalizations.of(context);
  final limit = maxQuantity.clamp(1, 10);

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return Container(
        margin: EdgeInsets.only(bottom: bottomMargin, left: bottomMargin > 0 ? 16 : 0, right: bottomMargin > 0 ? 16 : 0),
        padding: const EdgeInsets.only(
          top: 24,
          bottom: 32,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: bottomMargin > 0 
              ? BorderRadius.circular(28) 
              : const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomTextStyle(
              text: l10n.labelQty,
              fontsize: 18,
              bold: true,
              textColor: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(limit, (index) {
                final number = index + 1;
                final isSelected = number == currentQuantity;
                return InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onQuantitySelected(number);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryContainer : offWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: CustomTextStyle(
                        text: '$number',
                        fontsize: 18,
                        bold: isSelected,
                        textColor: isSelected
                            ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (onRemove != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onRemove();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  l10n.btnRemoveFromCart,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
