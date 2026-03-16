import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/goal.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/theme/spatial_colors.dart';

/// Spatial-styled bottom sheet for creating a new task.
class CreateTaskDialog extends ConsumerStatefulWidget {
  const CreateTaskDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateTaskDialog(),
    );
  }

  @override
  ConsumerState<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  String _type = 'task';
  String _priority = 'medium';
  DateTime? _dueDate;
  String? _goalId;
  bool _requiresProof = false;
  bool _saving = false;

  static const _types = [
    ('task', Icons.check_circle_outline_rounded, 'Task'),
    ('habit', Icons.loop_rounded, 'Habit'),
    ('event', Icons.event_rounded, 'Event'),
  ];

  static const _priorities = [
    ('low', Color(0xFF94A3B8), 'Low'),
    ('medium', Color(0xFFFACC15), 'Medium'),
    ('high', Color(0xFFF472B6), 'High'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String _toIso(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(tasksNotifierProvider.notifier).create(
          title: title,
          detail: _detailController.text.trim(),
          type: _type,
          goalId: _goalId,
          dueDate: _dueDate != null ? _toIso(_dueDate!) : null,
          requiresProof: _requiresProof,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final goalsAsync = ref.watch(goalsNotifierProvider);
    final goals = goalsAsync.valueOrNull ?? <Goal>[];

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: SpatialColors.surfaceMuted,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(height: 20),
            Text('New Task', style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w700, color: SpatialColors.textPrimary,
            )),
            const SizedBox(height: 24),
            // Title
            _glassField(controller: _titleController, hint: 'What needs to be done?', autofocus: true),
            const SizedBox(height: 12),
            // Detail
            _glassField(controller: _detailController, hint: 'Details (optional)', maxLines: 2),
            const SizedBox(height: 16),
            // Type chips
            Row(
              children: _types.map((t) {
                final isActive = t.$1 == _type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? SpatialColors.agentYellow.withAlpha(40) : SpatialColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? SpatialColors.agentYellow : SpatialColors.surfaceMuted,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.$2, size: 16, color: isActive ? const Color(0xFF92400E) : SpatialColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(t.$3, style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive ? const Color(0xFF92400E) : SpatialColors.textTertiary,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Priority + Due date row
            Row(
              children: [
                // Priority
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: SpatialColors.inputGlassBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SpatialColors.surfaceMuted),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _priority,
                        isExpanded: true,
                        icon: const Icon(Icons.unfold_more_rounded, size: 18),
                        style: GoogleFonts.inter(fontSize: 14, color: SpatialColors.textPrimary),
                        items: _priorities.map((p) => DropdownMenuItem(
                          value: p.$1,
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$2, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(p.$3),
                            ],
                          ),
                        )).toList(),
                        onChanged: (v) { if (v != null) setState(() => _priority = v); },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Due date
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: SpatialColors.inputGlassBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SpatialColors.surfaceMuted),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: SpatialColors.textTertiary),
                          const SizedBox(width: 8),
                          Text(
                            _dueDate != null ? _toIso(_dueDate!) : 'Due date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _dueDate != null ? SpatialColors.textPrimary : SpatialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: 12),
            // Proof toggle
            GestureDetector(
              onTap: () => setState(() => _requiresProof = !_requiresProof),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _requiresProof ? SpatialColors.proofBadgeBg : SpatialColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _requiresProof ? SpatialColors.proofBadgeBorder : SpatialColors.surfaceMuted),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 18, color: _requiresProof ? SpatialColors.proofBadgeText : SpatialColors.textTertiary),
                    const SizedBox(width: 10),
                    Text('Require proof to complete', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: _requiresProof ? SpatialColors.proofBadgeText : SpatialColors.textTertiary,
                    )),
                    const Spacer(),
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _requiresProof ? SpatialColors.proofBadgeText : Colors.transparent,
                        border: Border.all(color: _requiresProof ? SpatialColors.proofBadgeText : SpatialColors.surfaceMuted, width: 2),
                      ),
                      child: _requiresProof ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Save
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
                    : Text('Create Task', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassField({
    TextEditingController? controller,
    String? hint,
    bool autofocus = false,
    int maxLines = 1,
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
        maxLines: maxLines,
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
