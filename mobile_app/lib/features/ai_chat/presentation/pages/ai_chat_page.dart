import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_feedback.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/chat_message_bubble.dart';
import 'package:perfume_app/features/ai_chat/presentation/widgets/recommended_product_card.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final Set<String> _submittedFeedbackMessageIds = <String>{};
  final Set<String> _submittingFeedbackMessageIds = <String>{};
  final Map<String, bool> _feedbackHelpfulByMessage = <String, bool>{};
  final Set<String> _sessionFeedbackPromptedSessionIds = <String>{};
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _isClearingSession = false;
  int _scrollRequestVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    context.read<AIChatCubit>().syncLanguage(
      locale.languageCode == 'en'
          ? AIChatLanguage.english
          : AIChatLanguage.arabic,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    final requestVersion = ++_scrollRequestVersion;
    void scroll() {
      if (requestVersion != _scrollRequestVersion) return;
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    Future.delayed(const Duration(milliseconds: 120), scroll);
    Future.delayed(const Duration(milliseconds: 360), scroll);
    Future.delayed(const Duration(milliseconds: 700), scroll);
  }

  GlobalKey _targetMessageKeyFor(String messageId) {
    return _messageKeys.putIfAbsent(messageId, GlobalKey.new);
  }

  void _pruneMessageKeys(List<AIChatMessage> messages) {
    final activeIds = messages.map((message) => message.id).toSet();
    _messageKeys.removeWhere((messageId, _) => !activeIds.contains(messageId));
  }

  void _scrollToMessage(String messageId) {
    final requestVersion = ++_scrollRequestVersion;
    void scroll() {
      if (requestVersion != _scrollRequestVersion) return;
      if (!mounted) return;
      final context = _messageKeys[messageId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.06,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    Future.delayed(const Duration(milliseconds: 120), scroll);
    Future.delayed(const Duration(milliseconds: 360), scroll);
    Future.delayed(const Duration(milliseconds: 700), scroll);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || text.length > AIChatCubit.maxUserMessageLength) return;

    _messageController.clear();
    context.read<AIChatCubit>().sendMessage(text);
    _scrollToBottom();
  }

  bool _containsArabic(String text) => _arabicRegex.hasMatch(text);

  TextDirection _inputTextDirection(Locale locale) {
    final text = _messageController.text;
    if (text.trim().isNotEmpty) {
      return _containsArabic(text) ? TextDirection.rtl : TextDirection.ltr;
    }
    return locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }

  TextAlign _inputTextAlign(Locale locale) {
    return _inputTextDirection(locale) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
  }

  String _loadingPhaseText(AIChatState state, AppLocalizations l10n) {
    final isArabic = state.language.isArabic;
    return switch (state.loadingPhase) {
      'catalog' =>
        isArabic
            ? 'براجع الكتالوج المتاح...'
            : 'Checking the available catalog...',
      'filtering' =>
        isArabic
            ? 'بفلتر أفضل 15 اختيار حسب طلبك...'
            : 'Filtering the best 15 matches for your request...',
      'worker' =>
        isArabic
            ? 'بجهز الرد النهائي مع مساعد العطور...'
            : 'Preparing the final answer with the perfume assistant...',
      'final_guard' =>
        isArabic
            ? 'بتأكد من الميزانية والحساسية قبل العرض...'
            : 'Checking budget and exclusions before showing results...',
      'analyzing' ||
      _ => isArabic ? 'بحلل تفاصيل طلبك...' : l10n.hintAIChatThinking,
    };
  }

  void _trySendMessage() {
    final state = context.read<AIChatCubit>().state;
    if (state.status == AIChatStatus.loading || state.isInCooldown) {
      _messageFocusNode.requestFocus();
      return;
    }

    _sendMessage();
  }

  Future<void> _submitFeedback({
    required String messageId,
    required bool isHelpful,
    String? note,
    AIChatFeedbackReason? reason,
  }) async {
    if (_submittingFeedbackMessageIds.contains(messageId)) return;
    setState(() {
      _submittingFeedbackMessageIds.add(messageId);
    });

    final success = await context
        .read<AIChatCubit>()
        .submitRecommendationFeedback(
          messageId: messageId,
          isHelpful: isHelpful,
          note: note,
          reason: reason,
        );

    if (!mounted) return;
    setState(() {
      _submittingFeedbackMessageIds.remove(messageId);
      if (success) {
        _submittedFeedbackMessageIds.add(messageId);
        _feedbackHelpfulByMessage[messageId] = isHelpful;
      }
    });

    if (success) {
      final l10n = AppLocalizations.of(context);
      AppSnackBar.showWarning(context, l10n.msgAIChatFeedbackThankYou);
    }
  }

  bool get _showDebugIdAction {
    return !kReleaseMode || AIChatExperimentConfig.turnDebugRemoteEnabled;
  }

  Future<void> _copyChatDebugId() async {
    final status = context.read<AIChatCubit>().chatDebugStatus;
    final chatDebugId = status['chatDebugId']?.toString() ?? '';
    await Clipboard.setData(ClipboardData(text: chatDebugId));
    if (!mounted) return;
    final analytics = status['analyticsEventsEnabled'] == true ? 'ON' : 'OFF';
    final remote = status['turnDebugRemoteEnabled'] == true ? 'ON' : 'OFF';
    final mode = status['debugCaptureMode']?.toString() ?? 'unknown';
    final traces = status['traceCount']?.toString() ?? '0';
    final last = status['lastTurnDebugSendStatus']?.toString() ?? 'unknown';
    final error = status['lastTurnDebugSendError']?.toString();
    final errorSuffix = error == null || error.trim().isEmpty
        ? ''
        : '\nerror=${error.length > 70 ? '${error.substring(0, 70)}...' : error}';
    AppSnackBar.showInfo(
      context,
      'Debug ID copied:\n'
      '$chatDebugId\n'
      'analytics=$analytics remote=$remote mode=$mode traces=$traces last=$last'
      '$errorSuffix',
    );
  }

  /// Translates a scalar product value (season, occasion, note, etc.)
  /// to its display form. Product-data vocabulary kept local - not UI text.
  String _localizeScalarValue(AIChatLanguage language, String value) {
    final normalized = value.trim().toLowerCase();

    if (!language.isArabic) {
      return normalized
          .split('_')
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' ');
    }

    const arabicLabels = <String, String>{
      'men': 'رجالي',
      'women': 'نسائي',
      'unisex': 'للجنسين',
      'summer': 'صيفي',
      'winter': 'شتوي',
      'spring': 'ربيعي',
      'autumn': 'خريفي',
      'all_seasons': 'كل الفصول',
      'daily': 'يومي',
      'university': 'جامعة',
      'office': 'للشغل',
      'formal': 'رسمي',
      'evening': 'سهرة',
      'date': 'مواعدة',
      'casual': 'كاجوال',
      'day': 'نهاري',
      'night': 'ليلي',
      'all_day': 'طوال اليوم',
      'light': 'هادي',
      'medium': 'متوسط',
      'strong': 'قوي',
      'vanilla': 'فانيليا',
      'amber': 'عنبر',
      'musk': 'مسك',
      'oud': 'عود',
      'rose': 'ورد',
      'citrus': 'حمضيات',
      'woody': 'خشبي',
      'floral': 'زهري',
      'spicy': 'تابلي',
      'powdery': 'بودري',
      'fruity': 'فاكهي',
      'leather': 'جلدي',
      'aquatic': 'مائي',
      'sweet': 'حلو',
      'sugary': 'سكري',
      'fresh': 'منعش',
      'clean': 'نظيف',
      'smoky': 'دخاني',
      'musky': 'مسكي',
      'warm': 'دافئ',
      'elegant': 'أنيق',
      'bold': 'جريء',
      'classic': 'كلاسيكي',
      'sporty': 'رياضي',
    };

    return arabicLabels[normalized] ??
        normalized.split('_').where((part) => part.isNotEmpty).join(' ');
  }

  void _addLabeledValueTags({
    required List<String> output,
    required List<String> values,
    required AIChatLanguage language,
    required String prefix,
  }) {
    output.addAll(
      values.map(
        (value) => '$prefix: ${_localizeScalarValue(language, value)}',
      ),
    );
  }

  String _budgetSectionTitle(
    AIChatLanguage language,
    RecommendedBudgetStatus status,
  ) {
    switch (status) {
      case RecommendedBudgetStatus.withinBudget:
        return language.isArabic
            ? 'داخل ميزانيتك'
            : 'Best matches within your budget';
      case RecommendedBudgetStatus.slightlyAboveBudget:
        return language.isArabic
            ? 'أعلى قليلًا من ميزانيتك'
            : 'Slightly above budget, but worth considering';
    }
  }

  Widget _buildRecommendationProductsSection(
    List<RecommendedProduct> products,
  ) {
    if (products.length == 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          child: SizedBox(
            height: 376,
            child: RecommendedProductCard(
              recommendation: products.first,
              displayIndex: 1,
              compact: true,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 376,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => RecommendedProductCard(
        recommendation: products[i],
        displayIndex: i + 1,
        compact: true,
      ),
    );
  }

  Widget _buildRecommendationSections(
    AIChatLanguage language,
    List<RecommendedProduct> products,
  ) {
    final hasBudgetConstraint = products.any((p) => p.exactBudget != null);
    if (!hasBudgetConstraint) {
      return _buildRecommendationProductsSection(products);
    }

    final withinBudget = products
        .where((p) => p.budgetStatus == RecommendedBudgetStatus.withinBudget)
        .toList();
    final slightlyAboveBudget = products
        .where(
          (p) => p.budgetStatus == RecommendedBudgetStatus.slightlyAboveBudget,
        )
        .toList();

    final sections = <Widget>[];
    if (withinBudget.isNotEmpty) {
      sections.add(
        Text(
          _budgetSectionTitle(language, RecommendedBudgetStatus.withinBudget),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
      sections.add(const SizedBox(height: 8));
      sections.add(_buildRecommendationProductsSection(withinBudget));
    }

    if (slightlyAboveBudget.isNotEmpty) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 14));
      }
      sections.add(
        Text(
          _budgetSectionTitle(
            language,
            RecommendedBudgetStatus.slightlyAboveBudget,
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      sections.add(const SizedBox(height: 8));
      sections.add(_buildRecommendationProductsSection(slightlyAboveBudget));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  String _sessionFeedbackText(
    AIChatLanguage language, {
    required String ar,
    required String en,
  }) {
    return language.isArabic ? ar : en;
  }

  bool _shouldPromptSessionFeedback(AIChatCubit cubit) {
    final sessionId = cubit.currentSessionId;
    if (sessionId.trim().isEmpty) return false;
    if (_sessionFeedbackPromptedSessionIds.contains(sessionId)) return false;
    if (cubit.hasSessionFeedbackForSession(sessionId)) return false;
    if (!cubit.hasRecommendationInCurrentSession()) return false;
    return true;
  }

  Future<bool> _maybeRequestSessionFeedback(AIChatCubit cubit) async {
    if (!_shouldPromptSessionFeedback(cubit)) return true;

    final sessionId = cubit.currentSessionId;
    final alreadyPersisted = await cubit.hasPersistedSessionFeedbackForSession(
      sessionId,
    );
    if (alreadyPersisted) {
      _sessionFeedbackPromptedSessionIds.add(sessionId);
      return true;
    }

    final submitted = await _showSessionFeedbackSheet(cubit);
    if (submitted) {
      _sessionFeedbackPromptedSessionIds.add(sessionId);
      return true;
    }

    return false;
  }

  Future<bool> _showSessionFeedbackSheet(AIChatCubit cubit) async {
    final language = cubit.state.language;
    final l10n = AppLocalizations.of(context);

    var selectedRating = 0;
    bool? isHelpful;
    var isSubmitting = false;
    final commentController = TextEditingController();
    var submitted = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Container(
                key: const ValueKey('ai_chat_feedback_sheet'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sessionFeedbackText(
                        language,
                        ar: 'قيّم تجربة الجلسة',
                        en: 'Rate This Session',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sessionFeedbackText(
                        language,
                        ar: 'تقييمك يساعدنا نحسن الترشيحات القادمة.',
                        en: 'Your feedback helps improve future recommendations.',
                      ),
                      style: const TextStyle(fontSize: 13, color: darkGray),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _sessionFeedbackText(
                        language,
                        ar: 'التقييم (1 - 5)',
                        en: 'Rating (1 - 5)',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final isSelected = star <= selectedRating;
                        return IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setSheetState(() {
                                    selectedRating = star;
                                  });
                                },
                          icon: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: isSelected ? Colors.amber : darkGray,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.labelAIChatFeedbackQuestion),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setSheetState(() {
                                      isHelpful = true;
                                    });
                                  },
                            icon: Icon(
                              Icons.thumb_up_alt_outlined,
                              color: isHelpful == true ? Colors.green : null,
                            ),
                            label: Text(l10n.labelFeedbackHelpful),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setSheetState(() {
                                      isHelpful = false;
                                    });
                                  },
                            icon: Icon(
                              Icons.thumb_down_alt_outlined,
                              color: isHelpful == false ? Colors.red : null,
                            ),
                            label: Text(l10n.labelFeedbackNotHelpful),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('ai_chat_feedback_note_field'),
                      controller: commentController,
                      maxLength: 280,
                      minLines: 1,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: l10n.hintFeedbackNote,
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('ai_chat_feedback_submit_button'),
                        onPressed:
                            isSubmitting ||
                                selectedRating == 0 ||
                                isHelpful == null
                            ? null
                            : () async {
                                setSheetState(() {
                                  isSubmitting = true;
                                });
                                final success = await cubit
                                    .submitSessionFeedback(
                                      rating: selectedRating,
                                      isHelpful: isHelpful!,
                                      comment:
                                          commentController.text.trim().isEmpty
                                          ? null
                                          : commentController.text.trim(),
                                    );
                                if (!sheetContext.mounted) return;
                                if (success) {
                                  submitted = true;
                                  Navigator.of(sheetContext).pop();
                                  return;
                                }
                                setSheetState(() {
                                  isSubmitting = false;
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLowest,
                                ),
                              )
                            : Text(
                                _sessionFeedbackText(
                                  language,
                                  ar: 'إرسال تقييم الجلسة',
                                  en: 'Submit Session Feedback',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
    if (!mounted || !submitted) return submitted;
    AppSnackBar.showWarning(
      context,
      _sessionFeedbackText(
        language,
        ar: 'شكرًا، تم حفظ تقييم الجلسة.',
        en: 'Thanks, your session feedback has been saved.',
      ),
    );
    return submitted;
  }

  Future<void> _handleBackNavigation() async {
    final cubit = context.read<AIChatCubit>();
    await _maybeRequestSessionFeedback(cubit);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackNavigation());
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            l10n.labelAIChatTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          actions: [
            if (_showDebugIdAction)
              IconButton(
                key: const ValueKey('ai_chat_copy_debug_id_button'),
                icon: const Icon(Icons.bug_report_outlined, color: darkGray),
                tooltip: 'Copy Debug ID',
                onPressed: _copyChatDebugId,
              ),
            IconButton(
              key: const ValueKey('ai_chat_refresh_button'),
              icon: const Icon(Icons.refresh, color: darkGray),
              tooltip: l10n.tooltipNewChat,
              onPressed: _isClearingSession
                  ? null
                  : () async {
                      final cubit = context.read<AIChatCubit>();
                      setState(() {
                        _isClearingSession = true;
                      });
                      try {
                        // Temporarily disabled during chat testing: do not block
                        // "New Chat" refresh behind the session feedback sheet.
                        // final canProceed = await _maybeRequestSessionFeedback(
                        //   cubit,
                        // );
                        // if (!canProceed) {
                        //   return;
                        // }
                        await cubit.clearSession();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isClearingSession = false;
                          });
                        }
                      }
                    },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildPreferencesBar(),
            BlocBuilder<AIChatCubit, AIChatState>(
              builder: (context, state) {
                if (state.messages.length > 1) {
                  return const SizedBox.shrink();
                }
                return _buildPrivacyDisclosure();
              },
            ),
            Expanded(
              child: BlocConsumer<AIChatCubit, AIChatState>(
                listenWhen: (previous, current) =>
                    previous.messages != current.messages ||
                    previous.status != current.status ||
                    previous.errorMessage != current.errorMessage,
                buildWhen: (previous, current) =>
                    previous.messages != current.messages ||
                    previous.status != current.status ||
                    previous.language != current.language ||
                    previous.loadingPhase != current.loadingPhase,
                listener: (context, state) {
                  final latestMessage = state.messages.isEmpty
                      ? null
                      : state.messages.last;
                  if (latestMessage != null &&
                      latestMessage.isFromBot &&
                      latestMessage.isRecommendation &&
                      latestMessage.recommendedProducts.isNotEmpty) {
                    _scrollToMessage(latestMessage.id);
                  } else {
                    _scrollToBottom();
                  }
                  if (state.messages.length == 1 &&
                      state.messages.first.isFromBot &&
                      !state.messages.first.isRecommendation) {
                    _submittedFeedbackMessageIds.clear();
                    _submittingFeedbackMessageIds.clear();
                    _feedbackHelpfulByMessage.clear();
                  }
                  final message = state.errorMessage;
                  if (message != null && message.trim().isNotEmpty) {
                    AppSnackBar.showInfo(
                      context,
                      resolveUserFacingMessage(
                        context,
                        message,
                        fallback: message,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  final messages = state.messages;
                  _pruneMessageKeys(messages);
                  if (messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        key: ValueKey('ai_chat_initial_loading_spinner'),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      0,
                      16,
                      0,
                      MediaQuery.of(context).padding.bottom + 144,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];

                      Widget? recommendationWidget;
                      if (message.isRecommendation &&
                          message.recommendedProducts.isNotEmpty) {
                        final products = message.recommendedProducts;
                        recommendationWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRecommendationSections(
                              state.language,
                              products,
                            ),
                            const SizedBox(height: 10),
                            _RecommendationFeedbackForm(
                              isSubmitted: _submittedFeedbackMessageIds
                                  .contains(message.id),
                              isSubmitting: _submittingFeedbackMessageIds
                                  .contains(message.id),
                              submittedValue:
                                  _feedbackHelpfulByMessage[message.id],
                              onSubmit: (isHelpful, note, reason) =>
                                  _submitFeedback(
                                    messageId: message.id,
                                    isHelpful: isHelpful,
                                    note: note,
                                    reason: reason,
                                  ),
                            ),
                          ],
                        );
                      } else if (message.isAvailability &&
                          message.recommendedProducts.isNotEmpty) {
                        final product = message.recommendedProducts.first;
                        recommendationWidget = Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.65,
                            ),
                            child: SizedBox(
                              height: 376,
                              child: RecommendedProductCard(
                                recommendation: product,
                                displayIndex: 1,
                                compact: true,
                              ),
                            ),
                          ),
                        );
                      }

                      final bubble = ChatMessageBubble(
                        message: message,
                        loadingText: message.isLoading
                            ? _loadingPhaseText(state, l10n)
                            : null,
                        recommendationWidget: recommendationWidget,
                      );
                      final shouldTrackMessage =
                          message.isFromBot &&
                          message.isRecommendation &&
                          message.recommendedProducts.isNotEmpty &&
                          index == messages.length - 1;

                      return KeyedSubtree(
                        key: ValueKey('chat_message_${message.id}'),
                        child: shouldTrackMessage
                            ? Container(
                                key: _targetMessageKeyFor(message.id),
                                child: bubble,
                              )
                            : bubble,
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyDisclosure() {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        l10n.msgAIChatPrivacyDisclosure,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: darkGray,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPreferencesBar() {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<AIChatCubit, AIChatState>(
      builder: (context, state) {
        final p = state.preferences;
        if (!p.hasSufficientCriteria &&
            p.activeCriteriaCount == 0 &&
            p.gender == null) {
          return const SizedBox.shrink();
        }

        final List<String> tags = [];

        // Gender - UI label from ARB
        if (p.gender != null) {
          tags.add(
            p.gender == 'men'
                ? l10n.labelGenderMen
                : p.gender == 'women'
                ? l10n.labelGenderWomen
                : l10n.labelGenderUnisex,
          );
        }

        // Budget - UI label from ARB
        if (p.maxBudget != null) {
          tags.add(l10n.labelPrefBudgetUnder(p.maxBudget!.toInt()));
        }

        // Prefixed scalars - prefix from ARB, value from product-data vocabulary helper
        if (p.season != null) {
          tags.add(
            '${l10n.labelPrefSeason}: ${_localizeScalarValue(state.language, p.season!)}',
          );
        }
        if (p.occasion != null) {
          tags.add(
            '${l10n.labelPrefOccasion}: ${_localizeScalarValue(state.language, p.occasion!)}',
          );
        }
        if (p.time != null) {
          tags.add(
            '${l10n.labelPrefTime}: ${_localizeScalarValue(state.language, p.time!)}',
          );
        }
        if (p.intensity != null) {
          tags.add(
            '${l10n.labelPrefIntensity}: ${_localizeScalarValue(state.language, p.intensity!)}',
          );
        }

        _addLabeledValueTags(
          output: tags,
          values: p.preferredNotes,
          language: state.language,
          prefix: l10n.labelPrefNote,
        );
        _addLabeledValueTags(
          output: tags,
          values: p.preferredTopNotes,
          language: state.language,
          prefix: l10n.labelPrefTopNote,
        );
        _addLabeledValueTags(
          output: tags,
          values: p.preferredMiddleNotes,
          language: state.language,
          prefix: l10n.labelPrefMiddleNote,
        );
        _addLabeledValueTags(
          output: tags,
          values: p.preferredBaseNotes,
          language: state.language,
          prefix: l10n.labelPrefBaseNote,
        );
        _addLabeledValueTags(
          output: tags,
          values: p.tags.where((tag) => tag != 'open_budget').toList(),
          language: state.language,
          prefix: l10n.labelPrefVibe,
        );
        _addLabeledValueTags(
          output: tags,
          values: p.excludedNotes,
          language: state.language,
          prefix: l10n.labelPrefWithout,
        );

        if (tags.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: tags.map((t) => _buildChip(t)).toList()),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    return BlocBuilder<AIChatCubit, AIChatState>(
      builder: (context, state) {
        final isLoading = state.status == AIChatStatus.loading;
        final trimmedInput = _messageController.text.trim();
        final canSend =
            !isLoading &&
            !state.isInCooldown &&
            trimmedInput.isNotEmpty &&
            trimmedInput.length <= AIChatCubit.maxUserMessageLength;

        final hintText = isLoading
            ? l10n.hintAIChatThinking
            : state.isInCooldown
            ? l10n.hintAIChatCooldown(state.cooldownSecondsRemaining)
            : l10n.hintAIChatInput;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(150),

            boxShadow: [
              BoxShadow(
                color: const Color(0x2A9F8E74),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(-2, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('ai_chat_message_input'),
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: AIChatCubit.maxUserMessageLength,
                  textDirection: _inputTextDirection(locale),
                  textAlign: _inputTextAlign(locale),
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _trySendMessage(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: hintText,
                    hintMaxLines: 1,
                    counterText: '',
                    hintStyle: const TextStyle(
                      color: lightGray,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: canSend
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                child: IconButton(
                  key: const ValueKey('ai_chat_send_button'),
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            key: ValueKey('ai_chat_loading_spinner'),
                            strokeWidth: 2,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          size: 20,
                        ),
                  onPressed: canSend ? _sendMessage : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _RecommendationFeedbackForm - now sources all labels from AppLocalizations
// ---------------------------------------------------------------------------

class _RecommendationFeedbackForm extends StatefulWidget {
  const _RecommendationFeedbackForm({
    required this.isSubmitted,
    required this.isSubmitting,
    required this.onSubmit,
    this.submittedValue,
  });

  final bool isSubmitted;
  final bool isSubmitting;
  final bool? submittedValue;
  final Future<void> Function(
    bool isHelpful,
    String? note,
    AIChatFeedbackReason? reason,
  )
  onSubmit;

  @override
  State<_RecommendationFeedbackForm> createState() =>
      _RecommendationFeedbackFormState();
}

class _RecommendationFeedbackFormState
    extends State<_RecommendationFeedbackForm> {
  final TextEditingController _noteController = TextEditingController();
  AIChatFeedbackReason? _selectedReason;
  bool _showReasonPicker = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submittedValue = widget.submittedValue;
    final language = context.read<AIChatCubit>().state.language;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.labelAIChatFeedbackQuestion,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: (widget.isSubmitted || widget.isSubmitting)
                    ? null
                    : () => widget.onSubmit(
                        true,
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                        null,
                      ),
                icon: Icon(
                  Icons.thumb_up_alt_outlined,
                  color: submittedValue == true ? Colors.green : null,
                ),
                label: Text(l10n.labelFeedbackHelpful),
              ),
              OutlinedButton.icon(
                onPressed: (widget.isSubmitted || widget.isSubmitting)
                    ? null
                    : () {
                        if (_selectedReason == null) {
                          setState(() {
                            _showReasonPicker = true;
                          });
                          return;
                        }
                        widget.onSubmit(
                          false,
                          _noteController.text.trim().isEmpty
                              ? null
                              : _noteController.text.trim(),
                          _selectedReason,
                        );
                      },
                icon: Icon(
                  Icons.thumb_down_alt_outlined,
                  color: submittedValue == false ? Colors.red : null,
                ),
                label: Text(l10n.labelFeedbackNotHelpful),
              ),
              if (widget.isSubmitting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_showReasonPicker &&
              !(widget.isSubmitted || widget.isSubmitting)) ...[
            const SizedBox(height: 8),
            Text(
              _feedbackText(
                language,
                ar: 'إيه المشكلة؟',
                en: 'What was the issue?',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: darkGray,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _feedbackReasonOptions(language)
                  .map((option) {
                    final selected = _selectedReason == option.reason;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(option.label),
                      onSelected: (_) {
                        setState(() {
                          _selectedReason = option.reason;
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            enabled: !(widget.isSubmitted || widget.isSubmitting),
            maxLength: 280,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.hintFeedbackNote,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          if (widget.isSubmitted) ...[
            const SizedBox(height: 6),
            Text(
              l10n.msgFeedbackSaved,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _feedbackText(
    AIChatLanguage language, {
    required String ar,
    required String en,
  }) {
    return language == AIChatLanguage.english ? en : ar;
  }

  static List<_FeedbackReasonOption> _feedbackReasonOptions(
    AIChatLanguage language,
  ) {
    return [
      _FeedbackReasonOption(
        AIChatFeedbackReason.wrongRecommendation,
        _feedbackText(
          language,
          ar: 'الترشيحات مش مناسبة',
          en: 'Wrong recommendation',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.wrongGender,
        _feedbackText(
          language,
          ar: 'مش مناسب للنوع المطلوب',
          en: 'Wrong gender fit',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.wrongOccasion,
        _feedbackText(
          language,
          ar: 'مش مناسب للمناسبة',
          en: 'Wrong occasion fit',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.tooExpensive,
        _feedbackText(language, ar: 'غالي', en: 'Too expensive'),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.notSimilar,
        _feedbackText(
          language,
          ar: 'مش شبه اللي طلبته',
          en: 'Not similar enough',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.repeatedProducts,
        _feedbackText(
          language,
          ar: 'نفس المنتجات اتكررت',
          en: 'Repeated products',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.confusingAnswer,
        _feedbackText(language, ar: 'الرد غير واضح', en: 'Confusing answer'),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.slowResponse,
        _feedbackText(language, ar: 'الرد بطيء', en: 'Slow response'),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.externalLookupWrong,
        _feedbackText(
          language,
          ar: 'مشكلة في عطر خارجي',
          en: 'External perfume issue',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.availabilityWrong,
        _feedbackText(
          language,
          ar: 'التوفر أو السعر غير صحيح',
          en: 'Availability or price issue',
        ),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.badArabic,
        _feedbackText(language, ar: 'العربي سيئ', en: 'Bad Arabic'),
      ),
      _FeedbackReasonOption(
        AIChatFeedbackReason.other,
        _feedbackText(language, ar: 'مشكلة أخرى', en: 'Other'),
      ),
    ];
  }
}

class _FeedbackReasonOption {
  const _FeedbackReasonOption(this.reason, this.label);

  final AIChatFeedbackReason reason;
  final String label;
}
