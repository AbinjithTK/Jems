import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/providers/mcp_provider.dart';

/// MCP Connections page — list servers, add via paste-JSON, toggle/delete.
class McpConnectionsPage extends ConsumerWidget {
  const McpConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(mcpNotifierProvider);

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  Text('MCP SERVERS',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        letterSpacing: 1.2, color: SpatialColors.textTertiary,
                      )),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Server list
            Expanded(
              child: serversAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: SpatialColors.agentGreen)),
                error: (e, _) => Center(child: Text('Failed to load servers', style: GoogleFonts.inter(color: SpatialColors.textTertiary))),
                data: (servers) => servers.isEmpty
                    ? Center(child: Text('No MCP servers yet', style: GoogleFonts.inter(color: SpatialColors.textTertiary)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: servers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _McpServerCard(server: servers[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _AddServerFab(onTap: () => _showAddSheet(context, ref)),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMcpSheet(notifier: ref.read(mcpNotifierProvider.notifier)),
    );
  }
}


// --- Private widgets ---

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: SpatialColors.textTertiary),
      ),
    );
  }
}

class _AddServerFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddServerFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: SpatialColors.noorGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(offset: const Offset(0, 4), blurRadius: 16, color: SpatialColors.agentGreen.withAlpha(77))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}


class _McpServerCard extends ConsumerWidget {
  final McpServer server;
  const _McpServerCard({required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mcpNotifierProvider.notifier);
    final hasToken = notifier.hasToken(server);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpatialColors.surfaceSubtle),
        boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: server.builtin ? SpatialColors.agentGreen.withAlpha(26) : SpatialColors.agentViolet.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  server.builtin ? Icons.auto_awesome_rounded : Icons.extension_rounded,
                  color: server.builtin ? SpatialColors.agentGreen : SpatialColors.agentViolet,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(server.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                        if (server.builtin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: SpatialColors.agentGreen.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                            child: Text('BUILT-IN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: SpatialColors.agentGreen, letterSpacing: 0.5)),
                          ),
                        ],
                      ],
                    ),
                    if (server.description.isNotEmpty)
                      Text(server.description, style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Toggle
              Switch.adaptive(
                value: server.enabled,
                activeColor: SpatialColors.agentGreen,
                onChanged: (v) => notifier.toggleServer(server.serverId, v),
              ),
              // Delete (non-builtin only)
              if (!server.builtin)
                GestureDetector(
                  onTap: () => notifier.deleteServer(server.serverId),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.close_rounded, size: 18, color: SpatialColors.textMuted),
                  ),
                ),
            ],
          ),
          // Token status + configure button for built-in servers
          if (server.builtin) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showTokenSheet(context, ref, server),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasToken ? SpatialColors.agentGreen.withAlpha(15) : const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hasToken ? SpatialColors.agentGreen.withAlpha(40) : const Color(0xFFFEF9C3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasToken ? Icons.check_circle_rounded : Icons.key_rounded,
                      size: 14,
                      color: hasToken ? SpatialColors.agentGreen : const Color(0xFFCA8A04),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasToken ? 'Connected' : 'Add integration token',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasToken ? SpatialColors.agentGreen : const Color(0xFFCA8A04),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 14, color: hasToken ? SpatialColors.agentGreen : const Color(0xFFCA8A04)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTokenSheet(BuildContext context, WidgetRef ref, McpServer server) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TokenInputSheet(
        server: server,
        notifier: ref.read(mcpNotifierProvider.notifier),
      ),
    );
  }
}


class _TokenInputSheet extends StatefulWidget {
  final McpServer server;
  final McpNotifier notifier;
  const _TokenInputSheet({required this.server, required this.notifier});

  @override
  State<_TokenInputSheet> createState() => _TokenInputSheetState();
}

