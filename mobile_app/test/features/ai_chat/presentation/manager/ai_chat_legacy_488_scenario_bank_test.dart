import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_official_contracts.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_catalog.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

class _MockUserTasteRepo extends Mock implements UserTasteRepo {}

void main() {
  group('AI Chat legacy 488 bilingual scenario bank', () {
    late List<_LegacyScenarioPair> pairs;
    late List<_LegacyScenarioVariant> variants;

    setUpAll(() {
      registerFallbackValue(const SessionPreferences());
      registerFallbackValue(AIChatLanguage.english);
      registerFallbackValue(EventType.view);
      registerFallbackValue(AIChatMessage.user('fallback'));
      registerFallbackValue(
        const AIChatCompactConversationContext(
          recentMessages: <AIChatCompactMessage>[],
          lastVisibleProductIds: <String>[],
        ),
      );
      registerFallbackValue(
        const ExternalPerfumeCandidate(
          id: 'fallback',
          displayName: 'Fallback',
          brand: 'Fallback',
          sourceUrl: 'https://example.com/fallback',
        ),
      );
      pairs = _LegacyScenarioParser.parse(_legacyScenarioFile());
      variants = pairs.expand((pair) => pair.variants).toList(growable: false);
    });

    test('parses the full legacy bilingual bank without changing runtime', () {
      expect(pairs, hasLength(488));
      expect(variants, hasLength(976));
      expect(variants.where((item) => item.language == 'en'), hasLength(488));
      expect(variants.where((item) => item.language == 'ar'), hasLength(488));
      expect(
        pairs.expand((item) => item.messagesEn).length,
        785,
        reason: 'The old catalog declares 785 English test turns.',
      );
      expect(
        pairs.expand((item) => item.messagesAr).length,
        785,
        reason: 'The old catalog declares 785 Arabic test turns.',
      );
    });

    test('keeps scenarios bounded for future runtime execution', () {
      final maxTurns = pairs
          .map((item) => item.maxTurns)
          .reduce((a, b) => a > b ? a : b);
      expect(maxTurns, 7);
      expect(
        maxTurns <= 10,
        isTrue,
        reason:
            'The current 10-turn runtime cap is enough for this legacy bank.',
      );
      expect(pairs.where((item) => item.maxTurns == 1), hasLength(314));
      expect(pairs.where((item) => item.maxTurns > 1), hasLength(174));
    });

    test('generates stable split EN and AR variant IDs', () {
      final ids = variants.map((item) => item.id).toList(growable: false);
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.first, 'LEG-EN-001');
      expect(ids[1], 'LEG-AR-001');
      expect(ids.last, 'LEG-AR-488');
    });

    test(
      'records duplicate message fingerprints for dedup instead of hiding them',
      () {
        final enDuplicateGroups = _duplicateFingerprintGroups(
          pairs.map((item) => item.englishFingerprint),
        );
        final arDuplicateGroups = _duplicateFingerprintGroups(
          pairs.map((item) => item.arabicFingerprint),
        );

        expect(enDuplicateGroups, hasLength(12));
        expect(arDuplicateGroups, hasLength(12));
        expect(
          pairs.map((item) => item.englishFingerprint).toSet(),
          hasLength(474),
        );
        expect(
          pairs.map((item) => item.arabicFingerprint).toSet(),
          hasLength(474),
        );
      },
    );

    test(
      'contains high-value safety, availability, external, and UX scenarios',
      () {
        final allText = pairs
            .expand(
              (item) => <String>[
                item.title,
                item.whatItTestsEn,
                ...item.messagesEn,
                ...item.messagesAr,
              ],
            )
            .join('\n')
            .toLowerCase();

        expect(allText, contains('prompt injection'));
        expect(allText, contains('system prompt'));
        expect(allText, contains('availability'));
        expect(allText, contains('sauvage'));
        expect(allText, contains('dior sauvage'));
        expect(allText, contains('no raw json'));
        expect(allText, contains('percent'));
      },
    );

    test(
      'writes a sanitized readiness and UX audit report for all variants',
      () {
        final audit = _LegacyScenarioAudit.fromPairs(pairs);
        final outputDir = Directory(
          '../test_artifacts/ai_chat_legacy_488_scenario_bank',
        )..createSync(recursive: true);
        _writeUtf8ReportSync(
          File('${outputDir.path}/summary.md'),
          audit.toMarkdown(),
          includeBom: true,
        );
        _writeUtf8ReportSync(
          File('${outputDir.path}/results.json'),
          audit.toJson(),
        );

        expect(audit.totalPairs, 488);
        expect(audit.totalVariants, 976);
        expect(audit.maxTurns, lessThanOrEqualTo(10));
        expect(audit.categoryCounts['safety'], greaterThan(0));
        expect(audit.categoryCounts['availability'], greaterThan(0));
        expect(audit.categoryCounts['external_reference'], greaterThan(0));
        expect(audit.categoryCounts['memory'], greaterThan(0));
        expect(audit.categoryCounts['budget'], greaterThan(0));
        expect(
          audit.uxRiskCounts['legacy_exact_text_expectation'],
          greaterThan(0),
        );
        expect(
          audit.uxRiskCounts['mixed_arabic_english_translation'],
          greaterThan(0),
        );
      },
    );

    test(
      'runs all 976 variants through mocked Cubit runtime and writes ultimate UX feedback',
      () async {
        final results = <_LegacyRuntimeResult>[];
        for (var index = 0; index < variants.length; index++) {
          final variant = variants[index];
          results.add(await _runLegacyVariantRuntime(variant));
          if ((index + 1) % 50 == 0 || index + 1 == variants.length) {
            // Keep long local runs visibly alive; this suite exercises 976
            // full Cubit instances and can take several minutes on Windows.
            // ignore: avoid_print
            print('legacy_runtime_progress=${index + 1}/${variants.length}');
          }
        }

        final report = _LegacyRuntimeReport.fromResults(results);
        final outputDir = Directory(
          '../test_artifacts/ai_chat_legacy_488_runtime_audit',
        )..createSync(recursive: true);
        _writeUtf8ReportSync(
          File('${outputDir.path}/summary.md'),
          report.toMarkdown(),
          includeBom: true,
        );
        _writeUtf8ReportSync(
          File('${outputDir.path}/results.json'),
          report.toJson(),
        );

        expect(report.totalVariants, 976);
        expect(report.completedVariants, 976);
        expect(report.issueCounts, isEmpty);
        expect(report.issueCounts['mojibake'] ?? 0, 0);
        expect(report.previewMojibakeScenarioIds, isEmpty);
        final triagedCaveats = report.caveatCounts.entries
            .where(
              (entry) =>
                  entry.key.startsWith('recommendation_no_match_triaged:'),
            )
            .fold<int>(0, (sum, entry) => sum + entry.value);
        expect(
          report.noMatchTriageCounts.values.fold<int>(0, (a, b) => a + b),
          triagedCaveats,
          reason: 'Every recommendation no-match must have a triage cause.',
        );
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}

void _writeUtf8ReportSync(
  File file,
  String contents, {
  bool includeBom = false,
}) {
  final bytes = utf8.encode(contents);
  file.writeAsBytesSync(
    includeBom ? <int>[0xEF, 0xBB, 0xBF, ...bytes] : bytes,
    flush: true,
  );
}

File _legacyScenarioFile() {
  final candidates = <String>[
    '../docs/old tests/ai_chat_scenarios_bilingual.md',
    'docs/old tests/ai_chat_scenarios_bilingual.md',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  throw StateError('Could not find ai_chat_scenarios_bilingual.md');
}

List<List<String>> _duplicateFingerprintGroups(Iterable<String> fingerprints) {
  final counts = <String, int>{};
  for (final fingerprint in fingerprints) {
    counts[fingerprint] = (counts[fingerprint] ?? 0) + 1;
  }
  return counts.entries
      .where((entry) => entry.value > 1)
      .map((entry) => <String>[entry.key, entry.value.toString()])
      .toList(growable: false);
}

class _LegacyScenarioPair {
  const _LegacyScenarioPair({
    required this.index,
    required this.suite,
    required this.title,
    required this.category,
    required this.source,
    required this.messagesEn,
    required this.messagesAr,
    required this.whatItTestsEn,
  });

  final int index;
  final String suite;
  final String title;
  final String category;
  final String source;
  final List<String> messagesEn;
  final List<String> messagesAr;
  final String whatItTestsEn;

  int get maxTurns => messagesEn.length > messagesAr.length
      ? messagesEn.length
      : messagesAr.length;

  String get englishFingerprint => _fingerprint(messagesEn);
  String get arabicFingerprint => _fingerprint(messagesAr);

  List<_LegacyScenarioVariant> get variants => <_LegacyScenarioVariant>[
    _LegacyScenarioVariant(
      id: 'LEG-EN-${index.toString().padLeft(3, '0')}',
      pairIndex: index,
      language: 'en',
      suite: suite,
      title: title,
      category: category,
      source: source,
      messages: messagesEn,
      whatItTests: whatItTestsEn,
    ),
    _LegacyScenarioVariant(
      id: 'LEG-AR-${index.toString().padLeft(3, '0')}',
      pairIndex: index,
      language: 'ar',
      suite: suite,
      title: title,
      category: category,
      source: source,
      messages: messagesAr,
      whatItTests: whatItTestsEn,
    ),
  ];

  static String _fingerprint(List<String> messages) {
    return messages
        .map((item) => item.trim().replaceAll(RegExp(r'\s+'), ' '))
        .join(' || ')
        .toLowerCase();
  }
}

class _LegacyScenarioVariant {
  const _LegacyScenarioVariant({
    required this.id,
    required this.pairIndex,
    required this.language,
    required this.suite,
    required this.title,
    required this.category,
    required this.source,
    required this.messages,
    required this.whatItTests,
  });

  final String id;
  final int pairIndex;
  final String language;
  final String suite;
  final String title;
  final String category;
  final String source;
  final List<String> messages;
  final String whatItTests;
}

class _LegacyScenarioParser {
  static List<_LegacyScenarioPair> parse(File file) {
    final text = file.readAsStringSync();
    final lines = text.split(RegExp(r'\r?\n'));
    final pairs = <_LegacyScenarioPair>[];
    var currentSuite = '';
    var currentBlock = <String>[];

    void flush() {
      if (currentBlock.isEmpty) return;
      final pair = _parseBlock(
        currentBlock,
        index: pairs.length + 1,
        suite: currentSuite,
      );
      if (pair != null) pairs.add(pair);
      currentBlock = <String>[];
    }

    for (final line in lines) {
      final heading = RegExp(r'^##\s+(.+)$').firstMatch(line);
      if (heading != null && !line.startsWith('###')) {
        flush();
        currentSuite = heading.group(1)!.trim();
        continue;
      }
      if (line.startsWith('### ')) {
        flush();
      }
      if (line.startsWith('### ') || currentBlock.isNotEmpty) {
        currentBlock.add(line);
      }
    }
    flush();
    return pairs;
  }

  static _LegacyScenarioPair? _parseBlock(
    List<String> lines, {
    required int index,
    required String suite,
  }) {
    if (lines.isEmpty || !lines.first.startsWith('### ')) return null;
    final title = lines.first.replaceFirst(RegExp(r'^###\s+'), '').trim();
    final category = _extractLabel(lines, 'Category /') ?? 'Uncategorized';
    final source = _extractLabel(lines, 'Source /') ?? 'unknown';
    final whatItTestsEn = _extractLabel(lines, 'What it tests EN') ?? '';
    final messagesEn = <String>[];
    final messagesAr = <String>[];
    var mode = _MessageMode.none;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == '**Messages EN**') {
        mode = _MessageMode.english;
        continue;
      }
      if (mode == _MessageMode.english &&
          line.startsWith('**') &&
          line != '**Messages EN**') {
        mode = _MessageMode.arabic;
        continue;
      }
      if (line.startsWith('- **What it tests EN:**')) {
        mode = _MessageMode.none;
      }

      final enMatch = RegExp(r'^- Turn \d+:\s*(.+)$').firstMatch(line);
      if (mode == _MessageMode.english && enMatch != null) {
        messagesEn.add(enMatch.group(1)!.trim());
        continue;
      }

      if (mode == _MessageMode.arabic &&
          line.startsWith('- ') &&
          line.contains(':')) {
        messagesAr.add(line.substring(line.indexOf(':') + 1).trim());
      }
    }

    return _LegacyScenarioPair(
      index: index,
      suite: suite,
      title: title,
      category: category,
      source: source,
      messagesEn: messagesEn,
      messagesAr: messagesAr,
      whatItTestsEn: whatItTestsEn,
    );
  }

  static String? _extractLabel(List<String> lines, String labelPrefix) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('- **$labelPrefix')) continue;
      final separator = line.indexOf(':**');
      if (separator == -1) continue;
      return line.substring(separator + 3).trim();
    }
    return null;
  }
}

