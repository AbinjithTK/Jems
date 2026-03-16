import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'demo_mode_provider.dart';

export 'demo_mode_provider.dart' show demoModeProvider;

/// Manages Firebase auth state for the entire app.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _auth;

  AuthNotifier(this._auth) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    dev.log('[AuthNotifier] _init: starting, setting isLoading=true', name: 'AUTH');
    state = state.copyWith(isLoading: true);
    try {
      final user = await _auth.restoreSession();
      if (user != null) {
        dev.log('[AuthNotifier] _init: restored user=${user.email}, setting authenticated', name: 'AUTH');
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        dev.log('[AuthNotifier] _init: no session, setting unauthenticated', name: 'AUTH');
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      dev.log('[AuthNotifier] _init: ERROR: $e, setting unauthenticated', name: 'AUTH');
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    dev.log('[AuthNotifier] signIn: starting email=$email', name: 'AUTH');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.signIn(email: email, password: password);
      if (user != null) {
        dev.log('[AuthNotifier] signIn: success, user=${user.email}', name: 'AUTH');
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        dev.log('[AuthNotifier] signIn: returned null user', name: 'AUTH');
        state = state.copyWith(isLoading: false, error: 'Sign in failed');
      }
    } on FirebaseAuthException catch (e) {
      dev.log('[AuthNotifier] signIn: FirebaseAuthException code=${e.code}', name: 'AUTH');
      state = state.copyWith(
        isLoading: false,
        error: _mapFirebaseError(e.code),
      );
    } catch (e) {
      dev.log('[AuthNotifier] signIn: UNEXPECTED ERROR: $e', name: 'AUTH');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.signUp(email: email, password: password, name: name);
      if (user != null) {
        // User is signed in but email may not be verified yet
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        state = state.copyWith(isLoading: false, error: 'Sign up failed');
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _mapFirebaseError(e.code),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    dev.log('[AuthNotifier] signInWithGoogle: starting', name: 'AUTH');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        dev.log('[AuthNotifier] signInWithGoogle: success, user=${user.email}', name: 'AUTH');
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        dev.log('[AuthNotifier] signInWithGoogle: user cancelled (null)', name: 'AUTH');
        // User cancelled the Google sign-in flow
        state = state.copyWith(isLoading: false);
      }
    } on FirebaseAuthException catch (e) {
      dev.log('[AuthNotifier] signInWithGoogle: FirebaseAuthException code=${e.code}', name: 'AUTH');
      state = state.copyWith(
        isLoading: false,
        error: _mapFirebaseError(e.code),
      );
    } catch (e) {
      dev.log('[AuthNotifier] signInWithGoogle: UNEXPECTED ERROR: $e', name: 'AUTH');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> forgotPassword({required String email}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.forgotPassword(email: email);
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e.code));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _auth.resendVerificationEmail();
    } catch (_) {}
  }

  /// Maps Firebase error codes to user-friendly messages.
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed ($code).';
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
  );
});

// --- Server-side data providers (use JWT-authenticated API) ---

/// Settings provider that works in BOTH demo and auth modes.
/// Waits for auth to fully resolve before making API calls.
final userSettingsProvider = FutureProvider<UserSettings?>((ref) async {
  final isDemoMode = ref.watch(demoModeProvider);
  final authState = ref.watch(authNotifierProvider);

  // Don't fire API calls while auth is still initializing
  if (!isDemoMode && authState.status == AuthStatus.unknown) return null;

  if (isDemoMode || authState.status == AuthStatus.authenticated) {
    try {
      final api = ref.watch(apiClientProvider);
      final json = await api.get('/api/user-settings');
      if (json == null) return null;
      return UserSettings.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return const UserSettings(id: '', userId: '');
    }
  }
  return null;
});

final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) async {
  final isDemoMode = ref.watch(demoModeProvider);
  final authState = ref.watch(authNotifierProvider);

  // Demo mode → unlimited access, no API call needed
  if (isDemoMode) {
    return const SubscriptionStatus(isActive: true, plan: 'demo_pro');
  }

  // Don't fire API calls while auth is still initializing
  if (authState.status != AuthStatus.authenticated) {
    return const SubscriptionStatus();
  }
  try {
    final api = ref.watch(apiClientProvider);
    final json = await api.get('/api/subscription/status');
    return SubscriptionStatus.fromJson(json as Map<String, dynamic>);
  } catch (_) {
    return const SubscriptionStatus();
  }
});

final accessCodeStatusProvider = FutureProvider<bool>((ref) async {
  final isDemoMode = ref.watch(demoModeProvider);
  if (isDemoMode) return true; // Demo mode → always activated

  final authState = ref.watch(authNotifierProvider);
  // Don't fire API calls while auth is still initializing
  if (authState.status != AuthStatus.authenticated) return false;
  try {
    final api = ref.watch(apiClientProvider);
    final json = await api.get('/api/access-code/status');
    return (json as Map<String, dynamic>)['activated'] as bool? ?? false;
  } catch (_) {
    return false;
  }
});
