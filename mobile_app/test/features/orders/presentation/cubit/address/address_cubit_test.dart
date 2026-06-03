import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:perfume_app/features/orders/data/repos/address_repo.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';

class MockAddressRepo extends Mock implements AddressRepo {}

void main() {
  late AddressCubit addressCubit;
  late MockAddressRepo mockAddressRepo;
  late StreamController<List<AddressModel>> addressesController;

  final address1 = AddressModel(
    id: '1',
    type: AddressType.address,
    fullName: 'User 1',
    phone: '123',
    defaultAddress: true,
    createdAt: DateTime(2023, 1, 1),
  );

  final address2 = AddressModel(
    id: '2',
    type: AddressType.address,
    fullName: 'User 2',
    phone: '456',
    defaultAddress: false,
    createdAt: DateTime(2023, 1, 2),
  );

  setUp(() {
    mockAddressRepo = MockAddressRepo();
    addressesController = StreamController<List<AddressModel>>.broadcast();
    
    when(() => mockAddressRepo.streamAddressesInstance())
        .thenAnswer((_) => addressesController.stream);
        
    addressCubit = AddressCubit(addressRepo: mockAddressRepo);
  });

  tearDown(() {
    addressesController.close();
    addressCubit.close();
  });

  group('AddressCubit Initial State', () {
    test('initial state is correct', () {
      expect(addressCubit.state.status, AddressStatus.initial);
      expect(addressCubit.state.addresses, isEmpty);
      expect(addressCubit.state.defaultAddress, isNull);
    });
  });

  group('AddressCubit loadAddresses', () {
    blocTest<AddressCubit, AddressState>(
      'starts listening and updates state when repo emits',
      build: () => addressCubit,
      act: (cubit) {
        cubit.loadAddresses();
        addressesController.add([address1, address2]);
      },
      expect: () => [
        isA<AddressState>().having((s) => s.status, 'status', AddressStatus.loading),
        isA<AddressState>()
            .having((s) => s.status, 'status', AddressStatus.loaded)
            .having((s) => s.addresses, 'addresses', [address1, address2])
            .having((s) => s.defaultAddress?.id, 'defaultAddressId', '1'),
      ],
    );
  });

  group('AddressCubit setDefaultAddress', () {
    blocTest<AddressCubit, AddressState>(
      'calls repo.setDefaultAddressInstance and emits success',
      build: () => addressCubit,
      setUp: () {
        when(() => mockAddressRepo.setDefaultAddressInstance(any()))
            .thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.setDefaultAddress('2'),
      expect: () => [
        isA<AddressState>().having((s) => s.status, 'status', AddressStatus.loading),
        isA<AddressState>()
            .having((s) => s.status, 'status', AddressStatus.success)
            .having((s) => s.message, 'message', 'Default address updated'),
      ],
      verify: (_) {
        verify(() => mockAddressRepo.setDefaultAddressInstance('2')).called(1);
      },
    );
  });

  group('AddressCubit deleteAddress (with fallback verified via Repo calls)', () {
    blocTest<AddressCubit, AddressState>(
      'calls repo.deleteAddressWithDefaultFallback and emits success',
      build: () => addressCubit,
      setUp: () {
        when(() => mockAddressRepo.deleteAddressWithDefaultFallback(any()))
            .thenAnswer((_) async => {});
      },
      act: (cubit) => cubit.deleteAddress('1'),
      expect: () => [
        isA<AddressState>().having((s) => s.status, 'status', AddressStatus.loading),
        isA<AddressState>()
            .having((s) => s.status, 'status', AddressStatus.success)
            .having((s) => s.message, 'message', 'Address deleted successfully'),
      ],
      verify: (_) {
        verify(() => mockAddressRepo.deleteAddressWithDefaultFallback('1')).called(1);
      },
    );

    blocTest<AddressCubit, AddressState>(
      'verify state updates correctly when repo fallback happens (mocked stream)',
      build: () => addressCubit,
      setUp: () {
        when(() => mockAddressRepo.deleteAddressWithDefaultFallback(any()))
            .thenAnswer((_) async {
          // Simulate repo fallback promotion by emitting new state through stream
          final address2Promoted = AddressModel(
            id: '2',
            type: address2.type,
            fullName: address2.fullName,
            phone: address2.phone,
            defaultAddress: true,
            createdAt: address2.createdAt,
          );
          addressesController.add([address2Promoted]);
        });
      },
      act: (cubit) async {
        cubit.loadAddresses();
        await cubit.deleteAddress('1');
      },
      expect: () => [
        // loading from loadAddresses
        isA<AddressState>().having((s) => s.status, 'status', AddressStatus.loading),
        // loading from deleteAddress
        isA<AddressState>().having((s) => s.status, 'status', AddressStatus.loading),
        // loaded from stream listener
        isA<AddressState>()
            .having((s) => s.status, 'status', AddressStatus.loaded)
            .having((s) => s.defaultAddress?.id, 'newDefaultId', '2'),
        // success from deleteAddress completion
        isA<AddressState>()
            .having((s) => s.status, 'status', AddressStatus.success)
            .having((s) => s.message, 'message', 'Address deleted successfully'),
      ],
    );
  });
}
