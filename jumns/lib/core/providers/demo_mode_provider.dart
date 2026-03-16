import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo mode — bypasses Firebase auth for instant MVP testing.
/// Extracted to its own file to avoid circular imports between
/// api_client.dart ↔ auth_provider.dart.
final demoModeProvider = StateProvider<bool>((ref) => false);
