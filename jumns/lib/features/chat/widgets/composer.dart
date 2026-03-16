import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/jems_colors.dart';

/// Charcoal Sketch composer: wobbly input border, blob add button,
/// charcoal send button with blob shape.
class Composer extends StatefulWidget {
  final void Function(String text) onSend;
  final void Function(File image, String text)? onSendImage;
  final bool isDisabled;

  const Composer({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.isDisabled = false,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _hasText = false;
  File? _attachedImage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (widget.isDisabled) return;
    final text = _controller.text.trim();

    if (_attachedImage != null) {
      widget.onSendImage?.call(_attachedImage!, text);
      _controller.clear();
      setState(() => _attachedImage = null);
      return;
    }

    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: JemsColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: JemsColors.charcoal),
                title: Text('Camera',
                    style: GoogleFonts.architectsDaughter(
                        fontWeight: FontWeight.w700,
                        color: JemsColors.charcoal)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: JemsColors.charcoal),
                title: Text('Gallery',
                    style: GoogleFonts.architectsDaughter(
                        fontWeight: FontWeight.w700,
                        color: JemsColors.charcoal)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _attachedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: JemsColors.paper.withAlpha(240),
        border: const Border(
          top: BorderSide(
            color: JemsColors.ink,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: Transform.rotate(
        angle: 0.012, // ~0.7 degrees — subtle tilt like the Stitch design
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: JemsColors.surface,
            border: Border.all(color: JemsColors.ink, width: 2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.elliptical(20, 48),
              topRight: Radius.elliptical(48, 6),
              bottomLeft: Radius.elliptical(48, 6),
              bottomRight: Radius.elliptical(20, 42),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                offset: Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview strip
              if (_attachedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _attachedImage!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Image attached',
                            style: GoogleFonts.architectsDaughter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: JemsColors.ink.withAlpha(150))),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _attachedImage = null),
                        child: const Icon(Icons.close_rounded,
                            size: 20, color: JemsColors.ink),
                      ),
                    ],
                  ),
                ),
              Row(
            children: [
              // Add button — blob shape with lavender tint
              GestureDetector(
                onTap: widget.isDisabled ? null : _pickImage,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: JemsColors.lavender.withAlpha(80),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.elliptical(64, 55),
                      topRight: Radius.elliptical(36, 58),
                      bottomLeft: Radius.elliptical(27, 42),
                      bottomRight: Radius.elliptical(73, 45),
                    ),
                    border: Border.all(color: JemsColors.ink, width: 2),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: widget.isDisabled
                        ? JemsColors.ink.withAlpha(80)
                        : JemsColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isDisabled,
                  style: GoogleFonts.architectsDaughter(
                    color: JemsColors.charcoal,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isDisabled
                        ? 'Sketching...'
                        : 'Ask anything...',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    isDense: true,
                    hintStyle: GoogleFonts.architectsDaughter(
                      color: JemsColors.ink.withAlpha(100),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 4),
              // Mic button
              if (!_hasText && _attachedImage == null)
                GestureDetector(
                  onTap: widget.isDisabled
                      ? null
                      : () => context.push('/voice'),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.mic_rounded,
                      color: JemsColors.charcoal,
                      size: 22,
                    ),
                  ),
                ),
              // Send button — charcoal blob
              GestureDetector(
                onTap: widget.isDisabled
                    ? null
                    : () {
                        if (_hasText || _attachedImage != null) {
                          _handleSend();
                        } else {
                          context.push('/voice');
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (_hasText || _attachedImage != null)
                        ? JemsColors.charcoal
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.elliptical(64, 55),
                      topRight: Radius.elliptical(36, 58),
                      bottomLeft: Radius.elliptical(27, 42),
                      bottomRight: Radius.elliptical(73, 45),
                    ),
                    border: (_hasText || _attachedImage != null)
                        ? null
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Center(
                    child: Icon(
                      (_hasText || _attachedImage != null)
                          ? Icons.send_rounded
                          : Icons.edit_rounded,
                      color: (_hasText || _attachedImage != null)
                          ? JemsColors.paper
                          : JemsColors.charcoal,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ), // end Row
            ], // end Column children
          ), // end Column
        ),
      ),
    );
  }
}
