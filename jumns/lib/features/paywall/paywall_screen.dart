import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/utils/url_helper.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(subscriptionNotifierProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionNotifierProvider);

    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: SpatialColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildSphereCluster(),
                    const SizedBox(height: 20),
                    Text(
                      'Unlock Jems Pro',
                      style: GoogleFonts.plusJakartaSans(
                        color: SpatialColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Supercharge your AI assistant',
                      style: GoogleFonts.inter(
                        color: SpatialColors.textTertiary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ..._proFeatures.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SpatialColors.agentGreen.withAlpha(30),
                                ),
                                child: Icon(Icons.check,
                                    color: SpatialColors.agentGreen, size: 14),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(f,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: SpatialColors.textSecondary,
                                    fontSize: 15, fontWeight: FontWeight.w500,
                                  )),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),

                    if (sub.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(
                            color: SpatialColors.agentGreen),
                      )
                    else ...[
                      _PlanCard(
                        title: 'Monthly', price: '\$9.99',
                        subtitle: 'per month',
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      const SizedBox(height: 12),
                      _PlanCard(
                        title: 'Annual', price: '\$79.99',
                        subtitle: 'per year', badge: 'SAVE 33%',
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      const SizedBox(height: 28),
                      _buildInfoBanner(
                        'In-app purchases are not available in local dev mode.',
                        isError: false,
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              openUrl(context, JemsUrls.termsOfService),
                          child: Text('Terms',
                              style: GoogleFonts.inter(
                                  color: SpatialColors.textMuted, fontSize: 11)),
                        ),
                        Text('·',
                            style: TextStyle(color: SpatialColors.textMuted)),
                        TextButton(
                          onPressed: () =>
                              openUrl(context, JemsUrls.privacyPolicy),
                          child: Text('Privacy',
                              style: GoogleFonts.inter(
                                  color: SpatialColors.textMuted, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSphereCluster() {
    const spheres = [
      SpatialColors.noorGradient, SpatialColors.kaiGradient,
      SpatialColors.sageGradient, SpatialColors.echoGradient,
    ];
    return SizedBox(
      width: 100, height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 8, top: 8, child: _miniSphere(spheres[0], 40)),
          Positioned(right: 8, top: 12, child: _miniSphere(spheres[1], 34)),
          Positioned(left: 12, bottom: 10, child: _miniSphere(spheres[2], 32)),
          Positioned(right: 6, bottom: 6, child: _miniSphere(spheres[3], 36)),
        ],
      ),
    );
  }

  Widget _miniSphere(RadialGradient gradient, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle, gradient: gradient,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12,
              offset: const Offset(4, 6)),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String text, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFEF4444).withAlpha(15)
            : SpatialColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444).withAlpha(50)
              : SpatialColors.surfaceMuted,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: isError
                  ? const Color(0xFFEF4444)
                  : SpatialColors.textTertiary,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    color: isError
                        ? const Color(0xFFEF4444)
                        : SpatialColors.textTertiary,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  static const _proFeatures = [
    'Unlimited AI messages',
    'Unlimited goals & tasks',
    'Advanced AI memory',
    'All skills & MCP tools',
    'Voice mode',
    'Priority AI responses',
  ];
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title, required this.price, required this.subtitle,
    this.badge, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? SpatialColors.surface : SpatialColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? SpatialColors.agentGreen.withAlpha(120)
                : SpatialColors.surfaceMuted,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: SpatialColors.agentGreen.withAlpha(25),
                      blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withAlpha(8),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ]
              : [BoxShadow(color: Colors.black.withAlpha(10),
                    blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? SpatialColors.agentGreen : SpatialColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(child: Container(width: 12, height: 12,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SpatialColors.agentGreen)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title, style: GoogleFonts.plusJakartaSans(
                        color: SpatialColors.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w600)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SpatialColors.agentGreen,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(badge!,
                            style: GoogleFonts.inter(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(
                      color: SpatialColors.textTertiary, fontSize: 13)),
                ],
              ),
            ),
            Text(price, style: GoogleFonts.plusJakartaSans(
                color: SpatialColors.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
