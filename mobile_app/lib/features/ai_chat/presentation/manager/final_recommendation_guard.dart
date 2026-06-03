import 'dart:async';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

typedef FinalRecommendationGuardEventLogger =
    FutureOr<void> Function(String eventType, Map<String, dynamic> metadata);

typedef FinalRecommendationTranslator =
    String Function(
      AIChatLanguage language, {
      required String ar,
      required String en,
    });

class FinalRecommendationGuard {
  final FinalRecommendationTranslator translate;
  final FinalRecommendationGuardEventLogger? logEvent;

  const FinalRecommendationGuard({required this.translate, this.logEvent});

  FinalRecommendationGuardResult guard({
    required AIChatReply reply,
    required List<ProductModel> catalog,
    required AIChatRecommendationContext recommendationContext,
    required AIChatLanguage language,
    required String responseSource,
  }) {
    final recommendedProducts = <RecommendedProduct>[];
    final effectivePreferences = recommendationContext.effectivePreferences
        .mergePatch(reply.updatedPreferences);
    final allowUpsell =
        recommendationContext.budgetPolicy == AIChatBudgetPolicy.flexible;
    final catalogById = {
      for (final product in catalog) product.id.trim(): product,
    };
    final localCandidateById = {
      for (final candidate in recommendationContext.localCandidatesRefs)
        candidate.product.id.trim(): candidate,
    };
    final seenProductIds = <String>{};

    for (final rawId in reply.productIds) {
      if (recommendedProducts.length >= 3) break;

      final id = rawId.trim();
      if (id.isEmpty) {
        _logBlock(
          'catalog_id_missing',
          productId: rawId,
          responseSource: responseSource,
        );
        continue;
      }

      if (!seenProductIds.add(id)) {
        _logBlock(
          'duplicate_cards_blocked',
          productId: id,
          responseSource: responseSource,
        );
        continue;
      }

      final product = catalogById[id];
      if (product == null) {
        _logBlock(
          'catalog_id_missing',
          productId: id,
          responseSource: responseSource,
        );
        continue;
      }

      final availabilityBlock = _availabilityBlockReason(product);
      if (availabilityBlock != null) {
        _logBlock(
          availabilityBlock,
          productId: id,
          responseSource: responseSource,
          metadata: {'stock': product.stock, 'isActive': product.isActive},
        );
        continue;
      }

      final acceptancePolicy = localCandidateById.containsKey(id)
          ? WorkerRecommendationAcceptancePolicy.exactCandidate
          : WorkerRecommendationAcceptancePolicy.fallbackCandidate;
      var budgetStatus = LocalCandidateFilter.budgetStatusForProduct(
        product,
        effectivePreferences,
        allowUpsell: allowUpsell,
      );
      if (budgetStatus == null &&
          _isAcceptedBudgetFloorSource(responseSource) &&
          effectivePreferences.maxBudget != null &&
          product.effectivePrice > effectivePreferences.maxBudget!) {
        budgetStatus = RecommendedBudgetStatus.slightlyAboveBudget;
      }
      if (budgetStatus == null) {
        _logBlock(
          'budget_policy_block',
          productId: id,
          responseSource: responseSource,
          metadata: {
            'maxBudget': effectivePreferences.maxBudget,
            'productPrice': product.effectivePrice,
          },
        );
        continue;
      }

      final scentBlock = _excludedScentBlockReason(
        product,
        effectivePreferences,
      );
      if (scentBlock != null) {
        _logBlock(
          scentBlock,
          productId: id,
          responseSource: responseSource,
          metadata: {'excludedNotes': effectivePreferences.excludedNotes},
        );
        continue;
      }

      final acceptanceDecision =
          LocalCandidateFilter.evaluateWorkerRecommendationCandidate(
            product,
            effectivePreferences,
            policy: acceptancePolicy,
          );
      if (!acceptanceDecision.isAccepted) {
        final reasonCode = _mappedAcceptanceReasonCode(
          acceptanceDecision.reasonCode,
        );
        _logBlock(
          reasonCode,
          productId: id,
          responseSource: responseSource,
          metadata: {'policy': acceptancePolicy.name},
        );
        continue;
      }

      final localRef = localCandidateById[id];
      final realScore = localRef?.matchScore ?? 0.70;
      if (localRef == null) {
        _log('recommendation_score_fallback_used', {
          'productId': id,
          'source': responseSource,
          'fallbackScore': realScore,
          'issueCode': 'score_fallback',
        });
      }

      var matchReason = _resolveMatchReason(
        reply: reply,
        productId: id,
        product: product,
        preferences: effectivePreferences,
        budgetStatus: budgetStatus,
        language: language,
        responseSource: responseSource,
        localMatchReason: localRef?.matchReason,
      );
      if (_containsExcludedScentText(matchReason, effectivePreferences)) {
        matchReason = _safeConstraintMatchReason(
          preferences: effectivePreferences,
          language: language,
          budgetStatus: budgetStatus,
        );
        _logBlock(
          'excluded_note_match_reason_sanitized',
          productId: id,
          responseSource: responseSource,
        );
      }

      if (budgetStatus == RecommendedBudgetStatus.slightlyAboveBudget &&
          effectivePreferences.maxBudget != null &&
          !_shouldForceEnglishFallback(
            reply.matchReasons[id],
            language,
            responseSource,
          ) &&
          !_containsBudgetDisclosure(matchReason)) {
        matchReason = _upsellDisclosureReason(
          language,
          product,
          effectivePreferences.maxBudget!,
        );
        _log('conversion_upsell_reason_used', {
          'productId': id,
          'source': responseSource,
          'exactBudget': effectivePreferences.maxBudget,
          'productPrice': product.effectivePrice,
        });
      }
      matchReason = _appendMissingPreferenceCaveat(
        reason: matchReason,
        product: product,
        preferences: effectivePreferences,
        language: language,
      );

      recommendedProducts.add(
        RecommendedProduct(
          product: product,
          matchReason: matchReason,
          matchScore: realScore,
          matchLabel: _resolveMatchLabel(
            realScore,
            language,
            localMatchLabel: localRef?.matchLabel,
          ),
          budgetStatus: budgetStatus,
          exactBudget: effectivePreferences.maxBudget,
        ),
      );
    }

    if (recommendedProducts.isNotEmpty) {
      return FinalRecommendationGuardResult(safeProducts: recommendedProducts);
    }

    final localRecoveryProducts = _buildAcceptedLocalFallbackProducts(
      recommendationContext.localCandidatesRefs,
      effectivePreferences,
      responseSource,
      allowUpsell: allowUpsell,
    );
    if (localRecoveryProducts.isNotEmpty) {
      return FinalRecommendationGuardResult(
        localRecoveryProducts: localRecoveryProducts,
      );
    }

    return const FinalRecommendationGuardResult(
      shouldNoMatch: true,
      issueCode: 'no_candidate_match',
      reasonCode: 'no_candidate_match',
    );
  }

