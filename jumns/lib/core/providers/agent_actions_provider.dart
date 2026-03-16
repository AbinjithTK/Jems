import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// Provider for direct agent tool invocations from UI.
/// These call dedicated backend endpoints, not the chat flow.

final dailySummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/agent-actions/daily-summary');
  return json as Map<String, dynamic>;
});

final analyzeProgressProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/agent-actions/analyze-progress');
  return json as Map<String, dynamic>;
});

final smartSuggestProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, focus) async {
  final api = ref.watch(apiClientProvider);
  final json =
      await api.get('/api/agent-actions/smart-suggest', query: {'focus': focus});
  return json as Map<String, dynamic>;
});

final adaptGoalProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, goalId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.post('/api/agent-actions/goals/$goalId/adapt');
  return json as Map<String, dynamic>;
});

final rescheduleGoalProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, goalId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.post('/api/agent-actions/goals/$goalId/reschedule');
  return json as Map<String, dynamic>;
});
