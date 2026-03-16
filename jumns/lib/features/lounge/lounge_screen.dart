import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/connections_provider.dart';
import '../../core/providers/friend_messages_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/widgets/agent_chat_input.dart';

/// Social Briefing Room — wired to connectionsNotifierProvider.
class LoungeScreen extends ConsumerWidget {
  const LoungeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsNotifierProvider);

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
            onRefresh: () => ref.read(connectionsNotifierProvider.notifier).load(),
            child: CustomScrollView(
              slivers: [
                // Compact header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        const AgentSphere(agentColor: 'pink', size: 32),
                        const SizedBox(width: 10),
                        Text(
                          'LOUNGE',
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: 1.2, color: SpatialColors.agentPink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Content based on connections state
                SliverToBoxAdapter(
                  child: connectionsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 40, color: SpatialColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load connections',
                              style: GoogleFonts.inter(fontSize: 15, color: SpatialColors.textTertiary),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => ref.read(connectionsNotifierProvider.notifier).load(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: SpatialColors.agentPink.withAlpha(20),
                                  borderRadius: BorderRadius.circular(9999),
                                  border: Border.all(color: SpatialColors.agentPink.withAlpha(60)),
                                ),
                                child: Text('Retry', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SpatialColors.agentPink)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (connections) {
                      if (connections.isEmpty) {
                        return _EmptyLounge();
                      }
                      final accepted = connections.where((c) => c.isAccepted).toList();
                      final pending = connections.where((c) => c.isPending).toList();
                      return _LoungeContent(
                        accepted: accepted,
                        pending: pending,
                        ref: ref,
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 160)),
              ],
            ),
          ),
              ),
              const AgentChatInput(agentName: 'sage', agentColor: 'pink', hintText: 'Ask the social agent...'),
            ],
          ),

          // Floating action buttons — Chat, Find Friends, Map
          Positioned(
            right: 20,
            bottom: 100,
            child: _LoungeFabColumn(),
          ),
        ],
      ),
    );
  }
}

/// Floating action buttons column for Lounge social actions.
class _LoungeFabColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map button
        _LoungeFab(
          icon: Icons.map_outlined,
          label: 'Map',
          color: const Color(0xFF60A5FA),
          onTap: () => _showComingSoon(context, 'Map'),
        ),
        const SizedBox(height: 12),
        // Find Friends button — opens contacts-based sheet
        _LoungeFab(
          icon: Icons.person_search_rounded,
          label: 'Find',
          color: SpatialColors.agentPink,
          onTap: () => _showFindFriendsSheet(context),
        ),
        const SizedBox(height: 12),
        // Chat button — opens FRIENDS chat picker (not Hub)
        _LoungeFabPrimary(
          icon: Icons.chat_bubble_rounded,
          onTap: () => _showFriendsChatSheet(context),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: SpatialColors.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFindFriendsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => _FindFriendsFromContactsSheet(scrollController: controller),
      ),
    );
  }

  void _showFriendsChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => _FriendsChatPickerSheet(scrollController: controller),
      ),
    );
  }
}

/// Small floating action button for secondary actions.
class _LoungeFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _LoungeFab({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(210),
                  border: Border.all(color: color.withAlpha(60)),
                  boxShadow: [
                    BoxShadow(offset: const Offset(0, 4), blurRadius: 12, color: color.withAlpha(40)),
                    BoxShadow(offset: const Offset(0, 1), blurRadius: 4, color: Colors.black.withAlpha(10)),
                  ],
                ),
                child: Icon(icon, size: 22, color: color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: SpatialColors.textTertiary)),
        ],
      ),
    );
  }
}

