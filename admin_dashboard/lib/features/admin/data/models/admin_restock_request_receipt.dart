import 'package:equatable/equatable.dart';

class AdminRestockRequestReceipt extends Equatable {
  const AdminRestockRequestReceipt({
    required this.itemName,
    required this.requestedUnits,
    required this.queuedAt,
    required this.message,
  });

  final String itemName;
  final int requestedUnits;
  final DateTime queuedAt;
  final String message;

  @override
  List<Object?> get props => [itemName, requestedUnits, queuedAt, message];
}
