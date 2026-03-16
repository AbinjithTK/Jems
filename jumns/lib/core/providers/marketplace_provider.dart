import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace_agent.dart';
import '../services/api_client.dart';

/// Catalog of all available marketplace agents.
final marketplaceCatalogProvider = FutureProvider<List<MarketplaceAgent>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/marketplace');
  return (json as List<dynamic>)
      .map((e) => MarketplaceAgent.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// User's installed marketplace agents.
final installedAgentsProvider = FutureProvider<List<MarketplaceAgent>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/marketplace/installed');
  return (json as List<dynamic>)
      .map((e) => MarketplaceAgent.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Full team: core agents + installed marketplace agents (from GET /api/agents).
final teamAgentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/agents');
  return (json as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
});

/// Notifier for install/uninstall actions that invalidates related providers.
class MarketplaceActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  MarketplaceActionsNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<void> install(String agentId) async {
    state = const AsyncValue.loading();
    try {
      await _api.post('/api/marketplace/install/$agentId');
      _ref.invalidate(installedAgentsProvider);
      _ref.invalidate(teamAgentsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> uninstall(String agentId) async {
    state = const AsyncValue.loading();
    try {
      await _api.delete('/api/marketplace/uninstall/$agentId');
      _ref.invalidate(installedAgentsProvider);
      _ref.invalidate(teamAgentsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final marketplaceActionsProvider =
    StateNotifierProvider<MarketplaceActionsNotifier, AsyncValue<void>>((ref) {
  return MarketplaceActionsNotifier(ref.watch(apiClientProvider), ref);
});
