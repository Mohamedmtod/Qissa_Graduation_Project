import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/add_to_cart_cubit.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

class MockCartRepo extends Mock implements CartRepo {}

class MockEventRepo extends Mock implements EventRepo {}

class MockUserTasteRepo extends Mock implements UserTasteRepo {}

void main() {
  late MockCartRepo cartRepo;
  late MockEventRepo eventRepo;
  late MockUserTasteRepo tasteRepo;
  late AddToCartCubit cubit;

  final item = CartItemModel(
    productId: 'p1',
    name: 'Perfume',
    price: 1000,
    imageUrl: 'img',
    quantity: 1,
    brand: 'Brand',
    notes: const ['citrus', 'musk'],
  );

  setUpAll(() {
    registerFallbackValue(EventType.view);
    registerFallbackValue(
      CartItemModel(
        productId: 'fallback',
        name: 'fallback',
        price: 0,
        imageUrl: '',
        quantity: 1,
        brand: 'fallback',
      ),
    );
  });

  setUp(() {
    cartRepo = MockCartRepo();
    eventRepo = MockEventRepo();
    tasteRepo = MockUserTasteRepo();
    cubit = AddToCartCubit(
      cartRepo: cartRepo,
      eventRepo: eventRepo,
      userTasteRepo: tasteRepo,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  blocTest<AddToCartCubit, AddToCartState>(
    'tracks addToCart only after successful add',
    build: () {
      when(() => cartRepo.addToCart(any(), any(), maxStock: any(named: 'maxStock')))
          .thenAnswer((_) async {});
      when(() => eventRepo.logAddToCart(
            productId: any(named: 'productId'),
            name: any(named: 'name'),
            price: any(named: 'price'),
            quantity: any(named: 'quantity'),
          )).thenAnswer((_) async {});
      when(() => tasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
      return cubit;
    },
    act: (cubit) async {
      await cubit.addToCart(uid: 'u1', item: item, currentStock: 5);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [isA<AddToCartLoading>(), isA<AddToCartSuccess>()],
    verify: (_) {
      verify(() => tasteRepo.recordEvent(
            eventType: EventType.addToCart,
            notes: const ['citrus', 'musk'],
            userId: 'u1',
          )).called(1);
    },
  );

  blocTest<AddToCartCubit, AddToCartState>(
    'does not track addToCart when add fails',
    build: () {
      when(() => cartRepo.addToCart(any(), any(), maxStock: any(named: 'maxStock')))
          .thenThrow(Exception('failed'));
      return cubit;
    },
    act: (cubit) => cubit.addToCart(uid: 'u1', item: item, currentStock: 5),
    expect: () => [isA<AddToCartLoading>(), isA<AddToCartError>()],
    verify: (_) {
      verifyNever(() => tasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          ));
    },
  );
}
