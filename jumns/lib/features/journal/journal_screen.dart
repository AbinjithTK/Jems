import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/journal_entry.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/widgets/agent_chat_input.dart';

// ── Journal entry model ──

enum _EntryKind { quote, snippet, thought, image, task, voice, taskDone }

class _JournalEntry {
  final String id;
  final String text;
  final String agent;
  final DateTime date;
  final String? imageUrl;
  final String? cardType;
  final _EntryKind kind;
  final List<String> tags;
  final bool shareable;
  final String? voiceDuration;

  _JournalEntry({
    required this.id,
    required this.text,
    required this.agent,
    required this.date,
    this.imageUrl,
    this.cardType,
    required this.kind,
    this.tags = const [],
    this.shareable = false,
    this.voiceDuration,
  });

  factory _JournalEntry.fromJournalEntry(JournalEntry e) {
    final content = e.content;
    final entryType = e.type;
    _EntryKind kind;
    List<String> tags = List<String>.from(e.tags);
    String? voiceDur;

    if (entryType == 'audio') {
      kind = _EntryKind.voice;
      voiceDur = '0:42';
      if (!tags.contains('Voice')) tags = ['Voice', ...tags];
    } else if (entryType == 'polaroid') {
      kind = _EntryKind.image;
      if (!tags.contains('Photo')) tags = ['Photo', ...tags];
    } else if (entryType == 'sticky') {
      kind = _EntryKind.snippet;
    } else if (entryType == 'reflection') {
      kind = _EntryKind.thought;
      if (!tags.contains('Reflection')) tags = ['Reflection', ...tags];
    } else if (tags.contains('Completed')) {
      kind = _EntryKind.taskDone;
    } else if (content.length < 60) {
      kind = _EntryKind.quote;
      if (tags.isEmpty) tags = ['Quick Note'];
    } else if (content.length < 140) {
      kind = _EntryKind.snippet;
    } else {
      kind = _EntryKind.thought;
      if (!tags.contains('Reflection')) tags = ['Reflection', ...tags];
    }
    if (e.shareable && !tags.contains('Shared')) tags = [...tags, 'Shared'];
    if (!tags.contains('Journal')) tags = [...tags, 'Journal'];
    return _JournalEntry(
      id: e.id, text: content, agent: 'echo', date: e.createdAt ?? DateTime.now(),
      imageUrl: e.mediaUrl, cardType: null, kind: kind, tags: tags,
      shareable: e.shareable, voiceDuration: voiceDur,
    );
  }

  String get agentColor => switch (agent) {
    'noor' => 'green', 'kai' => 'yellow',
    'sage' => 'pink', 'echo' => 'violet', _ => 'green',
  };
  String get agentLabel => switch (agent) {
    'noor' => 'Green Jum', 'kai' => 'Yellow Jum',
    'sage' => 'Pink Jum', 'echo' => 'Violet Jum', _ => 'Jum',
  };
  String get tldr => text.length <= 120 ? text : '${text.substring(0, 117)}...';
}

// ── Search state ──
final _searchQueryProvider = StateProvider<String>((ref) => '');

// ── Main screen ──

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(journalNotifierProvider);
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
            onRefresh: () => ref.read(journalNotifierProvider.notifier).load(),
            child: journalAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _JournalError(ref: ref),
              data: (entries) {
                final journalEntries = entries
                    .map((e) => _JournalEntry.fromJournalEntry(e))
                    .toList();
                if (journalEntries.isEmpty) return const _EmptyJournal();
                return _JournalBoard(entries: journalEntries);
              },
            ),
          ),
              ),
              const AgentChatInput(agentName: 'echo', agentColor: 'violet', hintText: 'Ask the journal...'),
            ],
          ),
          // Floating add journal button
          Positioned(
            right: 20,
            bottom: 100,
            child: _AddJournalFab(
              onTap: () => NewEntrySheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating action button for adding a new journal entry.
class _AddJournalFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddJournalFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SpatialColors.echoGradient,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 6),
              blurRadius: 20,
              color: const Color(0xFF8B5CF6).withAlpha(80),
            ),
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 6,
              color: Colors.black.withAlpha(15),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }
}

// ── Masonry board (mymind-inspired) ──

