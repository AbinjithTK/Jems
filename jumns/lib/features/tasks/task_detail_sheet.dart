import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/task.dart';
import '../../core/providers/agent_chat_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';

/// Cached tips per task ID so we don't re-fetch every open.
final _taskTipsProvider =
    StateProvider.family<String?, String>((ref, taskId) => null);

/// Bottom sheet showing task details + AI-generated tips & directions.
class TaskDetailSheet extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailSheet({super.key, required this.task});

  static Future<void> show(BuildContext context, Task task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(task: task),
    );
  }

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  bool _loadingTips = false;

  @override
  void initState() {
    super.initState();
    _fetchTipsIfNeeded();
  }

  Future<void> _fetchTipsIfNeeded() async {
    final cached = ref.read(_taskTipsProvider(widget.task.id));
    if (cached != null) return;

    setState(() => _loadingTips = true);
    final prompt =
        'Give me practical tips and step-by-step directions for this task: '
        '"${widget.task.title}"'
        '${widget.task.detail.isNotEmpty ? ', detail: "${widget.task.detail}"' : ''}. '
        'Research the web if needed and provide actionable guidance.';

    final response =
        await ref.read(agentChatProvider('kai').notifier).send(prompt);
    if (response != null && mounted) {
      ref.read(_taskTipsProvider(widget.task.id).notifier).state = response;
    }
    if (mounted) setState(() => _loadingTips = false);
  }

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(_taskTipsProvider(widget.task.id));
    final t = widget.task;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: SpatialColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: SpatialColors.surfaceMuted,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          // Task header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: SpatialColors.textPrimary,
                        ),
                      ),
                      if (t.detail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t.detail,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: SpatialColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (t.completed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpatialColors.agentGreen.withAlpha(25),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      'DONE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: SpatialColors.agentGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Meta chips (due date, priority, proof)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (t.dueDate != null && t.dueDate!.isNotEmpty)
                  _Chip(
                    icon: Icons.calendar_today_rounded,
                    label: t.dueDate!,
                    color: SpatialColors.textTertiary,
                  ),
                _Chip(
                  icon: Icons.flag_rounded,
                  label: t.priority.toUpperCase(),
                  color: _priorityColor(t.priority),
                ),
                if (t.requiresProof)
                  _Chip(
                    icon: Icons.camera_alt_rounded,
                    label: t.proofStatus.toUpperCase(),
                    color: SpatialColors.proofBadgeText,
                    bg: SpatialColors.proofBadgeBg,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: SpatialColors.surfaceMuted, height: 1),
          // Tips section
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AgentDot(agentColor: 'yellow', size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'TIPS & DIRECTIONS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: SpatialColors.agentColor('yellow'),
                        ),
                      ),
                      const Spacer(),
                      if (tips != null)
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(
                                    _taskTipsProvider(widget.task.id).notifier)
                                .state = null;
                            _fetchTipsIfNeeded();
                          },
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: SpatialColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingTips)
                    _TipsLoading()
                  else if (tips != null)
                    Text(
                      tips,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: SpatialColors.textSecondary,
                        height: 1.6,
                      ),
                    )
                  else
                    Text(
                      'Tap refresh to get tips.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: SpatialColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Complete button
          if (!t.completed)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomPad),
              child: GestureDetector(
                onTap: () {
                  ref.read(tasksNotifierProvider.notifier).complete(t.id);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: SpatialColors.agentGreen,
                    borderRadius: BorderRadius.circular(9999),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 8),
                        blurRadius: 20,
                        color: SpatialColors.agentGreen.withAlpha(80),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Mark Complete',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _priorityColor(String p) => switch (p) {
        'high' => const Color(0xFFEF4444),
        'low' => SpatialColors.agentGreen,
        _ => SpatialColors.agentYellow,
      };
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bg;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? color.withAlpha(20),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: SpatialColors.surfaceMuted.withAlpha(128),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
