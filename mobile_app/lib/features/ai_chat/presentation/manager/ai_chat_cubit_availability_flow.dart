part of 'ai_chat_cubit.dart';

extension AIChatCubitAvailabilityFlow on AIChatCubit {
  String _normalizeAvailabilityText(String text) {
    return AIChatTextNormalizer.normalizeForParsing(text);
  }

  Future<bool> _tryHandleAvailabilityContextAnswer(
    String message, {
    required List<ProductModel> catalog,
    required AIChatLanguage language,
    required String sessionId,
    required bool pruneHistoricalBotMessages,
  }) async {
    final externalCandidates = state.availabilityContext.externalCandidates;
    if (state.availabilityContext.availabilityStatus ==
            AvailabilityStatus.ambiguous &&
        externalCandidates.isNotEmpty) {
      final selectedCandidate = _resolveExternalCandidateSelection(
        message,
        externalCandidates,
      );
      if (selectedCandidate == null) {
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: buildExternalPerfumeStillAmbiguousMessage(
              language,
              externalCandidates,
            ),
            updatedPreferences: state.preferences,
          ),
          language: language,
          source: 'perfume_knowledge_external_ambiguous',
          issueCode: 'perfume_knowledge_external_ambiguous',
          reasonCode: 'external_candidate_unclear',
          sessionId: sessionId,
          availabilityContext: state.availabilityContext,
          pruneHistoricalBotMessages: pruneHistoricalBotMessages,
        );
        return true;
      }

      final resolvedProfile = await _aiChatRepo
          .resolveExternalPerfumeKnowledgeCandidate(
            candidate: selectedCandidate,
            requestId: const Uuid().v4(),
          );
      if (resolvedProfile == null) {
        _handleUnknownAvailability(
          query: selectedCandidate.displayName,
          language: language,
          sessionId: sessionId,
        );
        return true;
      }

