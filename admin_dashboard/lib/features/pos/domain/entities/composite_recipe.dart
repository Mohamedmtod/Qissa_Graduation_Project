class RecipeComponent {
  final String id;
  final String productId; // ID of the raw material / packaging product
  final String name;
  final String nameAr;
  final double quantity; // quantity needed (e.g. 50ml, 1 piece)
  final String type; // 'fixed' | 'oil' | 'selectable'
  final double priceDelta; // for selectable packaging options, if any

  RecipeComponent({
    required this.id,
    required this.productId,
    required this.name,
    required this.nameAr,
    required this.quantity,
    required this.type,
    this.priceDelta = 0.0,
  });

  factory RecipeComponent.fromJson(Map<String, dynamic> json) {
    return RecipeComponent(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['nameAr'] as String? ?? '',
      quantity: (json['quantity'] as num? ?? 0.0).toDouble(),
      type: json['type'] as String? ?? 'fixed',
      priceDelta: (json['priceDelta'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'nameAr': nameAr,
      'quantity': quantity,
      'type': type,
      'priceDelta': priceDelta,
    };
  }
}

class CompositeRecipe {
  final String id;
  final String productId; // target composite product ID
  final String name;
  final String nameAr;
  final int recipeVersion;
  final bool isActive;
  final List<RecipeComponent> components;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CompositeRecipe({
    required this.id,
    required this.productId,
    required this.name,
    required this.nameAr,
    required this.recipeVersion,
    required this.isActive,
    required this.components,
    this.createdAt,
    this.updatedAt,
  });

  factory CompositeRecipe.fromJson(Map<String, dynamic> json) {
    return CompositeRecipe(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['nameAr'] as String? ?? '',
      recipeVersion: json['recipeVersion'] as int? ?? 1,
      isActive: json['isActive'] as bool? ?? true,
      components: (json['components'] as List?)
              ?.map((e) => RecipeComponent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'nameAr': nameAr,
      'recipeVersion': recipeVersion,
      'isActive': isActive,
      'components': components.map((e) => e.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