class _JournalBoard extends ConsumerWidget {
  final List<_JournalEntry> entries;
  const _JournalBoard({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider).toLowerCase();
    final filtered = query.isEmpty
        ? entries
        : entries.where((e) =>
            e.text.toLowerCase().contains(query) ||
            e.tags.any((t) => t.toLowerCase().contains(query)) ||
            e.agentLabel.toLowerCase().contains(query)).toList();

    return CustomScrollView(
      slivers: [
        // ── Search bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const AgentSphere(agentColor: 'violet', size: 28),
                const SizedBox(width: 10),
                Expanded(child: _SearchBar(ref: ref)),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Masonry grid ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(
            child: _WaterfallGrid(entries: filtered),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

// ── Search bar (mymind style) ──

class _SearchBar extends StatelessWidget {
  final WidgetRef ref;
  const _SearchBar({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: SpatialColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 18, color: SpatialColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
              style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textSecondary),
              decoration: InputDecoration(
                hintText: 'Find a thought...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waterfall masonry grid (2-column) ──

class _WaterfallGrid extends StatelessWidget {
  final List<_JournalEntry> entries;
  const _WaterfallGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Distribute entries into 2 columns by estimated height
    final List<_JournalEntry> left = [];
    final List<_JournalEntry> right = [];
    double leftH = 0, rightH = 0;

    for (final e in entries) {
      final h = _estimateHeight(e);
      if (leftH <= rightH) {
        left.add(e);
        leftH += h;
      } else {
        right.add(e);
        rightH += h;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Column(entries: left)),
        const SizedBox(width: 10),
        Expanded(child: _Column(entries: right)),
      ],
    );
  }

  double _estimateHeight(_JournalEntry e) => switch (e.kind) {
    _EntryKind.quote => 120,
    _EntryKind.snippet => 160,
    _EntryKind.thought => 220,
    _EntryKind.image => 240,
    _EntryKind.task => 140,
    _EntryKind.voice => 130,
    _EntryKind.taskDone => 140,
  };
}

class _Column extends StatelessWidget {
  final List<_JournalEntry> entries;
  const _Column({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildCard(context, e),
      )).toList(),
    );
  }

  Widget _buildCard(BuildContext ctx, _JournalEntry e) {
    final card = switch (e.kind) {
      _EntryKind.quote => _QuoteCard(entry: e),
      _EntryKind.snippet => _SnippetCard(entry: e),
      _EntryKind.thought => _ThoughtCard(entry: e),
      _EntryKind.image => _ImageCard(entry: e),
      _EntryKind.task => _TaskCard(entry: e),
      _EntryKind.voice => _VoiceCard(entry: e),
      _EntryKind.taskDone => _TaskDoneCard(entry: e),
    };
    return GestureDetector(
      onTap: () => _showDetail(ctx, e),
      child: Stack(
        children: [
          card,
          if (e.shareable) Positioned(top: 8, right: 8, child: _ShareableBadge()),
        ],
      ),
    );
  }

  void _showDetail(BuildContext ctx, _JournalEntry e) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalDetailSheet(entry: e),
    );
  }
}


// ── Quote card (yellow tint, short text — like mymind quotes) ──

class _QuoteCard extends StatelessWidget {
  final _JournalEntry entry;
  const _QuoteCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8).withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEF9C3)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8,
            color: Colors.black.withAlpha(8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28, fontWeight: FontWeight.w700,
              color: SpatialColors.agentColor(entry.agentColor).withAlpha(150),
              height: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: SpatialColors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _AgentPill(entry: entry),
        ],
      ),
    );
  }
}

// ── Snippet card (short text, white bg) ──

class _SnippetCard extends StatelessWidget {
  final _JournalEntry entry;
  const _SnippetCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8,
            color: Colors.black.withAlpha(8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: SpatialColors.textSecondary,
              height: 1.55,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _AgentPill(entry: entry),
        ],
      ),
    );
  }
}

// ── Thought card (longer reflection, subtle agent accent) ──

