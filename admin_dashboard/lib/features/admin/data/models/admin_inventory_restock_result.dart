import 'package:equatable/equatable.dart';

class AdminInventoryRestockResult extends Equatable {
  const AdminInventoryRestockResult({
    required this.productId,
    required this.stock,
    required this.delta,
    required this.notifiedCount,
    required this.traceId,
  });

  factory AdminInventoryRestockResult.fromJson(Map<String, dynamic> json) {
    return AdminInventoryRestockResult(
      productId: json['productId']?.toString() ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      notifiedCount: (json['notifiedCount'] as num?)?.toInt() ?? 0,
      traceId: json['traceId']?.toString() ?? '',
    );
  }

  final String productId;
  final int stock;
  final int delta;
  final int notifiedCount;
  final String traceId;

  @override
  List<Object?> get props => [productId, stock, delta, notifiedCount, traceId];
}
