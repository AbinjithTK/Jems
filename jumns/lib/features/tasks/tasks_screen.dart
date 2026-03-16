import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/task.dart';
import '../../core/models/reminder.dart';
import '../../core/models/proactive_insight.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/reminders_provider.dart';
import '../../core/providers/insights_provider.dart';
import '../../core/theme/jems_colors.dart';
import '../../core/theme/charcoal_decorations.dart';
import 'proof_capture_sheet.dart';

/// Selected segment on the Tasks screen.
final _segmentProvider = StateProvider<int>((ref) => 0);

/// Whether the calendar is expanded.
final _calendarExpandedProvider = StateProvider<bool>((ref) => false);

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(_segmentProvider);
    final remindersAsync = ref.watch(remindersNotifierProvider);
    final insightsAsync = ref.watch(insightsNotifierProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(tasksNotifierProvider.notifier).load(),
            ref.read(remindersNotifierProvider.notifier).load(),
            ref.read(insightsNotifierProvider.notifier).load(),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(child: _Header(segment: segment, ref: ref)),

            // ── Date carousel ──
            SliverToBoxAdapter(child: _DateCarousel(ref: ref)),

            // ── Expandable calendar ──
            SliverToBoxAdapter(child: _ExpandableCalendar(ref: ref)),

            // ── Proactive insight banner ──
            SliverToBoxAdapter(
              child: insightsAsync.whenOrNull(
                    data: (insights) {
                      final unread =
                          insights.where((i) => !i.read && !i.dismissed);
                      if (unread.isEmpty) return const SizedBox.shrink();
                      return _InsightBanner(
                        insight: unread.first,
                        onDismiss: () => ref
                            .read(insightsNotifierProvider.notifier)
                            .dismiss(unread.first.id),
                        onTap: () => ref
                            .read(insightsNotifierProvider.notifier)
                            .markRead(unread.first.id),
                      );
                    },
                  ) ??
                  const SizedBox.shrink(),
            ),

            // ── Overdue banner ──
            SliverToBoxAdapter(child: _OverdueBanner(ref: ref)),

            // ── Segment content ──
            if (segment == 0) ...[
              _TasksContent(ref: ref),
            ] else ...[
              _RemindersContent(remindersAsync: remindersAsync, ref: ref),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Header with segmented control ───

class _Header extends StatelessWidget {
  final int segment;
  final WidgetRef ref;
  const _Header({required this.segment, required this.ref});

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksNotifierProvider);
    final remindersAsync = ref.watch(remindersNotifierProvider);
    final pendingCount =
        tasksAsync.valueOrNull?.where((t) => !t.completed).length ?? 0;
    final activeReminders =
        remindersAsync.valueOrNull?.where((r) => r.active).length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.rotate(
                    angle: -1 * math.pi / 180,
                    child: Text('Planner',
                        style: GoogleFonts.gloriaHallelujah(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: JemsColors.charcoal)),
                  ),
                  Transform.rotate(
                    angle: 1 * math.pi / 180,
                    child: Text(
                      _todayLabel(),
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.ink.withAlpha(130)),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Calendar toggle
              GestureDetector(
                onTap: () => ref
                    .read(_calendarExpandedProvider.notifier)
                    .update((v) => !v),
                child: BlobShape(
                  color: JemsColors.lavender.withAlpha(80),
                  size: 40,
                  variant: 2,
                  child: const Icon(Icons.calendar_month,
                      color: JemsColors.charcoal, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => segment == 0
                    ? _showAddTaskSheet(context, ref)
                    : _showAddReminderSheet(context, ref),
                child: BlobShape(
                  color: JemsColors.surface,
                  size: 40,
                  variant: 1,
                  child: const Icon(Icons.add,
                      color: JemsColors.charcoal, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SketchSegmentedControl(
            selected: segment,
            items: [
              ('Tasks', pendingCount),
              ('Reminders', activeReminders),
            ],
            onChanged: (i) => ref.read(_segmentProvider.notifier).state = i,
          ),
          const SizedBox(height: 8),
          const DashedSeparator(),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${months[now.month - 1]} ${now.day}, ${days[now.weekday - 1]}';
  }
}


// ─── Date Carousel — horizontal scrollable date picker ───

class _DateCarousel extends StatelessWidget {
  final WidgetRef ref;
  const _DateCarousel({required this.ref});

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDateProvider);
    final today = DateTime.now();
    final tasks = ref.watch(tasksNotifierProvider).valueOrNull ?? [];

    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 30, // show 30 days
        itemBuilder: (ctx, i) {
          final date = today.add(Duration(days: i - 3)); // 3 days back
          final isSelected = _sameDay(date, selected);
          final isToday = _sameDay(date, today);
          final dateStr = _toIso(date);
          final taskCount = tasks
              .where((t) =>
                  !t.completed &&
                  (t.dueDate == dateStr ||
                      (i == 3 &&
                          (t.dueDate == null || t.dueDate!.isEmpty))))
              .length;

          return GestureDetector(
            onTap: () =>
                ref.read(selectedDateProvider.notifier).state = date,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? JemsColors.charcoal
                    : isToday
                        ? JemsColors.lavender.withAlpha(60)
                        : JemsColors.surface,
                borderRadius:
                    i.isEven ? kCharcoalRadius : kCharcoalRadiusAlt,
                border: Border.all(
                  color: isSelected
                      ? JemsColors.charcoal
                      : JemsColors.ink.withAlpha(isToday ? 180 : 80),
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayAbbr(date.weekday),
                    style: GoogleFonts.architectsDaughter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? JemsColors.paper
                          : JemsColors.ink.withAlpha(130),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.gloriaHallelujah(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? JemsColors.paper
                          : JemsColors.charcoal,
                    ),
                  ),
                  if (taskCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? JemsColors.mint
                            : JemsColors.coral,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dayAbbr(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

// ─── Expandable Calendar (month view) ───

class _ExpandableCalendar extends StatelessWidget {
  final WidgetRef ref;
  const _ExpandableCalendar({required this.ref});

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(_calendarExpandedProvider);
    if (!expanded) return const SizedBox.shrink();

    final selected = ref.watch(selectedDateProvider);
    final tasks = ref.watch(tasksNotifierProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final firstOfMonth = DateTime(selected.year, selected.month, 1);
    final daysInMonth =
        DateTime(selected.year, selected.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday; // 1=Mon

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: CharcoalCard(
        blobColor: JemsColors.lavender,
        rotation: 0,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Month nav
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => ref
                      .read(selectedDateProvider.notifier)
                      .state = DateTime(selected.year, selected.month - 1, 1),
                  child: const Icon(Icons.chevron_left,
                      color: JemsColors.charcoal),
                ),
                Text(
                  _monthLabel(selected),
                  style: GoogleFonts.gloriaHallelujah(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: JemsColors.charcoal),
                ),
                GestureDetector(
                  onTap: () => ref
                      .read(selectedDateProvider.notifier)
                      .state = DateTime(selected.year, selected.month + 1, 1),
                  child: const Icon(Icons.chevron_right,
                      color: JemsColors.charcoal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Day headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(d,
                              style: GoogleFonts.architectsDaughter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: JemsColors.ink.withAlpha(130))),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // Day grid
            ...List.generate(6, (week) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (day) {
                  final dayNum =
                      week * 7 + day - (startWeekday - 2);
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox(width: 36, height: 36);
                  }
                  final date = DateTime(
                      selected.year, selected.month, dayNum);
                  final isSelected = _sameDay(date, selected);
                  final isToday = _sameDay(date, now);
                  final dateStr = _toIso(date);
                  final hasTasks = tasks.any((t) =>
                      !t.completed && t.dueDate == dateStr);

                  return GestureDetector(
                    onTap: () => ref
                        .read(selectedDateProvider.notifier)
                        .state = date,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? JemsColors.charcoal
                            : isToday
                                ? JemsColors.mint.withAlpha(40)
                                : null,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday && !isSelected
                            ? Border.all(
                                color: JemsColors.ink, width: 1.5)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: GoogleFonts.architectsDaughter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? JemsColors.paper
                                  : JemsColors.charcoal,
                            ),
                          ),
                          if (hasTasks)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? JemsColors.mint
                                      : JemsColors.coral,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ─── Overdue tasks banner ───

class _OverdueBanner extends StatelessWidget {
  final WidgetRef ref;
  const _OverdueBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final overdue = ref.watch(overdueTasksProvider);
    if (overdue.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: JemsColors.smearRed.withAlpha(50),
          borderRadius: kCharcoalRadius,
          border: Border.all(color: JemsColors.ink, width: 1.5),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${overdue.length} overdue task${overdue.length > 1 ? 's' : ''} need attention',
                style: GoogleFonts.architectsDaughter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: JemsColors.charcoal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Sketch-style segmented control ───

class _SketchSegmentedControl extends StatelessWidget {
  final int selected;
  final List<(String, int)> items;
  final ValueChanged<int> onChanged;

  const _SketchSegmentedControl({
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JemsColors.paperDark.withAlpha(150),
        borderRadius: kCharcoalRadius,
        border: Border.all(color: JemsColors.ink, width: 2),
      ),
      child: Row(
        children: items.indexed.map((e) {
          final (i, (label, count)) = e;
          final isActive = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isActive ? JemsColors.surface : Colors.transparent,
                  borderRadius: isActive ? kCharcoalRadiusAlt : null,
                  border: isActive
                      ? Border.all(color: JemsColors.ink, width: 1.5)
                      : null,
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: JemsColors.borderShadow,
                            offset: Offset(1, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.architectsDaughter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? JemsColors.charcoal
                            : JemsColors.ink.withAlpha(150),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? JemsColors.charcoal
                              : JemsColors.ink.withAlpha(80),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.architectsDaughter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: JemsColors.paper,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Proactive insight banner ───

class _InsightBanner extends StatelessWidget {
  final ProactiveInsight insight;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InsightBanner({
    required this.insight,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = insight.isHigh ? JemsColors.coral : JemsColors.amber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Transform.rotate(
          angle: 0.5 * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: JemsColors.surface,
              borderRadius: kCharcoalRadiusAlt,
              border: Border.all(color: JemsColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: JemsColors.borderShadow,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('💡', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: GoogleFonts.gloriaHallelujah(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: JemsColors.charcoal,
                        ),
                      ),
                      // Only show content if it's human-readable (not raw JSON)
                      if (insight.content.isNotEmpty &&
                          !insight.content.trimLeft().startsWith('{'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            insight.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.architectsDaughter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: JemsColors.ink,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          insight.priority,
                          style: GoogleFonts.architectsDaughter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: JemsColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: JemsColors.paperDark.withAlpha(150),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: JemsColors.ink.withAlpha(80), width: 1),
                    ),
                    child: Icon(Icons.close,
                        size: 16, color: JemsColors.ink),
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


// ─── Tasks content (segment 0) — date-filtered ───

class _TasksContent extends StatelessWidget {
  final WidgetRef ref;
  const _TasksContent({required this.ref});

  @override
  Widget build(BuildContext context) {
    final tasksForDate = ref.watch(tasksForDateProvider);
    final selected = ref.watch(selectedDateProvider);
    final isToday = _sameDay(selected, DateTime.now());

    return SliverToBoxAdapter(
      child: tasksForDate.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('Could not load tasks',
                style: GoogleFonts.architectsDaughter(
                    color: JemsColors.ink.withAlpha(130),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        data: (tasks) {
          final active = tasks.where((t) => !t.completed).toList();
          final completed = tasks.where((t) => t.completed).toList();

          if (tasks.isEmpty) {
            return _EmptyState(
              icon: Icons.check_circle_outline,
              title: isToday ? 'Nothing planned today' : 'No tasks this day',
              subtitle: 'Ask Jems to create tasks, or tap + above',
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DayFocusCard(
                    tasks: active,
                    dateLabel: isToday
                        ? "Today's Focus"
                        : _formatDateLabel(selected),
                    onToggle: (id) {
                      final task = active.firstWhere((t) => t.id == id);
                      if (task.requiresProof) {
                        showProofCaptureSheet(context, task);
                      } else {
                        ref.read(tasksNotifierProvider.notifier).complete(id);
                      }
                    },
                    onDelete: (id) =>
                        ref.read(tasksNotifierProvider.notifier).delete(id),
                  ),
                ],
                ..._buildHabitsSection(active),
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CharcoalSectionHeader(
                      title: 'Done',
                      trailing: '${completed.length} completed',
                      rotation: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...completed.take(5).map((t) => _CompletedTaskRow(task: t)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateLabel(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  List<Widget> _buildHabitsSection(List<Task> active) {
    final habits = active.where((t) => t.type == 'habit').toList();
    if (habits.isEmpty) return [];
    return [
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CharcoalSectionHeader(
          title: 'Habits',
          trailing: '${habits.length} daily',
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: habits.indexed.map((e) {
            final (i, habit) = e;
            return _HabitChip(habit: habit, index: i);
          }).toList(),
        ),
      ),
    ];
  }
}

// ─── Day Focus Card (replaces Today's Focus, works for any date) ───

class _DayFocusCard extends StatelessWidget {
  final List<Task> tasks;
  final String dateLabel;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

  const _DayFocusCard({
    required this.tasks,
    required this.dateLabel,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final focusTasks = tasks.where((t) => t.type != 'habit').toList();
    if (focusTasks.isEmpty) return const SizedBox.shrink();

    return CharcoalCard(
      blobColor: JemsColors.lavender,
      rotation: -1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny,
                  color: JemsColors.charcoal, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(dateLabel,
                    style: GoogleFonts.gloriaHallelujah(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: JemsColors.charcoal)),
              ),
              Text(
                '${focusTasks.length} tasks',
                style: GoogleFonts.architectsDaughter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: JemsColors.ink.withAlpha(130)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...focusTasks.take(8).map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onDelete(t.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete_outline,
                        color: JemsColors.error.withAlpha(180)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: HandDrawnCheckbox(
                          checked: t.completed,
                          onChanged: (_) {
                            if (!t.completed) onToggle(t.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.architectsDaughter(
                                fontSize: 17,
                                color: JemsColors.charcoal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (t.time.isNotEmpty)
                              Text(t.time,
                                  style: GoogleFonts.architectsDaughter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: JemsColors.coral)),
                            if (t.detail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(t.detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.architectsDaughter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            JemsColors.ink.withAlpha(120))),
                              ),
                          ],
                        ),
                      ),
                      _TaskMeta(task: t),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Task metadata icons ───

class _TaskMeta extends StatelessWidget {
  final Task task;
  const _TaskMeta({required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.priority == 'high')
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: JemsColors.coral.withAlpha(80),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('!',
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.charcoal)),
            ),
          ),
        if (task.requiresProof)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.camera_alt_outlined,
                size: 16, color: JemsColors.ink.withAlpha(150)),
          ),
        if (task.goalId != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.flag_outlined, size: 16, color: JemsColors.mint),
          ),
      ],
    );
  }
}

// ─── Habit chip ───

class _HabitChip extends StatelessWidget {
  final Task habit;
  final int index;
  const _HabitChip({required this.habit, required this.index});

  static const _colors = [
    JemsColors.mint,
    JemsColors.coral,
    JemsColors.lavender,
    JemsColors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    // Constrain chip width so long habit titles don't overflow the screen.
    final maxWidth = MediaQuery.of(context).size.width - 48;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(50),
          borderRadius: kCharcoalRadiusAlt,
          border: Border.all(color: JemsColors.ink, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.repeat, size: 14, color: JemsColors.ink.withAlpha(150)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(habit.title,
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.charcoal)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Completed task row ───

class _CompletedTaskRow extends StatelessWidget {
  final Task task;
  const _CompletedTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          const HandDrawnCheckbox(checked: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              style: GoogleFonts.architectsDaughter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: JemsColors.ink.withAlpha(100),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          if (task.proofStatus == 'verified')
            Icon(Icons.verified, size: 16, color: JemsColors.success),
        ],
      ),
    );
  }
}


// ─── Reminders content (segment 1) — with snooze ───

class _RemindersContent extends StatelessWidget {
  final AsyncValue<List<Reminder>> remindersAsync;
  final WidgetRef ref;

  const _RemindersContent({required this.remindersAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: remindersAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('Could not load reminders',
                style: GoogleFonts.architectsDaughter(
                    color: JemsColors.ink.withAlpha(130),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        data: (reminders) {
          final active = reminders.where((r) => r.active).toList();
          final inactive = reminders.where((r) => !r.active).toList();

          if (reminders.isEmpty) {
            return _EmptyState(
              icon: Icons.notifications_none,
              title: 'No reminders',
              subtitle: 'Ask Jems to set reminders, or tap + above',
            );
          }

          final recurring =
              active.where((r) => _isRecurring(r.time)).toList();
          final oneTime =
              active.where((r) => !_isRecurring(r.time)).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recurring.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CharcoalSectionHeader(
                      title: 'Recurring',
                      trailing: '${recurring.length} active',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...recurring.indexed.map((e) {
                    final (i, r) = e;
                    return _ReminderCard(
                      reminder: r,
                      index: i,
                      onSnooze: () => _showSnoozeSheet(context, ref, r),
                      onToggle: () => ref
                          .read(remindersNotifierProvider.notifier)
                          .update(r.id, {'active': false}),
                      onDelete: () => ref
                          .read(remindersNotifierProvider.notifier)
                          .delete(r.id),
                    );
                  }),
                ],
                if (oneTime.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CharcoalSectionHeader(
                      title: 'Scheduled',
                      trailing: '${oneTime.length} upcoming',
                      rotation: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: oneTime.indexed.map((e) {
                      final (i, r) = e;
                      return _ReminderTile(
                        reminder: r,
                        index: i,
                        onSnooze: () => _showSnoozeSheet(context, ref, r),
                      );
                    }).toList(),
                  ),
                ],
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CharcoalSectionHeader(
                      title: 'Paused',
                      trailing: '${inactive.length}',
                      rotation: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...inactive.take(4).map((r) => _PausedReminderRow(
                        reminder: r,
                        onResume: () => ref
                            .read(remindersNotifierProvider.notifier)
                            .update(r.id, {'active': true}),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isRecurring(String time) {
    final lower = time.toLowerCase();
    return lower.contains('every') ||
        lower.contains('daily') ||
        lower.contains('weekday') ||
        lower.contains('morning') ||
        lower.contains('evening') ||
        lower.contains('weekly');
  }
}

// ─── Snooze bottom sheet ───

void _showSnoozeSheet(BuildContext context, WidgetRef ref, Reminder reminder) {
  showModalBottomSheet(
    context: context,
    backgroundColor: JemsColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: JemsColors.ink.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Snooze Reminder',
              style: GoogleFonts.gloriaHallelujah(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: JemsColors.charcoal)),
          const SizedBox(height: 4),
          Text(
            reminder.title,
            style: GoogleFonts.architectsDaughter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: JemsColors.ink.withAlpha(150)),
          ),
          if (reminder.snoozeCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Snoozed ${reminder.snoozeCount} time${reminder.snoozeCount > 1 ? 's' : ''}',
              style: GoogleFonts.architectsDaughter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.coral),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SnoozeOption(
                label: '15 min',
                minutes: 15,
                onTap: () {
                  ref
                      .read(remindersNotifierProvider.notifier)
                      .snooze(reminder.id, minutes: 15);
                  Navigator.pop(ctx);
                },
              ),
              _SnoozeOption(
                label: '30 min',
                minutes: 30,
                onTap: () {
                  ref
                      .read(remindersNotifierProvider.notifier)
                      .snooze(reminder.id, minutes: 30);
                  Navigator.pop(ctx);
                },
              ),
              _SnoozeOption(
                label: '1 hour',
                minutes: 60,
                onTap: () {
                  ref
                      .read(remindersNotifierProvider.notifier)
                      .snooze(reminder.id, minutes: 60);
                  Navigator.pop(ctx);
                },
              ),
              _SnoozeOption(
                label: '3 hours',
                minutes: 180,
                onTap: () {
                  ref
                      .read(remindersNotifierProvider.notifier)
                      .snooze(reminder.id, minutes: 180);
                  Navigator.pop(ctx);
                },
              ),
              _SnoozeOption(
                label: 'Tomorrow',
                minutes: 1440,
                onTap: () {
                  ref
                      .read(remindersNotifierProvider.notifier)
                      .snooze(reminder.id, minutes: 1440);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SnoozeOption extends StatelessWidget {
  final String label;
  final int minutes;
  final VoidCallback onTap;

  const _SnoozeOption({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: JemsColors.surface,
          borderRadius: kCharcoalRadiusAlt,
          border: Border.all(color: JemsColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(
              color: JemsColors.borderShadow,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.architectsDaughter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: JemsColors.charcoal),
        ),
      ),
    );
  }
}


// ─── Reminder card (recurring, full-width) with snooze button ───

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final int index;
  final VoidCallback onSnooze;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.index,
    required this.onSnooze,
    required this.onToggle,
    required this.onDelete,
  });

  static const _icons = [
    Icons.repeat,
    Icons.alarm,
    Icons.self_improvement,
    Icons.local_drink,
    Icons.medication,
  ];
  static const _colors = [
    JemsColors.mint,
    JemsColors.coral,
    JemsColors.lavender,
    JemsColors.amber,
    JemsColors.markerBlue,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: ValueKey(reminder.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.delete_outline,
              color: JemsColors.error.withAlpha(180)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: JemsColors.surface,
            borderRadius:
                index.isEven ? kCharcoalRadius : kCharcoalRadiusAlt,
            border: Border.all(color: JemsColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: JemsColors.borderShadow,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              BlobShape(
                color: color.withAlpha(80),
                size: 40,
                variant: index % 4,
                child: Icon(_icons[index % _icons.length],
                    color: JemsColors.charcoal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.architectsDaughter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: JemsColors.charcoal)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 12,
                            color: JemsColors.ink.withAlpha(130)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(reminder.time,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.architectsDaughter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: JemsColors.ink.withAlpha(130))),
                        ),
                        if (reminder.goalId != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.flag_outlined,
                              size: 12, color: JemsColors.mint),
                        ],
                        if (reminder.isSnoozed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: JemsColors.amber.withAlpha(80),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${reminder.snoozeCount}x',
                              style: GoogleFonts.architectsDaughter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: JemsColors.charcoal),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Snooze button
              GestureDetector(
                onTap: onSnooze,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: JemsColors.amber.withAlpha(60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.snooze,
                      size: 18, color: JemsColors.ink.withAlpha(180)),
                ),
              ),
              // Pause button
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: JemsColors.paperDark.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pause,
                      size: 18, color: JemsColors.ink.withAlpha(150)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reminder tile (one-time, 2-column grid) with snooze ───

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final int index;
  final VoidCallback onSnooze;
  const _ReminderTile({
    required this.reminder,
    required this.index,
    required this.onSnooze,
  });

  static const _icons = [
    Icons.notifications_active,
    Icons.event,
    Icons.alarm_on,
    Icons.schedule,
  ];
  static const _colors = [
    JemsColors.coral,
    JemsColors.lavender,
    JemsColors.mint,
    JemsColors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final rotation = index.isEven ? 1.0 : -1.0;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: JemsColors.surface,
            borderRadius:
                index.isEven ? kCharcoalRadius : kCharcoalRadiusAlt,
            border: Border.all(color: JemsColors.ink, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(_icons[index % _icons.length],
                      color: _colors[index % _colors.length], size: 24),
                  GestureDetector(
                    onTap: onSnooze,
                    child: Icon(Icons.snooze,
                        size: 18, color: JemsColors.ink.withAlpha(130)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(reminder.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.ink)),
              const SizedBox(height: 4),
              Text(reminder.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.charcoal)),
              if (reminder.isSnoozed) ...[
                const SizedBox(height: 4),
                Text(
                  'Snoozed ${reminder.snoozeCount}x',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.amber),
                ),
              ] else if (reminder.goalId != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 12, color: JemsColors.mint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('Linked to goal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.architectsDaughter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: JemsColors.ink.withAlpha(120))),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Paused reminder row ───

class _PausedReminderRow extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onResume;
  const _PausedReminderRow({required this.reminder, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Icon(Icons.notifications_paused,
              size: 18, color: JemsColors.ink.withAlpha(100)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reminder.title,
              style: GoogleFonts.architectsDaughter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: JemsColors.ink.withAlpha(100),
              ),
            ),
          ),
          GestureDetector(
            onTap: onResume,
            child: Text('Resume',
                style: GoogleFonts.architectsDaughter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: JemsColors.charcoal,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}


// ─── Empty state ───

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: 5 * math.pi / 180,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: JemsColors.lavender.withAlpha(60),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.elliptical(64, 55),
                        topRight: Radius.elliptical(36, 58),
                        bottomLeft: Radius.elliptical(27, 42),
                        bottomRight: Radius.elliptical(73, 45),
                      ),
                    ),
                  ),
                ),
                Icon(icon, size: 40, color: JemsColors.ink.withAlpha(100)),
              ],
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.gloriaHallelujah(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: JemsColors.ink.withAlpha(150))),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.architectsDaughter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: JemsColors.ink.withAlpha(100))),
          ],
        ),
      ),
    );
  }
}

// ─── Add Task bottom sheet (with dueDate) ───

void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final timeCtrl = TextEditingController();
  final detailCtrl = TextEditingController();
  String selectedType = 'task';
  final selected = ref.read(selectedDateProvider);
  String dueDate = _toIso(selected);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: JemsColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: JemsColors.ink.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('New Task',
                style: GoogleFonts.gloriaHallelujah(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: JemsColors.charcoal)),
            const SizedBox(height: 16),
            _SketchTextField(controller: titleCtrl, hint: 'What needs doing?'),
            const SizedBox(height: 12),
            _SketchTextField(
                controller: timeCtrl, hint: 'When? (e.g. Today 3 PM)'),
            const SizedBox(height: 12),
            _SketchTextField(
                controller: detailCtrl, hint: 'Details (optional)'),
            const SizedBox(height: 14),
            // Date chip
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selected,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => dueDate = _toIso(picked));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: JemsColors.lavender.withAlpha(50),
                  borderRadius: kCharcoalRadiusAlt,
                  border: Border.all(color: JemsColors.ink, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: JemsColors.ink.withAlpha(150)),
                    const SizedBox(width: 6),
                    Text(
                      dueDate,
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.charcoal),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Type selector
            Row(
              children: ['task', 'habit', 'event'].map((t) {
                final isActive = t == selectedType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? JemsColors.charcoal
                            : JemsColors.paperDark,
                        borderRadius: kCharcoalRadiusAlt,
                        border:
                            Border.all(color: JemsColors.ink, width: 1.5),
                      ),
                      child: Text(
                        t[0].toUpperCase() + t.substring(1),
                        style: GoogleFonts.architectsDaughter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? JemsColors.paper
                              : JemsColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    ref.read(tasksNotifierProvider.notifier).create(
                          title: titleCtrl.text.trim(),
                          time: timeCtrl.text.trim(),
                          detail: detailCtrl.text.trim(),
                          type: selectedType,
                          dueDate: dueDate,
                        );
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: JemsColors.charcoal,
                  foregroundColor: JemsColors.paper,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: kCharcoalRadius,
                  ),
                ),
                child: Text('Create Task',
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Add Reminder bottom sheet ───

void _showAddReminderSheet(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final timeCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: JemsColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: JemsColors.ink.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('New Reminder',
              style: GoogleFonts.gloriaHallelujah(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: JemsColors.charcoal)),
          const SizedBox(height: 16),
          _SketchTextField(
              controller: titleCtrl, hint: 'What to remember?'),
          const SizedBox(height: 12),
          _SketchTextField(
              controller: timeCtrl,
              hint: 'When? (e.g. Every morning, Today 5 PM)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty &&
                    timeCtrl.text.trim().isNotEmpty) {
                  ref.read(remindersNotifierProvider.notifier).create(
                        title: titleCtrl.text.trim(),
                        time: timeCtrl.text.trim(),
                      );
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JemsColors.charcoal,
                foregroundColor: JemsColors.paper,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: kCharcoalRadius,
                ),
              ),
              child: Text('Set Reminder',
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Sketch-style text field ───

class _SketchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _SketchTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.architectsDaughter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: JemsColors.charcoal),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.architectsDaughter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: JemsColors.ink.withAlpha(80)),
        filled: true,
        fillColor: JemsColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: kCharcoalRadius,
          borderSide: const BorderSide(color: JemsColors.ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: kCharcoalRadius,
          borderSide: const BorderSide(color: JemsColors.ink, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kCharcoalRadius,
          borderSide:
              const BorderSide(color: JemsColors.charcoal, width: 2.5),
        ),
      ),
    );
  }
}

// ─── Helpers ───

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _toIso(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
