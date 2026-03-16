import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// Social connection model.
class SocialConnection {
  final String connectionId;
  final String friendUserId;
  final String friendDisplayName;
  final String friendAgentCardUrl;
  final String status;
  final String createdAt;

  const SocialConnection({
    required this.connectionId,
    required this.friendUserId,
    this.friendDisplayName = '',
    this.friendAgentCardUrl = '',
    this.status = 'pending',
    this.createdAt = '',
  });

  factory SocialConnection.fromJson(Map<String, dynamic> json) => SocialConnection(
        connectionId: json['connectionId'] as String? ?? '',
        friendUserId: json['friendUserId'] as String? ?? '',
        friendDisplayName: json['friendDisplayName'] as String? ?? '',
        friendAgentCardUrl: json['friendAgentCardUrl'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        createdAt: json['createdAt'] as String? ?? '',
      );

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}

/// Social connections state notifier.
class ConnectionsNotifier extends StateNotifier<AsyncValue<List<SocialConnection>>> {
  final ApiClient _api;
  ConnectionsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/api/connections');
      final list = (res['connections'] as List)
          .map((e) => SocialConnection.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> sendRequest({required String friendUserId, String displayName = '', String agentCardUrl = ''}) async {
    try {
      await _api.post('/api/connections/request', body: {
        'friendUserId': friendUserId,
        'friendDisplayName': displayName,
        'agentCardUrl': agentCardUrl,
      });
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept(String connectionId) async {
    try {
      await _api.post('/api/connections/$connectionId/accept');
      await load();
    } catch (_) {}
  }

  Future<void> reject(String connectionId) async {
    try {
      await _api.post('/api/connections/$connectionId/reject');
      await load();
    } catch (_) {}
  }

  Future<void> remove(String connectionId) async {
    try {
      await _api.delete('/api/connections/$connectionId');
      await load();
    } catch (_) {}
  }

  Future<String?> getMyAgentCardUrl() async {
    try {
      final res = await _api.get('/api/connections/agent-card');
      return res['agentCardUrl'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final connectionsNotifierProvider =
    StateNotifierProvider<ConnectionsNotifier, AsyncValue<List<SocialConnection>>>((ref) {
  return ConnectionsNotifier(ref.watch(apiClientProvider));
});
