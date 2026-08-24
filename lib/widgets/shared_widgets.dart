import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/trip_provider.dart';

// ── Member Avatar ─────────────────────────────────────
class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;
  final List<String> allMembers;

  const MemberAvatar({
    super.key,
    required this.name,
    required this.allMembers,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    int rawIdx;
    try {
      final trip = context.read<TripProvider>().activeTrip;
      final member = trip?.allMembers.where((m) => m.name == name).firstOrNull;
      final listPos = allMembers.indexOf(name);
      final defaultIdx = listPos < 0
          ? 0
          : AppTheme.memberColorOrder[listPos % AppTheme.memberColorOrder.length];
      rawIdx = member?.colorIndex ?? defaultIdx;
    } catch (_) {
      final listPos = allMembers.indexOf(name);
      rawIdx = listPos < 0
          ? 0
          : AppTheme.memberColorOrder[listPos % AppTheme.memberColorOrder.length];
    }
    final idx = rawIdx % AppTheme.avatarPalette.length;
    final colors = AppTheme.avatarPalette[idx < 0 ? 0 : idx];
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors[0], shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: colors[1],
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Fluent Card ───────────────────────────────────────
class FluentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const FluentCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ── Section Header ────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: c.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  factory StatusBadge.green(String label) =>
      StatusBadge(label: label, color: AppTheme.green, bgColor: AppTheme.greenFill);
  factory StatusBadge.red(String label) =>
      StatusBadge(label: label, color: AppTheme.red, bgColor: AppTheme.redFill);
  factory StatusBadge.orange(String label) =>
      StatusBadge(label: label, color: AppTheme.orange, bgColor: AppTheme.orangeFill);
  factory StatusBadge.blue(String label) =>
      StatusBadge(label: label, color: AppTheme.blue, bgColor: AppTheme.blueFill);
  factory StatusBadge.amber(String label) =>
      StatusBadge(label: label, color: AppTheme.amber, bgColor: AppTheme.amberFill);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Metric Card ───────────────────────────────────────
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final String? subtitle;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: accentColor, width: 2.5),
          left: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: c.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: c.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

// ── Fluent List Tile ──────────────────────────────────
class FluentListTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FluentListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<FluentListTile> createState() => _FluentListTileState();
}

class _FluentListTileState extends State<FluentListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _hovered ? c.surfaceHigher : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.title,
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      widget.subtitle!,
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