enum _MessageMode { none, english, arabic }

Future<_LegacyRuntimeResult> _runLegacyVariantRuntime(
  _LegacyScenarioVariant variant,
) async {
  final repo = _MockAIChatRepo();
  final tasteRepo = _MockUserTasteRepo();
  final events = <String>[];
  AIChatExperimentConfig.resetTestOverrides();
  AIChatExperimentConfig.setTestOverrides(
    sendCompactContext: true,
    toolRouterV1: true,
    delegateMicroTurns: true,
    useCatalogSearchEngine: true,
    useSuitabilityPolicy: true,
    deterministicGateV1: true,
    analyticsEventsEnabled: false,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _stubLegacyRepo(repo, events);
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
    initialLanguage: variant.language == 'ar'
        ? AIChatLanguage.arabic
        : AIChatLanguage.english,
    thinkingDelay: Duration.zero,
    cooldownDuration: Duration.zero,
  );

  final stopwatch = Stopwatch()..start();
  final issues = <String>[];
  final caveats = <String>[];
  try {
    for (final message in variant.messages) {
      await cubit.sendMessage(message);
    }
  } catch (error) {
    issues.add('runtime_exception:${error.runtimeType}');
  } finally {
    stopwatch.stop();
  }

  final state = cubit.state;
  final lastBot = state.messages
      .where((message) => !message.isFromUser)
      .cast<AIChatMessage?>()
      .lastOrNull;
  final content = lastBot?.content.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  final productIds =
      lastBot?.recommendedProducts
          .map((item) => item.product.id)
          .toList(growable: false) ??
      <String>[];
  final productNames =
      lastBot?.recommendedProducts
          .map((item) => item.product.name)
          .toList(growable: false) ??
      <String>[];
  final noMatchTriage = _recommendationNoMatchTriageFor(variant, state);
  issues.addAll(_runtimeIssuesFor(variant, content, productIds, productNames));
  caveats.addAll(_runtimeCaveatsFor(variant, state, content, productIds));
  if (noMatchTriage != null) {
    caveats.add('recommendation_no_match_triaged:$noMatchTriage');
  }

  await cubit.close();
  AIChatExperimentConfig.resetTestOverrides();

  return _LegacyRuntimeResult(
    id: variant.id,
    pairIndex: variant.pairIndex,
    language: variant.language,
    title: variant.title,
    suite: variant.suite,
    turns: variant.messages.length,
    status: state.status.name,
    messageType: lastBot?.type.name ?? 'none',
    source: lastBot?.responseSource,
    contentPreview: content.length > 180 ? content.substring(0, 180) : content,
    productIds: productIds,
    productNames: productNames,
    elapsedMs: stopwatch.elapsedMilliseconds,
    issues: issues,
    caveats: caveats,
    noMatchTriage: noMatchTriage,
    eventTypes: events,
  );
}

