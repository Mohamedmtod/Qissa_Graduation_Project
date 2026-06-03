import 'package:equatable/equatable.dart';
import '../../data/models/shipping_zone_model.dart';

abstract class AdminShippingZonesState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminShippingZonesInitial extends AdminShippingZonesState {}

class AdminShippingZonesLoading extends AdminShippingZonesState {}

class AdminShippingZonesLoaded extends AdminShippingZonesState {
  final List<ShippingZoneModel> zones;
  final bool isSaving;

  AdminShippingZonesLoaded({
    required this.zones,
    this.isSaving = false,
  });

  @override
  List<Object?> get props => [zones, isSaving];

  AdminShippingZonesLoaded copyWith({
    List<ShippingZoneModel>? zones,
    bool? isSaving,
  }) {
    return AdminShippingZonesLoaded(
      zones: zones ?? this.zones,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AdminShippingZonesError extends AdminShippingZonesState {
  final String message;

  AdminShippingZonesError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminShippingZonesSuccess extends AdminShippingZonesState {
  final String message;

  AdminShippingZonesSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
