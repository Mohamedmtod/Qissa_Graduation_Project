import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_shadow_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/perfume_reference_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/preference_mutation_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/reference_product_similarity_ranker.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum AIChatToolResultStatus {
  success,
  needsClarification,
  noResults,
  blockedByGuard,
  validationFailed,
}

enum AIChatToolResultAction { recommend, answer, askClarification, noMatch }

enum AIChatToolRenderIntent {
  none,
  budgetFloorDisclosure,
  similarCheaperResults,
  cheaperFollowupResults,
  rejectionRecovery,
  closestMatchesWithCaveat,
  productQuestionAnswer,
  preferenceRefinementResults,
  externalReferenceClarification,
  externalProfileSimilarResults,
  externalProfileCheaperResults,
}

class AIChatToolExecutionResult {
  final bool handled;
  final String? tool;
  final AIChatToolResultStatus status;
  final AIChatToolResultAction action;
  final bool shouldRenderCards;
  final List<String> productIds;
  final AIChatToolRenderIntent renderIntent;
  final List<String> disclosures;
  final String? question;
  final String? traceReason;
  final AIChatReply? reply;
  final List<RecommendedProduct> recommendations;
  final SessionPreferences preferences;
  final String source;
  final String? issueCode;
  final String? reasonCode;
  final String? referenceQuery;
  final String? referenceStatus;
  final String? referenceSource;
  final int? selectedOptionIndex;
  final String? externalProfileId;
  final double? externalProfileConfidence;
  final String? cacheStatus;
  final RecommendationMemory? updatedRecommendationMemory;
  final AIChatResponseFacts? responseFacts;

  const AIChatToolExecutionResult.notHandled({
    this.tool,
    this.status = AIChatToolResultStatus.validationFailed,
    this.action = AIChatToolResultAction.askClarification,
    this.renderIntent = AIChatToolRenderIntent.none,
    this.disclosures = const <String>[],
    this.question,
    this.traceReason,
    this.issueCode,
    this.reasonCode,
    this.referenceQuery,
    this.referenceStatus,
    this.referenceSource,
    this.selectedOptionIndex,
    this.externalProfileId,
    this.externalProfileConfidence,
    this.cacheStatus,
    this.updatedRecommendationMemory,
    this.responseFacts,
  }) : handled = false,
       shouldRenderCards = false,
       productIds = const <String>[],
       reply = null,
       recommendations = const <RecommendedProduct>[],
       preferences = const SessionPreferences(),
       source = 'tool_not_handled';

  const AIChatToolExecutionResult.handled({
    required this.reply,
    required this.recommendations,
    required this.preferences,
    required this.source,
    required this.tool,
    required this.status,
    required this.action,
    required this.shouldRenderCards,
    this.productIds = const <String>[],
    this.renderIntent = AIChatToolRenderIntent.none,
    this.disclosures = const <String>[],
    this.question,
    this.traceReason,
    this.referenceQuery,
    this.referenceStatus,
    this.referenceSource,
    this.selectedOptionIndex,
    this.externalProfileId,
    this.externalProfileConfidence,
    this.cacheStatus,
    this.updatedRecommendationMemory,
    this.responseFacts,
  }) : handled = true,
       issueCode = null,
       reasonCode = null;

  Map<String, dynamic> toTraceJson() {
    return {
      if (tool != null) 'tool': tool,
      'status': status.name,
      'action': action.name,
      'shouldRenderCards': shouldRenderCards,
      if (productIds.isNotEmpty) 'productIds': productIds,
      if (renderIntent != AIChatToolRenderIntent.none)
        'renderIntent': renderIntent.name,
      if (disclosures.isNotEmpty) 'disclosures': disclosures,
      if (question != null) 'question': question,
      if (traceReason != null) 'traceReason': traceReason,
      if (issueCode != null) 'issueCode': issueCode,
      if (reasonCode != null) 'reasonCode': reasonCode,
      if (referenceQuery != null) 'referenceQuery': referenceQuery,
      if (referenceStatus != null) 'referenceStatus': referenceStatus,
      if (referenceSource != null) 'referenceSource': referenceSource,
      if (selectedOptionIndex != null)
        'selectedOptionIndex': selectedOptionIndex,
      if (externalProfileId != null) 'externalProfileId': externalProfileId,
      if (externalProfileConfidence != null)
        'externalProfileConfidence': externalProfileConfidence,
      if (cacheStatus != null) 'cacheStatus': cacheStatus,
      if (updatedRecommendationMemory != null)
        'updatedRecommendationMemory': true,
      if (responseFacts != null)
        'responseFacts': {
          'intent': responseFacts!.intent.name,
          'cardPolicy': responseFacts!.cardPolicy.name,
          'renderIntent': responseFacts!.renderIntent,
          'productCount': responseFacts!.products.length,
        },
    };
  }
}

class AIChatToolExecutor {
  final PerfumeKnowledgeLookup? lookupKnowledge;
  final ExternalPerfumeLookup? lookupExternal;

  const AIChatToolExecutor({this.lookupKnowledge, this.lookupExternal});

  Future<AIChatToolExecutionResult> execute({
    required AIChatReply reply,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
    RecommendationMemory recommendationMemory = const RecommendationMemory(),
  }) async {
    final toolCall = reply.toolCall;
    if (toolCall == null) {
      return const AIChatToolExecutionResult.notHandled(
        issueCode: 'missing_tool_call',
        reasonCode: 'missing_tool_call',
        traceReason: 'missing_tool_call',
      );
    }
    if (toolCall.confidence != null && toolCall.confidence! < 0.70) {
      return _lowConfidenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
      );
    }

