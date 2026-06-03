import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';

/// A reusable bottom navigation bar that can be placed on any page.
///
/// [currentIndex] — the tab that should appear active (use [Go] constants).
/// [onTabSelected] — called when the user taps a tab. If null, the default
/// behaviour is used: guard the Profile tab and navigate to [MainLayout].
class SharedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  const SharedNavBar({
    super.key,
    required this.currentIndex,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: NavBar(
        currentIndex: currentIndex,
        onTabSelected: onTabSelected ?? _defaultOnTabSelected(context),
      ),
    );
  }

  ValueChanged<int> _defaultOnTabSelected(BuildContext context) {
    return (index) {
      final needsAuth = index == Go.profile;
      final authState = context.read<AuthBloc>().state;
      if (needsAuth && authState.status != AuthStatus.authenticated) {
        goToLoginForProtectedTab(context, index);
        return;
      }
      
      switch (index) {
        case Go.home:
          context.go('/home');
          break;
        case Go.categories:
          context.go('/categories');
          break;
        case Go.aiChat:
          context.go('/ai-chat');
          break;
        case Go.cart:
          context.go('/cart');
          break;
        case Go.profile:
          context.go('/profile');
          break;
      }
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NavBar (stateful animated implementation)
// ─────────────────────────────────────────────────────────────────────────────

class NavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with SingleTickerProviderStateMixin {
  List<(IconData, String)> get items {
    final l10n = AppLocalizations.of(context);
    return [
      (Icons.home_outlined, l10n.labelNavHome),
      (Icons.category_outlined, l10n.labelNavCategories),
      (Icons.auto_awesome_outlined, l10n.labelNavAI),
      (Icons.shopping_cart_outlined, l10n.labelNavCart),
      (Icons.person_outline, l10n.labelNavProfile),
    ];
  }

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..value = 1.0;

  int fromIndex = 0;
  int toIndex = 0;

  bool _isDragging = false;
  double _dragCenterX = 0;
  double? _snapFromCenterX;

  double _cachedSlotWidth = 0;
  static const _horizontalPadding = 8.0;

  bool get _isRTL {
    if (!mounted) return false;
    return Directionality.of(context) == TextDirection.rtl;
  }

  int _getVisualIndex(int index) {
    return _isRTL ? (items.length - 1 - index) : index;
  }

  static const _navHeight = 64.0;
  static const _barHeight = 64.0;
  static const _barTop = 2.0;

  static const _bubbleWidthIdle = 72.0;
  static const _bubbleWidthDragging = 78.0;
  static const _bubbleHeightIdle = 56.0;
  static const _bubbleHeightDragging = 78.0;
  static const _bubbleTopIdle = 0;
  static const _bubbleTopDragging = 8.0;

  static const _shellRadius = 999.0;
  static const _pillRadius = 28.0;
  static const _maxOvershootT = 1.03;

  static const _inactiveColor = Color(0xFF4E4E50);
  static const _shellColor = Color(0xFFF8F4EE);
  static const _pillColor = Color.fromARGB(255, 248, 238, 240);
  static const _shellBorderColor = Color(0xFFEAE1D6);
  static const _pillBorderColor = Color(0xFFF3E6D3);

  @override
  void initState() {
    super.initState();
    toIndex = widget.currentIndex;
    fromIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant NavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      if (_snapFromCenterX == null) {
        fromIndex = oldWidget.currentIndex;
      }
      toIndex = widget.currentIndex;
      controller.forward(from: 0);
    }
  }

  void onTapItem(int index) {
    if (index == toIndex) return;
    widget.onTabSelected(index);
  }

  void _onDragStart() {
    _isDragging = true;
    _snapFromCenterX = null;
    controller.stop();
    _dragCenterX =
        _horizontalPadding +
        (_getVisualIndex(toIndex) + 0.5) * _cachedSlotWidth;
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final minX = _horizontalPadding + 0.5 * _cachedSlotWidth;
    final maxX = _horizontalPadding + (items.length - 0.5) * _cachedSlotWidth;
    _dragCenterX = (_dragCenterX + details.delta.dx).clamp(minX, maxX);
    setState(() {});
  }

  void _onDragEnd() {
    if (!_isDragging) return;
    _snapFromCenterX = _dragCenterX;
    _isDragging = false;

    final rawIndex =
        (_dragCenterX - _horizontalPadding) / _cachedSlotWidth - 0.5;
    final snappedVisualIndex = rawIndex.round().clamp(0, items.length - 1);
    final snappedIndex = _getVisualIndex(snappedVisualIndex);

    toIndex = snappedIndex;

    if (snappedIndex != widget.currentIndex) {
      widget.onTabSelected(snappedIndex);
    }
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _navHeight,
      child: LayoutBuilder(
        builder: (context, c) {
          final barWidth = c.maxWidth;
          final contentWidth = barWidth - (_horizontalPadding * 2);
          final slotWidth = contentWidth / items.length;

          _cachedSlotWidth = slotWidth;

          return GestureDetector(
            onPanStart: (_) => _onDragStart(),
            onPanUpdate: _onDragUpdate,
            onPanEnd: (_) => _onDragEnd(),
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                double centerX;

                if (_isDragging) {
                  centerX = _dragCenterX;
                } else {
                  final rawSlideT = Curves.easeOutBack.transform(
                    controller.value,
                  );
                  final slideT = rawSlideT.clamp(0.0, _maxOvershootT);

                  final fromCenter =
                      _snapFromCenterX ??
                      (_horizontalPadding +
                          (_getVisualIndex(fromIndex) + 0.5) * slotWidth);
                  final toCenter =
                      _horizontalPadding +
                      (_getVisualIndex(toIndex) + 0.5) * slotWidth;
                  centerX = lerpDouble(fromCenter, toCenter, slideT)!;

                  if (controller.value >= 1.0) {
                    _snapFromCenterX = null;
                  }
                }

                final animationT = _isDragging ? 1.0 : controller.value;

                final bubbleWidth =
                    _isDragging ? _bubbleWidthDragging : _bubbleWidthIdle;
                final bubbleHeight =
                    _isDragging ? _bubbleHeightDragging : _bubbleHeightIdle;
                final bubbleTop = lerpDouble(
                  _bubbleTopIdle,
                  _bubbleTopDragging,
                  animationT,
                )!;
                final bubbleLeft = (centerX - (bubbleWidth / 2)).clamp(
                  0.0,
                  barWidth - bubbleWidth,
                );
                final visualActiveDisplayIndex = _isDragging
                    ? (((centerX - _horizontalPadding) / slotWidth) - 0.5)
                          .round()
                          .clamp(0, items.length - 1)
                    : _getVisualIndex(toIndex);
                final activeDisplayIndex = _getVisualIndex(
                  visualActiveDisplayIndex,
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _barTop,
                      child: Container(
                        height: _barHeight,
                        decoration: BoxDecoration(
                          color: _shellColor,
                          borderRadius: BorderRadius.circular(_shellRadius),
                          border: Border.all(
                            color: _shellBorderColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x1A9F8E74),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
                              blurRadius: 0,
                              spreadRadius: 1,
                              offset: const Offset(0, -1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _horizontalPadding,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned(
                      left: bubbleLeft,
                      top: _isDragging ? bubbleTop - 13 : bubbleTop - 2,
                      width: bubbleWidth,
                      height: bubbleHeight,
                      child: IgnorePointer(
                        child: _buildActivePill(
                          pillColor: _pillColor,
                          pillBorderColor: _pillBorderColor,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _barTop,
                      height: _barHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _horizontalPadding,
                        ),
                        child: _row(
                          activeIndex: activeDisplayIndex,
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: _inactiveColor,
                          onTap: onTapItem,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _row({
    required int activeIndex,
    required Color activeColor,
    required Color inactiveColor,
    void Function(int index)? onTap,
  }) {
    return Row(
      children: List.generate(items.length, (i) {
        return Expanded(
          child: GestureDetector(
            key: ValueKey('nav_tab_$i'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap(i),
            child: _navItem(
              index: i,
              color: i == activeIndex ? activeColor : inactiveColor,
              bold: i == activeIndex,
            ),
          ),
        );
      }),
    );
  }

  Widget _navItem({
    required int index,
    required Color color,
    required bool bold,
  }) {
    final item = items[index];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.$1, color: color, size: 24),
        const SizedBox(height: 2),
        CustomTextStyle(
          text: item.$2,
          maxLines: 1,
          textOverflow: TextOverflow.fade,
          textColor: color,
          fontsize: 10.5,
          bold: bold,
        ),
      ],
    );
  }

  Widget _buildActivePill({
    required Color pillColor,
    required Color pillBorderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: pillColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
            colors: [
            Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.55),
            pillColor,
            const Color.fromARGB(255, 238, 215, 221),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(_pillRadius),
        border: Border.all(color: pillBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x2A9F8E74),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(-2, -4),
          ),
        ],
      ),
    );
  }
}
