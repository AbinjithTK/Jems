import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/goal.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/providers/agent_actions_provider.dart';
import '../../core/theme/jems_colors.dart';
import '../../core/theme/charcoal_decorations.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsNotifierProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(goalsNotifierProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.rotate(
                          angle: -1 * math.pi / 180,
                          child: Text('My Goals',
                              style: GoogleFonts.gloriaHallelujah(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: JemsColors.charcoal)),
                        ),
                        Transform.rotate(
                          angle: 1 * math.pi / 180,
                          child: Text('Focus on what matters',
                              style: GoogleFonts.architectsDaughter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: JemsColors.ink.withAlpha(130))),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showAddGoalDialog(context, ref),
                      child: BlobShape(
                        color: JemsColors.surface,
                        size: 40,
                        child: const Icon(Icons.add,
                            color: JemsColors.charcoal, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: DashedSeparator(),
              ),
            ),

            // ── Active Goals section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: CharcoalSectionHeader(
                  title: 'Active Goals',
                  trailing: goalsAsync.whenOrNull(
                    data: (g) => '${g.where((x) => !x.completed).length} In Progress',
                  ),
                ),
              ),
            ),

            // ── Goal cards ──
            SliverToBoxAdapter(
              child: goalsAsync.when(
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator())),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('Could not load goals',
                        style: GoogleFonts.architectsDaughter(
                            color: JemsColors.ink.withAlpha(130),
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                data: (goals) {
                  final active = goals.where((g) => !g.completed).toList();
                  if (active.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text('No active goals yet',
                            style: GoogleFonts.architectsDaughter(
                                color: JemsColors.ink.withAlpha(130),
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: active.indexed.map((e) {
                        final (i, goal) = e;
                        return _GoalCard(goal: goal, index: i);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),

            // ── Weekly Progress section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: CharcoalSectionHeader(
                  title: 'Weekly Progress',
                  rotation: 1,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WeeklyProgressChart(),
              ),
            ),

            // ── Smart Suggestions from Agent ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: CharcoalSectionHeader(
                  title: 'AI Suggestions',
                  rotation: -1,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SmartSuggestionsCard(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Goal',
            style: GoogleFonts.gloriaHallelujah(color: JemsColors.charcoal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: categoryCtrl,
              decoration:
                  const InputDecoration(labelText: 'Category (e.g. Health)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                ref.read(goalsNotifierProvider.notifier).create(
                      title: titleCtrl.text,
                      category: categoryCtrl.text.isEmpty
                          ? 'General'
                          : categoryCtrl.text,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Card with blob behind + charcoal border ───

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final int index;
  const _GoalCard({required this.goal, required this.index});

  static const _blobColors = [
    JemsColors.mint,
    JemsColors.markerBlue,
    JemsColors.amber,
    JemsColors.lavender,
    JemsColors.coral,
  ];

  @override
  Widget build(BuildContext context) {
    final blobColor = _blobColors[index % _blobColors.length];
    final rotation = index.isEven ? -1.0 : 1.0;

    return CharcoalCard(
      blobColor: blobColor,
      rotation: rotation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BlobShape(
                color: blobColor.withAlpha(130),
                size: 40,
                variant: index % 4,
                child: Text(goal.categoryEmoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              if (goal.priority != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: JemsColors.charcoal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(goal.priority!,
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.paper)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.gloriaHallelujah(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: JemsColors.charcoal)),
          const SizedBox(height: 4),
          Text(goal.progressText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.architectsDaughter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.ink.withAlpha(150))),
          if (goal.insight.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(goal.insight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.architectsDaughter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: JemsColors.ink.withAlpha(120))),
          ],
          const SizedBox(height: 14),
          CharcoalProgressBar(
            progress: goal.progressFraction,
            fillColor: blobColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${goal.progress}%',
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.charcoal)),
              if (goal.streakDays > 0)
                Text('${goal.streakDays} days streak!',
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: JemsColors.charcoal)),
            ],
          ),
          // ── Agent action buttons ──
          const SizedBox(height: 12),
          Row(
            children: [
              _GoalActionButton(
                label: 'Analyze',
                icon: Icons.insights,
                onTap: () => _showAnalysis(context),
              ),
              const SizedBox(width: 8),
              _GoalActionButton(
                label: 'Adapt',
                icon: Icons.auto_fix_high,
                onTap: () => _showAdaptation(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAnalysis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JemsColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final adaptAsync = ref.watch(adaptGoalProvider(goal.id));
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: JemsColors.ink.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Goal Analysis',
                    style: GoogleFonts.gloriaHallelujah(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: JemsColors.charcoal)),
                const SizedBox(height: 4),
                Text(goal.title,
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: JemsColors.ink.withAlpha(150))),
                const SizedBox(height: 16),
                adaptAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Could not analyze: $e',
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.coral)),
                  data: (data) => _AnalysisResult(data: data),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAdaptation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JemsColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final rescheduleAsync = ref.watch(rescheduleGoalProvider(goal.id));
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: JemsColors.ink.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Adapt Plan',
                    style: GoogleFonts.gloriaHallelujah(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: JemsColors.charcoal)),
                const SizedBox(height: 4),
                Text(goal.title,
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: JemsColors.ink.withAlpha(150))),
                const SizedBox(height: 16),
                rescheduleAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Could not adapt: $e',
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.coral)),
                  data: (data) {
                    final count = data['rescheduledCount'] as int? ?? 0;
                    final tasks = data['tasks'] as List? ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count > 0
                              ? '$count overdue tasks rescheduled'
                              : 'No overdue tasks to reschedule',
                          style: GoogleFonts.architectsDaughter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: JemsColors.charcoal),
                        ),
                        if (tasks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...tasks.take(5).map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule,
                                        size: 14,
                                        color: JemsColors.ink.withAlpha(130)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${t['title']} → ${t['newDate']}',
                                        style: GoogleFonts.architectsDaughter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: JemsColors.ink),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Weekly Progress Chart (real data from API) ───

class _WeeklyProgressChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(weeklyProgressProvider);

    return progressAsync.when(
      loading: () => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: charcoalBorderDecoration(fill: JemsColors.paper),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: charcoalBorderDecoration(fill: JemsColors.paper),
        child: Center(
          child: Text('Could not load progress',
              style: GoogleFonts.architectsDaughter(
                  color: JemsColors.ink.withAlpha(130),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      data: (wp) => _buildChart(wp),
    );
  }

  Widget _buildChart(WeeklyProgress wp) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxCount = wp.counts.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: charcoalBorderDecoration(fill: JemsColors.paper),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isBest = i == wp.bestDay && wp.total > 0;
                final heightFactor =
                    maxCount > 0 ? wp.counts[i] / maxCount : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: JemsColors.charcoal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Best!',
                                style: GoogleFonts.architectsDaughter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: JemsColors.paper)),
                          ),
                        if (isBest) const SizedBox(height: 4),
                        if (wp.counts[i] > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text('${wp.counts[i]}',
                                style: GoogleFonts.gloriaHallelujah(
                                    fontSize: 10,
                                    color: JemsColors.charcoal)),
                          ),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: heightFactor.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isBest
                                    ? JemsColors.mint
                                    : JemsColors.lavender.withAlpha(130),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: JemsColors.ink, width: 2),
                                boxShadow: isBest
                                    ? const [
                                        BoxShadow(
                                          color: JemsColors.borderShadow,
                                          offset: Offset(2, 2),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(days[i],
                            style: GoogleFonts.architectsDaughter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: JemsColors.ink)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          const DashedSeparator(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.ink.withAlpha(150)),
                  children: [
                    const TextSpan(text: 'Total tasks: '),
                    TextSpan(
                      text: '${wp.total}',
                      style: GoogleFonts.gloriaHallelujah(
                          fontSize: 18, color: JemsColors.charcoal),
                    ),
                  ],
                ),
              ),
              Text('View Report',
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.charcoal,
                      decoration: TextDecoration.underline)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Smart Suggestions Card (placeholder for AI-generated suggestions) ───