      final profile = AvailabilityReferenceProfile.fromKnowledge(
        resolvedProfile,
      );
      _handleKnownProfileAvailability(
        query: selectedCandidate.displayName,
        language: language,
        sessionId: sessionId,
        catalog: catalog,
        profile: profile,
        eventSource: 'external_lookup_resolve',
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'perfume_knowledge_external_candidate_resolved',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: selectedCandidate.displayName,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            confidence: profile.lookupConfidence,
          ),
        ),
      );
      return true;
    }

    final matchedProductId = state.availabilityContext.matchedProductId;
    if (matchedProductId == null) return false;

    final matchedAvailabilityProduct = catalog
        .where((product) => product.id == matchedProductId)
        .firstOrNull;
    if (matchedAvailabilityProduct == null) return false;

    if (looksLikeProductWhyFollowUp(message)) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: buildWhyProductFollowUpAnswer(
            matchedAvailabilityProduct,
            language,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_product_why',
        sessionId: sessionId,
        availabilityContext: state.availabilityContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    if (looksLikeProductDetailsFollowUp(message)) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: buildProductDetailsFollowUpAnswer(
            matchedAvailabilityProduct,
            language,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_product_details',
        sessionId: sessionId,
        availabilityContext: state.availabilityContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    return false;
  }

  ExternalPerfumeCandidate? _resolveExternalCandidateSelection(
    String message,
    List<ExternalPerfumeCandidate> candidates,
  ) {
    final normalized = _normalizeAvailabilityText(message);
    if (normalized.isEmpty) return null;

    if (candidates.length == 1 &&
        _isAffirmativeCandidateSelection(normalized)) {
      return candidates.first;
    }

    final ordinal = _ordinalSelectionIndex(normalized);
    if (ordinal != null && ordinal >= 0 && ordinal < candidates.length) {
      return candidates[ordinal];
    }

    final matches = candidates
        .where((candidate) {
          final displayName = _normalizeAvailabilityText(candidate.displayName);
          final label = _normalizeAvailabilityText(candidate.label);
          if (displayName == normalized || label == normalized) return true;
          if (normalized.length >= 3 &&
              (displayName.contains(normalized) ||
                  label.contains(normalized))) {
            return true;
          }
          return false;
        })
        .toList(growable: false);

    if (matches.length == 1) return matches.first;
    return null;
  }

  bool _isAffirmativeCandidateSelection(String normalized) {
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    const affirmativeAnswers = {
      'yes',
      'y',
      'yeah',
      'yep',
      'sure',
      'ok',
      'okay',
      'correct',
      'right',
      'confirm',
      'confirmed',
      'that one',
      'this one',
      'اه',
      'أه',
      'ايوه',
      'أيوه',
      'نعم',
      'تمام',
      'صح',
      'مظبوط',
      'ده',
      'دا',
    };
    return affirmativeAnswers.contains(compact);
  }

  int? _ordinalSelectionIndex(String normalized) {
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(r'^(1|one|first|option 1|number 1|#1)$').hasMatch(compact) ||
        compact == '١' ||
        compact == 'الأول' ||
        compact == 'اول' ||
        compact == 'اول واحد') {
      return 0;
    }
    if (RegExp(r'^(2|two|second|option 2|number 2|#2)$').hasMatch(compact) ||
        compact == '٢' ||
        compact == 'الثاني' ||
        compact == 'التاني' ||
        compact == 'تاني واحد') {
      return 1;
    }
    if (RegExp(r'^(3|three|third|option 3|number 3|#3)$').hasMatch(compact) ||
        compact == '٣' ||
        compact == 'الثالث' ||
        compact == 'التالت' ||
        compact == 'تالت واحد') {
      return 2;
    }
    return null;
  }

  bool _shouldContinueAvailabilityClarification(
    String message,
    AIChatIntent intent,
  ) {
    if (intent != AIChatIntent.newRecommendation) return false;
    if (!state.availabilityContext.hasContext) return false;

    final status = state.availabilityContext.availabilityStatus;
    final awaitingClarification =
        status == AvailabilityStatus.ambiguous ||
        status == AvailabilityStatus.notFoundUnknown ||
        status == AvailabilityStatus.notFoundKnownProfile;
    if (!awaitingClarification) return false;

    return AvailabilityIntentUtils.extractAvailabilityProductQuery(message) !=
        null;
  }

  Future<void> _handleAvailabilityFollowUpIntent({
    required String message,
    required AIChatLanguage language,
    required String sessionId,
  }) async {
    final catalog = await _aiChatRepo.getCatalog();
    final context = resolveAvailabilityContextForFollowUp(
      message: message,
      catalog: catalog,
      currentAvailabilityContext: state.availabilityContext,
      recommendationMemory: state.recommendationMemory,
      availabilityHintsFromProduct: availabilityHintsFromProduct,
      availabilityHintsFromProfile: availabilityHintsFromProfile,
    );

    if (context == null) {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityUnknownClarificationMessage(language),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_followup_missing_context',
        sessionId: sessionId,
      );
      return;
    }

    final substitutes = AvailabilitySubstituteEngine.findSubstitutes(
      context: context,
      catalog: catalog,
      currentPreferences: state.preferences,
    );

    final targetName = context.matchedProductName ?? context.lastQuery.trim();
    final normalizedTarget = targetName.isEmpty
        ? _t(language, ar: 'العطر المطلوب', en: 'the requested perfume')
        : targetName;

    final prefersCheaper = prefersCheaperAvailabilityAlternative(message);
    final targetPrice = catalog
        .where((product) => product.id == context.matchedProductId)
        .map((product) => product.effectivePrice)
        .firstOrNull;
    var suggestions = substitutes.suggestions;
    if (prefersCheaper && targetPrice != null) {
      final cheaperSuggestions = suggestions
          .where((item) => item.product.effectivePrice < targetPrice)
          .toList(growable: false);
      if (cheaperSuggestions.isNotEmpty) {
        suggestions = cheaperSuggestions;
      }
    }

    final explicitClosestRequest =
        AvailabilityIntentUtils.looksLikeClosestAvailabilityAlternativeRequest(
          message,
        );
    final allowExplicitClosestFallback =
        explicitClosestRequest &&
        suggestions.isNotEmpty &&
        suggestions.first.hasMeaningfulOverlap &&
        substitutes.bestScore >=
            AvailabilitySubstituteEngine
                .minimumExplicitClosestFallbackThreshold;

    if (suggestions.isEmpty ||
        (!substitutes.meetsConfidenceThreshold &&
            !allowExplicitClosestFallback)) {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityLowConfidenceFallbackMessage(
            language,
            normalizedTarget,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_followup_low_confidence',
        sessionId: sessionId,
        availabilityContext: context,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_followup_substitute',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: context.lastQuery,
            status: context.availabilityStatus,
            matchedProductId: context.matchedProductId,
            referenceProfileKey: context.referenceProfileKey,
            confidence: substitutes.bestScore,
          ),
        ),
      );
      return;
    }

    final substituteProducts = buildAvailabilitySubstituteProducts(
      suggestions,
      language,
    );
    var messageText = _t(
      language,
      ar: 'أقرب حاجة متوفرة شبه $normalizedTarget هي ${substitutes.suggestions.first.product.name}.',
      en: 'The closest available option similar to $normalizedTarget is ${substitutes.suggestions.first.product.name}.',
    );

    if (allowExplicitClosestFallback && !substitutes.meetsConfidenceThreshold) {
      messageText = _t(
        language,
        ar: 'أقرب بديل متاح عندنا لـ $normalizedTarget هو ${suggestions.first.product.name}. ليس مطابقًا تمامًا، لكنه الأقرب في الطابع المتاح حاليًا.',
        en: 'The closest available option we have to $normalizedTarget is ${suggestions.first.product.name}. It is not an exact match, but it is the closest available profile in the catalog.',
      );
    }

    if (prefersCheaper) {
      messageText = _t(
        language,
        ar: 'أقرب بديل مشابه وأقل في السعر لـ $normalizedTarget هو ${suggestions.first.product.name}.',
        en: 'A similar lower-priced alternative to $normalizedTarget is ${suggestions.first.product.name}.',
      );
    }

    _replyHandler.handleAvailabilityCardReply(
      AIChatMessage.botAvailability(
        content: messageText,
        products: substituteProducts,
      ),
      language: language,
      source: 'availability_followup_substitute',
      sessionId: sessionId,
      availabilityContext: context,
    );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_followup_substitute',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: context.lastQuery,
          status: context.availabilityStatus,
          matchedProductId: context.matchedProductId,
          referenceProfileKey: context.referenceProfileKey,
          substituteProductIds: substituteProducts
              .map((item) => item.product.id)
              .toList(),
          confidence: substitutes.bestScore,
        ),
      ),
    );
  }

  Future<void> _handleAvailabilityIntent({
    required String message,
    required AIChatLanguage language,
    required String sessionId,
  }) async {
    final query =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(message) ??
        AvailabilityIntentUtils.extractRedirectedProductQuery(
          message,
          hasRecommendationContext:
              state.recommendationMemory.lastRecommendedProducts.isNotEmpty,
        );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_check',
        sessionId: sessionId,
        metadata: {
          'language': language.code,
          'query': availabilityQueryForAnalytics(query),
          'queryLength': query?.trim().length ?? 0,
          'matchType': 'none',
          'stockState': 'unknown',
        },
      ),
    );

    if (query == null) {
      _handleAvailabilityMissingQuery(
        message: message,
        language: language,
        sessionId: sessionId,
      );
      return;
    }

    final catalog = await _aiChatRepo.getCatalog();
    final lookupResult = lookupAvailability(query, catalog);
    final normalizedQuery = _normalizeAvailabilityText(query);
    final queryTokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);

    if (lookupResult.isAmbiguous) {
      final options = lookupResult.options;
      final availabilityContext = AvailabilityContext(
        lastQuery: query,
        availabilityStatus: AvailabilityStatus.ambiguous,
        candidateOptionIds: options.map((item) => item.id).toList(),
        source: 'catalog_match',
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityAmbiguousMessage(language, query, options),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_ambiguous',
        issueCode: 'availability_ambiguous_name',
        reasonCode: 'availability_ambiguous_name',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_ambiguous_name',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.ambiguous,
            substituteProductIds: options.map((item) => item.id).toList(),
          ),
        ),
      );
      return;
    }

    if (lookupResult.product != null) {
      _handleFoundAvailabilityMatch(
        query: query,
        language: language,
        sessionId: sessionId,
        catalog: catalog,
        lookupResult: lookupResult,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
      );
      return;
    }

    var knowledgeProfile = await _aiChatRepo.lookupPerfumeKnowledge(query);
    if (knowledgeProfile != null) {
      if (_shouldRefreshPerfumeKnowledgeProfile(knowledgeProfile)) {
        final refreshedResult = await _aiChatRepo
            .lookupExternalPerfumeKnowledgeResult(
              query: query,
              responseLanguage: language,
              requestId: const Uuid().v4(),
            );
        final refreshedProfile = refreshedResult.profile;
        if (refreshedProfile != null) {
          knowledgeProfile = refreshedProfile;
          unawaited(
            _aiChatRepo.logAIChatEvent(
              eventType: 'perfume_knowledge_external_lookup_success',
              sessionId: sessionId,
              metadata: buildAvailabilityAnalyticsMetadata(
                query: query,
                status: AvailabilityStatus.notFoundKnownProfile,
                referenceProfileKey: refreshedProfile.id,
                confidence: refreshedProfile.lookupConfidence,
              ),
            ),
          );
        } else if (refreshedResult.isAmbiguous) {
          _handleExternalPerfumeAmbiguous(
            query: query,
            language: language,
            sessionId: sessionId,
            candidates: refreshedResult.candidates,
          );
          return;
        }
      }
      final profile = AvailabilityReferenceProfile.fromKnowledge(
        knowledgeProfile,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'perfume_knowledge_hit',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            confidence: profile.lookupConfidence,
          ),
        ),
      );
      _handleKnownProfileAvailability(
        query: query,
        language: language,
        sessionId: sessionId,
        catalog: catalog,
        profile: profile,
        eventSource: 'perfume_knowledge',
      );
      return;
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'perfume_knowledge_miss',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.notFoundUnknown,
        ),
      ),
    );

    final staticProfile = AvailabilityReferenceProfileRegistry.resolveByMessage(
      query,
    );
    if (staticProfile != null) {
      _handleKnownProfileAvailability(
        query: query,
        language: language,
        sessionId: sessionId,
        catalog: catalog,
        profile: staticProfile,
        eventSource: 'static_reference_profile',
      );
      return;
    }

    final externalResult = await _aiChatRepo
        .lookupExternalPerfumeKnowledgeResult(
          query: query,
          responseLanguage: language,
          requestId: const Uuid().v4(),
        );
    if (externalResult.isAmbiguous) {
      _handleExternalPerfumeAmbiguous(
        query: query,
        language: language,
        sessionId: sessionId,
        candidates: externalResult.candidates,
      );
      return;
    }
    final externalProfile = externalResult.profile;
    if (externalProfile != null) {
      final profile = AvailabilityReferenceProfile.fromKnowledge(
        externalProfile,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'perfume_knowledge_external_lookup_success',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            confidence: profile.lookupConfidence,
          ),
        ),
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'perfume_knowledge_saved_needs_review',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            confidence: profile.lookupConfidence,
          ),
        ),
      );
      _handleKnownProfileAvailability(
        query: query,
        language: language,
        sessionId: sessionId,
        catalog: catalog,
        profile: profile,
        eventSource: 'external_lookup',
      );
      return;
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'perfume_knowledge_external_lookup_failed',
        sessionId: sessionId,
        metadata: {
          ...buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundUnknown,
          ),
          'reason': externalResult.reason,
        },
      ),
    );

    if (queryTokens.length == 1 && queryTokens.first.length >= 3) {
      final brandLikeMatches = _catalogOptionsForBroadQuery(query, catalog);
      if (brandLikeMatches.length == 1) {
        final product = brandLikeMatches.single;
        _handleFoundAvailabilityMatch(
          query: query,
          language: language,
          sessionId: sessionId,
          catalog: catalog,
          lookupResult: AvailabilityLookupResult.found(
            product: product,
            matchType: AvailabilityMatchType.partial,
            stockState: product.stock > 0
                ? AvailabilityStockState.inStock
                : AvailabilityStockState.outOfStock,
          ),
          normalizedQuery: normalizedQuery,
          queryTokens: queryTokens,
        );
        return;
      }
      if (brandLikeMatches.isEmpty) {
        _handleUnknownAvailability(
          query: query,
          language: language,
          sessionId: sessionId,
          externalLookupFailed: _isExternalLookupFailure(externalResult.reason),
        );
        return;
      }
      final availabilityContext = AvailabilityContext(
        lastQuery: query,
        availabilityStatus: AvailabilityStatus.ambiguous,
        candidateOptionIds: brandLikeMatches.map((item) => item.id).toList(),
        source: 'catalog_match',
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityCatalogOptionsClarificationMessage(
            language,
            query,
            brandLikeMatches,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_ambiguous',
        issueCode: 'availability_ambiguous_name',
        reasonCode: 'availability_ambiguous_name',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_ambiguous_name',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.ambiguous,
            substituteProductIds: brandLikeMatches
                .map((item) => item.id)
                .toList(),
          ),
        ),
      );
      return;
    }

    _handleUnknownAvailability(
      query: query,
      language: language,
      sessionId: sessionId,
      externalLookupFailed: _isExternalLookupFailure(externalResult.reason),
    );
  }

  Future<bool> _tryHandleProductKnowledgeQuestion({
    required String message,
    required List<ProductModel> catalog,
    required AIChatLanguage language,
    required String sessionId,
    required bool pruneHistoricalBotMessages,
  }) async {
    final query = _extractProductKnowledgeQuestionQuery(message);
    if (query == null) return false;

    var lookupResult = lookupAvailability(query, catalog);
    var effectiveQuery = query;
    if (!lookupResult.isAmbiguous && lookupResult.product == null) {
      final interpretedQuery = await _interpretProductKnowledgeQuery(
        message: message,
        fallbackQuery: query,
        language: language,
      );
      if (interpretedQuery != null) {
        final interpretedLookup = lookupAvailability(interpretedQuery, catalog);
        if (interpretedLookup.isAmbiguous ||
            interpretedLookup.product != null) {
          lookupResult = interpretedLookup;
          effectiveQuery = interpretedQuery;
        }
      }
    }

    if (lookupResult.isAmbiguous) {
      final options = lookupResult.options;
      final availabilityContext = AvailabilityContext(
        lastQuery: effectiveQuery,
        availabilityStatus: AvailabilityStatus.ambiguous,
        candidateOptionIds: options.map((item) => item.id).toList(),
        source: 'catalog_knowledge_question',
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildAvailabilityAmbiguousMessage(
            language,
            effectiveQuery,
            options,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'product_knowledge_ambiguous',
        issueCode: 'product_knowledge_ambiguous',
        reasonCode: 'product_knowledge_ambiguous',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    final product = lookupResult.product;
    if (product != null) {
      final availabilityContext = AvailabilityContext(
        lastQuery: effectiveQuery,
        matchedProductId: product.id,
        matchedProductName: product.name,
        availabilityStatus: product.stock > 0
            ? AvailabilityStatus.found
            : AvailabilityStatus.outOfStock,
        hints: availabilityHintsFromProduct(product),
        source: 'catalog_knowledge_question',
      );
      _replyHandler.handleAvailabilityCardReply(
        AIChatMessage.botAvailability(
          content: buildKnownCatalogProductIntroAnswer(product, language),
          products: [buildAvailabilityCardProduct(product, language)],
        ),
        language: language,
        source: 'product_knowledge_catalog',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'product_knowledge_catalog_answer',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: effectiveQuery,
            status: product.stock > 0
                ? AvailabilityStatus.found
                : AvailabilityStatus.outOfStock,
            matchedProductId: product.id,
          ),
        ),
      );
      return true;
    }

    final profile = await _resolveProductKnowledgeProfile(
      effectiveQuery,
      language,
    );
    if (profile == null) return false;

    if (_tryHandleCatalogProductFromKnownProfile(
      query: effectiveQuery,
      language: language,
      sessionId: sessionId,
      catalog: catalog,
      profile: profile,
      eventSource: 'product_knowledge_profile_catalog',
    )) {
      return true;
    }

    _handleKnownProfileAvailability(
      query: effectiveQuery,
      language: language,
      sessionId: sessionId,
      catalog: catalog,
      profile: profile,
      eventSource: 'product_knowledge_question',
    );
    return true;
  }

  Future<String?> _interpretProductKnowledgeQuery({
    required String message,
    required String fallbackQuery,
    required AIChatLanguage language,
  }) async {
    final result = await _aiChatRepo.fetchAIInterpretation(
      currentMessage: message,
      currentPreferences: state.preferences,
      responseLanguage: language,
      hasRecommendationContext:
          state.recommendationMemory.lastRecommendedProducts.isNotEmpty,
      hasAvailabilityContext: state.availabilityContext.hasContext,
      requestId: const Uuid().v4(),
    );
    if (result == null) {
      log(
        'Product knowledge interpretation skipped | reason=null_result | query="$fallbackQuery"',
        name: 'AIChatCubit',
      );
      return null;
    }
    if (result.confidence < 0.75) {
      log(
        'Product knowledge interpretation rejected | reason=low_confidence | '
        'confidence=${result.confidence} | candidate=${result.productQueryCandidate}',
        name: 'AIChatCubit',
      );
      return null;
    }

    final candidate = result.productQueryCandidate?.trim();
    if (candidate == null || candidate.length < 3) {
      log(
        'Product knowledge interpretation rejected | reason=empty_candidate | '
        'intent=${result.intent} | confidence=${result.confidence}',
        name: 'AIChatCubit',
      );
      return null;
    }
    final normalizedCandidate = LocalIntentParser.normalizeInput(candidate);
    if (AvailabilityIntentUtils.isGenericAvailabilityCandidate(
          normalizedCandidate,
        ) ||
        AvailabilityIntentUtils.looksLikeGenderOnlyPreferenceReply(
          normalizedCandidate,
        ) ||
        AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(
          normalizedCandidate,
        )) {
      log(
        'Product knowledge interpretation rejected | reason=generic_candidate | '
        'candidate="$candidate"',
        name: 'AIChatCubit',
      );
      return null;
    }

    final normalizedFallback = LocalIntentParser.normalizeInput(fallbackQuery);
    if (normalizedCandidate == normalizedFallback) {
      log(
        'Product knowledge interpretation rejected | reason=same_candidate | '
        'candidate="$candidate"',
        name: 'AIChatCubit',
      );
      return null;
    }
    log(
      'Product knowledge interpretation accepted | query="$fallbackQuery" | '
      'candidate="$candidate" | intent=${result.intent} | confidence=${result.confidence}',
      name: 'AIChatCubit',
    );
    return candidate;
  }

  Future<AvailabilityReferenceProfile?> _resolveProductKnowledgeProfile(
    String query,
    AIChatLanguage language,
  ) async {
    final knowledgeProfile = await _aiChatRepo.lookupPerfumeKnowledge(query);
    if (knowledgeProfile != null) {
      return AvailabilityReferenceProfile.fromKnowledge(knowledgeProfile);
    }
    final staticProfile = AvailabilityReferenceProfileRegistry.resolveByMessage(
      query,
    );
    if (staticProfile != null) return staticProfile;

    final externalResult = await _aiChatRepo
        .lookupExternalPerfumeKnowledgeResult(
          query: query,
          responseLanguage: language,
          requestId: const Uuid().v4(),
        );
    final externalProfile = externalResult.profile;
    if (externalProfile == null) return null;
    return AvailabilityReferenceProfile.fromKnowledge(externalProfile);
  }

  String? _extractProductKnowledgeQuestionQuery(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;
    if (!_looksLikeProductKnowledgeQuestion(normalized)) return null;

    var candidate = normalized
        .replaceAll(RegExp(r'\b(do you know|you know|know about|know)\b'), ' ')
        .replaceAll(RegExp(r'\b(what do you know about|tell me about)\b'), ' ')
        .replaceAll(RegExp(r'(هل\s+)?(تعرف|عارف|تعرفي|بتعرف|بتعرفي)'), ' ')
        .replaceAll(RegExp(r'(عن|على|علي)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    candidate = candidate
        .replaceAll(LocalIntentParser.punctuation, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (candidate.length < 3) return null;
    return candidate;
  }

  bool _looksLikeProductKnowledgeQuestion(String normalized) {
    final hasKnowledgeCue =
        RegExp(
          r'\b(do you know|you know|know about|what do you know about|tell me about)\b',
        ).hasMatch(normalized) ||
        RegExp(r'(هل\s+)?(تعرف|عارف|تعرفي|بتعرف|بتعرفي)').hasMatch(normalized);
    if (!hasKnowledgeCue) return false;

    final recommendationCue =
        normalized.contains('recommend') ||
        normalized.contains('suggest') ||
        normalized.contains('رشح') ||
        normalized.contains('ترشيح');
    if (recommendationCue) return false;

    return true;
  }

  bool _isExternalLookupFailure(String? reason) {
    final normalized = reason?.trim().toLowerCase() ?? '';
    return normalized == 'source_lookup_failed' ||
        normalized == 'worker_error' ||
        normalized == 'exception';
  }

  List<ProductModel> _catalogOptionsForBroadQuery(
    String query,
    List<ProductModel> catalog,
  ) {
    final normalizedQuery = _normalizeAvailabilityText(query);
    if (normalizedQuery.isEmpty) return const <ProductModel>[];

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().length >= 2)
        .toList(growable: false);
    if (tokens.isEmpty) return const <ProductModel>[];

    bool matchesField(String value) {
      final normalized = _normalizeAvailabilityText(value);
      if (normalized.isEmpty) return false;
      if (normalized == normalizedQuery ||
          normalized.contains(normalizedQuery)) {
        return true;
      }
      return tokens.every(normalized.contains);
    }

    final matches = <ProductModel>[];
    final seenIds = <String>{};
    for (final product in catalog) {
      final fields = <String>[
        product.name,
        product.nameLower,
        product.nameAr,
        product.brand,
        product.brandAr,
        ...product.aliases,
        ...product.aliasesAr,
      ];
      if (fields.any(matchesField) && seenIds.add(product.id)) {
        matches.add(product);
      }
      if (matches.length >= 3) break;
    }
    return matches;
  }

  void _handleAvailabilityMissingQuery({
    required String message,
    required AIChatLanguage language,
    required String sessionId,
  }) {
    final availabilityContext = AvailabilityContext(
      lastQuery: message.trim(),
      availabilityStatus: AvailabilityStatus.notFoundUnknown,
      source: 'catalog_match',
    );
    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: buildAvailabilityClarifyMissingNameMessage(language),
        updatedPreferences: state.preferences,
      ),
      language: language,
      source: 'availability_missing_name',
      issueCode: 'availability_missing_name',
      reasonCode: 'availability_missing_name',
      sessionId: sessionId,
      availabilityContext: availabilityContext,
    );
  }

  void _handleFoundAvailabilityMatch({
    required String query,
    required AIChatLanguage language,
    required String sessionId,
    required List<ProductModel> catalog,
    required AvailabilityLookupResult lookupResult,
    required String normalizedQuery,
    required List<String> queryTokens,
  }) {
    final foundProduct = lookupResult.product!;
    final isOutOfStock =
        lookupResult.stockState == AvailabilityStockState.outOfStock;
    final normalizedMatchedName = _normalizeAvailabilityText(foundProduct.name);
    if (queryTokens.length == 1 && normalizedMatchedName != normalizedQuery) {
      final broadToken = queryTokens.first;
      final broadMatches = _catalogOptionsForBroadQuery(broadToken, catalog);
      if (broadMatches.length <= 1) {
        // A single catalog-backed option is concrete enough; continue with
        // the matched product instead of asking an unnecessary clarification.
      } else {
        final ambiguousContext = AvailabilityContext(
          lastQuery: query,
          availabilityStatus: AvailabilityStatus.ambiguous,
          candidateOptionIds: broadMatches.map((item) => item.id).toList(),
          source: 'catalog_match',
        );
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question: buildAvailabilityCatalogOptionsClarificationMessage(
              language,
              query,
              broadMatches,
            ),
            updatedPreferences: state.preferences,
          ),
          language: language,
          source: 'availability_ambiguous',
          issueCode: 'availability_ambiguous_name',
          reasonCode: 'availability_ambiguous_name',
          sessionId: sessionId,
          availabilityContext: ambiguousContext,
        );
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'availability_ambiguous_name',
            sessionId: sessionId,
            metadata: buildAvailabilityAnalyticsMetadata(
              query: query,
              status: AvailabilityStatus.ambiguous,
              substituteProductIds: broadMatches
                  .map((item) => item.id)
                  .toList(),
            ),
          ),
        );
        return;
      }
    }

    final availabilityContext = AvailabilityContext(
      lastQuery: query,
      matchedProductId: foundProduct.id,
      matchedProductName: foundProduct.name,
      availabilityStatus: isOutOfStock
          ? AvailabilityStatus.outOfStock
          : AvailabilityStatus.found,
      hints: availabilityHintsFromProduct(foundProduct),
      source: 'catalog_match',
    );

    if (isOutOfStock) {
      final substitutes = AvailabilitySubstituteEngine.findSubstitutes(
        context: availabilityContext,
        catalog: catalog,
        currentPreferences: state.preferences,
      );

      if (substitutes.suggestions.isNotEmpty &&
          substitutes.meetsConfidenceThreshold) {
        final substituteProducts = buildAvailabilitySubstituteProducts(
          substitutes.suggestions,
          language,
        );
        _replyHandler.handleAvailabilityCardReply(
          AIChatMessage.botAvailability(
            content: buildAvailabilityProactiveSubstituteMessage(
              language: language,
              query: foundProduct.name,
              substituteName: substitutes.suggestions.first.product.name,
              outOfStock: true,
            ),
            products: substituteProducts,
          ),
          language: language,
          source: 'availability_local',
          sessionId: sessionId,
          availabilityContext: availabilityContext,
        );

        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'availability_substitute_shown',
            sessionId: sessionId,
            metadata: buildAvailabilityAnalyticsMetadata(
              query: query,
              status: AvailabilityStatus.outOfStock,
              matchedProductId: foundProduct.id,
              substituteProductIds: substituteProducts
                  .map((item) => item.product.id)
                  .toList(),
              confidence: substitutes.bestScore,
            ),
          ),
        );
        unawaited(
          _aiChatRepo.logAIChatEvent(
            eventType: 'availability_catalog_out_of_stock_substitute',
            sessionId: sessionId,
            metadata: buildAvailabilityAnalyticsMetadata(
              query: query,
              status: AvailabilityStatus.outOfStock,
              matchedProductId: foundProduct.id,
              substituteProductIds: substituteProducts
                  .map((item) => item.product.id)
                  .toList(),
              confidence: substitutes.bestScore,
            ),
          ),
        );
      } else if (substitutes.suggestions.isEmpty) {
        _replyHandler.handleAvailabilityCardReply(
          AIChatMessage.botAvailability(
            content: buildAvailabilityMessageForFound(language, foundProduct),
            products: [buildAvailabilityCardProduct(foundProduct, language)],
          ),
          language: language,
          source: 'availability_local',
          sessionId: sessionId,
          availabilityContext: availabilityContext,
        );
      } else {
        _replyHandler.handleAskReply(
          AIChatReply.ask(
            question:
                '${buildAvailabilityMessageForFound(language, foundProduct)} ${buildAvailabilityLowConfidenceFallbackMessage(language, foundProduct.name)}',
            updatedPreferences: state.preferences,
          ),
          language: language,
          source: 'availability_local',
          sessionId: sessionId,
          availabilityContext: availabilityContext,
        );
      }

      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_out_of_stock',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.outOfStock,
            matchedProductId: foundProduct.id,
          ),
        ),
      );
      return;
    }

    _replyHandler.handleAvailabilityCardReply(
      AIChatMessage.botAvailability(
        content: buildAvailabilityMessageForFound(language, foundProduct),
        products: [buildAvailabilityCardProduct(foundProduct, language)],
      ),
      language: language,
      source: 'availability_local',
      sessionId: sessionId,
      availabilityContext: availabilityContext,
    );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_found',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.found,
          matchedProductId: foundProduct.id,
        ),
      ),
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_catalog_found',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.found,
          matchedProductId: foundProduct.id,
        ),
      ),
    );
  }

  void _handleKnownProfileAvailability({
    required String query,
    required AIChatLanguage language,
    required String sessionId,
    required List<ProductModel> catalog,
    required AvailabilityReferenceProfile profile,
    String eventSource = 'reference_profile',
  }) {
    if (_tryHandleCatalogProductFromKnownProfile(
      query: query,
      language: language,
      sessionId: sessionId,
      catalog: catalog,
      profile: profile,
      eventSource: '${eventSource}_catalog_found',
    )) {
      return;
    }

    final requestedName = profile.displayName.trim().isNotEmpty
        ? profile.displayName
        : query;
    final availabilityContext = AvailabilityContext(
      lastQuery: requestedName,
      availabilityStatus: AvailabilityStatus.notFoundKnownProfile,
      referenceProfileKey: profile.key,
      hints: availabilityHintsFromProfile(profile),
      source: eventSource,
    );
    final substitutes = AvailabilitySubstituteEngine.findSubstitutes(
      context: availabilityContext,
      catalog: catalog,
      currentPreferences: state.preferences,
    );

    final hasKnownProfileFallback = substitutes.suggestions.isNotEmpty;
    if (hasKnownProfileFallback && substitutes.meetsConfidenceThreshold) {
      final substituteProducts = buildAvailabilitySubstituteProducts(
        substitutes.suggestions,
        language,
      );
      _replyHandler.handleAvailabilityCardReply(
        AIChatMessage.botAvailability(
          content: buildAvailabilityKnowledgeSubstituteMessage(
            language: language,
            requestedName: requestedName,
            substituteName: substitutes.suggestions.first.product.name,
            profileHints: {
              ...profile.accords,
              ...profile.preferredNotes,
              ...profile.topNotes,
              ...profile.middleNotes,
              ...profile.baseNotes,
            },
          ),
          products: substituteProducts,
        ),
        language: language,
        source: 'availability_local',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType:
              eventSource == 'reference_profile' ||
                  eventSource == 'static_reference_profile'
              ? 'availability_substitute_shown'
              : 'availability_external_substitute_shown',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            substituteProductIds: substituteProducts
                .map((item) => item.product.id)
                .toList(),
            confidence: substitutes.bestScore,
          ),
        ),
      );
    } else {
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: buildKnownProfileLowConfidenceFallbackMessage(
            language,
            query,
          ),
          updatedPreferences: state.preferences,
        ),
        language: language,
        source: 'availability_known_profile_low_confidence',
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_external_unknown_asked',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: AvailabilityStatus.notFoundKnownProfile,
            referenceProfileKey: profile.key,
            confidence: substitutes.bestScore,
          ),
        ),
      );
    }

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_not_found_known_profile',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.notFoundKnownProfile,
          referenceProfileKey: profile.key,
          confidence: substitutes.bestScore,
        ),
      ),
    );
  }

  bool _tryHandleCatalogProductFromKnownProfile({
    required String query,
    required AIChatLanguage language,
    required String sessionId,
    required List<ProductModel> catalog,
    required AvailabilityReferenceProfile profile,
    required String eventSource,
  }) {
    final lookupNames = <String>{
      if (profile.displayName.trim().isNotEmpty) profile.displayName,
      if (profile.brand.trim().isNotEmpty &&
          profile.displayName.trim().isNotEmpty)
        '${profile.brand} ${profile.displayName}',
      ...profile.aliases,
    };
    for (final lookupName in lookupNames) {
      final lookup = lookupAvailability(lookupName, catalog);
      final product = lookup.product;
      if (product == null || lookup.isAmbiguous) continue;

      final availabilityContext = AvailabilityContext(
        lastQuery: query,
        matchedProductId: product.id,
        matchedProductName: product.name,
        availabilityStatus: product.stock > 0
            ? AvailabilityStatus.found
            : AvailabilityStatus.outOfStock,
        referenceProfileKey: profile.key,
        hints: availabilityHintsFromProduct(product),
        source: eventSource,
      );
      _replyHandler.handleAvailabilityCardReply(
        AIChatMessage.botAvailability(
          content: buildKnownCatalogProductIntroAnswer(product, language),
          products: [buildAvailabilityCardProduct(product, language)],
        ),
        language: language,
        source: eventSource,
        sessionId: sessionId,
        availabilityContext: availabilityContext,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: 'availability_profile_catalog_found',
          sessionId: sessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: product.stock > 0
                ? AvailabilityStatus.found
                : AvailabilityStatus.outOfStock,
            matchedProductId: product.id,
            referenceProfileKey: profile.key,
          ),
        ),
      );
      return true;
    }
    return false;
  }

  bool _shouldRefreshPerfumeKnowledgeProfile(PerfumeKnowledgeProfile profile) {
    return profile.status == PerfumeKnowledgeStatus.needsReview &&
        profile.extractionMethod == 'model' &&
        (profile.sourceUrl == null || profile.sourceUrl!.trim().isEmpty);
  }

  void _handleExternalPerfumeAmbiguous({
    required String query,
    required AIChatLanguage language,
    required String sessionId,
    required List<ExternalPerfumeCandidate> candidates,
  }) {
    final limitedCandidates = candidates.take(3).toList(growable: false);
    final availabilityContext = AvailabilityContext(
      lastQuery: query,
      availabilityStatus: AvailabilityStatus.ambiguous,
      externalCandidates: limitedCandidates,
      source: 'external_perfume_candidates',
    );

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: buildExternalPerfumeAmbiguousMessage(
          language,
          limitedCandidates,
        ),
        updatedPreferences: state.preferences,
      ),
      language: language,
      source: 'perfume_knowledge_external_ambiguous',
      issueCode: 'perfume_knowledge_external_ambiguous',
      reasonCode: 'external_candidates',
      sessionId: sessionId,
      availabilityContext: availabilityContext,
    );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'perfume_knowledge_external_lookup_ambiguous',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.ambiguous,
          substituteProductIds: limitedCandidates
              .map((item) => item.id)
              .toList(),
        ),
      ),
    );
  }

  void _handleUnknownAvailability({
    required String query,
    required AIChatLanguage language,
    required String sessionId,
    bool externalLookupFailed = false,
  }) {
    final availabilityContext = AvailabilityContext(
      lastQuery: query,
      availabilityStatus: AvailabilityStatus.notFoundUnknown,
      source: 'catalog_match',
    );

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: externalLookupFailed
            ? buildAvailabilityExternalLookupFailedMessage(language, query)
            : buildAvailabilityUnknownClarificationMessage(language),
        updatedPreferences: state.preferences,
      ),
      language: language,
      source: externalLookupFailed
          ? 'availability_external_lookup_failed'
          : 'availability_local',
      sessionId: sessionId,
      availabilityContext: availabilityContext,
    );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_not_found_unknown',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.notFoundUnknown,
        ),
      ),
    );
    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_external_unknown_asked',
        sessionId: sessionId,
        metadata: buildAvailabilityAnalyticsMetadata(
          query: query,
          status: AvailabilityStatus.notFoundUnknown,
        ),
      ),
    );
  }

  Future<bool> _handleAvailabilityBranches(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final routeResult = _availabilityRouteResolver.resolve(
      incoming: incoming,
      state: state,
      shouldContinueAvailabilityClarification:
          _shouldContinueAvailabilityClarification,
    );
    _logDecisionTrace(
      incoming,
      AIChatDecisionTrace(
        detectedLanguage: incoming.responseLanguage.code,
        detectedIntent: incoming.intent.name,
        availabilityRoute: routeResult.route.name,
        availabilityReasonCode: routeResult.reasonCode,
      ),
      phase: 'availability_route_resolved',
    );

    return _availabilityFlowService.handleRoutes(
      routeResult: routeResult,
      incoming: incoming,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      handleSimilarCheaperPivot: _tryHandleFoundAvailabilitySimilarCheaperPivot,
      handleFollowUp: _handleAvailabilityFollowUpIntent,
      handleDirect: _handleAvailabilityIntent,
    );
  }

  Future<bool> _tryHandleFoundAvailabilitySimilarCheaperPivot(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final matchedProductId =
        state.availabilityContext.matchedProductId ??
        state.availabilityContext.candidateOptionIds.firstOrNull;
    if (matchedProductId == null) return false;

    final catalog = await _aiChatRepo.getCatalog();
    final referenceProduct = catalog
        .where((product) => product.id == matchedProductId)
        .firstOrNull;
    if (referenceProduct == null) return false;

    final strictLowerBudget = referenceProduct.effectivePrice - 1;
    final normalizedLowerBudget = strictLowerBudget > 0
        ? strictLowerBudget
        : 0.0;
    final pivotPatch = availabilityHintsFromProduct(
      referenceProduct,
    ).copyWith(maxBudget: normalizedLowerBudget);
    final pivotPreferences = state.preferences.mergePatch(pivotPatch);

    // Defensive pre-filter: force cheaper-only candidate space before ranking.
    final cheaperCatalog = catalog
        .where((product) => product.id != referenceProduct.id)
        .where(
          (product) => product.effectivePrice < referenceProduct.effectivePrice,
        )
        .toList(growable: false);

    var localCandidates = ReferenceProductSimilarityRanker.rank(
      referenceProduct: referenceProduct,
      catalog: cheaperCatalog,
      sessionPreferences: state.preferences,
      effectivePreferences: pivotPreferences,
      mode: ReferenceSimilarityMode.similarCheaper,
    );
    if (localCandidates.isEmpty) {
      localCandidates = LocalCandidateFilter.getTopRecommendations(
        catalog: cheaperCatalog,
        preferences: pivotPreferences,
      );
    }

    // Defensive post-filter: keep invariant even if scoring/fallback internals change.
    final cheaperCandidates = localCandidates
        .where((candidate) => candidate.product.id != referenceProduct.id)
        .where(
          (candidate) =>
              candidate.product.effectivePrice <
              referenceProduct.effectivePrice,
        )
        .toList(growable: false);

    if (cheaperCandidates.isEmpty) {
      _replyHandler.replyWithFallback(
        buildNoMatchMessage(
          incoming.trimmed,
          pivotPreferences,
          catalog,
          incoming.responseLanguage,
          reasonCode: _localNoMatchReason(pivotPreferences),
        ),
        language: incoming.responseLanguage,
        source: 'availability_found_cheaper_pivot',
        updatedPreferences: pivotPreferences,
        isNoMatch: true,
        issueCode: 'no_candidate_match',
        reasonCode: 'availability_found_cheaper_no_match',
        sessionId: incoming.activeSessionId,
        requestId: incoming.requestId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    _replyHandler.handleRecommendationReply(
      buildRecommendReplyFromLocalCandidates(
        cheaperCandidates,
        updatedPreferences: pivotPreferences,
      ),
      cheaperCandidates,
      language: incoming.responseLanguage,
      source: 'availability_found_cheaper_pivot',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );

    unawaited(
      _aiChatRepo.logAIChatEvent(
        eventType: 'availability_found_cheaper_pivot',
        sessionId: incoming.activeSessionId,
        metadata: {
          'referenceProductId': referenceProduct.id,
          'referenceProductPrice': referenceProduct.effectivePrice,
          'resultIds': cheaperCandidates
              .map((candidate) => candidate.product.id)
              .toList(),
          'resultPrices': cheaperCandidates
              .map((candidate) => candidate.product.effectivePrice)
              .toList(),
          'maxBudget': pivotPreferences.maxBudget,
          'requestId': incoming.requestId,
        },
      ),
    );

    return true;
  }
}
