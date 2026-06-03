import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/perfume_reference_resolver.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('PerfumeReferenceResolver', () {
    test('resolves exact catalog product before external lookup', () async {
      var externalCalled = false;
      final resolver = PerfumeReferenceResolver(
        lookupExternal:
            ({required query, required responseLanguage, requestId}) async {
              externalCalled = true;
              return const ExternalPerfumeLookupResult.notFound();
            },
      );

      final result = await resolver.resolve(
        query: 'Light Blue',
        catalog: _catalog(),
        language: AIChatLanguage.english,
      );

      expect(result.status, PerfumeReferenceStatus.resolved);
      expect(result.source, PerfumeReferenceSource.catalog);
      expect(result.product?.id, 'light_blue');
      expect(externalCalled, isFalse);
    });

    test(
      'partial catalog reference resolves only when single strong match',
      () async {
        final resolver = const PerfumeReferenceResolver();

        final result = await resolver.resolve(
          query: 'Acqua',
          catalog: _catalog(),
          language: AIChatLanguage.english,
        );

        expect(result.status, PerfumeReferenceStatus.resolved);
        expect(result.product?.id, 'acqua_gio');
      },
    );

    test('brand-only catalog reference asks clarification', () async {
      final resolver = const PerfumeReferenceResolver();

      final result = await resolver.resolve(
        query: 'Dior',
        catalog: [
          ..._catalog(),
          _product(id: 'dior_sauvage', name: 'Sauvage', brand: 'Dior'),
          _product(id: 'dior_homme', name: 'Dior Homme Intense', brand: 'Dior'),
        ],
        language: AIChatLanguage.english,
      );

      expect(result.status, PerfumeReferenceStatus.needsClarification);
      expect(
        result.options.map((item) => item.productId),
        contains('dior_sauvage'),
      );
      expect(
        result.options.map((item) => item.productId),
        contains('dior_homme'),
      );
    });

    test(
      'series external reference with multiple candidates asks clarification',
      () async {
        final resolver = PerfumeReferenceResolver(
          lookupExternal:
              ({required query, required responseLanguage, requestId}) async {
                return const ExternalPerfumeLookupResult.ambiguous([
                  ExternalPerfumeCandidate(
                    id: 'swy_intensely',
                    displayName: 'Stronger With You Intensely',
                    brand: 'Giorgio Armani',
                    sourceUrl: 'https://example.com/intensely.html',
                    score: 0.86,
                  ),
                  ExternalPerfumeCandidate(
                    id: 'swy_absolutely',
                    displayName: 'Stronger With You Absolutely',
                    brand: 'Giorgio Armani',
                    sourceUrl: 'https://example.com/absolutely.html',
                    score: 0.84,
                  ),
                ]);
              },
        );

        final result = await resolver.resolve(
          query: 'Stronger With You',
          catalog: _catalog(),
          language: AIChatLanguage.english,
        );

        expect(result.status, PerfumeReferenceStatus.needsClarification);
        expect(result.options, hasLength(2));
        expect(result.options.first.name, 'Stronger With You Intensely');
      },
    );

    test('exact external profile resolves when confidence is high', () async {
      final resolver = PerfumeReferenceResolver(
        lookupKnowledge: (_) async => _profile(
          id: 'swy_intensely',
          displayName: 'Stronger With You Intensely',
          brand: 'Giorgio Armani',
          aliases: const ['stronger with you intensely'],
          confidence: 0.93,
        ),
      );

      final result = await resolver.resolve(
        query: 'Stronger With You Intensely',
        catalog: _catalog(),
        language: AIChatLanguage.english,
      );

      expect(result.status, PerfumeReferenceStatus.resolved);
      expect(result.source, PerfumeReferenceSource.perfumeKnowledge);
      expect(result.externalProfile?.id, 'swy_intensely');
    });

    test('unknown fake perfume returns not found', () async {
      final resolver = PerfumeReferenceResolver(
        lookupKnowledge: (_) async => null,
        lookupExternal:
            ({required query, required responseLanguage, requestId}) async {
              return const ExternalPerfumeLookupResult.notFound(
                reason: 'profile_not_verified',
              );
            },
      );

      final result = await resolver.resolve(
        query: 'Ocean Dragon Royal',
        catalog: _catalog(),
        language: AIChatLanguage.english,
      );

      expect(result.status, PerfumeReferenceStatus.notFound);
      expect(result.reason, 'reference_not_found');
    });

    test('cache permission failure does not crash', () async {
      final resolver = PerfumeReferenceResolver(
        lookupKnowledge: (_) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        },
      );

      final result = await resolver.resolve(
        query: 'Azzaro Pour Homme',
        catalog: _catalog(),
        language: AIChatLanguage.english,
      );

      expect(result.status, PerfumeReferenceStatus.cacheUnavailable);
      expect(result.cacheStatus, 'cache_unavailable');
    });

    test('selects pending option by number and partial name', () {
      const resolver = PerfumeReferenceResolver();
      const options = [
        PerfumeReferenceOption(
          index: 1,
          name: 'Dior Sauvage',
          brand: 'Dior',
          source: PerfumeReferenceSource.externalLookup,
          externalProfileId: 'dior_sauvage',
        ),
        PerfumeReferenceOption(
          index: 2,
          name: 'Dior Homme Intense',
          brand: 'Dior',
          source: PerfumeReferenceSource.externalLookup,
          externalProfileId: 'dior_homme_intense',
        ),
      ];

      expect(
        resolver.selectOption(userReply: '2', options: options)?.name,
        'Dior Homme Intense',
      );
      expect(
        resolver.selectOption(userReply: 'sauvage', options: options)?.name,
        'Dior Sauvage',
      );
      expect(
        resolver.selectOption(userReply: 'Dior', options: options),
        isNull,
      );
    });
  });
}

List<ProductModel> _catalog() {
  return [
    _product(id: 'light_blue', name: 'Light Blue', brand: 'Dolce & Gabbana'),
    _product(id: 'acqua_gio', name: 'Acqua di Gio', brand: 'Giorgio Armani'),
  ];
}

ProductModel _product({
  required String id,
  required String name,
  required String brand,
}) {
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const [],
    brand: brand,
    price: 3000,
    stock: 10,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh spicy',
    notes: const ['citrus', 'fresh'],
    imageUrls: const ['https://example.com/image.png'],
    description: 'Test product',
    categoryName: 'Perfumes',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    occasion: 'office',
    time: 'day',
    intensity: 'medium',
    topNotes: const ['citrus'],
    middleNotes: const ['fresh'],
    baseNotes: const ['musk'],
    tags: const ['fresh', 'clean'],
  );
}

PerfumeKnowledgeProfile _profile({
  required String id,
  required String displayName,
  required String brand,
  List<String> aliases = const [],
  double confidence = 0.92,
}) {
  return PerfumeKnowledgeProfile(
    id: id,
    displayName: displayName,
    brand: brand,
    aliases: aliases,
    searchKeys: aliases,
    accords: const ['fresh', 'spicy'],
    topNotes: const ['citrus'],
    middleNotes: const ['pepper'],
    baseNotes: const ['amber'],
    fragranceFamily: 'fresh spicy',
    genderHint: 'men',
    lookupConfidence: confidence,
    status: PerfumeKnowledgeStatus.approved,
  );
}
