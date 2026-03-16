import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Represents the currently authenticated user.
class AuthUser {
  final String sub;
  final String email;
  final String? name;
  final bool emailVerified;

  const AuthUser({
    required this.sub,
    required this.email,
    this.name,
    this.emailVerified = false,
  });
}

/// Auth state exposed to the UI.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? error,
    bool? isLoading,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Service that wraps Firebase Auth operations.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Firebase Auth is always available once Firebase.initializeApp() is called.
  bool get isConfigured => true;

  /// Returns the current valid Firebase ID token, refreshing if expired.
  Future<String?> getIdToken() async {
    return _firebaseAuth.currentUser?.getIdToken();
  }

  /// Force-refresh the Firebase ID token (e.g. after a 401 response).
  Future<String?> forceRefreshToken() async {
    return _firebaseAuth.currentUser?.getIdToken(true);
  }

  /// Alias for getIdToken — Firebase uses a single ID token (no separate access token).
  Future<String?> getAccessToken() => getIdToken();

  /// Try to restore a previous session. Firebase persists auth state automatically.
  Future<AuthUser?> restoreSession() async {
    final user = _firebaseAuth.currentUser;
    dev.log('[AuthService] restoreSession: currentUser=${user?.uid}', name: 'AUTH');
    if (user == null) return null;
    // Force a token refresh to ensure the session is still valid
    try {
      await user.getIdToken(true);
      dev.log('[AuthService] restoreSession: token refreshed OK', name: 'AUTH');
      return _toAuthUser(user);
    } catch (e) {
      dev.log('[AuthService] restoreSession: token refresh failed: $e', name: 'AUTH');
      return null;
    }
  }

  /// Sign up a new user with email and password.
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final cred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (name != null && name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();
    }
    // Send email verification
    await cred.user?.sendEmailVerification();
    return cred.user != null ? _toAuthUser(cred.user!) : null;
  }

  /// Sign in with email and password.
  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    dev.log('[AuthService] signIn: attempting email=$email', name: 'AUTH');
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      dev.log('[AuthService] signIn: success uid=${cred.user?.uid}', name: 'AUTH');
      return cred.user != null ? _toAuthUser(cred.user!) : null;
    } catch (e) {
      dev.log('[AuthService] signIn: FAILED: $e', name: 'AUTH');
      rethrow;
    }
  }

  /// Sign in with Google account via Firebase.
  Future<AuthUser?> signInWithGoogle() async {
    dev.log('[AuthService] signInWithGoogle: starting', name: 'AUTH');
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        dev.log('[AuthService] signInWithGoogle: user cancelled', name: 'AUTH');
        return null;
      }

      dev.log('[AuthService] signInWithGoogle: got google user ${googleUser.email}', name: 'AUTH');
      final googleAuth = await googleUser.authentication;
      dev.log('[AuthService] signInWithGoogle: got tokens, accessToken=${googleAuth.accessToken != null}, idToken=${googleAuth.idToken != null}', name: 'AUTH');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _firebaseAuth.signInWithCredential(credential);
      dev.log('[AuthService] signInWithGoogle: success uid=${cred.user?.uid}', name: 'AUTH');
      return cred.user != null ? _toAuthUser(cred.user!) : null;
    } catch (e) {
      dev.log('[AuthService] signInWithGoogle: FAILED: $e', name: 'AUTH');
      rethrow;
    }
  }

  /// Sign out (also signs out of Google to allow account switching).
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _firebaseAuth.signOut();
  }

  /// Initiate forgot password flow — sends a reset email.
  Future<void> forgotPassword({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Resend email verification to the current user.
  Future<void> resendVerificationEmail() async {
    await _firebaseAuth.currentUser?.sendEmailVerification();
  }

  // --- Private helpers ---

  AuthUser _toAuthUser(User user) {
    return AuthUser(
      sub: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      emailVerified: user.emailVerified,
    );
  }
}

/// Singleton provider for the auth service.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
