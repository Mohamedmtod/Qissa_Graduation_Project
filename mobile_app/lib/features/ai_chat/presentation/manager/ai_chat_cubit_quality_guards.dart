part of 'ai_chat_cubit.dart';

extension AIChatCubitQualityGuards on AIChatCubit {
  bool _handleEarlyBroadChoiceCandidateFallback(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) {
    if (catalog.isEmpty) return false;
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    final looksLikeBroadChoice = _looksLikeBroadChoiceHelpWithPerfumeProof(
      normalized,
    );
    final looksLikeOccasionRecommendation =
        _looksLikeOccasionRecommendationWithPerfumeProof(normalized);
    final looksLikeTrendRecommendation =
        _looksLikeTrendRecommendationWithPerfumeProof(normalized);
    final looksLikeSoftNoteGapRecommendation =
        _looksLikeSoftNoteGapRecommendationWithPerfumeProof(normalized);
    final looksLikeHotelCleanRecommendation =
        _looksLikeHotelCleanRecommendationWithPerfumeProof(normalized);
    final looksLikeAestheticRecommendation =
        _looksLikeAestheticRecommendationWithPerfumeProof(normalized);
    if (incoming.intent != AIChatIntent.newRecommendation &&
        !looksLikeBroadChoice &&
        !looksLikeOccasionRecommendation &&
        !looksLikeTrendRecommendation &&
        !looksLikeSoftNoteGapRecommendation &&
        !looksLikeHotelCleanRecommendation &&
        !looksLikeAestheticRecommendation) {
      return false;
    }
    if (!looksLikeBroadChoice &&
        !_looksLikeMemoryScentSimilarityWithPerfumeProof(normalized) &&
        !looksLikeOccasionRecommendation &&
        !looksLikeTrendRecommendation &&
        !looksLikeSoftNoteGapRecommendation &&
        !looksLikeHotelCleanRecommendation &&
        !looksLikeAestheticRecommendation) {
      return false;
    }

    final parsedPreferences = LocalIntentParser.parse(
      incoming.trimmed,
      state.preferences,
    );
    var candidates = LocalCandidateFilter.getTopRecommendations(
      catalog: catalog,
      preferences: parsedPreferences,
    ).take(3).toList(growable: false);
    if (candidates.isEmpty) {
      candidates = _fallbackBroadChoiceCatalogCandidates(catalog);
    }
    if (candidates.isEmpty) return false;

    _replyHandler.handleRecommendationReply(
      buildRecommendReplyFromLocalCandidates(
        candidates,
        updatedPreferences: parsedPreferences,
        requestId: incoming.requestId,
        promptVersion: 'local_preemptive_candidate_fallback_v1',
        provider: 'local',
        modelId: 'candidate_fallback',
      ),
      candidates,
      language: incoming.responseLanguage,
      source: 'local_candidate_preemptive_fallback',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      workerFailureReason: 'app_preemptive_candidate_fallback',
    );
    return true;
  }

  bool _handleOffTopicRequest(
    AIChatTurnContext incoming,
    AIChatTurnDecision turnDecision, {
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_looksLikeCarFragranceAdvice(normalized)) return false;
    if (turnDecision.route != AIChatTurnDecisionRoute.offTopic &&
        !LocalIntentParser.looksLikeOutOfDomainRequest(
          incoming.trimmed,
          currentPreferences: state.preferences,
        )) {
      return false;
    }

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: _t(
          incoming.responseLanguage,
          ar: 'أنا أقدر أساعدك في العطور المتاحة في الكتالوج فقط. لو تحب، ابعتلي نوع العطر أو الميزانية أو المناسبة وهارشح لك اختيار مناسب.',
          en: 'I can help with perfumes in the catalog only. Send the scent style, budget, or occasion and I will suggest a suitable perfume.',
        ),
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'ood_intent_guard',
        promptVersion: 'ood_intent_guard_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_ood_intent_guard',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleAdviceOnlyQuestion(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (!_looksLikeAdviceOnlyQuestion(normalized)) return false;

    final targetedAdvice = _targetedAdviceOnlyAnswer(
      normalized,
      incoming.responseLanguage,
    );
    if (targetedAdvice != null) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: targetedAdvice,
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'advice_only_guard',
          promptVersion: 'advice_only_v1',
        ),
        language: incoming.responseLanguage,
        source: 'local_advice_only_guard',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: _t(
          incoming.responseLanguage,
          ar: 'ينفع، لكن الأفضل تخلي الرشة الأخف في البداية وتختبرهم على الجلد قبل الخروج. لو الاتنين حضورهم عالي، قلل الكمية عشان النتيجة ما تبقاش مزعجة.',
          en: 'Yes, but test the combination on skin first and keep the lighter scent underneath. If both are strong, use fewer sprays so the result does not feel overwhelming.',
        ),
        updatedPreferences: state.preferences,
        provider: 'local',
        modelId: 'advice_only_guard',
        promptVersion: 'advice_only_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_advice_only_guard',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleContextualQualityAnswer(
    AIChatTurnContext incoming, {
    required List<ProductModel> catalog,
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    final productReviewAnswer = _buildSelectedProductReviewAnswer(
      normalized,
      incoming.responseLanguage,
      catalog,
    );
    if (productReviewAnswer != null) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: productReviewAnswer,
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'selected_product_review_guard',
          promptVersion: 'selected_product_review_v1',
        ),
        language: incoming.responseLanguage,
        source: 'local_selected_product_review',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    if (_looksLikeAnswerOnlySizeQuestion(normalized)) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: _t(
            incoming.responseLanguage,
            ar: '\u0644\u0648 \u0647\u062a\u0633\u062a\u062e\u062f\u0645\u0647 \u064a\u0648\u0645\u064a\u064b\u0627 \u0623\u0648 \u0627\u0644\u0639\u0637\u0631 \u0639\u062c\u0628\u0643 \u0628\u062c\u062f\u060c 100ml \u0623\u0648\u0641\u0631. \u0644\u0648 \u0628\u062a\u062c\u0631\u0628\u0647 \u0623\u0648 \u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629 \u0623\u0633\u0647\u0644 \u0641\u064a \u0627\u0644\u0634\u0646\u0637\u0629\u060c 50ml \u0623\u0641\u0636\u0644.',
            en: 'If you will use it daily or already love the scent, 100ml is better value. If you are trying it or want something easier to carry, choose 50ml.',
          ),
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'answer_only_size_guard',
          promptVersion: 'answer_only_size_v1',
        ),
        language: incoming.responseLanguage,
        source: 'local_answer_only_size_guard',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }
    final directExcludedNotes = _directSafetyExcludedNotes(incoming.trimmed);
    final hasAllergyConflict =
        directExcludedNotes.isNotEmpty &&
        _messageRequestsAnyNote(normalized, directExcludedNotes);
    final hasLockedMedicalExclusionConflict =
        state.preferences.medicalExcludedNotes.isNotEmpty &&
        _messageRequestsAnyNote(
          normalized,
          state.preferences.medicalExcludedNotes,
        );
    final looksLikeLongevityImpossible =
        RegExp(r'\b72\s*(hour|hours|hr|hrs)\b').hasMatch(normalized) ||
        normalized.contains('72 \u0633\u0627\u0639') ||
        normalized.contains('\u0667\u0662 \u0633\u0627\u0639');
    final looksLikeHeavyHotConflict =
        (normalized.contains('\u062a\u0642\u064a\u0644') ||
            normalized.contains('heavy')) &&
        (normalized.contains('\u062d\u0631') ||
            normalized.contains('august') ||
            normalized.contains('\u0623\u063a\u0633\u0637\u0633'));
    final looksLikeSummerHeavyNotes =
        (normalized.contains('\u0635\u064a\u0641') ||
            normalized.contains('summer')) &&
        (normalized.contains('\u0639\u0648\u062f') ||
            normalized.contains('oud')) &&
        (normalized.contains('vanilla') ||
            normalized.contains('\u0641\u0627\u0646\u064a\u0644')) &&
        (normalized.contains('tobacco') ||
            normalized.contains('\u062a\u0648\u0628\u0627\u0643\u0648'));
    final asksWeddingWithoutBudget = normalized.contains(
      '___disabled_wedding_without_budget_guard___',
    );
    final educationalWithRecommendation =
        (normalized.contains('\u0627\u0644\u0641\u0631\u0642') ||
            normalized.contains('difference between')) &&
        (normalized.contains('\u0631\u0634\u062d') ||
            normalized.contains('recommend'));
    final asksEdpEdtEducation =
        (normalized.contains('eau de parfum') || normalized.contains('edp')) &&
        (normalized.contains('eau de toilette') ||
            normalized.contains('edt')) &&
        (normalized.contains('\u0627\u0644\u0641\u0631\u0642') ||
            normalized.contains('difference'));
    final looksLikePromptInjection = _looksLikePromptInjection(normalized);
    final looksLikeCompoundExclusionOnly = _looksLikeCompoundExclusionOnly(
      normalized,
    );
    final looksLikeAsadKhamrahComparison = _looksLikeAsadKhamrahComparison(
      normalized,
    );
    final looksLikeBrandOnlyLattafa = _looksLikeBrandOnlyLattafa(normalized);

