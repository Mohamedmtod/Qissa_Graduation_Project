import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class ChatMessageBubble extends StatelessWidget {
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  final AIChatMessage message;
  final Widget? recommendationWidget;
  final String? loadingText;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.recommendationWidget,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) {
      return _buildLoadingBubble(context);
    }

    final l10n = AppLocalizations.of(context);
    final isUser = message.isFromUser;
    final isArabic = _containsArabic(message.content);
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isArabic ? TextAlign.right : TextAlign.left;
    final bubbleAlignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: bubbleAlignment,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) _buildBotAvatar(context),
              if (!isUser) const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                        boxShadow: isUser
                            ? []
                            : [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 20),
                        ),
                        border: isUser
                            ? null
                            : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        message.content,
                        textDirection: textDirection,
                        textAlign: textAlign,
                        style: TextStyle(
                          color: isUser
                          ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest
                          : Theme.of(context).colorScheme.onSurface,
                          fontSize: isArabic ? 15.5 : 15,
                          height: isArabic ? 1.58 : 1.42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
              if (isUser) _buildUserAvatar(),
            ],
          ),

          // Display attached product UI if present.
          if (recommendationWidget != null) ...[
            const SizedBox(height: 12),
            recommendationWidget!,
          ],

          // Error styling
          if (message.type == MessageType.error) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 44),
                Icon(Icons.warning_amber_rounded, size: 14, color: red),
                const SizedBox(width: 4),
                Text(
                  l10n.labelChatWarning,
                  style: const TextStyle(fontSize: 12, color: red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(context),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      loadingText ?? l10n.hintAIChatThinking,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: darkGray, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.auto_awesome,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        size: 18,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.person, color: darkGray, size: 20),
    );
  }

  bool _containsArabic(String text) => _arabicRegex.hasMatch(text);
}