/// Primary floating action button (Chat — uses Sage pink gradient).
class _LoungeFabPrimary extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _LoungeFabPrimary({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SpatialColors.sageGradient,
              boxShadow: [
                BoxShadow(offset: const Offset(0, 6), blurRadius: 20, color: SpatialColors.agentPink.withAlpha(80)),
                BoxShadow(offset: const Offset(0, 2), blurRadius: 6, color: Colors.black.withAlpha(15)),
              ],
            ),
            child: Icon(icon, size: 26, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('Chat', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: SpatialColors.agentPink)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends Chat Picker — shows accepted friends, tap to open DM
// ---------------------------------------------------------------------------

class _FriendsChatPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  const _FriendsChatPickerSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsNotifierProvider);
    final accepted = connectionsAsync.valueOrNull?.where((c) => c.isAccepted).toList() ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: SpatialColors.textMuted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: SpatialColors.sageGradient),
                  child: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('Friends Chat', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: SpatialColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a friend to start chatting',
                style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: accepted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 48, color: SpatialColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No friends yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: SpatialColors.textTertiary)),
                        const SizedBox(height: 6),
                        Text('Add friends to start chatting', style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accepted.length,
                    itemBuilder: (context, index) {
                      final friend = accepted[index];
                      return _FriendChatTile(
                        friend: friend,
                        onTap: () {
                          Navigator.pop(context);
                          _openFriendChat(context, friend);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openFriendChat(BuildContext context, SocialConnection friend) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FriendChatScreen(friend: friend)),
    );
  }
}

