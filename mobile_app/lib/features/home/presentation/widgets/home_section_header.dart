import 'package:flutter/material.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.padding = const EdgeInsetsDirectional.only(
      start: 12,
      end: 12,
      top: 24,
      bottom: 12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final showAction = actionText != null && onActionTap != null;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: CustomTextStyle(
              text: title,
              fontsize: 22,
              textColor: Theme.of(context).colorScheme.onSurface,
              bold: true,
            ),
          ),
          if (showAction)
            GestureDetector(
              onTap: onActionTap,
              child: CustomTextStyle(
                text: actionText!,
                fontsize: 13,
                textColor: Theme.of(context).colorScheme.primary,
                bold: true,
              ),
            ),
        ],
      ),
    );
  }
}
