import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_config.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/analysis_transcript_payload.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply_validator.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/restock_request_model.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';

/// Repository for AI Chat related data operations.
///
/// In MVP, this mainly proxies the product catalog fetch.
/// In Phase 2, it will also handle Cloudflare Worker communication
/// and Firestore writes for restock_requests / ai_chat_events.
class AIChatRepo {
  static const bool _debugLogsEnabled = bool.fromEnvironment(
    'AI_CHAT_DEBUG_LOGS_ENABLED',
    defaultValue: false,
  );
  static const bool _nonCriticalTelemetryEnabled = bool.fromEnvironment(
    'AI_CHAT_NON_CRITICAL_TELEMETRY_ENABLED',
    defaultValue: false,
  );
  static const bool _defaultAllowGuestWorkerRequests = bool.fromEnvironment(
    'AI_CHAT_ALLOW_GUEST_WORKER',
    defaultValue: !kReleaseMode,
  );
  static const int _workerHttpTimeoutSeconds = int.fromEnvironment(
    'AI_CHAT_WORKER_HTTP_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
  static const Set<String> _essentialTelemetryEvents = {
    'message_sent',
    'request_model_error',
    'request_failure',
    'recommendation_shown',
    'feedback_submitted',
  };

  final ProductRepo? _productRepo;
  final Future<List<ProductModel>> Function()? _catalogFetcher;
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final Dio _dio;
  final String _workerBaseUrl;
  final DateTime Function() _now;
  final bool _allowGuestWorkerRequests;
  String? _currentSessionId;

  /// Cached catalog to avoid repeated Firestore reads within the same session.
  List<ProductModel>? _cachedCatalog;

  /// Timestamp of the last successful catalog fetch (used for TTL).
  DateTime? _catalogCachedAt;

  AIChatBusinessInfo? _cachedBusinessInfo;
  DateTime? _businessInfoCachedAt;
  Map<String, AIChatProductPublicStats>? _cachedProductPublicStats;
  DateTime? _productPublicStatsCachedAt;
  DateTime? _workerCircuitOpenedAt;
  int _workerConsecutiveNetworkFailures = 0;
  String? _lastWorkerFailureReasonCode;

  /// How long the catalog cache stays valid before a background refresh.
  static const Duration _catalogTtl = Duration(minutes: 2);
  static const Duration _businessInfoTtl = Duration(minutes: 10);
  static const Duration _productStatsTtl = Duration(minutes: 10);
  static const Duration _workerCircuitCooldown = Duration(seconds: 60);
  static const int _workerCircuitFailureThreshold = 2;

  static const String _defaultWorkerBaseUrl = String.fromEnvironment(
    'AI_CHAT_WORKER_URL',
    defaultValue: AIChatConfig.defaultWorkerBaseUrl,
  );

  void _logDebug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_debugLogsEnabled) return;
    log(message, name: 'AIChatRepo', error: error, stackTrace: stackTrace);
  }

  String _shortText(String value, {int maxLength = 180}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength)}вЂ¦';
  }

  String _debugMessagePreview(String value, {int maxLength = 180}) {
    final length = value.trim().length;
    if (kReleaseMode) return '<redacted length=$length>';
    return _shortText(value, maxLength: maxLength);
  }

  Map<String, RecommendedProduct> _recommendationByProductId(
    List<RecommendedProduct> recommendations,
  ) {
    return {
      for (final recommendation in recommendations)
        recommendation.product.id: recommendation,
    };
  }

  Map<String, dynamic> _buildReasonFacts({
    required ProductModel product,
    required SessionPreferences preferences,
    RecommendedProduct? recommendation,
  }) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll('_', ' ');

    final requestedNotes = <String>{
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(normalize).where((item) => item.isNotEmpty).toSet();
    final productNotes = <String>{
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      ...product.tags,
    }.map(normalize).where((item) => item.isNotEmpty).toSet();
    final matchedNotes = requestedNotes
        .where((note) => productNotes.contains(note))
        .take(3)
        .toList(growable: false);

    final matchedContext = <String>[
      if (preferences.gender != null &&
          normalize(product.gender) == normalize(preferences.gender!))
        'gender:${preferences.gender}',
      if (preferences.season != null &&
          (normalize(product.season) == normalize(preferences.season!) ||
              normalize(product.season) == 'all seasons'))
        'season:${preferences.season}',
      if (preferences.occasion != null &&
          normalize(product.occasion) == normalize(preferences.occasion!))
        'occasion:${preferences.occasion}',
      if (preferences.time != null &&
          normalize(product.time) == normalize(preferences.time!))
        'time:${preferences.time}',
      if (preferences.intensity != null &&
          normalize(product.intensity) == normalize(preferences.intensity!))
        'intensity:${preferences.intensity}',
    ];

    final cautions = <String>[
      if (preferences.occasion != null &&
          normalize(preferences.occasion!) == 'office' &&
          normalize(product.intensity) == 'strong')
        'stronger than ideal for office',
      if (preferences.intensity != null &&
          normalize(product.intensity).isNotEmpty &&
          normalize(product.intensity) != normalize(preferences.intensity!))
        'intensity differs from request',
      if (preferences.season != null &&
          normalize(product.season).isNotEmpty &&
          normalize(product.season) != normalize(preferences.season!) &&
          normalize(product.season) != 'all seasons')
        'season differs from request',
    ];

    final exactBudget = preferences.maxBudget;
    return {
      'localMatchReason': recommendation?.matchReason,
      'matchLabel': recommendation?.matchLabel,
      'matchScore': recommendation?.matchScore,
      'matchedNotes': matchedNotes,
      'matchedContext': matchedContext,
      'budget': {
        'exactBudget': exactBudget,
        'price': product.effectivePrice,
        'withinBudget':
            exactBudget == null || product.effectivePrice <= exactBudget,
        'budgetStatus': recommendation?.budgetStatus.name,
      },
      'productProfile': {
        'family': product.fragranceFamily,
        'notes': product.notes.take(4).toList(growable: false),
        'topNotes': product.topNotes.take(3).toList(growable: false),
        'middleNotes': product.middleNotes.take(3).toList(growable: false),
        'baseNotes': product.baseNotes.take(3).toList(growable: false),
        'tags': product.tags.take(4).toList(growable: false),
      },
      'cautions': cautions,
    };
  }

  AIChatRepo({
    required ProductRepo productRepo,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Dio? dio,
    String? workerBaseUrl,
    DateTime Function()? nowProvider,
    bool? allowGuestWorkerRequests,
  }) : _productRepo = productRepo,
       _catalogFetcher = null,
       _firestore = firestore,
       _auth = auth,
       _dio = dio ?? Dio(),
       _workerBaseUrl = (workerBaseUrl ?? _defaultWorkerBaseUrl)
           .trim()
           .replaceAll(RegExp(r'/$'), ''),
       _now = nowProvider ?? DateTime.now,
       _allowGuestWorkerRequests =
           allowGuestWorkerRequests ?? _defaultAllowGuestWorkerRequests;

  AIChatRepo.forCatalogTest({
    required Future<List<ProductModel>> Function() catalogFetcher,
    DateTime Function()? nowProvider,
  }) : _productRepo = null,
       _catalogFetcher = catalogFetcher,
       _firestore = null,
       _auth = null,
       _dio = Dio(),
       _workerBaseUrl = _defaultWorkerBaseUrl,
       _now = nowProvider ?? DateTime.now,
       _allowGuestWorkerRequests = _defaultAllowGuestWorkerRequests;

  FirebaseFirestore get _resolvedFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  String? get currentUserId => _resolvedAuth.currentUser?.uid.trim();

  bool get canPersistSession {
    final uid = currentUserId;
    return uid != null && uid.isNotEmpty;
  }

  String? get lastWorkerFailureReasonCode => _lastWorkerFailureReasonCode;

  bool _isWorkerCircuitOpen() {
    final openedAt = _workerCircuitOpenedAt;
    if (openedAt == null) return false;
    if (_now().difference(openedAt) < _workerCircuitCooldown) return true;
    _workerCircuitOpenedAt = null;
    _workerConsecutiveNetworkFailures = 0;
    return false;
  }

  bool _isNetworkWorkerFailure(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  void _recordWorkerSuccess() {
    _workerConsecutiveNetworkFailures = 0;
    _workerCircuitOpenedAt = null;
    _lastWorkerFailureReasonCode = null;
  }

  String _classifyWorkerFailure(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'worker_timeout';
    }
    if (error.type == DioExceptionType.connectionError) {
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('xmlhttprequest') ||
          message.contains('cors') ||
          message.contains('access-control')) {
        return 'cors_error';
      }
      return 'network_error';
    }
    if (error.response?.statusCode != null) {
      return 'worker_http_${error.response!.statusCode}';
    }
    return 'worker_error';
  }

  void _recordWorkerFailure(DioException error, {String? requestId}) {
    _lastWorkerFailureReasonCode = _classifyWorkerFailure(error);
    if (!_isNetworkWorkerFailure(error)) return;
    _workerConsecutiveNetworkFailures++;
    if (_workerConsecutiveNetworkFailures >= _workerCircuitFailureThreshold) {
      _workerCircuitOpenedAt = _now();
      _logDebug(
        'AI worker circuit opened after $_workerConsecutiveNetworkFailures network failures | requestId=$requestId',
        error: error,
      );
    }
  }

  /// Fetches the product catalog for AI filtering/ranking.
  ///
  /// Uses an in-memory cache: the catalog is fetched once per app session
  /// and reused for subsequent AI requests. Call [invalidateCatalog] to
  /// force a refresh (e.g. after admin updates products).
  Future<List<ProductModel>> getCatalog({bool forceRefresh = false}) async {
    final isExpired =
        _catalogCachedAt == null ||
        _now().difference(_catalogCachedAt!) > _catalogTtl;

    if (!forceRefresh && !isExpired && _cachedCatalog != null) {
      unawaited(
        logAIChatEvent(
          eventType: 'request_catalog_cache_hit',
          metadata: {
            'cacheAgeSeconds': _now().difference(_catalogCachedAt!).inSeconds,
          },
        ),
      );
      return _cachedCatalog!;
    }

    final missReason = forceRefresh
        ? 'force_refresh'
        : _cachedCatalog == null
        ? 'cold_start'
        : 'ttl_expired';
    unawaited(
      logAIChatEvent(
        eventType: 'request_catalog_cache_miss',
        metadata: {'reason': missReason},
      ),
    );

    _cachedCatalog = await (_catalogFetcher != null
        ? _catalogFetcher()
        : _productRepo!.fetchAICatalog());
    _cachedCatalog = _cachedCatalog!
        .where((product) => product.isActive)
        .toList(growable: false);
    _catalogCachedAt = _now();
    return _cachedCatalog!;
  }

  /// Clears the cached catalog so the next [getCatalog] call
  /// fetches fresh data from Firestore.
  void invalidateCatalog() {
    _cachedCatalog = null;
    _catalogCachedAt = null;
  }

  Future<List<ProductModel>> fetchProductsByIds(List<String> ids) async {
    if (_productRepo == null) return const <ProductModel>[];
    return _productRepo.fetchProductsByIds(ids);
  }

  void invalidateCatalogCache() => invalidateCatalog();

  Future<AIChatSession?> fetchLatestRestorableSession({
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final minStartedAt = _now().toUtc().subtract(maxAge);
    final snapshot = await _resolvedFirestore
        .collection(AIChatCollectionNames.sessions)
        .where('userId', isEqualTo: normalizedUserId)
        .orderBy('startedAt', descending: true)
        .limit(5)
        .get();

    for (final doc in snapshot.docs) {
      try {
        final session = AIChatSession.fromJson(doc.data());
        if (session.startedAt.toUtc().isBefore(minStartedAt)) continue;
        return session;
      } catch (error, stackTrace) {
        _logDebug(
          'Skipping invalid persisted AI chat session ${doc.id}.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return null;
  }

  Future<AIChatSession?> fetchRestorableSessionById({
    required String sessionId,
    required String userId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final normalizedSessionId = sessionId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedSessionId.isEmpty || normalizedUserId.isEmpty) return null;

    final snapshot = await _resolvedFirestore
        .collection(AIChatCollectionNames.sessions)
        .doc(normalizedSessionId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;

    final session = AIChatSession.fromJson(snapshot.data()!);
    if (session.userId != normalizedUserId) return null;
    final minStartedAt = _now().toUtc().subtract(maxAge);
    if (session.startedAt.toUtc().isBefore(minStartedAt)) return null;
    return session;
  }

  Future<List<AIChatStoredMessage>> fetchSessionMessages(String sessionId) {
    return _loadPersistedSessionTranscript(sessionId);
  }

  Future<AIChatBusinessInfo?> fetchBusinessInfo({
    bool forceRefresh = false,
  }) async {
    final isExpired =
        _businessInfoCachedAt == null ||
        _now().difference(_businessInfoCachedAt!) > _businessInfoTtl;
    if (!forceRefresh && !isExpired && _cachedBusinessInfo != null) {
      return _cachedBusinessInfo;
    }

    try {
      final snapshot = await _resolvedFirestore
          .collection('config')
          .doc('business_info')
          .get();
      if (!snapshot.exists) {
        _cachedBusinessInfo = null;
        _businessInfoCachedAt = _now();
        return null;
      }
      final info = AIChatBusinessInfo.fromMap(snapshot.data());
      _cachedBusinessInfo = info;
      _businessInfoCachedAt = _now();
      return info;
    } catch (error, stackTrace) {
      _logDebug(
        'Failed to fetch AI chat business info.',
        error: error,
        stackTrace: stackTrace,
      );
      return _cachedBusinessInfo;
    }
  }

  Future<Map<String, AIChatProductPublicStats>> fetchProductPublicStats({
    bool forceRefresh = false,
  }) async {
    final isExpired =
        _productPublicStatsCachedAt == null ||
        _now().difference(_productPublicStatsCachedAt!) > _productStatsTtl;
    if (!forceRefresh && !isExpired && _cachedProductPublicStats != null) {
      return _cachedProductPublicStats!;
    }

    try {
      final snapshot = await _resolvedFirestore
          .collection('product_public_stats')
          .get();
      final stats = <String, AIChatProductPublicStats>{};
      for (final doc in snapshot.docs) {
        final entry = AIChatProductPublicStats.fromMap(
          documentId: doc.id,
          map: doc.data(),
        );
        if (entry.productId.isNotEmpty) {
          stats[entry.productId] = entry;
        }
      }
      _cachedProductPublicStats = stats;
      _productPublicStatsCachedAt = _now();
      return stats;
    } catch (error, stackTrace) {
      _logDebug(
        'Failed to fetch AI chat product stats.',
        error: error,
        stackTrace: stackTrace,
      );
      return _cachedProductPublicStats ?? const {};
    }
  }

  Future<PerfumeKnowledgeProfile?> lookupPerfumeKnowledge(String query) async {
    final normalized = normalizeKnowledgeKey(query);
    if (normalized.length < 3) return null;

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _resolvedFirestore
          .collection('perfume_knowledge')
          .where('searchKeys', arrayContains: normalized)
          .limit(1)
          .get();
    } on FirebaseException catch (error, stackTrace) {
      _logDebug(
        'Perfume knowledge lookup skipped: ${error.code}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    if (snapshot.docs.isEmpty) return null;

    final profile = PerfumeKnowledgeProfile.fromFirestore(snapshot.docs.first);
    if (!profile.isUsable) return null;

    unawaited(
      snapshot.docs.first.reference
          .set({
            'lastUsedAt': FieldValue.serverTimestamp(),
            'usageCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((Object error, StackTrace stackTrace) {
            _logDebug(
              'Perfume knowledge usage update skipped.',
              error: error,
              stackTrace: stackTrace,
            );
          }),
    );
    return profile;
  }

  Future<PerfumeKnowledgeProfile?> lookupExternalPerfumeKnowledge({
    required String query,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) async {
    final result = await lookupExternalPerfumeKnowledgeResult(
      query: query,
      responseLanguage: responseLanguage,
      requestId: requestId,
    );
    return result.profile;
  }

  Future<ExternalPerfumeLookupResult> lookupExternalPerfumeKnowledgeResult({
    required String query,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 3 || _workerBaseUrl.isEmpty) {
      return const ExternalPerfumeLookupResult.notFound(
        reason: 'invalid_query',
      );
    }

    try {
      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/perfume-knowledge/lookup',
        requestId: requestId,
      );
      if (headers == null) {
        return const ExternalPerfumeLookupResult.notFound(
          reason: 'worker_auth_required',
        );
      }

      final response = await _dio.post(
        _buildWorkerUrl('/api/perfume-knowledge/lookup'),
        data: {
          'query': normalizedQuery,
          'responseLanguage': responseLanguage.code,
          'requestId': requestId,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return const ExternalPerfumeLookupResult.notFound(
          reason: 'worker_error',
        );
      }
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : Map<String, dynamic>.from(
              response.data is Map ? response.data as Map : {},
            );
      if (data['status'] == 'ambiguous') {
        final rawCandidates = data['candidates'];
        final candidates = rawCandidates is Iterable
            ? rawCandidates
                  .whereType<Map>()
                  .map(
                    (item) => ExternalPerfumeCandidate.fromMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .where((item) => item.isUsable)
                  .take(3)
                  .toList(growable: false)
            : const <ExternalPerfumeCandidate>[];
        if (candidates.isEmpty) {
          return const ExternalPerfumeLookupResult.notFound(
            reason: 'empty_candidates',
          );
        }
        return ExternalPerfumeLookupResult.ambiguous(candidates);
      }
      if (data['status'] == 'not_found') {
        return ExternalPerfumeLookupResult.notFound(
          reason: data['reason']?.toString(),
        );
      }
      final profileMap = data['profile'];
      if (profileMap is! Map) {
        return const ExternalPerfumeLookupResult.notFound(
          reason: 'missing_profile',
        );
      }

      final profile = PerfumeKnowledgeProfile.fromMap(
        Map<String, dynamic>.from(profileMap),
        id: PerfumeKnowledgeProfile.documentIdForQuery(
          (profileMap['displayName'] ?? normalizedQuery).toString(),
        ),
      );
      if (!profile.isUsable || profile.lookupConfidence < 0.58) {
        return const ExternalPerfumeLookupResult.notFound(
          reason: 'low_confidence',
        );
      }

      final savedProfile = await savePerfumeKnowledgeProfile(profile);
      return ExternalPerfumeLookupResult.found(savedProfile);
    } catch (e, stackTrace) {
      _logDebug(
        'External perfume knowledge lookup failed: $e | requestId=$requestId',
        error: e,
        stackTrace: stackTrace,
      );
      return const ExternalPerfumeLookupResult.notFound(reason: 'exception');
    }
  }

  Future<PerfumeKnowledgeProfile?> resolveExternalPerfumeKnowledgeCandidate({
    required ExternalPerfumeCandidate candidate,
    String? requestId,
  }) async {
    if (!candidate.isUsable || _workerBaseUrl.isEmpty) return null;

    try {
      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/perfume-knowledge/resolve',
        requestId: requestId,
      );
      if (headers == null) return null;

      final response = await _dio.post(
        _buildWorkerUrl('/api/perfume-knowledge/resolve'),
        data: {
          'sourceUrl': candidate.sourceUrl,
          'selectedName': candidate.displayName,
          'requestId': requestId,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : Map<String, dynamic>.from(
              response.data is Map ? response.data as Map : {},
            );
      if (data['status'] != 'found') return null;
      final profileMap = data['profile'];
      if (profileMap is! Map) return null;
      final profile = PerfumeKnowledgeProfile.fromMap(
        Map<String, dynamic>.from(profileMap),
        id: PerfumeKnowledgeProfile.documentIdForQuery(
          (profileMap['displayName'] ?? candidate.displayName).toString(),
        ),
      );
      if (!profile.isUsable || profile.lookupConfidence < 0.58) return null;
      return savePerfumeKnowledgeProfile(profile);
    } catch (e, stackTrace) {
      _logDebug(
        'External perfume knowledge resolve failed: $e | requestId=$requestId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PerfumeKnowledgeProfile> savePerfumeKnowledgeProfile(
    PerfumeKnowledgeProfile profile,
  ) async {
    final docId = profile.id.trim().isNotEmpty
        ? profile.id
        : PerfumeKnowledgeProfile.documentIdForQuery(profile.displayName);
    final normalizedProfile = PerfumeKnowledgeProfile(
      id: docId,
      displayName: profile.displayName,
      brand: profile.brand,
      aliases: profile.aliases,
      searchKeys: buildPerfumeKnowledgeSearchKeys(
        displayName: profile.displayName,
        brand: profile.brand,
        aliases: profile.aliases,
      ),
      accords: profile.accords,
      topNotes: profile.topNotes,
      middleNotes: profile.middleNotes,
      baseNotes: profile.baseNotes,
      fragranceFamily: profile.fragranceFamily,
      genderHint: profile.genderHint,
      seasonHint: profile.seasonHint,
      occasionHint: profile.occasionHint,
      timeHint: profile.timeHint,
      intensityHint: profile.intensityHint,
      sourceName: profile.sourceName,
      sourceUrl: profile.sourceUrl,
      extractionMethod: profile.extractionMethod,
      lookupConfidence: profile.lookupConfidence,
      status: PerfumeKnowledgeStatus.needsReview,
      usageCount: profile.usageCount + 1,
    );

    try {
      await _resolvedFirestore
          .collection('perfume_knowledge')
          .doc(docId)
          .set(
            normalizedProfile.toFirestoreCreateMap(),
            SetOptions(merge: true),
          );
    } on FirebaseException catch (error, stackTrace) {
      _logDebug(
        'Perfume knowledge cache write skipped: ${error.code}',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return normalizedProfile;
  }

  void setSessionId(String sessionId) {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) return;
    _currentSessionId = normalized;
  }

  String? _resolvePersistenceUserId([String? explicitUserId]) {
    final supplied = explicitUserId?.trim() ?? '';
    if (supplied.isNotEmpty) return supplied;
    final authUserId = _resolvedAuth.currentUser?.uid.trim() ?? '';
    if (authUserId.isNotEmpty) return authUserId;
    return null;
  }

  AIChatMessageRole _toStoredRole(MessageSender sender) {
    return sender == MessageSender.user
        ? AIChatMessageRole.user
        : AIChatMessageRole.assistant;
  }

  AIChatMessageType _toStoredType(MessageType type) {
    switch (type) {
      case MessageType.recommendation:
        return AIChatMessageType.recommendation;
      case MessageType.availability:
        return AIChatMessageType.availability;
      case MessageType.loading:
        return AIChatMessageType.loading;
      case MessageType.error:
        return AIChatMessageType.error;
      case MessageType.text:
        return AIChatMessageType.text;
    }
  }

  Future<AnalysisTranscriptPayload> buildAnalysisPayload({
    required String sessionId,
    required SessionPreferences preferences,
    List<AIChatMessage>? fallbackTranscript,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty.');
    }

    final persistedTranscript = await _loadPersistedSessionTranscript(
      normalizedSessionId,
    );
    if (persistedTranscript.isNotEmpty) {
      return _buildAnalysisPayloadFromStoredTranscript(
        sessionId: normalizedSessionId,
        transcript: persistedTranscript,
        preferences: preferences,
      );
    }

    if (fallbackTranscript != null) {
      return _buildAnalysisPayloadFromUiTranscript(
        sessionId: normalizedSessionId,
        transcript: fallbackTranscript,
        preferences: preferences,
      );
    }

    return AnalysisTranscriptPayload(
      sessionId: normalizedSessionId,
      preferences: _sanitizeMap(preferences.toJson()),
      entries: const <AnalysisTranscriptEntry>[],
      originalMessageCount: 0,
      compactedMessageCount: 0,
      finalRecommendationMessageId: null,
      finalRecommendationProductIds: const <String>[],
    );
  }

  AnalysisTranscriptPayload buildAnalysisPayloadFromTranscriptForTesting({
    required String sessionId,
    required SessionPreferences preferences,
    required List<AIChatStoredMessage> transcript,
  }) {
    return _buildAnalysisPayloadFromStoredTranscript(
      sessionId: sessionId,
      transcript: transcript,
      preferences: preferences,
    );
  }

  Future<AIFeedbackAnalysis?> triggerFeedbackAnalysis({
    required AnalysisTranscriptPayload analysisPayload,
    required AIUnifiedFeedback sessionFeedback,
    Map<String, dynamic>? inlineFeedbackSummary,
    String? responseLanguage,
    String? requestId,
  }) async {
    try {
      if (_workerBaseUrl.isEmpty) {
        _logDebug('AI chat worker URL is not configured.');
        return null;
      }

      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/feedback-analysis',
        requestId: requestId,
      );
      if (headers == null) return null;

      final response = await _dio.post(
        _buildWorkerUrl('/api/feedback-analysis'),
        data: {
          'analysisPayload': analysisPayload.toJson(),
          'sessionFeedback': sessionFeedback.toJson(),
          'inlineFeedbackSummary': inlineFeedbackSummary,
          'responseLanguage': (responseLanguage?.trim() == 'en') ? 'en' : 'ar',
          'requestId': requestId,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          return AIFeedbackAnalysis.fromJson(
            response.data as Map<String, dynamic>,
          );
        }

        return AIFeedbackAnalysis.fromJson(
          Map<String, dynamic>.from(
            response.data is Map ? response.data as Map : <String, dynamic>{},
          ),
        );
      }

      log(
        'Feedback analysis worker returned non-200 status: ${response.statusCode} | Data: ${response.data}',
        name: 'AIChatRepo',
      );
      return null;
    } on DioException catch (dioErr) {
      log(
        'Dio networking error calling feedback analysis worker: ${dioErr.message} | Response: ${dioErr.response?.data}',
        name: 'AIChatRepo',
        error: dioErr,
      );
      return null;
    } catch (e) {
      log(
        'Unknown error calling feedback analysis worker: $e',
        name: 'AIChatRepo',
        error: e,
      );
      return null;
    }
  }

  Future<bool> sendNegativeFeedbackDebugSnapshot({
    required Map<String, Object?> payload,
    String? requestId,
  }) async {
    try {
      if (_workerBaseUrl.isEmpty) return false;

      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/ai-chat-feedback',
        requestId: requestId,
      );
      if (headers == null) return false;

      final response = await _dio.post(
        _buildWorkerUrl('/api/ai-chat-feedback'),
        data: payload,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      return response.statusCode == 200 || response.statusCode == 202;
    } on DioException catch (dioErr) {
      _logDebug(
        'Dio networking error sending AI chat feedback snapshot: ${dioErr.message} | requestId=$requestId',
        error: dioErr,
      );
      return false;
    } catch (e) {
      _logDebug(
        'Unknown error sending AI chat feedback snapshot: $e | requestId=$requestId',
        error: e,
      );
      return false;
    }
  }

  Future<bool> sendAIChatTurnDebug({
    required Map<String, Object?> payload,
    String? requestId,
  }) async {
    try {
      if (_workerBaseUrl.isEmpty) return false;

      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/ai-chat-turn-debug',
        requestId: requestId,
      );
      if (headers == null) return false;

      final response = await _dio.post(
        _buildWorkerUrl('/api/ai-chat-turn-debug'),
        data: payload,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      return response.statusCode == 200 || response.statusCode == 202;
    } on DioException catch (dioErr) {
      _logDebug(
        'Dio networking error sending AI chat turn debug: ${dioErr.message} | requestId=$requestId',
        error: dioErr,
      );
      return false;
    } catch (e) {
      _logDebug(
        'Unknown error sending AI chat turn debug: $e | requestId=$requestId',
        error: e,
      );
      return false;
    }
  }

  Future<List<AIChatStoredMessage>> _loadPersistedSessionTranscript(
    String sessionId,
  ) async {
    final snapshot = await _resolvedFirestore
        .collection(AIChatCollectionNames.messages)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AIChatStoredMessage.fromJson(doc.data()))
        .toList();
  }

  AnalysisTranscriptPayload _buildAnalysisPayloadFromStoredTranscript({
    required String sessionId,
    required List<AIChatStoredMessage> transcript,
    required SessionPreferences preferences,
  }) {
    final compacted = <AnalysisTranscriptEntry>[];
    AIChatStoredMessage? finalRecommendation;

    for (final message in transcript) {
      if (message.messageType == AIChatMessageType.loading) {
        continue;
      }

      final text = message.content.trim();

      if (message.role == AIChatMessageRole.user) {
        if (text.isEmpty) continue;
        compacted.add(
          AnalysisTranscriptEntry(
            role: 'user',
            messageType: 'text',
            content: text,
          ),
        );
        continue;
      }

      if (message.messageType == AIChatMessageType.recommendation) {
        finalRecommendation = message;
        final shortSummary = _shortRecommendationSummary(text);
        compacted.add(
          AnalysisTranscriptEntry(
            role: 'assistant',
            messageType: 'recommendation',
            productIds: message.productIds
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList(),
            matchSummary: shortSummary,
          ),
        );
        continue;
      }

      if (message.messageType == AIChatMessageType.availability) {
        if (text.isEmpty || _isBoilerplateAssistantText(text)) {
          continue;
        }

        compacted.add(
          AnalysisTranscriptEntry(
            role: 'assistant',
            messageType: 'availability',
            content: _clipText(text, maxLength: 280),
            productIds: message.productIds
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList(),
          ),
        );
        continue;
      }

      if (text.isEmpty || _isBoilerplateAssistantText(text)) {
        continue;
      }

      compacted.add(
        AnalysisTranscriptEntry(
          role: 'assistant',
          messageType: message.messageType == AIChatMessageType.error
              ? 'error'
              : 'text',
          content: _clipText(text, maxLength: 280),
        ),
      );
    }

    final finalRecommendationProductIds = finalRecommendation == null
        ? const <String>[]
        : finalRecommendation.productIds
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

    return AnalysisTranscriptPayload(
      sessionId: sessionId,
      preferences: _sanitizeMap(preferences.toJson()),
      entries: compacted,
      originalMessageCount: transcript.length,
      compactedMessageCount: compacted.length,
      finalRecommendationMessageId: finalRecommendation?.id,
      finalRecommendationProductIds: finalRecommendationProductIds,
    );
  }

  AnalysisTranscriptPayload _buildAnalysisPayloadFromUiTranscript({
    required String sessionId,
    required List<AIChatMessage> transcript,
    required SessionPreferences preferences,
  }) {
    final compacted = <AnalysisTranscriptEntry>[];
    AIChatMessage? finalRecommendation;

    for (final message in transcript) {
      if (message.isLoading) {
        continue;
      }

      final text = message.content.trim();

      if (message.isFromUser) {
        if (text.isEmpty) continue;
        compacted.add(
          AnalysisTranscriptEntry(
            role: 'user',
            messageType: 'text',
            content: text,
          ),
        );
        continue;
      }

      if (message.isRecommendation) {
        finalRecommendation = message;
        final productIds = message.recommendedProducts
            .map((product) => product.product.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        final shortSummary = _shortRecommendationSummary(text);
        compacted.add(
          AnalysisTranscriptEntry(
            role: 'assistant',
            messageType: 'recommendation',
            productIds: productIds,
            matchSummary: shortSummary,
          ),
        );
        continue;
      }

      if (message.isAvailability) {
        if (text.isEmpty || _isBoilerplateAssistantText(text)) {
          continue;
        }

        compacted.add(
          AnalysisTranscriptEntry(
            role: 'assistant',
            messageType: 'availability',
            content: _clipText(text, maxLength: 280),
            productIds: message.recommendedProducts
                .map((product) => product.product.id.trim())
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList(),
          ),
        );
        continue;
      }

      if (text.isEmpty || _isBoilerplateAssistantText(text)) {
        continue;
      }

      compacted.add(
        AnalysisTranscriptEntry(
          role: 'assistant',
          messageType: message.type == MessageType.error ? 'error' : 'text',
          content: _clipText(text, maxLength: 280),
        ),
      );
    }

    final finalRecommendationProductIds =
        (finalRecommendation?.recommendedProducts ??
                const <RecommendedProduct>[])
            .map((product) => product.product.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    return AnalysisTranscriptPayload(
      sessionId: sessionId,
      preferences: _sanitizeMap(preferences.toJson()),
      entries: compacted,
      originalMessageCount: transcript.length,
      compactedMessageCount: compacted.length,
      finalRecommendationMessageId: finalRecommendation?.id,
      finalRecommendationProductIds: finalRecommendationProductIds,
    );
  }

  bool _isBoilerplateAssistantText(String text) {
    final normalized = _normalizeBoilerplateText(text);
    if (normalized.isEmpty) return true;

    const markers = <String>[
      'welcome to the perfume assistant',
      'tell me the style, notes, or budget',
      'hello! tell me your preferences',
      'Ш§Щ‡Щ„Ш§ ШЁЩѓ ЩЃЩЉ Щ…ШіШ§Ш№ШЇ Ш§Щ„Ш№Ш·Щ€Ш±',
      'ШЈЩ‡Щ„Ш§Щ‹ ШЁЩѓ ЩЃЩЉ Щ…ШіШ§Ш№ШЇ Ш§Щ„Ш№Ш·Щ€Ш±',
      'Ш§Ш®ШЁШ±Щ†ЩЉ ШЁШ§Щ„Щ†Щ€Ш№ Ш§Щ€ Ш§Щ„Щ†Щ€ШЄШ§ШЄ Ш§Щ€ Ш§Щ„Щ…ЩЉШІШ§Щ†ЩЉШ©',
      'Щ‚Щ„Щ‘ЩЉ ШЄЩЃШ¶ЩЉЩ„Ш§ШЄЩѓ',
      'Щ‚Щ„Щ‘ЩЉ ШЄЩЃШ¶ЩЉЩ„Ш§ШЄЩѓ Щ…Ш«Щ„ Ш§Щ„Щ†Щ€Ш№',
      'typing...',
      'thinking...',
    ];

    return markers.any((marker) => normalized.contains(marker));
  }

  String _normalizeBoilerplateText(String value) {
    final lower = value.toLowerCase();
    final withoutPunctuation = lower.replaceAll(
      RegExp(r'[^\w\s\u0600-\u06FF]'),
      ' ',
    );
    final collapsedSpaces = withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ');
    return collapsedSpaces.trim();
  }

  String? _shortRecommendationSummary(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    if (_isBoilerplateAssistantText(cleaned)) return null;
    if (cleaned.length > 180) return null;
    return cleaned;
  }

  String _clipText(String value, {required int maxLength}) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  Future<void> createSession({
    required String sessionId,
    required AIChatLanguage language,
    DateTime? startedAt,
    String? userId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty.');
    }
    final persistenceUserId = _resolvePersistenceUserId(userId);
    if (persistenceUserId == null || persistenceUserId.isEmpty) {
      _logDebug(
        'AI chat session persistence skipped: guest_local_session | sessionId=$normalizedSessionId',
      );
      return;
    }

    final session = AIChatSession(
      id: normalizedSessionId,
      userId: persistenceUserId,
      language: language.code,
      status: AIChatSessionStatus.active,
      startedAt: (startedAt ?? _now()).toUtc(),
      messageCount: 0,
      endedAt: null,
      finalRecommendationMessageId: null,
    );

    await _resolvedFirestore
        .collection(AIChatCollectionNames.sessions)
        .doc(normalizedSessionId)
        .set(session.toJson(), SetOptions(merge: true));
  }

  Future<void> appendMessage({
    required AIChatMessage message,
    String? sessionId,
  }) async {
    if (message.isLoading) return;
    if (!canPersistSession) {
      _logDebug('AI chat message persistence skipped: auth_not_ready.');
      return;
    }

    final normalizedSessionId = (sessionId?.trim().isNotEmpty == true
        ? sessionId!.trim()
        : (_currentSessionId ?? '').trim());
    if (normalizedSessionId.isEmpty) {
      throw StateError('appendMessage requires an active sessionId.');
    }

    final payload = AIChatStoredMessage(
      id: message.id,
      sessionId: normalizedSessionId,
      role: _toStoredRole(message.sender),
      content: message.content,
      messageType: _toStoredType(message.type),
      productIds: message.isRecommendation || message.isAvailability
          ? message.recommendedProducts.map((item) => item.product.id).toList()
          : const <String>[],
      createdAt: message.timestamp.toUtc(),
    );

    final docId = '${normalizedSessionId}_${message.id}';
    await _resolvedFirestore
        .collection(AIChatCollectionNames.messages)
        .doc(docId)
        .set(payload.toJson(), SetOptions(merge: true));
  }

  Future<void> completeSession({
    required String sessionId,
    required int messageCount,
    String? finalRecommendationMessageId,
    DateTime? endedAt,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;
    if (!canPersistSession) {
      _logDebug('AI chat session completion skipped: auth_not_ready.');
      return;
    }

    await _resolvedFirestore
        .collection(AIChatCollectionNames.sessions)
        .doc(normalizedSessionId)
        .set({
          '_schemaVersion': 1,
          'status': 'ended',
          'endedAt': Timestamp.fromDate((endedAt ?? _now()).toUtc()),
          'messageCount': messageCount,
          'finalRecommendationMessageId':
              finalRecommendationMessageId?.trim().isNotEmpty == true
              ? finalRecommendationMessageId!.trim()
              : null,
        }, SetOptions(merge: true));
  }

  String _buildWorkerUrl(String path) => '$_workerBaseUrl$path';

  Future<Map<String, dynamic>?> _buildAuthenticatedWorkerHeaders({
    String? requestId,
    required String endpoint,
    bool forceRefresh = false,
  }) async {
    final user = _resolvedAuth.currentUser;
    if (user == null) {
      if (_allowGuestWorkerRequests) {
        _lastWorkerFailureReasonCode = null;
        _logDebug(
          'AI worker auth bypassed: guest_allowed | endpoint=$endpoint | requestId=$requestId',
        );
        return <String, dynamic>{'Content-Type': 'application/json'};
      }

      _lastWorkerFailureReasonCode = 'worker_auth_required';
      _logDebug(
        'AI worker skipped: auth_required | endpoint=$endpoint | requestId=$requestId',
      );
      return null;
    }

    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.trim().isEmpty) {
      if (_allowGuestWorkerRequests) {
        _lastWorkerFailureReasonCode = null;
        _logDebug(
          'AI worker auth bypassed: token_missing_guest_allowed | endpoint=$endpoint | requestId=$requestId',
        );
        return <String, dynamic>{'Content-Type': 'application/json'};
      }

      _lastWorkerFailureReasonCode = 'worker_auth_token_missing';
      _logDebug(
        'AI worker skipped: token_missing | endpoint=$endpoint | requestId=$requestId',
      );
      return null;
    }

    return <String, dynamic>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${idToken.trim()}',
    };
  }

  Future<AIChatInterpretationResult?> fetchAIInterpretation({
    required String currentMessage,
    required SessionPreferences currentPreferences,
    required AIChatLanguage responseLanguage,
    required bool hasRecommendationContext,
    required bool hasAvailabilityContext,
    String? requestId,
  }) async {
    try {
      if (_workerBaseUrl.isEmpty) return null;
      if (_isWorkerCircuitOpen()) {
        _logDebug(
          'AI interpretation worker skipped: circuit_open | requestId=$requestId',
        );
        return null;
      }

      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/interpret',
        requestId: requestId,
      );
      if (headers == null) return null;

      _logDebug(
        'Calling AI interpretation Worker | requestId=$requestId | '
        'language=${responseLanguage.code} | message="${_debugMessagePreview(currentMessage)}"',
      );

      final response = await _dio.post(
        _buildWorkerUrl('/api/interpret'),
        data: {
          'currentMessage': currentMessage,
          'currentPreferences': currentPreferences.toJson(),
          'hasRecommendationContext': hasRecommendationContext,
          'hasAvailabilityContext': hasAvailabilityContext,
          'sessionKey': _resolvedAuth.currentUser?.uid,
          'responseLanguage': responseLanguage.code,
          'requestId': requestId,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 14),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : Map<String, dynamic>.from(
              response.data is Map ? response.data as Map : {},
            );
      final result = AIChatInterpretationResult.fromJson(data);
      _recordWorkerSuccess();
      _logDebug(
        'AI interpretation received | requestId=$requestId | '
        'intent=${result.intent} | confidence=${result.confidence} | reason=${result.reasonCode}',
      );
      return result;
    } on DioException catch (dioErr) {
      _recordWorkerFailure(dioErr, requestId: requestId);
      _logDebug(
        'Dio networking error calling AI interpretation worker: ${dioErr.message} | requestId=$requestId',
        error: dioErr,
      );
      return null;
    } catch (error) {
      _logDebug(
        'Unknown error calling AI interpretation worker: $error | requestId=$requestId',
        error: error,
      );
      return null;
    }
  }

  // в”Ђв”Ђ Phase 2 Worker Integration в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  /// Sends the current message, session preferences, and filtered candidates
  /// to the Cloudflare Worker. Returns parsed reply or null on fail.
  Future<AIChatReply?> fetchAIRecommendation({
    required String currentMessage,
    required SessionPreferences preferences,
    required List<ProductModel> candidates,
    List<RecommendedProduct> localRecommendations = const [],
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) {
    return _fetchAIRecommendationInternal(
      currentMessage: currentMessage,
      preferences: preferences,
      candidates: candidates,
      localRecommendations: localRecommendations,
      responseLanguage: responseLanguage,
      requestId: requestId,
    );
  }

  /// Sends the worker request with PR6 compact conversation context.
  ///
  /// Kept separate from [fetchAIRecommendation] so old tests and v1 call sites
  /// keep the exact same method signature while the v2 context rollout is
  /// feature-flagged.
  Future<AIChatReply?> fetchAIRecommendationWithContext({
    required String currentMessage,
    required SessionPreferences preferences,
    required List<ProductModel> candidates,
    List<RecommendedProduct> localRecommendations = const [],
    required AIChatCompactConversationContext compactContext,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) {
    return _fetchAIRecommendationInternal(
      currentMessage: currentMessage,
      preferences: preferences,
      candidates: candidates,
      localRecommendations: localRecommendations,
      compactContext: compactContext,
      responseLanguage: responseLanguage,
      requestId: requestId,
    );
  }

  Future<AIChatReply?> _fetchAIRecommendationInternal({
    required String currentMessage,
    required SessionPreferences preferences,
    required List<ProductModel> candidates,
    List<RecommendedProduct> localRecommendations = const [],
    AIChatCompactConversationContext? compactContext,
    required AIChatLanguage responseLanguage,
    String? requestId,
  }) async {
    try {
      if (_workerBaseUrl.isEmpty) {
        _lastWorkerFailureReasonCode = 'worker_url_missing';
        log('AI chat worker URL is not configured.', name: 'AIChatRepo');
        return null;
      }
      if (_isWorkerCircuitOpen()) {
        _lastWorkerFailureReasonCode = 'worker_circuit_open';
        _logDebug(
          'AI worker skipped: reasonCode=worker_circuit_open | requestId=$requestId',
        );
        return null;
      }

      // 1. Simplify payload to save JSON size and AI tokens
      final recommendationsById = _recommendationByProductId(
        localRecommendations,
      );
      final simplifiedCandidates = candidates.take(15).map((p) {
        final localRecommendation = recommendationsById[p.id];
        final exactBudget = preferences.maxBudget;
        final overBudgetAmount =
            exactBudget != null && p.effectivePrice > exactBudget
            ? p.effectivePrice - exactBudget
            : null;
        final budgetStatus = overBudgetAmount != null
            ? 'slightlyAboveBudget'
            : 'withinBudget';
        return {
          'id': p.id,
          'name': p.name,
          'price': p.effectivePrice,
          'originalPrice': p.price,
          'budgetStatus': budgetStatus,
          'exactBudget': exactBudget,
          'overBudgetAmount': overBudgetAmount,
          'gender': p.gender,
          'season': p.season,
          'occasion': p.occasion,
          'time': p.time,
          'intensity': p.intensity,
          'notes': p.notes,
          'topNotes': p.topNotes,
          'middleNotes': p.middleNotes,
          'baseNotes': p.baseNotes,
          'tags': p.tags,
          'localMatchReason': localRecommendation?.matchReason,
          'reasonFacts': _buildReasonFacts(
            product: p,
            preferences: preferences,
            recommendation: localRecommendation,
          ),
        };
      }).toList();

      final headers = await _buildAuthenticatedWorkerHeaders(
        endpoint: '/api/chat',
        requestId: requestId,
      );
      if (headers == null) return null;

      final payload = {
        'currentMessage': currentMessage,
        'preferences': preferences.toJson(),
        'candidates': simplifiedCandidates,
        if (compactContext != null) ...compactContext.toJson(),
        'sessionKey': _resolvedAuth.currentUser?.uid,
        'responseLanguage': responseLanguage.code,
        'requestId': requestId,
      };

      Future<Response<dynamic>> postToWorker(
        Map<String, dynamic> requestHeaders,
      ) {
        return _dio.post(
          _buildWorkerUrl('/api/chat'),
          data: payload,
          options: Options(
            headers: requestHeaders,
            sendTimeout: const Duration(seconds: _workerHttpTimeoutSeconds),
            receiveTimeout: const Duration(seconds: _workerHttpTimeoutSeconds),
          ),
        );
      }

      // 2. Call Cloudflare Worker
      _logDebug(
        'Calling AI model via Worker | requestId=$requestId | language=${responseLanguage.code} | '
        'messageLength=${currentMessage.trim().length} | message="${_debugMessagePreview(currentMessage)}" | '
        'candidateCount=${simplifiedCandidates.length} | prefs=${preferences.toJson()} | '
        'candidateIds=${simplifiedCandidates.map((p) => p['id']).toList()} | '
        'hasCompactContext=${compactContext != null}',
      );

      late final Response<dynamic> response;
      try {
        response = await postToWorker(headers);
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode != 401) rethrow;
        _logDebug(
          'AI worker returned 401; retrying once with refreshed Firebase token | requestId=$requestId',
          error: dioErr,
        );
        final refreshedHeaders = await _buildAuthenticatedWorkerHeaders(
          endpoint: '/api/chat',
          requestId: requestId,
          forceRefresh: true,
        );
        if (refreshedHeaders == null) rethrow;
        response = await postToWorker(refreshedHeaders);
      }

      // 3. Stringify the output and pass to standard validator
      if (response.statusCode == 200 && response.data != null) {
        _recordWorkerSuccess();
        _logDebug(
          'Worker response received | requestId=$requestId | status=${response.statusCode} | '
          'dataType=${response.data.runtimeType}',
        );
        // Callback that fires when the worker omits match_reason for recommended
        // products. Logs to Firestore so prompt drift is measurable over time.
        void onMissingReason(int count) {
          unawaited(
            logAIChatEvent(
              eventType: 'recommendation_model_fallback_reason',
              metadata: {
                'missing_count': count,
                'source': 'worker_response_validator',
              },
            ),
          );
        }

        if (response.data is Map<String, dynamic>) {
          final parsedReply = AIChatReplyValidator.parseMap(
            response.data as Map<String, dynamic>,
            language: responseLanguage,
            onMissingReasonCount: onMissingReason,
          );
          _logDebug(
            'Parsed worker map response | requestId=$requestId | parsedType=${parsedReply == null
                ? 'null'
                : parsedReply.isAsk
                ? 'ask'
                : parsedReply.isAnswer
                ? 'answer'
                : parsedReply.isToolCall
                ? 'tool_call'
                : 'recommend'}',
          );
          if (parsedReply == null) {
            _lastWorkerFailureReasonCode = 'worker_parse_error';
          }
          return parsedReply;
        } else {
          final parsedReply = AIChatReplyValidator.parseAndValidate(
            response.data.toString(),
            language: responseLanguage,
            onMissingReasonCount: onMissingReason,
          );
          _logDebug(
            'Parsed worker string response | requestId=$requestId | parsedType=${parsedReply == null
                ? 'null'
                : parsedReply.isAsk
                ? 'ask'
                : parsedReply.isAnswer
                ? 'answer'
                : parsedReply.isToolCall
                ? 'tool_call'
                : 'recommend'}',
          );
          if (parsedReply == null) {
            _lastWorkerFailureReasonCode = 'worker_parse_error';
          }
          return parsedReply;
        }
      } else {
        _lastWorkerFailureReasonCode = response.statusCode == null
            ? 'worker_http_error'
            : 'worker_http_${response.statusCode}';
        _logDebug(
          'AI worker returned non-200 status: ${response.statusCode} | requestId=$requestId | reasonCode=$_lastWorkerFailureReasonCode | data=${_shortText(response.data.toString(), maxLength: 240)}',
        );
      }
      return null;
    } on DioException catch (dioErr) {
      _recordWorkerFailure(dioErr, requestId: requestId);
      _logDebug(
        'Dio networking error calling AI worker: ${dioErr.message} | requestId=$requestId | reasonCode=$_lastWorkerFailureReasonCode | '
        'response=${_shortText(dioErr.response?.data?.toString() ?? '')}',
        error: dioErr,
      );
      return null;
    } catch (e) {
      _lastWorkerFailureReasonCode = 'worker_unknown_error';
      _logDebug(
        'Unknown error calling AI worker: $e | requestId=$requestId | reasonCode=$_lastWorkerFailureReasonCode',
        error: e,
      );
      return null;
    }
  }

  /// Saves a restock request for a specific product and user.
  /// Uses a composite ID `${userId}_${productId}` to ensure idempotency (no duplicates).
  Future<void> saveRestockRequest({
    required String productId,
    required String userId,
  }) async {
    try {
      final docId = '${userId}_$productId';
      final docRef = _resolvedFirestore
          .collection('restock_requests')
          .doc(docId);
      final user = _resolvedAuth.currentUser;
      final email = user?.email?.trim() ?? '';
      final phone = user?.phoneNumber?.trim() ?? '';
      final contactMethod = email.isNotEmpty
          ? RestockContactMethod.email
          : phone.isNotEmpty
          ? RestockContactMethod.phone
          : null;
      final contactValue = email.isNotEmpty ? email : phone;

      if (contactMethod == null || contactValue.isEmpty) {
        throw StateError(
          'Authenticated contact information is required for restock requests.',
        );
      }

      final productSnapshot = await _resolvedFirestore
          .collection('products')
          .doc(productId)
          .get();
      if (!productSnapshot.exists) {
        throw StateError('Product is not available for restock notification.');
      }

      final now = _now();
      try {
        await docRef.set(<String, dynamic>{
          'id': docId,
          'productId': productId,
          'userId': userId,
          'contactMethod': contactMethod.name,
          'contactValue': contactValue,
          'status': RestockRequestStatus.pending.name,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      } on FirebaseException {
        rethrow;
      }
      await logAIChatEvent(
        eventType: 'conversion_notify_requested',
        sessionId: _currentSessionId,
        userId: userId,
        metadata: {
          'productId': productId,
          'hasUserId': userId.trim().isNotEmpty,
        },
      );
      log(
        'Restock request saved for product $productId by user $userId',
        name: 'AIChatRepo',
      );
    } catch (e) {
      log('Error saving restock request: $e', name: 'AIChatRepo', error: e);
      rethrow;
    }
  }

  Future<void> logAIChatEvent({
    required String eventType,
    String? sessionId,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_shouldLogTelemetryEvent(eventType)) return;

    var uid = userId?.trim();
    if (uid == null || uid.isEmpty) {
      try {
        uid = _resolvedAuth.currentUser?.uid.trim();
      } catch (_) {
        return;
      }
    }

    if (uid == null || uid.isEmpty) return;

    final resolvedSessionId = sessionId?.trim().isNotEmpty == true
        ? sessionId!.trim()
        : (_currentSessionId?.trim() ?? '');
    if (resolvedSessionId.isEmpty) return;

    final resolvedMetadata = _sanitizeMap(
      metadata ?? const <String, dynamic>{},
    );

    try {
      await _resolvedFirestore.collection('ai_chat_events').add({
        'eventType': eventType,
        'userId': uid,
        'sessionId': resolvedSessionId,
        'metadata': resolvedMetadata,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        log(
          'AI chat event telemetry skipped: permission denied for ai_chat_events.',
          name: 'AIChatRepo',
        );
        return;
      }
      log('Error logging AI chat event: $e', name: 'AIChatRepo', error: e);
    } catch (e) {
      log('Error logging AI chat event: $e', name: 'AIChatRepo', error: e);
    }
  }

  bool _shouldLogTelemetryEvent(String eventType) {
    final normalizedEventType = eventType.trim();
    if (normalizedEventType.isEmpty) return false;
    if (_essentialTelemetryEvents.contains(normalizedEventType)) return true;
    return _nonCriticalTelemetryEnabled;
  }

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
  }) async {
    if (!_debugLogsEnabled) return;

    var uid = _resolvedAuth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) return;

    final resolvedSessionId = sessionId?.trim().isNotEmpty == true
        ? sessionId!.trim()
        : (_currentSessionId?.trim() ?? '');
    if (resolvedSessionId.isEmpty) return;

    final normalizedPhase = phase.trim();
    if (normalizedPhase.isEmpty) return;

    final now = _now().toUtc();
    final normalizedRequestId = requestId?.trim().isNotEmpty == true
        ? requestId!.trim()
        : 'unknown';
    final docId =
        '${resolvedSessionId}_${normalizedRequestId}_${normalizedPhase}_${now.microsecondsSinceEpoch}';

    final payload = <String, dynamic>{
      '_schemaVersion': 1,
      'id': docId,
      'sessionId': resolvedSessionId,
      'requestId': normalizedRequestId,
      'userId': uid,
      'createdAt': Timestamp.fromDate(now),
      'phase': normalizedPhase,
      'language': (language?.trim().isNotEmpty == true)
          ? language!.trim()
          : 'unknown',
      'messageText': messageText ?? '',
      'detectedIntent': detectedIntent ?? 'unknown',
      'responseSource': responseSource ?? 'unknown',
      'issueCode': issueCode,
      'reasonCode': reasonCode,
      'preferencesSnapshot': preferencesSnapshot,
      'availabilityContextSnapshot': availabilityContextSnapshot,
      'recommendationMemorySnapshot': recommendationMemorySnapshot,
      'candidateSummary': candidateSummary,
      'recommendedProducts': recommendedProducts,
      'workerReplySummary': workerReplySummary,
    };

    final sanitized = _sanitizeMap(payload);
    try {
      await _resolvedFirestore
          .collection(AIChatCollectionNames.debugLogs)
          .doc(docId)
          .set(sanitized, SetOptions(merge: true));
    } catch (e) {
      _logDebug('Error saving AI chat debug log: $e', error: e);
    }
  }

  Future<void> saveRecommendationFeedback({
    required AIChatFeedback feedback,
    String? userId,
  }) async {
    var uid = userId?.trim();
    if (uid == null || uid.isEmpty) {
      uid = _resolvedAuth.currentUser?.uid.trim();
    }
    if (uid == null || uid.isEmpty) {
      throw StateError('Authenticated user is required to save feedback.');
    }

    final normalizedSessionId = feedback.sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty.');
    }

    final normalizedMessageId = feedback.messageId.trim();
    if (normalizedMessageId.isEmpty) {
      throw ArgumentError('messageId cannot be empty.');
    }

    final cleanNote = feedback.note?.trim();
    final normalizedComment = (cleanNote == null || cleanNote.isEmpty)
        ? null
        : (cleanNote.length <= 280 ? cleanNote : cleanNote.substring(0, 280));

    final docId = '${uid}_${normalizedSessionId}_$normalizedMessageId';
    final docRef = _resolvedFirestore
        .collection(AIChatCollectionNames.feedback)
        .doc(docId);

    final unifiedFeedback = AIUnifiedFeedback.message(
      id: docId,
      sessionId: normalizedSessionId,
      userId: uid,
      targetMessageId: normalizedMessageId,
      isHelpful: feedback.isHelpful,
      comment: normalizedComment,
      submittedAt: _now(),
      analysisStatus: null,
    );
    final payload = unifiedFeedback.toJson();
    payload['submittedAt'] = FieldValue.serverTimestamp();

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<AIUnifiedFeedback> saveSessionFeedback({
    required String sessionId,
    required int rating,
    required bool isHelpful,
    String? comment,
    String? userId,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Session feedback rating must be between 1 and 5.');
    }

    var uid = userId?.trim();
    if (uid == null || uid.isEmpty) {
      uid = _resolvedAuth.currentUser?.uid.trim();
    }
    if (uid == null || uid.isEmpty) {
      throw StateError('Authenticated user is required to save feedback.');
    }

    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty.');
    }

    final cleanComment = comment?.trim();
    final normalizedComment = (cleanComment == null || cleanComment.isEmpty)
        ? null
        : (cleanComment.length <= 280
              ? cleanComment
              : cleanComment.substring(0, 280));

    final docId = '${uid}_${normalizedSessionId}_session';
    final docRef = _resolvedFirestore
        .collection(AIChatCollectionNames.feedback)
        .doc(docId);

    final unifiedFeedback = AIUnifiedFeedback.session(
      id: docId,
      sessionId: normalizedSessionId,
      userId: uid,
      rating: rating,
      isHelpful: isHelpful,
      comment: normalizedComment,
      submittedAt: _now(),
      analysisStatus: AIFeedbackAnalysisStatus.pending,
    );
    final payload = unifiedFeedback.toJson();
    payload['submittedAt'] = FieldValue.serverTimestamp();

    await docRef.set(payload, SetOptions(merge: true));
    return unifiedFeedback;
  }

  Future<void> saveFeedbackAnalysis({
    required AIFeedbackAnalysis analysis,
  }) async {
    final normalizedId = analysis.id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('analysis.id cannot be empty.');
    }

    final docRef = _resolvedFirestore
        .collection(AIChatCollectionNames.feedbackAnalysis)
        .doc(normalizedId);

    await docRef.set(analysis.toJson(), SetOptions(merge: true));
  }

  Future<void> updateFeedbackAnalysisStatus({
    required String feedbackId,
    required AIFeedbackAnalysisStatus status,
  }) async {
    final normalizedId = feedbackId.trim();
    if (normalizedId.isEmpty) return;

    await _resolvedFirestore
        .collection(AIChatCollectionNames.feedback)
        .doc(normalizedId)
        .set({
          'analysisStatus': _feedbackAnalysisStatusToString(status),
        }, SetOptions(merge: true));
  }

  String _feedbackAnalysisStatusToString(AIFeedbackAnalysisStatus status) {
    switch (status) {
      case AIFeedbackAnalysisStatus.completed:
        return 'completed';
      case AIFeedbackAnalysisStatus.failed:
        return 'failed';
      case AIFeedbackAnalysisStatus.pendingRetry:
        return 'pending_retry';
      case AIFeedbackAnalysisStatus.pending:
        return 'pending';
    }
  }

  Future<bool> hasSessionFeedback({
    required String sessionId,
    String? userId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return false;

    var uid = userId?.trim();
    if (uid == null || uid.isEmpty) {
      uid = _resolvedAuth.currentUser?.uid.trim();
    }
    if (uid == null || uid.isEmpty) return false;

    final docId = '${uid}_${normalizedSessionId}_session';
    final snapshot = await _resolvedFirestore
        .collection(AIChatCollectionNames.feedback)
        .doc(docId)
        .get();

    if (!snapshot.exists) return false;
    final data = snapshot.data();
    if (data == null) return false;
    return (data['feedbackScope'] ?? '').toString() == 'session';
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};

    for (final entry in map.entries) {
      final value = _sanitizeValue(entry.value);
      if (value != null) {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null ||
        value is String ||
        value is bool ||
        value is int ||
        value is double) {
      return value;
    }

    if (value is num) return value.toDouble();
    if (value is DateTime) return Timestamp.fromDate(value);

    if (value is Map) {
      final nested = <String, dynamic>{};
      for (final entry in value.entries) {
        final nestedValue = _sanitizeValue(entry.value);
        if (nestedValue != null) {
          nested[entry.key.toString()] = nestedValue;
        }
      }
      return nested;
    }

    if (value is Iterable) {
      return value.map(_sanitizeValue).where((item) => item != null).toList();
    }

    return value.toString();
  }
}
