import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import 'tasks_provider.dart';
import 'reminders_provider.dart';
import 'goals_provider.dart';
import 'messages_provider.dart';

/// A single agent chat message (user or assistant).
class AgentChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final String? cardType;
  final Map<String, dynamic>? cardData;
  final DateTime timestamp;

  const AgentChatMessage({
    required this.role,
    required this.content,
    this.cardType,
    this.cardData,
    required this.timestamp,
  });
}

/// State for a per-agent chat session.
class AgentChatState {
  final List<AgentChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AgentChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AgentChatState copyWith({
    List<AgentChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) =>
      AgentChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Notifier that manages chat with a specific agent via REST.
/// After each agent response, auto-refreshes the relevant data providers.
class AgentChatNotifier extends StateNotifier<AgentChatState> {
  final ApiClient _api;
  final String agentName;
  final Ref _ref;

  AgentChatNotifier(this._api, this.agentName, this._ref)
      : super(const AgentChatState());

  /// Send a message to this agent and get a response.
  Future<String?> send(String text) async {
    if (text.trim().isEmpty) return null;

    // Add user message
    final userMsg = AgentChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      // Build history window (last 10 messages)
      final historyWindow = state.messages.length > 10
          ? state.messages.sublist(state.messages.length - 10)
          : state.messages;
      final history = historyWindow
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final json = await _api.chatPost(
        '/api/chat/agent/$agentName',
        body: {'message': text, 'history': history},
        timeout: const Duration(seconds: 120),
      );
      final data = json as Map<String, dynamic>;

      final aiMsg = AgentChatMessage(
        role: 'assistant',
        content: data['content'] as String? ?? '',
        cardType: data['card_type'] as String? ?? data['cardType'] as String?,
        cardData: data['card_data'] as Map<String, dynamic>? ??
            data['cardData'] as Map<String, dynamic>?,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );

      // Auto-refresh relevant providers based on agent
      _refreshProviders();

      return aiMsg.content;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.body);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not reach $agentName. Try again.',
      );
      return null;
    }
  }

  void _refreshProviders() {
    switch (agentName) {
      case 'kai':
        _ref.read(tasksNotifierProvider.notifier).load();
        _ref.read(remindersNotifierProvider.notifier).load();
        _ref.read(goalsNotifierProvider.notifier).load();
      case 'sage':
        _ref.read(goalsNotifierProvider.notifier).load();
      case 'echo':
        _ref.read(messagesNotifierProvider.notifier).load();
      default:
        break;
    }
  }

  void clearChat() => state = const AgentChatState();
}

/// Family provider — one chat notifier per agent name.
final agentChatProvider = StateNotifierProvider.family<
    AgentChatNotifier, AgentChatState, String>(
  (ref, agentName) {
    final api = ref.watch(apiClientProvider);
    return AgentChatNotifier(api, agentName, ref);
  },
);
