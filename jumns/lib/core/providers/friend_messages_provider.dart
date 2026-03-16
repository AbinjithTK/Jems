import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// A single DM between friends.
class FriendMessage {
  final String id;
  final String userId;
  final String connectionId;
  final String friendUserId;
  final String senderUserId;
  final String content;
  final String type;
  final String createdAt;

  const FriendMessage({
    required this.id,
    required this.userId,
    required this.connectionId,
    required this.friendUserId,
    required this.senderUserId,
    this.content = '',
    this.type = 'text',
    this.createdAt = '',
  });

  factory FriendMessage.fromJson(Map<String, dynamic> json) => FriendMessage(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        connectionId: json['connectionId'] as String? ?? '',
        friendUserId: json['friendUserId'] as String? ?? '',
        senderUserId: json['senderUserId'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        createdAt: json['createdAt'] as String? ?? '',
      );

  bool get isMe => senderUserId == userId;
}

/// Notifier for a single connection's message thread.
class FriendMessagesNotifier extends StateNotifier<AsyncValue<List<FriendMessage>>> {
  final ApiClient _api;
  final String connectionId;

  FriendMessagesNotifier(this._api, this.connectionId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/api/connections/$connectionId/messages');
      final list = (res['messages'] as List)
          .map((e) => FriendMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> send({
    required String friendUserId,
    required String content,
  }) async {
    try {
      final res = await _api.post(
        '/api/connections/$connectionId/messages',
        body: {
          'connectionId': connectionId,
          'friendUserId': friendUserId,
          'content': content,
        },
      );
      final msg = FriendMessage.fromJson(res['message'] as Map<String, dynamic>);
      state = AsyncValue.data([...state.value ?? [], msg]);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Family provider keyed by connectionId.
final friendMessagesProvider = StateNotifierProvider.family<
    FriendMessagesNotifier, AsyncValue<List<FriendMessage>>, String>(
  (ref, connectionId) =>
      FriendMessagesNotifier(ref.watch(apiClientProvider), connectionId),
);