void _stubLegacyRepo(_MockAIChatRepo repo, List<String> events) {
  when(() => repo.canPersistSession).thenReturn(false);
  when(() => repo.currentUserId).thenReturn(null);
  when(() => repo.lastWorkerFailureReasonCode).thenReturn(null);
  when(
    () => repo.getCatalog(forceRefresh: any(named: 'forceRefresh')),
  ).thenAnswer((_) async => mockCatalog);
  when(() => repo.setSessionId(any())).thenReturn(null);
  when(() => repo.invalidateCatalog()).thenReturn(null);
  when(() => repo.invalidateCatalogCache()).thenReturn(null);
  when(
    () => repo.fetchLatestRestorableSession(userId: any(named: 'userId')),
  ).thenAnswer((_) async => null);
  when(
    () => repo.fetchRestorableSessionById(
      sessionId: any(named: 'sessionId'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((_) async => null);
  when(
    () => repo.fetchSessionMessages(any()),
  ).thenAnswer((_) async => const <AIChatStoredMessage>[]);
  when(
    () => repo.createSession(
      sessionId: any(named: 'sessionId'),
      language: any(named: 'language'),
      startedAt: any(named: 'startedAt'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => repo.appendMessage(
      message: any(named: 'message'),
      sessionId: any(named: 'sessionId'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => repo.completeSession(
      sessionId: any(named: 'sessionId'),
      messageCount: any(named: 'messageCount'),
      finalRecommendationMessageId: any(named: 'finalRecommendationMessageId'),
      endedAt: any(named: 'endedAt'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => repo.logAIChatEvent(
      eventType: any(named: 'eventType'),
      sessionId: any(named: 'sessionId'),
      metadata: any(named: 'metadata'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((invocation) async {
    events.add(invocation.namedArguments[#eventType].toString());
  });
  when(
    () => repo.logAIChatEvent(
      eventType: any(named: 'eventType'),
      sessionId: any(named: 'sessionId'),
      metadata: any(named: 'metadata'),
    ),
  ).thenAnswer((invocation) async {
    events.add(invocation.namedArguments[#eventType].toString());
  });
  when(
    () => repo.saveAIChatDebugLog(
      phase: any(named: 'phase'),
      sessionId: any(named: 'sessionId'),
      requestId: any(named: 'requestId'),
      language: any(named: 'language'),
      messageText: any(named: 'messageText'),
      detectedIntent: any(named: 'detectedIntent'),
      responseSource: any(named: 'responseSource'),
      issueCode: any(named: 'issueCode'),
      reasonCode: any(named: 'reasonCode'),
      preferencesSnapshot: any(named: 'preferencesSnapshot'),
      availabilityContextSnapshot: any(named: 'availabilityContextSnapshot'),
      recommendationMemorySnapshot: any(named: 'recommendationMemorySnapshot'),
      candidateSummary: any(named: 'candidateSummary'),
      recommendedProducts: any(named: 'recommendedProducts'),
      workerReplySummary: any(named: 'workerReplySummary'),
    ),
  ).thenAnswer((_) async {});
  when(() => repo.lookupPerfumeKnowledge(any())).thenAnswer((_) async => null);
  when(
    () => repo.fetchBusinessInfo(forceRefresh: any(named: 'forceRefresh')),
  ).thenAnswer((_) async => null);
  when(
    () =>
        repo.fetchProductPublicStats(forceRefresh: any(named: 'forceRefresh')),
  ).thenAnswer((_) async => const <String, AIChatProductPublicStats>{});
  when(
    () => repo.fetchAIInterpretation(
      currentMessage: any(named: 'currentMessage'),
      currentPreferences: any(named: 'currentPreferences'),
      responseLanguage: any(named: 'responseLanguage'),
      hasRecommendationContext: any(named: 'hasRecommendationContext'),
      hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((_) async => null);
  when(
    () => repo.lookupExternalPerfumeKnowledge(
      query: any(named: 'query'),
      responseLanguage: any(named: 'responseLanguage'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((_) async => null);
  when(
    () => repo.lookupExternalPerfumeKnowledgeResult(
      query: any(named: 'query'),
      responseLanguage: any(named: 'responseLanguage'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((_) async => const ExternalPerfumeLookupResult.notFound());
  when(
    () => repo.resolveExternalPerfumeKnowledgeCandidate(
      candidate: any(named: 'candidate'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((_) async => null);
  when(
    () => repo.fetchAIRecommendation(
      currentMessage: any(named: 'currentMessage'),
      preferences: any(named: 'preferences'),
      candidates: any(named: 'candidates'),
      localRecommendations: any(named: 'localRecommendations'),
      responseLanguage: any(named: 'responseLanguage'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((invocation) async => _mockLegacyWorkerReply(invocation));
  when(
    () => repo.fetchAIRecommendationWithContext(
      currentMessage: any(named: 'currentMessage'),
      preferences: any(named: 'preferences'),
      candidates: any(named: 'candidates'),
      localRecommendations: any(named: 'localRecommendations'),
      compactContext: any(named: 'compactContext'),
      responseLanguage: any(named: 'responseLanguage'),
      requestId: any(named: 'requestId'),
    ),
  ).thenAnswer((invocation) async => _mockLegacyWorkerReply(invocation));
}

AIChatReply _mockLegacyWorkerReply(Invocation invocation) {
  final message = invocation.namedArguments[#currentMessage].toString();
  final normalized = message.toLowerCase();
  final preferences =
      invocation.namedArguments[#preferences] as SessionPreferences? ??
      const SessionPreferences();
  final language =
      invocation.namedArguments[#responseLanguage] as AIChatLanguage? ??
      AIChatLanguage.english;
  final requestId = invocation.namedArguments[#requestId]?.toString();
  final patched = preferences.mergePatch(_preferencesFromText(normalized));

  if (_containsAny(normalized, const [
    'system prompt',
    'developer message',
    'hidden policy',
    'jailbreak',
    'dan',
  ])) {
    return AIChatReply.answer(
      answer: language == AIChatLanguage.arabic
          ? 'لا أقدر أشارك تعليمات داخلية، لكن أقدر أساعدك في اختيار عطر مناسب من الكتالوج.'
          : 'I cannot share internal instructions, but I can help you choose a catalog perfume safely.',
      updatedPreferences: patched,
      requestId: requestId,
      provider: 'legacy_mock',
      modelId: 'semantic_contract_mock',
    );
  }
  if (_containsAny(normalized, const [
    'iphone',
    'qwerty',
    'asdf',
    'shawarma',
    'شاورما',
  ])) {
    return AIChatReply.answer(
      answer: language == AIChatLanguage.arabic
          ? 'أقدر أساعدك في العطور فقط. قلّي الطابع أو الميزانية أو المناسبة.'
          : 'I can help with perfumes only. Tell me the style, budget, or occasion you want.',
      updatedPreferences: patched,
      requestId: requestId,
      provider: 'legacy_mock',
      modelId: 'semantic_contract_mock',
    );
  }
  if (_looksLikeVagueLegacyAsk(normalized)) {
    return AIChatReply.ask(
      question: language == AIChatLanguage.arabic
          ? 'تحب العطر رجالي ولا نسائي، وميزانيتك في حدود كام؟'
          : 'Do you prefer men, women, or unisex, and what budget should I stay within?',
      updatedPreferences: patched,
      requestId: requestId,
      provider: 'legacy_mock',
      modelId: 'semantic_contract_mock',
    );
  }

  final ids = _rankMockProducts(normalized);
  return AIChatReply.recommend(
    productIds: ids,
    matchReasons: <String, String>{
      for (final id in ids)
        id: 'Closest catalog-backed match for this request.',
    },
    answer: language == AIChatLanguage.arabic
        ? 'اخترت لك أقرب ترشيحات آمنة من الكتالوج حسب طلبك.'
        : 'I found the closest safe catalog matches based on your request.',
    updatedPreferences: patched,
    requestId: requestId,
    provider: 'legacy_mock',
    modelId: 'semantic_contract_mock',
  );
}

SessionPreferences _preferencesFromText(String normalized) {
  return SessionPreferences(
    gender: normalized.contains('women') || normalized.contains('نسائي')
        ? 'women'
        : normalized.contains('unisex') || normalized.contains('يونيسكس')
        ? 'unisex'
        : normalized.contains('men') || normalized.contains('رجالي')
        ? 'men'
        : null,
    maxBudget: _budgetFromText(normalized),
    season: normalized.contains('winter') || normalized.contains('شتوي')
        ? 'winter'
        : normalized.contains('summer') || normalized.contains('صيف')
        ? 'summer'
        : null,
    occasion: normalized.contains('office') || normalized.contains('مكتب')
        ? 'office'
        : normalized.contains('university') || normalized.contains('جامعة')
        ? 'university'
        : normalized.contains('date') || normalized.contains('wedding')
        ? 'formal'
        : null,
    intensity: normalized.contains('strong') || normalized.contains('قوي')
        ? 'strong'
        : normalized.contains('light') || normalized.contains('خفيف')
        ? 'light'
        : null,
    preferredNotes: <String>[
      if (normalized.contains('vanilla') || normalized.contains('فانيليا'))
        'vanilla',
      if (normalized.contains('oud') || normalized.contains('عود')) 'oud',
      if (normalized.contains('woody') || normalized.contains('خشب')) 'woody',
      if (normalized.contains('musk') || normalized.contains('مسك')) 'musk',
      if (normalized.contains('citrus') || normalized.contains('lemon'))
        'citrus',
    ],
    excludedNotes: <String>[
      if (normalized.contains('without oud') || normalized.contains('no oud'))
        'oud',
      if (normalized.contains('without vanilla') ||
          normalized.contains('no vanilla'))
        'vanilla',
      if (normalized.contains('no citrus')) 'citrus',
    ],
  );
}

double? _budgetFromText(String normalized) {
  final match = RegExp(r'\b(\d{2,5})\b').firstMatch(normalized);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

bool _looksLikeVagueLegacyAsk(String normalized) {
  final trimmed = normalized.trim();
  return trimmed == 'عايز perfume' ||
      trimmed == 'عايز عطر' ||
      trimmed == 'هات perfume' ||
      trimmed == 'هات عطر' ||
      trimmed == 'i want a nice perfume' ||
      trimmed == 'recommend something' ||
      trimmed == 'show me something popular';
}

List<String> _rankMockProducts(String normalized) {
  if (normalized.contains('vanilla') ||
      normalized.contains('sweet') ||
      normalized.contains('فانيليا') ||
      normalized.contains('حلو')) {
    return const <String>['p3', 'p1', 'p2'];
  }
  if (normalized.contains('woody') ||
      normalized.contains('oud') ||
      normalized.contains('winter') ||
      normalized.contains('formal') ||
      normalized.contains('خشب') ||
      normalized.contains('عود') ||
      normalized.contains('شتوي')) {
    return const <String>['p2', 'p1', 'p3'];
  }
  return const <String>['p1', 'p2', 'p3'];
}

List<String> _runtimeIssuesFor(
  _LegacyScenarioVariant variant,
  String content,
  List<String> productIds,
  List<String> productNames,
) {
  final issues = <String>[];
  final text = <String>[
    variant.title,
    ...variant.messages,
  ].join('\n').toLowerCase();
  final lower = content.toLowerCase();
  if (content.trim().isEmpty) issues.add('empty_bot_reply');
  if (_containsMojibakeMarkers(content)) {
    issues.add('mojibake');
  }
  if (_containsAny(lower, const [
    'system prompt',
    'developer message',
    'hidden json contract',
    'internal policy',
  ])) {
    issues.add('internal_prompt_or_policy_leak');
  }
  if (RegExp(
    r'^(ok|okay|sure|understood|تمام|حاضر)[.!،\s]*$',
  ).hasMatch(lower)) {
    issues.add('generic_reply');
  }
  final invalidIds = productIds
      .where((id) => !mockCatalog.any((product) => product.id == id))
      .toList(growable: false);
  if (invalidIds.isNotEmpty) issues.add('invalid_product_ids');
  if (productNames.any(
    (name) => _containsAny(name.toLowerCase(), const [
      'dior',
      'sauvage',
      'bleu de chanel',
      'tom ford',
    ]),
  )) {
    issues.add('external_product_rendered_as_card');
  }
  final lastUserMessage = variant.messages.isEmpty
      ? ''
      : variant.messages.last.toLowerCase();
  if (_isSafetyScenario(lastUserMessage) && productIds.isNotEmpty) {
    issues.add('safety_or_offtopic_rendered_cards');
  }
  if (_isAvailabilityScenario(text) &&
      _containsAny(lower, const ['maybe', 'probably', 'i think']) &&
      productIds.isEmpty) {
    issues.add('ungrounded_availability_language');
  }
  return issues;
}

bool _containsMojibakeMarkers(String value) {
  return RegExp(
    r'[\u00d8\u00d9\u00c3\u00c2\u0400-\u04ff\ufffd]',
  ).hasMatch(value);
}

String? _recommendationNoMatchTriageFor(
  _LegacyScenarioVariant variant,
  AIChatState state,
) {
  final text = <String>[
    variant.title,
    ...variant.messages,
  ].join('\n').toLowerCase();
  if (!_isRecommendationLike(text) ||
      _isImpossibleBudget(text) ||
      state.status != AIChatStatus.noMatch) {
    return null;
  }
  return _noMatchTriageFor(variant);
}

List<String> _runtimeCaveatsFor(
  _LegacyScenarioVariant variant,
  AIChatState state,
  String content,
  List<String> productIds,
) {
  final caveats = <String>[];
  final text = <String>[
    variant.title,
    ...variant.messages,
  ].join('\n').toLowerCase();
  final lower = content.toLowerCase();
  if (_isRecommendationLike(text) &&
      state.status == AIChatStatus.ask &&
      !_looksLikeVagueLegacyAsk(variant.messages.last.toLowerCase())) {
    caveats.add('asked_clarification_for_specific_request');
  }
  final lastUserMessage = variant.messages.isEmpty
      ? ''
      : variant.messages.last.toLowerCase();
  if (_containsAny(lastUserMessage, const ['compare', 'which one', 'قارن']) &&
      productIds.isNotEmpty) {
    caveats.add('comparison_rendered_cards_instead_of_answer_only');
  }
  if (_containsAny(text, const [
        'emotional',
        'passed away',
        'wife will leave',
      ]) &&
      !_containsAny(lower, const ['sorry', 'understand', 'أفهم', 'آسف'])) {
    caveats.add('empathy_tone_not_obvious');
  }
  if (_containsAny(text, const ['summary', 'recall', 'remember', 'فاكر']) &&
      !_containsAny(lower, const ['so far', 'you asked', 'لحد دلوقتي'])) {
    caveats.add('memory_summary_not_obvious');
  }
  return caveats;
}

bool _containsAny(String value, Iterable<String> needles) {
  return needles.any(value.contains);
}

bool _isRecommendationLike(String text) {
  return _containsAny(text, const [
    'recommend',
    'perfume',
    'عطر',
    'رشح',
    'suggest',
    'i need',
    'i want',
  ]);
}

bool _isImpossibleBudget(String text) {
  return _containsAny(text, const [
    'under 50',
    'under 200',
    'تحت 200',
    'أقل من 50',
  ]);
}

bool _isSafetyScenario(String text) {
  return _containsAny(text, const [
    'system prompt',
    'jailbreak',
    'hidden policy',
    'iphone',
    'shawarma',
    'qwerty',
    'off-topic',
  ]);
}

bool _isAvailabilityScenario(String text) {
  return _containsAny(text, const [
    'available',
    'availability',
    'in stock',
    'موجود',
  ]);
}

String _noMatchTriageFor(_LegacyScenarioVariant variant) {
  final text = <String>[
    variant.title,
    variant.suite,
    variant.category,
    variant.whatItTests,
    ...variant.messages,
  ].join('\n').toLowerCase();

  if (_containsAny(text, const [
    'summary',
    'recall',
    'remember',
    'ذاكر',
    'فاكر',
    'لخص',
  ])) {
    return 'memory_context_loss';
  }
  if (_containsAny(text, const [
    'sauvage',
    'dior',
    'bleu de chanel',
    'tom ford',
    'external',
    'like ',
    'similar to',
    'شبه',
    'زي',
  ])) {
    return 'external_profile_gap';
  }
  if (_containsAny(text, const [
    'budget',
    'under ',
    'egp',
    'cheap',
    'cheaper',
    'جنيه',
    'ميزانية',
    'أرخص',
    'ارخص',
  ])) {
    return 'strict_budget_or_guard_real_no_match';
  }
  if (_containsAny(text, const [
    'rose',
    'floral',
    'oud',
    'amber',
    'woody',
    'musk',
    'spicy',
    'aquatic',
    'vanilla',
    'sandalwood',
    'jasmine',
    'ورد',
    'فلورال',
    'عود',
    'عنبر',
    'خشب',
    'مسك',
    'فانيليا',
  ])) {
    return 'scent_note_catalog_gap';
  }
  if (_isRecommendationLike(text)) {
    return 'mock_catalog_gap';
  }
  return 'policy_review_needed';
}

class _LegacyScenarioAudit {
  _LegacyScenarioAudit._({
    required this.totalPairs,
    required this.totalVariants,
    required this.maxTurns,
    required this.categoryCounts,
    required this.uxRiskCounts,
    required this.sampleFindings,
  });

  final int totalPairs;
  final int totalVariants;
  final int maxTurns;
  final Map<String, int> categoryCounts;
  final Map<String, int> uxRiskCounts;
  final List<_LegacyAuditFinding> sampleFindings;

  static _LegacyScenarioAudit fromPairs(List<_LegacyScenarioPair> pairs) {
    final categoryCounts = <String, int>{};
    final uxRiskCounts = <String, int>{};
    final sampleFindings = <_LegacyAuditFinding>[];

    void bump(Map<String, int> map, String key) {
      map[key] = (map[key] ?? 0) + 1;
    }

    for (final pair in pairs) {
      final text = <String>[
        pair.title,
        pair.whatItTestsEn,
        ...pair.messagesEn,
        ...pair.messagesAr,
      ].join('\n').toLowerCase();
      final categories = _categoriesFor(text);
      final risks = _uxRisksFor(pair, text);

      for (final category in categories) {
        bump(categoryCounts, category);
      }
      for (final risk in risks) {
        bump(uxRiskCounts, risk);
      }
      if ((categories.length > 1 || risks.isNotEmpty) &&
          sampleFindings.length < 60) {
        sampleFindings.add(
          _LegacyAuditFinding(
            index: pair.index,
            title: pair.title,
            categories: categories,
            risks: risks,
            turns: pair.maxTurns,
          ),
        );
      }
    }

    final maxTurns = pairs
        .map((item) => item.maxTurns)
        .reduce((a, b) => a > b ? a : b);
    return _LegacyScenarioAudit._(
      totalPairs: pairs.length,
      totalVariants: pairs.length * 2,
      maxTurns: maxTurns,
      categoryCounts: Map<String, int>.fromEntries(
        categoryCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
      uxRiskCounts: Map<String, int>.fromEntries(
        uxRiskCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
      sampleFindings: sampleFindings,
    );
  }

  static List<String> _categoriesFor(String text) {
    final categories = <String>{};
    if (_hasAny(text, const [
      'prompt injection',
      'system prompt',
      'jailbreak',
      'hidden policy',
    ])) {
      categories.add('safety');
    }
    if (_hasAny(text, const [
      'available',
      'availability',
      'in stock',
      'موجود',
    ])) {
      categories.add('availability');
    }
    if (_hasAny(text, const [
      'sauvage',
      'dior',
      'bleu de chanel',
      'tom ford',
      'external',
    ])) {
      categories.add('external_reference');
    }
    if (_hasAny(text, const ['budget', 'under ', 'egp', 'جنيه', 'ميزاني'])) {
      categories.add('budget');
    }
    if (_hasAny(text, const [
      'compare',
      'difference',
      'which one',
      'قارن',
      'الفرق',
    ])) {
      categories.add('comparison');
    }
    if (_hasAny(text, const ['cheaper', 'أرخص', 'ارخص', 'less expensive'])) {
      categories.add('cheaper_followup');
    }
    if (_hasAny(text, const [
      'summary',
      'recall',
      'remember',
      'فاكر',
      'تلخص',
    ])) {
      categories.add('memory');
    }
    if (_hasAny(text, const [
      'gift',
      'هدية',
      'father',
      'mother',
      'mum',
      'والد',
    ])) {
      categories.add('gift');
    }
    if (_hasAny(text, const [
      'office',
      'university',
      'gym',
      'date',
      'wedding',
      'interview',
      'مكتب',
      'جامعة',
      'جيم',
    ])) {
      categories.add('occasion');
    }
    if (_hasAny(text, const [
      'raw json',
      'percent',
      'percentage',
      'internal field',
    ])) {
      categories.add('ui_rendering');
    }
    if (_hasAny(text, const ['franco', '3ayz', 're7a', 'mixed language'])) {
      categories.add('language_mixed');
    }
    if (_hasAny(text, const [
      'iphone',
      'off-topic',
      'shawarma',
      'gibberish',
      'qwerty',
    ])) {
      categories.add('off_topic_or_noise');
    }
    if (categories.isEmpty) categories.add('general_recommendation');
    return categories.toList()..sort();
  }

  static List<String> _uxRisksFor(_LegacyScenarioPair pair, String text) {
    final risks = <String>{};
    if (pair.whatItTestsEn.toLowerCase().contains('expected to contain:')) {
      risks.add('legacy_exact_text_expectation');
    }
    if (pair.whatItTestsEn.toLowerCase().contains('perform chat interaction')) {
      risks.add('weak_expected_contract');
    }
    if (_hasAny(text, const [
      'percentage',
      'percent',
      'raw json',
      'system prompt',
    ])) {
      risks.add('internal_or_ui_leak_check');
    }
    if (_hasAny(text, const ['perfume', 'budget', 'sweet', 'office']) &&
        _hasAny(text, const ['عطر', 'ميزانية', 'حلو', 'مكتب'])) {
      risks.add('mixed_arabic_english_translation');
    }
    if (pair.maxTurns >= 5) {
      risks.add('long_memory_flow');
    }
    if (_hasAny(text, const [
      'wife will leave',
      'passed away',
      'grief',
      'emotional',
    ])) {
      risks.add('tone_empathy_required');
    }
    if (_hasAny(text, const [
      'under 50',
      'under 200',
      'تحت 200',
      'أقل من 50',
    ])) {
      risks.add('likely_no_match_or_budget_floor');
    }
    return risks.toList()..sort();
  }

  static bool _hasAny(String text, Iterable<String> needles) {
    return needles.any((needle) => text.contains(needle));
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# AI Chat Legacy 488 Scenario Bank Audit')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|---|---:|')
      ..writeln('| scenarioPairs | $totalPairs |')
      ..writeln('| languageVariants | $totalVariants |')
      ..writeln('| maxTurns | $maxTurns |')
      ..writeln()
      ..writeln('## Category Counts')
      ..writeln()
      ..writeln('| Category | Count |')
      ..writeln('|---|---:|');
    for (final entry in categoryCounts.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer
      ..writeln()
      ..writeln('## UX Risk Counts')
      ..writeln()
      ..writeln('| Risk | Count |')
      ..writeln('|---|---:|');
    for (final entry in uxRiskCounts.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer
      ..writeln()
      ..writeln('## Sample Findings')
      ..writeln()
      ..writeln('| # | Title | Turns | Categories | Risks |')
      ..writeln('|---:|---|---:|---|---|');
    for (final finding in sampleFindings) {
      buffer.writeln(
        '| ${finding.index} | ${_md(finding.title)} | ${finding.turns} | '
        '${finding.categories.join(', ')} | ${finding.risks.join(', ')} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Interpretation')
      ..writeln()
      ..writeln(
        '- This is a scenario-bank audit, not proof that all runtime UX is good.',
      )
      ..writeln(
        '- Exact legacy text expectations should be converted to semantic checks.',
      )
      ..writeln(
        '- High-risk groups should be executed in mocked runtime first, then selected real-backend smoke.',
      );
    return buffer.toString();
  }

  String toJson() {
    final payload = <String, Object?>{
      'totalPairs': totalPairs,
      'totalVariants': totalVariants,
      'maxTurns': maxTurns,
      'categoryCounts': categoryCounts,
      'uxRiskCounts': uxRiskCounts,
      'sampleFindings': sampleFindings.map((item) => item.toMap()).toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }

  static String _md(String value) => value.replaceAll('|', r'\|');
}

class _LegacyAuditFinding {
  const _LegacyAuditFinding({
    required this.index,
    required this.title,
    required this.categories,
    required this.risks,
    required this.turns,
  });

  final int index;
  final String title;
  final List<String> categories;
  final List<String> risks;
  final int turns;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'index': index,
      'title': title,
      'categories': categories,
      'risks': risks,
      'turns': turns,
    };
  }
}

class _LegacyRuntimeResult {
  const _LegacyRuntimeResult({
    required this.id,
    required this.pairIndex,
    required this.language,
    required this.title,
    required this.suite,
    required this.turns,
    required this.status,
    required this.messageType,
    required this.source,
    required this.contentPreview,
    required this.productIds,
    required this.productNames,
    required this.elapsedMs,
    required this.issues,
    required this.caveats,
    required this.noMatchTriage,
    required this.eventTypes,
  });

  final String id;
  final int pairIndex;
  final String language;
  final String title;
  final String suite;
  final int turns;
  final String status;
  final String messageType;
  final String? source;
  final String contentPreview;
  final List<String> productIds;
  final List<String> productNames;
  final int elapsedMs;
  final List<String> issues;
  final List<String> caveats;
  final String? noMatchTriage;
  final List<String> eventTypes;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'pairIndex': pairIndex,
      'language': language,
      'title': title,
      'suite': suite,
      'turns': turns,
      'status': status,
      'messageType': messageType,
      'source': source,
      'contentPreview': contentPreview,
      'productIds': productIds,
      'productNames': productNames,
      'elapsedMs': elapsedMs,
      'issues': issues,
      'caveats': caveats,
      'noMatchTriage': noMatchTriage,
      'eventTypes': eventTypes,
    };
  }
}

class _LegacyRuntimeReport {
  _LegacyRuntimeReport._({
    required this.totalVariants,
    required this.completedVariants,
    required this.issueCounts,
    required this.caveatCounts,
    required this.statusCounts,
    required this.languageIssueCounts,
    required this.noMatchTriageCounts,
    required this.previewMojibakeScenarioIds,
    required this.topProblemScenarios,
    required this.avgElapsedMs,
    required this.maxElapsedMs,
  });

  final int totalVariants;
  final int completedVariants;
  final Map<String, int> issueCounts;
  final Map<String, int> caveatCounts;
  final Map<String, int> statusCounts;
  final Map<String, int> languageIssueCounts;
  final Map<String, int> noMatchTriageCounts;
  final List<String> previewMojibakeScenarioIds;
  final List<_LegacyRuntimeResult> topProblemScenarios;
  final double avgElapsedMs;
  final int maxElapsedMs;

  static _LegacyRuntimeReport fromResults(List<_LegacyRuntimeResult> results) {
    final issueCounts = <String, int>{};
    final caveatCounts = <String, int>{};
    final statusCounts = <String, int>{};
    final languageIssueCounts = <String, int>{};
    final noMatchTriageCounts = <String, int>{};

    void bump(Map<String, int> map, String key) {
      map[key] = (map[key] ?? 0) + 1;
    }

    for (final result in results) {
      bump(statusCounts, result.status);
      if (result.issues.isNotEmpty) {
        bump(languageIssueCounts, result.language);
      }
      for (final issue in result.issues) {
        bump(issueCounts, issue.split(':').first);
      }
      for (final caveat in result.caveats) {
        bump(caveatCounts, caveat);
      }
      if (result.noMatchTriage != null) {
        bump(noMatchTriageCounts, result.noMatchTriage!);
      }
    }

    final elapsed = results.map((item) => item.elapsedMs).toList();
    final previewMojibakeScenarioIds = results
        .where((item) => _containsMojibakeMarkers(item.contentPreview))
        .map((item) => item.id)
        .toList(growable: false);
    final topProblems =
        results
            .where((item) => item.issues.isNotEmpty || item.caveats.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final issueCompare = b.issues.length.compareTo(a.issues.length);
            if (issueCompare != 0) return issueCompare;
            return b.caveats.length.compareTo(a.caveats.length);
          });

    return _LegacyRuntimeReport._(
      totalVariants: results.length,
      completedVariants: results.length,
      issueCounts: _sorted(issueCounts),
      caveatCounts: _sorted(caveatCounts),
      statusCounts: _sorted(statusCounts),
      languageIssueCounts: _sorted(languageIssueCounts),
      noMatchTriageCounts: _sorted(noMatchTriageCounts),
      previewMojibakeScenarioIds: previewMojibakeScenarioIds,
      topProblemScenarios: topProblems.take(80).toList(growable: false),
      avgElapsedMs: elapsed.isEmpty
          ? 0
          : elapsed.reduce((a, b) => a + b) / elapsed.length,
      maxElapsedMs: elapsed.isEmpty
          ? 0
          : elapsed.reduce((a, b) => a > b ? a : b),
    );
  }

  static Map<String, int> _sorted(Map<String, int> input) {
    final entries = input.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return Map<String, int>.fromEntries(entries);
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# AI Chat Legacy 976 Runtime UX Audit')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|---|---:|')
      ..writeln('| totalVariants | $totalVariants |')
      ..writeln('| completedVariants | $completedVariants |')
      ..writeln(
        '| variantsWithIssues | ${languageIssueCounts.values.fold<int>(0, (a, b) => a + b)} |',
      )
      ..writeln('| avgElapsedMs | ${avgElapsedMs.toStringAsFixed(1)} |')
      ..writeln('| maxElapsedMs | $maxElapsedMs |')
      ..writeln()
      ..writeln('## Issue Counts')
      ..writeln()
      ..writeln('| Issue | Count |')
      ..writeln('|---|---:|');
    if (issueCounts.isEmpty) {
      buffer.writeln('| none | 0 |');
    } else {
      for (final entry in issueCounts.entries) {
        buffer.writeln('| ${entry.key} | ${entry.value} |');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Caveat Counts')
      ..writeln()
      ..writeln('| Caveat | Count |')
      ..writeln('|---|---:|');
    if (caveatCounts.isEmpty) {
      buffer.writeln('| none | 0 |');
    } else {
      for (final entry in caveatCounts.entries) {
        buffer.writeln('| ${entry.key} | ${entry.value} |');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Status Counts')
      ..writeln()
      ..writeln('| Status | Count |')
      ..writeln('|---|---:|');
    for (final entry in statusCounts.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer
      ..writeln()
      ..writeln('## Language Issue Counts')
      ..writeln()
      ..writeln('| Language | Count |')
      ..writeln('|---|---:|');
    for (final entry in languageIssueCounts.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value} |');
    }
    buffer
      ..writeln()
      ..writeln('## Preview Mojibake Check')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|---|---:|')
      ..writeln(
        '| previewMojibakeScenarioCount | ${previewMojibakeScenarioIds.length} |',
      )
      ..writeln()
      ..writeln('| Scenario ID |')
      ..writeln('|---|');
    if (previewMojibakeScenarioIds.isEmpty) {
      buffer.writeln('| none |');
    } else {
      for (final id in previewMojibakeScenarioIds.take(120)) {
        buffer.writeln('| $id |');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Recommendation No-match Triage')
      ..writeln()
      ..writeln('| Triage Cause | Count |')
      ..writeln('|---|---:|');
    if (noMatchTriageCounts.isEmpty) {
      buffer.writeln('| none | 0 |');
    } else {
      for (final entry in noMatchTriageCounts.entries) {
        buffer.writeln('| ${entry.key} | ${entry.value} |');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Top Problem Scenarios')
      ..writeln()
      ..writeln(
        '| ID | Title | Status | Issues | Caveats | No-match Triage | Preview |',
      )
      ..writeln('|---|---|---|---|---|---|---|');
    for (final result in topProblemScenarios) {
      buffer.writeln(
        '| ${result.id} | ${_md(result.title)} | ${result.status} | '
        '${result.issues.join(', ')} | ${result.caveats.join(', ')} | '
        '${result.noMatchTriage ?? ''} | '
        '${_md(result.contentPreview)} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Ultimate Feedback')
      ..writeln()
      ..writeln(
        '- This mocked runtime validates app-side routing, guards, and rendering behavior over all legacy variants.',
      )
      ..writeln(
        '- It does not prove real LLM quality; selected real-backend smoke is still required for high-risk failures.',
      )
      ..writeln(
        '- The highest-priority fixes are any non-zero issue counts above. Caveats are UX polish or expectation-quality gaps.',
      );
    return buffer.toString();
  }

  String toJson() {
    final payload = <String, Object?>{
      'totalVariants': totalVariants,
      'completedVariants': completedVariants,
      'issueCounts': issueCounts,
      'caveatCounts': caveatCounts,
      'statusCounts': statusCounts,
      'languageIssueCounts': languageIssueCounts,
      'noMatchTriageCounts': noMatchTriageCounts,
      'previewMojibakeScenarioIds': previewMojibakeScenarioIds,
      'avgElapsedMs': avgElapsedMs,
      'maxElapsedMs': maxElapsedMs,
      'topProblemScenarios': topProblemScenarios
          .map((item) => item.toMap())
          .toList(growable: false),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload);
  }

  static String _md(String value) {
    return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
  }
}
