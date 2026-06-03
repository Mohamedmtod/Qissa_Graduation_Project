


import 'package:flutter/material.dart';

class GoBackIcon extends StatelessWidget {
  final VoidCallback navigateTo ;
  const GoBackIcon({
    required this.navigateTo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.arrow_back_ios_new),
      color: Theme.of(context).colorScheme.onSurface,
      onPressed: navigateTo,
    );
  }
}
