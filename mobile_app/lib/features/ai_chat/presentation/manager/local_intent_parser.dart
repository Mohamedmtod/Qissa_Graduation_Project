import 'package:perfume_app/features/ai_chat/core/ai_normalization_dictionary.dart';
import 'package:perfume_app/features/ai_chat/core/ai_normalizer.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_keywords.dart'
    as parser_keywords;
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_matchers.dart'
    as parser_matchers;
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_matchers.dart'
    show TermMatch;

enum AIChatIntent {
  newRecommendation,
  followUpProduct,
  compareProducts,
  availabilityCheck,
  summary,
}

enum ModifierPatchType { stronger, lighter, cheaper, sweeter, revert }

class ModifierPatch {
  final ModifierPatchType type;
  const ModifierPatch(this.type);
}

class LocalIntentParser {
  static final RegExp punctuation = RegExp(
    r'[^\w\s\u0400-\u04FF\u0600-\u06FF]',
  );
  static const Set<String> _budgetContextKeywords =
      parser_keywords.budgetContextKeywords;

  static const Set<String> cheapKeywords = parser_keywords.cheapKeywords;

  static const Set<String> _premiumKeywords = parser_keywords.premiumKeywords;

  static const Set<String> _compromiseKeywords =
      parser_keywords.compromiseKeywords;

  static const List<String> _summaryTailMarkers =
      parser_keywords.summaryTailMarkers;

  static const Set<String> _greetingPhrases = parser_keywords.greetingPhrases;

  static const Set<String> _greetingTokens = parser_keywords.greetingTokens;

  static const Set<String> _perfumeTopicKeywords =
      parser_keywords.perfumeTopicKeywords;

  static const Set<String> _continueWithCurrentStateKeywords =
      parser_keywords.continueWithCurrentStateKeywords;

  static const Set<String> _summaryKeywords = parser_keywords.summaryKeywords;

  static const Set<String> _contextResetKeywords =
      parser_keywords.contextResetKeywords;

  static const Set<String> lighterModifiers = parser_keywords.lighterModifiers;

  static const Set<String> strongerModifiers =
      parser_keywords.strongerModifiers;

  static const Set<String> sweeterModifiers = parser_keywords.sweeterModifiers;

  static const Set<String> revertModifiers = parser_keywords.revertModifiers;

  static const Set<String> _compareKeywords = parser_keywords.compareKeywords;

  static const Set<String> _followUpKeywords = parser_keywords.followUpKeywords;

  static const Set<String> _availabilitySubstituteFollowUpKeywords =
      parser_keywords.availabilitySubstituteFollowUpKeywords;

  static const Set<String> _addTriggers = parser_keywords.addTriggers;

  static const Set<String> _removeTriggers = parser_keywords.removeTriggers;

  static const Set<String> _femaleRelationshipKeywords =
      parser_keywords.femaleRelationshipKeywords;

  static const Set<String> _maleRelationshipKeywords =
      parser_keywords.maleRelationshipKeywords;

