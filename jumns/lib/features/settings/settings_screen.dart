import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/messages_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/utils/url_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final settingsAsync = ref.watch(userSettingsNotifierProvider);
    final sub = ref.watch(subscriptionNotifierProvider);

    final user = authState.user;
    final name = user?.name ??
        (user?.email != null ? user!.email.split('@').first : 'User');
    final isPro = sub.isPro;

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 20),
            _SpatialProfileSection(name: name),
            const SizedBox(height: 28),
            _buildAgentConfig(settingsAsync, context, ref),
            const SizedBox(height: 16),
            _buildSubscription(isPro, context),
            const SizedBox(height: 16),
            _buildDataPrivacy(context, ref),
            const SizedBox(height: 16),
            _buildNotifications(settingsAsync, context, ref),
            const SizedBox(height: 32),
            _buildSignOut(context, ref),
            const SizedBox(height: 20),
            _buildFooter(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          _NeumorphicCircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 14),
          Text('Settings',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: SpatialColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildAgentConfig(
      AsyncValue settingsAsync, BuildContext context, WidgetRef ref) {
    return _GlassCard(
      icon: Icons.smart_toy_outlined,
      title: 'Agent Configuration',
      child: settingsAsync.when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: SpatialColors.agentGreen, strokeWidth: 2))),
        error: (_, __) => Text('Could not load settings',
            style: GoogleFonts.plusJakartaSans(
                color: SpatialColors.textTertiary)),
        data: (settings) {
          final s = settings as dynamic;
          return Column(children: [
            _SettingsTile(
                icon: Icons.auto_awesome,
                label: 'Model',
                value: s.modelLabel as String,
                onTap: () =>
                    _showModelPicker(context, ref, s.model as String)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _SettingsTile(
                      icon: Icons.badge_outlined,
                      label: 'Name',
                      value: s.agentName as String,
                      onTap: () => _showNameEditor(
                          context, ref, s.agentName as String))),
              const SizedBox(width: 10),
              Expanded(
                  child: _SettingsTile(
                      icon: Icons.psychology_outlined,
                      label: 'Personality',
                      value: s.personalityLabel as String,
                      onTap: () => _showPersonalityPicker(
                          context, ref, s.agentBehavior as String))),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _buildSubscription(bool isPro, BuildContext context) {
    return _GlassCard(
      icon: Icons.loyalty_outlined,
      title: 'Subscription',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: SpatialColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isPro
                  ? SpatialColors.noorGradient
                  : const LinearGradient(
                      colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)]),
            ),
            child: Icon(
                isPro ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isPro
                    ? SpatialColors.textPrimary
                    : SpatialColors.textTertiary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPro ? 'Pro Status' : 'Free Plan',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SpatialColors.textPrimary)),
                  Text(isPro ? 'Active' : 'Upgrade for more',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: SpatialColors.textTertiary)),
                ]),
          ),
          if (isPro)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: SpatialColors.checkBg),
              child: const Icon(Icons.check_rounded,
                  color: SpatialColors.agentGreen, size: 16),
            )
          else
            GestureDetector(
              onTap: () => context.push('/paywall'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    gradient: SpatialColors.noorGradient,
                    borderRadius: BorderRadius.circular(9999)),
                child: Text('Upgrade',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SpatialColors.textPrimary)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildDataPrivacy(BuildContext context, WidgetRef ref) {
    return _GlassCard(
      icon: Icons.shield_outlined,
      title: 'Data & Privacy',
      child: Column(children: [
        _SettingsRow(
            label: 'Privacy Policy',
            onTap: () => openUrl(context, JemsUrls.privacyPolicy)),
        Divider(color: SpatialColors.surfaceMuted, height: 1),
        _SettingsRow(
            label: 'Clear Conversation History',
            isDestructive: true,
            trailing: Icons.delete_sweep_outlined,
            onTap: () => _showClearDialog(context, ref)),
      ]),
    );
  }

  Widget _buildNotifications(
      AsyncValue settingsAsync, BuildContext context, WidgetRef ref) {
    return _GlassCard(
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      child: settingsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (settings) {
          final s = settings as dynamic;
          return Column(children: [
            _SettingsRow(
                label: 'Daily Briefing',
                value: _formatTime(s.morningTime as String),
                onTap: () => _showTimePicker(context, ref, 'morningTime',
                    s.morningTime as String, 'Daily Briefing Time')),
            Divider(color: SpatialColors.surfaceMuted, height: 1),
            _SettingsRow(
                label: 'Journal Prompt',
                value: _formatTime(s.eveningTime as String),
                onTap: () => _showTimePicker(context, ref, 'eveningTime',
                    s.eveningTime as String, 'Journal Prompt Time')),
          ]);
        },
      ),
    );
  }

  Widget _buildSignOut(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('demo_mode', false);
        ref.read(demoModeProvider.notifier).state = false;
        ref.read(authNotifierProvider.notifier).signOut();
        if (context.mounted) context.go('/login');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Text('Sign Out',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700)),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(children: [
        Text('Jems v2.4',
            style: GoogleFonts.inter(
                fontSize: 12, color: SpatialColors.textMuted)),
        const SizedBox(height: 2),
        Text('Made with care',
            style: GoogleFonts.inter(
                fontSize: 10,
                color: SpatialColors.textMuted.withAlpha(150))),
      ]),
    );
  }

  // ─── Model picker bottom sheet ───
  void _showModelPicker(BuildContext context, WidgetRef ref, String current) {
    const models = [
      ('gemini-2.5-flash', 'Gemini 2.5 Flash', 'Fast & efficient', Icons.flash_on),
      ('gemini-2.5-pro', 'Gemini 2.5 Pro', 'Most capable', Icons.auto_awesome),
      ('gemini-2.0-flash', 'Gemini 2.0 Flash', 'Previous gen', Icons.speed),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: SpatialColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Model',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SpatialColors.textPrimary)),
            const SizedBox(height: 16),
            ...models.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(userSettingsNotifierProvider.notifier)
                          .update({'model': m.$1});
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: current == m.$1
                            ? SpatialColors.surfaceSubtle
                            : SpatialColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: current == m.$1
                                ? SpatialColors.agentGreen
                                : SpatialColors.surfaceMuted,
                            width: 1.5),
                      ),
                      child: Row(children: [
                        Icon(m.$4,
                            color: SpatialColors.textSecondary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.$2,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: SpatialColors.textPrimary)),
                                Text(m.$3,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: SpatialColors.textTertiary)),
                              ]),
                        ),
                        if (current == m.$1)
                          const Icon(Icons.check_circle_rounded,
                              color: SpatialColors.agentGreen, size: 20),
                      ]),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Agent name editor dialog ───
  void _showNameEditor(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpatialColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Agent Name',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: SpatialColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 18, color: SpatialColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Jems, Buddy, Coach...',
            hintStyle: GoogleFonts.plusJakartaSans(
                color: SpatialColors.textTertiary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: SpatialColors.surfaceMuted)),
            focusedBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: SpatialColors.agentGreen, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                      color: SpatialColors.textTertiary))),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(userSettingsNotifierProvider.notifier)
                    .update({'agentName': name});
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: SpatialColors.agentGreen)),
          ),
        ],
      ),
    );
  }

  // ─── Personality picker bottom sheet ───
  void _showPersonalityPicker(
      BuildContext context, WidgetRef ref, String current) {
    const personalities = [
      ('friendly', 'Friendly', '😊', 'Warm, supportive, encouraging'),
      ('coach', 'Coach', '💪', 'Motivating, goal-oriented, direct'),
      ('professional', 'Professional', '📋', 'Structured, efficient, formal'),
      ('zen', 'Zen', '🧘', 'Calm, mindful, reflective'),
      ('creative', 'Creative', '✨', 'Playful, imaginative, inspiring'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: SpatialColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agent Personality',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SpatialColors.textPrimary)),
            const SizedBox(height: 16),
            ...personalities.map((p) {
              final isSelected = current.toLowerCase() == p.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(userSettingsNotifierProvider.notifier)
                        .update({'agentBehavior': p.$1});
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SpatialColors.surfaceSubtle
                          : SpatialColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isSelected
                              ? SpatialColors.agentViolet
                              : SpatialColors.surfaceMuted,
                          width: 1.5),
                    ),
                    child: Row(children: [
                      Text(p.$3, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: SpatialColors.textPrimary)),
                              Text(p.$4,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: SpatialColors.textTertiary)),
                            ]),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: SpatialColors.agentViolet, size: 20),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Time picker ───
  Future<void> _showTimePicker(BuildContext context, WidgetRef ref,
      String field, String currentValue, String title) async {
    final parts = currentValue.split(':');
    final hour = int.tryParse(parts.firstOrNull ?? '8') ?? 8;
    final minute = int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: title,
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref
          .read(userSettingsNotifierProvider.notifier)
          .update({field: formatted});
    }
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    final h = int.tryParse(parts.firstOrNull ?? '0') ?? 0;
    final m = parts.elementAtOrNull(1) ?? '00';
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  // ─── Clear history dialog ───
  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpatialColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Clear History?',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: SpatialColors.textPrimary)),
        content: Text(
            'This will permanently delete all conversation messages.',
            style: GoogleFonts.plusJakartaSans(
                color: SpatialColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                      color: SpatialColors.textTertiary))),
          TextButton(
            onPressed: () {
              ref.read(messagesNotifierProvider.notifier).clearAll();
              Navigator.pop(ctx);
            },
            child: Text('Clear',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}


// ─── Neumorphic circle button (back button) ───
class _NeumorphicCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NeumorphicCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(26),
                offset: const Offset(-2, -2),
                blurRadius: 6,
                blurStyle: BlurStyle.inner),
            BoxShadow(
                color: Colors.white.withAlpha(128),
                offset: const Offset(2, 2),
                blurRadius: 6,
                blurStyle: BlurStyle.inner),
            BoxShadow(
                color: Colors.black.withAlpha(13),
                offset: const Offset(0, 1),
                blurRadius: 3),
          ],
        ),
        child: Icon(icon, color: SpatialColors.textTertiary, size: 18),
      ),
    );
  }
}

