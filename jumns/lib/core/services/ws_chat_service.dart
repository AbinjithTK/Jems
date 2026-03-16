import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../providers/demo_mode_provider.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Connection state for the WebSocket chat.
enum WsChatState { disconnected, connecting, connected, error }

/// A streaming event from the agent over WebSocket.
class WsChatEvent {
  final String type; // "event", "turn_complete", "tool_call", "error"
  final String? text;
  final String? author;
  final String? cardType;
  final Map<String, dynamic>? cardData;
  final Map<String, dynamic>? navigation;
  final String? error;

  const WsChatEvent({
    required this.type,
    this.text,
    this.author,
    this.cardType,
    this.cardData,
    this.navigation,
    this.error,
  });
}

/// WebSocket chat service for real-time bidi-streaming with the backend.
///
/// Connects to /api/ws/chat/{userId}/{sessionId}?agent=noor
/// Sends: {"type": "text", "text": "..."}
/// Receives: {"type": "event", "text": "...", "author": "noor"}
///           {"type": "turn_complete", "author": "noor"}
class WsChatService extends ChangeNotifier {
  final String _wsBaseUrl;
  final AuthService? _auth;

  /// When true, appends &demo=true instead of &token=<firebase_token>.
  bool _demoMode = false;
  set demoMode(bool v) => _demoMode = v;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  String _sessionId = '';

  WsChatState _state = WsChatState.disconnected;
  WsChatState get state => _state;

  String _currentAgent = 'noor';
  String get currentAgent => _currentAgent;

  /// The agent currently producing streamed tokens (may differ from _currentAgent
  /// when Noor delegates mid-turn).
  String _streamingAuthor = 'noor';
  String get streamingAuthor => _streamingAuthor;

  /// Accumulated text for the current agent turn (streamed token by token).
  String _streamBuffer = '';
  String get streamBuffer => _streamBuffer;

  // Reconnection state
  String? _lastUserId;
  String _lastAgentName = 'noor';
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _eventsController = StreamController<WsChatEvent>.broadcast();
  Stream<WsChatEvent> get events => _eventsController.stream;

  WsChatService({required String wsBaseUrl, AuthService? auth})
      : _wsBaseUrl = wsBaseUrl,
        _auth = auth;

  /// Connect to the WebSocket chat endpoint.
  Future<void> connect({
    required String userId,
    String agentName = 'noor',
  }) async {
    if (_state == WsChatState.connected || _state == WsChatState.connecting) {
      return;
    }

    // Store connect params for reconnection with fresh token
    _lastUserId = userId;
    _lastAgentName = agentName;

    _currentAgent = agentName;
    _setState(WsChatState.connecting);

    try {
      _sessionId = const Uuid().v4();
      var wsUrl = '$_wsBaseUrl/api/ws/chat/$userId/$_sessionId?agent=$agentName';

      if (_demoMode) {
        wsUrl += '&demo=true';
      } else {
        // Always fetch a fresh Firebase ID token at connect time
        final token = _auth != null ? await _auth.getIdToken() : null;
        if (token != null) {
          wsUrl += '&token=$token';
        }
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _reconnectAttempts = 0; // Reset on successful connect

      _wsSub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          _eventsController.add(WsChatEvent(type: 'error', error: e.toString()));
          _setState(WsChatState.error);
          _tryReconnect();
        },
        onDone: () {
          if (_state != WsChatState.disconnected) {
            _setState(WsChatState.disconnected);
            _tryReconnect();
          }
        },
      );

      _setState(WsChatState.connected);
    } catch (e) {
      _eventsController.add(WsChatEvent(type: 'error', error: e.toString()));
      _setState(WsChatState.error);
      _tryReconnect();
    }
  }

  /// Attempt to reconnect with exponential backoff and a fresh token.
  void _tryReconnect() {
    if (_lastUserId == null || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    debugPrint('WsChatService: reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    Future.delayed(delay, () {
      if (_state != WsChatState.connected) {
        connect(userId: _lastUserId!, agentName: _lastAgentName);
      }
    });
  }

  /// Send a text message over the WebSocket.
  void sendText(String text) {
    if (_channel == null || _state != WsChatState.connected) return;
    _streamBuffer = '';
    _streamingAuthor = _currentAgent;
    notifyListeners();
    _channel!.sink.add(jsonEncode({'type': 'text', 'text': text}));
  }

  /// Disconnect gracefully.
  Future<void> disconnect() async {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'close'}));
      } catch (_) {}
      try {
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }
    await _wsSub?.cancel();
    _wsSub = null;
    _streamBuffer = '';
    _reconnectAttempts = 0;
    _lastUserId = null;
    _setState(WsChatState.disconnected);
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? 'event';

      switch (type) {
        case 'event':
          final text = msg['text'] as String?;
          final author = msg['author'] as String?;
          if (author != null && author.isNotEmpty) {
            _streamingAuthor = author;
          }
          if (text != null && text.isNotEmpty) {
            _streamBuffer += text;
            notifyListeners();
          }
          _eventsController.add(WsChatEvent(
            type: 'event',
            text: text,
            author: msg['author'] as String?,
            cardType: msg['cardType'] as String?,
            cardData: msg['cardData'] as Map<String, dynamic>?,
            navigation: msg['navigation'] as Map<String, dynamic>?,
          ));

        case 'turn_complete':
          _eventsController.add(WsChatEvent(
            type: 'turn_complete',
            author: msg['author'] as String?,
          ));
          // Reset buffer after turn completes — the provider will
          // have already captured the full text.
          _streamBuffer = '';
          notifyListeners();

        case 'tool_call':
          _eventsController.add(WsChatEvent(
            type: 'tool_call',
            text: msg.toString(),
            author: msg['author'] as String?,
          ));

        case 'error':
          _eventsController.add(WsChatEvent(
            type: 'error',
            error: msg['error'] as String? ?? 'Unknown error',
          ));

        default:
          break;
      }
    } catch (e) {
      debugPrint('WsChatService: parse error: $e');
    }
  }

  void _setState(WsChatState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    _eventsController.close();
    super.dispose();
  }
}

/// Provider for the WebSocket chat service.
/// In demo mode, sends &demo=true instead of Firebase token.
final wsChatServiceProvider = ChangeNotifierProvider<WsChatService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authServiceProvider);
  final isDemoMode = ref.watch(demoModeProvider);
  final svc = WsChatService(wsBaseUrl: apiClient.wsBaseUrl, auth: auth);
  svc.demoMode = isDemoMode;
  return svc;
});