    switch (toolCall.name) {
      case AIChatToolName.searchProducts:
      case AIChatToolName.cheapestCatalog:
      case AIChatToolName.mostExpensiveCatalog:
        return _executeSearchTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
        );
      case AIChatToolName.updatePreferencesAndRecommend:
        return _executePreferenceTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          language: language,
        );
      case AIChatToolName.showLowestAvailableAfterBudgetNoMatch:
        return _executeBudgetFloorTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.rejectVisibleProducts:
        return _executeRejectVisibleProductsTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.answerProductQuestion:
        return _executeAnswerProductQuestionTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.askProductClarification:
        return _executeAskProductClarificationTool(
          reply: reply,
          toolCall: toolCall,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.resolvePerfumeReference:
        return _executeResolvePerfumeReferenceTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.selectPerfumeReferenceOption:
        return _executeSelectPerfumeReferenceOptionTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.lookupExternalPerfumeProfile:
        return _executeLookupExternalPerfumeProfileTool(
          reply: reply,
          toolCall: toolCall,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.recommendSimilarToExternalProfile:
      case AIChatToolName.similarCheaperToExternalProfile:
        return _executeExternalProfileRecommendationTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.similarCheaper:
      case AIChatToolName.cheaperFollowup:
        return _executeCheaperReferenceTool(
          reply: reply,
          toolCall: toolCall,
          catalog: catalog,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory,
          language: language,
        );
      case AIChatToolName.askClarification:
        return _executeAskClarificationTool(
          reply: reply,
          toolCall: toolCall,
          currentPreferences: currentPreferences,
          language: language,
        );
    }
  }

  AIChatToolExecutionResult _executeAskClarificationTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
  }) {
    final patch =
        _preferencePatchFromArguments(toolCall.arguments) ??
        reply.preferencePatch;
    final preferences = patch == null || patch.isEmpty
        ? currentPreferences
        : const PreferenceMutationExecutor()
              .applyPatch(
                current: currentPreferences,
                patch: patch,
                source: 'tool_ask_clarification',
              )
              .preferences;
    final question =
        _stringArg(toolCall.arguments, 'question') ??
        reply.answer?.trim() ??
        (language.isArabic
            ? '\u0645\u0645\u0643\u0646 \u062a\u0648\u0636\u062d \u062a\u0641\u0636\u064a\u0644\u0643 \u0623\u0643\u062a\u0631\u061f'
            : 'Can you clarify your preference a bit more?');

    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.ask(
        question: question,
        updatedPreferences: preferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: patch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: preferences,
      source: 'tool_ask_clarification',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.needsClarification,
      action: AIChatToolResultAction.askClarification,
      shouldRenderCards: false,
      renderIntent: AIChatToolRenderIntent.none,
      question: question,
      traceReason: 'llm_requested_clarification',
    );
  }

  AIChatToolExecutionResult _executeSearchTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
  }) {
    final preferences = _preferencesFromArguments(
      toolCall.arguments,
      currentPreferences,
    );
    final searchPreferences = switch (toolCall.name) {
      AIChatToolName.cheapestCatalog => preferences.copyWith(
        rankingStrategy: RankingStrategy.cheapestFirst,
      ),
      AIChatToolName.mostExpensiveCatalog => preferences.copyWith(
        rankingStrategy: RankingStrategy.expensiveFirst,
      ),
      _ => preferences,
    };
    final recommendations = const CatalogSearchShadowService().buildCandidates(
      catalog: catalog,
      preferences: searchPreferences,
      limit: _limitFromArgs(toolCall.arguments),
    );
    if (recommendations.isEmpty) {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.noResults,
        action: AIChatToolResultAction.noMatch,
        issueCode: 'tool_no_results',
        reasonCode: 'tool_no_results',
        traceReason: 'catalog_search_empty',
      );
    }
    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: recommendation.matchReason,
        },
        updatedPreferences: searchPreferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: recommendations,
      preferences: searchPreferences,
      source: 'tool_${toolCall.name.name}',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: AIChatToolRenderIntent.closestMatchesWithCaveat,
      traceReason: 'catalog_search_guarded',
    );
  }

  AIChatToolExecutionResult _executePreferenceTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
  }) {
    final patch = toolCall.preferencePatch ?? reply.preferencePatch;
    if (patch == null || patch.isEmpty) {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.validationFailed,
        issueCode: 'tool_invalid_preference_patch',
        reasonCode: 'tool_invalid_preference_patch',
        traceReason: 'missing_preference_patch',
      );
    }
    final mutation = const PreferenceMutationExecutor().applyPatch(
      current: currentPreferences,
      patch: patch,
      source: 'tool_update_preferences',
    );
    final recommendations = const CatalogSearchShadowService()
        .buildCandidates(
          catalog: catalog,
          preferences: mutation.preferences,
          limit: _limitFromArgs(toolCall.arguments),
        )
        .toList(growable: false);
    if (recommendations.isEmpty) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: mutation.preferences,
        language: language,
        traceReason: 'preference_patch_applied_but_no_results',
        status: AIChatToolResultStatus.noResults,
        renderIntent: AIChatToolRenderIntent.preferenceRefinementResults,
      );
    }
    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: recommendation.matchReason,
        },
        updatedPreferences: mutation.preferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: patch,
      ),
      recommendations: recommendations,
      preferences: mutation.preferences,
      source: 'tool_update_preferences',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: AIChatToolRenderIntent.preferenceRefinementResults,
      traceReason: 'preference_patch_applied_and_recommended',
    );
  }

  AIChatToolExecutionResult _executeAnswerProductQuestionTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    final product = _resolveProductFromArgsOrMemory(
      args: toolCall.arguments,
      catalog: catalog,
      recommendationMemory: recommendationMemory,
    );
    if (product == null) {
      return _executeAskProductClarificationTool(
        reply: reply,
        toolCall: toolCall,
        currentPreferences: currentPreferences,
        recommendationMemory: recommendationMemory,
        language: language,
      );
    }
    final ref = _memoryRefForProduct(product, recommendationMemory);
    final answer = ref != null
        ? const AIChatRecommendationMemoryAnswerBuilder().buildMemoryAnswer(
            ref,
            language,
            includeNotes: true,
            includeReason: true,
          )
        : _catalogProductAnswer(product, language);
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.answer(
        answer: answer,
        updatedPreferences: currentPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: currentPreferences,
      source: 'tool_answerProductQuestion',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.answer,
      shouldRenderCards: false,
      renderIntent: AIChatToolRenderIntent.productQuestionAnswer,
      traceReason: 'product_question_answered_from_catalog_or_memory',
      updatedRecommendationMemory: recommendationMemory.copyWith(
        lastFocusedProductId: product.id,
      ),
    );
  }

  AIChatToolExecutionResult _executeAskProductClarificationTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    final refs = recommendationMemory.lastRecommendedProducts;
    final question = refs.isNotEmpty
        ? const AIChatRecommendationMemoryAnswerBuilder()
              .buildAmbiguousSelectionAnswer(refs.take(5).toList(), language)
        : language.isArabic
        ? 'تقصد أنهي عطر؟ اكتب الاسم أو اختار من الترشيحات الظاهرة.'
        : 'Which perfume do you mean? Write its name or choose from the visible recommendations.';
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.ask(
        question: question,
        updatedPreferences: currentPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: currentPreferences,
      source: 'tool_askProductClarification',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.needsClarification,
      action: AIChatToolResultAction.askClarification,
      shouldRenderCards: false,
      renderIntent: AIChatToolRenderIntent.productQuestionAnswer,
      question: question,
      traceReason: 'product_reference_requires_clarification',
    );
  }

  AIChatToolExecutionResult _executeBudgetFloorTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    final lastNoMatch = recommendationMemory.lastNoMatchContext;
    if (lastNoMatch == null || lastNoMatch.reason != 'budget_no_match') {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.validationFailed,
        issueCode: 'missing_budget_no_match_context',
        reasonCode: 'missing_budget_no_match_context',
        traceReason: 'budget_floor_requires_previous_budget_no_match',
      );
    }

    final catalogById = {for (final product in catalog) product.id: product};
    final floorProducts = lastNoMatch.lowestAvailableProductIds
        .map((id) => catalogById[id])
        .whereType<ProductModel>()
        .where((product) => product.isActive && product.stock > 0)
        .toList(growable: false);
    final products = floorProducts.isNotEmpty
        ? floorProducts
        : _lowestAvailableProducts(catalog);
    if (products.isEmpty) {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.noResults,
        action: AIChatToolResultAction.noMatch,
        issueCode: 'budget_floor_no_available_product',
        reasonCode: 'budget_floor_no_available_product',
        traceReason: 'budget_floor_empty_catalog',
      );
    }

    final disclosure = _budgetFloorDisclosure(
      language,
      requestedBudget:
          lastNoMatch.requestedBudget ?? currentPreferences.maxBudget,
      lowestPrice: products.first.effectivePrice,
    );
    final recommendations = products
        .take(3)
        .map((product) {
          return RecommendedProduct(
            product: product,
            matchScore: 1,
            matchLabel: language.isArabic ? 'أقل سعر متاح' : 'Lowest Available',
            matchReason: disclosure,
            candidateSource: RecommendedCandidateSource.strict,
          );
        })
        .toList(growable: false);
    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);

    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final item in recommendations) item.product.id: disclosure,
        },
        updatedPreferences: currentPreferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: recommendations,
      preferences: currentPreferences,
      source: 'tool_showLowestAvailableAfterBudgetNoMatch',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: AIChatToolRenderIntent.budgetFloorDisclosure,
      disclosures: [disclosure],
      traceReason: 'accepted_budget_floor_after_no_match',
    );
  }

  AIChatToolExecutionResult _executeRejectVisibleProductsTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    final rejectedIds = {
      ...recommendationMemory.lastRecommendedProducts.map(
        (item) => item.productId,
      ),
      ..._stringListArg(toolCall.arguments, 'productIds'),
      ..._stringListArg(toolCall.arguments, 'rejectedProductIds'),
    }..removeWhere((id) => id.trim().isEmpty);

    if (rejectedIds.isEmpty) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: 'missing_visible_products_to_reject',
      );
    }

    final filteredCatalog = catalog
        .where((product) => !rejectedIds.contains(product.id))
        .toList(growable: false);
    final recommendations = const CatalogSearchShadowService()
        .buildCandidates(
          catalog: filteredCatalog,
          preferences: currentPreferences,
          limit: _limitFromArgs(toolCall.arguments),
        )
        .where((item) => !rejectedIds.contains(item.product.id))
        .toList(growable: false);

    if (recommendations.isEmpty) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: 'rejection_filtered_all_candidates',
      );
    }

    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: recommendation.matchReason,
        },
        updatedPreferences: currentPreferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: recommendations,
      preferences: currentPreferences,
      source: 'tool_rejectVisibleProducts',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: AIChatToolRenderIntent.rejectionRecovery,
      traceReason: 'excluded_rejected_visible_products',
    );
  }

  Future<AIChatToolExecutionResult> _executeResolvePerfumeReferenceTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) async {
    final query = _referenceQuery(toolCall.arguments);
    if (query == null) {
      return _referenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: 'missing_perfume_reference_query',
      );
    }
    final resolver = PerfumeReferenceResolver(
      lookupKnowledge: lookupKnowledge,
      lookupExternal: lookupExternal,
    );
    final resolution = await resolver.resolve(
      query: query,
      catalog: catalog,
      language: language,
      requestId: reply.requestId,
    );
    return _resultFromReferenceResolution(
      reply: reply,
      toolCall: toolCall,
      resolution: resolution,
      catalog: catalog,
      currentPreferences: currentPreferences,
      recommendationMemory: recommendationMemory,
      language: language,
    );
  }

  Future<AIChatToolExecutionResult> _executeLookupExternalPerfumeProfileTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) async {
    final query = _referenceQuery(toolCall.arguments);
    if (query == null || lookupExternal == null) {
      return _referenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: lookupExternal == null
            ? 'external_lookup_callback_missing'
            : 'missing_external_lookup_query',
      );
    }
    final lookup = await lookupExternal!(
      query: query,
      responseLanguage: language,
      requestId: reply.requestId,
    );
    if (lookup.isAmbiguous) {
      final pending = PendingPerfumeReferenceClarification(
        query: query,
        options: lookup.candidates
            .take(5)
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) {
              final candidate = entry.value;
              return PerfumeReferenceOptionRef(
                index: entry.key + 1,
                name: candidate.displayName,
                brand: candidate.brand,
                source: PerfumeReferenceSource.externalLookup.name,
                externalProfileId: candidate.id,
                confidence: candidate.score,
              );
            })
            .toList(growable: false),
      );
      final question = _perfumeReferenceOptionsQuestion(
        query: query,
        options: pending.options,
        language: language,
      );
      return AIChatToolExecutionResult.handled(
        reply: AIChatReply.ask(
          question: question,
          updatedPreferences: currentPreferences,
          requestId: reply.requestId,
          promptVersion: reply.promptVersion,
          provider: reply.provider,
          modelId: reply.modelId,
          preferencePatch: reply.preferencePatch,
        ),
        recommendations: const <RecommendedProduct>[],
        preferences: currentPreferences,
        source: 'tool_lookupExternalPerfumeProfile',
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.needsClarification,
        action: AIChatToolResultAction.askClarification,
        shouldRenderCards: false,
        renderIntent: AIChatToolRenderIntent.externalReferenceClarification,
        question: question,
        traceReason: 'external_lookup_ambiguous',
        referenceQuery: query,
        referenceStatus: 'needs_clarification',
        referenceSource: PerfumeReferenceSource.externalLookup.name,
        updatedRecommendationMemory: recommendationMemory.copyWith(
          pendingPerfumeReferenceClarification: pending,
        ),
      );
    }
    final profile = lookup.profile;
    if (profile == null || !profile.isUsable) {
      return _referenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: lookup.reason ?? 'external_profile_not_found',
        referenceQuery: query,
        referenceStatus: 'not_found',
      );
    }
    return _externalProfileResolvedResult(
      reply: reply,
      toolCall: toolCall,
      profile: profile,
      source: PerfumeReferenceSource.externalLookup,
      currentPreferences: currentPreferences,
      recommendationMemory: recommendationMemory,
      language: language,
      traceReason: 'external_profile_lookup_resolved',
      referenceQuery: query,
      cacheStatus: 'external_lookup',
    );
  }

  Future<AIChatToolExecutionResult> _executeSelectPerfumeReferenceOptionTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) async {
    final pending = recommendationMemory.pendingPerfumeReferenceClarification;
    if (pending == null || pending.options.isEmpty) {
      return _referenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: 'missing_pending_perfume_reference_options',
      );
    }
    final userReply =
        _stringArg(toolCall.arguments, 'userReply') ??
        _stringArg(toolCall.arguments, 'reply') ??
        _stringArg(toolCall.arguments, 'selection') ??
        _stringArg(toolCall.arguments, 'query') ??
        reply.answer;
    if (userReply == null || userReply.trim().isEmpty) {
      return _referenceClarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: 'missing_perfume_reference_selection_reply',
      );
    }
    final resolver = PerfumeReferenceResolver();
    final option = resolver.selectOption(
      userReply: userReply,
      options: pending.options
          .map(_optionFromMemoryRef)
          .toList(growable: false),
    );
    if (option == null) {
      final question = _perfumeReferenceOptionsQuestion(
        query: pending.query,
        options: pending.options,
        language: language,
      );
      return AIChatToolExecutionResult.handled(
        reply: AIChatReply.ask(
          question: question,
          updatedPreferences: currentPreferences,
          requestId: reply.requestId,
          promptVersion: reply.promptVersion,
          provider: reply.provider,
          modelId: reply.modelId,
          preferencePatch: reply.preferencePatch,
        ),
        recommendations: const <RecommendedProduct>[],
        preferences: currentPreferences,
        source: 'tool_selectPerfumeReferenceOption',
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.needsClarification,
        action: AIChatToolResultAction.askClarification,
        shouldRenderCards: false,
        renderIntent: AIChatToolRenderIntent.externalReferenceClarification,
        question: question,
        traceReason: 'perfume_reference_selection_ambiguous',
        referenceQuery: pending.query,
        referenceStatus: 'needs_clarification',
      );
    }
    if (option.productId != null) {
      final product = _productById(catalog, option.productId);
      if (product != null) {
        return AIChatToolExecutionResult.handled(
          reply: AIChatReply.answer(
            answer: _catalogProductAnswer(product, language),
            updatedPreferences: currentPreferences,
            requestId: reply.requestId,
            promptVersion: reply.promptVersion,
            provider: reply.provider,
            modelId: reply.modelId,
            preferencePatch: reply.preferencePatch,
          ),
          recommendations: const <RecommendedProduct>[],
          preferences: currentPreferences,
          source: 'tool_selectPerfumeReferenceOption',
          tool: toolCall.name.name,
          status: AIChatToolResultStatus.success,
          action: AIChatToolResultAction.answer,
          shouldRenderCards: false,
          renderIntent: AIChatToolRenderIntent.productQuestionAnswer,
          traceReason: 'catalog_reference_option_selected',
          referenceQuery: pending.query,
          referenceStatus: 'resolved',
          referenceSource: PerfumeReferenceSource.catalog.name,
          selectedOptionIndex: option.index,
          updatedRecommendationMemory: recommendationMemory.copyWith(
            lastFocusedProductId: product.id,
            clearPendingPerfumeReferenceClarification: true,
          ),
        );
      }
    }
    if (lookupExternal != null) {
      final lookup = await lookupExternal!(
        query: option.brand.trim().isEmpty
            ? option.name
            : '${option.brand} ${option.name}',
        responseLanguage: language,
        requestId: reply.requestId,
      );
      final profile = lookup.profile;
      if (profile != null && profile.isUsable) {
        return _externalProfileResolvedResult(
          reply: reply,
          toolCall: toolCall,
          profile: profile,
          source: PerfumeReferenceSource.externalLookup,
          currentPreferences: currentPreferences,
          recommendationMemory: recommendationMemory.copyWith(
            clearPendingPerfumeReferenceClarification: true,
          ),
          language: language,
          traceReason: 'external_reference_option_selected',
          referenceQuery: pending.query,
          selectedOptionIndex: option.index,
          cacheStatus: 'external_lookup',
        );
      }
    }
    return _referenceClarificationResult(
      reply: reply,
      toolCall: toolCall,
      preferences: currentPreferences,
      language: language,
      traceReason: 'selected_external_reference_not_verified',
      referenceQuery: pending.query,
      referenceStatus: 'not_found',
    );
  }

  AIChatToolExecutionResult _resultFromReferenceResolution({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required PerfumeReferenceResolution resolution,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    switch (resolution.status) {
      case PerfumeReferenceStatus.resolved:
        final product = resolution.product;
        if (product != null) {
          return AIChatToolExecutionResult.handled(
            reply: AIChatReply.answer(
              answer: _catalogProductAnswer(product, language),
              updatedPreferences: currentPreferences,
              requestId: reply.requestId,
              promptVersion: reply.promptVersion,
              provider: reply.provider,
              modelId: reply.modelId,
              preferencePatch: reply.preferencePatch,
            ),
            recommendations: const <RecommendedProduct>[],
            preferences: currentPreferences,
            source: 'tool_resolvePerfumeReference',
            tool: toolCall.name.name,
            status: AIChatToolResultStatus.success,
            action: AIChatToolResultAction.answer,
            shouldRenderCards: false,
            renderIntent: AIChatToolRenderIntent.productQuestionAnswer,
            traceReason: 'catalog_reference_resolved',
            referenceQuery: resolution.query,
            referenceStatus: 'resolved',
            referenceSource: PerfumeReferenceSource.catalog.name,
            updatedRecommendationMemory: recommendationMemory.copyWith(
              lastFocusedProductId: product.id,
              clearPendingPerfumeReferenceClarification: true,
            ),
          );
        }
        final profile = resolution.externalProfile;
        if (profile != null) {
          return _externalProfileResolvedResult(
            reply: reply,
            toolCall: toolCall,
            profile: profile,
            source:
                resolution.source ?? PerfumeReferenceSource.perfumeKnowledge,
            currentPreferences: currentPreferences,
            recommendationMemory: recommendationMemory,
            language: language,
            traceReason: 'external_reference_resolved',
            referenceQuery: resolution.query,
            cacheStatus: resolution.cacheStatus,
          );
        }
        break;
      case PerfumeReferenceStatus.needsClarification:
        final pending = PendingPerfumeReferenceClarification(
          query: resolution.query,
          options: resolution.options
              .map(_optionRefFromResolution)
              .toList(growable: false),
        );
        final question = _perfumeReferenceOptionsQuestion(
          query: resolution.query,
          options: pending.options,
          language: language,
        );
        return AIChatToolExecutionResult.handled(
          reply: AIChatReply.ask(
            question: question,
            updatedPreferences: currentPreferences,
            requestId: reply.requestId,
            promptVersion: reply.promptVersion,
            provider: reply.provider,
            modelId: reply.modelId,
            preferencePatch: reply.preferencePatch,
          ),
          recommendations: const <RecommendedProduct>[],
          preferences: currentPreferences,
          source: 'tool_resolvePerfumeReference',
          tool: toolCall.name.name,
          status: AIChatToolResultStatus.needsClarification,
          action: AIChatToolResultAction.askClarification,
          shouldRenderCards: false,
          renderIntent: AIChatToolRenderIntent.externalReferenceClarification,
          question: question,
          traceReason: resolution.reason ?? 'reference_requires_clarification',
          referenceQuery: resolution.query,
          referenceStatus: 'needs_clarification',
          referenceSource: resolution.options.isEmpty
              ? null
              : resolution.options.first.source.name,
          cacheStatus: resolution.cacheStatus,
          updatedRecommendationMemory: recommendationMemory.copyWith(
            pendingPerfumeReferenceClarification: pending,
          ),
        );
      case PerfumeReferenceStatus.notFound:
      case PerfumeReferenceStatus.cacheUnavailable:
        return _referenceClarificationResult(
          reply: reply,
          toolCall: toolCall,
          preferences: currentPreferences,
          language: language,
          traceReason: resolution.reason ?? 'reference_not_found',
          referenceQuery: resolution.query,
          referenceStatus:
              resolution.status == PerfumeReferenceStatus.cacheUnavailable
              ? 'cache_unavailable'
              : 'not_found',
          cacheStatus: resolution.cacheStatus,
        );
    }
    return _referenceClarificationResult(
      reply: reply,
      toolCall: toolCall,
      preferences: currentPreferences,
      language: language,
      traceReason: 'reference_resolution_empty_result',
      referenceQuery: resolution.query,
      referenceStatus: 'not_found',
    );
  }

  AIChatToolExecutionResult _externalProfileResolvedResult({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required PerfumeKnowledgeProfile profile,
    required PerfumeReferenceSource source,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
    required String traceReason,
    String? referenceQuery,
    int? selectedOptionIndex,
    String? cacheStatus,
  }) {
    final ref = _externalProfileRef(profile, source);
    final answer = language.isArabic
        ? 'تمام، فهمت مرجع العطر: ${profile.displayName}. مش هاعتبره منتج متاح إلا لو موجود في الكتالوج، لكن أقدر أستخدم طابعه عشان أرشح بدائل متاحة.'
        : 'Got it, I will use ${profile.displayName} as a scent reference. I will not treat it as an available catalog product unless it exists in the catalog.';
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.answer(
        answer: answer,
        updatedPreferences: currentPreferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: currentPreferences,
      source: 'tool_${toolCall.name.name}',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.answer,
      shouldRenderCards: false,
      renderIntent: AIChatToolRenderIntent.externalReferenceClarification,
      traceReason: traceReason,
      referenceQuery: referenceQuery ?? profile.displayName,
      referenceStatus: 'resolved',
      referenceSource: source.name,
      selectedOptionIndex: selectedOptionIndex,
      externalProfileId: ref.id,
      externalProfileConfidence: ref.confidence,
      cacheStatus: cacheStatus,
      updatedRecommendationMemory: recommendationMemory.copyWith(
        lastExternalProfile: ref,
        clearPendingPerfumeReferenceClarification: true,
      ),
    );
  }

  AIChatToolExecutionResult _referenceClarificationResult({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences preferences,
    required AIChatLanguage language,
    required String traceReason,
    String? referenceQuery,
    String? referenceStatus,
    String? cacheStatus,
  }) {
    final question = language.isArabic
        ? 'مش قادر أتحقق من المرجع ده بدقة. اكتب اسم العطر كامل أو قولّي طابعه: فريش، خشبي، مسك، سويت، ولا هادي؟'
        : 'I cannot verify that perfume reference clearly. Write the full name or describe the vibe: fresh, woody, musky, sweet, or soft.';
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.ask(
        question: question,
        updatedPreferences: preferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: preferences,
      source: 'tool_${toolCall.name.name}_clarification',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.needsClarification,
      action: AIChatToolResultAction.askClarification,
      shouldRenderCards: false,
      renderIntent: AIChatToolRenderIntent.externalReferenceClarification,
      question: question,
      traceReason: traceReason,
      referenceQuery: referenceQuery,
      referenceStatus: referenceStatus,
      cacheStatus: cacheStatus,
    );
  }

  Future<AIChatToolExecutionResult> _executeExternalProfileRecommendationTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) async {
    final requestedProfileId =
        _stringArg(toolCall.arguments, 'externalProfileId') ??
        _stringArg(toolCall.arguments, 'profileId');
    var profile = recommendationMemory.lastExternalProfile;
    if (profile == null &&
        requestedProfileId != null &&
        lookupKnowledge != null) {
      final lookedUp = await lookupKnowledge!(requestedProfileId);
      if (lookedUp != null && lookedUp.isUsable) {
        profile = _externalProfileRef(
          lookedUp,
          PerfumeReferenceSource.perfumeKnowledge,
        );
      }
    }
    if (profile == null) {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.validationFailed,
        issueCode: 'missing_external_profile_context',
        reasonCode: 'missing_external_profile_context',
        traceReason: 'external_profile_tool_requires_last_external_profile',
        referenceStatus: 'missing',
      );
    }

    if (requestedProfileId != null && requestedProfileId != profile.id) {
      return AIChatToolExecutionResult.notHandled(
        tool: toolCall.name.name,
        status: AIChatToolResultStatus.validationFailed,
        issueCode: 'ungrounded_external_profile_id',
        reasonCode: 'ungrounded_external_profile_id',
        traceReason: 'external_profile_id_not_grounded_in_context',
        referenceStatus: 'validation_failed',
        externalProfileId: requestedProfileId,
      );
    }

    final isCheaper =
        toolCall.name == AIChatToolName.similarCheaperToExternalProfile;
    final hasVerifiedPrice =
        profile.priceReference != null && profile.priceReference! > 0;
    final priceCeiling = isCheaper && hasVerifiedPrice
        ? profile.priceReference
        : null;
    final recommendations = _rankCatalogAgainstExternalProfile(
      profile: profile,
      catalog: catalog,
      currentPreferences: currentPreferences,
      language: language,
      priceCeiling: priceCeiling,
      limit: _limitFromArgs(toolCall.arguments),
    );

    if (recommendations.isEmpty) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: priceCeiling == null && isCheaper
            ? 'no_external_profile_similar_results_without_price_reference'
            : 'no_external_profile_similar_results',
        status: AIChatToolResultStatus.noResults,
        renderIntent: isCheaper
            ? AIChatToolRenderIntent.externalProfileCheaperResults
            : AIChatToolRenderIntent.externalProfileSimilarResults,
      );
    }

    final disclosure = isCheaper && !hasVerifiedPrice
        ? _externalPriceReferenceMissingDisclosure(language, profile.name)
        : null;
    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);
    final source = isCheaper
        ? 'tool_similarCheaperToExternalProfile'
        : 'tool_recommendSimilarToExternalProfile';
    final traceReason = isCheaper
        ? hasVerifiedPrice
              ? 'external_profile_similarity_with_verified_price_ceiling'
              : 'external_profile_similarity_without_verified_price_reference'
        : 'external_profile_similarity';

    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: [
              recommendation.matchReason,
              ?disclosure,
            ].join(' '),
        },
        updatedPreferences: currentPreferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: recommendations,
      preferences: currentPreferences,
      source: source,
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: isCheaper
          ? AIChatToolRenderIntent.externalProfileCheaperResults
          : AIChatToolRenderIntent.externalProfileSimilarResults,
      disclosures: disclosure == null ? const <String>[] : [disclosure],
      traceReason: traceReason,
      referenceQuery: profile.name,
      referenceStatus: 'resolved',
      referenceSource: profile.source,
      externalProfileId: profile.id,
      externalProfileConfidence: profile.confidence,
      updatedRecommendationMemory: recommendationMemory.copyWith(
        lastExternalProfile: profile,
      ),
    );
  }

  AIChatToolExecutionResult _executeCheaperReferenceTool({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required RecommendationMemory recommendationMemory,
    required AIChatLanguage language,
  }) {
    final anchor = _resolveAnchorProduct(
      args: toolCall.arguments,
      catalog: catalog,
      recommendationMemory: recommendationMemory,
      allowVisibleMinimumFallback:
          toolCall.name == AIChatToolName.cheaperFollowup,
    );

    if (anchor.status == _AnchorResolutionStatus.ambiguous ||
        anchor.status == _AnchorResolutionStatus.missing) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: anchor.status == _AnchorResolutionStatus.ambiguous
            ? 'anchor_ambiguous_multiple_visible_products'
            : 'anchor_missing_for_reference_tool',
        renderIntent: toolCall.name == AIChatToolName.similarCheaper
            ? AIChatToolRenderIntent.similarCheaperResults
            : AIChatToolRenderIntent.cheaperFollowupResults,
      );
    }

    final limit = _limitFromArgs(toolCall.arguments);
    final recommendations = anchor.product != null
        ? _rankSimilarCheaper(
            referenceProduct: anchor.product!,
            catalog: catalog,
            currentPreferences: currentPreferences,
            language: language,
            limit: limit,
          )
        : _rankCheaperThanVisibleMinimum(
            catalog: catalog,
            currentPreferences: currentPreferences,
            priceCeiling: anchor.priceCeiling!,
            limit: limit,
          );

    if (recommendations.isEmpty) {
      return _clarificationResult(
        reply: reply,
        toolCall: toolCall,
        preferences: currentPreferences,
        language: language,
        traceReason: anchor.product != null
            ? 'no_similar_product_below_anchor_price'
            : 'no_product_below_visible_minimum_price',
        status: AIChatToolResultStatus.noResults,
        renderIntent: toolCall.name == AIChatToolName.similarCheaper
            ? AIChatToolRenderIntent.similarCheaperResults
            : AIChatToolRenderIntent.cheaperFollowupResults,
      );
    }

    final productIds = recommendations
        .map((item) => item.product.id)
        .toList(growable: false);
    final source = toolCall.name == AIChatToolName.similarCheaper
        ? 'tool_similarCheaper'
        : 'tool_cheaperFollowup';
    final renderIntent = toolCall.name == AIChatToolName.similarCheaper
        ? AIChatToolRenderIntent.similarCheaperResults
        : AIChatToolRenderIntent.cheaperFollowupResults;

    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.recommend(
        productIds: productIds,
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: recommendation.matchReason,
        },
        updatedPreferences: currentPreferences,
        answer: _toolIntro(reply),
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: recommendations,
      preferences: currentPreferences,
      source: source,
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.success,
      action: AIChatToolResultAction.recommend,
      shouldRenderCards: true,
      productIds: productIds,
      renderIntent: renderIntent,
      traceReason: anchor.product != null
          ? 'anchor_price_similarity'
          : 'visible_minimum_price_ceiling',
    );
  }

  AIChatToolExecutionResult _clarificationResult({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences preferences,
    required AIChatLanguage language,
    required String traceReason,
    AIChatToolResultStatus status = AIChatToolResultStatus.needsClarification,
    AIChatToolRenderIntent renderIntent =
        AIChatToolRenderIntent.rejectionRecovery,
  }) {
    final question = language.isArabic
        ? 'تحب أغير الاتجاه؟ أرخص، أهدى، أدفى، أو استخدام مختلف؟'
        : 'Do you want me to change the style, make it cheaper, lighter, warmer, or for another occasion?';
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.ask(
        question: question,
        updatedPreferences: preferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: preferences,
      source: 'tool_${toolCall.name.name}_clarification',
      tool: toolCall.name.name,
      status: status,
      action: AIChatToolResultAction.askClarification,
      shouldRenderCards: false,
      renderIntent: renderIntent,
      question: question,
      traceReason: traceReason,
    );
  }

  AIChatToolExecutionResult _lowConfidenceClarificationResult({
    required AIChatReply reply,
    required AIChatToolCall toolCall,
    required SessionPreferences preferences,
    required AIChatLanguage language,
  }) {
    final question = language.isArabic
        ? 'ممكن توضح تقصد أي اختيار أو تغيير بالضبط؟'
        : 'Can you clarify which option or change you mean?';
    return AIChatToolExecutionResult.handled(
      reply: AIChatReply.ask(
        question: question,
        updatedPreferences: preferences,
        requestId: reply.requestId,
        promptVersion: reply.promptVersion,
        provider: reply.provider,
        modelId: reply.modelId,
        preferencePatch: reply.preferencePatch,
      ),
      recommendations: const <RecommendedProduct>[],
      preferences: preferences,
      source: 'tool_${toolCall.name.name}_low_confidence',
      tool: toolCall.name.name,
      status: AIChatToolResultStatus.needsClarification,
      action: AIChatToolResultAction.askClarification,
      shouldRenderCards: false,
      question: question,
      traceReason: 'tool_confidence_below_threshold',
    );
  }

  SessionPreferences _preferencesFromArguments(
    Map<String, dynamic> args,
    SessionPreferences current,
  ) {
    return current.mergePatch(
      SessionPreferences(
        gender: _stringArg(args, 'gender'),
        maxBudget:
            _doubleArg(args, 'maxPrice') ?? _doubleArg(args, 'maxBudget'),
        season: _stringArg(args, 'season'),
        occasion: _stringArg(args, 'occasion'),
        time: _stringArg(args, 'time'),
        intensity: _stringArg(args, 'intensity'),
        preferredNotes: _stringListArg(args, 'notes'),
        tags: _stringListArg(args, 'tags'),
      ),
    );
  }

  int _limitFromArgs(Map<String, dynamic> args) {
    final raw = args['limit'];
    if (raw is num) return raw.toInt().clamp(1, 5);
    return 3;
  }

  String? _stringArg(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  double? _doubleArg(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '').trim());
    return null;
  }

  List<String> _stringListArg(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is Iterable) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final single = _stringArg(args, key);
    return single == null ? const <String>[] : <String>[single];
  }

  PreferencePatch? _preferencePatchFromArguments(Map<String, dynamic> args) {
    final raw = args['preferencePatch'] ?? args['preference_patch'];
    if (raw is! Map) return null;
    final patch = PreferencePatch.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    return patch.isEmpty ? null : patch;
  }

  String? _toolIntro(AIChatReply reply) {
    final intro = reply.answer?.trim();
    if (intro == null || intro.isEmpty) return null;
    return intro;
  }

  String? _referenceQuery(Map<String, dynamic> args) {
    final value =
        _stringArg(args, 'query') ??
        _stringArg(args, 'name') ??
        _stringArg(args, 'brand') ??
        _stringArg(args, 'reference') ??
        _stringArg(args, 'perfumeName');
    return value?.trim().isEmpty == true ? null : value;
  }

  PerfumeReferenceOptionRef _optionRefFromResolution(
    PerfumeReferenceOption option,
  ) {
    return PerfumeReferenceOptionRef(
      index: option.index,
      name: option.name,
      brand: option.brand,
      source: option.source.name,
      productId: option.productId,
      externalProfileId: option.externalProfileId,
      confidence: option.confidence,
    );
  }

  PerfumeReferenceOption _optionFromMemoryRef(PerfumeReferenceOptionRef ref) {
    final source = switch (ref.source) {
      'catalog' => PerfumeReferenceSource.catalog,
      'externalLookup' => PerfumeReferenceSource.externalLookup,
      'external_lookup' => PerfumeReferenceSource.externalLookup,
      _ => PerfumeReferenceSource.perfumeKnowledge,
    };
    return PerfumeReferenceOption(
      index: ref.index,
      name: ref.name,
      brand: ref.brand,
      source: source,
      productId: ref.productId,
      externalProfileId: ref.externalProfileId,
      confidence: ref.confidence,
    );
  }

  String _perfumeReferenceOptionsQuestion({
    required String query,
    required List<PerfumeReferenceOptionRef> options,
    required AIChatLanguage language,
  }) {
    final optionText = options
        .take(5)
        .map((option) {
          final label = option.brand.trim().isEmpty
              ? option.name
              : '${option.brand} ${option.name}';
          return '${option.index}. $label';
        })
        .join('\n');
    if (language.isArabic) {
      return 'تقصد أي عطر من "$query"؟\n$optionText';
    }
    return 'Which perfume do you mean by "$query"?\n$optionText';
  }

  ExternalProfileRef _externalProfileRef(
    PerfumeKnowledgeProfile profile,
    PerfumeReferenceSource source,
  ) {
    return ExternalProfileRef(
      id: profile.id,
      name: profile.displayName,
      brand: profile.brand,
      fragranceFamily: profile.fragranceFamily,
      notes: profile.preferredNotes.take(8).toList(growable: false),
      tags: profile.accords.take(8).toList(growable: false),
      source: source.name,
      confidence: profile.lookupConfidence,
    );
  }

  ProductModel? _resolveProductFromArgsOrMemory({
    required Map<String, dynamic> args,
    required List<ProductModel> catalog,
    required RecommendationMemory recommendationMemory,
  }) {
    final id =
        _stringArg(args, 'productId') ??
        _stringArg(args, 'product_id') ??
        recommendationMemory.lastFocusedProductId;
    final byId = _productById(catalog, id);
    if (byId != null) return byId;
    final query = _stringArg(args, 'query') ?? _stringArg(args, 'name');
    if (query == null) return null;
    final normalized = query.trim().toLowerCase();
    for (final product in catalog) {
      final labels = <String>{
        product.name,
        product.brand,
        '${product.brand} ${product.name}',
        ...product.aliases,
        ...product.aliasesAr,
      }.map((item) => item.trim().toLowerCase());
      if (labels.any(
        (label) => label == normalized || label.contains(normalized),
      )) {
        return product;
      }
    }
    return null;
  }

  ProductModel? _productById(List<ProductModel> catalog, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final product in catalog) {
      if (product.id == id) return product;
    }
    return null;
  }

  RecommendedProductRef? _memoryRefForProduct(
    ProductModel product,
    RecommendationMemory memory,
  ) {
    for (final ref in memory.lastRecommendedProducts) {
      if (ref.productId == product.id) return ref;
    }
    return null;
  }

  String _catalogProductAnswer(ProductModel product, AIChatLanguage language) {
    final notes = <String>{
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.notes,
    }.where((note) => note.trim().isNotEmpty).take(5).join(', ');
    if (language.isArabic) {
      final notesText = notes.isEmpty ? '' : ' أبرز النوتات: $notes.';
      return '${product.name} من ${product.brand} متاح في الكتالوج بسعر ${product.effectivePrice.toStringAsFixed(0)} EGP.$notesText';
    }
    final notesText = notes.isEmpty ? '' : ' Main notes: $notes.';
    return '${product.name} by ${product.brand} is in the catalog at ${product.effectivePrice.toStringAsFixed(0)} EGP.$notesText';
  }

  List<ProductModel> _lowestAvailableProducts(List<ProductModel> catalog) {
    final available = catalog
        .where((product) => product.isActive && product.stock > 0)
        .toList(growable: false);
    if (available.isEmpty) return const <ProductModel>[];
    final lowestPrice = available
        .map((product) => product.effectivePrice)
        .reduce((value, element) => value < element ? value : element);
    return available
        .where((product) => product.effectivePrice == lowestPrice)
        .toList(growable: false);
  }

  _AnchorResolution _resolveAnchorProduct({
    required Map<String, dynamic> args,
    required List<ProductModel> catalog,
    required RecommendationMemory recommendationMemory,
    required bool allowVisibleMinimumFallback,
  }) {
    final catalogById = {for (final product in catalog) product.id: product};
    final explicitId = _explicitAnchorId(args);
    if (explicitId != null) {
      final product = catalogById[explicitId];
      if (product != null) return _AnchorResolution.product(product);
    }

    final explicitName = _explicitAnchorName(args);
    if (explicitName != null) {
      final normalizedName = explicitName.toLowerCase();
      for (final product in catalog) {
        if (product.name.toLowerCase() == normalizedName ||
            '${product.brand} ${product.name}'.toLowerCase() ==
                normalizedName) {
          return _AnchorResolution.product(product);
        }
      }
    }

    final focusedId = recommendationMemory.lastFocusedProductId;
    if (focusedId != null && catalogById[focusedId] != null) {
      return _AnchorResolution.product(catalogById[focusedId]!);
    }

    final selectedVisible = _selectedVisibleProduct(
      args,
      catalogById,
      recommendationMemory,
    );
    if (selectedVisible != null) {
      return _AnchorResolution.product(selectedVisible);
    }

    final visibleProducts = recommendationMemory.lastRecommendedProducts
        .map((item) => catalogById[item.productId])
        .whereType<ProductModel>()
        .toList(growable: false);
    if (visibleProducts.length == 1) {
      return _AnchorResolution.product(visibleProducts.single);
    }
    if (allowVisibleMinimumFallback && visibleProducts.isNotEmpty) {
      final minimumPrice = visibleProducts
          .map((product) => product.effectivePrice)
          .reduce((value, element) => value < element ? value : element);
      return _AnchorResolution.visibleMinimum(minimumPrice);
    }
    if (visibleProducts.length > 1) {
      return const _AnchorResolution.ambiguous();
    }
    return const _AnchorResolution.missing();
  }

  String? _explicitAnchorId(Map<String, dynamic> args) {
    for (final key in const [
      'anchorProductId',
      'anchorId',
      'productId',
      'selectedProductId',
    ]) {
      final value = _stringArg(args, key);
      if (value != null) return value;
    }
    final anchorRef = _stringArg(args, 'anchorRef');
    if (anchorRef == null) return null;
    final normalized = anchorRef.toLowerCase();
    if (normalized == 'last_focused_product' ||
        normalized == 'focused' ||
        normalized == 'last') {
      return null;
    }
    return anchorRef;
  }

  String? _explicitAnchorName(Map<String, dynamic> args) {
    for (final key in const ['anchorName', 'productName', 'name']) {
      final value = _stringArg(args, key);
      if (value != null) return value;
    }
    return null;
  }

  ProductModel? _selectedVisibleProduct(
    Map<String, dynamic> args,
    Map<String, ProductModel> catalogById,
    RecommendationMemory recommendationMemory,
  ) {
    final rawIndex =
        args['selectedIndex'] ?? args['visibleIndex'] ?? args['index'];
    final selectedIndex = rawIndex is num
        ? rawIndex.toInt()
        : rawIndex is String
        ? int.tryParse(rawIndex.trim())
        : null;
    if (selectedIndex == null) return null;
    for (final item in recommendationMemory.lastRecommendedProducts) {
      if (item.displayIndex == selectedIndex) {
        return catalogById[item.productId];
      }
    }
    return null;
  }

  List<RecommendedProduct> _rankSimilarCheaper({
    required ProductModel referenceProduct,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
    required int limit,
  }) {
    return ReferenceProductSimilarityRanker.rank(
      referenceProduct: referenceProduct,
      catalog: catalog,
      sessionPreferences: currentPreferences,
      effectivePreferences: currentPreferences,
      mode: ReferenceSimilarityMode.similarCheaper,
      limit: limit,
      arabicReasons: language.isArabic,
    );
  }

  List<RecommendedProduct> _rankCheaperThanVisibleMinimum({
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required double priceCeiling,
    required int limit,
  }) {
    final filteredCatalog = catalog
        .where(
          (product) =>
              product.isActive &&
              product.stock > 0 &&
              product.effectivePrice < priceCeiling,
        )
        .toList(growable: false);
    if (filteredCatalog.isEmpty) return const <RecommendedProduct>[];
    return const CatalogSearchShadowService().buildCandidates(
      catalog: filteredCatalog,
      preferences: currentPreferences.copyWith(
        rankingStrategy: RankingStrategy.cheapestFirst,
      ),
      limit: limit,
    );
  }

  List<RecommendedProduct> _rankCatalogAgainstExternalProfile({
    required ExternalProfileRef profile,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
    required double? priceCeiling,
    required int limit,
  }) {
    final profileTerms = _externalProfileTerms(profile);
    if (profileTerms.isEmpty) return const <RecommendedProduct>[];

    final candidates = <_ExternalProfileCandidate>[];
    for (final product in catalog) {
      if (!product.isActive || product.stock <= 0) continue;
      if (priceCeiling != null && product.effectivePrice >= priceCeiling) {
        continue;
      }
      if (_containsExcludedNotes(product, currentPreferences.excludedNotes)) {
        continue;
      }
      if (currentPreferences.gender != null &&
          !_isGenderCompatible(currentPreferences.gender!, product.gender)) {
        continue;
      }

      final productTerms = _productScentTerms(product);
      final sharedTerms = profileTerms.intersection(productTerms);
      if (sharedTerms.isEmpty) continue;
      final scentScore = sharedTerms.length / profileTerms.length;
      if (scentScore < 0.18) continue;
      final priceScore = priceCeiling == null
          ? 0.5
          : (1 - (product.effectivePrice / priceCeiling)).clamp(0.0, 1.0);
      final contextScore = _externalContextScore(product, currentPreferences);
      final score =
          (scentScore * 0.72) + (priceScore * 0.10) + (contextScore * 0.18);
      candidates.add(
        _ExternalProfileCandidate(
          product: product,
          score: score.clamp(0.0, 1.0),
          sharedTerms: sharedTerms.take(4).toList(growable: false),
        ),
      );
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byPrice = a.product.effectivePrice.compareTo(
        b.product.effectivePrice,
      );
      if (byPrice != 0) return byPrice;
      return a.product.name.compareTo(b.product.name);
    });

    return candidates
        .take(limit)
        .map((candidate) {
          return RecommendedProduct(
            product: candidate.product,
            matchScore: candidate.score,
            matchLabel: _externalProfileMatchLabel(
              candidate.score,
              arabic: language.isArabic,
            ),
            matchReason: _externalProfileMatchReason(
              profile: profile,
              candidate: candidate,
              arabic: language.isArabic,
              priceCeiling: priceCeiling,
            ),
            candidateSource: RecommendedCandidateSource.strict,
          );
        })
        .toList(growable: false);
  }

  Set<String> _externalProfileTerms(ExternalProfileRef profile) {
    return {
      profile.fragranceFamily,
      ...profile.notes,
      ...profile.tags,
    }.map(_normalizeTerm).where((item) => item.length >= 3).toSet();
  }

  Set<String> _productScentTerms(ProductModel product) {
    return {
      product.fragranceFamily,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
    }.map(_normalizeTerm).where((item) => item.length >= 3).toSet();
  }

  bool _containsExcludedNotes(
    ProductModel product,
    List<String> excludedNotes,
  ) {
    if (excludedNotes.isEmpty) return false;
    final productTerms = _productScentTerms(product);
    return excludedNotes
        .map(_normalizeTerm)
        .where((item) => item.isNotEmpty)
        .any(productTerms.contains);
  }

  bool _isGenderCompatible(String requestedGender, String productGender) {
    final requested = _normalizeTerm(requestedGender);
    final product = _normalizeTerm(productGender);
    if (requested.isEmpty || requested == 'unisex') return true;
    if (product.isEmpty || product == 'unisex') return true;
    return requested == product;
  }

  double _externalContextScore(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    var score = 0.0;
    var total = 0.0;
    void add(bool matches) {
      total += 1;
      if (matches) score += 1;
    }

    if (preferences.occasion != null) {
      add(
        _normalizeTerm(product.occasion) ==
            _normalizeTerm(preferences.occasion!),
      );
    }
    if (preferences.season != null) {
      final productSeason = _normalizeTerm(product.season);
      final requestedSeason = _normalizeTerm(preferences.season!);
      add(productSeason == requestedSeason || productSeason == 'all seasons');
    }
    if (preferences.intensity != null) {
      add(
        _normalizeTerm(product.intensity) ==
            _normalizeTerm(preferences.intensity!),
      );
    }
    if (total == 0) return 0.5;
    return score / total;
  }

  String _externalProfileMatchLabel(double score, {required bool arabic}) {
    if (score >= 0.58) {
      return arabic ? 'بديل قريب' : 'Close Alternative';
    }
    if (score >= 0.35) {
      return arabic ? 'بديل مناسب' : 'Relevant Alternative';
    }
    return arabic ? 'تطابق محدود' : 'Limited Match';
  }

  String _externalProfileMatchReason({
    required ExternalProfileRef profile,
    required _ExternalProfileCandidate candidate,
    required bool arabic,
    required double? priceCeiling,
  }) {
    final terms = candidate.sharedTerms.take(3).join(arabic ? '، ' : ', ');
    final priceText = priceCeiling != null
        ? (arabic
              ? ' وسعره أقل من المرجع المتاح.'
              : ' and it is below the verified reference price.')
        : '';
    if (arabic) {
      return 'بديل من الكتالوج قريب من طابع ${profile.name} في $terms$priceText';
    }
    return 'Catalog option close to ${profile.name} through $terms$priceText';
  }

  String _externalPriceReferenceMissingDisclosure(
    AIChatLanguage language,
    String profileName,
  ) {
    return language.isArabic
        ? 'أقدر أطابق طابع $profileName، لكن لا أقدر أؤكد أنه أرخص منه لأن السعر المرجعي غير متحقق.'
        : 'I can match the scent profile of $profileName, but I cannot verify that it is cheaper because the reference price is unavailable.';
  }

  String _normalizeTerm(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
  }

  String _budgetFloorDisclosure(
    AIChatLanguage language, {
    required double? requestedBudget,
    required double lowestPrice,
  }) {
    final roundedPrice = lowestPrice.toStringAsFixed(0);
    if (requestedBudget == null) {
      return language.isArabic
          ? 'ده أقل اختيار متاح حاليًا في الكتالوج بسعر $roundedPrice جنيه.'
          : 'This is the lowest available catalog option at $roundedPrice EGP.';
    }
    final roundedBudget = requestedBudget.toStringAsFixed(0);
    return language.isArabic
        ? 'ده أعلى من ميزانيتك الأصلية $roundedBudget جنيه، لكنه أقل سعر متاح حاليًا ($roundedPrice جنيه).'
        : 'This is above your original $roundedBudget EGP budget, but it is the lowest available option at $roundedPrice EGP.';
  }
}

class _ExternalProfileCandidate {
  final ProductModel product;
  final double score;
  final List<String> sharedTerms;

  const _ExternalProfileCandidate({
    required this.product,
    required this.score,
    required this.sharedTerms,
  });
}

enum _AnchorResolutionStatus { product, visibleMinimum, ambiguous, missing }

class _AnchorResolution {
  final _AnchorResolutionStatus status;
  final ProductModel? product;
  final double? priceCeiling;

  const _AnchorResolution.product(this.product)
    : status = _AnchorResolutionStatus.product,
      priceCeiling = null;

  const _AnchorResolution.visibleMinimum(this.priceCeiling)
    : status = _AnchorResolutionStatus.visibleMinimum,
      product = null;

  const _AnchorResolution.ambiguous()
    : status = _AnchorResolutionStatus.ambiguous,
      product = null,
      priceCeiling = null;

  const _AnchorResolution.missing()
    : status = _AnchorResolutionStatus.missing,
      product = null,
      priceCeiling = null;
}
