class CategoryModel {
  final String id;
  final String name;
  final String categoryName;
  final String imageUrl;
  final int sortOrder;
  final String query; // slug/filterValue

  const CategoryModel({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.imageUrl,
    required this.sortOrder,
    required this.query,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    final name = map['name'] ?? '';
    return CategoryModel(
      id: id,
      name: name,
      categoryName: map['categoryName'] ?? map['catName'] ?? name,
      imageUrl: map['imageUrl'] ?? '',
      sortOrder: map['sortOrder'] ?? 0,
      query: map['query'] ?? map['slug'] ?? '',
    );
  }

  String get displayName {
    final normalizedCategoryName = categoryName.trim();
    if (normalizedCategoryName.isNotEmpty) return normalizedCategoryName;
    return name.trim();
  }

  String get filterValue {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) return normalizedQuery;
    return displayName;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryName': categoryName,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'query': query,
    };
  }
}
