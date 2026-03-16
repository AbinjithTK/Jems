import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

/// Central API client for the Jems backend.
///
/// Split architecture:
///   API_BASE_URL  → Cloud Run (CRUD, data endpoints)
///   CHAT_BASE_URL → Cloud Run (ADK agents, WebSocket, voice)
///
/// Auth: Firebase ID tokens sent as Bearer tokens.
///
/// Set at build time:
///   flutter run \
///     --dart-define=API_BASE_URL=https://jems-api-xxx.run.app \
///     --dart-define=CHAT_BASE_URL=https://jems-agent-xxx.run.app
class ApiClient {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jumns-backend-dev-ypwmnkarcq-uc.a.run.app',
  );

  /// Separate URL for agent/chat/WebSocket endpoints (Cloud Run).
  /// Falls back to _baseUrl if not set (local dev uses same server).
  static const String _chatBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );

  final http.Client _http;
  final AuthService? _auth;

  ApiClient({AuthService? auth, http.Client? client})
      : _auth = auth,
        _http = client ?? http.Client();

  String get baseUrl => _baseUrl;

  /// The base URL for chat/agent endpoints. Falls back to baseUrl in local dev.
  String get chatBaseUrl => _chatBaseUrl.isNotEmpty ? _chatBaseUrl : _baseUrl;

  /// WebSocket URL for bidi-streaming chat.
  /// Converts https:// to wss:// or http:// to ws://.
  String get wsBaseUrl {
    final base = chatBaseUrl;
    if (base.startsWith('https://')) return base.replaceFirst('https://', 'wss://');
    if (base.startsWith('http://')) return base.replaceFirst('http://', 'ws://');
    return base;
  }

  Future<Map<String, String>> get _headers async {
    final token = _auth != null ? await _auth.getIdToken() : null;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- Generic helpers with retry ---

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _withRetry(() async {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      final res = await _http.get(uri, headers: await _headers);
      return _handleResponse(res);
    });
  }

  Future<dynamic> post(String path, {Object? body, Duration? timeout}) async {
    return _withRetry(() async {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _http.post(uri, headers: await _headers, body: jsonEncode(body));
      return _handleResponse(res);
    }, timeout: timeout);
  }

  /// POST to the chat/agent service (Cloud Run in production, same server locally).
  Future<dynamic> chatPost(String path, {Object? body, Duration? timeout}) async {
    return _withRetry(() async {
      final uri = Uri.parse('$chatBaseUrl$path');
      final res = await _http.post(uri, headers: await _headers, body: jsonEncode(body));
      return _handleResponse(res);
    }, timeout: timeout ?? const Duration(seconds: 120));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _withRetry(() async {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _http.patch(uri, headers: await _headers, body: jsonEncode(body));
      return _handleResponse(res);
    });
  }

  Future<void> delete(String path) async {
    return _withRetry(() async {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _http.delete(uri, headers: await _headers);
      if (res.statusCode != 204 && res.statusCode != 200) {
        throw ApiException(res.statusCode, res.body);
      }
    });
  }

  /// Upload a file via multipart POST. Returns parsed JSON response.
  Future<dynamic> uploadFile(
    String path, {
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    final headers = await _headers;
    headers.remove('Content-Type'); // multipart sets its own
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    if (fields != null) request.fields.addAll(fields);

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  /// Retry up to 2 times on network errors (SocketException, timeout).
  /// Also handles 401 by force-refreshing the Firebase token and retrying once.
  Future<T> _withRetry<T>(Future<T> Function() fn, {int retries = 2, Duration? timeout}) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    bool hasRetried401 = false;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await fn().timeout(effectiveTimeout);
      } on ApiException catch (e) {
        // On 401, force-refresh the Firebase token and retry once
        if (e.statusCode == 401 && !hasRetried401 && _auth != null) {
          hasRetried401 = true;
          await _auth.forceRefreshToken();
          continue;
        }
        rethrow;
      } on SocketException {
        if (attempt == retries) {
          throw ApiException(0, 'No internet connection. Check your network and try again.');
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } on TimeoutException {
        if (attempt == retries) {
          throw ApiException(0, 'Request timed out. Please try again.');
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw ApiException(0, 'Unexpected retry failure');
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Creates ApiClient with AuthService for Firebase ID tokens.
/// In demo/local mode the auth service still exists but tokens will be null,
/// which is fine — the local server ignores Authorization headers.
final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return ApiClient(auth: auth);
});
