import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/shared_recommended_product_card.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

ProductModel _product() {
  final now = Timestamp.fromMillisecondsSinceEpoch(0);
  return ProductModel(
    id: 'p1',
    name: 'Shared Product',
    nameLower: 'shared product',
    searchPrefixes: buildSearchPrefixes('Shared Product'),
    brand: 'Brand',
    price: 1200,
    stock: 5,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'desc',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'day',
    intensity: 'light',
    topNotes: const ['bergamot'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['fresh'],
  );
}

void main() {
  testWidgets('supporting text shows up to three lines with larger font', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: SharedRecommendedProductCard(
                product: _product(),
                onTap: () {},
                primaryActionLabel: 'Details',
                compact: true,
                supportingText:
                    'Fits preferences because it is fresh, citrus-led, and works well for daily wear.',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final text = tester.widget<Text>(find.textContaining('Fits preferences'));
    expect(text.maxLines, 3);
    expect(text.style?.fontSize, 14);
  });
}
