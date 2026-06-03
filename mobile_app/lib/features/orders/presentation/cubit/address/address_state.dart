part of 'address_cubit.dart';

enum AddressStatus { initial, loading, loaded, success, error }

class AddressState {
  final List<AddressModel> addresses;
  final AddressModel? defaultAddress;
  final AddressModel? selectedAddress;
  final AddressStatus status;
  final String? message;

  AddressState({
    this.addresses = const [],
    this.defaultAddress,
    this.selectedAddress,
    this.status = AddressStatus.initial,
    this.message,
  });

  AddressState copyWith({
    List<AddressModel>? addresses,
    AddressModel? defaultAddress,
    AddressModel? selectedAddress,
    AddressStatus? status,
    String? message,
  }) {
    return AddressState(
      addresses: addresses ?? this.addresses,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}
