import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/task.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/reminders_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/widgets/agent_chat_input.dart';
import '../tasks/task_detail_sheet.dart';
import 'create_task_dialog.dart';
import 'create_reminder_dialog.dart';
import 'create_goal_dialog.dart';

/// Active filter tab index.
final _filterProvider = StateProvider<int>((ref) => 0);

/// Whether the calendar popup is visible.
final _calendarOpenProvider = StateProvider<bool>((ref) => false);

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final calendarOpen = ref.watch(_calendarOpenProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(tasksNotifierProvider.notifier).load(),
                ref.read(remindersNotifierProvider.notifier).load(),
                ref.read(goalsNotifierProvider.notifier).load(),
              ]);
            },
            child: CustomScrollView(
              slivers: [
            // Compact header with calendar button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const AgentSphere(agentColor: 'yellow', size: 32),
                    const SizedBox(width: 10),
                    Text(
                      'SCHEDULE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: SpatialColors.agentColor('yellow'),
                      ),
                    ),
                    const Spacer(),
                    // Calendar toggle button
                    GestureDetector(
                      onTap: () => ref.read(_calendarOpenProvider.notifier).state = !calendarOpen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: calendarOpen
                              ? SpatialColors.agentYellow.withAlpha(40)
                              : SpatialColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: calendarOpen
                                ? SpatialColors.agentYellow.withAlpha(120)
                                : SpatialColors.surfaceMuted.withAlpha(128),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              calendarOpen ? Icons.calendar_month_rounded : Icons.calendar_today_rounded,
                              size: 16,
                              color: calendarOpen ? const Color(0xFF92400E) : SpatialColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM d').format(selectedDate),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: calendarOpen ? const Color(0xFF92400E) : SpatialColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Collapsible calendar
            if (calendarOpen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SpatialColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SpatialColors.surfaceSubtle),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 10),
                          blurRadius: 25,
                          spreadRadius: -5,
                          color: Colors.black.withAlpha(10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: SpatialColors.agentYellow,
                            onPrimary: const Color(0xFF1E293B),
                            surface: SpatialColors.surface,
                            onSurface: SpatialColors.textPrimary,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          onDateChanged: (date) {
                            ref.read(selectedDateProvider.notifier).state = date;
                            ref.read(_calendarOpenProvider.notifier).state = false;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!calendarOpen)
              // Compact date selector (5-day strip)
              SliverToBoxAdapter(child: _DateSelector(ref: ref)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            // Filter tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _FilterTabs(
                  selected: filter,
                  onChanged: (i) => ref.read(_filterProvider.notifier).state = i,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            // Task list
            _TaskList(filter: filter, ref: ref),
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
              ),
              const AgentChatInput(agentName: 'kai', agentColor: 'yellow', hintText: 'Ask the planner...'),
            ],
          ),
      // Floating add button
      Positioned(
        right: 24,
        bottom: 100,
        child: GestureDetector(
          onTap: () {
            switch (filter) {
              case 0:
                CreateTaskDialog.show(context);
              case 1:
                CreateReminderDialog.show(context);
              case 2:
                CreateGoalDialog.show(context);
            }
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SpatialColors.agentYellow,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 8),
                  blurRadius: 20,
                  spreadRadius: -4,
                  color: const Color(0xFFFEF08A).withAlpha(180),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, size: 28, color: Color(0xFF1E293B)),
          ),
        ),
      ),
    ],
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final WidgetRef ref;
  const _DateSelector({required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDateProvider);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final date = today.add(Duration(days: i));
          final isActive = _sameDay(date, selected);
          final dayAbbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

          return GestureDetector(
            onTap: () => ref.read(selectedDateProvider.notifier).state = date,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    dayAbbr,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? SpatialColors.textPrimary : SpatialColors.textTertiary,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SpatialColors.agentYellow,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 10),
                          blurRadius: 15,
                          spreadRadius: -3,
                          color: const Color(0xFFFEF08A).withAlpha(128),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: SpatialColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _FilterTabs({required this.selected, required this.onChanged});

  static const _labels = ['Tasks', 'Reminders', 'Goals'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: SpatialColors.surfaceSubtle.withAlpha(128),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: SpatialColors.surfaceMuted.withAlpha(128)),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: isActive
                    ? BoxDecoration(
                        color: SpatialColors.agentYellow,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                            color: const Color(0xFFFEF08A).withAlpha(128),
                          ),
                        ],
                      )
                    : null,
                child: Center(
                  child: Text(
                    _labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? const Color(0xFF1E293B) : SpatialColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final int filter;
  final WidgetRef ref;

  const _TaskList({required this.filter, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (filter == 0) {
      return _buildTaskCards();
    } else if (filter == 1) {
      return _buildReminderCards();
    } else {
      return _buildGoalCards();
    }
  }

  Widget _buildTaskCards() {
    final tasksForDate = ref.watch(tasksForDateProvider);
    return SliverToBoxAdapter(
      child: tasksForDate.when(
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        )),
        error: (_, __) => _ErrorRetry(
          message: 'Could not load tasks',
          color: SpatialColors.agentYellow,
          onRetry: () => ref.read(tasksNotifierProvider.notifier).load(),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _EmptyState(
              message: 'No tasks for today',
              buttonLabel: 'Add Task',
              onTap: () => CreateTaskDialog.show(ref.context),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: tasks.map((t) => Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                onDismissed: (_) => ref.read(tasksNotifierProvider.notifier).delete(t.id),
                child: _SpatialTaskCard(task: t, ref: ref),
              )).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReminderCards() {
    final remindersAsync = ref.watch(remindersNotifierProvider);
    return SliverToBoxAdapter(
      child: remindersAsync.when(
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        )),
        error: (_, __) => _ErrorRetry(
          message: 'Could not load reminders',
          color: SpatialColors.agentYellow,
          onRetry: () => ref.read(remindersNotifierProvider.notifier).load(),
        ),
        data: (reminders) {
          final active = reminders.where((r) => r.active).toList();
          if (active.isEmpty) {
            return _EmptyState(
              message: 'No active reminders',
              buttonLabel: 'Add Reminder',
              onTap: () => CreateReminderDialog.show(ref.context),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: active.map((r) => Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                onDismissed: (_) => ref.read(remindersNotifierProvider.notifier).delete(r.id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      color: SpatialColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SpatialColors.surfaceSubtle),
                      boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(r.time, style: GoogleFonts.inter(fontSize: 12, color: SpatialColors.textTertiary)),
                              ),
                              if (r.isSnoozed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Snoozed ${r.snoozeCount}x',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: SpatialColors.agentYellow),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Snooze button
                        GestureDetector(
                          onTap: () => ref.read(remindersNotifierProvider.notifier).snooze(r.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SpatialColors.surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.snooze_rounded, size: 16, color: SpatialColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.notifications_active_outlined, size: 20, color: SpatialColors.agentYellow),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalCards() {
    final goalsAsync = ref.watch(goalsNotifierProvider);
    return SliverToBoxAdapter(
      child: goalsAsync.when(
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        )),
        error: (_, __) => _ErrorRetry(
          message: 'Could not load goals',
          color: SpatialColors.agentYellow,
          onRetry: () => ref.read(goalsNotifierProvider.notifier).load(),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyState(
              message: 'No goals yet',
              buttonLabel: 'Add Goal',
              onTap: () => CreateGoalDialog.show(ref.context),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: goals.map((g) => Dismissible(
                key: ValueKey(g.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                onDismissed: (_) => ref.read(goalsNotifierProvider.notifier).delete(g.id),
                child: GestureDetector(
                  onTap: () => ref.context.push('/goal/${g.id}'),
                  child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      color: SpatialColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SpatialColors.surfaceSubtle),
                      boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
                    ),
                    child: Row(
                      children: [
                        Text(g.categoryEmoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9999),
                                child: LinearProgressIndicator(
                                  value: g.progressFraction,
                                  backgroundColor: SpatialColors.surfaceMuted,
                                  valueColor: const AlwaysStoppedAnimation(SpatialColors.agentGreen),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(g.progressText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: SpatialColors.agentGreen)),
                      ],
                    ),
                  ),
                ),
                ),
              )).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _SpatialTaskCard extends StatelessWidget {
  final Task task;
  final WidgetRef ref;

  const _SpatialTaskCard({required this.task, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hasProof = task.type == 'habit' || task.requiresProof;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => TaskDetailSheet.show(context, task),
        child: Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SpatialColors.surfaceSubtle),
          boxShadow: [
            BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SpatialColors.textSecondary,
                            decoration: task.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (hasProof) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: SpatialColors.proofBadgeBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: SpatialColors.proofBadgeBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, size: 10, color: SpatialColors.proofBadgeText),
                              const SizedBox(width: 4),
                              Text(
                                'PROOF REQUIRED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: SpatialColors.proofBadgeText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        task.dueDate!,
                        style: GoogleFonts.inter(fontSize: 12, color: SpatialColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
            // Checkbox
            GestureDetector(
              onTap: () => ref.read(tasksNotifierProvider.notifier).complete(task.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SpatialColors.surfaceMuted, width: 2),
                ),
                child: task.completed
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: SpatialColors.agentGreen,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: SpatialColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(2),
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

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Reusable empty state with a soft create button.
class _EmptyState extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const _EmptyState({
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 15, color: SpatialColors.textTertiary),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: SpatialColors.agentYellow.withAlpha(30),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: SpatialColors.agentYellow.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: const Color(0xFF92400E)),
                  const SizedBox(width: 6),
                  Text(
                    buttonLabel,
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
        ],
      ),
    );
  }
}

/// Reusable error state with retry button.
class _ErrorRetry extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback onRetry;

  const _ErrorRetry({
    required this.message,
    required this.color,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: SpatialColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 15, color: SpatialColors.textTertiary),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Text('Retry', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ),
          ),
        ],
      ),
    );
  }
}
