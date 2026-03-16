import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/skill.dart';
import '../../core/models/cron_job.dart';
import '../../core/providers/skills_provider.dart';
import '../../core/providers/cron_provider.dart';
import '../../core/theme/jems_colors.dart';
import '../../core/theme/charcoal_decorations.dart';

class ToolkitScreen extends ConsumerWidget {
  const ToolkitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsNotifierProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(skillsNotifierProvider.notifier).load(),
        child: skillsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48,
                    color: JemsColors.ink),
                const SizedBox(height: 12),
                Text('Could not load toolkit',
                    style: GoogleFonts.architectsDaughter(
                        color: JemsColors.ink, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () =>
                      ref.read(skillsNotifierProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (skills) => _ToolkitContent(skills: skills),
        ),
      ),
    );
  }
}

class _ToolkitContent extends ConsumerWidget {
  final List<Skill> skills;
  const _ToolkitContent({required this.skills});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mcpSkills = skills.where((s) => s.isMcp).toList();
    final agentSkills = skills.where((s) => s.isAgent).toList();
    final regularSkills =
        skills.where((s) => !s.isMcp && !s.isAgent).toList();
    final cronAsync = ref.watch(cronNotifierProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Transform.rotate(
            angle: 1 * math.pi / 180,
            child: Text('Toolkit',
                style: GoogleFonts.gloriaHallelujah(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: JemsColors.charcoal)),
          ),
        ),
        const DashedSeparator(),
        const SizedBox(height: 20),
        // ── Active Skills (2x2 blob grid) ──
        CharcoalSectionHeader(
          title: 'Active Skills',
          trailing: '${regularSkills.length + mcpSkills.length} running',
          rotation: -1,
        ),
        const SizedBox(height: 12),
        _SkillBlobGrid(skills: regularSkills),
        const SizedBox(height: 28),

        // ── Agents (horizontal scroll) ──
        CharcoalSectionHeader(
          title: 'Agents',
          trailing: '${agentSkills.length} connected',
          rotation: 1,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: agentSkills.isEmpty
              ? Center(
                  child: Text('No agents connected',
                      style: GoogleFonts.architectsDaughter(
                          color: JemsColors.ink.withAlpha(130),
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: agentSkills.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    if (i == agentSkills.length) {
                      return _AddAgentBlob();
                    }
                    return _AgentBlob(
                        skill: agentSkills[i], index: i);
                  },
                ),
        ),
        const SizedBox(height: 28),

        // ── MCP Servers ──
        CharcoalSectionHeader(
          title: 'MCP Servers',
          trailing: 'Active',
          rotation: -1,
        ),
        const SizedBox(height: 12),
        if (mcpSkills.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('No MCP servers configured',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.ink.withAlpha(130),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          )
        else
          ...mcpSkills.indexed.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _McpServerCard(skill: e.$2, index: e.$1),
              )),
        const SizedBox(height: 28),

        // ── Scheduled Jobs (Cron) ──
        CharcoalSectionHeader(
          title: 'Scheduled Jobs',
          trailing: 'Automation',
          rotation: 1,
        ),
        const SizedBox(height: 12),
        cronAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Could not load jobs',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.ink.withAlpha(130),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          data: (jobs) => jobs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 36,
                          color: JemsColors.ink.withAlpha(100)),
                      const SizedBox(height: 8),
                      Text('No scheduled jobs yet',
                          style: GoogleFonts.architectsDaughter(
                              color: JemsColors.ink.withAlpha(130),
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Ask Jems in chat to set up automations',
                          style: GoogleFonts.patrickHand(
                              color: JemsColors.ink.withAlpha(100),
                              fontSize: 13)),
                    ],
                  ),
                )
              : Column(
                  children: jobs.indexed.map((e) {
                    final (i, job) = e;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CronJobCard(job: job, index: i),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),

        // ── Toolkit Store card ──
        _ToolkitStoreCard(),
        const SizedBox(height: 100),
      ],
    );
  }
}

// ─── 2x2 Blob Grid for Skills ───

class _SkillBlobGrid extends StatelessWidget {
  final List<Skill> skills;
  const _SkillBlobGrid({required this.skills});

  static const _blobColors = [
    JemsColors.markerBlue,
    JemsColors.mint,
    JemsColors.lavender,
  ];
  static const _icons = [
    Icons.translate,
    Icons.music_note,
    Icons.schedule,
  ];

  @override
  Widget build(BuildContext context) {
    final displaySkills = skills.take(3).toList();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        ...displaySkills.indexed.map((e) {
          final (i, skill) = e;
          final color = _blobColors[i % _blobColors.length];
          return _SkillBlobTile(
            skill: skill,
            color: color,
            icon: _icons[i % _icons.length],
            variant: i,
          );
        }),
        // Add skill button
        _AddSkillBlob(),
      ],
    );
  }
}

class _SkillBlobTile extends StatelessWidget {
  final Skill skill;
  final Color color;
  final IconData icon;
  final int variant;