  static SessionPreferences parse(String message, SessionPreferences current) {
    final normalized = normalizeInput(_focusRecommendationTail(message));
    if (normalized.isEmpty) return current;
    if (containsAny(normalized, _continueWithCurrentStateKeywords) &&
        !BudgetAmountParser.containsBudgetNumber(normalized)) {
      return current.sanitize();
    }
    final extractedBudget = _extractBudget(normalized, current.maxBudget);
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
          normalized,
        ) &&
        extractedBudget == null &&
        !_looksLikeConstraintPatchCommand(normalized) &&
        !_hasExplicitReferenceProfile(normalized)) {
      return current.sanitize();
    }

    final professionGender = _inferGenderFromProfessionContext(normalized);
    var gender = _extractGenderScalar(normalized);
    gender ??= _inferExplicitPersonaGender(normalized);
    if (professionGender != null && !_hasDirectGenderPreference(normalized)) {
      gender = professionGender;
    } else {
      gender ??= professionGender;
    }
    var season = _extractScalar(
      normalized,
      AINormalizationDictionary.canonicalSeasons,
      AINormalizer.flatSeasonAliases,
    );
    var occasion = _extractScalar(
      normalized,
      AINormalizationDictionary.canonicalOccasions,
      AINormalizer.flatOccasionAliases,
    );
    var time = _extractScalar(
      normalized,
      AINormalizationDictionary.canonicalTimes,
      AINormalizer.flatTimeAliases,
    );
    if (_looksLikeValentineContext(normalized) &&
        time == 'day' &&
        !_hasExplicitDaytimeContext(normalized)) {
      time = null;
    }
    var intensity = _extractIntensity(normalized);

    if (containsAny(normalized, lighterModifiers) &&
        !isRelaxExcludedNotesCommand(normalized)) {
      intensity = 'light';
    } else if (_containsNonNegatedStrongerModifier(normalized)) {
      intensity = 'strong';
    }
    if (isRelaxExcludedNotesCommand(normalized)) {
      intensity = current.intensity;
    }
    final maxBudget = extractedBudget;

    final preferredNotes = <String>{...current.preferredNotes};
    final preferredTopNotes = <String>{...current.preferredTopNotes};
    final preferredMiddleNotes = <String>{...current.preferredMiddleNotes};
    final preferredBaseNotes = <String>{...current.preferredBaseNotes};
    final excludedNotes = <String>{...current.excludedNotes};
    final medicalExcludedNotes = <String>{...current.medicalExcludedNotes};
    final tags = <String>{...current.tags};

    final detectedLayer = _detectLayer(normalized);
    final extracted = _extractNotes(normalized);
    final includedNotes = <String>{...extracted.included};
    final excludedExtractedNotes = <String>{...extracted.excluded};
    final allergyExcludedNotes = _extractAllergyExcludedNotes(normalized);
    excludedExtractedNotes.addAll(allergyExcludedNotes);
    medicalExcludedNotes.addAll(allergyExcludedNotes);
    includedNotes.removeAll(excludedExtractedNotes);
    includedNotes.removeAll(medicalExcludedNotes);
    final hasImplicitEnglishReplace =
        _containsTerm(normalized, 'instead') &&
        includedNotes.isEmpty &&
        excludedExtractedNotes.isNotEmpty;
    final hasExplicitEnglishReplace =
        _containsTerm(normalized, 'instead') && includedNotes.isNotEmpty;

    if (hasImplicitEnglishReplace) {
      includedNotes.addAll(excludedExtractedNotes);
      excludedExtractedNotes.clear();
    }

    if (_shouldReplacePreferredNotesForFreshRequest(
      normalized,
      includedNotes,
    )) {
      preferredNotes.clear();
      preferredTopNotes.clear();
      preferredMiddleNotes.clear();
      preferredBaseNotes.clear();
    }

    for (final note in excludedExtractedNotes) {
      excludedNotes.add(note);
      preferredNotes.remove(note);
      preferredTopNotes.remove(note);
      preferredMiddleNotes.remove(note);
      preferredBaseNotes.remove(note);
    }

    if (hasImplicitEnglishReplace || hasExplicitEnglishReplace) {
      for (final note in current.preferredNotes) {
        if (includedNotes.contains(note) ||
            medicalExcludedNotes.contains(note)) {
          continue;
        }
        excludedNotes.add(note);
        preferredNotes.remove(note);
      }
      preferredTopNotes.clear();
      preferredMiddleNotes.clear();
      preferredBaseNotes.clear();
    }

    for (final note in includedNotes) {
      if (excludedNotes.contains(note) &&
          !excludedExtractedNotes.contains(note) &&
          !medicalExcludedNotes.contains(note)) {
        excludedNotes.remove(note);
      }
      if (medicalExcludedNotes.contains(note)) {
        continue;
      }
      _addPreferredNote(
        note: note,
        layer: detectedLayer,
        preferredNotes: preferredNotes,
        preferredTopNotes: preferredTopNotes,
        preferredMiddleNotes: preferredMiddleNotes,
        preferredBaseNotes: preferredBaseNotes,
      );
    }

    tags.addAll(_extractTags(normalized));
    if (_hasExplicitGiftContext(normalized) ||
        normalized.contains('\u0647\u062f\u064a\u0629') ||
        normalized.contains('\u0647\u062f\u064a\u0647') ||
        normalized.contains('gift')) {
      occasion ??= 'gift';
      tags.add('gift');
    }
    if (_shouldSuppressAmbiguousGiftTag(normalized)) {
      tags.remove('gift');
    }
    if (_hasNegativeSweetStyle(normalized)) {
      final hardSweetExclusion = !_hasSoftSweetLimit(normalized);
      tags.remove('sweet');
      tags.remove('sugary');
      tags.addAll(const {'clean', 'fresh'});
      preferredNotes.remove('sweet');
      preferredNotes.remove('sugary');
      if (_looksLikeCleanerDirection(normalized)) {
        preferredNotes.remove('vanilla');
        preferredTopNotes.remove('vanilla');
        preferredMiddleNotes.remove('vanilla');
        preferredBaseNotes.remove('vanilla');
      }
      if (hardSweetExclusion) {
        excludedNotes.addAll(const {'sweet', 'sugary'});
      }
    }
    if (_looksLikeMasculineStyle(normalized)) {
      tags.add('masculine');
    }
    final rankingStrategy = _extractRankingStrategy(normalized);
    _applyReferenceProfiles(
      message: normalized,
      preferredNotes: preferredNotes,
      tags: tags,
      onGenderHint: (hint) => gender ??= hint,
      onSeasonHint: (hint) => season ??= hint,
      onOccasionHint: (hint) => occasion ??= hint,
      onIntensityHint: (hint) => intensity ??= hint,
      onTimeHint: (hint) {
        if (time == null || (time == 'day' && hint == 'all_day')) {
          time = hint;
        }
      },
    );

    final inferredBudget = _extractAffordabilityBudgetHint(
      normalized,
      current.maxBudget,
    );

    final inferredGender = _inferGenderFromRelationshipContext(normalized);

    if (containsAny(normalized, _premiumKeywords)) {
      tags.addAll(const {'elegant', 'classic', 'bold'});
    }

    if (containsAny(normalized, _compromiseKeywords)) {
      tags.addAll(const {'clean', 'sweet'});
      if (gender == null && inferredGender == null) {
        gender = 'unisex';
      }
      intensity ??= 'medium';
    }

    final professionalContext = _looksLikeProfessionalContext(normalized);
    final medicalContext = _looksLikeMedicalProfessionalContext(normalized);
    final gymContext = _looksLikeGymContext(normalized);
    final formalEveningContext = _looksLikeFormalEveningContext(normalized);
    final officeSafeContext = _looksLikeOfficeSafeContext(normalized);

    if (professionalContext) {
      tags.addAll(const {'elegant', 'classic'});
      occasion ??= 'office';
    }
    if (medicalContext) {
      tags.addAll(const {'clean', 'fresh'});
      occasion ??= 'office';
      time ??= 'all_day';
      intensity ??= 'light';
    }
    if (gymContext) {
      tags.addAll(const {'clean', 'fresh'});
      occasion ??= 'daily';
      intensity ??= 'light';
    }
    if (formalEveningContext) {
      tags.addAll(const {'elegant', 'classic'});
      occasion ??= 'formal';
      time ??= 'night';
      intensity ??= 'strong';
    }
    if (officeSafeContext) {
      tags.addAll(const {'clean', 'fresh'});
      occasion ??= 'office';
      time ??= 'all_day';
      intensity ??= 'light';
    }
    if (occasion == 'office' &&
        (season == 'summer' ||
            intensity == 'light' ||
            _hasCalmQuietCue(normalized))) {
      tags.addAll(const {'clean', 'fresh'});
      time ??= 'all_day';
      intensity ??= 'light';
    }
    if ((tags.contains('fresh') || tags.contains('clean')) &&
        occasion == 'office') {
      tags.add('clean');
      time ??= 'all_day';
      intensity ??= 'light';
    }

    final patch = PreferencePatch()
      ..replaceList(PreferenceListField.preferredNotes, preferredNotes)
      ..replaceList(PreferenceListField.preferredTopNotes, preferredTopNotes)
      ..replaceList(
        PreferenceListField.preferredMiddleNotes,
        preferredMiddleNotes,
      )
      ..replaceList(PreferenceListField.preferredBaseNotes, preferredBaseNotes)
      ..replaceList(PreferenceListField.excludedNotes, excludedNotes)
      ..replaceList(
        PreferenceListField.medicalExcludedNotes,
        medicalExcludedNotes,
      )
      ..replaceList(PreferenceListField.tags, tags);

    final effectiveGender = gender ?? inferredGender;
    if (effectiveGender != null) {
      patch.setScalar(PreferenceScalar.gender, effectiveGender);
    }
    final effectiveBudget = maxBudget ?? inferredBudget;
    if (effectiveBudget != null) {
      patch.setScalar(PreferenceScalar.maxBudget, effectiveBudget);
    }
    if (season != null) patch.setScalar(PreferenceScalar.season, season);
    if (occasion != null) patch.setScalar(PreferenceScalar.occasion, occasion);
    if (time != null) patch.setScalar(PreferenceScalar.time, time);
    if (intensity != null) {
      patch.setScalar(PreferenceScalar.intensity, intensity);
    }
    if (rankingStrategy != null) {
      patch.setScalar(PreferenceScalar.rankingStrategy, rankingStrategy);
    }
    if (maxBudget == null &&
        (containsAny(normalized, _premiumKeywords) ||
            normalized.contains('premium') ||
            normalized.contains('luxury') ||
            normalized.contains('بريميوم') ||
            normalized.contains('بريميم') ||
            _shouldClearBudget(normalized))) {
      patch.clearScalar(PreferenceScalar.maxBudget);
    }

    return patch.applyTo(current);
  }

  static AIChatBudgetPolicy detectBudgetPolicy(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty ||
        !BudgetAmountParser.containsBudgetNumber(normalized)) {
      return AIChatBudgetPolicy.flexible;
    }

    if (_containsStrictPhrase(normalized, 'exactly') ||
        _containsStrictPhrase(normalized, 'not one pound more') ||
        _containsStrictPhrase(normalized, 'not a pound more') ||
        _containsStrictPhrase(normalized, 'not one egp more') ||
        _containsStrictPhrase(normalized, 'not more than') ||
        _containsStrictPhrase(normalized, 'no more than') ||
        _containsStrictPhrase(normalized, 'strictly under') ||
        _containsStrictPhrase(normalized, 'strict under') ||
        _containsStrictPhrase(normalized, 'below budget') ||
        _containsStrictPhrase(normalized, 'above budget') ||
        _containsStrictPhrase(
          normalized,
          'do not show anything above budget',
        ) ||
        _containsStrictPhrase(normalized, 'do not show over budget') ||
        _containsStrictPhrase(normalized, 'do not show anything over budget') ||
        _containsStrictPhrase(normalized, 'below') ||
        _containsStrictPhrase(normalized, 'less than') ||
        _containsStrictPhrase(normalized, 'maximum') ||
        _containsStrictPhrase(normalized, 'strictly') ||
        _containsStrictPhrase(normalized, 'strict budget') ||
        _containsStrictPhrase(normalized, 'hard budget') ||
        _containsStrictPhrase(
          normalized,
          '\u0645\u062a\u0637\u0644\u0639\u0647\u0627\u0634',
        ) ||
        _containsStrictPhrase(
          normalized,
          '\u0645\u0627 \u062a\u0637\u0644\u0639\u0647\u0627\u0634',
        ) ||
        _containsStrictPhrase(
          normalized,
          '\u0645\u062a\u0639\u0631\u0636\u0647\u0627\u0634',
        ) ||
        _containsStrictPhrase(
          normalized,
          '\u0645\u0627 \u062a\u0639\u0631\u0636\u0647\u0627\u0634',
        ) ||
        RegExp(r'\bmax\b').hasMatch(normalized)) {
      return AIChatBudgetPolicy.strict;
    }

    return AIChatBudgetPolicy.flexible;
  }

  static bool _looksLikeConstraintPatchCommand(String normalizedMessage) {
    if (BudgetAmountParser.containsBudgetNumber(normalizedMessage)) {
      return true;
    }
    if (detectModifierPatch(normalizedMessage) != null) {
      return true;
    }
    if (_extractRankingStrategy(normalizedMessage) != null) {
      return true;
    }
    if (containsAny(normalizedMessage, _addTriggers) ||
        containsAny(normalizedMessage, _removeTriggers)) {
      return true;
    }
    return false;
  }

  static bool _shouldClearBudget(String normalizedMessage) {
    if (_containsStrictPhrase(normalizedMessage, 'above budget') ||
        _containsStrictPhrase(
          normalizedMessage,
          'do not show anything above budget',
        ) ||
        _containsStrictPhrase(normalizedMessage, 'do not show over budget') ||
        _containsStrictPhrase(
          normalizedMessage,
          'do not show anything over budget',
        )) {
      return false;
    }
    return _containsStrictPhrase(normalizedMessage, 'forget budget') ||
        _containsStrictPhrase(
          normalizedMessage,
          '\u0627\u0646\u0633\u064a \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0647',
        ) ||
        _containsStrictPhrase(
          normalizedMessage,
          '\u0627\u0646\u0633\u064a \u0645\u064a\u0632\u0627\u0646\u064a\u0647',
        ) ||
        _containsStrictPhrase(
          normalizedMessage,
          '\u0627\u0646\u0633\u064a \u0627\u0644\u0628\u062f\u062c\u062a',
        ) ||
        _containsStrictPhrase(
          normalizedMessage,
          '\u0628\u0644\u0627\u0634 \u0645\u064a\u0632\u0627\u0646\u064a\u0647',
        ) ||
        _containsStrictPhrase(normalizedMessage, 'remove budget') ||
        _containsStrictPhrase(normalizedMessage, 'clear budget') ||
        _containsStrictPhrase(normalizedMessage, 'no budget') ||
        _containsStrictPhrase(normalizedMessage, 'without budget') ||
        isOpenBudgetClearCommand(normalizedMessage);
  }

  static bool isOpenBudgetClearCommand(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (normalized.contains('open budget') ||
        normalized.contains('budget open') ||
        normalized.contains('no budget limit') ||
        normalized.contains('no limit') ||
        normalized.contains('unlimited') ||
        normalized.contains('money is not a problem') ||
        normalized.contains(
          '\u0627\u0646\u0633\u064a \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0627\u0646\u0633\u064a \u0645\u064a\u0632\u0627\u0646\u064a\u0647',
        ) ||
        normalized.contains(
          '\u0627\u0646\u0633\u064a \u0627\u0644\u0628\u062f\u062c\u062a',
        )) {
      return true;
    }
    final hasBudgetWord =
        normalized.contains('budget') ||
        normalized.contains('price') ||
        normalized.contains('ميزاني') ||
        normalized.contains('سعر') ||
        normalized.contains('ميزاني') ||
        normalized.contains('سعر');
    final hasOpenWord =
        normalized.contains('مفتوح') ||
        normalized.contains('مفتوحه') ||
        normalized.contains('مفتوحة') ||
        normalized.contains('مفتوح') ||
        normalized.contains('مفتوحه') ||
        normalized.contains('مفتوحة') ||
        normalized.contains('مش فارق') ||
        normalized.contains('مش مهم') ||
        normalized.contains('بدون حد');
    return hasBudgetWord && hasOpenWord;
  }

  static bool isRelaxExcludedNotesCommand(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;

    if (_containsAnyTerm(normalized, const [
      'relax exclusion',
      'relax exclusions',
      'relax it',
      'loosen exclusion',
      'loosen exclusions',
      'ignore exclusion',
      'ignore exclusions',
      'remove exclusion',
      'remove exclusions',
      'clear exclusion',
      'clear exclusions',
      '\u062e\u0641\u0641 \u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u062e\u0641\u0641 \u0627\u0644\u0645\u0646\u0639',
      '\u062e\u0641\u0641\u0647',
      '\u062e\u0641\u0641\u0647\u0627',
      '\u062a\u062c\u0627\u0647\u0644 \u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u0634\u064a\u0644 \u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u0627\u0644\u063a\u064a \u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u0627\u0644\u063a\u064a \u0627\u0644\u0645\u0646\u0639',
      '\u0645\u0634 \u0645\u0647\u0645 \u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
    ])) {
      return true;
    }

    final hasRelaxWord = _containsAnyTerm(normalized, const [
      '\u062e\u0641\u0641',
      '\u062e\u0641\u0641\u0647',
      '\u062e\u0641\u0641\u0647\u0627',
      '\u0627\u0644\u063a\u064a',
      '\u0627\u0644\u063a\u064a\u0647',
      '\u0627\u0644\u063a\u064a\u0647\u0627',
      '\u0634\u064a\u0644',
      '\u062a\u062c\u0627\u0647\u0644',
    ]);
    final hasExclusionWord = _containsAnyTerm(normalized, const [
      '\u0627\u0644\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u0627\u0633\u062a\u0628\u0639\u0627\u062f',
      '\u0627\u0644\u0645\u0646\u0639',
      '\u0645\u0646\u0639',
      '\u0627\u0644\u0645\u0645\u0646\u0648\u0639',
      '\u0645\u0645\u0646\u0648\u0639',
    ]);
    return hasRelaxWord && hasExclusionWord;
  }

  static bool _looksLikeValentineContext(String normalizedMessage) {
    return normalizedMessage.contains('valentine');
  }

  static bool _looksLikeSoftRomanticContext(String normalizedMessage) {
    if (normalizedMessage.contains('date night') ||
        normalizedMessage.contains('night date')) {
      return false;
    }
    return normalizedMessage.contains('romantic') ||
        normalizedMessage.contains('valentine');
  }

  static bool _looksLikeProfessionalContext(String normalizedMessage) {
    return _containsStrictPhrase(normalizedMessage, 'finance') ||
        _containsStrictPhrase(normalizedMessage, 'banking') ||
        _containsStrictPhrase(normalizedMessage, 'corporate') ||
        _containsStrictPhrase(normalizedMessage, 'professional') ||
        _containsStrictPhrase(normalizedMessage, 'engineer') ||
        _containsStrictPhrase(normalizedMessage, 'interview') ||
        _containsStrictPhrase(normalizedMessage, 'office') ||
        _containsStrictPhrase(normalizedMessage, 'work') ||
        _containsStrictPhrase(normalizedMessage, 'hospital') ||
        _containsStrictPhrase(normalizedMessage, 'clinic') ||
        _containsStrictPhrase(normalizedMessage, 'doctor') ||
        _containsStrictPhrase(normalizedMessage, 'shift') ||
        _containsStrictPhrase(normalizedMessage, 'meeting') ||
        _containsStrictPhrase(normalizedMessage, 'company') ||
        _containsStrictPhrase(normalizedMessage, 'work in finance') ||
        _containsStrictPhrase(normalizedMessage, 'working in finance') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0634\u063a\u0644',
          '\u062f\u0648\u0627\u0645',
          '\u0645\u0643\u062a\u0628',
          '\u0627\u0646\u062a\u0631\u0641\u064a\u0648',
          '\u0645\u0642\u0627\u0628\u0644\u0629 \u0634\u063a\u0644',
          '\u062f\u0643\u062a\u0648\u0631',
          '\u062f\u0643\u062a\u0648\u0631\u0629',
          '\u0645\u0633\u062a\u0634\u0641\u0649',
          '\u0645\u0633\u062a\u0634\u0641\u064a',
          '\u0639\u064a\u0627\u062f\u0629',
          '\u0634\u0641\u062a',
          '\u0646\u0628\u0637\u0634\u064a\u0629',
          '\u0645\u0647\u0646\u062f\u0633',
          '\u0645\u0647\u0646\u062f\u0633\u0629',
        ]);
  }

  static bool _looksLikeMedicalProfessionalContext(String normalizedMessage) {
    return _containsStrictPhrase(normalizedMessage, 'hospital') ||
        _containsStrictPhrase(normalizedMessage, 'clinic') ||
        _containsStrictPhrase(normalizedMessage, 'doctor') ||
        _containsStrictPhrase(normalizedMessage, 'nurse') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u062f\u0643\u062a\u0648\u0631',
          '\u062f\u0643\u062a\u0648\u0631\u0629',
          '\u0645\u0633\u062a\u0634\u0641\u0649',
          '\u0645\u0633\u062a\u0634\u0641\u064a',
          '\u0639\u064a\u0627\u062f\u0629',
          '\u062a\u0645\u0631\u064a\u0636',
          '\u0637\u0628\u064a\u0628',
          '\u0637\u0628\u064a\u0628\u0629',
        ]);
  }

  static bool _looksLikeGymContext(String normalizedMessage) {
    return _containsStrictPhrase(normalizedMessage, 'gym') ||
        _containsStrictPhrase(normalizedMessage, 'workout') ||
        _containsStrictPhrase(normalizedMessage, 'training') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u062c\u064a\u0645',
          '\u0627\u0644\u062c\u064a\u0645',
          '\u062a\u0645\u0631\u064a\u0646',
          '\u0627\u0644\u062a\u0645\u0631\u064a\u0646',
          '\u062c\u0627\u0645',
        ]);
  }

  static bool _looksLikeFormalEveningContext(String normalizedMessage) {
    final hasFormalOccasion =
        _containsStrictPhrase(normalizedMessage, 'wedding') ||
        _containsStrictPhrase(normalizedMessage, 'engagement') ||
        _containsStrictPhrase(normalizedMessage, 'formal') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0641\u0631\u062d',
          '\u0632\u0648\u0627\u062c',
          '\u0645\u0646\u0627\u0633\u0628\u0629',
          '\u0645\u0646\u0627\u0633\u0628\u0627\u062a',
          '\u0631\u0633\u0645\u064a',
          '\u062e\u0637\u0648\u0628\u0629',
        ]);
    final hasEveningSignal =
        _containsStrictPhrase(normalizedMessage, 'night') ||
        _containsStrictPhrase(normalizedMessage, 'evening') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0644\u064a\u0644',
          '\u0644\u064a\u0644\u064a',
          '\u0628\u0627\u0644\u0644\u064a\u0644',
          '\u0645\u0633\u0627\u0621',
          '\u0645\u0633\u0627\u0626\u064a',
        ]);
    return hasFormalOccasion && hasEveningSignal;
  }

  static bool _looksLikeOfficeSafeContext(String normalizedMessage) {
    final officeContext =
        _containsStrictPhrase(normalizedMessage, 'office') ||
        _containsStrictPhrase(normalizedMessage, 'work') ||
        _containsStrictPhrase(normalizedMessage, 'university') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0634\u063a\u0644',
          '\u062f\u0648\u0627\u0645',
          '\u0645\u0643\u062a\u0628',
          '\u062c\u0627\u0645\u0639\u0629',
          '\u062c\u0627\u0645\u0639\u0647',
        ]);
    final safeCleanCue =
        _containsStrictPhrase(normalizedMessage, 'safe') ||
        _containsStrictPhrase(normalizedMessage, 'clean') ||
        _containsStrictPhrase(normalizedMessage, 'not annoying') ||
        _containsStrictPhrase(normalizedMessage, 'inoffensive') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0646\u0638\u0627\u0641\u0629',
          '\u0646\u0636\u064a\u0641',
          '\u0646\u0636\u064a\u0641\u0629',
          '\u0645\u0634 \u0645\u0632\u0639\u062c',
          '\u0645\u0634 \u0645\u0632\u0639\u062c\u0629',
        ]);
    return officeContext && safeCleanCue;
  }

  static bool _hasCheaperCue(String normalizedMessage) {
    return containsAny(normalizedMessage, cheapKeywords) ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0627\u0631\u062e\u0635',
          '\u0623\u0631\u062e\u0635',
          '\u0631\u062e\u064a\u0635',
          '\u0627\u0642\u0644',
          '\u0623\u0642\u0644',
          '\u0627\u0648\u0641\u0631',
          '\u0623\u0648\u0641\u0631',
          '\u0645\u0648\u0641\u0631',
          '\u0627\u0642\u062a\u0635\u0627\u062f\u064a',
          '\u0633\u0639\u0631 \u0627\u0642\u0644',
        ]);
  }

  static bool _looksLikeContextualCheaperSimilarity(String normalizedMessage) {
    if (!_hasCheaperCue(normalizedMessage)) return false;
    final hasSimilarityCue =
        _containsStrictPhrase(normalizedMessage, 'similar') ||
        _containsStrictPhrase(normalizedMessage, 'something like') ||
        _containsStrictPhrase(normalizedMessage, 'something similar') ||
        _containsStrictPhrase(normalizedMessage, 'same vibe') ||
        _containsStrictPhrase(normalizedMessage, 'vibe') ||
        _containsStrictPhrase(normalizedMessage, 'smells like') ||
        _containsStrictPhrase(normalizedMessage, 'scent like') ||
        _containsStrictPhrase(normalizedMessage, 'like it') ||
        _containsStrictPhrase(normalizedMessage, 'like this') ||
        _containsStrictPhrase(normalizedMessage, 'like that') ||
        _containsAnyTerm(normalizedMessage, const [
          '\u0634\u0628\u0647',
          '\u0634\u0628\u0647\u0647',
          '\u0632\u064a\u0647',
          '\u0632\u064a',
          '\u0646\u0641\u0633',
          '\u0646\u0641\u0633\u0647',
        ]);
    return hasSimilarityCue;
  }

  static bool looksLikeRankingRequest(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;

    if (_extractRankingStrategy(normalized) != null) {
      return true;
    }

    final hasRankingCue =
        _hasCheaperCue(normalized) ||
        containsAny(normalized, _premiumKeywords) ||
        normalized.contains('premium') ||
        normalized.contains('luxury') ||
        normalized.contains('بريميوم') ||
        normalized.contains('بريميم') ||
        normalized.contains('اغلى') ||
        normalized.contains('اغلي') ||
        normalized.contains('الاغلى') ||
        normalized.contains('الاغلي') ||
        normalized.contains('افخم') ||
        normalized.contains('الافخم') ||
        normalized.contains('اعلى') ||
        normalized.contains('الاعلى') ||
        normalized.contains('most expensive') ||
        normalized.contains('highest price') ||
        normalized.contains('best') ||
        normalized.contains('top');
    if (!hasRankingCue) return false;

    return containsAny(normalized, _perfumeTopicKeywords) ||
        normalized.contains('عطر') ||
        normalized.contains('برفان') ||
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('scent');
  }

  static bool _hasExplicitDaytimeContext(String normalizedMessage) {
    return _containsStrictPhrase(normalizedMessage, 'daytime') ||
        _containsStrictPhrase(normalizedMessage, 'during the day') ||
        _containsStrictPhrase(normalizedMessage, 'for daytime') ||
        _containsStrictPhrase(normalizedMessage, 'for day use') ||
        _containsStrictPhrase(normalizedMessage, 'all day') ||
        _containsStrictPhrase(normalizedMessage, 'morning') ||
        _containsStrictPhrase(normalizedMessage, 'afternoon');
  }

  static String? _inferGenderFromRelationshipContext(String normalizedMessage) {
    if (containsAny(normalizedMessage, _femaleRelationshipKeywords)) {
      return 'women';
    }
    if (containsAny(normalizedMessage, _maleRelationshipKeywords)) {
      return 'men';
    }
    return null;
  }

  static String? _inferExplicitPersonaGender(String normalizedMessage) {
    if (_containsTerm(normalizedMessage, 'راجل') ||
        _containsTerm(normalizedMessage, 'رجل') ||
        _containsTerm(normalizedMessage, 'رجالي') ||
        _containsTerm(normalizedMessage, 'راجل') ||
        _containsTerm(normalizedMessage, 'رجل') ||
        _containsTerm(normalizedMessage, 'رجالي')) {
      return 'men';
    }
    if (_containsTerm(normalizedMessage, 'ست') ||
        _containsTerm(normalizedMessage, 'امرأة') ||
        _containsTerm(normalizedMessage, 'نسائي')) {
      return 'women';
    }
    if (RegExp(
      r"\b(i am|im|i'm)\s+(?:a\s+)?(?:\d{1,2}\s*(?:-\s*)?year\s*(?:-\s*)?old\s+)?(?:man|male)\b",
    ).hasMatch(normalizedMessage)) {
      return 'men';
    }
    if (RegExp(
      r'\b(for a man|for man|for men|men perfume|male perfume|manly|masculine)\b',
    ).hasMatch(normalizedMessage)) {
      return 'men';
    }
    if (RegExp(
      r"\b(i am|im|i'm)\s+(?:a\s+)?(?:\d{1,2}\s*(?:-\s*)?year\s*(?:-\s*)?old\s+)?(?:woman|female)\b",
    ).hasMatch(normalizedMessage)) {
      return 'women';
    }
    if (RegExp(
      r'\b(for a woman|for woman|for women|women perfume|female perfume|feminine|womanly)\b',
    ).hasMatch(normalizedMessage)) {
      return 'women';
    }
    return null;
  }

  static String? _inferGenderFromProfessionContext(String normalizedMessage) {
    if (_containsAnyNormalizedToken(normalizedMessage, const [
      '\u0645\u0647\u0646\u062f\u0633\u0629',
      '\u062f\u0643\u062a\u0648\u0631\u0629',
      '\u0637\u0628\u064a\u0628\u0629',
      '\u0645\u062d\u0627\u0645\u064a\u0629',
      '\u0645\u062f\u064a\u0631\u0629',
      '\u0645\u062f\u0631\u0633\u0629',
      '\u0645\u0635\u0645\u0645\u0629',
    ])) {
      return 'women';
    }
    if (_containsAnyNormalizedToken(normalizedMessage, const [
      '\u0645\u0647\u0646\u062f\u0633',
      '\u062f\u0643\u062a\u0648\u0631',
      '\u0637\u0628\u064a\u0628',
      '\u0645\u062d\u0627\u0645\u064a',
      '\u0645\u062f\u064a\u0631',
      '\u0645\u062f\u0631\u0633',
      '\u0645\u0635\u0645\u0645',
    ])) {
      return 'men';
    }
    return null;
  }

  static bool _containsAnyNormalizedToken(
    String normalizedMessage,
    Iterable<String> terms,
  ) {
    final tokens = normalizedMessage.split(RegExp(r'\s+')).toSet();
    for (final term in terms) {
      if (tokens.contains(normalizeInput(term))) return true;
    }
    return false;
  }

  static bool _hasDirectGenderPreference(String normalizedMessage) {
    return _containsAnyTerm(normalizedMessage, const [
          'men',
          'mens',
          'male',
          'man',
          'women',
          'womens',
          'female',
          'woman',
          'unisex',
          '\u0631\u062c\u0627\u0644\u064a',
          '\u0644\u0644\u0631\u062c\u0627\u0644',
          '\u0631\u062c\u0644',
          '\u0646\u0633\u0627\u0626\u064a',
          '\u062d\u0631\u064a\u0645\u064a',
          '\u0644\u0644\u0646\u0633\u0627\u0621',
          '\u0644\u0644\u062c\u0646\u0633\u064a\u0646',
        ]) ||
        RegExp(
          r'\b(for a man|for man|for men|men perfume|male perfume|for a woman|for woman|for women|women perfume|female perfume)\b',
        ).hasMatch(normalizedMessage);
  }

  static bool _looksLikeMasculineStyle(String normalizedMessage) {
    return RegExp(r'\b(manly|masculine)\b').hasMatch(normalizedMessage);
  }

  static AIChatIntent detectIntent(
    String message, {
    bool hasRecommendationContext = false,
  }) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return AIChatIntent.newRecommendation;
    if (isGreetingOnly(normalized)) return AIChatIntent.newRecommendation;

    if (isSummaryRequest(normalized)) {
      return AIChatIntent.summary;
    }
    final extractedNotes = _extractNotes(normalized);
    final looksLikeNoteReplacementPatch =
        containsAny(normalized, _removeTriggers) &&
        containsAny(normalized, _addTriggers) &&
        (extractedNotes.included.isNotEmpty ||
            extractedNotes.excluded.isNotEmpty);
    if (looksLikeNoteReplacementPatch) {
      return AIChatIntent.newRecommendation;
    }
    if (AvailabilityIntentUtils.looksLikePersonaOrPreferenceStatement(
      normalized,
    )) {
      return AIChatIntent.newRecommendation;
    }
    if (_looksLikePerfumeWithNotePreference(normalized)) {
      return AIChatIntent.newRecommendation;
    }
    if (_looksLikeNoteOnlyAvailabilityPatch(normalized, extractedNotes)) {
      return AIChatIntent.newRecommendation;
    }
    if (containsAny(normalized, _availabilitySubstituteFollowUpKeywords) ||
        _looksLikeContextualCheaperSimilarity(normalized)) {
      return AIChatIntent.followUpProduct;
    }
    final modifierPatch = detectModifierPatch(normalized);
    final earlyAvailabilityProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(message);
    if (earlyAvailabilityProduct != null &&
        !AvailabilityIntentUtils.isGenericAvailabilityCandidate(
          earlyAvailabilityProduct,
        ) &&
        AvailabilityIntentUtils.hasDirectAvailabilityCue(normalized)) {
      return AIChatIntent.availabilityCheck;
    }
    if (AvailabilityIntentUtils.looksLikeRecommendationContinuationCommand(
      normalized,
    )) {
      return AIChatIntent.newRecommendation;
    }
    if (normalized.contains('خليط') ||
        normalized.contains('mix of two scents') ||
        normalized.contains('mix between') ||
        normalized.contains('blend between') ||
        normalized.contains('blend of') ||
        normalized.contains('scent blend')) {
      return AIChatIntent.newRecommendation;
    }
    if (_looksLikeScentBlendRequest(normalized)) {
      return AIChatIntent.newRecommendation;
    }
    if (containsAny(normalized, _compareKeywords)) {
      return AIChatIntent.compareProducts;
    }
    if (looksLikeRankingRequest(normalized)) {
      return AIChatIntent.newRecommendation;
    }
    if (BudgetAmountParser.containsBudgetNumber(normalized)) {
      return AIChatIntent.newRecommendation;
    }
    final extractedProduct =
        AvailabilityIntentUtils.extractAvailabilityProductQuery(message);
    final hasAvailabilityKeyword = containsAny(
      normalized,
      AvailabilityIntentUtils.availabilityKeywords,
    );
    if (extractedProduct != null &&
        !AvailabilityIntentUtils.isGenericAvailabilityCandidate(
          extractedProduct,
        ) &&
        AvailabilityIntentUtils.hasDirectAvailabilityCue(normalized)) {
      return AIChatIntent.availabilityCheck;
    }
    if (AvailabilityIntentUtils.looksLikeLatinStandaloneName(message)) {
      return AIChatIntent.availabilityCheck;
    }
    // Modifier-like requests must not classify as availability without a
    // concrete product anchor or contextual availability follow-up.
    if (modifierPatch != null &&
        (!hasAvailabilityKeyword ||
            AvailabilityIntentUtils.isGenericAvailabilityCandidate(
              extractedProduct,
            ))) {
      return AIChatIntent.newRecommendation;
    }
    if (containsAny(normalized, _followUpKeywords)) {
      return AIChatIntent.followUpProduct;
    }
    if (AvailabilityIntentUtils.looksLikeAvailabilityQuery(
      normalized,
      hasRecommendationContext: hasRecommendationContext,
      extractedProduct: extractedProduct,
    )) {
      return AIChatIntent.availabilityCheck;
    }
    return AIChatIntent.newRecommendation;
  }

  static bool _looksLikePerfumeWithNotePreference(String normalized) {
    if (containsAny(
      normalized,
      AvailabilityIntentUtils.recommendationRejectionKeywords,
    )) {
      return false;
    }
    if (RegExp(r'"[^"]+"').hasMatch(normalized)) {
      return false;
    }
    final hasWantCue =
        normalized.contains('i want') ||
        normalized.contains('\u0639\u0627\u064a\u0632') ||
        normalized.contains('\u0639\u0627\u064a\u0632\u0629') ||
        normalized.contains('\u0639\u0627\u0648\u0632') ||
        normalized.contains('\u0639\u0627\u0648\u0632\u0629');
    if (!hasWantCue) return false;

    final hasPerfumeCue =
        normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646');
    if (!hasPerfumeCue) return false;

    return normalized.contains('with') ||
        normalized.contains('\u0641\u064a\u0647') ||
        normalized.contains('\u0641\u064a\u0647\u0627');
  }

  static bool _looksLikeNoteOnlyAvailabilityPatch(
    String normalized,
    _ExtractedNotes extractedNotes,
  ) {
    if (extractedNotes.included.isEmpty && extractedNotes.excluded.isEmpty) {
      return false;
    }
    return RegExp(
      r'\b(is there|do you have|have you got|available)\s+(?:one\s+|anything\s+)?with\b',
    ).hasMatch(normalized);
  }

  static bool looksLikeNoteOnlyAvailabilityPatch(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    return _looksLikeNoteOnlyAvailabilityPatch(
      normalized,
      _extractNotes(normalized),
    );
  }

  static bool _looksLikeScentBlendRequest(String normalized) {
    final hasBlendSignal =
        normalized.contains('خليط بين ريحتين') ||
        normalized.contains('خليط بين راحتين') ||
        normalized.contains('خليط بين رائحتين') ||
        normalized.contains('خليط بين نوتتين') ||
        normalized.contains('مزيج بين ريحتين') ||
        normalized.contains('مزيج بين نوتتين') ||
        normalized.contains('mix of two scents') ||
        normalized.contains('between two scents');
    if (!hasBlendSignal) return false;
    if (normalized.contains('خليط بين') ||
        normalized.contains('خليط ما بين') ||
        normalized.contains('mix between') ||
        normalized.contains('blend between') ||
        normalized.contains('blend of') ||
        normalized.contains('scent blend')) {
      return true;
    }
    final hasProductCompareAnchor =
        RegExp(r'\b[12]\b').hasMatch(normalized) ||
        normalized.contains('الاول') ||
        normalized.contains('الأول') ||
        normalized.contains('التاني') ||
        normalized.contains('الثاني') ||
        normalized.contains('compare') ||
        normalized.contains('قارن');
    return !hasProductCompareAnchor;
  }

  static bool isSummaryRequest(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    return containsAny(normalized, _summaryKeywords);
  }

  static bool shouldResetConversationContext(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    return containsAny(normalized, _contextResetKeywords);
  }

  /// Detects whether [message] is a short modifier patch (e.g. "أقوى", "أرخص",
  /// "سويت أكتر", "رجع زي الأول"). Returns `null` if the message is not a
  /// recognised modifier.
  static ModifierPatch? detectModifierPatch(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return null;

    // Revert has highest priority — it undoes previous modifiers.
    if (containsAny(normalized, revertModifiers)) {
      return const ModifierPatch(ModifierPatchType.revert);
    }
    if (containsAny(normalized, strongerModifiers)) {
      return const ModifierPatch(ModifierPatchType.stronger);
    }
    if (containsAny(normalized, lighterModifiers)) {
      return const ModifierPatch(ModifierPatchType.lighter);
    }
    if (_hasCheaperCue(normalized)) {
      return const ModifierPatch(ModifierPatchType.cheaper);
    }
    if (containsAny(normalized, sweeterModifiers)) {
      return const ModifierPatch(ModifierPatchType.sweeter);
    }

    // Pre-normalization check: the text normalizer converts "سويت اكتر" → "sweet"
    // which loses the "more" semantics. Catch the original Arabic phrase.
    final preNormalized = message
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    if (preNormalized.contains('سويت اكتر') ||
        preNormalized.contains('سويت أكتر')) {
      return const ModifierPatch(ModifierPatchType.sweeter);
    }

    return null;
  }

  static RankingStrategy? _extractRankingStrategy(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return null;

    final hasExpensiveCue =
        containsAny(normalized, _premiumKeywords) ||
        RegExp(
          r'(^|[\s،,.!?؛:])(?:أغلى|اغلى|اغلي|الأغلى|الاغلى|الاغلي|أفخم|افخم|بريميوم|بريميم)(?=$|[\s،,.!?؛:])',
        ).hasMatch(normalized) ||
        normalized.contains('premium') ||
        normalized.contains('luxury') ||
        normalized.contains('most expensive') ||
        normalized.contains('highest price');
    if (hasExpensiveCue) {
      return RankingStrategy.expensiveFirst;
    }

    final hasCheapestCue =
        RegExp(
          r'(^|[\s،,.!?؛:])(?:أرخص|ارخص|اقتصادي|موفر|أوفر|اوفر)(?=$|[\s،,.!?؛:])',
        ).hasMatch(normalized) ||
        _hasCheaperCue(normalized) ||
        normalized.contains('cheap') ||
        normalized.contains('cheaper') ||
        normalized.contains('cheapest') ||
        normalized.contains('more affordable') ||
        normalized.contains('most affordable') ||
        normalized.contains('less expensive') ||
        normalized.contains('lowest price') ||
        normalized.contains('best price') ||
        normalized.contains('minimum price') ||
        normalized.contains('economy') ||
        normalized.contains('economic') ||
        normalized.contains('economical');
    if (hasCheapestCue) {
      return RankingStrategy.cheapestFirst;
    }

    return null;
  }

  /// Convenience check: returns `true` when [message] is a recognised modifier.
  static bool isModifierPatchMessage(String message) {
    return detectModifierPatch(message) != null;
  }

  static bool isGreetingOnly(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;

    final cleaned = normalized.replaceAll(punctuation, ' ').trim();
    if (_looksLikeArabicGreeting(cleaned)) return true;
    if (_greetingPhrases.contains(cleaned)) return true;

    final tokens = cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (tokens.isEmpty) return false;

    var hasGreeting = false;
    for (final token in tokens) {
      if (_greetingTokens.contains(token)) {
        hasGreeting = true;
        continue;
      }
      return false;
    }
    return hasGreeting;
  }

  static bool _looksLikeArabicGreeting(String cleaned) {
    if (cleaned.isEmpty) return false;
    final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.contains('السلام عليكم') &&
        (compact.contains('ورحمه الله وبركاته') ||
            compact.contains('ورحمه الله') ||
            compact.contains('ورحمة الله وبركاته') ||
            compact.contains('ورحمة الله'))) {
      return true;
    }
    const exactGreetings = {
      'السلام عليكم',
      'السلام عليكم ورحمه الله',
      'السلام عليكم ورحمه الله وبركاته',
      'وعليكم السلام',
      'وعليكم السلام ورحمه الله',
      'وعليكم السلام ورحمه الله وبركاته',
    };
    if (exactGreetings.contains(compact)) return true;
    final tokens = compact.split(' ').where((token) => token.isNotEmpty);
    const allowedTokens = {
      'السلام',
      'عليكم',
      'وعليكم',
      'ورحمه',
      'رحمه',
      'الله',
      'وبركاته',
      'بركاته',
    };
    var hasCoreGreeting = false;
    for (final token in tokens) {
      if (!allowedTokens.contains(token)) return false;
      if (token == 'السلام' || token == 'عليكم' || token == 'وعليكم') {
        hasCoreGreeting = true;
      }
    }
    return hasCoreGreeting;
  }

  static bool isOpenChoiceReply(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (normalized.contains('open budget') ||
        normalized.contains('budget open') ||
        normalized.contains('no budget limit') ||
        normalized.contains('no limit') ||
        normalized.contains('unlimited') ||
        normalized.contains('مفتوح') ||
        normalized.contains('مفتوحه') ||
        normalized.contains('مفتوحة')) {
      return true;
    }
    return containsAny(normalized, _continueWithCurrentStateKeywords);
  }

  static bool isVague(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty || normalized.length < 3) return true;
    if (isGreetingOnly(normalized)) return false;
    if (detectIntent(normalized) != AIChatIntent.newRecommendation) {
      return false;
    }
    if (isModifierPatchMessage(normalized)) return false;

    final parsed = parse(normalized, SessionPreferences.empty());
    return !parsed.hasSufficientCriteria &&
        parsed.gender == null &&
        parsed.maxBudget == null &&
        parsed.season == null &&
        parsed.tags.isEmpty &&
        parsed.preferredNotes.isEmpty;
  }

  static bool looksLikePerfumeRequest(
    String message, {
    SessionPreferences currentPreferences = const SessionPreferences(),
  }) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;

    if (containsAny(normalized, _perfumeTopicKeywords)) {
      return true;
    }

    return currentPreferences.hasAnyScalarSignal ||
        currentPreferences.hasAnyNoteSignal ||
        currentPreferences.intensity != null ||
        currentPreferences.tags.isNotEmpty;
  }

  static bool looksLikeOutOfDomainRequest(
    String message, {
    SessionPreferences currentPreferences = const SessionPreferences(),
  }) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty || isGreetingOnly(normalized)) return false;
    if (_looksLikeBusinessInfoRequest(normalized)) return false;

    const outOfDomainTerms = {
      'mobile',
      'phone',
      'iphone',
      'android',
      'laptop',
      'macbook',
      'tablet',
      'car',
      'toyota',
      'tesla',
      'football',
      'soccer',
      'bank',
      'credit card',
      'debit card',
      '\u0645\u0648\u0628\u0627\u064a\u0644',
      '\u062a\u0644\u064a\u0641\u0648\u0646',
      '\u0644\u0627\u0628\u062a\u0648\u0628',
      '\u0644\u0627\u0628 \u062a\u0648\u0628',
      '\u0639\u0631\u0628\u064a\u0629',
      '\u0633\u064a\u0627\u0631\u0629',
      '\u0643\u0648\u0631\u0629',
      '\u0628\u0646\u0643',
      '\u0643\u0627\u0631\u062a',
      '\u0628\u0637\u0627\u0642\u0629',
    };
    final hasOutOfDomainTerm = outOfDomainTerms.any(
      (term) => _containsTerm(normalized, normalizeInput(term)),
    );
    if (!hasOutOfDomainTerm) return false;

    final hasRequestVerb =
        RegExp(
          r'\b(recommend|suggest|buy|purchase|choose|pick|best|which|what)\b',
        ).hasMatch(normalized) ||
        _containsAnyTerm(normalized, const [
          '\u0631\u0634\u062d',
          '\u0631\u0634\u062d\u0644\u064a',
          '\u0639\u0627\u064a\u0632',
          '\u0639\u0627\u0648\u0632',
          '\u0627\u0634\u062a\u0631\u064a',
          '\u0627\u062e\u062a\u0627\u0631',
          '\u0623\u0641\u0636\u0644',
          '\u0627\u0641\u0636\u0644',
        ]);
    return hasRequestVerb || normalized.split(RegExp(r'\s+')).length <= 5;
  }

  static bool _looksLikeBusinessInfoRequest(String normalized) {
    return RegExp(
          r'\b(address|location|contact|phone|whatsapp|number|opening hours|working hours|delivery|shipping)\b',
        ).hasMatch(normalized) ||
        _containsAnyTerm(normalized, const [
          '\u0627\u0644\u0639\u0646\u0648\u0627\u0646',
          '\u0639\u0646\u0648\u0627\u0646\u0643\u0645',
          '\u0645\u0643\u0627\u0646\u0643\u0645',
          '\u0641\u064a\u0646 \u0627\u0644\u0645\u062d\u0644',
          '\u0627\u062a\u0648\u0627\u0635\u0644',
          '\u0631\u0642\u0645\u0643\u0645',
          '\u0648\u0627\u062a\u0633\u0627\u0628',
          '\u0645\u0648\u0627\u0639\u064a\u062f',
          '\u062a\u0648\u0635\u064a\u0644',
          '\u0634\u062d\u0646',
        ]);
  }

  static String normalizeInput(String input) {
    return parser_matchers.normalizeInput(input);
  }

  static bool containsAny(String message, Set<String> terms) {
    return parser_matchers.containsAny(message, terms);
  }

  static bool _containsTerm(String message, String term) {
    return findTermMatches(message, term).isNotEmpty;
  }

  static List<TermMatch> findTermMatches(String message, String term) {
    return parser_matchers.findTermMatches(message, term);
  }

  static String? _extractScalar(
    String message,
    List<String> canonicalValues,
    Map<String, String> aliases,
  ) {
    // Collect every match alongside its position in the message so we can
    // apply last-mention precedence: the rightmost mention reflects the
    // user's most recent intent (e.g. "I wanted summer but now autumn" → autumn).
    final allMatches = <({int start, int length, String value})>[];

    for (final canonical in canonicalValues) {
      final matchList = findTermMatches(message, normalizeInput(canonical));
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: canonical,
        ));
      }
    }
    for (final entry in aliases.entries) {
      final matchList = findTermMatches(message, normalizeInput(entry.key));
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: entry.value,
        ));
      }
    }

    if (allMatches.isEmpty) return null;

    // Sort ascending by position → last element = last mention
    final filteredMatches = allMatches.where((candidate) {
      final candidateEnd = candidate.start + candidate.length;
      return !allMatches.any((other) {
        if (candidate == other) return false;
        final otherEnd = other.start + other.length;
        return other.start <= candidate.start &&
            otherEnd >= candidateEnd &&
            other.length > candidate.length;
      });
    }).toList();

    filteredMatches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.length.compareTo(b.length);
    });
    return filteredMatches.last.value;
  }

  static String? _extractGenderScalar(String message) {
    // Gender aliases such as "male" are too short for fuzzy matching:
    // "make" is one edit away from "male", which can corrupt constraint-only
    // turns like "make it strictly under 800". Keep gender matching exact here;
    // typo-heavy gender is handled by the interpretation layer.
    final allMatches = <({int start, int length, String value})>[];

    for (final canonical in AINormalizationDictionary.canonicalGenders) {
      final matchList = _findExactTermMatches(
        message,
        normalizeInput(canonical),
      );
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: canonical,
        ));
      }
    }
    for (final entry in AINormalizer.flatGenderAliases.entries) {
      final matchList = _findExactTermMatches(
        message,
        normalizeInput(entry.key),
      );
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: entry.value,
        ));
      }
    }

    if (allMatches.isEmpty) return null;
    final filteredMatches = allMatches.where((candidate) {
      final candidateEnd = candidate.start + candidate.length;
      return !allMatches.any((other) {
        if (candidate == other) return false;
        final otherEnd = other.start + other.length;
        return other.start <= candidate.start &&
            otherEnd >= candidateEnd &&
            other.length > candidate.length;
      });
    }).toList();

    filteredMatches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.length.compareTo(b.length);
    });
    return filteredMatches.last.value;
  }

  static List<TermMatch> _findExactTermMatches(String message, String term) {
    final t = normalizeInput(term);
    if (t.isEmpty) return const [];

    final results = <TermMatch>[];
    var idx = message.indexOf(t);
    while (idx != -1) {
      final start = idx;
      final end = idx + t.length;

      var beforeOk = true;
      if (start > 0) {
        if (parser_matchers.isWordChar(message[start - 1])) {
          beforeOk = _hasArabicPrefixBoundary(message, start, t);
          if (parser_matchers.arabicChar(t)) {
            final prefixStr = message.substring(0, start);
            if (RegExp(
              r'(^|\s)(ال|و|ف|ب|ك|ل|وال|فال|بال|كال|لل)$',
            ).hasMatch(prefixStr)) {
              beforeOk = true;
            }
          }
        }
      }

      var afterOk = true;
      if (end < message.length) {
        if (parser_matchers.isWordChar(message[end])) {
          afterOk = _hasArabicSuffixBoundary(message, end, t);
          if (parser_matchers.arabicChar(t)) {
            final suffixStr = message.substring(end);
            if (RegExp(
              r'^(ها|ه|ي|ك|كم|نا|ة|ين|ون|ات)(\s|$)',
            ).hasMatch(suffixStr)) {
              afterOk = true;
            }
          }
        }
      }

      if (beforeOk && afterOk) {
        results.add(TermMatch(start: start, end: end));
      }
      idx = message.indexOf(t, idx + 1);
    }
    return results;
  }

  static bool _hasArabicPrefixBoundary(String message, int start, String term) {
    if (!parser_matchers.arabicChar(term)) return false;
    final prefix = message.substring(0, start);
    return RegExp(r'(^|\s)(ال|و|ف|ب|ك|ل|وال|فال|بال|كال|لل)$').hasMatch(prefix);
  }

  static bool _hasArabicSuffixBoundary(String message, int end, String term) {
    if (!parser_matchers.arabicChar(term)) return false;
    final suffix = message.substring(end);
    return RegExp(r'^(ها|ه|ي|ك|كم|نا|ة|ين|ون|ات)(\s|$)').hasMatch(suffix);
  }

  static String? _extractIntensity(String message) {
    final allMatches = <({int start, int length, String value})>[];

    for (final canonical in AINormalizationDictionary.canonicalIntensities) {
      final matchList = findTermMatches(message, normalizeInput(canonical));
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: canonical,
        ));
      }
    }
    for (final entry in AINormalizer.flatIntensityAliases.entries) {
      final matchList = findTermMatches(message, normalizeInput(entry.key));
      for (final m in matchList) {
        allMatches.add((
          start: m.start,
          length: m.end - m.start,
          value: entry.value,
        ));
      }
    }

    if (allMatches.isEmpty) return null;

    final filteredMatches = allMatches.where((candidate) {
      final candidateEnd = candidate.start + candidate.length;
      final isContained = allMatches.any((other) {
        if (candidate == other) return false;
        final otherEnd = other.start + other.length;
        return other.start <= candidate.start &&
            otherEnd >= candidateEnd &&
            other.length > candidate.length;
      });
      if (isContained) return false;
      if (candidate.value == 'strong' &&
          _isNegatedIntensityMatch(message, candidate.start, candidateEnd)) {
        return false;
      }
      return true;
    }).toList();

    if (filteredMatches.isEmpty) return null;
    filteredMatches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.length.compareTo(b.length);
    });
    return filteredMatches.last.value;
  }

  static bool _containsNonNegatedStrongerModifier(String message) {
    for (final term in strongerModifiers) {
      final normalizedTerm = normalizeInput(term);
      final matches = findTermMatches(message, normalizedTerm);
      for (final match in matches) {
        if (!_isNegatedIntensityMatch(message, match.start, match.end)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isNegatedIntensityMatch(String message, int start, int end) {
    final windowStart = (start - 18).clamp(0, message.length);
    final before = message.substring(windowStart, start).trimRight();
    if (before.isEmpty) return false;

    const negationPrefixes = <String>{
      'not',
      'no',
      'without',
      'less',
      'not too',
      'not very',
      'not that',
      '\u0645\u0634',
      '\u0648\u0645\u0634',
      '\u0648 \u0645\u0634',
      '\u0645\u0648\u0634',
      '\u0648\u0645\u0648\u0634',
      '\u0628\u0644\u0627\u0634',
      '\u0628\u062f\u0648\u0646',
      '\u0645\u0646 \u063a\u064a\u0631',
    };

    for (final prefix in negationPrefixes) {
      final normalizedPrefix = normalizeInput(prefix);
      if (before == normalizedPrefix || before.endsWith(' $normalizedPrefix')) {
        return true;
      }
    }

    return false;
  }

  static double? _extractBudget(String message, double? currentBudget) {
    return BudgetAmountParser.extractMaxBudget(
      message,
      currentBudget: currentBudget,
      budgetContextKeywords: _budgetContextKeywords,
      cheapKeywords: cheapKeywords,
    );
  }

  static double? _extractAffordabilityBudgetHint(
    String message,
    double? currentBudget,
  ) {
    if (_shouldClearBudget(message)) return null;
    if (BudgetAmountParser.containsBudgetNumber(message)) return null;
    if (!_hasCheaperCue(message)) return null;
    if (currentBudget != null) return currentBudget * 0.8;
    if (_hasExplicitReferenceProfile(message) &&
        (message.contains('sauvage') ||
            message.contains('سوفاج') ||
            message.contains('سوفاج'))) {
      return null;
    }
    return 1200;
  }

  static String _focusRecommendationTail(String input) {
    final normalized = AIChatTextNormalizer.normalizeForParsing(input);
    var bestIndex = -1;
    for (final marker in _summaryTailMarkers) {
      final index = normalized.lastIndexOf(normalizeInput(marker));
      if (index > bestIndex) bestIndex = index;
    }
    if (bestIndex == -1) {
      if (normalized.length <= 240) return input;
      return normalized.substring(normalized.length - 240);
    }
    return normalized.substring(bestIndex);
  }

  static String? _detectLayer(String message) {
    for (final entry in AINormalizer.flatLayerAliases.entries) {
      if (_containsTerm(message, normalizeInput(entry.key))) {
        return entry.value;
      }
    }
    for (final layer in AINormalizationDictionary.canonicalNoteLayers) {
      if (_containsTerm(message, normalizeInput(layer))) return layer;
    }
    return null;
  }

  static Set<String> _extractTags(String message) {
    final tags = <String>{};
    for (final entry in AINormalizer.flatTagAliases.entries) {
      if (_containsTerm(message, normalizeInput(entry.key))) {
        tags.add(entry.value);
      }
    }
    for (final canonical in AINormalizationDictionary.canonicalTags) {
      if (_containsTerm(message, normalizeInput(canonical))) {
        tags.add(canonical);
      }
    }
    return tags;
  }

  static bool _shouldSuppressAmbiguousGiftTag(String message) {
    if (!_hasCalmQuietCue(message)) {
      return false;
    }
    if (_hasExplicitGiftContext(message)) return false;

    return _looksLikeProfessionalContext(message) ||
        _looksLikeOfficeSafeContext(message) ||
        _containsAnyTerm(message, const [
          '\u0635\u064a\u0641',
          '\u0635\u064a\u0641\u064a',
          '\u0644\u0644\u0635\u064a\u0641',
          '\u0634\u062a\u0627',
          '\u0634\u062a\u0648\u064a',
          '\u0644\u0644\u0634\u062a\u0627',
          '\u0634\u063a\u0644',
          '\u0644\u0644\u0634\u063a\u0644',
          '\u0645\u0643\u062a\u0628',
          '\u062f\u0648\u0627\u0645',
        ]) ||
        _containsStrictPhrase(message, 'summer') ||
        _containsStrictPhrase(message, 'winter') ||
        _containsStrictPhrase(message, 'office') ||
        _containsStrictPhrase(message, 'work');
  }

  static bool _hasCalmQuietCue(String message) {
    return _containsAnyTerm(message, const [
          '\u0647\u0627\u062f\u064a',
          '\u0647\u0627\u062f\u064a\u0647',
          '\u0647\u0627\u062f\u0626',
          '\u0647\u0627\u062f\u0626\u0647',
          '\u0647\u0627\u062f\u0626\u0629',
        ]) ||
        _containsStrictPhrase(message, 'quiet') ||
        _containsStrictPhrase(message, 'calm');
  }

  static bool _hasExplicitGiftContext(String message) {
    return _containsStrictPhrase(message, 'gift for') ||
        _containsStrictPhrase(message, 'present for') ||
        _containsAnyTerm(message, const [
          '\u0647\u062f\u064a\u0629 \u0644',
          '\u0647\u062f\u064a\u0647 \u0644',
          '\u0644\u0644\u0625\u0647\u062f\u0627\u0621',
          '\u0644\u0644\u0627\u0647\u062f\u0627\u0621',
          '\u0644\u062e\u0637\u064a\u0628\u062a\u064a',
          '\u0644\u062e\u0637\u064a\u0628\u064a',
          '\u0644\u0632\u0648\u062c\u062a\u064a',
          '\u0644\u0632\u0648\u062c\u064a',
          '\u0644\u0648\u0627\u0644\u062f\u062a\u064a',
          '\u0644\u0648\u0627\u0644\u062f\u064a',
          '\u0644\u0645\u062f\u064a\u0631\u064a',
          '\u0644\u0645\u062f\u064a\u0631\u062a\u064a',
          '\u0644\u0648\u0627\u062d\u062f \u0635\u0627\u062d\u0628\u064a',
          '\u0644\u0648\u0627\u062d\u062f\u0629 \u0635\u0627\u062d\u0628\u062a\u064a',
        ]);
  }

  static bool _hasNegativeSweetStyle(String message) {
    final normalized = normalizeInput(message);
    if (normalized.isEmpty) return false;
    final hasSweetSignal =
        _containsTerm(normalized, 'sweet') ||
        _containsTerm(normalized, 'sugary');
    if (!hasSweetSignal) return false;
    return RegExp(
          r'\bnothing\s+(?:too|very|overly)?\s*(sweet|sugary)\b',
        ).hasMatch(normalized) ||
        RegExp(
          r'\b(remove|without|avoid|exclude|excluding|not|no)\b',
        ).hasMatch(normalized) ||
        RegExp(r'\b(?:sweet|sugary)\s+false\b').hasMatch(normalized) ||
        RegExp(r'\b(?:sweet|sugary)\s*=\s*false\b').hasMatch(normalized);
  }

  static bool _hasSoftSweetLimit(String message) {
    final normalized = normalizeInput(message);
    return RegExp(
          r'\bnothing\s+(?:too|very|overly)?\s*(sweet|sugary)\b',
        ).hasMatch(normalized) ||
        RegExp(
          r'\bnot\s+(too|very|overly)\s+(sweet|sugary)\b',
        ).hasMatch(normalized) ||
        RegExp(
          r'\bnot\s+(sweet|sugary)\s+(too|very|overly)\b',
        ).hasMatch(normalized);
  }

  static bool _looksLikeCleanerDirection(String message) {
    final normalized = normalizeInput(message);
    return _containsTerm(normalized, 'clean') ||
        _containsTerm(normalized, 'cleaner') ||
        _containsTerm(normalized, 'fresh') ||
        _containsTerm(normalized, '\u0646\u0636\u064a\u0641') ||
        _containsTerm(normalized, '\u0646\u0636\u064a\u0641\u0629') ||
        _containsTerm(normalized, '\u0641\u0631\u064a\u0634');
  }

  static _ExtractedNotes _extractNotes(String message) {
    final included = <String>{};
    final excluded = <String>{};

    final terms = <MapEntry<String, String>>[
      ...AINormalizer.flatNoteAliases.entries,
      ...AINormalizationDictionary.canonicalNotes.map((n) => MapEntry(n, n)),
    ];

    for (final entry in terms) {
      final canonical = entry.value;
      final matches = _findNoteTermMatches(message, normalizeInput(entry.key));
      for (final match in matches) {
        final start = match.start;
        final end = match.end;

        if (_isNegationContext(message, start, end)) {
          excluded.add(canonical);
        } else {
          included.add(canonical);
        }
      }
    }

    included.removeAll(excluded);

    return _ExtractedNotes(included: included, excluded: excluded);
  }

  static List<TermMatch> _findNoteTermMatches(String message, String term) {
    final normalizedTerm = normalizeInput(term);
    if (normalizedTerm.isEmpty) return const [];
    if (parser_matchers.arabicChar(normalizedTerm) &&
        normalizedTerm.length <= 4) {
      return _findExactTermMatches(message, normalizedTerm);
    }
    return findTermMatches(message, normalizedTerm);
  }

  static Set<String> _extractAllergyExcludedNotes(String message) {
    final normalized = normalizeInput(message);
    final hasAllergySignal =
        normalized.contains('allergy') ||
        normalized.contains('allergic') ||
        normalized.contains('sensitive to') ||
        normalized.contains('\u062d\u0633\u0627\u0633\u064a\u0629') ||
        normalized.contains('\u062d\u0633\u0627\u0633');
    if (!hasAllergySignal) return const <String>{};

    final excluded = <String>{};
    if (_containsAnyTerm(normalized, const [
      'vanilla',
      '\u0641\u0627\u0646\u064a\u0644\u064a\u0627',
      '\u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627',
    ])) {
      excluded.add('vanilla');
    }
    if (_containsAnyTerm(normalized, const [
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
    if (_containsAnyTerm(normalized, const [
      'rose',
      '\u0648\u0631\u062f',
      '\u0627\u0644\u0648\u0631\u062f',
    ])) {
      excluded.add('rose');
    }
    if (_containsAnyTerm(normalized, const [
      'jasmine',
      '\u064a\u0627\u0633\u0645\u064a\u0646',
      '\u0627\u0644\u064a\u0627\u0633\u0645\u064a\u0646',
    ])) {
      excluded.add('jasmine');
    }
    return excluded;
  }

  static bool _containsAnyTerm(String message, List<String> terms) {
    return terms.any((term) => _containsTerm(message, normalizeInput(term)));
  }

  static bool _isNegationContext(String message, int start, int end) {
    final windowStart = (start - 35).clamp(0, message.length);
    final before = message.substring(windowStart, start);

    int lastRemoveIdx = -1;
    for (final term in _removeTriggers) {
      final matches = findTermMatches(before, term);
      if (matches.isNotEmpty && matches.last.start > lastRemoveIdx) {
        lastRemoveIdx = matches.last.start;
      }
    }

    int lastAddIdx = -1;
    for (final term in _addTriggers) {
      final matches = findTermMatches(before, term);
      if (matches.isNotEmpty && matches.last.start > lastAddIdx) {
        lastAddIdx = matches.last.start;
      }
    }

    if (lastRemoveIdx != -1) {
      if (lastAddIdx > lastRemoveIdx) {
        return false;
      }
      return true;
    }

    final afterEnd = (end + 18).clamp(0, message.length);
    final after = message.substring(end, afterEnd);
    return _arabicRemoveTriggers.any((term) => _containsTerm(before, term)) ||
        _arabicHardExclusionSuffixes.any((term) => _containsTerm(after, term));
  }

  static bool _shouldReplacePreferredNotesForFreshRequest(
    String message,
    Set<String> includedNotes,
  ) {
    if (includedNotes.isEmpty) return false;
    if (containsAny(message, _addTriggers) ||
        containsAny(message, _removeTriggers)) {
      return false;
    }
    return _containsAnyTerm(message, const [
      'recommend',
      'suggest',
      'i need',
      'need a',
      'need perfume',
      'want perfume',
      '\u0631\u0634\u062d',
      '\u0631\u0634\u062d\u0644\u064a',
      '\u0631\u0634\u062d\u0644\u0649',
      '\u0645\u062d\u062a\u0627\u062c \u0639\u0637\u0631',
      '\u0639\u0627\u064a\u0632 \u0639\u0637\u0631',
      '\u0647\u0627\u062a\u0644\u064a \u0639\u0637\u0631',
      '\u0647\u0627\u062a\u0644\u0649 \u0639\u0637\u0631',
    ]);
  }

  static const Set<String> _arabicRemoveTriggers = {
    '\u0645\u064a\u0643\u0648\u0646\u0634 \u0641\u064a\u0647',
    '\u0645\u0627\u064a\u0643\u0648\u0646\u0634 \u0641\u064a\u0647',
    '\u0645\u064a\u0643\u0648\u0646\u0634',
    '\u0645\u0627\u064a\u0643\u0648\u0646\u0634',
    '\u0645\u0641\u064a\u0634',
    '\u0645\u0641\u064a\u0647\u0648\u0634',
    '\u0645\u0627\u0641\u064a\u0647\u0648\u0634',
    '\u0645\u0641\u064a\u0647\u0627\u0634',
    '\u0645\u0627\u0641\u064a\u0647\u0627\u0634',
    '\u0628\u062f\u0648\u0646',
    '\u0645\u0646 \u063a\u064a\u0631',
  };

  static const Set<String> _arabicHardExclusionSuffixes = {
    '\u0646\u0647\u0627\u0626\u064a',
    '\u062e\u0627\u0644\u0635',
  };

  static void _addPreferredNote({
    required String note,
    required String? layer,
    required Set<String> preferredNotes,
    required Set<String> preferredTopNotes,
    required Set<String> preferredMiddleNotes,
    required Set<String> preferredBaseNotes,
  }) {
    switch (layer) {
      case 'top':
        preferredTopNotes.add(note);
        break;
      case 'middle':
        preferredMiddleNotes.add(note);
        break;
      case 'base':
        preferredBaseNotes.add(note);
        break;
      default:
        preferredNotes.add(note);
        break;
    }
  }

  static void _applyReferenceProfiles({
    required String message,
    required Set<String> preferredNotes,
    required Set<String> tags,
    required void Function(String hint) onGenderHint,
    required void Function(String hint) onSeasonHint,
    required void Function(String hint) onOccasionHint,
    required void Function(String hint) onIntensityHint,
    required void Function(String hint) onTimeHint,
  }) {
    for (final profile in AvailabilityReferenceProfileRegistry.profiles) {
      if (profile.key == 'date_night' &&
          _looksLikeSoftRomanticContext(message)) {
        continue;
      }
      if (!_containsExplicitReferenceAlias(message, profile.aliases)) {
        continue;
      }
      preferredNotes.addAll(profile.preferredNotes);
      tags.addAll(profile.tags);
      if (profile.genderHint != null) onGenderHint(profile.genderHint!);
      if (profile.seasonHint != null) onSeasonHint(profile.seasonHint!);
      if (profile.occasionHint != null) onOccasionHint(profile.occasionHint!);
      if (profile.intensityHint != null) {
        onIntensityHint(profile.intensityHint!);
      }
      if (profile.timeHint != null) onTimeHint(profile.timeHint!);
    }
  }

  static bool _hasExplicitReferenceProfile(String message) {
    for (final profile in AvailabilityReferenceProfileRegistry.profiles) {
      if (_containsExplicitReferenceAlias(message, profile.aliases)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsExplicitReferenceAlias(
    String message,
    Set<String> aliases,
  ) {
    for (final alias in aliases) {
      if (_containsExplicitAlias(message, alias)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsExplicitAlias(String message, String alias) {
    final normalizedAlias = normalizeInput(alias);
    if (normalizedAlias.isEmpty) return false;

    if (normalizedAlias.contains(' ')) {
      return _containsStrictPhrase(message, normalizedAlias);
    }

    for (final token in parser_matchers.tokenMatches(message)) {
      final candidate = message.substring(token.start, token.end);
      if (_normalizeTokenForReferenceMatch(candidate) == normalizedAlias) {
        return true;
      }
    }
    return false;
  }

  static bool _containsStrictPhrase(String message, String phrase) {
    var idx = message.indexOf(phrase);
    while (idx != -1) {
      final start = idx;
      final end = idx + phrase.length;
      final beforeOk =
          start == 0 || !parser_matchers.isWordChar(message[start - 1]);
      final afterOk =
          end >= message.length || !parser_matchers.isWordChar(message[end]);
      if (beforeOk && afterOk) {
        return true;
      }
      idx = message.indexOf(phrase, idx + 1);
    }
    return false;
  }

  static String _normalizeTokenForReferenceMatch(String token) {
    var normalized = normalizeInput(token);
    if (normalized.isEmpty) return normalized;

    // Strip common Arabic clitics so aliases still match explicit phrases
    // like "للجامعة" -> "جامعة".
    var keepStripping = true;
    while (keepStripping && normalized.length > 3) {
      keepStripping = false;
      if (normalized.startsWith('وال') ||
          normalized.startsWith('فال') ||
          normalized.startsWith('بال') ||
          normalized.startsWith('كال')) {
        normalized = normalized.substring(3);
        keepStripping = true;
        continue;
      }
      if (normalized.startsWith('لل')) {
        normalized = normalized.substring(2);
        keepStripping = true;
        continue;
      }
      if (normalized.startsWith('ال')) {
        normalized = normalized.substring(2);
        keepStripping = true;
        continue;
      }
      if ('وفبكل'.contains(normalized[0])) {
        normalized = normalized.substring(1);
        keepStripping = true;
      }
    }

    return normalized;
  }
}

class _ExtractedNotes {
  final Set<String> included;
  final Set<String> excluded;

  const _ExtractedNotes({required this.included, required this.excluded});
}
