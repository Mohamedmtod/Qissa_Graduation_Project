
class WishlistItemModel {
  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  final String brand;

  WishlistItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.brand,
  });

  factory WishlistItemModel.fromMap(Map<String, dynamic> map) {
    return WishlistItemModel(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      brand: map['brand'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'brand': brand,
    };
  }
}