  String _resolveMatchReason({
    required AIChatReply reply,
    required String productId,
    required ProductModel product,
    required SessionPreferences preferences,
    required RecommendedBudgetStatus budgetStatus,
    required AIChatLanguage language,
    required String responseSource,
    String? localMatchReason,
  }) {
    final groundedFallbackReason = _buildGroundedFallbackMatchReason(
      product: product,
      preferences: preferences,
      budgetStatus: budgetStatus,
      language: language,
    );
    final rawMatchReason = reply.matchReasons[productId];
    final groundedLocalReason =
        localMatchReason != null &&
            localMatchReason.trim().isNotEmpty &&
            !_isGenericMatchReason(localMatchReason)
        ? localMatchReason.trim()
        : null;
    final effectiveRawReason =
        rawMatchReason != null && !_isGenericMatchReason(rawMatchReason)
        ? rawMatchReason
        : groundedLocalReason;
    final safeRawReason =
        effectiveRawReason != null &&
            !_reasonClaimsUnsupportedRequestedNote(
              effectiveRawReason,
              product,
              preferences,
            )
        ? effectiveRawReason
        : null;
    final forceEnglishFallback = _shouldForceEnglishFallback(
      safeRawReason,
      language,
      responseSource,
    );
    final replaceEnglishReasonInArabicSession =
        language.isArabic &&
        safeRawReason != null &&
        _shouldReplaceReasonInArabicSession(safeRawReason);

    return forceEnglishFallback
        ? groundedFallbackReason
        : replaceEnglishReasonInArabicSession
        ? translate(
            language,
            ar: groundedFallbackReason,
            en: groundedFallbackReason,
          )
        : (safeRawReason ?? groundedFallbackReason);
  }