// ─── Profile section with agent sphere style avatar ───
class _SpatialProfileSection extends StatelessWidget {
  final String name;
  const _SpatialProfileSection({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SpatialColors.noorGradient,
            boxShadow: [
              BoxShadow(
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  color: const Color(0xFF6EE7B7).withAlpha(60)),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: SpatialColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SpatialColors.textPrimary)),
        const SizedBox(height: 2),
        Text('Making life simpler',
            style: GoogleFonts.inter(
                fontSize: 13, color: SpatialColors.textTertiary)),
      ]),
    );
  }
}

// ─── Glass card container ───
class _GlassCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _GlassCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SpatialColors.surfaceMuted, width: 1),
        boxShadow: [
          BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withAlpha(13)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: SpatialColors.textTertiary, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SpatialColors.textPrimary)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}


// ─── Settings tile (tappable card with icon, label, value) ───
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SpatialColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: SpatialColors.textTertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: SpatialColors.textTertiary)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SpatialColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: SpatialColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

// ─── Settings row (simple label + optional value + chevron) ───
class _SettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isDestructive;
  final IconData? trailing;
  final VoidCallback onTap;
  const _SettingsRow(
      {required this.label,
      this.value,
      this.isDestructive = false,
      this.trailing,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? Colors.red.shade600 : SpatialColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w500, color: color)),
          const Spacer(),
          if (value != null)
            Text(value!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: SpatialColors.textTertiary)),
          const SizedBox(width: 4),
          Icon(trailing ?? Icons.chevron_right_rounded,
              color: isDestructive ? Colors.red.shade400 : SpatialColors.textMuted,
              size: 18),
        ]),
      ),
    );
  }
}
