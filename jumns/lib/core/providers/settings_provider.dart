import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';

/// Mutable settings state — loaded from backend, editable in-app.
class UserSettingsNotifier extends StateNotifier<AsyncValue<UserSettings>> {
  final ApiClient _api;

  UserSettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.get('/api/user-settings');
      if (json != null) {
        state = AsyncValue.data(
          UserSettings.fromJson(json as Map<String, dynamic>),
        );
      } else {
        state = const AsyncValue.data(UserSettings(id: '', userId: ''));
      }
    } catch (e, st) {
      // Backend unreachable — use defaults
      state = const AsyncValue.data(UserSettings(id: '', userId: ''));
    }
  }

  Future<void> reload() => _load();

  /// Patch one or more fields and persist to backend.
  Future<void> update(Map<String, dynamic> fields) async {
    final current = state.valueOrNull ?? const UserSettings(id: '', userId: '');

    // Optimistic local update
    state = AsyncValue.data(current.copyWith(
      agentName: fields['agentName'] as String? ?? current.agentName,
      agentBehavior:
          fields['agentBehavior'] as String? ?? current.agentBehavior,
      model: fields['model'] as String? ?? current.model,
      morningTime: fields['morningTime'] as String? ?? current.morningTime,
      eveningTime: fields['eveningTime'] as String? ?? current.eveningTime,
    ));

    // Persist to backend
    try {
      await _api.post('/api/user-settings', body: fields);
    } catch (_) {
      // Revert on failure
      state = AsyncValue.data(current);
    }
  }
}

final userSettingsNotifierProvider = StateNotifierProvider<
    UserSettingsNotifier, AsyncValue<UserSettings>>((ref) {
  final isDemoMode = ref.watch(demoModeProvider);
  final authState = ref.watch(authNotifierProvider);
  final api = ref.watch(apiClientProvider);

  // Only create when we have a valid session
  return UserSettingsNotifier(api);
});
