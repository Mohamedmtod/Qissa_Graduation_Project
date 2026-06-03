import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/widgets/skeletons.dart';

void main() {
  group('Skeleton Widgets', () {
    testWidgets('SkeletonWrapper renders with Shimmer effect', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonWrapper(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );

      expect(find.byType(SkeletonWrapper), findsOneWidget);
    });

    testWidgets('ProductCardSkeleton renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProductCardSkeleton(width: 160, height: 280)),
        ),
      );

      expect(find.byType(ProductCardSkeleton), findsOneWidget);
    });

    testWidgets('ProductGridSkeleton renders with correct item count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductGridSkeleton(crossAxisCount: 2, itemCount: 10),
          ),
        ),
      );

      expect(find.byType(ProductGridSkeleton), findsOneWidget);
    });

    testWidgets('SearchSuggestionsSkeleton renders compact suggestion rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SearchSuggestionsSkeleton(itemCount: 4)),
        ),
      );

      expect(find.byType(SearchSuggestionsSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(8));
    });

    testWidgets('CartSkeleton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CartSkeleton())),
      );

      expect(find.byType(CartSkeleton), findsOneWidget);
    });

    testWidgets('OrderListSkeleton renders with correct item count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrderListSkeleton(itemCount: 3)),
        ),
      );

      expect(find.byType(OrderListSkeleton), findsOneWidget);
    });

    testWidgets('HomeSkeleton renders complete home layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeSkeleton())),
      );

      expect(find.byType(HomeSkeleton), findsOneWidget);
    });

    testWidgets('CategoryListSkeleton renders custom category layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CategoryListSkeleton())),
      );

      expect(find.byType(CategoryListSkeleton), findsOneWidget);
    });
  });
}
