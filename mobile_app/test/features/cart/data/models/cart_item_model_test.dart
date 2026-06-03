import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';

void main() {
  test('fromMap handles old items without notes safely', () {
    final item = CartItemModel.fromMap({
      'productId': 'p1',
      'name': 'Perfume',
      'price': 1000,
      'imageUrl': 'img',
      'quantity': 1,
      'brand': 'Brand',
    });

    expect(item.notes, isEmpty);
  });

  test('serializes and deserializes notes correctly', () {
    final original = CartItemModel(
      productId: 'p2',
      name: 'Perfume 2',
      price: 1500,
      imageUrl: 'img2',
      quantity: 2,
      brand: 'Brand 2',
      notes: const ['citrus', 'musk'],
    );

    final map = original.toMap();
    final restored = CartItemModel.fromMap(map);

    expect(restored.notes, const ['citrus', 'musk']);
  });
}
