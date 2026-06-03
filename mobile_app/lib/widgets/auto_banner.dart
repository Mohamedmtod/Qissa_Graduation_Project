import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/home/data/models/banner_model.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class AutoBanner extends StatefulWidget {
  final List<Widget> banners;
  final double? height;
  final EdgeInsetsGeometry padding;
  const AutoBanner({
    super.key,
    required this.banners,
    this.height,
    required this.padding,
  });

  @override
  State<AutoBanner> createState() => _AutoBannerState();
}

class _AutoBannerState extends State<AutoBanner> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_controller.hasClients && widget.banners.isNotEmpty) {
        _currentPage = (_currentPage + 1) % widget.banners.length;

        _controller.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalHeight = widget.height ?? 140;
    final bool showIndicator = widget.banners.length > 1;
    final double indicatorHeight = showIndicator ? 18 : 0;
    final double bannerHeight = (totalHeight - indicatorHeight).clamp(
      0.0,
      totalHeight,
    );

    return SizedBox(
      height: totalHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: bannerHeight,
            child: PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: widget.banners,
            ),
          ),
          if (showIndicator)
            SizedBox(
              height: indicatorHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.primary
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BannerWidget extends StatelessWidget {
  final BannerModel bannerInfo;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const BannerWidget({
    super.key,
    required this.bannerInfo,
    required this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GestureDetector(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
                final cacheWidth = constraints.maxWidth.isFinite
                    ? (constraints.maxWidth * devicePixelRatio).round()
                    : null;
                final cacheHeight = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight * devicePixelRatio).round()
                    : null;

                return CachedNetworkImage(
                  imageUrl: bannerInfo.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheWidth,
                  memCacheHeight: cacheHeight,
                  placeholder: (context, url) => const SkeletonWrapper(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 24,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[50],
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        onTap: () {
          onTap?.call();
        },
      ),
    );
  }
}