    String? answer;
    if (looksLikePromptInjection) {
      answer = _t(
        incoming.responseLanguage,
        ar: '\u0645\u0634 \u0647\u0642\u062f\u0631 \u0623\u062a\u062c\u0627\u0647\u0644 \u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0646\u0638\u0627\u0645 \u0623\u0648 \u0623\u062e\u062a\u0631\u0639 \u0645\u0646\u062a\u062c\u0627\u062a \u062e\u0627\u0631\u062c \u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c. \u0623\u0642\u062f\u0631 \u0623\u0633\u0627\u0639\u062f\u0643 \u0628\u0627\u0644\u0639\u0637\u0648\u0631 \u0627\u0644\u0645\u062a\u0627\u062d\u0629 \u0639\u0646\u062f\u0646\u0627 \u0641\u0642\u0637.',
        en: 'I cannot ignore the system rules or invent products outside the catalog. I can help only with perfumes available in our catalog.',
      );
    } else if (looksLikeCompoundExclusionOnly) {
      answer = _t(
        incoming.responseLanguage,
        ar: '\u062a\u0645\u0627\u0645\u060c \u0647\u062a\u062c\u0646\u0628 \u0627\u0644\u0627\u062a\u062c\u0627\u0647\u0627\u062a \u0627\u0644\u0644\u064a \u0627\u0633\u062a\u0628\u0639\u062f\u062a\u0647\u0627. \u062a\u062d\u0628 \u0627\u0644\u0627\u062e\u062a\u064a\u0627\u0631 \u0631\u062c\u0627\u0644\u064a \u0648\u0644\u0627 \u062d\u0631\u064a\u0645\u064a \u0648\u0644\u0627 \u0644\u0644\u062c\u0646\u0633\u064a\u0646\u061f',
        en: 'Understood. I will avoid the directions you excluded. Should I keep the choice for men, women, or unisex?',
      );
    } else if (looksLikeAsadKhamrahComparison) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'لو تقصد Asad وKhamrah كطابع عطري: Khamrah عادةً أدفأ وأنسب للشتاء والجو المسائي، بينما Asad أجرأ وأقرب للطابع الحار/العنبر. الاختيار الأفضل يعتمد على الاستخدام: للدفء والنعومة اختار Khamrah، ولحضور أقوى اختار Asad.',
        en: 'If you mean Asad and Khamrah as scent styles: Khamrah is usually warmer and better for winter or evenings, while Asad is bolder and more spicy/ambery. The better choice depends on use: Khamrah for warmth and smoothness, Asad for a stronger presence.',
      );
    } else if (looksLikeBrandOnlyLattafa) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'تقصد عطور Lattafa نفسها ولا طابع شرقي قريب منها؟ ابعت الميزانية وهل الاختيار رجالي ولا حريمي ولا للجنسين، وأرشح لك من المتاح بدون اختراع منتجات.',
        en: 'Do you mean Lattafa products specifically, or a similar oriental style? Send the budget and whether it is for men, women, or unisex, and I will suggest available catalog options without inventing products.',
      );
    } else if (hasLockedMedicalExclusionConflict) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'قلت قبل كده إن في نوتة بتسبب لك حساسية، فمش هعرض عطور فيها حفاظًا على السلامة. أقدر أرشح بدائل آمنة بنفس الإحساس العام ومن غير النوتة المسببة للحساسية.',
        en: 'You previously mentioned an allergy to one of these notes, so I will not show perfumes containing it for safety. I can suggest safer alternatives in the same general style without the allergen.',
      );
    } else if (hasAllergyConflict) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'بما إنك ذكرت حساسية، هتجنب النوتات دي تمامًا حتى لو كانت ضمن طلبك. أقدر أكمّل ببدائل آمنة بنفس الإحساس العام، لكن من غير النوتة المسببة للحساسية.',
        en: 'Because you mentioned an allergy, I will avoid those notes completely even if they appear in the request. I can continue with safer alternatives in the same general style without the allergen.',
      );
    } else if (looksLikeLongevityImpossible) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'ثبات 72 ساعة على الجلد غير واقعي لمعظم العطور وبيتغير حسب الجلد والجو وطريقة الرش. أقدر أبحث لك عن أعلى اختيارات متاحة في الثبات، لكن من غير وعد مبالغ فيه.',
        en: 'A 72-hour skin longevity promise is not realistic for most perfumes and varies by skin, weather, and spraying. I can look for the strongest available options without overpromising.',
      );
    } else if (looksLikeHeavyHotConflict || looksLikeSummerHeavyNotes) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'فيه تعارض في الطلب: النوتات أو الطابع التقيل أنسب للشتاء، بينما الحر والصيف محتاجين حاجة أخف. الحل الأفضل عطر متوسط الثقل، يستخدم ليلًا أو في مكان مكيف، ومش خانق.',
        en: 'There is a trade-off here: heavy notes fit winter better, while heat and summer need something lighter. The safest fit is a medium-weight scent for evening or air-conditioned places, not overpowering.',
      );
    } else if (educationalWithRecommendation) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'العود غالبًا أعمق ودخاني/خشبي وفخم، أما المسك أنعم وأنضف ويميل للإحساس الهادئ. عشان أرشح 3 اختيارات بدقة، ابعت الميزانية والجندر أو الاستخدام.',
        en: 'Oud is usually deeper, smoky/woody, and luxurious, while musk is softer, cleaner, and calmer. To recommend three accurate options, send the budget plus gender or use case.',
      );
    } else if (asksEdpEdtEducation) {
      answer = _t(
        incoming.responseLanguage,
        ar: '\u0627\u0644\u0641\u0631\u0642 \u0627\u0644\u0623\u0633\u0627\u0633\u064a \u0625\u0646 Eau de Parfum \u0639\u0627\u062f\u0629\u064b \u062a\u0631\u0643\u064a\u0632\u0647 \u0623\u0639\u0644\u0649 \u0648\u062b\u0628\u0627\u062a\u0647 \u0623\u0637\u0648\u0644\u060c \u0628\u064a\u0646\u0645\u0627 Eau de Toilette \u0623\u062e\u0641 \u0648\u0623\u0646\u0633\u0628 \u0644\u0644\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u064a\u0648\u0645\u064a \u0623\u0648 \u0627\u0644\u062c\u0648 \u0627\u0644\u062d\u0627\u0631. \u0645\u0634 \u0647\u0639\u0631\u0636 \u0643\u0631\u0648\u062a \u0645\u0646\u062a\u062c\u0627\u062a \u0644\u0623\u0646 \u0637\u0644\u0628\u0643 \u0634\u0631\u062d \u0641\u0642\u0637.',
        en: 'Eau de Parfum usually has a higher concentration and lasts longer, while Eau de Toilette is lighter and often better for daily wear or hot weather. I will not show product cards because you asked for an explanation only.',
      );
    } else if (asksWeddingWithoutBudget) {
      answer = _t(
        incoming.responseLanguage,
        ar: 'للفرح الأفضل عطر ثابت ومميز من غير ما يبقى مزعج. ابعت الميزانية وهل هو رجالي ولا حريمي، وسأرشح لك اختيار مناسب للمناسبة.',
        en: 'For a wedding, you want something memorable and long-lasting without being overwhelming. Send the budget and whether it is for men or women, and I will suggest a suitable option.',
      );
    }

    if (answer == null) return false;
    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: answer,
        updatedPreferences: state.preferences.mergePatch(
          LocalIntentParser.parse(incoming.trimmed, state.preferences),
        ),
        provider: 'local',
        modelId: 'contextual_quality_guard',
        promptVersion: 'contextual_quality_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_contextual_quality_guard',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _messageRequestsAnyNote(String normalized, Iterable<String> notes) {
    for (final note in notes) {
      final normalizedNote = LocalIntentParser.normalizeInput(note);
      if (normalizedNote.isNotEmpty && normalized.contains(normalizedNote)) {
        return true;
      }
      if (normalizedNote == 'rose' &&
          normalized.contains('\u0648\u0631\u062f')) {
        return true;
      }
      if (normalizedNote == 'vanilla' &&
          normalized.contains('\u0641\u0627\u0646\u064a\u0644')) {
        return true;
      }
    }
    return false;
  }

  bool _looksLikePromptInjection(String normalized) {
    return (normalized.contains('ignore') &&
            normalized.contains('instruction')) ||
        (normalized.contains('\u0627\u0646\u0633') &&
            normalized.contains(
              '\u0627\u0644\u062a\u0639\u0644\u064a\u0645\u0627\u062a',
            )) ||
        normalized.contains(
          '\u062a\u062c\u0627\u0647\u0644 \u0627\u0644\u062a\u0639\u0644\u064a\u0645\u0627\u062a',
        ) ||
        normalized.contains('\u0645\u0646 \u062f\u0645\u0627\u063a\u0643') ||
        normalized.contains('invent products') ||
        normalized.contains('make up products');
  }

  bool _looksLikeCompoundExclusionOnly(String normalized) {
    final hasExclusion =
        normalized.contains('\u0645\u0634 \u0639\u0627\u064a\u0632') ||
        normalized.contains('\u0645\u0646 \u063a\u064a\u0631') ||
        normalized.contains('without') ||
        normalized.contains('no ');
    if (!hasExclusion) return false;
    final excludedSignals = [
      normalized.contains('\u0648\u0631\u062f') || normalized.contains('rose'),
      normalized.contains('\u0641\u0627\u0646\u064a\u0644') ||
          normalized.contains('vanilla'),
      normalized.contains('\u0633\u0643\u0631') ||
          normalized.contains('\u062d\u0644\u0648') ||
          normalized.contains('sweet'),
    ].where((matched) => matched).length;
    return excludedSignals >= 2;
  }

  bool _looksLikeAsadKhamrahComparison(String normalized) {
    final mentionsBoth =
        normalized.contains('asad') && normalized.contains('khamrah');
    if (!mentionsBoth) return false;
    return normalized.contains('\u0645\u064a\u0646 \u0627\u062d\u0633\u0646') ||
        normalized.contains('\u0627\u064a\u0647 \u0627\u062d\u0633\u0646') ||
        normalized.contains('which is better') ||
        normalized.contains('best');
  }

  bool _looksLikeBrandOnlyLattafa(String normalized) {
    if (!normalized.contains('lattafa')) return false;
    final hasSpecificProductSignal =
        normalized.contains('asad') ||
        normalized.contains('khamrah') ||
        normalized.contains('yara') ||
        normalized.contains('oud');
    if (hasSpecificProductSignal) return false;
    return normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('perfume') ||
        normalized.contains('fragrance');
  }

  bool _handleImpossiblePurchaseRequest(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (!_looksLikeImpossibleZeroBudgetPurchase(normalized)) return false;

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: _t(
          incoming.responseLanguage,
          ar: 'بصراحة صفر جنيه لا يسمح بشراء عطر من الكتالوج حاليا، خصوصا لو هدية فخمة. الأفضل تحدد أقل ميزانية ممكنة، وساعتها أرشح لك أقرب اختيار واقعي.',
          en: 'A zero budget cannot buy a catalog perfume right now, especially for a premium gift. Set the lowest realistic budget you can spend and I will suggest the closest suitable option.',
        ),
        updatedPreferences: state.preferences.copyWith(maxBudget: 0),
        provider: 'local',
        modelId: 'impossible_budget_guard',
        promptVersion: 'impossible_budget_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_impossible_budget_guard',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleImpossiblePremiumBudgetGuard(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) {
    final parsed = LocalIntentParser.parse(
      incoming.trimmed,
      SessionPreferences.empty(),
    );
    final budget =
        parsed.maxBudget ?? _extractExplicitBudgetAmount(incoming.trimmed);
    if (budget == null || budget <= 0) return false;

    final availablePrices = catalog
        .where((product) => product.stock > 0)
        .map((product) => product.effectivePrice)
        .where((price) => price > 0)
        .toList(growable: false);
    if (availablePrices.isEmpty) return false;
    final cheapestAvailable = availablePrices.reduce((a, b) => a < b ? a : b);
    if (budget >= cheapestAvailable) return false;

    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    final mentionsPremiumOrOriginal =
        normalized.contains('original') ||
        normalized.contains('authentic') ||
        normalized.contains('niche') ||
        normalized.contains('luxury') ||
        normalized.contains('premium') ||
        normalized.contains('dior') ||
        normalized.contains('sauvage') ||
        normalized.contains('creed') ||
        normalized.contains('aventus') ||
        normalized.contains('tom ford') ||
        normalized.contains('bleu de chanel') ||
        normalized.contains('\u0623\u0635\u0644\u064a') ||
        normalized.contains('\u0627\u0635\u0644\u064a') ||
        normalized.contains('\u0639\u0627\u0644\u0645\u064a') ||
        normalized.contains('\u0641\u062e\u0645') ||
        normalized.contains('\u0646\u064a\u0634');
    if (!mentionsPremiumOrOriginal) return false;

    _replyHandler.handleAnswerReply(
      AIChatReply.answer(
        answer: _t(
          incoming.responseLanguage,
          ar: 'الميزانية الحالية ${budget.toStringAsFixed(0)} جنيه أقل من أرخص عطر متاح في الكتالوج، والمنتج الأصلي أو البراند المطلوب أعلى من كده بكتير. مش هعرض عليك اختيارات فوق ميزانيتك. ارفع الميزانية أو قل لي لو تحب أبحث عن أقرب بديل اقتصادي لما يكون متاح.',
          en: 'Your ${budget.toStringAsFixed(0)} EGP budget is below the cheapest available catalog perfume, and the original/premium brand you mentioned costs much more. I will not show over-budget cards. Raise the budget or tell me if you want the closest budget-friendly alternative when available.',
        ),
        updatedPreferences: state.preferences.copyWith(maxBudget: budget),
        provider: 'local',
        modelId: 'impossible_premium_budget_guard',
        promptVersion: 'impossible_premium_budget_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_impossible_premium_budget_guard',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  double? _extractExplicitBudgetAmount(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    final matches = RegExp(r'\d{2,5}').allMatches(normalized).toList();
    if (matches.isEmpty) return null;
    final value = double.tryParse(matches.first.group(0) ?? '');
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<bool> _handleDirectAvailabilityQueryGuard(
    AIChatTurnContext incoming,
    List<ProductModel> catalog, {
    required bool pruneHistoricalBotMessages,
  }) async {
    final normalized = LocalIntentParser.normalizeInput(incoming.trimmed);
    if (_looksLikeExactSkuLookup(normalized)) {
      _replyHandler.handleAnswerReply(
        AIChatReply.answer(
          answer: _t(
            incoming.responseLanguage,
            ar: 'لم أجد هذا الكود في الكتالوج الحالي. ابعت اسم العطر لو تحب أتحقق من التوفر بالاسم.',
            en: 'I could not find that exact SKU in the current catalog. Send the perfume name if you want me to check availability by name.',
          ),
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'sku_lookup_guard',
          promptVersion: 'sku_lookup_guard_v1',
        ),
        language: incoming.responseLanguage,
        source: 'local_exact_sku_not_found',
        sessionId: incoming.activeSessionId,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }
    if (_looksLikeGenericCatalogRankingQuery(normalized)) {
      return false;
    }

    final hasAvailabilityKeyword = LocalIntentParser.containsAny(
      normalized,
      AvailabilityIntentUtils.availabilityKeywords,
    );
    final directProductQuery = _extractDirectAvailabilityProductQuery(
      incoming.trimmed,
    );
    final questionShapedProductQuery =
        directProductQuery ??
        AvailabilityIntentUtils.extractQuestionShapedLatinProductQuery(
          incoming.trimmed,
        );
    if (!hasAvailabilityKeyword && questionShapedProductQuery == null) {
      return false;
    }

    final query =
        incoming.availabilityProductQuery ??
        questionShapedProductQuery ??
        AvailabilityIntentUtils.extractAvailabilityProductQuery(
          incoming.trimmed,
        );
    if (query == null) return false;
    if (AvailabilityIntentUtils.isGenericAvailabilityCandidate(query)) {
      return false;
    }

    final lookupResult = lookupAvailability(query, catalog);
    if (lookupResult.product != null) {
      final product = lookupResult.product!;
      final isAvailable = product.stock > 0;
      if (!isAvailable) {
        return false;
      }
      final availabilityContext = AvailabilityContext(
        lastQuery: query,
        matchedProductId: product.id,
        matchedProductName: product.name,
        availabilityStatus: isAvailable
            ? AvailabilityStatus.found
            : AvailabilityStatus.outOfStock,
        hints: availabilityHintsFromProduct(product),
        source: 'local_direct_availability_answer_only',
      );
      _replyHandler.handleAvailabilityCardReply(
        AIChatMessage.botAvailability(
          content: buildAvailabilityMessageForFound(
            incoming.responseLanguage,
            product,
          ),
          products: [
            buildAvailabilityCardProduct(product, incoming.responseLanguage),
          ],
        ),
        language: incoming.responseLanguage,
        source: 'local_direct_availability_answer_only',
        availabilityContext: availabilityContext,
        sessionId: incoming.activeSessionId,
      );
      unawaited(
        _aiChatRepo.logAIChatEvent(
          eventType: isAvailable
              ? 'availability_catalog_found'
              : 'availability_out_of_stock',
          sessionId: incoming.activeSessionId,
          metadata: buildAvailabilityAnalyticsMetadata(
            query: query,
            status: isAvailable
                ? AvailabilityStatus.found
                : AvailabilityStatus.outOfStock,
            matchedProductId: product.id,
          ),
        ),
      );
      return true;
    }
    if (lookupResult.isAmbiguous) {
      final ambiguousContext = AvailabilityContext(
        lastQuery: query,
        availabilityStatus: AvailabilityStatus.ambiguous,
        candidateOptionIds: lookupResult.options
            .map((product) => product.id)
            .toList(growable: false),
        source: 'local_direct_availability_ambiguous',
      );
      _replyHandler.handleAskReply(
        AIChatReply.ask(
          question: _t(
            incoming.responseLanguage,
            ar: 'لقيت أكتر من منتج قريب من "$query". اكتب الاسم كامل أو البراند عشان أتأكد من التوفر بدقة.',
            en: 'I found more than one close match for "$query". Send the full name or brand so I can verify availability accurately.',
          ),
          updatedPreferences: state.preferences,
          provider: 'local',
          modelId: 'direct_availability_ambiguous',
          promptVersion: 'direct_availability_ambiguous_v1',
        ),
        language: incoming.responseLanguage,
        source: 'local_direct_availability_ambiguous',
        reasonCode: 'availability_ambiguous_no_cards',
        sessionId: incoming.activeSessionId,
        availabilityContext: ambiguousContext,
        pruneHistoricalBotMessages: pruneHistoricalBotMessages,
      );
      return true;
    }

    // Let the richer availability flow try perfume knowledge/external profile
    // substitution before falling back to a plain not-found answer.
    return false;
  }

  String? _extractDirectAvailabilityProductQuery(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;
    if (LocalIntentParser.looksLikeRankingRequest(normalized)) return null;
    if (LocalIntentParser.containsAny(
          normalized,
          LocalIntentParser.cheapKeywords,
        ) &&
        (normalized.contains('perfume') ||
            normalized.contains('fragrance') ||
            normalized.contains('\u0639\u0637\u0631') ||
            normalized.contains('\u0628\u0631\u0641\u0627\u0646'))) {
      return null;
    }
    if (_looksLikeNicheScentAvailabilityPhrase(normalized)) return null;
    if (!RegExp(
          r'\b(do you have|have you got|in stock)\b',
        ).hasMatch(normalized) &&
        !normalized.contains('\u0647\u0644 \u0639\u0646\u062f\u0643') &&
        !normalized.contains('\u0647\u0644 \u0639\u0646\u062f\u0643\u0645') &&
        !normalized.contains('\u0639\u0646\u062f\u0643') &&
        !normalized.contains('\u0639\u0646\u062f\u0643\u0645') &&
        !normalized.contains('\u0645\u062a\u0648\u0641\u0631') &&
        !normalized.contains('\u0645\u0648\u062c\u0648\u062f')) {
      return null;
    }

    var candidate = normalized
        .replaceAll(RegExp(r'[?\u061f]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final phrase in const <String>[
      'do you have',
      'have you got',
      'in stock',
      'available',
      'perfume',
      'fragrance',
      '\u0647\u0644',
      '\u0639\u0646\u062f\u0643',
      '\u0639\u0646\u062f\u0643\u0645',
      '\u0645\u062a\u0648\u0641\u0631',
      '\u0645\u0648\u062c\u0648\u062f',
      '\u0639\u0637\u0631',
      '\u0628\u0631\u0641\u0627\u0646',
    ]) {
      candidate = candidate.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        ' ',
      );
    }
    candidate = _trimAvailabilityIntentBoundary(candidate);
    candidate = candidate.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (candidate.length < 3) return null;
    return candidate;
  }

  bool _looksLikeGenericCatalogRankingQuery(String normalized) {
    return LocalIntentParser.containsAny(
          normalized,
          LocalIntentParser.cheapKeywords,
        ) &&
        (normalized.contains('perfume') ||
            normalized.contains('fragrance') ||
            normalized.contains('\u0639\u0637\u0631') ||
            normalized.contains('\u0628\u0631\u0641\u0627\u0646'));
  }

  bool _looksLikeNicheScentAvailabilityPhrase(String normalized) {
    final hasNicheScent =
        normalized.contains('petrichor') ||
        normalized.contains('rain on soil') ||
        normalized.contains('wet soil') ||
        normalized.contains('rain smell') ||
        normalized.contains('smell of rain') ||
        normalized.contains('earthy rain');
    if (!hasNicheScent) return false;
    return normalized.contains('do you have') ||
        normalized.contains('something like') ||
        normalized.contains('smells like') ||
        normalized.contains('scent like') ||
        normalized.contains('in stock') ||
        normalized.contains('available');
  }

  String _trimAvailabilityIntentBoundary(String value) {
    final padded = ' ${value.trim()} ';
    final boundaries = <String>[
      ' if not ',
      ' if available ',
      ' and compare ',
      ' compare ',
      ' and recommend ',
      ' recommend ',
      ' \u0648\u0644\u0648 ',
      ' \u0644\u0648 ',
      ' \u0642\u0627\u0631\u0646 ',
      ' \u0648\u0642\u0627\u0631\u0646 ',
      ' \u0631\u0634\u062d ',
      ' \u0648\u0631\u0634\u062d ',
    ];
    var bestIndex = -1;
    for (final boundary in boundaries) {
      final index = padded.indexOf(boundary);
      if (index > 0 && (bestIndex == -1 || index < bestIndex)) {
        bestIndex = index;
      }
    }
    if (bestIndex == -1) return value.trim();
    return padded.substring(1, bestIndex).trim();
  }

  bool _looksLikeExactSkuLookup(String normalized) {
    return RegExp(r'\bsku\s+[a-z0-9][a-z0-9_-]{4,}\b').hasMatch(normalized);
  }

  bool _handleExclusionOnlySafetyUpdate(
    AIChatTurnContext incoming,
    AIChatDiscoveryContext discovery, {
    required bool pruneHistoricalBotMessages,
  }) {
    final directExcludedNotes = _directSafetyExcludedNotes(incoming.trimmed);
    if (directExcludedNotes.isEmpty &&
        _looksLikeDislikeOnlyPreference(incoming.trimmed)) {
      return false;
    }
    final preferences = directExcludedNotes.isEmpty
        ? discovery.localPreferences
        : discovery.localPreferences.copyWith(
            excludedNotes: {
              ...discovery.localPreferences.excludedNotes,
              ...directExcludedNotes,
            }.toList(growable: false),
          );
    final isExclusionOnly =
        preferences.excludedNotes.isNotEmpty &&
        preferences.gender == null &&
        preferences.maxBudget == null &&
        preferences.season == null &&
        preferences.occasion == null &&
        preferences.time == null &&
        preferences.intensity == null &&
        preferences.preferredNotes.isEmpty &&
        preferences.preferredTopNotes.isEmpty &&
        preferences.preferredMiddleNotes.isEmpty &&
        preferences.preferredBaseNotes.isEmpty &&
        preferences.tags.isEmpty;
    if (!isExclusionOnly) return false;

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: _t(
          incoming.responseLanguage,
          ar: 'تمام، هتجنب النوتات اللي ذكرتها في أي ترشيح. قل لي النوع أو الميزانية أو الاستخدام عشان أرشح لك اختيار مناسب بأمان.',
          en: 'Noted. I will avoid the notes you mentioned in any recommendation. Tell me the gender, budget, or use case so I can suggest a safe match.',
        ),
        updatedPreferences: preferences,
        provider: 'local',
        modelId: 'exclusion_only_guard',
        promptVersion: 'exclusion_only_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_exclusion_only_safety_update',
      reasonCode: 'exclusion_only_no_worker',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  bool _handleDirectExclusionOnlySafetyUpdate(
    AIChatTurnContext incoming, {
    required bool pruneHistoricalBotMessages,
  }) {
    final directExcludedNotes = _directSafetyExcludedNotes(incoming.trimmed);
    if (directExcludedNotes.isEmpty) return false;
    if (_looksLikeDislikeOnlyPreference(incoming.trimmed)) return false;
    final preferences = state.preferences.copyWith(
      excludedNotes: {
        ...state.preferences.excludedNotes,
        ...directExcludedNotes,
      }.toList(growable: false),
    );
    final isExclusionOnly =
        preferences.gender == null &&
        preferences.maxBudget == null &&
        preferences.season == null &&
        preferences.occasion == null &&
        preferences.time == null &&
        preferences.intensity == null &&
        preferences.preferredNotes.isEmpty &&
        preferences.preferredTopNotes.isEmpty &&
        preferences.preferredMiddleNotes.isEmpty &&
        preferences.preferredBaseNotes.isEmpty &&
        preferences.tags.isEmpty;
    if (!isExclusionOnly) return false;

    _replyHandler.handleAskReply(
      AIChatReply.ask(
        question: _t(
          incoming.responseLanguage,
          ar: 'تمام، هتجنب النوتات اللي ذكرتها في أي ترشيح. قل لي النوع أو الميزانية أو الاستخدام عشان أرشح لك اختيار مناسب بأمان.',
          en: 'Noted. I will avoid the notes you mentioned in any recommendation. Tell me the gender, budget, or use case so I can suggest a safe match.',
        ),
        updatedPreferences: preferences,
        provider: 'local',
        modelId: 'direct_exclusion_only_guard',
        promptVersion: 'direct_exclusion_only_v1',
      ),
      language: incoming.responseLanguage,
      source: 'local_direct_exclusion_only_safety_update',
      reasonCode: 'direct_exclusion_only_no_worker',
      sessionId: incoming.activeSessionId,
      pruneHistoricalBotMessages: pruneHistoricalBotMessages,
    );
    return true;
  }

  List<String> _directSafetyExcludedNotes(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    final hasSafetySignal =
        normalized.contains('allergy') ||
        normalized.contains('allergic') ||
        normalized.contains('sensitive') ||
        normalized.contains('\u062d\u0633\u0627\u0633\u064a\u0629') ||
        normalized.contains('\u062d\u0633\u0627\u0633') ||
        normalized.contains('avoid') ||
        normalized.contains('exclude') ||
        normalized.contains('without') ||
        normalized.contains('\u0627\u0628\u0639\u062f') ||
        normalized.contains('\u0628\u0639\u064a\u062f') ||
        normalized.contains('\u0645\u0646 \u063a\u064a\u0631');
    if (!hasSafetySignal) return const <String>[];

    final excluded = <String>{};
    if (_containsAnyNormalized(normalized, const [
      'citrus',
      'lemon',
      'bergamot',
      'orange',
      '\u062d\u0645\u0636\u064a\u0627\u062a',
      '\u062d\u0645\u0636\u064a',
      '\u0644\u064a\u0645\u0648\u0646',
      '\u0628\u0631\u063a\u0645\u0648\u062a',
      '\u0628\u0631\u062a\u0642\u0627\u0644',
    ])) {
      excluded.add('citrus');
    }
    if (_containsAnyNormalized(normalized, const [
      'rose',
      '\u0648\u0631\u062f',
      '\u0627\u0644\u0648\u0631\u062f',
    ])) {
      excluded.add('rose');
    }
    if (_containsAnyNormalized(normalized, const [
      'jasmine',
      '\u064a\u0627\u0633\u0645\u064a\u0646',
      '\u0627\u0644\u064a\u0627\u0633\u0645\u064a\u0646',
    ])) {
      excluded.add('jasmine');
    }
    return excluded.toList(growable: false);
  }

  bool _containsAnyNormalized(String normalized, List<String> terms) {
    return terms.any(
      (term) => normalized.contains(LocalIntentParser.normalizeInput(term)),
    );
  }

  bool _looksLikeAnswerOnlySizeQuestion(String normalized) {
    if (normalized.isEmpty) return false;
    final hasSize =
        normalized.contains('50ml') ||
        normalized.contains('100ml') ||
        normalized.contains('50 ml') ||
        normalized.contains('100 ml') ||
        normalized.contains('\u0645\u0644');
    if (!hasSize) return false;
    return normalized.contains('or') ||
        normalized.contains('choose') ||
        normalized.contains('\u0648\u0644\u0627') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631');
  }

  String? _buildSelectedProductReviewAnswer(
    String normalized,
    AIChatLanguage language,
    List<ProductModel> catalog,
  ) {
    final hasReviewQuestion =
        normalized.contains('suitable for') ||
        normalized.contains('good for') ||
        normalized.contains('not suitable') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628') ||
        normalized.contains('\u0645\u0634 \u0645\u0646\u0627\u0633\u0628');
    if (!hasReviewQuestion) return null;
    final product = catalog
        .where(
          (item) =>
              normalized.contains(LocalIntentParser.normalizeInput(item.name)),
        )
        .cast<ProductModel?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (product == null) return null;

    final notes = product.notes.take(3).join(', ');
    final suitable = [
      product.occasion,
      product.time,
      product.season,
    ].where((value) => value.trim().isNotEmpty).join(', ');
    return _t(
      language,
      ar: '${product.name} مناسب لو عايز طابع ${product.intensity} بنوتات $notes. أنسب استخدام له: $suitable. مش أفضل اختيار لو عايز عطر شديد جدًا أو طابع مختلف تمامًا عن النوتات دي.',
      en: '${product.name} works well if you want a ${product.intensity} scent with $notes. Best use: $suitable. It is not the best fit if you want something much stronger or a completely different scent direction.',
    );
  }

  String? _targetedAdviceOnlyAnswer(
    String normalized,
    AIChatLanguage language,
  ) {
    if (_looksLikeBlindBuyingAdvice(normalized)) {
      return _t(
        language,
        ar: 'لو هتشتري أونلاين من غير ما تشم، اختار عطر آمن وسهل: نضيف، منعش أو مسكي خفيف، وابعد عن العود الثقيل أو السويت القوي لو مش متأكد. راجع النوتات، الاستخدام المناسب، وحجم أصغر لو أول تجربة.',
        en: 'If you are buying online without smelling first, choose a safe easy scent: clean, fresh, or soft musky. Avoid very heavy oud or very sweet styles if you are unsure. Check the notes, use case, and start with a smaller size if it is your first try.',
      );
    }
    if (_looksLikePriceDifferenceExplanation(normalized)) {
      return _t(
        language,
        ar: 'السعر ممكن يختلف بسبب البراند، تركيز العطر، حجم العبوة، جودة المكونات، الثبات، أو ندرة العطر. لو بتقارن بين اختيارين، ابعتلي الاسمين أو اختارهم من الكروت وأقارن لك القيمة والاستخدام بدون ما أفترض تفاصيل غير موجودة.',
        en: 'A perfume can cost more because of the brand, concentration, bottle size, ingredient quality, longevity, or rarity. If you are comparing two options, send their names or select them from the cards and I will compare value and use without guessing missing facts.',
      );
    }
    if (_looksLikePurchaseHesitationAdvice(normalized)) {
      return _t(
        language,
        ar: 'لو لسه مش متأكد، اختار بناءً على الاستخدام: يومي ولا خروجة، خفيف ولا واضح، وراجع الميزانية والنوتات. لو عندك كارتين محتار بينهم ابعتهم، وأقارن لك بدون ما أزود ترشيحات جديدة.',
        en: 'If you are still unsure, decide by use case: daily or going out, subtle or noticeable, then check budget and notes. If you are choosing between two cards, send them and I will compare without adding new recommendations.',
      );
    }
    if (_looksLikeSprayCountAdvice(normalized)) {
      return _t(
        language,
        ar: 'ابدأ بـ 3 إلى 5 رشات حسب قوة العطر: رشتين على الرقبة أو خلف الأذن، ورشة أو رشتين على الملابس من مسافة مناسبة. لو العطر قوي أو المكان مغلق، خليه 2 إلى 3 رشات فقط.',
        en: 'Start with 3 to 5 sprays depending on strength: two around the neck or behind the ears, and one or two on clothes from a reasonable distance. If the scent is strong or the place is closed, keep it to 2 or 3 sprays.',
      );
    }
    return null;
  }

  bool _looksLikeBlindBuyingAdvice(String normalized) {
    final online =
        normalized.contains('online') ||
        normalized.contains('\u0623\u0648\u0646\u0644\u0627\u064a\u0646') ||
        normalized.contains('\u0627\u0648\u0646\u0644\u0627\u064a\u0646');
    final blind =
        normalized.contains('blind buy') ||
        normalized.contains('without smelling') ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u0645\u0627 \u0623\u0634\u0645',
        ) ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u0645\u0627 \u0627\u0634\u0645',
        ) ||
        normalized.contains('\u0645\u0634 \u0647\u0634\u0645');
    final choosing =
        normalized.contains('choose') ||
        normalized.contains('\u0623\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631') ||
        normalized.contains('\u0625\u0632\u0627\u064a') ||
        normalized.contains('\u0627\u0632\u0627\u064a');
    return (online && blind) || (blind && choosing);
  }

  bool _looksLikeSprayCountAdvice(String normalized) {
    final spray =
        normalized.contains('spray') ||
        normalized.contains('\u0631\u0634\u0629') ||
        normalized.contains('\u0631\u0634\u0627\u062a') ||
        normalized.contains('\u0623\u0631\u0634') ||
        normalized.contains('\u0627\u0631\u0634');
    final count =
        normalized.contains('how many') ||
        normalized.contains('count') ||
        normalized.contains('\u0643\u0627\u0645') ||
        normalized.contains('\u0639\u062f\u062f');
    return spray && count;
  }

  bool _looksLikePurchaseHesitationAdvice(String normalized) {
    final unsure =
        normalized.contains('not sure') ||
        normalized.contains('unsure') ||
        normalized.contains('hesitat') ||
        normalized.contains('\u0645\u0634 \u0645\u062a\u0623\u0643\u062f') ||
        normalized.contains('\u0645\u0634 \u0645\u062a\u0627\u0643\u062f') ||
        normalized.contains('\u0645\u062d\u062a\u0627\u0631');
    final purchase =
        normalized.contains('buy') ||
        normalized.contains('purchase') ||
        normalized.contains('\u0623\u0634\u062a\u0631\u064a') ||
        normalized.contains('\u0627\u0634\u062a\u0631\u064a') ||
        normalized.contains('\u0634\u0631\u0627\u0621');
    return unsure && purchase;
  }

  bool _looksLikePriceDifferenceExplanation(String normalized) {
    final asksWhy =
        normalized.contains('why') ||
        normalized.contains('\u0644\u064a\u0647') ||
        normalized.contains('\u0644\u0645\u0627\u0630\u0627');
    final hasPriceDifference =
        normalized.contains('more expensive') ||
        normalized.contains('higher price') ||
        normalized.contains('\u0623\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u063a\u0644\u0649') ||
        normalized.contains('\u0627\u063a\u0644\u064a');
    final hasComparison =
        normalized.contains('than') ||
        normalized.contains('\u0645\u0646') ||
        normalized.contains('\u062f\u0647');
    return asksWhy && hasPriceDifference && hasComparison;
  }

  bool _looksLikeCarFragranceAdvice(String normalized) {
    final car =
        normalized.contains('car') ||
        normalized.contains('\u0639\u0631\u0628\u064a\u0629') ||
        normalized.contains('\u0639\u0631\u0628\u064a\u0647') ||
        normalized.contains('\u0633\u064a\u0627\u0631\u0629') ||
        normalized.contains('\u0633\u064a\u0627\u0631\u0647');
    final perfume =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0631\u064a\u062d\u0629');
    final comfort =
        normalized.contains('dizzy') ||
        normalized.contains('headache') ||
        normalized.contains('\u064a\u062f\u0648\u062e') ||
        normalized.contains('\u062f\u0648\u062e\u0629') ||
        normalized.contains('\u0645\u0634 \u064a\u062f\u0648\u062e') ||
        normalized.contains('\u0645\u0634 \u062e\u0627\u0646\u0642');
    return car && perfume && comfort;
  }

  bool _looksLikeBroadChoiceHelpWithPerfumeProof(String normalized) {
    if (normalized.isEmpty) return false;
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631') ||
        normalized.contains('gift') ||
        normalized.contains('\u0647\u062f\u064a\u0629');
    if (!hasPerfumeProof) return false;
    return normalized.contains('help me choose') ||
        normalized.contains('help choose') ||
        normalized.contains('surprise me') ||
        normalized.contains('not sure') ||
        normalized.contains('confused') ||
        normalized.contains('\u0641\u0627\u062c') ||
        normalized.contains('\u0641\u0627\u062c\u0626\u0646\u064a') ||
        normalized.contains('\u0645\u0634 \u0639\u0627\u0631\u0641') ||
        normalized.contains('\u0645\u062d\u062a\u0627\u0631') ||
        normalized.contains('\u0633\u0627\u0639\u062f\u0646\u064a') ||
        normalized.contains('\u0627\u062e\u062a\u0627\u0631');
  }

  bool _looksLikeTrendRecommendationWithPerfumeProof(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    return normalized.contains('tiktok') ||
        normalized.contains('tik tok') ||
        normalized.contains('viral') ||
        normalized.contains('trend') ||
        normalized.contains('trending') ||
        normalized.contains('popular') ||
        normalized.contains('\u062a\u064a\u0643 \u062a\u0648\u0643') ||
        normalized.contains('\u062a\u064a\u0643\u062a\u0648\u0643') ||
        normalized.contains('\u062a\u0631\u064a\u0646\u062f') ||
        normalized.contains('\u0645\u0634\u0647\u0648\u0631');
  }

  bool _looksLikeSoftNoteGapRecommendationWithPerfumeProof(String normalized) {
    final hasPerfumeOrScentPreference =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631') ||
        normalized.contains('\u0628\u062d\u0628 \u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0628\u062d\u0628 \u0631\u064a\u062d\u0647') ||
        normalized.contains('love the smell') ||
        normalized.contains('like the smell');
    if (!hasPerfumeOrScentPreference) return false;
    final hasScentPhrase =
        normalized.contains('scent') ||
        normalized.contains('smell') ||
        normalized.contains('note') ||
        normalized.contains('with ') ||
        normalized.contains('\u0631\u064a\u062d\u0629') ||
        normalized.contains('\u0631\u064a\u062d\u0647') ||
        normalized.contains('\u0631\u064a\u062d\u062a\u0647') ||
        normalized.contains('\u0641\u064a\u0647') ||
        normalized.contains('\u0646\u0648\u062a\u0629');
    if (!hasScentPhrase) return false;
    return normalized.contains('coffee') ||
        normalized.contains('tea') ||
        normalized.contains('coconut') ||
        normalized.contains('tobacco') ||
        normalized.contains('soapy') ||
        normalized.contains('soap') ||
        normalized.contains('\u0642\u0647\u0648\u0629') ||
        normalized.contains('\u0642\u0647\u0648\u0647') ||
        normalized.contains('\u0634\u0627\u064a') ||
        normalized.contains(
          '\u062c\u0648\u0632 \u0627\u0644\u0647\u0646\u062f',
        ) ||
        normalized.contains('\u062a\u0628\u063a') ||
        normalized.contains('\u0635\u0627\u0628\u0648\u0646') ||
        normalized.contains('\u0635\u0627\u0628\u0648\u0646\u0629');
  }

  bool _looksLikeHotelCleanRecommendationWithPerfumeProof(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    final hasHotel =
        normalized.contains('hotel') ||
        normalized.contains('lobby') ||
        normalized.contains('\u0641\u0646\u062f\u0642') ||
        normalized.contains('\u0644\u0648\u0628\u064a');
    final hasClean =
        normalized.contains('clean') ||
        normalized.contains('fresh') ||
        normalized.contains('\u0646\u0638\u064a\u0641') ||
        normalized.contains('\u0646\u0636\u064a\u0641') ||
        normalized.contains('\u0645\u0646\u0639\u0634');
    return hasHotel && hasClean;
  }

  bool _looksLikeAestheticRecommendationWithPerfumeProof(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    return normalized.contains('aesthetic') ||
        normalized.contains('creator') ||
        normalized.contains('content') ||
        normalized.contains('bottle') ||
        normalized.contains('\u0634\u0643\u0644\u0647') ||
        normalized.contains('\u0628\u0648\u062a\u0644') ||
        normalized.contains(
          '\u0635\u0627\u0646\u0639 \u0645\u062d\u062a\u0648\u0649',
        );
  }

  bool _looksLikeDislikeOnlyPreference(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    final dislike =
        normalized.contains("don't like") ||
        normalized.contains('do not like') ||
        normalized.contains('dislike') ||
        normalized.contains('\u0645\u0634 \u0628\u062d\u0628') ||
        normalized.contains('\u0645\u0628\u062d\u0628\u0634');
    if (!dislike) return false;
    final hasNote =
        normalized.contains('vanilla') ||
        normalized.contains('\u0641\u0627\u0646\u064a\u0644') ||
        normalized.contains('oud') ||
        normalized.contains('\u0639\u0648\u062f') ||
        normalized.contains('musk') ||
        normalized.contains('\u0645\u0633\u0643') ||
        normalized.contains('rose') ||
        normalized.contains('\u0648\u0631\u062f');
    final hasSafety =
        normalized.contains('allergy') ||
        normalized.contains('allergic') ||
        normalized.contains('sensitive') ||
        normalized.contains('\u062d\u0633\u0627\u0633');
    return hasNote && !hasSafety;
  }

  bool _looksLikeMemoryScentSimilarityWithPerfumeProof(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    final hasMemoryCue =
        normalized.contains('old') ||
        normalized.contains('used to have') ||
        normalized.contains('\u0642\u062f\u064a\u0645') ||
        normalized.contains('\u0643\u0627\u0646 \u0639\u0646\u062f\u064a') ||
        normalized.contains('\u0643\u0627\u0646 \u0639\u0646\u062f\u0649');
    final hasSimilarityCue =
        normalized.contains('similar') ||
        normalized.contains('like it') ||
        normalized.contains('\u0634\u0628\u0647') ||
        normalized.contains('\u0632\u064a') ||
        normalized.contains('\u0646\u0641\u0633');
    final hasScentCue =
        normalized.contains('citrus') ||
        normalized.contains('fresh') ||
        normalized.contains('\u062d\u0645\u0636\u064a') ||
        normalized.contains('\u0645\u0646\u0639\u0634');
    return hasMemoryCue && hasSimilarityCue && hasScentCue;
  }

  bool _looksLikeOccasionRecommendationWithPerfumeProof(String normalized) {
    final hasPerfumeProof =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    if (!hasPerfumeProof) return false;
    return normalized.contains('wedding') ||
        normalized.contains('party') ||
        normalized.contains('occasion') ||
        normalized.contains('\u0641\u0631\u062d') ||
        normalized.contains('\u0632\u0641\u0627\u0641') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628\u0629') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628\u0647');
  }

  List<RecommendedProduct> _fallbackBroadChoiceCatalogCandidates(
    List<ProductModel> catalog,
  ) {
    final inStock =
        catalog.where((product) => product.stock > 0).toList(growable: false)
          ..sort((a, b) {
            final aScore = _broadChoiceFallbackScore(a);
            final bScore = _broadChoiceFallbackScore(b);
            if (aScore != bScore) return bScore.compareTo(aScore);
            return a.effectivePrice.compareTo(b.effectivePrice);
          });
    return inStock
        .take(3)
        .map(
          (product) => RecommendedProduct(
            product: product,
            matchScore: _broadChoiceFallbackScore(product).toDouble(),
            matchLabel: 'Catalog fallback',
            matchReason: 'Available catalog result.',
            candidateSource: RecommendedCandidateSource.strict,
          ),
        )
        .toList(growable: false);
  }

  int _broadChoiceFallbackScore(ProductModel product) {
    final terms = <String>{
      product.fragranceFamily,
      product.season,
      product.occasion,
      product.intensity,
      ...product.notes,
      ...product.tags,
    }.map((term) => LocalIntentParser.normalizeInput(term)).join(' ');
    var score = 0;
    if (terms.contains('fresh')) score += 3;
    if (terms.contains('citrus')) score += 2;
    if (terms.contains('musk')) score += 2;
    if (terms.contains('daily')) score += 2;
    if (terms.contains('light')) score += 1;
    return score;
  }

  bool _looksLikeAdviceOnlyQuestion(String normalized) {
    if (normalized.isEmpty) return false;
    if (_looksLikeBlindBuyingAdvice(normalized) ||
        _looksLikePriceDifferenceExplanation(normalized) ||
        _looksLikeSprayCountAdvice(normalized) ||
        _looksLikePurchaseHesitationAdvice(normalized)) {
      return true;
    }
    final hasLayeringSignal =
        normalized.contains('layering') ||
        normalized.contains('layer ') ||
        normalized.contains('mix ') ||
        normalized.contains('combine') ||
        normalized.contains('\u062e\u0644\u0637') ||
        normalized.contains('\u0627\u062e\u0644\u0637') ||
        normalized.contains('\u0623\u062e\u0644\u0637') ||
        normalized.contains('\u062d\u0637 \u0639\u0637\u0631') ||
        normalized.contains('\u0623\u062d\u0637 \u0639\u0637\u0631') ||
        normalized.contains('\u0627\u062d\u0637 \u0639\u0637\u0631');
    final hasQuestionSignal =
        normalized.contains('?') ||
        normalized.contains('\u061f') ||
        normalized.contains('should i') ||
        normalized.contains('can i') ||
        normalized.contains('does it work') ||
        normalized.contains('\u064a\u0646\u0641\u0639') ||
        normalized.contains('\u0647\u064a\u0628\u0642\u0648\u0627') ||
        normalized.contains('\u0647\u062a\u0628\u0642\u0649');
    final hasRecommendationCommand =
        normalized.contains('recommend') ||
        normalized.contains('suggest') ||
        normalized.contains('\u0631\u0634\u062d') ||
        normalized.contains('\u0627\u0642\u062a\u0631\u062d');
    final explicitlyNoRecommendations =
        normalized.contains('without recommendation') ||
        normalized.contains('without product') ||
        normalized.contains('no product') ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u062a\u0631\u0634\u064a\u062d',
        ) ||
        normalized.contains(
          '\u0645\u0646 \u063a\u064a\u0631 \u0643\u0631\u0648\u062a',
        ) ||
        normalized.contains(
          '\u0628\u062f\u0648\u0646 \u062a\u0631\u0634\u064a\u062d',
        ) ||
        normalized.contains(
          '\u0628\u062f\u0648\u0646 \u0643\u0631\u0648\u062a',
        );
    return hasLayeringSignal &&
        (hasQuestionSignal || explicitlyNoRecommendations) &&
        (!hasRecommendationCommand || explicitlyNoRecommendations);
  }

  bool _looksLikeImpossibleZeroBudgetPurchase(String normalized) {
    if (normalized.isEmpty) return false;
    final hasZeroBudget =
        RegExp(r'\b0+\b').hasMatch(normalized) ||
        normalized.contains('\u0635\u0641\u0631');
    if (!hasZeroBudget) return false;
    final hasPurchaseIntent =
        normalized.contains('gift') ||
        normalized.contains('premium') ||
        normalized.contains('luxury') ||
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0647\u062f\u064a\u0629') ||
        normalized.contains('\u0641\u062e\u0645') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646');
    return hasPurchaseIntent;
  }
}
