import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_facet_index.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product({
  required String id,
  required String name,
  String brand = 'Brand',
  double price = 1000,
  int stock = 5,
  bool isActive = true,
  String gender = 'unisex',
  String season = 'all_seasons',
  String family = 'fresh',
  List<String> notes = const <String>[],
  List<String> topNotes = const <String>[],
  List<String> middleNotes = const <String>[],
  List<String> baseNotes = const <String>[],
  List<String> tags = const <String>[],
  String description = '',
  String occasion = 'daily',
  String time = 'all_day',
  String intensity = 'medium',
  Map<String, int> staffTagScores = const <String, int>{},
  List<String> staffWarnings = const <String>[],
  List<String> similarFamousDna = const <String>[],
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const <String>[],
    brand: brand,
    price: price,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: description,
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
    staffTagScores: staffTagScores,
    staffWarnings: staffWarnings,
    similarFamousDna: similarFamousDna,
  );
}

void main() {
  group('CatalogFacetIndex', () {
    test('indexes notes from notes and pyramid layers', () {
      final strawberry = _product(
        id: 'strawberry',
        name: 'Berry Musk',
        notes: const ['strawberry'],
        topNotes: const ['pear'],
        middleNotes: const ['jasmine'],
        baseNotes: const ['musk'],
      );
      final index = CatalogFacetIndex.build([strawberry]);

      expect(index.find('strawberry').map((m) => m.productId), ['strawberry']);
      expect(index.find('pear').map((m) => m.productId), ['strawberry']);
      expect(index.find('musk').map((m) => m.productId), ['strawberry']);
    });

    test('matches Arabic strawberry alias only when catalog facet exists', () {
      final strawberry = _product(
        id: 'strawberry',
        name: 'Berry Musk',
        notes: const ['strawberry'],
      );
      final citrus = _product(
        id: 'citrus',
        name: 'Citrus Musk',
        notes: const ['citrus'],
      );
      final index = CatalogFacetIndex.build([strawberry, citrus]);

      expect(
        index
            .find('\u0641\u0631\u0627\u0648\u0644\u0629')
            .map((m) => m.productId),
        ['strawberry'],
      );

      final noStrawberryIndex = CatalogFacetIndex.build([citrus]);
      expect(
        noStrawberryIndex.find('\u0641\u0631\u0627\u0648\u0644\u0629'),
        isEmpty,
      );
    });

    test('indexes tags family and description', () {
      final product = _product(
        id: 'p1',
        name: 'Powder Leather',
        family: 'leather',
        tags: const ['powdery', 'classic'],
        description: 'Soft tropical fruit opening.',
      );
      final index = CatalogFacetIndex.build([product]);

      expect(
        index.find('powdery').single.fields,
        contains(CatalogFacetField.tags),
      );
      expect(
        index.find('leather').single.fields,
        contains(CatalogFacetField.family),
      );
      expect(
        index.find('tropical').single.fields,
        contains(CatalogFacetField.description),
      );
    });

    test('normalizes common Arabic scent aliases', () {
      final product = _product(
        id: 'p1',
        name: 'Marine Leather',
        family: 'aquatic',
        tags: const ['leather'],
      );
      final index = CatalogFacetIndex.build([product]);

      expect(index.find('\u0645\u0627\u0626\u064a').map((m) => m.productId), [
        'p1',
      ]);
      expect(index.find('\u062c\u0644\u062f\u064a').map((m) => m.productId), [
        'p1',
      ]);
    });

    test('indexes staff taste facets separately from normal tags', () {
      final product = _product(
        id: 'staffed',
        name: 'Office Soft',
        tags: const ['fresh'],
        staffTagScores: const {'office': 3, 'elegant': 3, 'not_cloying': 2},
        staffWarnings: const ['too_sweet_for_some'],
        similarFamousDna: const ['sauvage_like'],
      );
      final index = CatalogFacetIndex.build([product]);

      expect(
        index.find('مش خانق').single.fields,
        contains(CatalogFacetField.staffTags),
      );
      expect(
        index.find('شيك').single.fields,
        contains(CatalogFacetField.staffTags),
      );
      expect(
        index.find('sauvage').single.fields,
        contains(CatalogFacetField.staffDna),
      );
      expect(
        index.find('too_sweet_for_some').single.fields,
        contains(CatalogFacetField.staffWarnings),
      );
    });
  });
}
