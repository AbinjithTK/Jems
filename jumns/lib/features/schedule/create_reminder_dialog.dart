import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/goal.dart';
import '../../core/providers/reminders_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/theme/spatial_colors.dart';

/// Spatial-styled bottom sheet for creating a new reminder.
class CreateReminderDialog extends ConsumerStatefulWidget {
  const CreateReminderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateReminderDialog(),
    );
  }

  @override
  ConsumerState<CreateReminderDialog> createState() => _State();
}

class _State extends ConsumerState<CreateReminderDialog> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  String? _goalId;
  bool _saving = false;

  static const _presets = [
    'Every day 8 AM',
    'Every day 9 PM',
    'Every Monday 9 AM',
    'Every weekday 7 AM',
    'Tomorrow 10 AM',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final time = _timeController.text.trim();
    if (title.isEmpty || time.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(remindersNotifierProvider.notifier).create(
          title: title,
          time: time,
          goalId: _goalId,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final goals = ref.watch(goalsNotifierProvider).valueOrNull ?? <Goal>[];

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: SpatialColors.surfaceMuted,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          const SizedBox(height: 20),
          Text('New Reminder', style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w700, color: SpatialColors.textPrimary,
          )),
          const SizedBox(height: 24),
          _glassField(controller: _titleController, hint: 'Remind me to...', autofocus: true),
          const SizedBox(height: 12),
          _glassField(controller: _timeController, hint: 'When? (e.g. Every day 8 AM)'),
          const SizedBox(height: 12),
          // Quick presets
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _presets.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _timeController.text = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SpatialColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: SpatialColors.surfaceMuted),
                    ),
                    child: Text(p, style: GoogleFonts.inter(fontSize: 12, color: SpatialColors.textTertiary)),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Link to goal
          if (goals.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: SpatialColors.inputGlassBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SpatialColors.surfaceMuted),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _goalId,
                  isExpanded: true,
                  hint: Text('Link to goal (optional)', style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textMuted)),
                  icon: const Icon(Icons.unfold_more_rounded, size: 18),
                  style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textPrimary),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text('No goal', style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textTertiary))),
                    ...goals.map((g) => DropdownMenuItem(value: g.id, child: Text('${g.categoryEmoji} ${g.title}'))),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: SpatialColors.agentYellow,
                foregroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Create Reminder', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassField({
    TextEditingController? controller,
    String? hint,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SpatialColors.inputGlassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpatialColors.surfaceMuted),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: SpatialColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: SpatialColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
