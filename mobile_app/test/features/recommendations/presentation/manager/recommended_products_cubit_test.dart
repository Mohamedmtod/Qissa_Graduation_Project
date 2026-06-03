import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/user_taste_profile.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/presentation/manager/recommended_products_cubit.dart';
import 'package:perfume_app/features/recommendations/presentation/manager/recommended_products_state.dart';

class MockProductRepo extends Mock implements ProductRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

ProductModel _product({
  required String id,
  required List<String> notes,
  List<String> tags = const <String>[],
  int stock = 5,
  double price = 1000,
  double? salePrice,
  int createdAtMs = 100,
  bool isActive = true,
}) {
  final ts = Timestamp.fromMillisecondsSinceEpoch(createdAtMs);
  return ProductModel(
    id: id,
    name: id,
    nameLower: id,
    searchPrefixes: buildSearchPrefixes(id),
    brand: 'Brand',
    price: price,
    salePrice: salePrice,
    size: '100 ml',
    stock: stock,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: ts,
    updatedAt: ts,
    isActive: isActive,
    occasion: 'daily',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: tags,
  );
}

void main() {
  late MockProductRepo productRepo;
  late MockUserTasteRepo userTasteRepo;

  setUp(() {
    productRepo = MockProductRepo();
    userTasteRepo = MockUserTasteRepo();
  });

  blocTest<RecommendedProductsCubit, RecommendedProductsState>(
    'filters inactive products out of recommendations',
    build: () {
      when(
        () => userTasteRepo.getTopNotes(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const <String>[]);
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product(id: 'active', notes: const ['amber'], createdAtMs: 300),
          _product(
            id: 'inactive',
            notes: const ['oud'],
            createdAtMs: 200,
            isActive: false,
          ),
        ],
      );
      return RecommendedProductsCubit(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
      );
    },
    act: (cubit) => cubit.load(limit: 3),
    verify: (cubit) {
      final state = cubit.state;
      expect(state.status, RecommendedProductsStatus.success);
      expect(state.products.map((p) => p.id).toList(), const ['active']);
    },
  );

  blocTest<RecommendedProductsCubit, RecommendedProductsState>(
    'uses fallback source on cold start when no top notes exist',
    build: () {
      when(
        () => userTasteRepo.getTopNotes(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const <String>[]);
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product(id: 'p_new', notes: const ['amber'], createdAtMs: 300),
          _product(
            id: 'p_sale',
            notes: const ['oud'],
            salePrice: 900,
            createdAtMs: 200,
          ),
        ],
      );
      return RecommendedProductsCubit(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
      );
    },
    act: (cubit) => cubit.load(limit: 2),
    expect: () => <dynamic>[
      isA<RecommendedProductsState>().having(
        (s) => s.status,
        'status',
        RecommendedProductsStatus.loading,
      ),
      isA<RecommendedProductsState>()
          .having((s) => s.status, 'status', RecommendedProductsStatus.success)
          .having((s) => s.source, 'source', RecommendationSource.fallback)
          .having((s) => s.products.length, 'products.length', 2),
    ],
  );

  blocTest<RecommendedProductsCubit, RecommendedProductsState>(
    'builds behavioral results and excludes current product',
    build: () {
      when(
        () => userTasteRepo.getTopNotes(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const ['citrus', 'fresh']);
      when(
        () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const UserTasteProfile(
          noteScores: <String, double>{'citrus': 8, 'fresh': 4},
        ),
      );
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product(
            id: 'excluded',
            notes: const ['citrus'],
            tags: const ['fresh'],
            createdAtMs: 300,
          ),
          _product(
            id: 'sale_first',
            notes: const ['citrus', 'fresh'],
            salePrice: 800,
            createdAtMs: 200,
          ),
          _product(id: 'regular', notes: const ['citrus'], createdAtMs: 400),
          _product(
            id: 'out_stock',
            notes: const ['citrus', 'fresh'],
            stock: 0,
            salePrice: 700,
            createdAtMs: 500,
          ),
        ],
      );
      return RecommendedProductsCubit(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
      );
    },
    act: (cubit) => cubit.load(excludeProductId: 'excluded', limit: 3),
    verify: (cubit) {
      final state = cubit.state;
      expect(state.status, RecommendedProductsStatus.success);
      expect(state.source, RecommendationSource.behavioral);
      expect(state.products.map((p) => p.id).toList(), const [
        'sale_first',
        'regular',
        'out_stock',
      ]);
    },
  );

  blocTest<RecommendedProductsCubit, RecommendedProductsState>(
    'falls back to generic products when behavioral matching is empty',
    build: () {
      when(
        () => userTasteRepo.getTopNotes(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const ['citrus']);
      when(
        () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async =>
            const UserTasteProfile(noteScores: <String, double>{'citrus': 8}),
      );
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product(id: 'excluded', notes: const ['amber'], createdAtMs: 500),
          _product(
            id: 'p_sale',
            notes: const ['oud'],
            salePrice: 700,
            createdAtMs: 300,
          ),
          _product(id: 'p_regular', notes: const ['musk'], createdAtMs: 400),
        ],
      );
      return RecommendedProductsCubit(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
      );
    },
    act: (cubit) => cubit.load(excludeProductId: 'excluded', limit: 2),
    verify: (cubit) {
      final state = cubit.state;
      expect(state.status, RecommendedProductsStatus.success);
      expect(state.source, RecommendationSource.fallback);
      expect(state.products.map((p) => p.id).toList(), const [
        'p_sale',
        'p_regular',
      ]);
    },
  );

  blocTest<RecommendedProductsCubit, RecommendedProductsState>(
    'emits empty fallback when both behavioral and fallback are empty',
    build: () {
      when(
        () => userTasteRepo.getTopNotes(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const ['citrus']);
      when(
        () => userTasteRepo.getTasteProfile(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async =>
            const UserTasteProfile(noteScores: <String, double>{'citrus': 8}),
      );
      when(() => productRepo.fetchAICatalog()).thenAnswer(
        (_) async => <ProductModel>[
          _product(id: 'excluded', notes: const ['amber'], createdAtMs: 500),
        ],
      );
      return RecommendedProductsCubit(
        productRepo: productRepo,
        userTasteRepo: userTasteRepo,
      );
    },
    act: (cubit) => cubit.load(excludeProductId: 'excluded', limit: 2),
    verify: (cubit) {
      final state = cubit.state;
      expect(state.status, RecommendedProductsStatus.empty);
      expect(state.source, RecommendationSource.fallback);
      expect(state.products, isEmpty);
    },
  );
}
