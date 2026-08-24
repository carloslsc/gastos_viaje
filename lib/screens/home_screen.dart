import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/edit_members_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/premium_sheet.dart';
import 'expenses_tab.dart';
import 'summary_tab.dart';
import 'debts_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final settings = context.watch<SettingsProvider>();
    final s = settings.strings;
    final trip = provider.activeTrip!;
    final balances = trip.balances;
    final isWide = MediaQuery.of(context).size.width >= 700;
    final accent = Theme.of(context).colorScheme.primary;
    final c = AppColors.of(context);

    final dests = [
      _NavDest(label: s.tabExpenses, icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
      _NavDest(label: s.tabSummary, icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
      _NavDest(label: s.tabDebts, icon: Icons.swap_horiz_outlined, activeIcon: Icons.swap_horiz),
    ];

    final titles = [s.tabExpenses, s.tabSummary, s.tabDebts];
    final subtitles = [s.subtitleExpenses, s.subtitleSummary, s.subtitleDebts];

    final body = IndexedStack(
      index: _selectedIndex,
      children: const [ExpensesTab(), SummaryTab(), DebtsTab()],
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              trip: trip,
              balances: balances,
              selectedIndex: _selectedIndex,
              dests: dests,
              strings: s,
              onSelect: (i) => setState(() => _selectedIndex = i),
              onSwitchTrip: () => _showTripSwitcher(context, s),
              onEditMembers: () => _openEditMembers(context),
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: titles[_selectedIndex],
                    subtitle: subtitles[_selectedIndex],
                    onSettings: () => _openSettings(context),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.name,
              style: GoogleFonts.inter(
                color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              titles[_selectedIndex],
              style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (!settings.hasAnyPremium)
            IconButton(
              icon: Icon(FluentIcons.crown_24_regular, color: Theme.of(context).colorScheme.primary),
              tooltip: 'Premium',
              onPressed: () => showPremiumSheet(context),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            tooltip: s.settings,
            onPressed: () => _openSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.card_travel_outlined, color: AppTheme.textSecondary),
            tooltip: s.myTrips,
            onPressed: () => _showTripSwitcher(context, s),
          ),
          IconButton(
            icon: const Icon(FluentIcons.people_edit_24_regular,
                color: AppTheme.textSecondary),
            tooltip: s.editParticipants,
            onPressed: () => _openEditMembers(context),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          child: Row(
            children: List.generate(dests.length, (i) {
              final sel = i == _selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dests[i].activeIcon,
                          size: 22,
                          color: sel ? accent : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dests[i].label.split(' ').first,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: sel ? accent : AppTheme.textMuted,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _openEditMembers(BuildContext context) {
    final trip = context.read<TripProvider>().activeTrip!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TripProvider>(),
        child: EditMembersSheet(
          allMembers: trip.allMembers,
          expenses: trip.expenses,
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<SettingsProvider>()),
          ChangeNotifierProvider.value(value: context.read<TripProvider>()),
        ],
        child: const SettingsSheet(),
      ),
    );
  }

  void _showTripSwitcher(BuildContext context, AppStrings s) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<TripProvider>(),
          child: _TripSwitcherSheet(
            strings: s,
            onNewTrip: () {
              Navigator.pop(context);
              _confirmNewTrip(context, s);
            },
          ),
        ),
      );

  void _confirmNewTrip(BuildContext context, AppStrings s) {
    final hasAnyPremium = context.read<SettingsProvider>().hasAnyPremium;
    final tripCount = context.read<TripProvider>().trips.length;
    if (!hasAnyPremium && tripCount >= 1) {
      showPremiumSheet(context);
      return;
    }
    final c = AppColors.of(context);
    showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      title: Text(
        s.newTripTitle,
        style: GoogleFonts.inter(
            color: c.textPrimary, fontWeight: FontWeight.w600),
      ),
      content: Text(
        s.newTripBody,
        style: GoogleFonts.inter(color: c.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.cancel,
              style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<TripProvider>().setActiveTrip('__new__');
          },
          child: Text(s.create),
        ),
      ],
    ),
  );
  }
}

// ── Trip Switcher Sheet ───────────────────────────────
class _TripSwitcherSheet extends StatelessWidget {
  final AppStrings strings;
  final VoidCallback onNewTrip;
  const _TripSwitcherSheet({required this.strings, required this.onNewTrip});

