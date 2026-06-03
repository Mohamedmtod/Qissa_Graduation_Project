import 'dart:async';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';

bool isOpeningWelcomeMessage(AIChatMessage message) {
  final content = message.content.trim();
  return content == buildWelcomeText(AIChatLanguage.arabic) ||
      content == buildWelcomeText(AIChatLanguage.english);
}

List<AIChatMessage> pruneBotHistoryForFreshTurn(
  List<AIChatMessage> messages, {
  required bool enabled,
}) {
  return messages;
}

List<AIChatMessage> localizedOpeningMessages(
  List<AIChatMessage> messages,
  AIChatLanguage language,
) {
  if (messages.length != 1) return messages;
  final first = messages.first;
  if (!first.isFromBot || !isOpeningWelcomeMessage(first)) {
    return messages;
  }
  return <AIChatMessage>[AIChatMessage.botText(buildWelcomeText(language))];
}

void sendWelcomeMessage({
  required AIChatState Function() getState,
  required void Function(AIChatState state) emitState,
}) {
  final currentState = getState();
  emitState(
    currentState.copyWith(
      messages: [
        AIChatMessage.botText(buildWelcomeText(currentState.language)),
      ],
    ),
  );
}

Timer startCooldownTimer({
  required Timer? existingTimer,
  required Duration cooldownDuration,
  required AIChatState Function() getState,
  required void Function(AIChatState state) emitState,
  required bool Function() isClosed,
}) {
  existingTimer?.cancel();

  var secondsRemaining = cooldownDuration.inSeconds;
  emitState(getState().copyWith(cooldownSecondsRemaining: secondsRemaining));

  return Timer.periodic(const Duration(seconds: 1), (timer) {
    if (isClosed()) {
      timer.cancel();
      return;
    }

    secondsRemaining -= 1;
    if (secondsRemaining <= 0) {
      emitState(getState().copyWith(cooldownSecondsRemaining: 0));
      timer.cancel();
      return;
    }

    emitState(getState().copyWith(cooldownSecondsRemaining: secondsRemaining));
  });
}

void pruneRequestWindow(
  List<int> requestTimestampsMs,
  int nowMs,
  Duration rateLimitWindow,
) {
  requestTimestampsMs.removeWhere(
    (timestamp) => nowMs - timestamp >= rateLimitWindow.inMilliseconds,
  );
}