class _FriendChatTile extends StatelessWidget {
  final SocialConnection friend;
  final VoidCallback onTap;
  const _FriendChatTile({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = friend.friendDisplayName.isNotEmpty ? friend.friendDisplayName : 'Friend';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SpatialColors.surfaceSubtle),
          boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: SpatialColors.agentPink.withAlpha(26)),
              child: Center(
                child: Text(
                  _initials(name),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: SpatialColors.agentPink),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('Tap to chat', style: GoogleFonts.inter(fontSize: 12, color: SpatialColors.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: SpatialColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Friend Chat Screen — simple DM with a friend
// ---------------------------------------------------------------------------

class _FriendChatScreen extends ConsumerStatefulWidget {
  final SocialConnection friend;
  const _FriendChatScreen({required this.friend});

  @override
  ConsumerState<_FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends ConsumerState<_FriendChatScreen> {
  final _controller = TextEditingController();

  String get _friendName => widget.friend.friendDisplayName.isNotEmpty ? widget.friend.friendDisplayName : 'Friend';
  String get _connectionId => widget.friend.connectionId;
  String get _friendUserId => widget.friend.friendUserId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(friendMessagesProvider(_connectionId).notifier).send(
      friendUserId: _friendUserId,
      content: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(friendMessagesProvider(_connectionId));

    return Scaffold(
      backgroundColor: SpatialColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: SpatialColors.agentPink.withAlpha(26)),
              child: Center(
                child: Text(
                  _initials(_friendName),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: SpatialColors.agentPink),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(_friendName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: SpatialColors.textPrimary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load messages', style: GoogleFonts.inter(color: SpatialColors.textTertiary))),
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: SpatialColors.agentPink.withAlpha(20)),
                            child: Icon(Icons.chat_bubble_outline_rounded, size: 28, color: SpatialColors.agentPink.withAlpha(120)),
                          ),
                          const SizedBox(height: 16),
                          Text('Say hi to $_friendName', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: SpatialColors.textTertiary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _FriendMessageBubble(message: messages[i]),
                    ),
            ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).viewPadding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 8, color: Colors.black.withAlpha(10))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: SpatialColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textSecondary),
                      decoration: InputDecoration(
                        hintText: 'Message $_friendName...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: SpatialColors.sageGradient),
                    child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

class _FriendMessageBubble extends StatelessWidget {
  final FriendMessage message;
  const _FriendMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: message.isMe ? const Color(0xFF4A90E2) : SpatialColors.surfaceSubtle,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(32),
            topRight: const Radius.circular(32),
            bottomLeft: Radius.circular(message.isMe ? 32 : 8),
            bottomRight: Radius.circular(message.isMe ? 8 : 32),
          ),
          boxShadow: [
            if (message.isMe)
              BoxShadow(offset: const Offset(0, 4), blurRadius: 12, color: const Color(0xFF4A90E2).withAlpha(50)),
          ],
        ),
        child: Text(
          message.content,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w500,
            height: 1.5,
            color: message.isMe ? Colors.white : SpatialColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Find Friends from Contacts — reads device contacts, Add or Invite
// ---------------------------------------------------------------------------

class _FindFriendsFromContactsSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _FindFriendsFromContactsSheet({required this.scrollController});

  @override
  ConsumerState<_FindFriendsFromContactsSheet> createState() => _FindFriendsFromContactsSheetState();
}

class _FindFriendsFromContactsSheetState extends ConsumerState<_FindFriendsFromContactsSheet> {
  List<Contact>? _contacts;
  bool _loading = true;
  bool _denied = false;
  String _search = '';
  final _sentIds = <String>{}; // track which contacts got an invite/add

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) {
      setState(() { _denied = true; _loading = false; });
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    // Sort alphabetically
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    setState(() { _contacts = contacts; _loading = false; });
  }

  List<Contact> get _filtered {
    if (_contacts == null) return [];
    if (_search.isEmpty) return _contacts!;
    final q = _search.toLowerCase();
    return _contacts!.where((c) {
      if (c.displayName.toLowerCase().contains(q)) return true;
      for (final p in c.phones) {
        if (p.number.contains(q)) return true;
      }
      return false;
    }).toList();
  }

  /// Simulate checking if a contact has a Jems account.
  /// In production this would call a backend lookup endpoint.
  /// For now: contacts with emails are treated as "on Jems" (demo heuristic).
  bool _hasJemsAccount(Contact c) => c.emails.isNotEmpty;

  Future<void> _addFriend(Contact c) async {
    final id = c.id;
    setState(() => _sentIds.add(id));
    // Use phone or email as the friend user ID for the connection request
    final identifier = c.emails.isNotEmpty
        ? c.emails.first.address
        : (c.phones.isNotEmpty ? c.phones.first.number : c.displayName);
    await ref.read(connectionsNotifierProvider.notifier).sendRequest(
      friendUserId: identifier,
      displayName: c.displayName,
    );
  }

  void _inviteFriend(Contact c) {
    setState(() => _sentIds.add(c.id));
    Share.share(
      'Hey ${c.displayName.split(' ').first}! Join me on Jems — your AI life assistant. Download it here: https://jems.app/invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: SpatialColors.textMuted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: SpatialColors.agentPink.withAlpha(26)),
                  child: const Icon(Icons.contacts_rounded, size: 16, color: SpatialColors.agentPink),
                ),
                const SizedBox(width: 10),
                Text('Find Friends', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: SpatialColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add friends from your contacts or invite them to Jems',
                style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: SpatialColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, size: 20, color: SpatialColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textSecondary),
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts_rounded, size: 48, color: SpatialColors.textMuted),
              const SizedBox(height: 16),
              Text('Contacts access needed', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: SpatialColors.textTertiary)),
              const SizedBox(height: 8),
              Text(
                'Allow Jems to access your contacts to find friends who are already on the app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loadContacts,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(gradient: SpatialColors.sageGradient, borderRadius: BorderRadius.circular(9999)),
                  child: Text('Grant Access', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _search.isEmpty ? 'No contacts found' : 'No matches for "$_search"',
          style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textTertiary),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];
        final onJems = _hasJemsAccount(c);
        final sent = _sentIds.contains(c.id);
        return _ContactTile(
          contact: c,
          isOnJems: onJems,
          isSent: sent,
          onAdd: () => _addFriend(c),
          onInvite: () => _inviteFriend(c),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool isOnJems;
  final bool isSent;
  final VoidCallback onAdd;
  final VoidCallback onInvite;
  const _ContactTile({required this.contact, required this.isOnJems, required this.isSent, required this.onAdd, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName;
    final subtitle = isOnJems ? 'On Jems' : (contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpatialColors.surfaceSubtle),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnJems ? SpatialColors.agentGreen.withAlpha(26) : SpatialColors.surfaceMuted,
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: isOnJems ? SpatialColors.agentGreen : SpatialColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isOnJems) ...[
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: SpatialColors.agentGreen),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: isOnJems ? SpatialColors.agentGreen : SpatialColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action button
          if (isSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: SpatialColors.surfaceMuted,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text('Sent', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.textTertiary)),
            )
          else if (isOnJems)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: SpatialColors.sageGradient,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text('Add', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else
            GestureDetector(
              onTap: onInvite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: SpatialColors.agentPink.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, size: 12, color: SpatialColors.agentPink),
                    const SizedBox(width: 4),
                    Text('Invite', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.agentPink)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Lounge content widgets (connections list, masonry, pending, empty)
// ---------------------------------------------------------------------------

class _LoungeContent extends StatelessWidget {
  final List<SocialConnection> accepted;
  final List<SocialConnection> pending;
  final WidgetRef ref;

  const _LoungeContent({required this.accepted, required this.pending, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Text(
            accepted.isEmpty
                ? 'No friends connected yet.\nSend an invite to get started!'
                : '${accepted.length} friend${accepted.length > 1 ? 's' : ''} connected.\n'
                    '${pending.isEmpty ? 'No pending requests.' : '${pending.length} pending invite${pending.length > 1 ? 's' : ''}.'}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, letterSpacing: -0.6, color: SpatialColors.textSecondary),
          ),
        ),
        const SizedBox(height: 40),
        if (pending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('PENDING INVITES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: SpatialColors.textMuted)),
            ),
          ),
          const SizedBox(height: 12),
          ...pending.map((c) => _PendingCard(
                connection: c,
                onAccept: () => ref.read(connectionsNotifierProvider.notifier).accept(c.connectionId),
                onReject: () => ref.read(connectionsNotifierProvider.notifier).reject(c.connectionId),
              )),
          const SizedBox(height: 32),
        ],
        if (accepted.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('YOUR CIRCLE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: SpatialColors.textMuted)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _FriendsMasonry(friends: accepted, ref: ref),
          ),
        ],
      ],
    );
  }
}

class _FriendsMasonry extends StatelessWidget {
  final List<SocialConnection> friends;
  final WidgetRef ref;
  const _FriendsMasonry({required this.friends, required this.ref});

  static const _rotations = [-3.0, 4.0, -1.5, 2.0, -2.5, 3.0];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: friends.indexed.map((e) {
        final (i, friend) = e;
        final rotation = _rotations[i % _rotations.length];
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: _FriendCard(
              connection: friend,
              index: i,
              onRemove: () => ref.read(connectionsNotifierProvider.notifier).remove(friend.connectionId),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final SocialConnection connection;
  final int index;
  final VoidCallback onRemove;
  const _FriendCard({required this.connection, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpatialColors.surfaceSubtle.withAlpha(128)),
        boxShadow: [BoxShadow(offset: const Offset(0, 20), blurRadius: 40, spreadRadius: -10, color: Colors.black.withAlpha(15))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: SpatialColors.surfaceMuted, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    _initials(connection.friendDisplayName),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: SpatialColors.textSecondary),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(onTap: onRemove, child: Icon(Icons.more_horiz, size: 16, color: SpatialColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connection.friendDisplayName.isNotEmpty ? connection.friendDisplayName : 'Friend',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: SpatialColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text('Connected', style: GoogleFonts.inter(fontSize: 10, color: SpatialColors.agentGreen)),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

class _PendingCard extends StatelessWidget {
  final SocialConnection connection;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _PendingCard({required this.connection, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SpatialColors.surfaceSubtle),
          boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: SpatialColors.agentPink.withAlpha(26), shape: BoxShape.circle),
              child: const Icon(Icons.person_add, size: 20, color: SpatialColors.agentPink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connection.friendDisplayName.isNotEmpty ? connection.friendDisplayName : 'New invite',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
                  ),
                  Text('Wants to connect', style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.textTertiary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAccept,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: SpatialColors.agentGreen.withAlpha(26), borderRadius: BorderRadius.circular(9999)),
                child: Text('Accept', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.agentGreen)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(onTap: onReject, child: Icon(Icons.close, size: 18, color: SpatialColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyLounge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        children: [
          Text('No connections yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: SpatialColors.textTertiary)),
          const SizedBox(height: 8),
          Text(
            'Connect with friends to see their updates here. Tap Find to add friends from your contacts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
