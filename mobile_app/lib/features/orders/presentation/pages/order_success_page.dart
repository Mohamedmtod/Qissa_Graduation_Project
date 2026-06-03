import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/orders/utils/order_display_code.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class OrderSuccessPage extends StatelessWidget {
  final String orderId;
  final String? orderCode;
  final bool cartCleanupFailed;

  const OrderSuccessPage({
    super.key,
    required this.orderId,
    this.orderCode,
    this.cartCleanupFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const pagePadding = 24.0;
    final rose = Theme.of(context).colorScheme.primary;
    final roseDark = const Color(0xFFAA6470);
    final softShadow = rose.withValues(alpha: 0.16);
    final isNarrow = MediaQuery.sizeOf(context).width < 380;
    final successRingSize = isNarrow ? 164.0 : 188.0;
    final successIconSize = isNarrow ? 82.0 : 92.0;
    final displayCode = orderDisplayCode(
      orderId: orderId,
      orderCode: orderCode,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        const Color(0xFFF9F5F0),
                        Theme.of(context).colorScheme.surface,
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 220,
                left: -60,
                right: -60,
                child: IgnorePointer(
                  child: Container(
                    height: 420,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.25),
                        radius: 0.78,
                        colors: [
                          rose.withValues(alpha: 0.20),
                          rose.withValues(alpha: 0.10),
                          const Color.fromARGB(0, 0, 0, 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: pagePadding,
                    vertical: 0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),
                        Container(
                          width: successRingSize,
                          height: successRingSize,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLowest
                                .withValues(alpha: 0.96),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: softShadow,
                                blurRadius: 42,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: successIconSize,
                              height: successIconSize,
                              decoration: BoxDecoration(
                                color: rose,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: rose.withValues(alpha: 0.24),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: white,
                                size: isNarrow ? 50 : 54,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isNarrow ? 30 : 38),
                        Text(
                          l10n.labelOrderSuccessful,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerif(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: isNarrow ? 26 : 28,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.msgOrderProcessingAssurance,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.68),
                            fontSize: isNarrow ? 15 : 16,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 34),
                        if (orderId.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest
                                  .withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: rose.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.045),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.34),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.orderNumber,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.42),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  displayCode,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF7F7C78),
                                    fontSize: isNarrow ? 20 : 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: displayCode),
                                    );
                                    if (!context.mounted) return;
                                    AppSnackBar.showInfo(
                                      context,
                                      l10n.msgOrderNumberCopied,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                  ),
                                  label: Text(l10n.btnCopyID),
                                  style: TextButton.styleFrom(
                                    foregroundColor: roseDark,
                                    textStyle: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                        if (cartCleanupFailed) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6EB),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.10),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.msgCartCleanupWarning,
                                    style: GoogleFonts.manrope(
                                      color: Colors.orange.shade900,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 68,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [rose, roseDark],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: rose.withValues(alpha: 0.28),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                context.go('/my-orders');
                              },
                              icon: const Icon(
                                Icons.local_shipping_rounded,
                                color: white,
                                size: 22,
                              ),
                              label: Text(
                                l10n.btnTrackOrder,
                                style: GoogleFonts.manrope(
                                  color: white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: OutlinedButton(
                            onPressed: navigateToMainLayout(context, 0),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: white.withValues(alpha: 0.35),
                              side: BorderSide(
                                color: rose.withValues(alpha: 0.12),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              l10n.btnContinueShopping,
                              style: GoogleFonts.manrope(
                                color: rose,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
