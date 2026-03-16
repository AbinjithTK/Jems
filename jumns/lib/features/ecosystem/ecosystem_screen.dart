import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/providers/marketplace_provider.dart';

/// Ecosystem Hub — agent carousel, connections grid, marketplace.
class EcosystemScreen extends ConsumerWidget {
  const EcosystemScreen({super.key});

  /// Fallback carousel when API fails — show the 4 default agents.
  Widget _buildFallbackCarousel() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: const [
        _AgentCarouselItem(color: 'green', label: 'Noor', subtitle: 'Hub'),
        SizedBox(width: 20),
        _AgentCarouselItem(color: 'yellow', label: 'Kai', subtitle: 'Schedule'),
        SizedBox(width: 20),
        _AgentCarouselItem(color: 'violet', label: 'Echo', subtitle: 'Journal'),
        SizedBox(width: 20),
        _AgentCarouselItem(color: 'pink', label: 'Sage', subtitle: 'Lounge'),
      ],
    );
  }

  /// Map agent data to a color key string for AgentSphere.
  String _agentColorKey(Map<String, dynamic> a) {
    final name = (a['name'] as String? ?? '').toLowerCase();
    if (name.contains('noor')) return 'green';
    if (name.contains('kai')) return 'yellow';
    if (name.contains('echo')) return 'violet';
    if (name.contains('sage')) return 'pink';
    // Fallback: cycle through colors
    return 'green';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Compact header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const AgentSphere(agentColor: 'green', size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'ECOSYSTEM',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: SpatialColors.agentGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Agent carousel — dynamic from API
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'YOUR TEAM',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.1, color: SpatialColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: ref.watch(teamAgentsProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _buildFallbackCarousel(),
                    data: (agents) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: agents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 20),
                      itemBuilder: (context, i) {
                        final a = agents[i];
                        final isMarketplace = a['isMarketplace'] == true;
                        final color = _agentColorKey(a);
                        final label = a['displayName'] as String? ?? a['name'] as String? ?? '';
                        final subtitle = isMarketplace ? 'Marketplace' : (a['tab'] as String? ?? '').replaceAll('/', '');
                        return _AgentCarouselItem(
                          color: color,
                          label: label,
                          subtitle: subtitle.isEmpty ? 'Agent' : subtitle[0].toUpperCase() + subtitle.substring(1),
                          accentHex: isMarketplace ? a['accent'] as String? : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // Connections grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONNECTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.1, color: SpatialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _ConnectionCard(icon: Icons.extension_rounded, label: 'MCP Servers', status: 'Manage', color: SpatialColors.agentViolet, onTap: () => context.go('/ecosystem/mcp')),
                _ConnectionCard(icon: Icons.people_rounded, label: 'Friends', status: 'A2A Social', color: SpatialColors.agentPink, onTap: () => context.go('/ecosystem/friends')),
                _ConnectionCard(icon: Icons.calendar_today_rounded, label: 'Calendar', status: 'Connected', color: SpatialColors.agentYellow),
                _ConnectionCard(icon: Icons.code_rounded, label: 'GitHub', status: 'Connected', color: SpatialColors.textPrimary),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),

          // Marketplace button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => context.go('/ecosystem/marketplace'),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SpatialColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: SpatialColors.surfaceSubtle),
                    boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: SpatialColors.agentViolet.withAlpha(26),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: SpatialColors.agentViolet, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agent Marketplace', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('Discover new specialized agents', style: GoogleFonts.inter(fontSize: 12, color: SpatialColors.textTertiary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: SpatialColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }
}

class _AgentCarouselItem extends StatelessWidget {
  final String color;
  final String label;
  final String subtitle;
  final String? accentHex;

  const _AgentCarouselItem({required this.color, required this.label, required this.subtitle, this.accentHex});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AgentSphere(agentColor: color, size: 64),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: SpatialColors.textTertiary)),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color color;
  final VoidCallback? onTap;

  const _ConnectionCard({required this.icon, required this.label, required this.status, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SpatialColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpatialColors.surfaceSubtle),
          boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary)),
                const SizedBox(height: 2),
                Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: SpatialColors.agentGreen)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
