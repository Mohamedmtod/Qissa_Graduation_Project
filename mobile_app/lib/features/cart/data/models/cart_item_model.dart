class CartItemModel {
  static const defaultVariantId = 'default';

  final String productId;
  final String variantId;
  final String variantLabel;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;
  final String brand; // Optional but good for display
  final List<String> notes;
  final String? source;

  CartItemModel({
    required this.productId,
    this.variantId = defaultVariantId,
    this.variantLabel = '',
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    required this.brand,
    this.notes = const [],
    this.source,
  });

  String get cartDocumentId =>
      variantId == defaultVariantId ? productId : '${productId}_$variantId';

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    final variantId = (map['variantId'] ?? defaultVariantId).toString().trim();
    return CartItemModel(
      productId: map['productId'] ?? '',
      variantId: variantId.isEmpty ? defaultVariantId : variantId,
      variantLabel:
          (map['variantLabel'] ?? map['size'])?.toString().trim() ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      quantity: map['quantity'] ?? 1,
      brand: map['brand'] ?? '',
      notes: (map['notes'] is Iterable)
          ? (map['notes'] as Iterable)
                .map((e) => e?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      if (variantLabel.trim().isNotEmpty) 'variantLabel': variantLabel,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'brand': brand,
      'notes': notes,
      'source': source,
    };
  }

  CartItemModel copyWith({
    String? productId,
    String? variantId,
    String? variantLabel,
    String? name,
    double? price,
    String? imageUrl,
    int? quantity,
    String? brand,
    List<String>? notes,
    String? source,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      variantLabel: variantLabel ?? this.variantLabel,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      brand: brand ?? this.brand,
      notes: notes ?? this.notes,
      source: source ?? this.source,
    );
  }
}
