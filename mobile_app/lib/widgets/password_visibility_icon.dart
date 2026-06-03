import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';

class PasswordVisibilityIcon extends StatelessWidget {
  final bool isHidden;
  final VoidCallback onPressed;

  const PasswordVisibilityIcon({
    super.key,
    required this.isHidden,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: IconButton(
        icon: Icon(
          isHidden ? Icons.visibility_off : Icons.visibility,
          color: darkGray,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
