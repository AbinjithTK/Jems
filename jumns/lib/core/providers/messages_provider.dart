import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/api_client.dart';
import '../services/chat_storage_service.dart';
import '../services/ws_chat_service.dart';

/// Messages provider — hybrid REST + WebSocket.
///
/// History loads via REST (/api/messages).
/// Sending uses WebSocket bidi-streaming for real-time token streaming.
/// Falls back to REST POST if WebSocket is not connected.
class MessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final ApiClient _api;
  final WsChatService _ws;
  final ChatStorageService _storage = ChatStorageService();
  StreamSubscription? _wsSub;

  MessagesNotifier(this._api, this._ws) : super(const AsyncValue.data([])) {
    load();
    _listenToWs();
  }

  void _listenToWs() {
    _wsSub = _ws.events.listen((event) {
      if (event.type == 'turn_complete') {
        _onTurnComplete(event);
      }
    });
  }

  /// When the agent finishes a turn, capture the full response as a message.
  void _onTurnComplete(WsChatEvent event) {
    // The stream buffer has the full accumulated text
    final fullText = _ws.streamBuffer;
    if (fullText.isEmpty) return;

    // Use the streaming author tracked by WS service (updated per-token),
    // falling back to event.author, then 'noor'.
    final agent = _ws.streamingAuthor.isNotEmpty
        ? _ws.streamingAuthor
        : (event.author ?? 'noor');

    final aiMsg = Message(
      id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'Jems',
      role: 'assistant',
      type: 'text',
      content: fullText,
      timestamp: _formatTime(DateTime.now()),
      createdAt: DateTime.now(),
      metadata: {'agent': agent},
    );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, aiMsg]);
    _storage.saveMessages(state.valueOrNull ?? []);
  }

  /// Load messages — local cache first, then server sync.
  Future<void> load() async {
    final cached = await _storage.loadMessages();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    try {
      final json = await _api.get('/api/messages');
      if (!mounted) return;
      final list = (json as List<dynamic>)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
      await _storage.saveMessages(list);
    } catch (e) {
      if (!mounted) return;
      if (state is! AsyncData) {
        state = const AsyncValue.data([]);
      }
    }
  }

  /// Send a message — uses WebSocket if connected, REST fallback otherwise.
  Future<Message?> sendChat(String text) async {
    final current = state.valueOrNull ?? [];
    final now = DateTime.now();
    final ts = _formatTime(now);

    // Add user message immediately
    final userMsg = Message(
      id: 'u_${now.millisecondsSinceEpoch}',
      userId: 'local',
      role: 'user',
      type: 'text',
      content: text,
      timestamp: ts,
      createdAt: now,
    );
    state = AsyncValue.data([...current, userMsg]);
    await _storage.saveMessages(state.valueOrNull ?? []);

    // Try WebSocket first
    if (_ws.state == WsChatState.connected) {
      _ws.sendText(text);
      // Response will arrive via _onTurnComplete
      return null;
    }

    // REST fallback
    return _sendViaRest(text);
  }

  Future<Message?> _sendViaRest(String text) async {
    try {
      final recentMessages = (state.valueOrNull ?? [])
          .where((m) => m.content != null && m.content!.isNotEmpty)
          .toList();
      final historyWindow = recentMessages.length > 20
          ? recentMessages.sublist(recentMessages.length - 20)
          : recentMessages;
      final history = historyWindow
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final json = await _api.chatPost('/api/chat', body: {
        'message': text,
        'history': history,
      }, timeout: const Duration(seconds: 120));
      final data = json as Map<String, dynamic>;

      final agentName = data['agent'] as String? ?? 'noor';
      final delegatedTo = data['delegated_to'] as String? ?? data['delegatedTo'] as String?;
      final aiMsg = Message(
        id: data['id'] as String? ?? 'a_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'Jems',
        role: 'assistant',
        type: data['type'] as String? ?? 'text',
        content: data['content'] as String?,
        cardType: data['cardType'] as String?,
        cardData: data['cardData'] as Map<String, dynamic>?,
        timestamp: _formatTime(DateTime.now()),
        createdAt: DateTime.now(),
        metadata: {
          'agent': agentName,
          if (delegatedTo != null) 'delegatedTo': delegatedTo,
        },
      );
      state = AsyncValue.data([...state.valueOrNull ?? [], aiMsg]);
      await _storage.saveMessages(state.valueOrNull ?? []);
      return aiMsg;
    } catch (e) {
      final errMsg = Message(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'Jems',
        role: 'assistant',
        type: 'text',
        content: 'Sorry, I couldn\'t connect right now. Please try again.',
        timestamp: _formatTime(DateTime.now()),
        createdAt: DateTime.now(),
      );
      state = AsyncValue.data([...state.valueOrNull ?? [], errMsg]);
      await _storage.saveMessages(state.valueOrNull ?? []);
      return null;
    }
  }

  /// Send a message with an attached image file.
  Future<Message?> sendChatWithImage(String text, File imageFile) async {
    final current = state.valueOrNull ?? [];
    final now = DateTime.now();
    final ts = _formatTime(now);

    final userMsg = Message(
      id: 'u_${now.millisecondsSinceEpoch}',
      userId: 'local',
      role: 'user',
      type: 'text',
      content: text.isEmpty ? '📎 Image' : text,
      timestamp: ts,
      createdAt: now,
      imageUrl: imageFile.path,
    );
    state = AsyncValue.data([...current, userMsg]);
    await _storage.saveMessages(state.valueOrNull ?? []);

    try {
      final json = await _api.uploadFile(
        '/api/upload',
        file: imageFile,
        fields: {'message': text},
      );
      final data = json as Map<String, dynamic>;
      final response = data['response'] as Map<String, dynamic>?;

      if (response != null) {
        final imgAgent = response['agent'] as String? ?? 'noor';
        final aiMsg = Message(
          id: response['id'] as String? ??
              'a_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'Jems',
          role: 'assistant',
          type: response['type'] as String? ?? 'text',
          content: response['content'] as String?,
          cardType: response['cardType'] as String?,
          cardData: response['cardData'] as Map<String, dynamic>?,
          timestamp: _formatTime(DateTime.now()),
          createdAt: DateTime.now(),
          metadata: {'agent': imgAgent},
        );
        state = AsyncValue.data([...state.valueOrNull ?? [], aiMsg]);
        await _storage.saveMessages(state.valueOrNull ?? []);
        return aiMsg;
      }
      return null;
    } catch (e) {
      final errMsg = Message(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'Jems',
        role: 'assistant',
        type: 'text',
        content: 'Could not upload the file. Please try again.',
        timestamp: _formatTime(DateTime.now()),
        createdAt: DateTime.now(),
      );
      state = AsyncValue.data([...state.valueOrNull ?? [], errMsg]);
      await _storage.saveMessages(state.valueOrNull ?? []);
      return null;
    }
  }

  /// Clear all messages (server + local cache).
  Future<void> clearAll() async {
    try {
      await _api.delete('/api/messages');
    } catch (_) {}
    await _storage.clear();
    state = const AsyncValue.data([]);
  }

  /// Delete a single message by ID (local only).
  void deleteMessage(String id) {
    final current = state.valueOrNull ?? [];
    final updated = current.where((m) => m.id != id).toList();
    state = AsyncValue.data(updated);
    _storage.saveMessages(updated);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

final messagesNotifierProvider =
    StateNotifierProvider<MessagesNotifier, AsyncValue<List<Message>>>((ref) {
  final api = ref.watch(apiClientProvider);
  final ws = ref.watch(wsChatServiceProvider);
  return MessagesNotifier(api, ws);
});

/// Whether the AI is currently processing a response.
final isChatLoadingProvider = StateProvider<bool>((ref) => false);

/// Whether the WebSocket is streaming (agent is typing).
final isStreamingProvider = Provider<bool>((ref) {
  final ws = ref.watch(wsChatServiceProvider);
  return ws.streamBuffer.isNotEmpty;
});
