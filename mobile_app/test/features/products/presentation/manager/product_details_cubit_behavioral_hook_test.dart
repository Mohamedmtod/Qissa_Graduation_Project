import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_state.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

class MockProductRepo extends Mock implements ProductRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockRecentlyViewedRepo extends Mock implements RecentlyViewedRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

ProductModel _product() {
  final ts = Timestamp.fromMillisecondsSinceEpoch(10);
  return ProductModel(
    id: 'p1',
    name: 'Perfume',
    nameLower: 'perfume',
    searchPrefixes: buildSearchPrefixes('Perfume'),
    brand: 'Brand',
    price: 1000,
    stock: 4,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus', 'musk'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: ts,
    updatedAt: ts,
    occasion: 'daily',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(EventType.view);
  });

  test('tracks view exactly once on first successful load', () async {
    final productRepo = MockProductRepo();
    final eventRepo = MockEventRepo();
    final recentlyViewedRepo = MockRecentlyViewedRepo();
    final tasteRepo = MockUserTasteRepo();
    final controller = StreamController<ProductModel?>();

    when(
      () => productRepo.streamProductById(any()),
    ).thenAnswer((_) => controller.stream);
    when(
      () => recentlyViewedRepo.addView(any(), maxItems: any(named: 'maxItems')),
    ).thenAnswer((_) async {});
    when(
      () => eventRepo.logProductView(
        productId: any(named: 'productId'),
        name: any(named: 'name'),
        price: any(named: 'price'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tasteRepo.recordEvent(
        eventType: any(named: 'eventType'),
        notes: any(named: 'notes'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    final cubit = ProductDetailsCubit(
      productRepo,
      eventRepo,
      recentlyViewedRepo,
      tasteRepo,
    );

    cubit.watchProduct('p1');

    final product = _product();
    controller.add(product);
    controller.add(product);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => eventRepo.logProductView(
        productId: 'p1',
        name: 'Perfume',
        price: 1000,
      ),
    ).called(1);
    verify(
      () => tasteRepo.recordEvent(
        eventType: any(named: 'eventType'),
        notes: const ['citrus', 'musk'],
        userId: any(named: 'userId'),
      ),
    ).called(1);

    await cubit.close();
    await controller.close();
  });

  test('emits unavailable state for hidden products', () async {
    final productRepo = MockProductRepo();
    final eventRepo = MockEventRepo();
    final recentlyViewedRepo = MockRecentlyViewedRepo();
    final tasteRepo = MockUserTasteRepo();
    final controller = StreamController<ProductModel?>();

    when(
      () => productRepo.streamProductById(any()),
    ).thenAnswer((_) => controller.stream);
    when(
      () => recentlyViewedRepo.addView(any(), maxItems: any(named: 'maxItems')),
    ).thenAnswer((_) async {});
    when(
      () => eventRepo.logProductView(
        productId: any(named: 'productId'),
        name: any(named: 'name'),
        price: any(named: 'price'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tasteRepo.recordEvent(
        eventType: any(named: 'eventType'),
        notes: any(named: 'notes'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    final cubit = ProductDetailsCubit(
      productRepo,
      eventRepo,
      recentlyViewedRepo,
      tasteRepo,
    );

    cubit.watchProduct('p1');

    controller.add(_product().copyWith(isActive: false));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<ProductDetailsUnavailable>());
    verifyNever(
      () => eventRepo.logProductView(
        productId: any(named: 'productId'),
        name: any(named: 'name'),
        price: any(named: 'price'),
      ),
    );
    verifyNever(
      () => recentlyViewedRepo.addView(any(), maxItems: any(named: 'maxItems')),
    );

    await cubit.close();
    await controller.close();
  });
}