  void _confirmDelete(BuildContext context, TripProvider provider, String id, String name, AppStrings s) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
        title: Text(s.deleteTripTitle,
            style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(s.deleteTripBody,
                style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);      // cierra el diálogo
              Navigator.pop(context);  // cierra el bottom sheet
              provider.deleteTrip(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            child: Text(s.eliminate),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final trips = provider.trips;
    final activeId = provider.activeTrip?.id;
    final accent = Theme.of(context).colorScheme.primary;
    final accentFill = accent.withValues(alpha: 0.1);
    final c = AppColors.of(context);
    final s = strings;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  s.myTrips,
                  style: GoogleFonts.inter(
                    color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onNewTrip,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        s.newTrip,
                        style: GoogleFonts.inter(
                            color: accent, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: trips.length,
              itemBuilder: (ctx, i) {
                final t = trips[i];
                final isActive = t.id == activeId;
                return InkWell(
                  onTap: () {
                    if (!isActive) provider.setActiveTrip(t.id);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _confirmDelete(context, provider, t.id, t.name, s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.redFill,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                            ),
                            child: Icon(Icons.delete_outline, size: 16, color: AppTheme.red),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? accentFill : c.surfaceHigher,
                            shape: BoxShape.circle,
                            border: Border.all(color: isActive ? accent : c.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            t.name[0].toUpperCase(),
                            style: GoogleFonts.inter(
                              color: isActive ? accent : c.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.name,
                                style: GoogleFonts.inter(
                                  color: isActive ? accent : c.textPrimary,
                                  fontSize: 14,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${t.members.length} personas · ${t.currency}'
                                '${t.dateLabel.isNotEmpty ? " · ${t.dateLabel}" : ""}',
                                style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, color: accent, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSettings;
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final settings = context.watch<SettingsProvider>();
    final s = settings.strings;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 16, 18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!settings.hasAnyPremium)
            IconButton(
              onPressed: () => showPremiumSheet(context),
              icon: Icon(FluentIcons.crown_24_regular, color: Theme.of(context).colorScheme.primary, size: 22),
              tooltip: 'Premium',
            ),
          IconButton(
            onPressed: onSettings,
            icon: Icon(Icons.settings_outlined, color: c.textMuted, size: 22),
            tooltip: s.settings,
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final dynamic trip;
  final Map<String, double> balances;
  final int selectedIndex;
  final List<_NavDest> dests;
  final AppStrings strings;
  final ValueChanged<int> onSelect;
  final VoidCallback onSwitchTrip;
  final VoidCallback onEditMembers;
  final VoidCallback onSettings;

  const _Sidebar({
    required this.trip,
    required this.balances,
    required this.selectedIndex,
    required this.dests,
    required this.strings,
    required this.onSelect,
    required this.onSwitchTrip,
    required this.onEditMembers,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final sidebarColor = Theme.of(context).colorScheme.surfaceContainerLowest;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final c = AppColors.of(context);
    final s = strings;
    final isPremium = context.watch<SettingsProvider>().hasAnyPremium;

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: sidebarColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + settings
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: c.textPrimary,
                      ),
                      children: [
                        TextSpan(text: 'Ni', style: TextStyle(color: c.textPrimary)),
                        TextSpan(
                          text: 'vela',
                          style: GoogleFonts.inter(
                              color: accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isPremium)
                  IconButton(
                    onPressed: () => showPremiumSheet(context),
                    icon: Icon(FluentIcons.crown_24_regular,
                        color: Theme.of(context).colorScheme.primary, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Premium',
                  ),
                IconButton(
                  onPressed: onSettings,
                  icon: Icon(Icons.settings_outlined,
                      color: c.textMuted, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: s.settings,
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 1),

          // Trip info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.activeTrip,
                  style: GoogleFonts.inter(
                    color: c.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.dateLabel?.isNotEmpty == true ? "${trip.dateLabel} · " : ""}${trip.members.length} personas · ${trip.currency}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: _actionButton(
                        context, Icons.collections_bookmark_outlined,
                        s.myTrips, onSwitchTrip,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _actionButton(
                        context, FluentIcons.people_edit_24_regular,
                        s.editParticipants, onEditMembers,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),

          // Nav items
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: dests.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                final sel = i == selectedIndex;
                return _NavItem(
                  label: d.label,
                  icon: sel ? d.activeIcon : d.icon,
                  selected: sel,
                  onTap: () => onSelect(i),
                );
              }).toList(),
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Members
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              s.participants,
              style: GoogleFonts.inter(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: trip.members.map<Widget>((m) {
                final b = balances[m.id] ?? 0;
                final bColor = b > 0.005
                    ? AppTheme.green
                    : b < -0.005
                    ? AppTheme.red
                    : c.textMuted;
                final bText = b > 0.005
                    ? '+${trip.currency.substring(0, 2)} ${b.toStringAsFixed(0)}'
                    : b < -0.005
                    ? '-${trip.currency.substring(0, 2)} ${b.abs().toStringAsFixed(0)}'
                    : '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      MemberAvatar(
                        name: m.name,
                        allMembers: trip.members.map((x) => x.name).toList(),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m.name,
                          style: GoogleFonts.inter(
                            color: c.textSecondary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        bText,
                        style: GoogleFonts.inter(
                          color: bColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.surfaceHigher,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: c.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final c = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: 0.15)
                : _hovered
                ? c.surfaceHigher
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.selected
                ? Border.all(color: accent.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: widget.selected ? accent : c.textMuted),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: widget.selected ? accent : c.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDest {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavDest({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
