import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:perfume_app/core/theme/theme.dart';

/// Base Skeleton Wrapper using Shimmer effect
class SkeletonWrapper extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonWrapper({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? lighterBeige2,
      highlightColor: highlightColor ?? offWhite,
      child: child,
    );
  }
}

/// Generic Skeleton Box for rectangles and circles
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets margin;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.margin = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Product Card Skeleton - matches ProductCard dimensions
class ProductCardSkeleton extends StatelessWidget {
  final double width;
  final double height;

  const ProductCardSkeleton({super.key, this.width = 160, this.height = 280});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand name
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Product name
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price
                  Container(
                    width: 80,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable products skeleton
class HorizontalProductsSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double itemHeight;

  const HorizontalProductsSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemWidth = 160,
    this.itemHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 12 : 8,
              right: index == itemCount - 1 ? 12 : 8,
            ),
            child: ProductCardSkeleton(width: itemWidth, height: itemHeight),
          );
        },
      ),
    );
  }
}

/// Product Grid Skeleton - for search/category/wishlist
class ProductGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double childAspectRatio;

  const ProductGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 10,
    this.childAspectRatio = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return ProductCardSkeleton(
            width: double.infinity,
            height: double.infinity,
          );
        },
      ),
    );
  }
}

/// Search suggestions skeleton - matches the compact ListTile results.
class SearchSuggestionsSkeleton extends StatelessWidget {
  final int itemCount;

  const SearchSuggestionsSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
            ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 16,
                    borderRadius: 4,
                  ),
                ),
                const SizedBox(width: 18),
                SkeletonBox(
                  width: 16,
                  height: 16,
                  borderRadius: 8,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Cart Item Skeleton
class CartItemSkeleton extends StatelessWidget {
  const CartItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Image
            SkeletonBox(width: 80, height: 80, borderRadius: 8),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 60, height: 16, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cart Loading Skeleton
class CartSkeleton extends StatelessWidget {
  const CartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Items list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return const CartItemSkeleton();
              },
            ),
            const SizedBox(height: 20),
            // Summary section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 100, height: 16, borderRadius: 4),
                  const SizedBox(height: 12),
                  // Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 80, height: 14, borderRadius: 4),
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Shipping
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 80, height: 14, borderRadius: 4),
                      SkeletonBox(width: 60, height: 14, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 100, height: 18, borderRadius: 4),
                      SkeletonBox(width: 80, height: 18, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Checkout button
                  SkeletonBox(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order Card Skeleton
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 14, borderRadius: 4),
                    const SizedBox(height: 4),
                    SkeletonBox(width: 120, height: 12, borderRadius: 4),
                  ],
                ),
                SkeletonBox(width: 80, height: 16, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 12),
            // Divider
            Container(
              height: 1,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            // Order items preview
            Column(
              children: List.generate(
                2,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SkeletonBox(width: 60, height: 60, borderRadius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                              width: double.infinity,
                              height: 12,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 4),
                            SkeletonBox(width: 80, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Status
            SkeletonBox(width: 100, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Orders List Loading Skeleton
class OrderListSkeleton extends StatelessWidget {
  final int itemCount;

  const OrderListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const OrderCardSkeleton();
      },
    );
  }
}

/// Checkout Page Skeleton
class CheckoutSkeleton extends StatelessWidget {
  const CheckoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shipping Address Section
                  SkeletonBox(width: 150, height: 18, borderRadius: 4),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 200, height: 14, borderRadius: 4),
                        const SizedBox(height: 8),
                        SkeletonBox(
                          width: double.infinity,
                          height: 12,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 8),
                        SkeletonBox(
                          width: double.infinity,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Payment Method Section
                  SkeletonBox(width: 150, height: 18, borderRadius: 4),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SkeletonBox(width: 24, height: 24, borderRadius: 4),
                        const SizedBox(width: 12),
                        SkeletonBox(width: 150, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Order Summary
                  SkeletonBox(width: 150, height: 18, borderRadius: 4),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(
                              width: 100,
                              height: 12,
                              borderRadius: 4,
                            ),
                            SkeletonBox(width: 60, height: 12, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Place Order Button
                  SkeletonBox(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile Header Skeleton
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            SkeletonBox(width: 80, height: 80, borderRadius: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 150, height: 18, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 200, height: 14, borderRadius: 4),
                  const SizedBox(height: 8),
                  SkeletonBox(width: 180, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home Page Loading Skeleton - complete home layout
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header bar (greeting + icons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 100, height: 16, borderRadius: 4),
                      Row(
                        children: [
                          SkeletonBox(width: 32, height: 32, borderRadius: 8),
                          const SizedBox(width: 12),
                          SkeletonBox(width: 32, height: 32, borderRadius: 8),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  SkeletonBox(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SkeletonBox(
                width: double.infinity,
                height: 180,
                borderRadius: 12,
              ),
            ),
            const SizedBox(height: 20),
            // Categories Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 100, height: 16, borderRadius: 4),
                  const SizedBox(height: 12),
                  HorizontalProductsSkeleton(
                    itemCount: 4,
                    itemWidth: 100,
                    itemHeight: 120,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Products Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 150, height: 16, borderRadius: 4),
                  const SizedBox(height: 12),
                  HorizontalProductsSkeleton(
                    itemCount: 4,
                    itemWidth: 160,
                    itemHeight: 240,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Categories Page Skeleton - matches the custom fragrance families layout
class CategoryListSkeleton extends StatelessWidget {
  const CategoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title skeleton
              const SkeletonBox(
                width: 220,
                height: 32,
                borderRadius: 8,
              ),
              const SizedBox(height: 16),
              // Row 1: Floral & Fruity
              Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Oriental & Woody
              Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 3: Fresh (full width)
              const SkeletonBox(
                width: double.infinity,
                height: 225,
                borderRadius: 40,
              ),
              const SizedBox(height: 16),
              // Row 4: Gourmand & Leather
              Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 225,
                      borderRadius: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 5: Oud (full width)
              const SkeletonBox(
                width: double.infinity,
                height: 225,
                borderRadius: 40,
              ),
              const SizedBox(height: 16),
              // Bottom AI Card skeleton
              const SkeletonBox(
                width: double.infinity,
                height: 180,
                borderRadius: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

