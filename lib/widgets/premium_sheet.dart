import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

void showPremiumSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PremiumSheet(),
  );
}

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    const ultimateAccent = Color(0xFF9B82D4);
    final bottom = MediaQuery.of(context).padding.bottom;
    final s = context.watch<SettingsProvider>().strings;
    final settings = context.watch<SettingsProvider>();

    return Container(
      padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: c.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── PREMIUM TIER ──────────────────────────────
            if (!settings.isPremium) ...[
              _TierHeader(
                icon: FluentIcons.crown_24_filled,
                iconColor: accent,
                title: 'Nivela Premium',
                subtitle: s.premiumOnce,
                c: c,
              ),
              const SizedBox(height: 16),
              _FeatureRow(text: s.premiumFeatureNoAds, accent: accent, c: c),
              const SizedBox(height: 10),
              _FeatureRow(text: s.premiumFeatureExport, accent: accent, c: c),
              const SizedBox(height: 10),
              _FeatureRow(text: s.premiumFeatureTrips, accent: accent, c: c),
              const SizedBox(height: 10),
              _FeatureRow(text: s.premiumFeatureWidgets, accent: accent, c: c),
              const SizedBox(height: 10),
              _FeatureRow(text: s.ultimateFeatureBackup, accent: accent, c: c),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: settings.purchasePending
                      ? null
                      : () => context.read<SettingsProvider>().buyPremium(),
                  child: settings.purchasePending
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s.premiumBuyButton),
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 24),
            ],

            // ── ULTIMATE TIER ─────────────────────────────
            if (!settings.isUltimate) ...[
              _TierHeader(
                icon: FluentIcons.star_24_filled,
                iconColor: ultimateAccent,
                title: 'Nivela Ultimate',
                subtitle: s.ultimateCardSubtitle,
                c: c,
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                  text: s.ultimateFeatureAllPremium,
                  accent: ultimateAccent,
                  c: c),
              const SizedBox(height: 10),
              _FeatureRow(
                  text: s.ultimateFeatureCloud,
                  accent: ultimateAccent,
                  c: c),
              const SizedBox(height: 20),

              // Monthly / Annual side-by-side
              Row(
                children: [
                  Expanded(
                    child: _PriceButton(
                      label: s.ultimateBuyMonthly,
                      price: s.ultimatePriceMonthly,
                      badge: null,
                      accent: ultimateAccent,
                      filled: false,
                      pending: settings.purchasePending,
                      onTap: () => context
                          .read<SettingsProvider>()
                          .buyUltimateMonthly(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PriceButton(
                      label: s.ultimateBuyAnnual,
                      price: s.ultimatePriceAnnual,
                      badge: s.ultimateAnnualBadge,
                      accent: ultimateAccent,
                      filled: true,
                      pending: settings.purchasePending,
                      onTap: () => context
                          .read<SettingsProvider>()
                          .buyUltimateAnnual(),
                    ),
                  ),
                ],
              ),
            ],

            // Already has both tiers
            if (settings.isPremium && settings.isUltimate) ...[
              Center(
                child: Text(
                  s.premiumComingSoon,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () =>
                    context.read<SettingsProvider>().restorePurchases(),
                child: Text(
                  s.premiumRestoreButton,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Price button ──────────────────────────────────────
class _PriceButton extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final Color accent;
  final bool filled;
  final bool pending;
  final VoidCallback onTap;

  const _PriceButton({
    required this.label,
    required this.price,
    required this.badge,
    required this.accent,
    required this.filled,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending)
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : accent,
            ),
          )
        else ...[
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: filled
                    ? Colors.white.withValues(alpha: 0.25)
                    : accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : accent,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: filled
                  ? Colors.white.withValues(alpha: 0.8)
                  : c.textMuted,
            ),
          ),
        ],
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: pending ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: content,
      );
    } else {
      return OutlinedButton(
        onPressed: pending ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: content,
      );
    }
  }
}

// ── Tier header ───────────────────────────────────────
class _TierHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppColors c;

  const _TierHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final Color accent;
  final AppColors c;
  const _FeatureRow({
    required this.text,
    required this.accent,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(FluentIcons.checkmark_circle_24_filled, color: accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
