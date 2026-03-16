import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// MCP server model.
class McpServer {
  final String serverId;
  final String name;
  final String description;
  final String connectionType;
  final Map<String, dynamic> config;
  final bool enabled;
  final bool builtin;

  const McpServer({
    required this.serverId,
    required this.name,
    this.description = '',
    this.connectionType = 'stdio',
    this.config = const {},
    this.enabled = true,
    this.builtin = false,
  });

  factory McpServer.fromJson(Map<String, dynamic> json) => McpServer(
        serverId: json['serverId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        connectionType: json['connectionType'] as String? ?? 'stdio',
        config: json['config'] as Map<String, dynamic>? ?? {},
        enabled: json['enabled'] as bool? ?? true,
        builtin: json['builtin'] as bool? ?? false,
      );
}

/// Validation result from the backend.
class McpValidationResult {
  final bool valid;
  final List<String> errors;
  final Map<String, dynamic>? parsed;

  const McpValidationResult({this.valid = false, this.errors = const [], this.parsed});
}

/// MCP servers state notifier.
class McpNotifier extends StateNotifier<AsyncValue<List<McpServer>>> {
  final ApiClient _api;
  McpNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/api/mcp/servers');
      final list = (res['servers'] as List)
          .map((e) => McpServer.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<McpValidationResult> validate(String rawJson) async {
    try {
      final res = await _api.post('/api/mcp/servers/validate', body: {'raw_json': rawJson});
      return McpValidationResult(valid: true, parsed: res['parsed'] as Map<String, dynamic>?);
    } on ApiException catch (e) {
      try {
        final body = jsonDecode(e.body) as Map<String, dynamic>;
        final errors = (body['errors'] as List?)?.cast<String>() ?? [body['error']?.toString() ?? 'Unknown error'];
        return McpValidationResult(errors: errors);
      } catch (_) {
        return McpValidationResult(errors: [e.body]);
      }
    }
  }

  Future<bool> addServer(String rawJson) async {
    try {
      await _api.post('/api/mcp/servers', body: {'raw_json': rawJson});
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleServer(String serverId, bool enabled) async {
    try {
      await _api.post('/api/mcp/servers/$serverId/toggle', body: {'enabled': enabled});
      await load();
    } catch (_) {}
  }

  Future<void> deleteServer(String serverId) async {
    try {
      await _api.delete('/api/mcp/servers/$serverId');
      await load();
    } catch (_) {}
  }

  /// Update the auth token for a built-in MCP server (e.g. Notion).
  Future<bool> updateToken(String serverId, String token) async {
    try {
      await _api.post('/api/mcp/servers/$serverId/token', body: {'token': token});
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check if a built-in server has a configured token.
  bool hasToken(McpServer server) {
    final env = server.config['env'] as Map<String, dynamic>?;
    if (env == null) return false;
    // Check common token keys
    for (final key in ['NOTION_TOKEN', 'TOKEN']) {
      final val = env[key];
      if (val is String && val.isNotEmpty) return true;
    }
    return false;
  }
}

final mcpNotifierProvider = StateNotifierProvider<McpNotifier, AsyncValue<List<McpServer>>>((ref) {
  return McpNotifier(ref.watch(apiClientProvider));
});