  const _SkillBlobTile({
    required this.skill,
    required this.color,
    required this.icon,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = variant.isEven ? 2.0 : -2.0;
    final blobVariant = variant % 4;
    final blobRadius = switch (blobVariant) {
      1 => const BorderRadius.only(
          topLeft: Radius.elliptical(34, 49),
          topRight: Radius.elliptical(66, 62),
          bottomLeft: Radius.elliptical(70, 38),
          bottomRight: Radius.elliptical(30, 51)),
      2 => const BorderRadius.only(
          topLeft: Radius.elliptical(42, 45),
          topRight: Radius.elliptical(58, 45),
          bottomLeft: Radius.elliptical(70, 55),
          bottomRight: Radius.elliptical(30, 55)),
      _ => const BorderRadius.only(
          topLeft: Radius.elliptical(64, 55),
          topRight: Radius.elliptical(36, 58),
          bottomLeft: Radius.elliptical(27, 42),
          bottomRight: Radius.elliptical(73, 45)),
    };

    return Stack(
      children: [
        // Color blob behind
        Positioned.fill(
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: color.withAlpha(200),
                borderRadius: blobRadius,
              ),
            ),
          ),
        ),
        // Foreground card
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(100),
              borderRadius: blobRadius,
              border: Border.all(color: JemsColors.ink, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: JemsColors.charcoal),
                const SizedBox(height: 8),
                Text(skill.name,
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: JemsColors.charcoal),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddSkillBlob extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.elliptical(34, 49),
          topRight: Radius.elliptical(66, 62),
          bottomLeft: Radius.elliptical(70, 38),
          bottomRight: Radius.elliptical(30, 51),
        ),
        border: Border.all(
            color: JemsColors.ink, width: 2, style: BorderStyle.none),
        color: JemsColors.paperDark.withAlpha(80),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.elliptical(34, 49),
            topRight: Radius.elliptical(66, 62),
            bottomLeft: Radius.elliptical(70, 38),
            bottomRight: Radius.elliptical(30, 51),
          ),
          border: Border.all(
              color: JemsColors.ink, width: 2, style: BorderStyle.none),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 32,
                  color: JemsColors.ink.withAlpha(150)),
              const SizedBox(height: 4),
              Text('Add Skill',
                  style: GoogleFonts.architectsDaughter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: JemsColors.ink.withAlpha(150))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JemsColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(20)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
            metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Agent blob avatar (horizontal scroll) ───

class _AgentBlob extends StatelessWidget {
  final Skill skill;
  final int index;
  const _AgentBlob({required this.skill, required this.index});

  static const _colors = [
    JemsColors.coral,
    JemsColors.markerBlue,
    JemsColors.mint,
    JemsColors.lavender,
  ];
  static const _icons = [
    Icons.face_3,
    Icons.smart_toy,
    Icons.psychology,
    Icons.auto_awesome,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    final icon = _icons[index % _icons.length];
    final variant = index % 4;

    return SizedBox(
      width: 110,
      child: Column(
        children: [
          Stack(
            children: [
              // Color blob behind
              Positioned.fill(
                child: Transform.rotate(
                  angle: (index.isEven ? -3 : 3) * math.pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withAlpha(230),
                      borderRadius: BlobShape(
                              color: color, child: const SizedBox())
                          ._radiusForVariant(variant),
                    ),
                  ),
                ),
              ),
              // Avatar
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(80),
                  borderRadius: BlobShape(
                          color: color, child: const SizedBox())
                      ._radiusForVariant(variant),
                  border: Border.all(color: JemsColors.ink, width: 2),
                ),
                child: Center(
                  child: Icon(icon, size: 40, color: JemsColors.charcoal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(skill.name,
              style: GoogleFonts.architectsDaughter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.charcoal),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(skill.description,
              style: GoogleFonts.patrickHand(
                  fontSize: 12,
                  color: JemsColors.ink.withAlpha(150)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _AddAgentBlob extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(34, 49),
                topRight: Radius.elliptical(66, 62),
                bottomLeft: Radius.elliptical(70, 38),
                bottomRight: Radius.elliptical(30, 51),
              ),
              border: Border.all(
                  color: JemsColors.ink,
                  width: 2,
                  style: BorderStyle.none),
              color: JemsColors.paperDark.withAlpha(80),
            ),
            child: Center(
              child: Icon(Icons.add, size: 32,
                  color: JemsColors.ink.withAlpha(130)),
            ),
          ),
          const SizedBox(height: 8),
          Text('New Agent',
              style: GoogleFonts.architectsDaughter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.ink.withAlpha(150))),
        ],
      ),
    );
  }
}

// ─── MCP Server card ───

class _McpServerCard extends StatelessWidget {
  final Skill skill;
  final int index;
  const _McpServerCard({required this.skill, required this.index});

  static const _icons = [Icons.public, Icons.calendar_month, Icons.folder_open];