class _ThoughtCard extends StatelessWidget {
  final _JournalEntry entry;
  const _ThoughtCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = SpatialColors.agentColor(entry.agentColor);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpatialColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: Colors.black.withAlpha(8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width: 24, height: 3,
            decoration: BoxDecoration(
              color: accent.withAlpha(180),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: SpatialColors.textPrimary,
              height: 1.6,
            ),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AgentPill(entry: entry),
              const Spacer(),
              if (entry.tags.contains('Reflection'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Reflection',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


// ── Image card (polaroid style) ──

class _ImageCard extends StatelessWidget {
  final _JournalEntry entry;
  const _ImageCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 16,
            color: Colors.black.withAlpha(10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: entry.imageUrl != null && entry.imageUrl!.startsWith('http')
                  ? Image.network(entry.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
          ),
          // Caption
          if (entry.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                entry.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: SpatialColors.textSecondary, height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _AgentPill(entry: entry),
                if (entry.tags.contains('Shared')) ...[
                  const Spacer(),
                  Icon(Icons.share_rounded, size: 12, color: SpatialColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    'Shared',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: SpatialColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    color: SpatialColors.surfaceMuted,
    child: Center(
      child: Icon(Icons.image_rounded, size: 32, color: SpatialColors.textMuted),
    ),
  );
}

// ── Task card (verified task / goal) ──

class _TaskCard extends StatelessWidget {
  final _JournalEntry entry;
  const _TaskCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isGoal = entry.cardType == 'goal' || entry.cardType == 'goal_check_in';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpatialColors.surfaceMuted),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: 4,
            color: Colors.black.withAlpha(8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGoal
                      ? SpatialColors.agentColor(entry.agentColor).withAlpha(30)
                      : SpatialColors.checkBg,
                  border: Border.all(
                    color: isGoal
                        ? SpatialColors.agentColor(entry.agentColor)
                        : SpatialColors.verifiedBadgeText,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isGoal ? Icons.flag_rounded : Icons.check_rounded,
                  size: 12,
                  color: isGoal
                      ? SpatialColors.agentColor(entry.agentColor)
                      : SpatialColors.verifiedBadgeText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isGoal ? SpatialColors.proofBadgeBg : SpatialColors.verifiedBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGoal ? 'GOAL' : 'TASK',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: isGoal ? SpatialColors.proofBadgeText : SpatialColors.verifiedBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: SpatialColors.textPrimary, height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _AgentPill(entry: entry),
        ],
      ),
    );
  }
}


// ── Voice memo card (waveform style) ──

class _VoiceCard extends StatelessWidget {
  final _JournalEntry entry;
  const _VoiceCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = SpatialColors.agentColor(entry.agentColor);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(100)),
        boxShadow: [
          BoxShadow(offset: const Offset(0, 2), blurRadius: 10, color: Colors.black.withAlpha(8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withAlpha(25),
                ),
                child: Icon(Icons.play_arrow_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Memo',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: SpatialColors.textPrimary,
                      ),
                    ),
                    Text(
                      entry.voiceDuration ?? '0:42',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10, color: SpatialColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Waveform bars
          SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(18, (i) {
                final h = 6.0 + (((i * 7 + 3) % 11) / 11.0) * 18.0;
                return Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(80 + ((i * 13) % 120)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          if (entry.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: SpatialColors.textTertiary, height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _AgentPill(entry: entry),
        ],
      ),
    );
  }
}

// ── Task completed card (celebration style) ──

class _TaskDoneCard extends StatelessWidget {
  final _JournalEntry entry;
  const _TaskDoneCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = SpatialColors.agentColor(entry.agentColor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        boxShadow: [
          BoxShadow(offset: const Offset(0, 2), blurRadius: 8, color: Colors.black.withAlpha(6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF10B981), const Color(0xFF34D399)],
                  ),
                ),
                child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DONE',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: SpatialColors.textSecondary,
              decoration: TextDecoration.lineThrough,
              decorationColor: SpatialColors.textMuted,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _AgentPill(entry: entry),
        ],
      ),
    );
  }
}

// ── Shareable badge (frosted glass pill overlay) ──

class _ShareableBadge extends StatelessWidget {
  const _ShareableBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: Colors.white.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 10, color: SpatialColors.textTertiary),
              const SizedBox(width: 3),
              Text(
                'Shared',
                style: GoogleFonts.robotoMono(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: SpatialColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── New Entry bottom sheet ──

class NewEntrySheet extends StatelessWidget {
  const NewEntrySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: SpatialColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Capture a thought',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: SpatialColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What would you like to save?',
            style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary),
          ),
          const SizedBox(height: 20),
          _EntryOption(
            icon: Icons.edit_rounded,
            label: 'Text Entry',
            subtitle: 'Write a note, thought, or reflection',
            color: SpatialColors.agentViolet,
            onTap: () {
              Navigator.pop(context);
              _TextEntrySheet.show(context);
            },
          ),
          const SizedBox(height: 10),
          _EntryOption(
            icon: Icons.camera_alt_rounded,
            label: 'Photo Capture',
            subtitle: 'Save an image with a caption',
            color: SpatialColors.agentPink,
            onTap: () {
              Navigator.pop(context);
              _PhotoCaptureSheet.show(context);
            },
          ),
          const SizedBox(height: 10),
          _EntryOption(
            icon: Icons.mic_rounded,
            label: 'Voice Memo',
            subtitle: 'Record a quick voice note',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.pop(context);
              _VoiceMemoSheet.show(context);
            },
          ),
          const SizedBox(height: 10),
          _EntryOption(
            icon: Icons.check_circle_rounded,
            label: 'Mark Task Complete',
            subtitle: 'Log a completed task or goal',
            color: SpatialColors.agentGreen,
            onTap: () {
              Navigator.pop(context);
              _TaskCompleteSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}

class _EntryOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _EntryOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SpatialColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(20),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: SpatialColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11, color: SpatialColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: SpatialColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Relative date formatter for cards ──

String _formatCardDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  if (d.year == now.year) return '${months[d.month - 1]} ${d.day}';
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ── Agent pill (small label under cards) ──

class _AgentPill extends StatelessWidget {
  final _JournalEntry entry;
  final bool showDate;
  const _AgentPill({super.key, required this.entry, this.showDate = true});

  @override
  Widget build(BuildContext context) {
    final color = SpatialColors.agentColor(entry.agentColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          entry.agentLabel,
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: SpatialColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        if (showDate) ...[
          const SizedBox(width: 6),
          Text(
            '·',
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: SpatialColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatCardDate(entry.date),
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: SpatialColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Detail bottom sheet (mymind-inspired) ──

class _JournalDetailSheet extends ConsumerStatefulWidget {
  final _JournalEntry entry;
  const _JournalDetailSheet({super.key, required this.entry});

  @override
  ConsumerState<_JournalDetailSheet> createState() => _JournalDetailSheetState();
}

class _JournalDetailSheetState extends ConsumerState<_JournalDetailSheet> {
  late final TextEditingController _notesController;
  late List<String> _tags;
  bool _notesSaved = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _tags = List<String>.from(widget.entry.tags);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) return;
    // Save note as a new journal entry linked to this one
    await ref.read(journalNotifierProvider.notifier).create(
      content: 'Note: $text',
      type: 'thought',
      tags: const ['Note'],
    );
    setState(() => _notesSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note saved', style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: SpatialColors.agentViolet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteEntry() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete entry?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        content: Text(
          'This will remove this journal entry permanently.',
          style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: SpatialColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(journalNotifierProvider.notifier).delete(widget.entry.id);
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close detail sheet
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _shareEntry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing coming soon', style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: SpatialColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addTag() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Tag', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: tagController,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tag name',
            hintStyle: GoogleFonts.inter(color: SpatialColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: SpatialColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              final tag = tagController.text.trim();
              if (tag.isNotEmpty) {
                setState(() => _tags.add(tag));
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.inter(color: SpatialColors.agentViolet, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final accent = SpatialColors.agentColor(entry.agentColor);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: SpatialColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 8),
                  // Agent + date header
                  Row(
                    children: [
                      AgentSphere(agentColor: entry.agentColor, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.agentLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          Text(
                            _formatDate(entry.date),
                            style: GoogleFonts.inter(
                              fontSize: 11, color: SpatialColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Full content
                  Text(
                    entry.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: SpatialColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TLDR section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        left: BorderSide(color: accent, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TLDR',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.tldr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: SpatialColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tags section
                  Text(
                    'MIND TAGS',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: SpatialColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._tags.map((t) => _TagChip(label: t, color: accent)),
                      _TagChip(label: '+ Add tag', color: accent, isAdd: true, onTap: _addTag),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Notes section
                  Text(
                    'MIND NOTES',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: SpatialColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SpatialColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: SpatialColors.textSecondary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a note...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: SpatialColors.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() => _notesSaved = false),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _saveNote,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _notesSaved
                                    ? SpatialColors.agentGreen.withAlpha(20)
                                    : accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(
                                  color: _notesSaved
                                      ? SpatialColors.agentGreen.withAlpha(80)
                                      : accent.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _notesSaved ? Icons.check_rounded : Icons.save_outlined,
                                    size: 14,
                                    color: _notesSaved ? SpatialColors.agentGreen : accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _notesSaved ? 'Saved' : 'Save Note',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _notesSaved ? SpatialColors.agentGreen : accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24 + bottomPad),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPad),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: SpatialColors.surfaceMuted)),
              ),
              child: Row(
                children: [
                  _ActionButton(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: _deleteEntry),
                  const SizedBox(width: 16),
                  _ActionButton(icon: Icons.share_outlined, label: 'Share', onTap: _shareEntry),
                  const Spacer(),
                  // Color dots (visual indicator only — agent color is set by the AI)
                  ...[
                    SpatialColors.agentGreen,
                    SpatialColors.agentYellow,
                    SpatialColors.agentPink,
                    SpatialColors.agentViolet,
                  ].map((c) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Agent color is assigned automatically', style: GoogleFonts.inter(fontSize: 13)),
                            backgroundColor: SpatialColors.textSecondary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: c == SpatialColors.agentColor(entry.agentColor)
                              ? Border.all(color: SpatialColors.textPrimary, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Tag chip ──

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isAdd;
  final VoidCallback? onTap;
  const _TagChip({required this.label, required this.color, this.isAdd = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAdd ? color.withAlpha(20) : SpatialColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isAdd ? color.withAlpha(80) : SpatialColors.surfaceMuted.withAlpha(120),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isAdd ? color : SpatialColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Action button (bottom bar) ──

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: SpatialColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: SpatialColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AgentSphere(agentColor: 'violet', size: 64),
            const SizedBox(height: 20),
            Text(
              'Your mind is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: SpatialColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation and your thoughts\nwill appear here as journal entries.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13, color: SpatialColors.textTertiary, height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ──

class _JournalError extends StatelessWidget {
  final WidgetRef ref;
  const _JournalError({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: SpatialColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load your journal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: SpatialColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.read(journalNotifierProvider.notifier).load(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: SpatialColors.agentViolet.withAlpha(20),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'Try again',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: SpatialColors.agentViolet,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Text Entry Sheet ──
// ══════════════════════════════════════════════════════════════════════════════

class _TextEntrySheet extends ConsumerStatefulWidget {
  const _TextEntrySheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TextEntrySheet(),
    );
  }

  @override
  ConsumerState<_TextEntrySheet> createState() => _TextEntrySheetState();
}

class _TextEntrySheetState extends ConsumerState<_TextEntrySheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await ref.read(journalNotifierProvider.notifier).create(
      content: text,
      type: 'thought',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset + bottomPad),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: SpatialColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpatialColors.agentViolet.withAlpha(25),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: SpatialColors.agentViolet),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'New Thought',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: SpatialColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SpatialColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  minLines: 3,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: SpatialColors.textPrimary, height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: SpatialColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _sending ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: SpatialColors.echoGradient,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Save to Journal',
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Photo Capture Sheet ──
// ══════════════════════════════════════════════════════════════════════════════

class _PhotoCaptureSheet extends ConsumerStatefulWidget {
  const _PhotoCaptureSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhotoCaptureSheet(),
    );
  }

  @override
  ConsumerState<_PhotoCaptureSheet> createState() => _PhotoCaptureSheetState();
}

class _PhotoCaptureSheetState extends ConsumerState<_PhotoCaptureSheet> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  File? _imageFile;
  bool _sending = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (_imageFile == null) return;
    setState(() => _sending = true);
    final caption = _captionController.text.trim();
    await ref.read(journalNotifierProvider.notifier).createWithImage(
      imageFile: _imageFile!,
      caption: caption.isEmpty ? 'Journal photo' : caption,
      type: 'polaroid',
      tags: const ['Photo'],
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset + bottomPad),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: SpatialColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpatialColors.agentPink.withAlpha(25),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: SpatialColors.agentPink),
              ),
              const SizedBox(width: 10),
              Text(
                'Photo Capture',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: SpatialColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Image preview or pick buttons
          if (_imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(_imageFile!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _imageFile = null),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.agentPink),
                ),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: SpatialColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 28, color: SpatialColors.agentPink),
                          const SizedBox(height: 6),
                          Text('Camera', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: SpatialColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_rounded, size: 28, color: SpatialColors.agentViolet),
                          const SizedBox(height: 6),
                          Text('Gallery', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          // Caption input
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpatialColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
            ),
            child: TextField(
              controller: _captionController,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: SpatialColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: SpatialColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: (_sending || _imageFile == null) ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _imageFile != null ? SpatialColors.echoGradient : null,
                  color: _imageFile == null ? SpatialColors.surfaceMuted : null,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Save to Journal',
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _imageFile != null ? Colors.white : SpatialColors.textMuted,
                          ),
                        ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// ── Voice Memo Sheet ──
// ══════════════════════════════════════════════════════════════════════════════

class _VoiceMemoSheet extends ConsumerStatefulWidget {
  const _VoiceMemoSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VoiceMemoSheet(),
    );
  }

  @override
  ConsumerState<_VoiceMemoSheet> createState() => _VoiceMemoSheetState();
}

class _VoiceMemoSheetState extends ConsumerState<_VoiceMemoSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _sending = false;
  String _transcription = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
        return;
      }
      setState(() {
        _isListening = true;
        _transcription = '';
      });
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _transcription = result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
    }
  }

  Future<void> _save() async {
    if (_transcription.trim().isEmpty) return;
    setState(() => _sending = true);
    await ref.read(journalNotifierProvider.notifier).create(
      content: _transcription.trim(),
      type: 'audio',
      tags: const ['Voice'],
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset + bottomPad),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: SpatialColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B5CF6).withAlpha(25),
                    ),
                    child: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Voice Memo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: SpatialColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Transcription area
              Container(
                constraints: const BoxConstraints(minHeight: 100),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SpatialColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                ),
                child: Text(
                  _transcription.isEmpty
                      ? (_isListening ? 'Listening...' : 'Tap the mic to start speaking')
                      : _transcription,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: _transcription.isEmpty ? SpatialColors.textMuted : SpatialColors.textPrimary,
                    height: 1.6,
                    fontStyle: _transcription.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Mic button
              Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? const LinearGradient(colors: [Color(0xFFF472B6), Color(0xFFEC4899)])
                          : SpatialColors.echoGradient,
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 6),
                          blurRadius: 20,
                          color: (_isListening ? const Color(0xFFF472B6) : const Color(0xFF8B5CF6)).withAlpha(80),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 28, color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_isListening)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap to stop',
                      style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.textTertiary),
                    ),
                  ),
                ),
              if (!_isAvailable)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Speech recognition unavailable',
                      style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.agentPink),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Save button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: (_sending || _transcription.trim().isEmpty) ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _transcription.trim().isNotEmpty ? SpatialColors.echoGradient : null,
                      color: _transcription.trim().isEmpty ? SpatialColors.surfaceMuted : null,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Save to Journal',
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: _transcription.trim().isNotEmpty ? Colors.white : SpatialColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// ── Task Complete Sheet ──
// ══════════════════════════════════════════════════════════════════════════════

class _TaskCompleteSheet extends ConsumerStatefulWidget {
  const _TaskCompleteSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TaskCompleteSheet(),
    );
  }

  @override
  ConsumerState<_TaskCompleteSheet> createState() => _TaskCompleteSheetState();
}

class _TaskCompleteSheetState extends ConsumerState<_TaskCompleteSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await ref.read(journalNotifierProvider.notifier).create(
      content: text,
      type: 'thought',
      tags: const ['Completed'],
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset + bottomPad),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: SpatialColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpatialColors.agentGreen.withAlpha(25),
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 16, color: SpatialColors.agentGreen),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mark Complete',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: SpatialColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SpatialColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(120)),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: SpatialColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'What did you complete?',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: SpatialColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _sending ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Mark as Done',
                                  style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
