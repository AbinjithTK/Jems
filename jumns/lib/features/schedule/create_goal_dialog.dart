import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/theme/spatial_colors.dart';

/// Spatial-styled bottom sheet for creating a new goal.
class CreateGoalDialog extends ConsumerStatefulWidget {
  const CreateGoalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateGoalDialog(),
    );
  }

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _titleController = TextEditingController();
  String _category = 'personal';
  int _total = 100;
  String _unit = '%';
  bool _saving = false;

  static const _categories = [
    ('personal', '🎯'),
    ('health', '🏃'),
    ('learning', '📚'),
    ('finance', '💰'),
    ('work', '💼'),
    ('mindfulness', '🧘'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(goalsNotifierProvider.notifier).create(
          title: title,
          category: _category,
          total: _total,
          unit: _unit,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: SpatialColors.surfaceMuted,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          const SizedBox(height: 20),
          Text('New Goal', style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w700, color: SpatialColors.textPrimary,
          )),
          const SizedBox(height: 24),
          // Title
          _glassField(
            controller: _titleController,
            hint: 'What do you want to achieve?',
            autofocus: true,
          ),
          const SizedBox(height: 16),
          // Category chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((c) {
                final isActive = c.$1 == _category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _category = c.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? SpatialColors.agentGreen.withAlpha(30) : SpatialColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isActive ? SpatialColors.agentGreen : SpatialColors.surfaceMuted,
                        ),
                      ),
                      child: Text(
                        '${c.$2} ${c.$1[0].toUpperCase()}${c.$1.substring(1)}',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? SpatialColors.agentGreen : SpatialColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Target + unit row
          Row(
            children: [
              Expanded(
                child: _glassField(
                  hint: 'Target (e.g. 100)',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _total = int.tryParse(v) ?? 100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _glassField(
                  hint: 'Unit (e.g. %, km, pages)',
                  onChanged: (v) => _unit = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: SpatialColors.agentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Create Goal', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600)),
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
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
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
        keyboardType: keyboardType,
        onChanged: onChanged,
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
