import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Direct Gemini API client — no backend needed.
/// Calls Google's generativeLanguage REST API with the provided API key.
///
/// Pass the key at build time:
///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
class GeminiService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String _model = 'gemini-3-flash-preview';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final http.Client _http;

  /// Conversation history sent with each request so Gemini has context.
  final List<Map<String, dynamic>> _history = [];

  GeminiService({http.Client? client}) : _http = client ?? http.Client();

  static const String _systemPrompt = '''
You are Jems, a warm and encouraging AI life assistant. You help users with:
- Setting and tracking personal goals
- Managing daily tasks and reminders
- Health and wellness check-ins
- Journaling and self-reflection
- Daily briefings and motivation

Keep responses concise, friendly, and actionable. Use a supportive tone.
When the user mentions a goal, task, or reminder, acknowledge it and offer to help track it.
Never use markdown formatting — respond in plain text since this is a mobile chat app.
''';

  /// Send a message and get a response. Maintains conversation history.
  Future<String> chat(String userMessage) async {
    if (_apiKey.isEmpty) {
      throw GeminiException(0, 'GEMINI_API_KEY not set. Pass it via --dart-define=GEMINI_API_KEY=your_key');
    }

    // Add user turn to history
    _history.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    final body = {
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 1024,
      },
    };

    final uri = Uri.parse('$_baseUrl?key=$_apiKey');
    final res = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw GeminiException(res.statusCode, res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiException(0, 'No response from Gemini');
    }

    final parts = (candidates[0]['content']['parts'] as List<dynamic>);
    final text = parts.map((p) => p['text'] as String).join();

    // Add assistant turn to history
    _history.add({
      'role': 'model',
      'parts': [{'text': text}],
    });

    return text;
  }

  /// Clear conversation history (new chat session).
  void clearHistory() => _history.clear();
}

class GeminiException implements Exception {
  final int statusCode;
  final String body;
  GeminiException(this.statusCode, this.body);

  @override
  String toString() => 'GeminiException($statusCode): $body';
}

/// Singleton provider for the Gemini service.
final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
