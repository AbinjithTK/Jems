import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/providers/connections_provider.dart';

/// Social Connections page — friends list, pending requests, add friend.
class SocialConnectionsPage extends ConsumerWidget {
  const SocialConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsNotifierProvider);

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  Text('FRIENDS',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        letterSpacing: 1.2, color: SpatialColors.textTertiary,
                      )),
                  const Spacer(),
                  // Share my agent card
                  GestureDetector(
                    onTap: () => _shareAgentCard(context, ref),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: SpatialColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)],
                      ),
                      child: const Icon(Icons.share_rounded, size: 16, color: SpatialColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Connections list
            Expanded(
              child: connectionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: SpatialColors.agentPink)),
                error: (e, _) => Center(child: Text('Failed to load', style: GoogleFonts.inter(color: SpatialColors.textTertiary))),
                data: (connections) {
                  final pending = connections.where((c) => c.isPending).toList();
                  final accepted = connections.where((c) => c.isAccepted).toList();
                  return CustomScrollView(
                    slivers: [
                      if (pending.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Text('PENDING REQUESTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: SpatialColors.textMuted)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.separated(
                            itemCount: pending.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _PendingCard(connection: pending[i]),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Text('CONNECTED FRIENDS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: SpatialColors.textMuted)),
                        ),
                      ),
                      if (accepted.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('No friends connected yet. Share your agent card to get started.', style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary)),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.separated(
                            itemCount: accepted.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _FriendCard(connection: accepted[i]),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _AddFriendFab(onTap: () => _showAddFriendSheet(context, ref)),
    );
  }

  void _shareAgentCard(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(connectionsNotifierProvider.notifier);
    final url = await notifier.getMyAgentCardUrl();
    if (context.mounted && url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agent card URL copied: $url'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showAddFriendSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFriendSheet(notifier: ref.read(connectionsNotifierProvider.notifier)),
    );
  }
}

// --- Private widgets ---

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: SpatialColors.textTertiary),
      ),
    );
  }
}

class _AddFriendFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFriendFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: SpatialColors.sageGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(offset: const Offset(0, 4), blurRadius: 16, color: SpatialColors.agentPink.withAlpha(77))],
        ),
        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}


class _FriendCard extends ConsumerWidget {
  final SocialConnection connection;
  const _FriendCard({required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpatialColors.surfaceSubtle),
        boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
      ),
      child: Row(
        children: [
          const AgentSphere(agentColor: 'green', size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.friendDisplayName.isNotEmpty ? connection.friendDisplayName : 'Friend',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
                ),
                Text('Agent connected', style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.agentGreen)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(connectionsNotifierProvider.notifier).remove(connection.connectionId),
            child: const Icon(Icons.more_horiz_rounded, size: 20, color: SpatialColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  final SocialConnection connection;
  const _PendingCard({required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(connectionsNotifierProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpatialColors.agentYellow.withAlpha(77)),
        boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
      ),
      child: Row(
        children: [
          const AgentSphere(agentColor: 'pink', size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.friendDisplayName.isNotEmpty ? connection.friendDisplayName : 'New Request',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
                ),
                Text('Wants to connect agents', style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.agentYellow)),
              ],
            ),
          ),
          // Accept
          GestureDetector(
            onTap: () => notifier.accept(connection.connectionId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(gradient: SpatialColors.noorGradient, borderRadius: BorderRadius.circular(12)),
              child: Text('Accept', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // Reject
          GestureDetector(
            onTap: () => notifier.reject(connection.connectionId),
            child: const Icon(Icons.close_rounded, size: 20, color: SpatialColors.textMuted),
          ),
        ],
      ),
    );
  }
}


class _AddFriendSheet extends StatefulWidget {
  final ConnectionsNotifier notifier;
  const _AddFriendSheet({required this.notifier});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_urlController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.notifier.sendRequest(
      friendUserId: _urlController.text.trim().hashCode.toString(),
      displayName: _nameController.text.trim(),
      agentCardUrl: _urlController.text.trim(),
    );
    if (mounted) {
      setState(() => _sending = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SpatialColors.surfaceMuted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Connect a Friend', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: SpatialColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Paste their agent card URL to connect your agents', style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary)),
          const SizedBox(height: 16),
          // Name field
          TextField(
            controller: _nameController,
            style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Friend name (optional)',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textMuted),
              filled: true, fillColor: SpatialColors.surfaceSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          // Agent card URL field
          TextField(
            controller: _urlController,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SpatialColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://api.jems.app/a2a/user123/.well-known/agent-card.json',
              hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: SpatialColors.textMuted),
              filled: true, fillColor: SpatialColors.surfaceSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              height: 48,
              decoration: BoxDecoration(gradient: SpatialColors.sageGradient, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Send Connection Request', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