  @override
  Widget build(BuildContext context) {
    final rotation = index.isEven ? -1.0 : 0.5;
    final isConnected = skill.isConnected;

    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: isConnected
            ? charcoalBorderDecoration()
            : BoxDecoration(
                color: JemsColors.paperDark.withAlpha(50),
                borderRadius: kCharcoalRadius,
                border: Border.all(
                    color: JemsColors.ink,
                    width: 2,
                    style: BorderStyle.none),
              ),
        child: Row(
          children: [
            BlobShape(
              color: JemsColors.paper,
              size: 48,
              variant: index % 4,
              child: Icon(_icons[index % _icons.length],
                  color: JemsColors.charcoal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.architectsDaughter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: JemsColors.charcoal)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? JemsColors.success
                              : JemsColors.amber,
                          border: Border.all(
                              color: JemsColors.ink, width: 1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        skill.status,
                        style: GoogleFonts.patrickHand(
                            fontSize: 12,
                            color: JemsColors.ink.withAlpha(130)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.settings,
                color: JemsColors.ink.withAlpha(130), size: 20),
          ],
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Toolkit Store coming soon')),
  );
}

// ─── Cron Job card ───

class _CronJobCard extends ConsumerWidget {
  final CronJob job;
  final int index;
  const _CronJobCard({required this.job, required this.index});

  static const _icons = [Icons.alarm, Icons.repeat, Icons.event, Icons.timer];
  static const _colors = [
    JemsColors.mint,
    JemsColors.markerBlue,
    JemsColors.lavender,
    JemsColors.amber,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotation = index.isEven ? -0.5 : 0.8;
    final color = _colors[index % _colors.length];

    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: charcoalBorderDecoration(),
        child: Row(
          children: [
            BlobShape(
              color: color.withAlpha(job.enabled ? 200 : 80),
              size: 44,
              variant: index % 4,
              child: Icon(
                _icons[index % _icons.length],
                color: JemsColors.charcoal,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.architectsDaughter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: job.enabled
                          ? JemsColors.charcoal
                          : JemsColors.ink.withAlpha(100),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.scheduleDisplay,
                    style: GoogleFonts.patrickHand(
                      fontSize: 12,
                      color: JemsColors.ink.withAlpha(130),
                    ),
                  ),
                  if (job.runCount > 0)
                    Text(
                      'Ran ${job.runCount}x',
                      style: GoogleFonts.patrickHand(
                        fontSize: 11,
                        color: JemsColors.ink.withAlpha(100),
                      ),
                    ),
                ],
              ),
            ),
            // Toggle switch
            Switch(
              value: job.enabled,
              onChanged: (val) {
                ref.read(cronNotifierProvider.notifier).toggle(job.id, val);
              },
              activeColor: JemsColors.mint,
              inactiveThumbColor: JemsColors.ink.withAlpha(80),
            ),
            // Run now button
            GestureDetector(
              onTap: () {
                ref.read(cronNotifierProvider.notifier).runNow(job.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Running "${job.name}"...')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.play_arrow,
                    color: JemsColors.ink.withAlpha(150), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toolkit Store card ───

class _ToolkitStoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: JemsColors.paperDark.withAlpha(80),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: JemsColors.ink,
                width: 2,
                style: BorderStyle.none),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Toolkit Store',
                      style: GoogleFonts.gloriaHallelujah(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: JemsColors.charcoal)),
                  const SizedBox(height: 8),
                  Text(
                    'Discover new AI capabilities and integrations sketched by the community.',
                    style: GoogleFonts.architectsDaughter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: JemsColors.ink.withAlpha(200)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showComingSoon(context),
                      child: const Text('Browse Store'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Decorative blob
        Positioned(
          right: -8,
          bottom: -8,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: JemsColors.lavender.withAlpha(100),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(64, 55),
                topRight: Radius.elliptical(36, 58),
                bottomLeft: Radius.elliptical(27, 42),
                bottomRight: Radius.elliptical(73, 45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Helper extension for blob radius
extension on BlobShape {
  BorderRadius _radiusForVariant(int variant) => switch (variant) {
        1 => const BorderRadius.only(
            topLeft: Radius.elliptical(34, 49),
            topRight: Radius.elliptical(66, 62),
            bottomLeft: Radius.elliptical(70, 38),
            bottomRight: Radius.elliptical(30, 51)),
        2 => const BorderRadius.only(
            topLeft: Radius.elliptical(42, 45),
            topRight: Radius.elliptical(58, 45),
            bottomLeft: Radius.elliptical(70, 55),
            bottomRight: Radius.elliptical(30, 55)),
        3 => const BorderRadius.only(
            topLeft: Radius.elliptical(73, 57),
            topRight: Radius.elliptical(27, 59),
            bottomLeft: Radius.elliptical(59, 41),
            bottomRight: Radius.elliptical(41, 43)),
        _ => const BorderRadius.only(
            topLeft: Radius.elliptical(64, 55),
            topRight: Radius.elliptical(36, 58),
            bottomLeft: Radius.elliptical(27, 42),
            bottomRight: Radius.elliptical(73, 45)),
      };
}
