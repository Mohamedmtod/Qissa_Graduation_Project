import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';

class CustomIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool background;
  final double size;
  final EdgeInsets padding;
  final Color color;
  final Color? iconColor;

  const CustomIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = true,
    this.size = 26,
    this.padding = EdgeInsets.zero,
    this.color = lighterBeige2,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? Theme.of(context).colorScheme.primary;

    return ClipRRect(
      child: Container(
        decoration: BoxDecoration(
          color: background ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: padding ,
            child: Icon(icon, size: size, color: resolvedIconColor),
          ),
        ),
      ),
    );
  }
}
