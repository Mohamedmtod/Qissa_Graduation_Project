import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/orders/presentation/pages/address_page.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/custom_icon.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:go_router/go_router.dart';

class HomeHeaderBar extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool isAtTop;
  final double radius;
  const HomeHeaderBar({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.color,
    this.isAtTop = true,
    this.radius = 20,
  });

  @override
  State<HomeHeaderBar> createState() => _HomeHeaderBarState();
}

class _HomeHeaderBarState extends State<HomeHeaderBar> {
  @override
  void initState() {
    super.initState();
    // Load/Update using the realtime stream
    context.read<AddressCubit>().loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: widget.padding,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(widget.isAtTop ? 0 : widget.radius),
            bottomRight: Radius.circular(widget.isAtTop ? 0 : widget.radius),
          ),
        ),
        child: Row(
          children: [
            BlocBuilder<AddressCubit, AddressState>(
              builder: (context, state) {
                final address = state.selectedAddress ?? state.defaultAddress;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: CustomIcon(
                            icon: FluentIcons.home_28_filled,
                            background: false,
                            size: 20,
                            onTap: () {},
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: CustomTextStyle(
                            text: l10n.labelDeliverTo,
                            textColor: const Color.fromARGB(255, 107, 107, 110),
                            fontsize: 15,
                            bold: true,
                          ),
                        ),
                        CustomIcon(
                          icon: Icons.keyboard_arrow_down,
                          size: 20,
                          background: false,
                          onTap: () async {
                            final result = await openAddressSheetPage(context);
                            if (result != null && context.mounted) {
                              context.read<AddressCubit>().setSelectedAddress(
                                AddressModel.fromMap(
                                  result,
                                  result['id'] ?? '',
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: CustomTextStyle(
                        text: address == null
                            ? l10n.labelSelectAddress
                            : '${address.area ?? ''}, ${address.city ?? ''}'
                                  .replaceAll(RegExp(r'^, |, $'), '')
                                  .trim(),
                        textColor: Theme.of(context).colorScheme.onSurface,
                        fontsize: 16,
                        bold: true,
                      ),
                    ),
                  ],
                );
              },
            ),

            const Spacer(),
            CustomIcon(
              icon: Icons.favorite,
              padding: const EdgeInsets.all(8),
              color: Colors.transparent,
              iconColor: Theme.of(context).colorScheme.primary,
              onTap: () {
                context.push('/wishlist');
              },
            ),
          ],
        ),
      ),
    );
  }
}
