import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/goal.dart';
import '../../core/models/task.dart';
import '../../core/providers/agent_chat_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../tasks/task_detail_sheet.dart';

/// Tasks filtered by a specific goal ID.
final _goalTasksProvider =
    FutureProvider.family<List<Task>, String>((ref, goalId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get('/api/tasks', query: {'goalId': goalId});
  final list = json as List<dynamic>;
  return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
});

class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  bool _showChat = false;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    ref.read(agentChatProvider('kai').notifier).send(text);
    setState(() => _showChat = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _decompose(Goal goal) {
    ref.read(agentChatProvider('kai').notifier).send(
          'Decompose this goal into a detailed plan with small daily tasks: '
          '"${goal.title}" (category: ${goal.category}). '
          'Break it into milestones and actionable steps I can do each day.',
        );
    setState(() => _showChat = true);
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(goalProvider(widget.goalId));
    final tasksAsync = ref.watch(_goalTasksProvider(widget.goalId));
    final chatState = ref.watch(agentChatProvider('kai'));
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: goalAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text('Could not load goal',
              style: GoogleFonts.inter(color: SpatialColors.textTertiary)),
        ),
        data: (goal) {
          if (goal == null) {
            return Center(
              child: Text('Goal not found',
                  style: GoogleFonts.inter(color: SpatialColors.textTertiary)),
            );
          }
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // App bar
                    SliverAppBar(
                      backgroundColor: SpatialColors.background,
                      surfaceTintColor: Colors.transparent,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: SpatialColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: Text(
                        'Goal',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: SpatialColors.textPrimary,
                        ),
                      ),
                      centerTitle: true,
                      pinned: true,
                    ),
                    // Goal card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: SpatialColors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border:
                                Border.all(color: SpatialColors.surfaceSubtle),
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0, 10),
                                blurRadius: 25,
                                spreadRadius: -5,
                                color: Colors.black.withAlpha(10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(goal.categoryEmoji,
                                      style: const TextStyle(fontSize: 32)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      goal.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: SpatialColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9999),
                                child: LinearProgressIndicator(
                                  value: goal.progressFraction,
                                  backgroundColor: SpatialColors.surfaceMuted,
                                  valueColor: const AlwaysStoppedAnimation(
                                      SpatialColors.agentGreen),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    goal.progressText,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: SpatialColors.agentGreen,
                                    ),
                                  ),
                                  Text(
                                    '${(goal.progressFraction * 100).toInt()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: SpatialColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              if (goal.streakDays > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        SpatialColors.agentYellow.withAlpha(30),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🔥',
                                          style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${goal.streakDays} day streak',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Decompose button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: GestureDetector(
                          onTap: () => _decompose(goal),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  SpatialColors.agentYellow.withAlpha(30),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                  color: SpatialColors.agentYellow
                                      .withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const AgentDot(
                                    agentColor: 'yellow', size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Plan this goal',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Linked tasks header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Text(
                          'LINKED TASKS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: SpatialColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    // Linked tasks list
                    SliverToBoxAdapter(
                      child: tasksAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child:
                              Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load tasks',
                            style: GoogleFonts.inter(
                                color: SpatialColors.textTertiary),
                          ),
                        ),
                        data: (tasks) {
                          if (tasks.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              child: Text(
                                'No tasks linked to this goal yet. Tap above to plan it!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: SpatialColors.textTertiary,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: tasks
                                  .map((t) => _GoalTaskTile(
                                        task: t,
                                        onTap: () => TaskDetailSheet.show(
                                            context, t),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    // Chat history (if expanded)
                    if (_showChat && chatState.messages.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KAI',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: SpatialColors.agentColor('yellow'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...chatState.messages.map((m) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: m.role == 'user'
                                            ? SpatialColors.userBubble
                                            : SpatialColors.surfaceSubtle
                                                .withAlpha(200),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        m.content,
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: m.role == 'user'
                                              ? Colors.white
                                              : SpatialColors.textPrimary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  )),
                              if (chatState.isLoading)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const AgentDot(
                                          agentColor: 'yellow', size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Kai is thinking...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color:
                                              SpatialColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                        child: SizedBox(height: 100 + bottomPad)),
                  ],
                ),
              ),
              // Bottom chat input
              _GoalChatInput(
                controller: _chatController,
                isLoading: chatState.isLoading,
                onSend: _sendChat,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact task tile for the goal detail linked tasks list.
class _GoalTaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const _GoalTaskTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: SpatialColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SpatialColors.surfaceSubtle),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withAlpha(10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.completed
                      ? SpatialColors.agentGreen
                      : SpatialColors.surfaceMuted,
                  border: Border.all(
                    color: task.completed
                        ? SpatialColors.agentGreen
                        : SpatialColors.surfaceMuted,
                    width: 2,
                  ),
                ),
                child: task.completed
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: task.completed
                        ? SpatialColors.textTertiary
                        : SpatialColors.textSecondary,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: SpatialColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism chat input at the bottom of goal detail.
class _GoalChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _GoalChatInput({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 8 + bottomPad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SpatialColors.inputGlassBg,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(12, 12),
                  blurRadius: 24,
                  color: Colors.black.withAlpha(13),
                ),
                const BoxShadow(
                  offset: Offset(-12, -12),
                  blurRadius: 24,
                  color: Colors.white,
                ),
              ],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: AgentDot(agentColor: 'yellow', size: 28),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isLoading,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SpatialColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about this goal...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: SpatialColors.textTertiary.withAlpha(128),
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                GestureDetector(
                  onTap: isLoading ? null : onSend,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpatialColors.agentColor('yellow')
                          .withAlpha(isLoading ? 60 : 200),
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
