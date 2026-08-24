import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/export_service.dart';
import '../widgets/premium_sheet.dart';

// ── Category icon metadata (top-level so expandable rows can access) ─────────
const Map<String, IconData> _catIcons = {
  'food': FluentIcons.food_24_regular,
  'lodging': FluentIcons.bed_24_regular,
  'transport': FluentIcons.vehicle_car_24_regular,
  'entertainment': FluentIcons.balloon_24_regular,
  'shopping': FluentIcons.cart_24_regular,
  'activities': FluentIcons.beach_24_regular,
  'health': FluentIcons.pill_24_regular,
  'flight': FluentIcons.airplane_24_regular,
  'drinks': FluentIcons.drink_wine_24_regular,
  'fuel': FluentIcons.gas_pump_24_regular,
  'tips': FluentIcons.money_hand_24_regular,
  'parking': FluentIcons.vehicle_car_parking_24_regular,
  'other': FluentIcons.box_24_regular,
};

Map<String, double> _categoryTotals(Trip trip) {
  final map = <String, double>{};
  for (final e in trip.expenses) {
    map[e.category] = (map[e.category] ?? 0) + e.amount;
  }
  final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

// ── Activity item data ────────────────────────────────
class _ActivityItem {
  final IconData icon;
  final String label;
  final String sublabel;
  final double amount;
  final Color amountColor;
  final String amountSign;
  final DateTime date;

  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.amount,
    required this.amountColor,
    required this.amountSign,
    required this.date,
  });
}

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final settings = context.watch<SettingsProvider>();
    final s = settings.strings;
    final trip = context.watch<TripProvider>().activeTrip!;
    final balances = trip.balances;
    final total = trip.totalSpent;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Material(
      color: c.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Export buttons ────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(FluentIcons.document_pdf_24_regular, size: 16),
                    label: Text(s.exportPdf),
                    onPressed: () {
                      if (!settings.hasAnyPremium) { showPremiumSheet(context); return; }
                      ExportService.exportPdf(context, trip, s);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(FluentIcons.table_24_regular, size: 16),
                    label: Text(s.exportCsv),
                    onPressed: () {
                      if (!settings.hasAnyPremium) { showPremiumSheet(context); return; }
                      ExportService.exportCsv(context, trip, s);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Banner ad ─────────────────────────────
            const Center(child: AppBannerAd()),
            const SizedBox(height: 16),

            // ── Gráfico de consumo ────────────────────
            _ConsumptionChart(trip: trip, total: total),
            const SizedBox(height: 24),

            // ── Gráfico de torta por categoría ────────
            if (trip.expenses.isNotEmpty) ...[
              _CategoryPieChart(trip: trip),
              const SizedBox(height: 24),
            ],

            // ── Balance por persona ───────────────────
            FluentCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: SectionHeader(title: s.balancePerPerson),
                  ),
                  const Divider(height: 1),
                  ...trip.allParticipants.map((m) {
                    final paid = trip.expenses
                        .where((e) => e.payer == m.id)
                        .fold(0.0, (sum, e) => sum + e.amount);
                    final consumed = trip.expenses.fold(
                      0.0,
                      (sum, e) => sum + (e.splits[m.id] ?? 0),
                    );
                    final bal = balances[m.id] ?? 0;
                    final allNames = trip.allParticipants.map((x) => x.name).toList();

                    return _PersonBalanceRow(
                      key: ValueKey(m.id),
                      member: m,
                      trip: trip,
                      allMemberNames: allNames,
                      paid: paid,
                      consumed: consumed,
                      balance: bal,
                      totalSpent: total,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Gastos por categoría ──────────────────
            if (trip.expenses.isNotEmpty)
              FluentCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: SectionHeader(
                        title: s.expensesByCategory,
                        trailing: Text(
                          s.txCount(trip.expenses.length),
                          style: GoogleFonts.inter(
                            color: c.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ..._categoryTotals(trip).entries.map(
                      (e) => _CategoryRow(
                        key: ValueKey(e.key),
                        category: e.key,
                        amount: e.value,
                        trip: trip,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Expandable person balance row ─────────────────────
class _PersonBalanceRow extends StatefulWidget {
  final Member member;
  final Trip trip;
  final List<String> allMemberNames;
  final double paid;
  final double consumed;
  final double balance;
  final double totalSpent;

  const _PersonBalanceRow({
    super.key,
    required this.member,
    required this.trip,
    required this.allMemberNames,
    required this.paid,
    required this.consumed,
    required this.balance,
    required this.totalSpent,
  });

  @override
  State<_PersonBalanceRow> createState() => _PersonBalanceRowState();
}

class _PersonBalanceRowState extends State<_PersonBalanceRow> {
  bool _expanded = false;

  List<_ActivityItem> _buildHistory(String paidExpenseLabel, String consumedLabel,
      String paymentMadeLabel, String paymentReceivedLabel) {
    final m = widget.member;
    final trip = widget.trip;
    final items = <_ActivityItem>[];

    for (final e in trip.expenses) {
      if (e.payer == m.id) {
        items.add(_ActivityItem(
          icon: FluentIcons.receipt_24_regular,
          label: e.name,
          sublabel: paidExpenseLabel,
          amount: e.amount,
          amountColor: AppTheme.green,
          amountSign: '+',
          date: e.date,
        ));
      }
      final split = e.splits[m.id] ?? 0;
      if (split > 0 && e.payer != m.id) {
        items.add(_ActivityItem(
          icon: FluentIcons.people_24_regular,
          label: e.name,
          sublabel: consumedLabel,
          amount: split,
          amountColor: AppTheme.red,
          amountSign: '−',
          date: e.date,
        ));
      }
    }

    for (final p in trip.payments) {
      if (p.from == m.id) {
        final label = p.note.isNotEmpty
            ? p.note
            : '$paymentMadeLabel → ${trip.memberName(p.to)}';
        items.add(_ActivityItem(
          icon: FluentIcons.money_24_regular,
          label: label,
          sublabel: paymentMadeLabel,
          amount: p.amount,
          amountColor: AppTheme.blue,
          amountSign: '+',
          date: p.date,
        ));
      } else if (p.to == m.id) {
        final label = p.note.isNotEmpty
            ? p.note
            : '$paymentReceivedLabel ← ${trip.memberName(p.from)}';
        items.add(_ActivityItem(
          icon: FluentIcons.money_24_regular,
          label: label,
          sublabel: paymentReceivedLabel,
          amount: p.amount,
          amountColor: AppTheme.amber,
          amountSign: '−',
          date: p.date,
        ));
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final m = widget.member;
    final trip = widget.trip;
    final bal = widget.balance;

    final badge = bal > 0.005
        ? StatusBadge.green('${s.receives} ${trip.currency} ${bal.toStringAsFixed(2)}')
        : bal < -0.005
        ? StatusBadge.red('${s.owes} ${trip.currency} ${bal.abs().toStringAsFixed(2)}')
        : StatusBadge.blue(s.upToDate);

    final history = _expanded
        ? _buildHistory(s.paidExpense, s.consumedLabel, s.paymentMade, s.paymentReceived)
        : <_ActivityItem>[];

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                MemberAvatar(name: m.name, allMembers: widget.allMemberNames, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.paidBy} ${trip.currency} ${widget.paid.toStringAsFixed(2)}'
                        ' · ${s.consumedLabel} ${trip.currency} ${widget.consumed.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(fit: FlexFit.loose, child: badge),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: c.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (widget.paid > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: _ProgressBar(
              value: widget.paid / (widget.totalSpent == 0 ? 1 : widget.totalSpent),
            ),
          ),
        if (_expanded) ...[
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                s.noActivity,
                style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
              ),
            )
          else
            ColoredBox(
              color: c.background,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  ...history.map((item) => _ActivityRow(item: item, currency: trip.currency)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
        const Divider(height: 1),
      ],
    );
  }
}

// ── Activity row ──────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final _ActivityItem item;
  final String currency;

  const _ActivityRow({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        children: [
          Icon(item.icon, size: 16, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13),
                ),
                Text(
                  item.sublabel,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.amountSign} $currency ${item.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: item.amountColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${item.date.day}/${item.date.month}/${item.date.year}',
                style: GoogleFonts.inter(color: c.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Expandable category row ───────────────────────────
class _CategoryRow extends StatefulWidget {
  final String category;
  final double amount;
  final Trip trip;

  const _CategoryRow({
    super.key,
    required this.category,
    required this.amount,
    required this.trip,
  });

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;

    final expenses = widget.trip.expenses
        .where((e) => e.category == widget.category)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _catIcons[widget.category] ?? FluentIcons.box_24_regular,
                  size: 22,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.catLabel(widget.category),
                    style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                  ),
                ),
                Text(
                  '${widget.trip.currency} ${widget.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: c.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ColoredBox(
            color: c.background,
            child: Column(
              children: [
                const SizedBox(height: 4),
                ...expenses.map((e) {
                  final payerName = widget.trip.memberName(e.payer);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    child: Row(
                      children: [
                        Icon(FluentIcons.receipt_24_regular, size: 16, color: c.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13),
                              ),
                              Text(
                                '${s.paidBy} $payerName',
                                style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${widget.trip.currency} ${e.amount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${e.date.day}/${e.date.month}/${e.date.year}',
                              style: GoogleFonts.inter(color: c.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ── Consumption Donut Chart ───────────────────────────
class _ConsumptionChart extends StatefulWidget {
  final Trip trip;
  final double total;

  const _ConsumptionChart({required this.trip, required this.total});

  @override
  State<_ConsumptionChart> createState() => _ConsumptionChartState();
}

class _ConsumptionChartState extends State<_ConsumptionChart> {
  int? _selectedIdx;
  bool _expanded = true;

  Map<String, double> _categoryBreakdown(String memberId) {
    final map = <String, double>{};
    for (final e in widget.trip.expenses) {
      final split = e.splits[memberId] ?? 0;
      if (split > 0) {
        map[e.category] = (map[e.category] ?? 0) + split;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  void _handleTap(Offset localPos, List<_Slice> slices) {
    const cx = 100.0;
    const cy = 100.0;
    final dx = localPos.dx - cx;
    final dy = localPos.dy - cy;
    final dist = math.sqrt(dx * dx + dy * dy);

    const outerR = 98.0;
    const innerR = outerR * 0.58;

    if (dist < innerR || dist > outerR + 10) {
      setState(() => _selectedIdx = null);
      return;
    }

    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    if (angle >= 2 * math.pi) angle -= 2 * math.pi;

    final gap = slices.length > 1 ? 0.03 : 0.0;
    double start = 0;
    for (int i = 0; i < slices.length; i++) {
      final sweep = slices[i].fraction * 2 * math.pi;
      if (angle >= start && angle < start + sweep - gap / 2) {
        setState(() => _selectedIdx = _selectedIdx == i ? null : i);
        return;
      }
      start += sweep;
    }
    setState(() => _selectedIdx = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final trip = widget.trip;
    final participants = trip.allParticipants;
    final allNames = participants.map((m) => m.name).toList();

    final consumedMap = <String, double>{};
    for (final m in participants) {
      consumedMap[m.id] = trip.expenses.fold(
        0.0,
        (sum, e) => sum + (e.splits[m.id] ?? 0),
      );
    }

    final totalConsumed = consumedMap.values.fold(0.0, (a, b) => a + b);

    final slices = <_Slice>[];
    for (final m in participants) {
      final consumed = consumedMap[m.id] ?? 0;
      if (consumed <= 0) continue;
      final listPos = allNames.indexOf(m.name);
      final defaultIdx = listPos < 0
          ? 0
          : AppTheme.memberColorOrder[listPos % AppTheme.memberColorOrder.length];
      final colorIdx = (m.colorIndex ?? defaultIdx) % AppTheme.avatarPalette.length;
      final color = AppTheme.avatarPalette[colorIdx < 0 ? 0 : colorIdx][1];
      slices.add(_Slice(
        name: m.name,
        memberId: m.id,
        value: consumed,
        fraction: totalConsumed > 0 ? consumed / totalConsumed : 0,
        color: color,
      ));
    }

    if (slices.isEmpty) {
      return FluentCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              s.addExpensesForChart,
              style: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final selected = _selectedIdx != null && _selectedIdx! < slices.length
        ? slices[_selectedIdx!]
        : null;

    return FluentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  Expanded(child: SectionHeader(title: s.consumptionPerPerson)),
                  Icon(
                    _expanded
                        ? FluentIcons.chevron_up_24_regular
                        : FluentIcons.chevron_down_24_regular,
                    size: 16,
                    color: c.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
          const Divider(height: 1),
          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: GestureDetector(
                onTapDown: (details) => _handleTap(details.localPosition, slices),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _DonutPainter(
                        slices: slices,
                        borderColor: c.border,
                        selectedIdx: _selectedIdx,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.totalLabel,
                          style: GoogleFonts.inter(
                            color: c.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip.currency,
                          style: GoogleFonts.inter(color: c.textSecondary, fontSize: 11),
                        ),
                        Text(
                          widget.total.toStringAsFixed(2),
                          style: GoogleFonts.inter(
                            color: c.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: selected != null
                ? Padding(
                    key: ValueKey(selected.memberId),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _CategoryTooltip(
                      slice: selected,
                      breakdown: _categoryBreakdown(selected.memberId),
                      allNames: allNames,
                      currency: trip.currency,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              children: slices.asMap().entries.map((entry) {
                final i = entry.key;
                final sl = entry.value;
                final pct = (sl.fraction * 100).toStringAsFixed(1);
                final isSelected = _selectedIdx == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIdx = isSelected ? null : i),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _selectedIdx == null || isSelected
                              ? sl.color
                              : sl.color.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          sl.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? c.textPrimary
                                : _selectedIdx == null
                                    ? c.textSecondary
                                    : c.textMuted,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$pct%',
                        style: GoogleFonts.inter(
                          color: _selectedIdx == null || isSelected
                              ? sl.color
                              : sl.color.withValues(alpha: 0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          ], // end if (_expanded)
        ],
      ),
    );
  }
}

class _Slice {
  final String name;
  final String memberId;
  final double value;
  final double fraction;
  final Color color;
  const _Slice({
    required this.name,
    required this.memberId,
    required this.value,
    required this.fraction,
    required this.color,
  });
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final Color borderColor;
  final int? selectedIdx;
  const _DonutPainter({required this.slices, required this.borderColor, this.selectedIdx});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 3;
    final innerR = outerR * 0.56;
    final strokeW = outerR - innerR;
    final arcR   = (outerR + innerR) / 2;

    // Subtle background track
    canvas.drawCircle(
      center, arcR,
      Paint()
        ..color = borderColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..isAntiAlias = true,
    );

    if (slices.isEmpty) return;

    final gap = slices.length > 1 ? 0.022 : 0.0;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final sl = slices[i];
      final totalSweep = sl.fraction * 2 * math.pi;
      final sweep = totalSweep - gap;
      if (sweep <= 0.01) { startAngle += totalSweep; continue; }

      final dimmed   = selectedIdx != null && selectedIdx != i;
      final selected = selectedIdx == i;

      // Push selected arc outward along its bisector
      final bisector = startAngle + gap / 2 + sweep / 2;
      final push = selected ? 5.0 : 0.0;
      final sliceCenter = center + Offset(
        push * math.cos(bisector),
        push * math.sin(bisector),
      );

      canvas.drawArc(
        Rect.fromCircle(center: sliceCenter, radius: arcR),
        startAngle + gap / 2,
        sweep,
        false,
        Paint()
          ..color = dimmed ? sl.color.withValues(alpha: 0.18) : sl.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? strokeW * 1.15 : strokeW
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      startAngle += totalSweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.borderColor != borderColor || old.selectedIdx != selectedIdx;
}

class _CategoryTooltip extends StatelessWidget {
  final _Slice slice;
  final Map<String, double> breakdown;
  final List<String> allNames;
  final String currency;

  const _CategoryTooltip({
    required this.slice,
    required this.breakdown,
    required this.allNames,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final total = slice.value;

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceHigher,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: slice.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: slice.color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                MemberAvatar(name: slice.name, allMembers: allNames, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slice.name,
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$currency ${total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: slice.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...breakdown.entries.map((entry) {
            final pct = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Icon(
                    _catIcons[entry.key] ?? FluentIcons.box_24_regular,
                    size: 15,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.catLabel(entry.key),
                                style: GoogleFonts.inter(color: c.textSecondary, fontSize: 12),
                              ),
                            ),
                            Text(
                              '$currency ${entry.value.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                color: c.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.end,
                                style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _ProgressBar(
                          value: pct,
                          color: slice.color.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ── Category Pie Chart (collapsible) ─────────────────
class _CategoryPieChart extends StatefulWidget {
  final Trip trip;
  const _CategoryPieChart({required this.trip});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  bool _expanded = false;

  static const Map<String, Color> _pieColors = {
    'food':          Color(0xFFC8592A), // orange
    'lodging':       Color(0xFF4FA3D4), // blue
    'transport':     Color(0xFF4CAF7D), // green
    'entertainment': Color(0xFFD4679C), // pink
    'shopping':      Color(0xFF4CBFBF), // teal
    'activities':    Color(0xFF7ED44F), // lime
    'health':        Color(0xFFD45A5A), // red
    'flight':        Color(0xFF9B82D4), // purple
    'drinks':        Color(0xFFD4A017), // amber
    'fuel':          Color(0xFFB05AD4), // violet
    'tips':          Color(0xFF5B9FD4), // sky
    'parking':       Color(0xFF78909C), // grey-blue
    'other':         Color(0xFF90A4AE), // grey
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final trip = widget.trip;

    final totals = _categoryTotals(trip);
    final grand = totals.values.fold(0.0, (a, b) => a + b);

    final slices = totals.entries.map((e) => _PieSlice(
      category: e.key,
      value: e.value,
      fraction: grand > 0 ? e.value / grand : 0,
      color: _pieColors[e.key] ?? const Color(0xFF90A4AE),
    )).toList();

    return FluentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(FluentIcons.data_pie_24_regular,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.categoryDistribution,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: c.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  size: const Size(180, 180),
                  painter: _PiePainter(slices: slices, trackColor: c.border),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: slices.map((sl) {
                  final pct = (sl.fraction * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: sl.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Icon(_catIcons[sl.category] ?? FluentIcons.box_24_regular,
                            size: 14, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.catLabel(sl.category),
                            style: GoogleFonts.inter(
                                color: c.textSecondary, fontSize: 12),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.inter(
                            color: sl.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${trip.currency} ${sl.value.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: c.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PieSlice {
  final String category;
  final double value;
  final double fraction;
  final Color color;
  const _PieSlice({
    required this.category,
    required this.value,
    required this.fraction,
    required this.color,
  });
}

class _PiePainter extends CustomPainter {
  final List<_PieSlice> slices;
  final Color trackColor;
  const _PiePainter({required this.slices, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center  = Offset(size.width / 2, size.height / 2);
    final outerR  = math.min(size.width, size.height) / 2 - 4;
    final strokeW = outerR * 0.38;
    final arcR    = outerR - strokeW / 2;
    final gap     = slices.length > 1 ? 0.022 : 0.0;
    double angle  = -math.pi / 2;

    // Background track
    canvas.drawCircle(
      center, arcR,
      Paint()
        ..color = trackColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..isAntiAlias = true,
    );

    for (final s in slices) {
      final totalSweep = s.fraction * 2 * math.pi;
      final sweep = totalSweep - gap;
      if (sweep > 0.01) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcR),
          angle + gap / 2,
          sweep,
          false,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true,
        );
      }
      angle += totalSweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.slices != slices || old.trackColor != trackColor;
}

// ── Progress Bar ──────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  const _ProgressBar({required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: c.surfaceHigher,
        valueColor: AlwaysStoppedAnimation(color ?? c.accent),
      ),
    );
  }
}
