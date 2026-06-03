import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/products/presentation/manager/search_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/search_state.dart';

class MockProductRepo extends Mock implements ProductRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockRecentlyViewedRepo extends Mock implements RecentlyViewedRepo {}

void main() {
  late SearchCubit searchCubit;
  late MockProductRepo mockProductRepo;
  late MockEventRepo mockEventRepo;
  late MockRecentlyViewedRepo mockRecentlyViewedRepo;

  ProductModel createProduct(String id) => ProductModel(
    id: id,
    name: 'Product $id',
    nameLower: 'product $id',
    searchPrefixes: const [],
    brand: 'Brand',
    price: 100,
    stock: 10,
    gender: 'unisex',
    season: 'all',
    fragranceFamily: 'floral',
    notes: const [],
    imageUrls: const [],
    description: '',
    categoryName: 'cat',
    createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
    updatedAt: Timestamp.fromMillisecondsSinceEpoch(0),
    occasion: '',
    time: '',
    intensity: '',
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const [],
  );

  setUp(() {
    mockProductRepo = MockProductRepo();
    mockEventRepo = MockEventRepo();
    mockRecentlyViewedRepo = MockRecentlyViewedRepo();
    searchCubit = SearchCubit(
      mockProductRepo,
      mockEventRepo,
      mockRecentlyViewedRepo,
    );

    registerFallbackValue(createProduct('any'));
  });

  tearDown(() {
    searchCubit.close();
  });

  group('SearchCubit.search', () {
    blocTest<SearchCubit, SearchState>(
      'emits SearchInitial if query is too short',
      build: () => searchCubit,
      act: (cubit) => cubit.search('a'),
      expect: () => [SearchInitial()],
    );

    blocTest<SearchCubit, SearchState>(
      'emits [SearchLoading, SearchSuccess] on successful first page',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('1'), createProduct('2')],
            lastDocument: Object(),
          ),
        );
      },
      act: (cubit) => cubit.search('perfume'),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 2),
      ],
      verify: (_) {
        verify(
          () => mockProductRepo.searchByPrefix(
            query: 'perfume',
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).called(1);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'uses repository hasMore even when result count is below page size',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('1')],
            lastDocument: Object(),
            hasMore: true,
          ),
        );
      },
      act: (cubit) => cubit.search('perfume'),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>()
            .having((s) => s.products.length, 'length', 1)
            .having((s) => s.hasMore, 'hasMore', isTrue),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'emits [SearchLoading, SearchError] on failure',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: any(named: 'startAfterDocument'),
          ),
        ).thenThrow(Exception('Search failed'));
      },
      act: (cubit) => cubit.search('perfume'),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchError>().having(
          (s) => s.message,
          'message',
          contains('Search failed'),
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'falls back to local catalog when Firestore search fails',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: any(named: 'startAfterDocument'),
          ),
        ).thenThrow(Exception('No internet'));
        when(
          () => mockProductRepo.searchLocally(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenReturn(ProductQueryResult(products: [createProduct('cached')]));
      },
      act: (cubit) => cubit.search('perfume'),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>()
            .having((s) => s.products.single.id, 'cached id', 'cached')
            .having((s) => s.isOfflineFallback, 'offline fallback', isTrue)
            .having((s) => s.hasMore, 'hasMore', isFalse),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'emits [SearchLoading, SearchSuccess] with empty list when no results found',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(products: [], lastDocument: null),
        );
      },
      act: (cubit) => cubit.search('nonexistent'),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.products, 'products', isEmpty),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'handles Arabic query correctly',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('1')],
            lastDocument: Object(),
          ),
        );
      },
      act: (cubit) => cubit.search('عطر'),
      expect: () => [isA<SearchLoading>(), isA<SearchSuccess>()],
      verify: (_) {
        verify(
          () => mockProductRepo.searchByPrefix(
            query: 'عطر',
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).called(1);
      },
    );
  });

  group('SearchCubit.loadMore', () {
    late Object lastDoc;

    setUp(() {
      lastDoc = Object();
    });

    blocTest<SearchCubit, SearchState>(
      'LoadMore (Search Mode): appends products and deduplicates',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: List.generate(20, (i) => createProduct('$i')),
            lastDocument: lastDoc,
            hasMore: true,
          ),
        );

        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('20'), createProduct('1')],
            lastDocument: Object(),
            hasMore: false,
          ),
        );
      },
      act: (cubit) async {
        await cubit.search('perfume');
        await cubit.loadMore();
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 20),
        isA<SearchLoadingMore>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 21),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'LoadMore (Filter Mode): calls filterProducts branch',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.filterProducts(
            query: any(named: 'query'),
            gender: any(named: 'gender'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: List.generate(20, (i) => createProduct('$i')),
            lastDocument: lastDoc,
            hasMore: true,
          ),
        );

        when(
          () => mockProductRepo.filterProducts(
            query: any(named: 'query'),
            gender: any(named: 'gender'),
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('20')],
            lastDocument: Object(),
            hasMore: false,
          ),
        );
      },
      act: (cubit) async {
        await cubit.filter(query: 'p', gender: 'male');
        await cubit.loadMore();
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 20),
        isA<SearchLoadingMore>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 21),
      ],
      verify: (_) {
        verify(
          () => mockProductRepo.filterProducts(
            query: any(named: 'query'),
            gender: 'male',
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).called(1);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'LoadMore (Category Mode): calls filterByCategory branch',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.filterByCategory(
            categoryName: any(named: 'categoryName'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: List.generate(20, (i) => createProduct('$i')),
            lastDocument: lastDoc,
            hasMore: true,
          ),
        );

        when(
          () => mockProductRepo.filterByCategory(
            categoryName: any(named: 'categoryName'),
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('20')],
            lastDocument: Object(),
            hasMore: false,
          ),
        );
      },
      act: (cubit) async {
        await cubit.searchByCategory('floral');
        await cubit.loadMore();
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 20),
        isA<SearchLoadingMore>(),
        isA<SearchSuccess>().having((s) => s.products.length, 'length', 21),
      ],
      verify: (_) {
        verify(
          () => mockProductRepo.filterByCategory(
            categoryName: 'floral',
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).called(1);
      },
    );

    test(
      'LoadMore Concurrency: late pagination during new search is ignored',
      () async {
        when(
          () => mockProductRepo.searchByPrefix(
            query: 's1',
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: [createProduct('1')],
            lastDocument: lastDoc,
            hasMore: true,
          ),
        );

        // Slow pagination for s1
        when(
          () => mockProductRepo.searchByPrefix(
            query: 's1',
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 5));
          return ProductQueryResult(products: [createProduct('2')]);
        });

        // Quick search for s2
        when(
          () => mockProductRepo.searchByPrefix(
            query: 's2',
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(products: [createProduct('3')]),
        );

        final states = <SearchState>[];
        searchCubit.stream.listen(states.add);

        await searchCubit.search('s1');
        searchCubit.loadMore(); // Start slow loadMore
        await Future.delayed(const Duration(milliseconds: 1));
        await searchCubit.search('s2'); // New search increments opId

        await Future.delayed(const Duration(milliseconds: 10));

        // Final state should be Success for s2 (product 3), not s1 pagination (product 1,2)
        expect(states.last, isA<SearchSuccess>());
        final finalProducts = (states.last as SearchSuccess).products;
        expect(finalProducts.length, 1);
        expect(finalProducts.first.id, '3');
      },
    );

    blocTest<SearchCubit, SearchState>(
      'stops loading when hasMore is false',
      build: () => searchCubit,
      seed: () => SearchSuccess([createProduct('1')], hasMore: false),
      act: (cubit) => cubit.loadMore(),
      expect: () => [],
      verify: (_) {
        verifyNever(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: any(named: 'startAfterDocument'),
          ),
        );
      },
    );

    blocTest<SearchCubit, SearchState>(
      'sets hasMore false when pagination fails to avoid retry loop',
      build: () => searchCubit,
      setUp: () {
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: null,
          ),
        ).thenAnswer(
          (_) async => ProductQueryResult(
            products: List.generate(20, (i) => createProduct('$i')),
            lastDocument: lastDoc,
            hasMore: true,
          ),
        );
        when(
          () => mockProductRepo.searchByPrefix(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            startAfterDocument: lastDoc,
          ),
        ).thenThrow(Exception('network'));
      },
      act: (cubit) async {
        await cubit.search('perfume');
        await cubit.loadMore();
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.hasMore, 'initial hasMore', true),
        isA<SearchLoadingMore>(),
        isA<SearchSuccess>().having((s) => s.hasMore, 'final hasMore', false),
      ],
    );
  });

  group('SearchCubit.logSearch', () {
    test('calls eventRepo if query not empty', () {
      when(() => mockEventRepo.logSearch(any())).thenAnswer((_) async => {});
      searchCubit.logSearch('test');
      verify(() => mockEventRepo.logSearch('test')).called(1);
    });

    test('does nothing if query empty', () {
      searchCubit.logSearch(' ');
      verifyNever(() => mockEventRepo.logSearch(any()));
    });
  });

  group('SearchCubit.reset', () {
    blocTest<SearchCubit, SearchState>(
      'emits SearchInitial and cancels pending searches (via opId increment)',
      build: () => searchCubit,
      seed: () => SearchSuccess([createProduct('1')], hasMore: true),
      act: (cubit) => cubit.reset(),
      expect: () => [SearchInitial()],
    );
  });
}
