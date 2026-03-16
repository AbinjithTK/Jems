import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// Voice session state exposed to UI.
enum VoiceSessionState { idle, connecting, listening, agentSpeaking, error }

/// A single voice event from the agent.
class VoiceEvent {
  final String type; // "audio", "text", "turn_complete", "error"
  final String? text;
  final String? author;
  final Uint8List? audioData;
  final String? mimeType;
  final String? error;

  const VoiceEvent({
    required this.type,
    this.text,
    this.author,
    this.audioData,
    this.mimeType,
    this.error,
  });
}

/// Manages Gemini Live voice sessions over WebSocket.
///
/// Flow:
/// 1. [startSession] opens WS to backend with voice=true + agent name
/// 2. Records PCM audio from mic, sends as base64 chunks
/// 3. Receives audio/text events from agent, emits via [events] stream
/// 4. [endSession] stops recording and closes WS
class VoiceService extends ChangeNotifier {
  final String _wsBaseUrl;
  final AuthService? _auth;

  WebSocketChannel? _channel;
  AudioRecorder? _recorder;
  StreamSubscription? _recorderSub;
  StreamSubscription? _wsSub;

  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionState get state => _state;

  String _currentAgent = 'green';
  String get currentAgent => _currentAgent;

  final _eventsController = StreamController<VoiceEvent>.broadcast();
  Stream<VoiceEvent> get events => _eventsController.stream;

  VoiceService({required String wsBaseUrl, AuthService? auth})
      : _wsBaseUrl = wsBaseUrl,
        _auth = auth;

  /// Map frontend color names to backend agent names.
  static const _colorToBackendName = {
    'green': 'noor',
    'yellow': 'kai',
    'pink': 'sage',
    'violet': 'echo',
  };

  /// Start a voice session for the given agent.
  Future<void> startSession({
    required String userId,
    required String agentName,
    bool sendHi = false,
  }) async {
    if (_state != VoiceSessionState.idle) return;

    _currentAgent = agentName;
    _setState(VoiceSessionState.connecting);

    // Map color to backend name (noor/kai/sage/echo)
    final backendName = _colorToBackendName[agentName] ?? 'noor';

    try {
      // Build WebSocket URL with auth token
      final sessionId = const Uuid().v4();
      var wsUrl = '$_wsBaseUrl/api/ws/chat/$userId/$sessionId'
          '?agent=$backendName&voice=true';

      // Attach Firebase ID token for server-side auth validation
      final token = _auth != null ? await _auth.getIdToken() : null;
      if (token != null) {
        wsUrl += '&token=$token';
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      // Listen for downstream events
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          _eventsController.add(VoiceEvent(type: 'error', error: e.toString()));
          _setState(VoiceSessionState.error);
        },
        onDone: () {
          if (_state != VoiceSessionState.idle) {
            _setState(VoiceSessionState.idle);
          }
        },
      );

      // Start recording PCM audio
      _recorder = AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        _eventsController.add(
          const VoiceEvent(type: 'error', error: 'Microphone permission denied'),
        );
        await endSession();
        return;
      }

      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
      );

      _recorderSub = stream.listen((data) {
        if (_channel != null && data.isNotEmpty) {
          final b64 = base64Encode(data);
          _channel!.sink.add(jsonEncode({
            'type': 'audio',
            'data': b64,
            'mimeType': 'audio/pcm;rate=16000',
          }));
        }
      });

      _setState(VoiceSessionState.listening);

      // Auto-send "hi" to kick off the conversation
      if (sendHi && _channel != null) {
        _channel!.sink.add(jsonEncode({
          'type': 'text',
          'text': 'hi',
        }));
      }
    } catch (e) {
      _eventsController.add(VoiceEvent(type: 'error', error: e.toString()));
      _setState(VoiceSessionState.error);
      await endSession();
    }
  }

  /// End the current voice session.
  Future<void> endSession() async {
    // Stop recording
    await _recorderSub?.cancel();
    _recorderSub = null;
    if (_recorder != null) {
      try {
        await _recorder!.stop();
      } catch (_) {}
      _recorder!.dispose();
      _recorder = null;
    }

    // Close WebSocket
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

    _setState(VoiceSessionState.idle);
  }

  void _onWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? 'event';

      switch (type) {
        case 'audio':
          final b64 = msg['data'] as String?;
          final audioBytes = b64 != null ? base64Decode(b64) : null;
          _eventsController.add(VoiceEvent(
            type: 'audio',
            author: msg['author'] as String?,
            audioData: audioBytes != null ? Uint8List.fromList(audioBytes) : null,
            mimeType: msg['mimeType'] as String? ?? 'audio/pcm',
          ));
          _setState(VoiceSessionState.agentSpeaking);

        case 'event':
          _eventsController.add(VoiceEvent(
            type: 'text',
            text: msg['text'] as String?,
            author: msg['author'] as String?,
          ));

        case 'turn_complete':
          _eventsController.add(VoiceEvent(
            type: 'turn_complete',
            author: msg['author'] as String?,
          ));
          if (_state == VoiceSessionState.agentSpeaking) {
            _setState(VoiceSessionState.listening);
          }

        case 'error':
          _eventsController.add(VoiceEvent(
            type: 'error',
            error: msg['error'] as String? ?? msg['errorMessage'] as String?,
          ));

        default:
          break;
      }
    } catch (e) {
      debugPrint('VoiceService: failed to parse WS message: $e');
    }
  }

  void _setState(VoiceSessionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    endSession();
    _eventsController.close();
    super.dispose();
  }
}

/// Provider for the voice service singleton.
final voiceServiceProvider = ChangeNotifierProvider<VoiceService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final auth = ref.watch(authServiceProvider);
  return VoiceService(wsBaseUrl: apiClient.wsBaseUrl, auth: auth);
});