class _SmartSuggestionsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: JemsColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JemsColors.ink.withAlpha(40), width: 2),
        boxShadow: const [
          BoxShadow(color: JemsColors.borderShadow, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: JemsColors.amber),
              const SizedBox(width: 8),
              Text('AI Suggestions',
                  style: GoogleFonts.gloriaHallelujah(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: JemsColors.charcoal)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Based on your progress, try breaking large goals into smaller milestones.',
            style: GoogleFonts.architectsDaughter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: JemsColors.ink.withAlpha(180)),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Action Button ───

class _GoalActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GoalActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: JemsColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JemsColors.ink.withAlpha(60), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: JemsColors.charcoal),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.architectsDaughter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: JemsColors.charcoal)),
          ],
        ),
      ),
    );
  }
}

// ─── Analysis Result (displayed inside the analysis bottom sheet) ───

class _AnalysisResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalysisResult({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as String? ?? 'Analysis complete.';
    final suggestions = (data['suggestions'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary,
            style: GoogleFonts.architectsDaughter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: JemsColors.charcoal)),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: GoogleFonts.architectsDaughter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: JemsColors.ink)),
                    Expanded(
                      child: Text(s,
                          style: GoogleFonts.architectsDaughter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: JemsColors.ink.withAlpha(180))),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
