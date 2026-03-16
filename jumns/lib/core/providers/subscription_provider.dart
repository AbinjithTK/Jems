import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Subscription state — stubbed for MVP (no RevenueCat).
class SubscriptionState {
  final bool isPro;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.isPro = false,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPro,
    bool? isLoading,
    String? error,
  }) =>
      SubscriptionState(
        isPro: isPro ?? this.isPro,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    // MVP — always free tier
    state = state.copyWith(isLoading: false, isPro: false);
  }

  Future<void> restore() async {
    state = state.copyWith(isLoading: false, error: 'Not available in MVP');
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
