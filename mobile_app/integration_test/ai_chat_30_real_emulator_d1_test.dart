import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProductRepo extends Mock implements ProductRepo {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserTasteRepo extends Mock implements UserTasteRepo {}

class _RealWorkerAuditRepo extends AIChatRepo {
  _RealWorkerAuditRepo({
    required super.productRepo,
    required FirebaseAuth auth,
    required this.catalog,
  }) : super(auth: auth, allowGuestWorkerRequests: true);

  final List<ProductModel> catalog;
  final Map<String, PerfumeKnowledgeProfile> _knowledgeCache = {};
  int externalLookupCount = 0;
  int cacheHitCount = 0;

  @override
  bool get canPersistSession => false;

  @override
  String? get currentUserId => null;

  @override
  Future<List<ProductModel>> getCatalog({bool forceRefresh = false}) async {
    return catalog;
  }

  @override
  void invalidateCatalog() {}

  @override
  void invalidateCatalogCache() {}

  @override
  Future<AIChatSession?> fetchLatestRestorableSession({
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    return null;
  }

  @override
  Future<AIChatSession?> fetchRestorableSessionById({
    required String sessionId,
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    return null;
  }

  @override
  Future<List<AIChatStoredMessage>> fetchSessionMessages(String sessionId) {
    return Future.value(const <AIChatStoredMessage>[]);
  }

  @override
  Future<void> createSession({
    required String sessionId,
    required AIChatLanguage language,
    DateTime? startedAt,
    String? userId,
  }) async {}

  @override
  Future<void> appendMessage({
    required AIChatMessage message,
    String? sessionId,
  }) async {}

  @override
  Future<void> completeSession({
    required String sessionId,
    required int messageCount,
    String? finalRecommendationMessageId,
    DateTime? endedAt,
  }) async {}

  @override
  Future<AIChatBusinessInfo?> fetchBusinessInfo({
    bool forceRefresh = false,
  }) async {
    return const AIChatBusinessInfo(
      storeName: 'Qissa Perfumes',
      addressAr: '',
      addressEn: '',
      phone: '',
      whatsapp: '',
      facebookUrl: '',
      instagramUrl: '',
      websiteUrl: '',
      openingHoursAr: '',
      openingHoursEn: '',
      deliveryInfoAr:
          'مدة التوصيل وطريقة الدفع تظهران أثناء إتمام الطلب حسب العنوان.',
      deliveryInfoEn:
          'Delivery timing and payment options are shown during checkout.',
      isPublished: true,
    );
  }

  @override
  Future<Map<String, AIChatProductPublicStats>> fetchProductPublicStats({
    bool forceRefresh = false,
  }) async {
    return const <String, AIChatProductPublicStats>{};
  }

  @override
  Future<PerfumeKnowledgeProfile?> lookupPerfumeKnowledge(String query) async {
    final key = PerfumeKnowledgeProfile.documentIdForQuery(query);
    final cached = _knowledgeCache[key];
    if (cached != null) cacheHitCount += 1;
    return cached;
  }

  @override
  Future<ExternalPerfumeLookupResult> lookupExternalPerfumeKnowledgeResult({
    required String query,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) async {
    externalLookupCount += 1;
    return super.lookupExternalPerfumeKnowledgeResult(
      query: query,
      responseLanguage: responseLanguage,
      requestId: requestId,
    );
  }

  @override
  Future<PerfumeKnowledgeProfile> savePerfumeKnowledgeProfile(
    PerfumeKnowledgeProfile profile,
  ) async {
    _knowledgeCache[profile.id] = profile;
    _knowledgeCache[PerfumeKnowledgeProfile.documentIdForQuery(
          profile.displayName,
        )] =
        profile;
    if (profile.brand.trim().isNotEmpty) {
      _knowledgeCache[PerfumeKnowledgeProfile.documentIdForQuery(
            '${profile.brand} ${profile.displayName}',
          )] =
          profile;
    }
    return profile;
  }

  @override
  Future<void> logAIChatEvent({
    required String eventType,
    String? sessionId,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {}

  @override
  Future<void> saveAIChatDebugLog({
    required String phase,
    String? sessionId,
    String? requestId,
    String? language,
    String? messageText,
    String? detectedIntent,
    String? responseSource,
    String? issueCode,
    String? reasonCode,
    Map<String, dynamic>? preferencesSnapshot,
    Map<String, dynamic>? availabilityContextSnapshot,
    Map<String, dynamic>? recommendationMemorySnapshot,
    Map<String, dynamic>? candidateSummary,
    List<Map<String, dynamic>>? recommendedProducts,
    Map<String, dynamic>? workerReplySummary,
  }) async {}
}

class _Scenario {
  const _Scenario({
    required this.id,
    required this.title,
    required this.messages,
    required this.focus,
    this.expectCards,
  });

  final String id;
  final String title;
  final List<String> messages;
  final List<String> focus;
  final bool? expectCards;
}

class _ScenarioResult {
  _ScenarioResult({
    required this.id,
    required this.title,
    required this.messages,
    required this.focus,
    required this.expectedIntent,
    required this.chatDebugId,
    required this.remoteSyncStatus,
    required this.status,
    required this.type,
    required this.source,
    required this.contentPreview,
    required this.productIds,
    required this.productNames,
    required this.latencyMs,
    required this.turnLatenciesMs,
    required this.issues,
    required this.caveats,
  });

  final String id;
  final String title;
  final List<String> messages;
  final List<String> focus;
  final String? expectedIntent;
  final String chatDebugId;
  final Map<String, Object?> remoteSyncStatus;
  final String status;
  final String type;
  final String? source;
  final String contentPreview;
  final List<String> productIds;
  final List<String> productNames;
  final int latencyMs;
  final List<int> turnLatenciesMs;
  final List<String> issues;
  final List<String> caveats;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'messages': messages,
    'focus': focus,
    'expectedIntent': expectedIntent,
    'chatDebugId': chatDebugId,
    'remoteSyncStatus': remoteSyncStatus,
    'status': status,
    'type': type,
    'source': source,
    'contentPreview': contentPreview,
    'productIds': productIds,
    'productNames': productNames,
    'latencyMs': latencyMs,
    'turnLatenciesMs': turnLatenciesMs,
    'maxTurnLatencyMs': turnLatenciesMs.isEmpty
        ? null
        : turnLatenciesMs.reduce((a, b) => a > b ? a : b),
    'issues': issues,
    'caveats': caveats,
  };
}

class _TurnSendOutcome {
  const _TurnSendOutcome({required this.latencyMs, required this.timedOut});

  final int latencyMs;
  final bool timedOut;
}

ProductModel _product({
  required String id,
  required String name,
  required String brand,
  required double price,
  required String gender,
  required String season,
  required String occasion,
  required String time,
  required String intensity,
  required List<String> notes,
  required List<String> tags,
  String family = 'fresh',
  int stock = 10,
}) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: [name.substring(0, 2).toLowerCase()],
    brand: brand,
    price: price,
    gender: gender,
    stock: stock,
    season: season,
    fragranceFamily: family,
    notes: notes,
    imageUrls: const ['https://placehold.co/300x300/png'],
    description: 'Real emulator D1 audit product',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: occasion,
    time: time,
    intensity: intensity,
    topNotes: notes.take(2).toList(growable: false),
    middleNotes: notes.skip(1).take(2).toList(growable: false),
    baseNotes: notes.skip(2).take(3).toList(growable: false),
    tags: tags,
  );
}

List<ProductModel> _catalog() {
  return <ProductModel>[
    _product(
      id: 'budget_citrus',
      name: 'Budget Citrus',
      brand: 'Noura Atelier',
      price: 790,
      gender: 'men',
      season: 'summer',
      occasion: 'university',
      time: 'day',
      intensity: 'light',
      notes: const ['citrus', 'fruity', 'musk', 'clean'],
      tags: const ['fresh', 'clean', 'budget', 'office'],
    ),
    _product(
      id: 'campus_musk',
      name: 'Campus Musk',
      brand: 'Maison Rayah',
      price: 1450,
      gender: 'unisex',
      season: 'all seasons',
      occasion: 'university',
      time: 'day',
      intensity: 'light',
      notes: const ['musk', 'clean', 'soft', 'citrus'],
      tags: const ['clean', 'soft', 'student', 'sensitive'],
      family: 'musky',
    ),
    _product(
      id: 'aqua_breeze',
      name: 'Aqua Breeze',
      brand: 'Scent Theory',
      price: 2500,
      gender: 'unisex',
      season: 'summer',
      occasion: 'office',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
      tags: const ['fresh', 'clean', 'office', 'summer'],
    ),
    _product(
      id: 'light_blue',
      name: 'Light Blue',
      brand: 'Dolce & Gabbana',
      price: 3250,
      gender: 'unisex',
      season: 'summer',
      occasion: 'office',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'floral', 'fruity', 'woody'],
      tags: const ['fresh', 'clean', 'classic', 'bestseller'],
    ),
    _product(
      id: 'blue_wood',
      name: 'Blue Wood',
      brand: 'Qissa',
      price: 2100,
      gender: 'men',
      season: 'all seasons',
      occasion: 'daily',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'woody', 'amber', 'aromatic'],
      tags: const ['fresh', 'woody', 'masculine', 'attractive'],
      family: 'woody aromatic',
    ),
    _product(
      id: 'acqua_gio',
      name: 'Acqua di Gio',
      brand: 'Giorgio Armani',
      price: 3350,
      gender: 'men',
      season: 'summer',
      occasion: 'office',
      time: 'day',
      intensity: 'medium',
      notes: const ['citrus', 'aquatic', 'fruity', 'woody'],
      tags: const ['fresh', 'clean', 'classic', 'projection'],
    ),
    _product(
      id: 'oud_majlis',
      name: 'Oud Majlis',
      brand: 'Qissa',
      price: 2850,
      gender: 'unisex',
      season: 'winter',
      occasion: 'evening',
      time: 'night',
      intensity: 'strong',
      notes: const ['oud', 'amber', 'woody', 'spicy'],
      tags: const ['oud', 'oriental', 'luxury', 'long lasting'],
      family: 'oriental woody',
    ),
    _product(
      id: 'velvet_oud',
      name: 'Velvet Oud',
      brand: 'Maison Rayah',
      price: 4100,
      gender: 'men',
      season: 'winter',
      occasion: 'evening',
      time: 'night',
      intensity: 'strong',
      notes: const ['oud', 'leather', 'amber', 'spices'],
      tags: const ['oud', 'luxury', 'masculine', 'evening'],
      family: 'oriental',
    ),
    _product(
      id: 'vanilla_silk',
      name: 'Vanilla Silk',
      brand: 'Gourmand Lab',
      price: 1850,
      gender: 'women',
      season: 'winter',
      occasion: 'date',
      time: 'night',
      intensity: 'medium',
      notes: const ['vanilla', 'musk', 'caramel', 'floral'],
      tags: const ['sweet', 'romantic', 'soft', 'gift'],
      family: 'gourmand',
    ),
    _product(
      id: 'sweet_amber',
      name: 'Sweet Amber',
      brand: 'Qissa',
      price: 2300,
      gender: 'unisex',
      season: 'winter',
      occasion: 'evening',
      time: 'night',
      intensity: 'strong',
      notes: const ['vanilla', 'amber', 'caramel', 'sweet'],
      tags: const ['sweet', 'warm', 'projection', 'long lasting'],
      family: 'amber',
    ),
    _product(
      id: 'rose_muse',
      name: 'Rose Muse',
      brand: 'Noura Atelier',
      price: 2700,
      gender: 'women',
      season: 'spring',
      occasion: 'date',
      time: 'day',
      intensity: 'medium',
      notes: const ['rose', 'musk', 'floral', 'vanilla'],
      tags: const ['romantic', 'feminine', 'gift', 'soft'],
      family: 'floral',
    ),
    _product(
      id: 'bright_crystal',
      name: 'Bright Crystal',
      brand: 'Versace',
      price: 2950,
      gender: 'women',
      season: 'spring',
      occasion: 'daily',
      time: 'day',
      intensity: 'medium',
      notes: const ['floral', 'aquatic', 'musk', 'fresh'],
      tags: const ['fresh', 'soft', 'clean', 'gift'],
      family: 'floral',
    ),
    _product(
      id: 'black_tie',
      name: 'Black Tie',
      brand: 'Qissa',
      price: 3600,
      gender: 'men',
      season: 'winter',
      occasion: 'evening',
      time: 'night',
      intensity: 'strong',
      notes: const ['amber', 'spicy', 'woody', 'leather'],
      tags: const ['evening', 'luxury', 'projection', 'masculine'],
      family: 'spicy woody',
    ),
    _product(
      id: 'executive_clean',
      name: 'Executive Clean',
      brand: 'Scent Theory',
      price: 1900,
      gender: 'men',
      season: 'all seasons',
      occasion: 'office',
      time: 'day',
      intensity: 'light',
      notes: const ['musk', 'citrus', 'lavender', 'clean'],
      tags: const ['office', 'clean', 'not offensive', 'work'],
      family: 'aromatic',
    ),
    _product(
      id: 'imperial_noir',
      name: 'Imperial Noir',
      brand: 'Maison Rayah',
      price: 6900,
      gender: 'unisex',
      season: 'winter',
      occasion: 'evening',
      time: 'night',
      intensity: 'strong',
      notes: const ['amber', 'oud', 'vanilla', 'spices'],
      tags: const ['premium', 'luxury', 'long lasting', 'projection'],
      family: 'oriental amber',
    ),
    _product(
      id: 'soft_linen',
      name: 'Soft Linen',
      brand: 'Noura Atelier',
      price: 980,
      gender: 'unisex',
      season: 'all seasons',
      occasion: 'daily',
      time: 'day',
      intensity: 'light',
      notes: const ['musk', 'powdery', 'clean', 'floral'],
      tags: const ['soft', 'sensitive', 'budget', 'skin scent'],
      family: 'musky',
    ),
  ];
}

final _scenarios = <_Scenario>[
  const _Scenario(
    id: 'S01',
    title: 'unsure then men fresh',
    messages: ['أنا مش عارف أختار عطر، ممكن تساعدني؟', 'عايزه رجالي وفريش.'],
    focus: ['retarget', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S02',
    title: 'office not annoying',
    messages: ['عايز عطر مناسب للشغل ومش مزعج.'],
    focus: ['office', 'soft intensity'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S03',
    title: 'evening occasions',
    messages: ['عايز عطر للسهرات والمناسبات.'],
    focus: ['evening', 'luxury'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S04',
    title: 'longevity',
    messages: ['إيه أكتر عطر ثابت عندكم؟'],
    focus: ['direct catalog ranking'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S05',
    title: 'projection',
    messages: ['عايز عطر فواح الناس تحسه حواليا.'],
    focus: ['projection'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S06',
    title: 'quiet perfume',
    messages: ['مش بحب العطور القوية، عايز حاجة هادية.'],
    focus: ['low intensity', 'exclusion'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S07',
    title: 'feminine romantic',
    messages: ['عايزة عطر حريمي رومانسي.'],
    focus: ['women', 'romantic'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S08',
    title: 'masculine attractive',
    messages: ['عايز عطر رجالي جذاب وملفت.'],
    focus: ['men', 'attractive'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S09',
    title: 'summer heat',
    messages: ['عايز عطر للصيف والحر.'],
    focus: ['summer'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S10',
    title: 'winter',
    messages: ['عايز عطر للشتا.'],
    focus: ['winter'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S11',
    title: 'gift then woman 25',
    messages: ['عايز أجيب عطر هدية ومش عارف أختار.', 'لست، 25 سنة.'],
    focus: ['gift', 'follow-up memory'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S12',
    title: 'gift for man 30s',
    messages: ['عايز عطر هدية لراجل في الثلاثينات.'],
    focus: ['gift', 'men'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S13',
    title: 'budget 1000',
    messages: ['معايا 1000 جنيه، إيه أفضل عطر؟'],
    focus: ['budget'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S14',
    title: 'cheap good option',
    messages: ['عايز حاجة كويسة وسعرها قليل.'],
    focus: ['cheap'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S15',
    title: 'luxury no price limit',
    messages: ['عايز حاجة فخمة ومش مهم السعر.'],
    focus: ['premium'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S16',
    title: 'similar to Sauvage',
    messages: ['عندكم عطر شبه Sauvage؟'],
    focus: ['external reference', 'catalog-only cards'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S17',
    title: 'vanilla',
    messages: ['بحب الفانيليا، عندكم إيه؟'],
    focus: ['note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S18',
    title: 'oud',
    messages: ['عايز عطر عود.'],
    focus: ['note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S19',
    title: 'clean musk',
    messages: ['عايز عطر مسك نظيف.'],
    focus: ['musk', 'clean'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S20',
    title: 'sweet',
    messages: ['بحب العطور السويت.'],
    focus: ['sweet'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S21',
    title: 'not sweet',
    messages: ['مش بحب العطور المسكرة.'],
    focus: ['exclude sweet'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S22',
    title: '50ml or 100ml',
    messages: ['أجيب 50ml ولا 100ml؟'],
    focus: ['answer-only advice'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S23',
    title: 'EDP vs EDT',
    messages: ['الفرق بين EDP و EDT إيه؟'],
    focus: ['education answer'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S24',
    title: 'sensitive skin',
    messages: ['بشرتي حساسة، أختار إيه؟'],
    focus: ['safety caveat'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S25',
    title: 'authenticity',
    messages: ['العطور أصلية؟'],
    focus: ['business info'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S26',
    title: 'delivery',
    messages: ['التوصيل بياخد قد إيه؟'],
    focus: ['business info'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S27',
    title: 'payment',
    messages: ['الدفع أونلاين ولا عند الاستلام؟'],
    focus: ['business info'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S28',
    title: 'compare two perfumes',
    messages: ['محتار بين العطر ده والعطر ده.'],
    focus: ['comparison/clarification'],
    expectCards: null,
  ),
  const _Scenario(
    id: 'S29',
    title: 'best sellers',
    messages: ['إيه أكتر العطور مبيعًا عندكم؟'],
    focus: ['catalog ranking'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S30',
    title: 'one final recommendation',
    messages: ['رشحلي عطر واحد وخلاص.'],
    focus: ['decisive recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S31',
    title: 'calm chic personality',
    messages: ['عايز عطر هادي وشيك، مش صاخب.'],
    focus: ['personality', 'quiet luxury', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S32',
    title: 'bold confident personality',
    messages: ['عايز عطر جريء واثق ومميز.'],
    focus: ['personality', 'bold', 'projection'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S33',
    title: 'date night',
    messages: ['عايز عطر مناسب لدייט بالليل.'],
    focus: ['occasion', 'date', 'night'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S34',
    title: 'wedding guest',
    messages: ['عندي فرح وعايز عطر يبان محترم.'],
    focus: ['occasion', 'wedding', 'elegant'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S35',
    title: 'groom perfume',
    messages: ['أنا العريس وعايز عطر قوي للمناسبة.'],
    focus: ['occasion', 'groom', 'special event'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S36',
    title: 'bride perfume',
    messages: ['أنا العروسة وعايزة عطر ناعم وفخم.'],
    focus: ['occasion', 'bride', 'soft luxury'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S37',
    title: 'gym fragrance',
    messages: ['ينفع عطر للجيم؟ عايز حاجة خفيفة.'],
    focus: ['occasion', 'gym', 'light advice'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S38',
    title: 'travel fragrance',
    messages: ['مسافر وعايز عطر مناسب للسفر والجو المتغير.'],
    focus: ['occasion', 'travel', 'versatile'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S39',
    title: 'eid perfume',
    messages: ['عايز عطر للعيد يكون مبهج وراقي.'],
    focus: ['occasion', 'eid', 'festive'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S40',
    title: 'ramadan evenings',
    messages: ['عايز عطر مناسب لرمضان والخروجات الهادية.'],
    focus: ['occasion', 'ramadan', 'soft evening'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S41',
    title: 'morning daily',
    messages: ['عايز عطر صباحي يومي.'],
    focus: ['time', 'morning', 'daily'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S42',
    title: 'night strong',
    messages: ['عايز عطر ليلي ثابت وفخم.'],
    focus: ['time', 'night', 'long lasting'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S43',
    title: 'unique not common',
    messages: ['عايز عطر مش منتشر ومش كل الناس بتلبسه.'],
    focus: ['unique', 'not common', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S44',
    title: 'buying blind advice',
    messages: ['هشتري أونلاين من غير ما أشم، أختار إزاي؟'],
    focus: ['advice', 'buying blind', 'answer-only'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S45',
    title: 'old citrus memory',
    messages: ['كان عندي عطر قديم حمضي ومنعش، عايز حاجة شبهه.'],
    focus: ['memory-like preference', 'citrus', 'fresh'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S46',
    title: 'does not know notes',
    messages: ['مش فاهم في النوتات، اختارلي حاجة سهلة تعجب أغلب الناس.'],
    focus: ['beginner', 'safe recommendation', 'popular'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S47',
    title: 'formal outfit',
    messages: ['لابس بدلة وعايز عطر مناسب.'],
    focus: ['clothing', 'formal', 'elegant'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S48',
    title: 'casual outfit',
    messages: ['لبسي كاجوال وعايز عطر خفيف.'],
    focus: ['clothing', 'casual', 'light'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S49',
    title: 'smoker preference',
    messages: ['أنا بدخن وعايز عطر يفضل واضح بس مش خانق.'],
    focus: ['smoker', 'projection', 'not choking'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S50',
    title: 'car fragrance advice',
    messages: ['عايز عطر مناسب وأنا راكب عربية كتير، مش يدوخ.'],
    focus: ['advice', 'car', 'not offensive'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S51',
    title: 'lasts on clothes',
    messages: ['عايز عطر يثبت على الهدوم.'],
    focus: ['longevity', 'clothes', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S52',
    title: 'spray count advice',
    messages: ['أرش كام رشة من العطر؟'],
    focus: ['advice', 'spray count', 'answer-only'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S53',
    title: 'teen perfume',
    messages: ['عايز عطر مناسب لشاب صغير في الجامعة.'],
    focus: ['age', 'student', 'fresh'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S54',
    title: 'older parent gift',
    messages: ['عايز أجيب عطر لوالدي، حاجة محترمة وهادية.'],
    focus: ['gift', 'older parent', 'respectful'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S55',
    title: 'mother gift',
    messages: ['عايز عطر هدية لماما، ناعم ومش تقيل.'],
    focus: ['gift', 'mother', 'soft'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S56',
    title: 'hijab long lasting',
    messages: ['عايزة عطر يثبت مع الحجاب بس يكون ناعم.'],
    focus: ['long lasting', 'soft', 'women'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S57',
    title: 'unisex request',
    messages: ['عايز عطر ينفع رجالي وحريمي.'],
    focus: ['unisex', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S58',
    title: 'mood based',
    messages: ['مزاجي رايق وعايز ريحة تفتح النفس.'],
    focus: ['mood', 'fresh', 'uplifting'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S59',
    title: 'perfume routine',
    messages: ['أعمل روتين عطور؟ واحد للشغل وواحد للخروج.'],
    focus: ['routine', 'work', 'evening'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S60',
    title: 'selected product review',
    messages: ['لو اخترت Light Blue، مناسب لإيه ومش مناسب لإيه؟'],
    focus: ['selected product review', 'answer-only', 'product context'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S61',
    title: 'surprise me',
    messages: ['فاجئني بعطر حلو.'],
    focus: ['surprise', 'broad recommendation', 'safe popular picks'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S62',
    title: 'expensive smelling',
    messages: ['عايز عطر ريحته تبان غالية.'],
    focus: ['luxury vibe', 'expensive smelling', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S63',
    title: 'luxury without oud',
    messages: ['عايز عطر فخم بس من غير عود.'],
    focus: ['luxury', 'exclude oud', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S64',
    title: 'exclude vanilla',
    messages: ['مش بحب الفانيليا خالص.'],
    focus: ['exclude vanilla', 'less sweet', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S65',
    title: 'shower fresh',
    messages: ['عايز ريحة كأني لسه واخد شاور.'],
    focus: ['clean', 'shower fresh', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S66',
    title: 'soapy clean',
    messages: ['عندكم عطر ريحته صابونة نظيفة؟'],
    focus: ['soapy', 'clean musk', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S67',
    title: 'powdery',
    messages: ['بحب العطور البودرية.'],
    focus: ['powdery', 'soft', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S68',
    title: 'fruity',
    messages: ['عايزة عطر فيه ريحة فواكه.'],
    focus: ['fruity', 'note search', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S69',
    title: 'rose',
    messages: ['عايزة عطر ريحته ورد.'],
    focus: ['rose', 'floral', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S70',
    title: 'jasmine',
    messages: ['بحب ريحة الياسمين.'],
    focus: ['jasmine', 'white floral', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S71',
    title: 'coffee',
    messages: ['عندكم عطر فيه ريحة قهوة؟'],
    focus: ['coffee', 'gourmand', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S72',
    title: 'tobacco',
    messages: ['عايز عطر فيه تبغ.'],
    focus: ['tobacco', 'warm', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S73',
    title: 'leather',
    messages: ['عايز عطر فيه leather.'],
    focus: ['leather', 'formal', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S74',
    title: 'woody',
    messages: ['بحب العطور الخشبية.'],
    focus: ['woody', 'note search', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S75',
    title: 'green natural',
    messages: ['عايز عطر ريحته خضرا وطبيعية.'],
    focus: ['green', 'natural', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S76',
    title: 'tea note',
    messages: ['عندكم عطر فيه ريحة شاي؟'],
    focus: ['tea', 'herbal', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S77',
    title: 'coconut',
    messages: ['بحب ريحة جوز الهند.'],
    focus: ['coconut', 'tropical', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S78',
    title: 'marine fresh',
    messages: ['عايز ريحة بحر وفريش.'],
    focus: ['marine', 'aquatic', 'fresh'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S79',
    title: 'citrus fruits',
    messages: ['بحب الليمون والبرتقال في العطور.'],
    focus: ['citrus', 'fruit notes', 'fresh'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S80',
    title: 'spicy',
    messages: ['عايز عطر فيه توابل.'],
    focus: ['spicy', 'warm', 'note search'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S81',
    title: 'hotel lobby clean',
    messages: ['عايز عطر ريحته زي لوبي فندق نظيف.'],
    focus: ['hotel lobby', 'clean luxury', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S82',
    title: 'old money',
    messages: ['عايز عطر old money.'],
    focus: ['old money', 'quiet classic', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S83',
    title: 'quiet luxury',
    messages: ['عايز عطر quiet luxury.'],
    focus: ['quiet luxury', 'subtle premium', 'vibe'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S84',
    title: 'tiktok viral',
    messages: ['عندكم عطور تريند على تيك توك؟'],
    focus: ['trend', 'viral', 'catalog-safe popularity'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S85',
    title: 'content creator aesthetic',
    messages: ['أنا content creator وعايز عطر شكله وريحه حلوين.'],
    focus: ['content creator', 'aesthetic bottle', 'recommendation'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S86',
    title: 'price difference explanation',
    messages: ['ليه العطر ده أغلى من ده؟'],
    focus: ['price explanation', 'comparison', 'answer-only'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S87',
    title: 'cart hesitation',
    messages: ['حاسس إني لسه مش متأكد أشتري.'],
    focus: ['cart recovery', 'hesitation', 'advice'],
    expectCards: false,
  ),
  const _Scenario(
    id: 'S88',
    title: 'add-on recommendation',
    messages: ['هشتري العطر ده، أضيف معاه إيه؟'],
    focus: ['cross-sell', 'add-on', 'bundle'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S89',
    title: 'two-perfume combo',
    messages: ['عايز عطرين، واحد هادي وواحد قوي.'],
    focus: ['combo', 'daily and evening', 'cross-sell'],
    expectCards: true,
  ),
  const _Scenario(
    id: 'S90',
    title: 'best value',
    messages: ['عايز أفضل value for money.'],
    focus: ['value for money', 'budget quality', 'recommendation'],
    expectCards: true,
  ),
];

const _suiteName = String.fromEnvironment(
  'AI_CHAT_SCENARIO_SUITE',
  defaultValue: 'ai_chat_real_emulator_30',
);

const _scenarioIdsFilter = String.fromEnvironment('AI_CHAT_30_SCENARIO_IDS');

const _supplementalScenarioIds = <String>{
  'S31',
  'S32',
  'S33',
  'S34',
  'S35',
  'S36',
  'S37',
  'S38',
  'S39',
  'S40',
  'S41',
  'S42',
  'S43',
  'S44',
  'S45',
  'S46',
  'S47',
  'S48',
  'S49',
  'S50',
  'S51',
  'S52',
  'S53',
  'S54',
  'S55',
  'S56',
  'S57',
  'S58',
  'S59',
  'S60',
};

const _supplemental6190ScenarioIds = <String>{
  'S61',
  'S62',
  'S63',
  'S64',
  'S65',
  'S66',
  'S67',
  'S68',
  'S69',
  'S70',
  'S71',
  'S72',
  'S73',
  'S74',
  'S75',
  'S76',
  'S77',
  'S78',
  'S79',
  'S80',
  'S81',
  'S82',
  'S83',
  'S84',
  'S85',
  'S86',
  'S87',
  'S88',
  'S89',
  'S90',
};

const _baselineScenarioIds = <String>{
  'S01',
  'S02',
  'S03',
  'S04',
  'S05',
  'S06',
  'S07',
  'S08',
  'S09',
  'S10',
  'S11',
  'S12',
  'S13',
  'S14',
  'S15',
  'S16',
  'S17',
  'S18',
  'S19',
  'S20',
  'S21',
  'S22',
  'S23',
  'S24',
  'S25',
  'S26',
  'S27',
  'S28',
  'S29',
  'S30',
};

const _allScenarioIds = <String>{
  ..._baselineScenarioIds,
  ..._supplementalScenarioIds,
};

const _all90ScenarioIds = <String>{
  ..._allScenarioIds,
  ..._supplemental6190ScenarioIds,
};

String _expectedIntentFor(_Scenario scenario) {
  switch (scenario.id) {
    case 'S44':
    case 'S52':
    case 'S86':
    case 'S87':
      return 'answer-only';
    case 'S60':
      return 'follow-up review';
    case 'S37':
    case 'S50':
      return 'contextual advice';
    default:
      return scenario.expectCards == false ? 'answer-only' : 'recommendation';
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(EventType.view);
  });

  testWidgets(
    'runs 30 real emulator scenarios and emits D1 debug ids',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AIChatExperimentConfig.setTestOverrides(
        sendCompactContext: true,
        toolRouterV1: true,
        delegateMicroTurns: true,
        useCatalogSearchEngine: true,
        useSuitabilityPolicy: true,
        analyticsEventsEnabled: true,
        analyticsDebugSinkEnabled: true,
        analyticsRemoteSinkEnabled: false,
        turnDebugRemoteEnabled: true,
        debugCaptureMode: 'all',
        deterministicGateV1: true,
        llmLedRouterV2: true,
      );
      addTearDown(AIChatExperimentConfig.resetTestOverrides);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final results = <_ScenarioResult>[];
      var totalExternalLookupCount = 0;
      var totalCacheHitCount = 0;

      Future<bool> waitForTurn(
        AIChatCubit cubit,
        int expectedMessages,
        String scenarioId,
      ) async {
        for (var i = 0; i < 520; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final hasExpectedMessages =
              cubit.state.messages.length >= expectedMessages;
          final lastIsNotLoading =
              cubit.state.messages.isNotEmpty &&
              !cubit.state.messages.last.isLoading;
          if (hasExpectedMessages && lastIsNotLoading) {
            await tester.pump(const Duration(milliseconds: 700));
            return true;
          }
        }
        debugPrint(
          'AI_CHAT_30_TURN_TIMEOUT '
          '$scenarioId messages=${cubit.state.messages.length} '
          'expected=$expectedMessages status=${cubit.state.status.name}',
        );
        return false;
      }

      Future<void> waitForRemoteDebugSync(AIChatCubit cubit) async {
        for (var i = 0; i < 100; i++) {
          final status = cubit.chatDebugStatus;
          final success =
              int.tryParse(
                status['remoteDebugTurnSuccessCount']?.toString() ?? '0',
              ) ??
              0;
          if (success > 0) return;
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      Future<_TurnSendOutcome> sendMessage(
        AIChatCubit cubit,
        String message,
        String scenarioId,
      ) async {
        final stopwatch = Stopwatch()..start();
        final beforeCount = cubit.state.messages.length;
        final expectedCount = beforeCount + 2;
        final field = find.byKey(const ValueKey('ai_chat_message_input'));
        expect(field, findsOneWidget);
        await tester.ensureVisible(field);
        await tester.tap(field, warnIfMissed: false);
        tester.testTextInput.enterText(message);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump(const Duration(milliseconds: 300));
        if (cubit.state.messages.length == beforeCount) {
          final sendButton = find.byKey(const ValueKey('ai_chat_send_button'));
          if (sendButton.evaluate().isNotEmpty) {
            await tester.tap(sendButton, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
        if (cubit.state.messages.length == beforeCount) {
          await cubit.sendMessage(message);
        }
        final completed = await waitForTurn(cubit, expectedCount, scenarioId);
        await tester.pump(const Duration(milliseconds: 750));
        stopwatch.stop();
        return _TurnSendOutcome(
          latencyMs: stopwatch.elapsedMilliseconds,
          timedOut: !completed,
        );
      }

      Future<_ScenarioResult> runScenario(_Scenario scenario) async {
        final auth = _MockFirebaseAuth();
        when(() => auth.currentUser).thenReturn(null);
        final productRepo = _MockProductRepo();
        final repo = _RealWorkerAuditRepo(
          productRepo: productRepo,
          auth: auth,
          catalog: _catalog(),
        );

        final tasteRepo = _MockUserTasteRepo();
        when(
          () => tasteRepo.recordEvent(
            eventType: any(named: 'eventType'),
            notes: any(named: 'notes'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async {});

        final cubit = AIChatCubit(
          aiChatRepo: repo,
          userTasteRepo: tasteRepo,
          initialLanguage: AIChatLanguage.arabic,
          thinkingDelay: Duration.zero,
          cooldownDuration: Duration.zero,
        );

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  BlocProvider.value(value: cubit, child: const AIChatPage()),
            ),
            GoRoute(
              path: '/product/:id',
              builder: (context, state) => Scaffold(
                body: Text(
                  'Product ${state.pathParameters['id'] ?? 'unknown'}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        final stopwatch = Stopwatch()..start();
        final turnLatenciesMs = <int>[];
        final issues = <String>[];
        final caveats = <String>[];
        var turnTimedOut = false;

        for (final message in scenario.messages) {
          final outcome = await sendMessage(cubit, message, scenario.id);
          turnLatenciesMs.add(outcome.latencyMs);
          if (outcome.timedOut) {
            turnTimedOut = true;
            issues.add('turn_wait_timeout');
            break;
          }
          await tester.pump(const Duration(milliseconds: 700));
        }
        stopwatch.stop();
        await waitForRemoteDebugSync(cubit);

        final visibleMessages = cubit.state.messages
            .where((message) => !message.isLoading)
            .toList(growable: false);
        final last = visibleMessages.isNotEmpty
            ? visibleMessages.last
            : cubit.state.messages.last;
        final content = last.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        final lowerContent = content.toLowerCase();
        final ids = last.recommendedProducts
            .map((item) => item.product.id)
            .toList(growable: false);
        final names = last.recommendedProducts
            .map((item) => item.product.name)
            .toList(growable: false);
        final hasCards = ids.isNotEmpty;

        void issue(String value) => issues.add(value);
        void caveat(String value) => caveats.add(value);

        final hasMojibake = RegExp(
          r'[\u00d8\u00d9\u00c3\u00c2\ufffd]',
        ).hasMatch(content);
        final genericMessage = RegExp(
          r'^(understood|okay|ok|sure|تمام|حاضر)[.!؟\s]*$',
          caseSensitive: false,
        ).hasMatch(content);
        final invalidIds = ids
            .where((id) => !repo.catalog.any((product) => product.id == id))
            .toList(growable: false);
        final externalCard = names.any(
          (name) =>
              name.toLowerCase().contains('dior') ||
              name.toLowerCase().contains('sauvage'),
        );
        final fakeExternalClaim =
            lowerContent.contains('dior sauvage') &&
            RegExp(
              r'\b(available|in stock|stock|price|egp|buy)\b',
              caseSensitive: false,
            ).hasMatch(lowerContent);

        if (hasMojibake) issue('mojibake');
        if (genericMessage) issue('generic_copy');
        if (invalidIds.isNotEmpty) {
          issue('invalid_product_ids:${invalidIds.join(',')}');
        }
        if (externalCard) issue('external_card_violation');
        if (fakeExternalClaim) issue('fake_external_price_or_stock_claim');
        final maxTurnLatencyMs = turnLatenciesMs.isEmpty
            ? 0
            : turnLatenciesMs.reduce((a, b) => a > b ? a : b);
        if (maxTurnLatencyMs > 15000) {
          issue('turn_latency_over_15s');
        } else if (maxTurnLatencyMs > 10000) {
          caveat('turn_latency_over_10s');
        }
        if (stopwatch.elapsedMilliseconds > 15000) {
          caveat('scenario_latency_over_15s');
        }
        if (scenario.expectCards == true && !hasCards) {
          caveat('expected_cards_but_none');
        }
        if (scenario.expectCards == false && hasCards) {
          caveat('unexpected_cards_for_answer_only');
        }
        if (scenario.id == 'S44' &&
            (last.responseSource == 'local_business_info' ||
                lowerContent.contains('الدفع') ||
                lowerContent.contains('الاستلام'))) {
          caveat('buying_blind_advice_routed_to_payment');
        }
        if (scenario.id == 'S49' &&
            last.responseSource == 'compare_clarification') {
          caveat('smoker_preference_routed_compare_clarification');
        }
        if (scenario.id == 'S50' &&
            last.responseSource == 'local_ood_intent_guard') {
          caveat('car_fragrance_advice_routed_to_ood');
        }
        if (scenario.id == 'S60' && hasCards) {
          caveat('selected_product_review_rendered_new_cards');
        }
        if (cubit.state.status == AIChatStatus.noMatch && hasCards) {
          issue('no_match_with_cards');
        }
        if (scenario.id == 'S16' && hasCards && externalCard) {
          issue('sauvage_external_product_card');
        }
        if (scenario.id == 'S13' &&
            (lowerContent.contains('3 egp') ||
                lowerContent.contains('٣ جنيه'))) {
          issue('budget_count_misparse');
        }

        final status = Map<String, Object?>.from(cubit.chatDebugStatus);
        final chatDebugId = status['chatDebugId']?.toString() ?? '';
        final synced =
            int.tryParse(
              status['remoteDebugTurnSuccessCount']?.toString() ?? '0',
            ) ??
            0;
        if (chatDebugId.isEmpty) issue('missing_chat_debug_id');
        if (synced <= 0) issue('d1_debug_sync_not_confirmed');
        if (turnTimedOut && cubit.state.status == AIChatStatus.loading) {
          issue('status_still_loading_after_timeout');
        }

        final result = _ScenarioResult(
          id: scenario.id,
          title: scenario.title,
          messages: scenario.messages,
          focus: scenario.focus,
          expectedIntent: _expectedIntentFor(scenario),
          chatDebugId: chatDebugId,
          remoteSyncStatus: status,
          status: cubit.state.status.name,
          type: last.type.name,
          source: last.responseSource,
          contentPreview: content.length > 220
              ? content.substring(0, 220)
              : content,
          productIds: ids,
          productNames: names,
          latencyMs: stopwatch.elapsedMilliseconds,
          turnLatenciesMs: turnLatenciesMs,
          issues: issues,
          caveats: caveats,
        );
        totalExternalLookupCount += repo.externalLookupCount;
        totalCacheHitCount += repo.cacheHitCount;
        await cubit.close();
        return result;
      }

      final preflightIds = _suiteName == 'ai_chat_supplemental_31_60'
          ? const <String>['S31', 'S44']
          : _suiteName == 'ai_chat_supplemental_61_90'
          ? const <String>['S61', 'S86']
          : _suiteName == 'ai_chat_real_emulator_60'
          ? const <String>['S01', 'S31']
          : _suiteName == 'ai_chat_real_emulator_90'
          ? const <String>['S01', 'S61']
          : const <String>['S01', 'S16'];
      final preflight = preflightIds
          .map((id) => _scenarios.firstWhere((scenario) => scenario.id == id))
          .toList(growable: false);
      for (final scenario in preflight) {
        final result = await runScenario(scenario);
        debugPrint(
          'AI_CHAT_30_PREFLIGHT ${jsonEncode(result.toJson())}',
          wrapWidth: 4096,
        );
        if (result.chatDebugId.isEmpty ||
            result.remoteSyncStatus['remoteDebugSynced'] != true) {
          fail(
            'Preflight failed D1 sync for ${scenario.id}: ${result.toJson()}',
          );
        }
      }

      final requestedScenarioIds = _scenarioIdsFilter
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      final defaultScenarioIds = _suiteName == 'ai_chat_supplemental_31_60'
          ? _supplementalScenarioIds
          : _suiteName == 'ai_chat_supplemental_61_90'
          ? _supplemental6190ScenarioIds
          : _suiteName == 'ai_chat_real_emulator_60'
          ? _allScenarioIds
          : _suiteName == 'ai_chat_real_emulator_90'
          ? _all90ScenarioIds
          : _baselineScenarioIds;
      final selectedScenarioIds = requestedScenarioIds.isEmpty
          ? defaultScenarioIds
          : requestedScenarioIds;
      final scenariosToRun = _scenarios
          .where((scenario) => selectedScenarioIds.contains(scenario.id))
          .toList(growable: false);
      if (requestedScenarioIds.isNotEmpty &&
          scenariosToRun.length != requestedScenarioIds.length) {
        final found = scenariosToRun.map((scenario) => scenario.id).toSet();
        final missing = requestedScenarioIds.difference(found).join(', ');
        fail('Unknown AI_CHAT_30_SCENARIO_IDS: $missing');
      }

      for (final scenario in scenariosToRun) {
        final result = await runScenario(scenario);
        results.add(result);
        debugPrint(
          'AI_CHAT_30_SCENARIO_RESULT ${jsonEncode(result.toJson())}',
          wrapWidth: 4096,
        );
        await tester.pump(const Duration(seconds: 1));
      }

      final latencies = results.map((item) => item.latencyMs).toList()..sort();
      final turnLatencies =
          results.expand((item) => item.turnLatenciesMs).toList()..sort();
      final p95Index = latencies.isEmpty
          ? 0
          : ((latencies.length - 1) * 0.95).round();
      final p95TurnIndex = turnLatencies.isEmpty
          ? 0
          : ((turnLatencies.length - 1) * 0.95).round();
      final summary = <String, Object?>{
        'scenarioCount': results.length,
        'd1StoredSessions': results
            .where((item) => item.remoteSyncStatus['remoteDebugSynced'] == true)
            .length,
        'missingDebugSessionCount': results
            .where((item) => item.chatDebugId.isEmpty)
            .length,
        'missingTurnsCount': results
            .where(
              (item) =>
                  item.remoteSyncStatus['remoteDebugTurnSuccessCount'] ==
                      null ||
                  item.remoteSyncStatus['remoteDebugTurnSuccessCount'] == 0,
            )
            .length,
        'externalCardViolationCount': results
            .where((item) => item.issues.contains('external_card_violation'))
            .length,
        'fakeProductIdCount': results
            .where(
              (item) => item.issues.any(
                (issue) => issue.startsWith('invalid_product_ids'),
              ),
            )
            .length,
        'fakePriceStockClaimCount': results
            .where(
              (item) =>
                  item.issues.contains('fake_external_price_or_stock_claim'),
            )
            .length,
        'mojibakeCount': results
            .where((item) => item.issues.contains('mojibake'))
            .length,
        'genericCopyCount': results
            .where((item) => item.issues.contains('generic_copy'))
            .length,
        'over10sCount': results.where((item) => item.latencyMs > 10000).length,
        'over15sCount': results.where((item) => item.latencyMs > 15000).length,
        'over10sTurnCount': turnLatencies
            .where((latencyMs) => latencyMs > 10000)
            .length,
        'over15sTurnCount': turnLatencies
            .where((latencyMs) => latencyMs > 15000)
            .length,
        'maxTurnLatencyMs': turnLatencies.isEmpty ? 0 : turnLatencies.last,
        'avgLatencyMs': latencies.isEmpty
            ? 0
            : latencies.reduce((a, b) => a + b) / latencies.length,
        'p95LatencyMs': latencies.isEmpty ? 0 : latencies[p95Index],
        'p95TurnLatencyMs': turnLatencies.isEmpty
            ? 0
            : turnLatencies[p95TurnIndex],
        'issueScenarioCount': results
            .where((item) => item.issues.isNotEmpty)
            .length,
        'caveatScenarioCount': results
            .where((item) => item.caveats.isNotEmpty)
            .length,
        'externalLookupCount': totalExternalLookupCount,
        'cacheHitCount': totalCacheHitCount,
      };

      final report = <String, Object?>{
        'suiteName': _suiteName,
        'summary': summary,
        'results': results.map((item) => item.toJson()).toList(),
      };
      debugPrint(
        'AI_CHAT_30_REAL_EMULATOR_D1_REPORT ${jsonEncode(report)}',
        wrapWidth: 4096,
      );
      binding.reportData = <String, Object?>{_suiteName: summary};
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