class _TokenInputSheetState extends State<_TokenInputSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Please enter a token');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final ok = await widget.notifier.updateToken(widget.server.serverId, token);
    if (!mounted) return;
    if (ok) {
      setState(() { _saving = false; _saved = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() { _saving = false; _error = 'Failed to save token. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final serverName = widget.server.name;
    final isNotion = serverName.toLowerCase().contains('notion');

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: SpatialColors.surfaceMuted, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connect $serverName',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: SpatialColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              isNotion
                  ? 'Create an internal integration at notion.so/profile/integrations, then paste the token below.'
                  : 'Paste the integration token for $serverName below.',
              style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary, height: 1.4),
            ),
            if (isNotion) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpatialColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick steps:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      '1. Go to notion.so/profile/integrations\n'
                      '2. Click "New integration"\n'
                      '3. Give it a name and select a workspace\n'
                      '4. Copy the Internal Integration Secret\n'
                      '5. Share pages/databases with the integration',
                      style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.textTertiary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Token input
            Container(
              decoration: BoxDecoration(
                color: SpatialColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _error != null ? const Color(0xFFF87171) : SpatialColors.surfaceMuted),
              ),
              child: TextField(
                controller: _controller,
                obscureText: true,
                style: GoogleFonts.jetBrainsMono(fontSize: 13, color: SpatialColors.textPrimary),
                decoration: InputDecoration(
                  hintText: isNotion ? 'ntn_****' : 'Paste token here',
                  hintStyle: GoogleFonts.jetBrainsMono(fontSize: 13, color: SpatialColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded, size: 18, color: SpatialColors.textTertiary),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) _controller.text = data!.text!;
                    },
                  ),
                ),
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
              ),
            const SizedBox(height: 16),
            // Save button
            GestureDetector(
              onTap: (_saving || _saved) ? null : _save,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: _saved ? null : SpatialColors.noorGradient,
                  color: _saved ? SpatialColors.agentGreen : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(offset: const Offset(0, 4), blurRadius: 12, color: SpatialColors.agentGreen.withAlpha(51))],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : _saved
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text('Connected', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            )
                          : Text('Save Token', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AddMcpSheet extends StatefulWidget {
  final McpNotifier notifier;
  const _AddMcpSheet({required this.notifier});

  @override
  State<_AddMcpSheet> createState() => _AddMcpSheetState();
}

class _AddMcpSheetState extends State<_AddMcpSheet> {
  final _controller = TextEditingController();
  bool _validating = false;
  bool _saving = false;
  McpValidationResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() { _validating = true; _result = null; });
    final result = await widget.notifier.validate(_controller.text.trim());
    if (mounted) setState(() { _validating = false; _result = result; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.notifier.addServer(_controller.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      _validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SpatialColors.surfaceMuted, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Add MCP Server', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: SpatialColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Paste the server connection JSON below', style: GoogleFonts.inter(fontSize: 13, color: SpatialColors.textTertiary)),
          const SizedBox(height: 16),
          // JSON input
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: SpatialColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _result != null && !_result!.valid ? const Color(0xFFF87171) : SpatialColors.surfaceMuted),
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SpatialColors.textPrimary),
              decoration: InputDecoration(
                hintText: '{\n  "name": "My Server",\n  "command": "npx",\n  "args": ["-y", "my-mcp-server"]\n}',
                hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: SpatialColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) { if (_result != null) setState(() => _result = null); },
            ),
          ),
          // Validation feedback
          if (_result != null && !_result!.valid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _result!.errors.join('\n'),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444)),
              ),
            ),
          if (_result != null && _result!.valid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: SpatialColors.agentGreen),
                  const SizedBox(width: 6),
                  Text('Valid config', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: SpatialColors.agentGreen)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              // Paste from clipboard
              Expanded(
                child: GestureDetector(
                  onTap: _paste,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: SpatialColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.content_paste_rounded, size: 16, color: SpatialColors.textTertiary),
                        const SizedBox(width: 6),
                        Text('Paste', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: SpatialColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Validate
              Expanded(
                child: GestureDetector(
                  onTap: _validating ? null : _validate,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: SpatialColors.agentViolet.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _validating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SpatialColors.agentViolet))
                          : Text('Validate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SpatialColors.agentViolet)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Save
              Expanded(
                child: GestureDetector(
                  onTap: (_result?.valid == true && !_saving) ? _save : null,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _result?.valid == true ? SpatialColors.noorGradient : null,
                      color: _result?.valid != true ? SpatialColors.surfaceMuted : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Add', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _result?.valid == true ? Colors.white : SpatialColors.textMuted)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
