import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:perfume_app/features/orders/data/repos/address_repo.dart';

part 'address_state.dart';

class AddressCubit extends Cubit<AddressState> {
  final AddressRepo _addressRepo;

  AddressCubit({AddressRepo? addressRepo})
      : _addressRepo = addressRepo ?? AddressRepo.instance,
        super(AddressState());

  StreamSubscription<List<AddressModel>>? _addressesSubscription;

  void loadAddresses() {
    emit(state.copyWith(status: AddressStatus.loading));
    _addressesSubscription?.cancel();
    _addressesSubscription = _addressRepo.streamAddressesInstance().listen(
      (addresses) {
        // Automatically find and sync the default address
        AddressModel? defaultAddr;
        try {
          defaultAddr = addresses.firstWhere((a) => a.defaultAddress);
        } catch (_) {
          defaultAddr = null;
        }

        emit(state.copyWith(
          addresses: addresses,
          defaultAddress: defaultAddr,
          status: AddressStatus.loaded,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          status: AddressStatus.error,
          message: error.toString(),
        ));
      },
    );
  }

  Future<void> addAddress(AddressModel address) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      await _addressRepo.addAddressInstance(address);
      emit(state.copyWith(
        status: AddressStatus.success,
        message: 'Address added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AddressStatus.error,
        message: e.toString(),
      ));
    }
  }

  Future<void> updateAddress(AddressModel address) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      await _addressRepo.updateAddressInstance(address);
      emit(state.copyWith(
        status: AddressStatus.success,
        message: 'Address updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AddressStatus.error,
        message: e.toString(),
      ));
    }
  }

  Future<void> deleteAddress(String addressId) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      // Use the new atomic fallback method
      await _addressRepo.deleteAddressWithDefaultFallback(addressId);
      emit(state.copyWith(
        status: AddressStatus.success,
        message: 'Address deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AddressStatus.error,
        message: e.toString(),
      ));
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    emit(state.copyWith(status: AddressStatus.loading));
    try {
      await _addressRepo.setDefaultAddressInstance(addressId);
      emit(state.copyWith(
        status: AddressStatus.success,
        message: 'Default address updated',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AddressStatus.error,
        message: e.toString(),
      ));
    }
  }

  Future<void> loadDefaultAddress() async {
    try {
      final address = await _addressRepo.getDefaultAddressInstance();
      emit(state.copyWith(defaultAddress: address));
    } catch (e) {
      emit(state.copyWith(
        status: AddressStatus.error,
        message: e.toString(),
      ));
    }
  }

  void setSelectedAddress(AddressModel? address) {
    emit(state.copyWith(selectedAddress: address));
  }

  void clearStatus() {
    emit(state.copyWith(status: AddressStatus.initial, message: null));
  }

  @override
  Future<void> close() {
    _addressesSubscription?.cancel();
    return super.close();
  }
}
