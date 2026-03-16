import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../services/api_client.dart';

/// Journal entries provider — full CRUD via /api/journal.
class JournalNotifier extends StateNotifier<AsyncValue<List<JournalEntry>>> {
  final ApiClient _api;

  JournalNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? type}) async {
    state = const AsyncValue.loading();
    try {
      final query = type != null ? {'type': type} : null;
      final json = await _api.get('/api/journal', query: query);
      final list = (json as List<dynamic>)
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new journal entry. Returns the created entry or null on failure.
  Future<JournalEntry?> create({
    required String content,
    String type = 'thought',
    String title = '',
    String? mood,
    List<String> tags = const [],
    bool shareable = false,
    String? linkedGoalId,
    String? mediaUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
        'type': type,
        'title': title,
        'tags': tags,
        'shareable': shareable,
        if (mood != null) 'mood': mood,
        if (linkedGoalId != null) 'linkedGoalId': linkedGoalId,
      };
      final json = await _api.post('/api/journal', body: body);
      final entry = JournalEntry.fromJson(json as Map<String, dynamic>);
      await load();
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// Upload an image and create a polaroid journal entry.
  Future<JournalEntry?> createWithImage({
    required File imageFile,
    String caption = '',
    String type = 'polaroid',
    List<String> tags = const [],
  }) async {
    try {
      // Upload image first
      final uploadJson = await _api.uploadFile(
        '/api/upload/proof',
        file: imageFile,
        fields: {'message': caption},
      );
      final uploadData = uploadJson as Map<String, dynamic>;
      final mediaUrl = uploadData['url'] as String? ?? uploadData['mediaUrl'] as String? ?? '';

      // Create journal entry with the uploaded media URL
      return create(
        content: caption.isNotEmpty ? caption : 'Photo journal entry',
        type: type,
        tags: tags.isEmpty ? ['Photo'] : tags,
        shareable: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _api.patch('/api/journal/$id', body: data);
    await load();
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/journal/$id');
    await load();
  }
}

final journalNotifierProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<List<JournalEntry>>>((ref) {
  return JournalNotifier(ref.watch(apiClientProvider));
});
