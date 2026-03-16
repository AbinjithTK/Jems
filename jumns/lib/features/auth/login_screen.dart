import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/utils/url_helper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const AgentSphere(agentColor: 'green', size: 80, showFace: true),
              const SizedBox(height: 20),
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  color: SpatialColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Sign up to get started with Jems'
                    : 'Sign in to your Jems account',
                style: GoogleFonts.inter(
                  color: SpatialColors.textTertiary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (authState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withAlpha(60)),
                  ),
                  child: Text(authState.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              if (_isSignUp) ...[
                _GlassTextField(
                  controller: _nameCtrl,
                  label: 'Name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
              ],
              _GlassTextField(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _GlassTextField(
                controller: _passwordCtrl,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: SpatialColors.textTertiary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),
              _SpatialButton(
                label: _isSignUp ? 'Sign Up' : 'Sign In',
                loading: authState.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              // --- OR divider ---
              Row(
                children: [
                  Expanded(child: Divider(color: SpatialColors.textMuted.withAlpha(80))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or',
                        style: GoogleFonts.inter(
                            color: SpatialColors.textTertiary, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: SpatialColors.textMuted.withAlpha(80))),
                ],
              ),
              const SizedBox(height: 16),
              // --- Google Sign-In button ---
              _GoogleSignInButton(
                loading: authState.isLoading,
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).signInWithGoogle();
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: GoogleFonts.inter(
                        color: SpatialColors.textTertiary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Sign Up',
                      style: GoogleFonts.inter(
                          color: SpatialColors.agentGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (!_isSignUp) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _forgotPassword,
                  child: Text('Forgot Password?',
                      style: GoogleFonts.inter(
                          color: SpatialColors.textTertiary,
                          fontSize: 13)),
                ),
              ],
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('demo_mode', true);
                  ref.read(appStateProvider.notifier).completeOnboarding();
                  ref.read(demoModeProvider.notifier).state = true;
                  if (context.mounted) context.go('/hub');
                },
                child: Text('Try Demo Mode',
                    style: GoogleFonts.inter(
                        color: SpatialColors.textMuted,
                        fontSize: 13)),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () =>
                        openUrl(context, JemsUrls.privacyPolicy),
                    child: Text('Privacy Policy',
                        style: GoogleFonts.inter(
                            color: SpatialColors.textMuted,
                            fontSize: 11)),
                  ),
                  Text('·',
                      style: TextStyle(color: SpatialColors.textMuted)),
                  TextButton(
                    onPressed: () =>
                        openUrl(context, JemsUrls.termsOfService),
                    child: Text('Terms of Service',
                        style: GoogleFonts.inter(
                            color: SpatialColors.textMuted,
                            fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    if (_isSignUp) {
      ref.read(authNotifierProvider.notifier).signUp(
            email: email,
            password: password,
            name: _nameCtrl.text.trim().isEmpty
                ? null
                : _nameCtrl.text.trim(),
          );
    } else {
      ref.read(authNotifierProvider.notifier).signIn(
            email: email,
            password: password,
          );
    }
  }

  void _forgotPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    ref
        .read(authNotifierProvider.notifier)
        .forgotPassword(email: email);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Password reset email sent')),
    );
  }
}

// ─── Glassmorphism text field ───

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: SpatialColors.inputGlassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SpatialColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            obscureText: obscureText,
            autocorrect: false,
            style: GoogleFonts.inter(
              color: SpatialColors.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.inter(
                color: SpatialColors.textTertiary,
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: SpatialColors.textTertiary),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Spatial button (green gradient pill) ───

class _SpatialButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _SpatialButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: SpatialColors.noorGradient,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: SpatialColors.agentGreen.withAlpha(51),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: SpatialColors.textPrimary))
              : Text(label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SpatialColors.textPrimary,
                  )),
        ),
      ),
    );
  }
}


// ─── Google Sign-In button (glassmorphism style) ───

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: SpatialColors.glassBg,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: SpatialColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: SpatialColors.glassShadow,
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: loading ? null : onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google "G" logo using text (no asset needed)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          'G',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4285F4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SpatialColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
