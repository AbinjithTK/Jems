import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/task.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/services/proof_service.dart';
import '../../core/theme/jems_colors.dart';
import '../../core/theme/charcoal_decorations.dart';

/// Bottom sheet for capturing proof when completing a task that requires it.
///
/// Shows camera/gallery options, preview, and upload + complete flow.
class ProofCaptureSheet extends ConsumerStatefulWidget {
  final Task task;
  const ProofCaptureSheet({super.key, required this.task});

  @override
  ConsumerState<ProofCaptureSheet> createState() => _ProofCaptureSheetState();
}

class _ProofCaptureSheetState extends ConsumerState<ProofCaptureSheet> {
  File? _selectedFile;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: JemsColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: JemsColors.ink.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Proof Required',
            style: GoogleFonts.gloriaHallelujah(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: JemsColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.task.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.architectsDaughter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: JemsColors.ink.withAlpha(150),
            ),
          ),
          const SizedBox(height: 20),

          if (_selectedFile != null) ...[
            // Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedFile!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: 'Retake',
                    icon: Icons.refresh,
                    color: JemsColors.ink.withAlpha(80),
                    onTap: () => setState(() => _selectedFile = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SheetButton(
                    label: _uploading ? 'Uploading...' : 'Submit',
                    icon: Icons.check,
                    color: JemsColors.mint,
                    onTap: _uploading ? null : _uploadAndComplete,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Capture options
            Row(
              children: [
                Expanded(
                  child: _CaptureOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: JemsColors.coral,
                    onTap: _captureFromCamera,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CaptureOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: JemsColors.lavender,
                    onTap: _pickFromGallery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Skip option
            GestureDetector(
              onTap: () => _completeWithoutProof(),
              child: Text(
                'Complete without proof',
                style: GoogleFonts.architectsDaughter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.ink.withAlpha(100),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    final proof = ref.read(proofServiceProvider);
    final file = await proof.captureFromCamera();
    if (file != null && mounted) setState(() => _selectedFile = file);
  }

  Future<void> _pickFromGallery() async {
    final proof = ref.read(proofServiceProvider);
    final file = await proof.pickFromGallery();
    if (file != null && mounted) setState(() => _selectedFile = file);
  }

  Future<void> _uploadAndComplete() async {
    if (_selectedFile == null) return;
    setState(() => _uploading = true);

    final proof = ref.read(proofServiceProvider);
    final url = await proof.uploadProof(_selectedFile!, taskId: widget.task.id);

    if (url != null) {
      await ref.read(tasksNotifierProvider.notifier).complete(
            widget.task.id,
            proofUrl: url,
            proofType: 'image',
          );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again.')),
        );
      }
    }
  }

  Future<void> _completeWithoutProof() async {
    await ref.read(tasksNotifierProvider.notifier).complete(widget.task.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _CaptureOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CaptureOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color.withAlpha(50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: JemsColors.ink, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: JemsColors.charcoal),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.architectsDaughter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: JemsColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: JemsColors.ink, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: JemsColors.charcoal),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.architectsDaughter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: JemsColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the proof capture sheet. Returns true if task was completed.
Future<bool> showProofCaptureSheet(BuildContext context, Task task) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProofCaptureSheet(task: task),
  );
  return result ?? false;
}
