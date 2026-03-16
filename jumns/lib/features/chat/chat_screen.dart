import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/message.dart';
import '../../core/providers/messages_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/reminders_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/jems_colors.dart';
import 'widgets/agent_header.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';
import 'cards/card_renderer.dart';
import '../../core/models/agent_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesNotifierProvider);
    final isLoading = ref.watch(isChatLoadingProvider);
    final settingsAsync = ref.watch(userSettingsNotifierProvider);
    final agentName = settingsAsync.valueOrNull?.agentName ?? 'Jems';

    return Column(
      children: [
        AgentHeader(
          agentName: agentName,
          status: isLoading ? 'Sketching...' : 'Ready',
        ),
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48,
                      color: JemsColors.ink.withAlpha(120)),
                  const SizedBox(height: 12),
                  Text('Could not connect to server',
                      style: GoogleFonts.architectsDaughter(
                        color: JemsColors.ink.withAlpha(150),
                      )),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(messagesNotifierProvider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (messages) => messages.isEmpty
                ? _EmptyChat()
                : _ChatList(messages: messages, isThinking: isLoading),
          ),
        ),
        Composer(
          onSend: _sendMessage,
          onSendImage: _sendImageMessage,
          isDisabled: isLoading,
        ),
      ],
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    ref.read(isChatLoadingProvider.notifier).state = true;
    try {
      await ref.read(messagesNotifierProvider.notifier).sendChat(text);
    } finally {
      if (!_disposed) {
        ref.read(isChatLoadingProvider.notifier).state = false;
        ref.read(goalsNotifierProvider.notifier).load();
        ref.read(tasksNotifierProvider.notifier).load();
        ref.read(remindersNotifierProvider.notifier).load();
      }
    }
  }

  Future<void> _sendImageMessage(File image, String text) async {
    ref.read(isChatLoadingProvider.notifier).state = true;
    try {
      await ref
          .read(messagesNotifierProvider.notifier)
          .sendChatWithImage(text, image);
    } finally {
      if (!_disposed) {
        ref.read(isChatLoadingProvider.notifier).state = false;
        ref.read(goalsNotifierProvider.notifier).load();
        ref.read(tasksNotifierProvider.notifier).load();
        ref.read(remindersNotifierProvider.notifier).load();
      }
    }
  }
}

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48,
              color: JemsColors.ink.withAlpha(100)),
          const SizedBox(height: 16),
          Text('Start a conversation',
              style: GoogleFonts.architectsDaughter(
                color: JemsColors.ink.withAlpha(150),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<Message> messages;
  final bool isThinking;

  const _ChatList({required this.messages, required this.isThinking});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + (isThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: JemsColors.charcoal,
                    )),
                SizedBox(width: 8),
                Text('Sketching...',
                    style: TextStyle(color: JemsColors.ink,
                        fontSize: 13)),
              ],
            ),
          );
        }

        final msg = messages[index];
        final widgets = <Widget>[];

        // Agent label for assistant messages
        if (msg.isAssistant &&
            (index == 0 || messages[index - 1].isUser)) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 8),
            child: Text(
              'JEMS ${msg.timestamp}',
              style: GoogleFonts.architectsDaughter(
                color: JemsColors.ink.withAlpha(150),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ));
        }

        // Render card or text
        if (msg.isCard && msg.cardData != null) {
          final card = AgentCard.fromJson({
            'type': _mapCardType(msg.cardType!),
            ...msg.cardData!,
          });
          if (card != null) {
            widgets.add(CardRenderer(card: card));
          }
          // Also show text content if present alongside card
          if (msg.content != null && msg.content!.isNotEmpty) {
            widgets.add(MessageBubble(text: msg.content!, isUser: false));
          }
        } else if (msg.content != null && msg.content!.isNotEmpty) {
          widgets.add(
              MessageBubble(
                text: msg.content!,
                isUser: msg.isUser,
                imageUrl: msg.imageUrl,
              ));
        } else if (msg.hasImage) {
          widgets.add(
              MessageBubble(
                text: '',
                isUser: msg.isUser,
                imageUrl: msg.imageUrl,
              ));
        }

        return Column(
          crossAxisAlignment:
              msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: widgets,
        );
      },
    );
  }

  /// Map backend card types to our AgentCard type keys.
  String _mapCardType(String backendType) => switch (backendType) {
        'briefing' => 'daily_briefing',
        'health' => 'health_snapshot',
        'goal' || 'goal_check_in' => 'goal_check_in',
        'reminder' => 'reminder',
        'journal' || 'journal_prompt' => 'journal_prompt',
        'insight' || 'proactive' => 'insight',
        _ => backendType,
      };
}