  String _buildGroundedFallbackMatchReason({
    required ProductModel product,
    required SessionPreferences preferences,
    required RecommendedBudgetStatus budgetStatus,
    required AIChatLanguage language,
  }) {
    final preferredNotes = {
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();
    final productNotes = {
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      product.fragranceFamily,
      ...product.tags,
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();
    final noteOverlap = preferredNotes
        .where((note) => productNotes.any((productNote) => productNote == note))
        .take(2)
        .toList(growable: false);

    final context = <String>[
      if (preferences.gender != null &&
          _normalizeReasonToken(product.gender) ==
              _normalizeReasonToken(preferences.gender!))
        _reasonDisplayValue(preferences.gender!, language),
      if (preferences.season != null &&
          (_normalizeReasonToken(product.season) ==
                  _normalizeReasonToken(preferences.season!) ||
              _normalizeReasonToken(product.season) == 'all seasons' ||
              _normalizeReasonToken(product.season) == 'all_seasons'))
        _reasonDisplayValue(preferences.season!, language),
      if (preferences.occasion != null &&
          _normalizeReasonToken(product.occasion) ==
              _normalizeReasonToken(preferences.occasion!))
        _reasonDisplayValue(preferences.occasion!, language),
      if (preferences.intensity != null &&
          _normalizeReasonToken(product.intensity) ==
              _normalizeReasonToken(preferences.intensity!))
        _reasonDisplayValue(preferences.intensity!, language),
    ].take(2).toList(growable: false);

    final withinBudget =
        preferences.maxBudget != null &&
        product.effectivePrice <= preferences.maxBudget!;
    final slightlyAbove =
        budgetStatus == RecommendedBudgetStatus.slightlyAboveBudget;
    final signatureLimit = noteOverlap.isNotEmpty ? 1 : 2;
    final signature = product.notes
        .where((note) => note.trim().isNotEmpty)
        .where((note) => !noteOverlap.contains(_normalizeReasonToken(note)))
        .take(signatureLimit)
        .toList(growable: false);

    if (language.isArabic) {
      final parts = <String>[];
      if (noteOverlap.isNotEmpty) {
        parts.add('يطابق نوتات ${_joinReasonItems(noteOverlap, arabic: true)}');
      }
      if (context.isNotEmpty) {
        parts.add('مناسب لـ ${_joinReasonItems(context, arabic: true)}');
      }
      if (withinBudget) {
        parts.add(
          'داخل ميزانيتك ${preferences.maxBudget!.toStringAsFixed(0)} جنيه',
        );
      } else if (slightlyAbove) {
        parts.add('أقرب اختيار مع فرق بسيط عن الميزانية');
      }
      if (parts.isNotEmpty) return '${parts.join('، ')}.';
      if (signature.isNotEmpty) {
        return 'اختيار مناسب بطابع ${_joinReasonItems(signature, arabic: true)} من الكتالوج المتاح.';
      }
      return 'اختيار مناسب من الكتالوج بناءً على تفضيلاتك الحالية.';
    }

    final scentPieces = <String>[];
    if (noteOverlap.isNotEmpty) {
      scentPieces.add('${_joinReasonItems(noteOverlap)} notes');
    }
    if (signature.isNotEmpty) {
      scentPieces.add('${_joinReasonItems(signature)} character');
    }

    final fitPieces = <String>[];
    if (context.isNotEmpty) {
      fitPieces.addAll(context);
    }

    final valuePiece = withinBudget
        ? 'keeps you inside your ${preferences.maxBudget!.toStringAsFixed(0)} EGP budget'
        : slightlyAbove
        ? 'is the closest available match with only a small budget stretch'
        : product.effectivePrice > 0
        ? 'comes in at ${product.effectivePrice.toStringAsFixed(0)} EGP'
        : '';

    final parts = <String>[];
    if (scentPieces.isNotEmpty) {
      parts.add('gives you ${_joinReasonItems(scentPieces)}');
    }
    if (fitPieces.isNotEmpty) {
      parts.add('fits ${_fitPhrase(fitPieces)}');
    }
    if (valuePiece.isNotEmpty) {
      parts.add(valuePiece);
    }

    if (withinBudget) {
      // Already included as a value piece above.
    }
    if (parts.isNotEmpty) {
      return 'Strong pick because it ${_joinReasonItems(parts)}.';
    }
    if (signature.isNotEmpty) {
      return 'Strong catalog pick because it has a ${_joinReasonItems(signature)} profile and is available now.';
    }
    return 'Safe catalog pick because it is available and matches your current request.';
  }

  String _normalizeReasonToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _reasonDisplayValue(String value, AIChatLanguage language) {
    final normalized = _normalizeReasonToken(value);
    if (!language.isArabic) {
      const en = {
        'men': 'men',
        'women': 'women',
        'unisex': 'unisex',
        'summer': 'summer',
        'winter': 'winter',
        'spring': 'spring',
        'autumn': 'autumn',
        'fall': 'autumn',
        'all seasons': 'all seasons',
        'all_seasons': 'all seasons',
        'daily': 'daily use',
        'office': 'office wear',
        'work': 'office wear',
        'university': 'university use',
        'gym': 'gym',
        'date': 'dates',
        'formal': 'formal occasions',
        'day': 'daytime',
        'night': 'night',
        'all day': 'all-day wear',
        'all_day': 'all-day wear',
        'light': 'a light feel',
        'medium': 'medium intensity',
        'strong': 'strong intensity',
      };
      return en[normalized] ?? normalized.replaceAll('_', ' ');
    }
    const ar = {
      'men': 'رجالي',
      'women': 'حريمي',
      'unisex': 'للجنسين',
      'summer': 'صيفي',
      'winter': 'شتوي',
      'spring': 'ربيعي',
      'autumn': 'خريفي',
      'fall': 'خريفي',
      'all seasons': 'كل المواسم',
      'all_seasons': 'كل المواسم',
      'daily': 'الاستخدام اليومي',
      'office': 'الشغل',
      'work': 'الشغل',
      'university': 'الجامعة',
      'gym': 'الجيم',
      'date': 'الخروجات',
      'formal': 'المناسبات الرسمية',
      'day': 'النهار',
      'night': 'الليل',
      'all day': 'طوال اليوم',
      'all_day': 'طوال اليوم',
      'light': 'هادي',
      'medium': 'متوسط',
      'strong': 'قوي',
    };
    return ar[normalized] ?? value;
  }

  String _joinReasonItems(List<String> items, {bool arabic = false}) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    final separator = arabic ? ' و' : ' and ';
    if (items.length == 2) return '${items.first}$separator${items.last}';
    final last = items.last;
    final head = items.take(items.length - 1).join(arabic ? '، ' : ', ');
    return arabic ? '$head، و$last' : '$head, and $last';
  }

  String _fitPhrase(List<String> items) {
    if (items.isEmpty) return '';
    final unique = <String>[];
    for (final item in items) {
      final cleaned = item.trim();
      if (cleaned.isNotEmpty && !unique.contains(cleaned)) unique.add(cleaned);
    }
    if (unique.isEmpty) return '';
    if (unique.length == 1) return unique.single;
    return _joinReasonItems(unique);
  }

  bool _isGenericMatchReason(String reason) {
    final normalized = reason.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.startsWith('matched catalog facets:') ||
        normalized.startsWith('matched catalog facet:') ||
        normalized ==
            'this perfume matches your current taste and preferences.' ||
        normalized ==
            'this perfume matches your current taste and preferences' ||
        normalized == 'good match.' ||
        normalized == 'good match' ||
        normalized == 'great option.' ||
        normalized == 'great option' ||
        normalized == 'fits preferences.' ||
        normalized == 'fits preferences' ||
        normalized == 'fits your preferences.' ||
        normalized == 'fits your preferences' ||
        normalized == 'reason' ||
        normalized == 'r1' ||
        normalized == 'r2';
  }

  bool _reasonClaimsUnsupportedRequestedNote(
    String reason,
    ProductModel product,
    SessionPreferences preferences,
  ) {
    final normalizedReason = _normalizeReasonToken(reason);
    if (normalizedReason.contains('not exact') ||
        normalizedReason.contains('missing requested') ||
        normalizedReason.contains('except')) {
      return false;
    }

    final requestedNotes = {
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();
    if (requestedNotes.isEmpty) return false;

    final productProfile = {
      product.fragranceFamily,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
      product.description,
      product.pyramidDescription ?? '',
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();

    for (final note in requestedNotes) {
      if (!_containsGuardToken(normalizedReason, note)) continue;
      final productSupportsNote = productProfile.any(
        (item) => _containsGuardToken(item, note),
      );
      if (!productSupportsNote) return true;
    }
    return false;
  }

  bool _shouldForceEnglishFallback(
    String? rawMatchReason,
    AIChatLanguage language,
    String responseSource,
  ) {
    return !language.isArabic &&
        (responseSource == 'local_fallback' ||
            (rawMatchReason != null && _containsArabicScript(rawMatchReason)));
  }

  List<RecommendedProduct> _buildAcceptedLocalFallbackProducts(
    List<RecommendedProduct> localCandidates,
    SessionPreferences effectivePreferences,
    String responseSource, {
    required bool allowUpsell,
  }) {
    final accepted = <RecommendedProduct>[];
    final seenProductIds = <String>{};
    for (final candidate in localCandidates) {
      final product = candidate.product;
      final id = product.id.trim();
      if (id.isEmpty) {
        _logBlock(
          'catalog_id_missing',
          productId: product.id,
          responseSource: responseSource,
        );
        continue;
      }

      if (!seenProductIds.add(id)) {
        _logBlock(
          'duplicate_cards_blocked',
          productId: id,
          responseSource: responseSource,
        );
        continue;
      }

      final availabilityBlock = _availabilityBlockReason(product);
      if (availabilityBlock != null) {
        _logBlock(
          availabilityBlock,
          productId: id,
          responseSource: responseSource,
          metadata: {'stock': product.stock, 'isActive': product.isActive},
        );
        continue;
      }

      final budgetStatus = LocalCandidateFilter.budgetStatusForProduct(
        product,
        effectivePreferences,
        allowUpsell: allowUpsell,
      );
      if (budgetStatus == null) {
        _logBlock(
          'budget_policy_block',
          productId: id,
          responseSource: responseSource,
          metadata: {
            'maxBudget': effectivePreferences.maxBudget,
            'productPrice': product.effectivePrice,
          },
        );
        continue;
      }

      final scentBlock = _excludedScentBlockReason(
        product,
        effectivePreferences,
      );
      if (scentBlock != null) {
        _logBlock(
          scentBlock,
          productId: id,
          responseSource: responseSource,
          metadata: {'excludedNotes': effectivePreferences.excludedNotes},
        );
        continue;
      }

      final decision =
          LocalCandidateFilter.evaluateWorkerRecommendationCandidate(
            product,
            effectivePreferences,
            policy: WorkerRecommendationAcceptancePolicy.exactCandidate,
          );
      if (!decision.isAccepted) {
        _logBlock(
          _mappedAcceptanceReasonCode(decision.reasonCode),
          productId: id,
          responseSource: responseSource,
          metadata: {
            'policy': WorkerRecommendationAcceptancePolicy.exactCandidate.name,
          },
        );
        continue;
      }
      accepted.add(
        RecommendedProduct(
          product: product,
          matchReason: _appendMissingPreferenceCaveat(
            reason: candidate.matchReason,
            product: product,
            preferences: effectivePreferences,
            language: _getReasonLanguage(candidate.matchReason),
          ),
          matchScore: candidate.matchScore,
          matchLabel: candidate.matchLabel,
          budgetStatus: budgetStatus,
          exactBudget: effectivePreferences.maxBudget,
        ),
      );
      if (accepted.length >= 3) break;
    }

    if (accepted.isNotEmpty) {
      _log('recommendation_score_fallback_used', {
        'source': responseSource,
        'issueCode': 'worker_ids_filtered_local_recovery',
        'productIds': accepted.map((item) => item.product.id).toList(),
      });
    }
    return accepted;
  }

  String _resolveMatchLabel(
    double score,
    AIChatLanguage lang, {
    String? localMatchLabel,
  }) {
    final local = localMatchLabel?.trim();
    if (local != null && local.isNotEmpty) {
      if (lang.isArabic && _containsArabicScript(local)) return local;
      if (!lang.isArabic && !_containsArabicScript(local)) return local;
    }
    if (score >= 0.85) {
      return translate(lang, ar: 'تطابق ممتاز', en: 'Excellent Match');
    }
    if (score >= 0.70) {
      return translate(lang, ar: 'تطابق جيد جدًا', en: 'Great Match');
    }
    if (score >= 0.55) {
      return translate(lang, ar: 'تطابق جيد', en: 'Good Match');
    }
    return translate(lang, ar: 'تطابق محدود', en: 'Partial Match');
  }

  String _upsellDisclosureReason(
    AIChatLanguage language,
    ProductModel product,
    double exactBudget,
  ) {
    final roundedPrice = product.effectivePrice.toStringAsFixed(0);
    final roundedBudget = exactBudget.toStringAsFixed(0);
    return translate(
      language,
      ar: 'هذا أنسب اختيار متاح، لكنه أغلى قليلًا من ميزانيتك ($roundedPrice بدل $roundedBudget).',
      en: 'The lowest available option is above your original budget ($roundedPrice vs $roundedBudget), so I am showing it clearly before you decide.',
    );
  }

  bool _containsArabicScript(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  bool _containsEnglishScript(String text) {
    return RegExp(r'[A-Za-z]').hasMatch(text);
  }

  AIChatLanguage _getReasonLanguage(String reason) {
    return _containsArabicScript(reason)
        ? AIChatLanguage.arabic
        : AIChatLanguage.english;
  }

  String _appendMissingPreferenceCaveat({
    required String reason,
    required ProductModel product,
    required SessionPreferences preferences,
    required AIChatLanguage language,
  }) {
    final missing = _missingPreferenceLabels(
      product: product,
      preferences: preferences,
      language: language,
    );
    if (missing.isEmpty) return reason;

    final cleanReason = reason.trim();
    final normalizedReason = _normalizeReasonToken(cleanReason);
    if (normalizedReason.contains('not exact on') ||
        normalizedReason.contains('missing requested')) {
      return _normalizeExistingMismatchCaveat(cleanReason, language);
    }

    final selected = missing.take(2).toList(growable: false);
    final baseReason = _removeDuplicateMismatchNotes(
      cleanReason,
      selected,
      language,
    );
    final caveat = _customerFacingMismatchCaveat(selected, language: language);
    final punctuatedBaseReason = _ensureTerminalPunctuation(baseReason);
    return punctuatedBaseReason.isEmpty
        ? caveat
        : '$punctuatedBaseReason $caveat';
  }

  String _customerFacingMismatchCaveat(
    List<String> selected, {
    required AIChatLanguage language,
  }) {
    final normalized = selected.map(_normalizeReasonToken).toSet();
    final hasIntensityGap =
        normalized.contains('light intensity') ||
        normalized.contains('a light feel') ||
        normalized.contains('light');
    final noteGaps = selected
        .where((item) => _normalizeReasonToken(item).contains('note'))
        .toList(growable: false);

    if (language.isArabic) {
      if (hasIntensityGap) {
        return '\u0627\u062e\u062a\u064a\u0627\u0631 \u0642\u0631\u064a\u0628 \u0645\u0646 \u0637\u0644\u0628\u0643\u060c \u0644\u0643\u0646 \u062d\u0636\u0648\u0631\u0647 \u0623\u0642\u0648\u0649 \u0642\u0644\u064a\u0644\u064b\u0627 \u0645\u0646 \u0627\u0644\u0644\u064a \u0637\u0644\u0628\u062a\u0647.';
      }
      if (noteGaps.isNotEmpty) {
        return '\u0645\u0634 \u0644\u0627\u0642\u064a ${_joinReasonItems(noteGaps, arabic: true)} \u0635\u0631\u064a\u062d\u0629 \u0641\u064a \u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c\u060c \u0644\u0643\u0646 \u062f\u064a \u0623\u0642\u0631\u0628 \u0627\u062e\u062a\u064a\u0627\u0631\u0627\u062a \u0628\u0646\u0641\u0633 \u0627\u0644\u0625\u062d\u0633\u0627\u0633.';
      }
      return '\u0627\u062e\u062a\u064a\u0627\u0631 \u0642\u0631\u064a\u0628 \u0645\u0646 \u0637\u0644\u0628\u0643\u060c \u0645\u0639 \u0627\u062e\u062a\u0644\u0627\u0641 \u0628\u0633\u064a\u0637 \u0641\u064a ${_joinReasonItems(selected, arabic: true)}.';
    }

    if (hasIntensityGap) {
      return 'This is close to your request, but it may feel a little stronger than you asked for.';
    }
    if (noteGaps.isNotEmpty) {
      final notes = noteGaps
          .map(
            (item) =>
                item.replaceAll(RegExp(r'\s+note$', caseSensitive: false), ''),
          )
          .toList(growable: false);
      return 'I could not find ${_joinReasonItems(notes)} explicitly in the catalog, so I am showing the closest catalog-backed alternatives.';
    }
    return 'This is close to your request, with a small difference in ${_joinReasonItems(selected)}.';
  }

  String _ensureTerminalPunctuation(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp(r'[.!?؟]$').hasMatch(trimmed)) return trimmed;
    return '$trimmed.';
  }

  String _normalizeExistingMismatchCaveat(
    String reason,
    AIChatLanguage language,
  ) {
    if (language.isArabic) {
      return reason.replaceFirst(
        RegExp(r'مش\s+مطابق\s+تمامًا\s+في\s*:', caseSensitive: false),
        '\u0645\u062a\u0648\u0627\u0641\u0642 \u0645\u0639 \u0637\u0644\u0628\u0643 \u0645\u0627 \u0639\u062f\u0627:',
      );
    }
    return reason.replaceFirst(
      RegExp(r'Not exact on\s*:', caseSensitive: false),
      'This is close to your request, with a small difference in:',
    );
  }

  String _removeDuplicateMismatchNotes(
    String reason,
    List<String> selected,
    AIChatLanguage language,
  ) {
    if (language.isArabic || selected.isEmpty || reason.trim().isEmpty) {
      return reason;
    }
    var cleaned = reason.trim();
    final normalizedSelected = selected.map(_normalizeReasonToken).toSet();
    if (normalizedSelected.contains('light intensity') ||
        normalizedSelected.contains('a light feel')) {
      cleaned = cleaned.replaceAll(
        RegExp(
          r'\s*,?\s*note:\s*intensity differs from request\.?',
          caseSensitive: false,
        ),
        '',
      );
    }
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _missingPreferenceLabels({
    required ProductModel product,
    required SessionPreferences preferences,
    required AIChatLanguage language,
  }) {
    final missing = <String>[];
    final productProfile = {
      product.fragranceFamily,
      ...product.notes,
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
      product.description,
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();

    final requestedNotes = {
      ...preferences.preferredNotes,
      ...preferences.preferredTopNotes,
      ...preferences.preferredMiddleNotes,
      ...preferences.preferredBaseNotes,
    }.map(_normalizeReasonToken).where((item) => item.isNotEmpty).toSet();
    for (final note in requestedNotes) {
      if (!productProfile.any((item) => _containsGuardToken(item, note))) {
        missing.add(language.isArabic ? note : '$note note');
      }
    }

    final requestedGender = preferences.gender;
    if (requestedGender != null &&
        !_genderIsCompatible(requestedGender, product.gender)) {
      missing.add(
        language.isArabic
            ? _reasonDisplayValue(requestedGender, language)
            : '${_reasonDisplayValue(requestedGender, language)} profile',
      );
    }

    _addScalarMismatch(
      missing,
      requested: preferences.intensity,
      actual: product.intensity,
      language: language,
      englishSuffix: 'intensity',
    );
    _addScalarMismatch(
      missing,
      requested: preferences.occasion,
      actual: product.occasion,
      language: language,
      englishSuffix: 'use',
      compatibleActuals: const {'daily'},
    );
    _addScalarMismatch(
      missing,
      requested: preferences.time,
      actual: product.time,
      language: language,
      englishSuffix: 'time',
      compatibleActuals: const {'all_day', 'all day'},
    );
    _addScalarMismatch(
      missing,
      requested: preferences.season,
      actual: product.season,
      language: language,
      englishSuffix: 'season',
      compatibleActuals: const {'all_seasons', 'all seasons'},
    );

    return missing.toList(growable: false);
  }

  void _addScalarMismatch(
    List<String> output, {
    required String? requested,
    required String actual,
    required AIChatLanguage language,
    required String englishSuffix,
    Set<String> compatibleActuals = const <String>{},
  }) {
    if (requested == null || requested.trim().isEmpty) return;
    final normalizedRequested = _normalizeReasonToken(requested);
    final normalizedActual = _normalizeReasonToken(actual);
    if (normalizedRequested == normalizedActual) return;
    if (compatibleActuals.contains(normalizedActual)) return;
    if (normalizedRequested == 'all day' && normalizedActual == 'day') return;
    if (normalizedRequested == 'all_day' && normalizedActual == 'day') return;

    final value = _reasonDisplayValue(requested, language);
    if (language.isArabic) {
      output.add(value);
      return;
    }
    final normalizedSuffix = _normalizeReasonToken(englishSuffix);
    if (normalizedSuffix == 'intensity') {
      output.add(value);
      return;
    }
    final normalizedValue = _normalizeReasonToken(value);
    output.add(
      normalizedValue.contains(normalizedSuffix)
          ? value
          : '$value $englishSuffix',
    );
  }

  bool _genderIsCompatible(String requested, String actual) {
    final normalizedRequested = _normalizeReasonToken(requested);
    final normalizedActual = _normalizeReasonToken(actual);
    if (normalizedRequested.isEmpty || normalizedRequested == 'unisex') {
      return true;
    }
    return normalizedActual == normalizedRequested ||
        normalizedActual == 'unisex';
  }

  bool _shouldReplaceReasonInArabicSession(String text) {
    return _containsEnglishScript(text) && !_containsArabicScript(text);
  }

  bool _containsBudgetDisclosure(String text) {
    final lower = text.toLowerCase();
    return lower.contains('over budget') ||
        lower.contains('above budget') ||
        lower.contains('above your original') ||
        lower.contains('slightly above') ||
        lower.contains('higher than your budget') ||
        text.contains('أعلى من ميزانيتك الأصلية') ||
        text.contains('أعلى من ميزانيتك') ||
        text.contains('أعلى قليلًا من ميزانيتك') ||
        text.contains('أغلى قليلًا من ميزانيتك') ||
        text.contains('فوق الميزانية');
  }

  bool _isAcceptedBudgetFloorSource(String responseSource) {
    return responseSource.contains('showLowestAvailableAfterBudgetNoMatch');
  }

  bool _containsExcludedScentText(String text, SessionPreferences preferences) {
    if (preferences.excludedNotes.isEmpty) return false;
    final normalizedText = _normalizeReasonToken(text);
    for (final excluded in preferences.excludedNotes) {
      for (final token in _expandedExcludedTokens(excluded)) {
        if (_containsGuardToken(normalizedText, token)) {
          return true;
        }
      }
    }
    return false;
  }

  String? _availabilityBlockReason(ProductModel product) {
    if (!product.isActive || product.stock <= 0) {
      return 'inactive_or_out_of_stock';
    }
    return null;
  }

  String? _excludedScentBlockReason(
    ProductModel product,
    SessionPreferences preferences,
  ) {
    if (preferences.excludedNotes.isEmpty) return null;

    final canonicalText = [
      ...product.notes,
      product.fragranceFamily,
    ].map(_normalizeReasonToken).join(' ');
    final fineText = [
      ...product.topNotes,
      ...product.middleNotes,
      ...product.baseNotes,
      ...product.tags,
      product.description,
      product.pyramidDescription ?? '',
    ].map(_normalizeReasonToken).join(' ');

    for (final excluded in preferences.excludedNotes) {
      for (final token in _expandedExcludedTokens(excluded)) {
        if (_containsGuardToken(canonicalText, token)) {
          return 'excluded_note_violation';
        }
        if (_containsGuardToken(fineText, token)) {
          return 'fine_note_violation';
        }
      }
    }
    return null;
  }

  bool _containsGuardToken(String normalizedText, String token) {
    final normalizedToken = _normalizeReasonToken(token);
    if (normalizedText.isEmpty || normalizedToken.isEmpty) return false;

    final asciiToken = RegExp(r'^[a-z0-9 ]+$').hasMatch(normalizedToken);
    if (!asciiToken) return normalizedText.contains(normalizedToken);

    final escapedToken = RegExp.escape(normalizedToken);
    return RegExp(
      '(^|[^a-z0-9])$escapedToken([^a-z0-9]|\$)',
    ).hasMatch(normalizedText);
  }

  String _mappedAcceptanceReasonCode(String? reasonCode) {
    if (reasonCode == 'excluded_note') return 'excluded_note_violation';
    return reasonCode ?? 'hard_filter_block';
  }

  Set<String> _expandedExcludedTokens(String value) {
    final normalized = _normalizeReasonToken(value);
    final tokens = <String>{normalized};
    if (normalized.contains('citrus') ||
        normalized.contains('lemon') ||
        normalized.contains('bergamot') ||
        normalized.contains('orange')) {
      tokens.addAll(const {'citrus', 'lemon', 'bergamot', 'orange'});
    }
    if (normalized.contains('rose')) {
      tokens.add('rose');
    }
    if (normalized.contains('jasmine')) {
      tokens.add('jasmine');
    }
    return tokens;
  }

  String _safeConstraintMatchReason({
    required SessionPreferences preferences,
    required AIChatLanguage language,
    required RecommendedBudgetStatus budgetStatus,
  }) {
    if (language.isArabic) {
      if (preferences.maxBudget != null &&
          budgetStatus == RecommendedBudgetStatus.withinBudget) {
        return 'اختيار متاح يراعي قيودك الحالية وداخل الميزانية.';
      }
      return 'اختيار متاح يراعي قيودك الحالية من الكتالوج.';
    }
    if (preferences.maxBudget != null &&
        budgetStatus == RecommendedBudgetStatus.withinBudget) {
      return 'Available catalog pick that respects your current constraints and budget.';
    }
    return 'Available catalog pick that respects your current constraints.';
  }

  void _log(String eventType, Map<String, dynamic> metadata) {
    final logger = logEvent;
    if (logger == null) return;
    unawaited(Future<void>.sync(() => logger(eventType, metadata)));
  }

  void _logBlock(
    String reasonCode, {
    required String productId,
    required String responseSource,
    Map<String, dynamic> metadata = const {},
  }) {
    _log('recommendation_hard_filter_blocked', {
      'productId': productId,
      'source': responseSource,
      'issueCode': reasonCode,
      'reasonCode': reasonCode,
      ...metadata,
    });
  }
}
