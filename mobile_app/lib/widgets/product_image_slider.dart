import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class ProductImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  final double sliderPositionVertically;
  final double height;
  final double selectedSliderWidth;
  final double defaultSliderWidth;

  final BoxFit boxFit;
  final PageController? controller;
  final ScrollPhysics? physics;

  const ProductImageSlider({
    super.key,
    required this.imageUrls,
    this.height = 400,
    required this.sliderPositionVertically,
    required this.selectedSliderWidth,
    required this.defaultSliderWidth,

    this.boxFit = BoxFit.contain,
    this.controller,
    this.physics,
  });

  @override
  State<ProductImageSlider> createState() => _ProductImageSliderState();
}

class _ProductImageSliderState extends State<ProductImageSlider> {
  int _currentIndex = 0;
  PageController? _localController;

  PageController get _pageController =>
      widget.controller ?? (_localController ??= PageController());

  @override
  void dispose() {
    _localController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.height,
        color: lightGray,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: widget.physics,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: widget.boxFit,
                placeholder: (context, url) => SkeletonWrapper(
                  child: Container(
                    color: Colors.grey[100],
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error, color: Colors.red)),
              );
            },
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: widget.sliderPositionVertically,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index
                        ? widget.selectedSliderWidth
                        : widget.defaultSliderWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? AppTheme.primaryContainer
                          : Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
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
