import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import 'premium_sheet.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final s = settings.strings;
    final accent = settings.accentColor;
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).viewPadding.top + 8,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header — mismo estilo que edit_members_sheet
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Text(
                  s.settings,
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.surfaceHigher,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 20),

          // ── Upgrade cards ─────────────────────────────────
          if (!settings.hasAnyPremium) ...[
            _UpgradeCard(
              icon: FluentIcons.crown_24_filled,
              title: 'Nivela Premium',
              subtitle: s.premiumCardSubtitle,
              badge: s.premiumBuyButton,
              accent: accent,
              c: c,
              onTap: () { Navigator.pop(context); showPremiumSheet(context); },
            ),
            const SizedBox(height: 8),
            _UpgradeCard(
              icon: FluentIcons.star_24_filled,
              title: 'Nivela Ultimate',
              subtitle: s.ultimateCardSubtitle,
              badge: s.ultimatePriceMonthly,
              accent: const Color(0xFF9B82D4),
              c: c,
              onTap: () { Navigator.pop(context); showPremiumSheet(context); },
            ),
            const SizedBox(height: 20),
          ] else if (settings.isPremium && !settings.isUltimate) ...[
            _UpgradeCard(
              icon: FluentIcons.star_24_filled,
              title: 'Nivela Ultimate',
              subtitle: s.ultimateCardSubtitle,
              badge: s.ultimatePriceMonthly,
              accent: const Color(0xFF9B82D4),
              c: c,
              onTap: () { Navigator.pop(context); showPremiumSheet(context); },
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // ── Export section ────────────────────────
          Builder(
            builder: (ctx) {
              final trip = context.read<TripProvider>().activeTrip;
              if (trip == null) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(s.exportSection),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ExportBtn(
                          icon: FluentIcons.document_pdf_24_regular,
                          label: s.exportPdf,
                          onTap: () async {
                            if (!settings.hasAnyPremium) {
                              showPremiumSheet(context); return;
                            }
                            await ExportService.exportPdf(context, trip, s);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ExportBtn(
                          icon: FluentIcons.table_24_regular,
                          label: s.exportCsv,
                          onTap: () async {
                            if (!settings.hasAnyPremium) {
                              showPremiumSheet(context); return;
                            }
                            await ExportService.exportCsv(context, trip, s);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Backup section ──────────────────────
                  _SectionLabel(s.backupSection),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ExportBtn(
                          icon: FluentIcons.cloud_arrow_up_24_regular,
                          label: s.backupExport,
                          onTap: () async {
                            if (!settings.hasAnyPremium) {
                              showPremiumSheet(context); return;
                            }
                            await BackupService.exportAll(context, s);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ExportBtn(
                          icon: FluentIcons.cloud_arrow_down_24_regular,
                          label: s.backupImport,
                          onTap: () async {
                            if (!settings.hasAnyPremium) {
                              showPremiumSheet(context); return;
                            }
                            final ok = await BackupService.importAll(context, s);
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // ── Accent color ──────────────────────────
          _SectionLabel(s.accentColor),
          const SizedBox(height: 12),
          _ColorGrid(
            current: accent,
            onChange: settings.setAccentColor,
          ),
          const SizedBox(height: 24),

          // ── Style ─────────────────────────────────
          _SectionLabel(s.style),
          const SizedBox(height: 12),
          _StyleSelector(
            current: settings.style,
            onChange: settings.setStyle,
            strings: s,
            accent: accent,
          ),
          const SizedBox(height: 24),

          // ── Language ──────────────────────────────
          _SectionLabel(s.language),
          const SizedBox(height: 12),
          _LangToggle(
            current: settings.language,
            onChange: settings.setLanguage,
            strings: s,
            accent: accent,
          ),
          const SizedBox(height: 16),

          // ── About ─────────────────────────────────
          Divider(color: c.border, thickness: 1, height: 1),
          _AboutRow(label: s.aboutTitle),
        ],
      ),
    ),
  );
  }
}

// ── Section label ─────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: GoogleFonts.inter(
        color: c.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Color grid ────────────────────────────────────
class _ColorGrid extends StatelessWidget {
  final Color current;
  final void Function(Color) onChange;

  const _ColorGrid({required this.current, required this.onChange});

  static const _presets = [
    Color(0xFFC8592A), // orange (default)
    Color(0xFFE05C5C), // red
    Color(0xFFD4A017), // amber
    Color(0xFF7ED44F), // lime
    Color(0xFF4CAF7D), // green
    Color(0xFF4CBFBF), // teal
    Color(0xFF4FA3D4), // blue
    Color(0xFF9B82D4), // purple
    Color(0xFFB05AD4), // violet
    Color(0xFFD4679C), // pink
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: _presets.map((c) {
      final selected = c.toARGB32() == current.toARGB32();
      return GestureDetector(
        onTap: () => onChange(c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 1)]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      );
    }).toList(),
  );
}

// ── Style selector ────────────────────────────────
class _StyleSelector extends StatelessWidget {
  final AppStyle current;
  final void Function(AppStyle) onChange;
  final AppStrings strings;
  final Color accent;

  const _StyleSelector({
    required this.current,
    required this.onChange,
    required this.strings,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final styles = AppStyle.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(styles.length, (i) {
        final style = styles[i];
        final label = switch (style) {
          AppStyle.dark => strings.styleDark,
          AppStyle.midnight => strings.styleMidnight,
          AppStyle.slate => strings.styleSlate,
          AppStyle.light => strings.styleLight,
        };
        final bg = AppTheme.styleBg(style);
        final selected = style == current;
        final itemWidth = (MediaQuery.of(context).size.width - 48 - 8) / 2;
        return SizedBox(
          width: itemWidth,
          child: GestureDetector(
            onTap: () => onChange(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: bg[0],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? accent : c.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MiniDot(bg[1], c.border),
                      const SizedBox(width: 4),
                      _MiniDot(bg[3], c.border),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: selected ? accent : c.textSecondary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  const _MiniDot(this.color, this.borderColor);
  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: borderColor.withValues(alpha: 0.6)),
    ),
  );
}

// ── Language toggle ───────────────────────────────
class _LangToggle extends StatelessWidget {
  final AppLanguage current;
  final void Function(AppLanguage) onChange;
  final AppStrings strings;
  final Color accent;

  const _LangToggle({
    required this.current,
    required this.onChange,
    required this.strings,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    const langs = [
      (AppLanguage.en, 'English'),
      (AppLanguage.es, 'Español'),
      (AppLanguage.fr, 'Français'),
      (AppLanguage.zh, '中文'),
      (AppLanguage.ja, '日本語'),
      (AppLanguage.ko, '한국어'),
      (AppLanguage.ru, 'Русский'),
      (AppLanguage.de, 'Deutsch'),
      (AppLanguage.it, 'Italiano'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: langs.map((entry) {
        final (lang, label) = entry;
        return _LangBtn(
          label: label,
          selected: current == lang,
          onTap: () => onChange(lang),
          accent: accent,
        );
      }).toList(),
    );
  }
}

// ── Export button ─────────────────────────────────
class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExportBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.surfaceHigher,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── About row ─────────────────────────────────────
class _AboutRow extends StatelessWidget {
  final String label;
  const _AboutRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAboutSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(FluentIcons.info_24_regular, color: c.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

void _showAboutSheet(BuildContext context) {
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (_, snap) => Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: c.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Logo
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1008),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'logo_nivela.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),

          // App name
          Text(
            'Nivela',
            style: GoogleFonts.inter(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${snap.data?.version ?? '...'}',
            style: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Divide y gestiona los gastos de tus viajes\nde forma sencilla y sin complicaciones.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Info rows
          _AboutInfoRow(
            icon: FluentIcons.person_24_regular,
            label: 'Desarrollador',
            value: 'Garrobo Dev',
            c: c,
          ),
          Divider(color: c.border, height: 1),
          _AboutInfoRow(
            icon: FluentIcons.mail_24_regular,
            label: 'Contacto',
            value: 'hola@nivelaapp.com',
            c: c,
          ),
          Divider(color: c.border, height: 1),
          _AboutInfoRow(
            icon: FluentIcons.shield_24_regular,
            label: 'Privacidad',
            value: 'Política de privacidad',
            c: c,
          ),
          Divider(color: c.border, height: 1),
          _AboutInfoRow(
            icon: FluentIcons.document_24_regular,
            label: 'Términos',
            value: 'Términos de uso',
            c: c,
          ),
          const SizedBox(height: 24),

          // Copyright
          Text(
            '© 2026 Nivela. Todos los derechos reservados.',
            style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
          ),

          // Debug toggle — only visible in debug builds
          if (kDebugMode) ...[
            const SizedBox(height: 20),
            _DebugPremiumToggle(c: c),
          ],
        ],
        ),
      ),
    ),
    ),
  );
}

class _AboutInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColors c;
  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.c,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.inter(
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
      ],
    ),
  );
}

// ── Debug premium toggle (only shown in debug builds) ─
class _DebugPremiumToggle extends StatelessWidget {
  final AppColors c;
  const _DebugPremiumToggle({required this.c});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Column(
      children: [
        _DebugTierBtn(
          label: 'Premium',
          active: settings.isPremium,
          onTap: () => settings.setPremium(!settings.isPremium),
          c: c,
        ),
        const SizedBox(height: 8),
        _DebugTierBtn(
          label: 'Ultimate',
          active: settings.isUltimate,
          onTap: () => settings.setUltimate(!settings.isUltimate),
          c: c,
        ),
      ],
    );
  }
}

class _DebugTierBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors c;
  const _DebugTierBtn({
    required this.label,
    required this.active,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CAF7D);
    const red   = Color(0xFFE05C5C);
    final color = active ? green : red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 16, color: color,
            ),
            const SizedBox(width: 8),
            Text(
              active
                  ? 'DEBUG: $label activo — toca para desactivar'
                  : 'DEBUG: Sin $label — toca para activar',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upgrade card ──────────────────────────────────────
class _UpgradeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color accent;
  final AppColors c;
  final VoidCallback onTap;

  const _UpgradeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accent,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.15),
              accent.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _LangBtn({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final itemWidth = (MediaQuery.of(context).size.width - 48 - 16) / 3;
    return SizedBox(
      width: itemWidth,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : c.surfaceHigher,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? accent : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? accent : c.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
