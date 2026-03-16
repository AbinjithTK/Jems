import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/models/marketplace_agent.dart';
import '../../core/providers/marketplace_provider.dart';

/// Agent Marketplace — browse and install specialized agents.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(marketplaceCatalogProvider);
    final installedAsync = ref.watch(installedAgentsProvider);

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: SpatialColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18, color: SpatialColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.storefront_rounded, color: SpatialColors.agentViolet, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'MARKETPLACE',
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        letterSpacing: 1.2, color: SpatialColors.agentViolet,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Discover specialized agents to add to your team.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: SpatialColors.textTertiary),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Agent grid
            catalogAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text('Failed to load marketplace', style: GoogleFonts.inter(color: SpatialColors.textTertiary)),
                )),
              ),
              data: (catalog) {
                final installedIds = installedAsync.valueOrNull?.map((a) => a.id).toSet() ?? {};
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                    children: catalog.map((agent) {
                      final installed = installedIds.contains(agent.id);
                      return _MarketplaceCard(agent: agent, installed: installed);
                    }).toList(),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCard extends ConsumerWidget {
  final MarketplaceAgent agent;
  final bool installed;

  const _MarketplaceCard({required this.agent, required this.installed});

  Color _parseAccent() {
    try {
      final hex = agent.accent.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return SpatialColors.textTertiary;
    }
  }

  IconData _iconFromName() => switch (agent.icon) {
        'fitness_center' => Icons.fitness_center_rounded,
        'account_balance_wallet' => Icons.account_balance_wallet_rounded,
        'restaurant' => Icons.restaurant_rounded,
        'school' => Icons.school_rounded,
        _ => Icons.extension_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseAccent();
    final actions = ref.watch(marketplaceActionsProvider);
    final isLoading = actions is AsyncLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpatialColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: installed ? color.withAlpha(77) : SpatialColors.surfaceSubtle),
        boxShadow: [BoxShadow(offset: const Offset(0, 1), blurRadius: 2, color: Colors.black.withAlpha(13))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sphere preview
          Center(
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  radius: 0.9,
                  colors: [color.withAlpha(77), color.withAlpha(153), color],
                ),
                boxShadow: [BoxShadow(offset: const Offset(4, 6), blurRadius: 12, color: color.withAlpha(51))],
              ),
              child: Icon(_iconFromName(), color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            agent.displayName,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SpatialColors.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              agent.description,
              style: GoogleFonts.inter(fontSize: 11, color: SpatialColors.textTertiary, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          // Publisher + version
          Text(
            '${agent.publisher} · v${agent.version}',
            style: GoogleFonts.inter(fontSize: 9, color: SpatialColors.textMuted),
          ),
          const SizedBox(height: 8),
          // Install / Uninstall button
          SizedBox(
            width: double.infinity,
            height: 32,
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      final notifier = ref.read(marketplaceActionsProvider.notifier);
                      if (installed) {
                        notifier.uninstall(agent.id);
                      } else {
                        notifier.install(agent.id);
                      }
                    },
              style: TextButton.styleFrom(
                backgroundColor: installed ? SpatialColors.surfaceSubtle : color.withAlpha(26),
                foregroundColor: installed ? SpatialColors.textTertiary : color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                installed ? 'Remove' : 'Add to Team',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
