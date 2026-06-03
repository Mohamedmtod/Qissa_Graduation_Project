class OrderItemModel {
  static const defaultVariantId = 'default';

  final String productId;
  final String variantId;
  final String variantLabel;
  final String name;
  final double priceSnapshot;
  final int quantity;

  OrderItemModel({
    required this.productId,
    this.variantId = defaultVariantId,
    this.variantLabel = '',
    required this.name,
    required this.priceSnapshot,
    required this.quantity,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final variantId = (map['variantId'] ?? defaultVariantId).toString().trim();
    return OrderItemModel(
      productId: map['productId'] ?? '',
      variantId: variantId.isEmpty ? defaultVariantId : variantId,
      variantLabel:
          (map['variantLabel'] ?? map['size'])?.toString().trim() ?? '',
      name: map['name'] ?? '',
      priceSnapshot: (map['priceSnapshot'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      if (variantLabel.trim().isNotEmpty) 'variantLabel': variantLabel,
      'name': name,
      'priceSnapshot': priceSnapshot,
      'quantity': quantity,
    };
  }
}
