import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/banner_ad_widget.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final Set<String> _catFilter = {};
  final Set<String> _payerFilter = {};
  double? _minAmt;
  double? _maxAmt;
  String _nameFilter = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _collapsedDays = {};

  static const Map<String, IconData> _catIcons = {
    'food': FluentIcons.food_24_regular,
    'lodging': FluentIcons.bed_24_regular,
    'transport': FluentIcons.vehicle_car_24_regular,
    'entertainment': FluentIcons.balloon_24_regular,
    'shopping': FluentIcons.cart_24_regular,
    'activities': FluentIcons.beach_24_regular,
    'health': FluentIcons.pill_24_regular,
    'flight': FluentIcons.airplane_24_regular,
    'other': FluentIcons.box_24_regular,
  };

  Color _catFg(String cat, AppColors c) => switch (cat) {
    'food' => c.accent,
    'lodging' => AppTheme.blue,
    'transport' => AppTheme.green,
    'entertainment' => const Color(0xFFD4679C),
    'shopping' => AppTheme.amber,
    'activities' => AppTheme.blue,
    'health' => const Color(0xFF9B82D4),
    _ => c.textSecondary,
  };

  bool get _hasFilters =>
      _dateFrom != null ||
      _dateTo != null ||
      _catFilter.isNotEmpty ||
      _payerFilter.isNotEmpty ||
      _minAmt != null ||
      _maxAmt != null ||
      _nameFilter.isNotEmpty;

  int get _filterCount =>
      (_dateFrom != null || _dateTo != null ? 1 : 0) +
      (_catFilter.isNotEmpty ? 1 : 0) +
      (_payerFilter.isNotEmpty ? 1 : 0) +
      (_minAmt != null || _maxAmt != null ? 1 : 0) +
      (_nameFilter.isNotEmpty ? 1 : 0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() => setState(() {
    _dateFrom = null;
    _dateTo = null;
    _catFilter.clear();
    _payerFilter.clear();
    _minAmt = null;
    _maxAmt = null;
    _nameFilter = '';
    _searchCtrl.clear();
  });

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<Expense> _filtered(List<Expense> all) => all.where((e) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    if (_dateFrom != null && d.isBefore(_dateFrom!)) return false;
    if (_dateTo != null && d.isAfter(_dateTo!)) return false;
    if (_catFilter.isNotEmpty && !_catFilter.contains(e.category)) return false;
    if (_payerFilter.isNotEmpty && !_payerFilter.contains(e.payer)) return false;
    if (_minAmt != null && e.amount < _minAmt!) return false;
    if (_maxAmt != null && e.amount > _maxAmt!) return false;
    if (_nameFilter.isNotEmpty &&
        !e.name.toLowerCase().contains(_nameFilter.toLowerCase())) { return false; }
    return true;
  }).toList();

  // Returns flat list alternating DateTime headers and Expense items, sorted newest first
  List<dynamic> _buildItems(List<Expense> expenses) {
    final groups = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <dynamic>[];
    for (final day in sortedDays) {
      items.add(day);
      if (!_collapsedDays.contains(_dayKey(day))) {
        final dayExpenses = groups[day]!..sort((a, b) => b.date.compareTo(a.date));
        items.addAll(dayExpenses);
      }
    }
    return items;
  }

  void _openFilters(BuildContext context, List<Member> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        catFilter: Set.from(_catFilter),
        payerFilter: Set.from(_payerFilter),
        minAmt: _minAmt,
        maxAmt: _maxAmt,
        members: members,
        onApply: (from, to, cats, payers, min, max) {
          setState(() {
            _dateFrom = from;
            _dateTo = to;
            _catFilter..clear()..addAll(cats);
            _payerFilter..clear()..addAll(payers);
            _minAmt = min;
            _maxAmt = max;
          });
          Navigator.pop(context);
        },
        onClear: () {
          _clearFilters();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final provider = context.watch<TripProvider>();
    final trip = provider.activeTrip!;
    final allExpenses = trip.expenses.toList();
    final filtered = _filtered(allExpenses);
    final items = _buildItems(filtered);
    final maxExpense = allExpenses.isEmpty
        ? null
        : allExpenses.reduce((a, b) => a.amount > b.amount ? a : b);

    return Scaffold(
      backgroundColor: c.background,
      body: allExpenses.isEmpty
          ? EmptyState(
              icon: FluentIcons.receipt_24_regular,
              title: s.noExpenses,
              subtitle: s.noExpensesHint,
              action: ElevatedButton.icon(
                onPressed: () => _openSheet(context, trip),
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.newTransaction),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Metric cards + filter bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MetricCard(
                                label: s.totalSpent,
                                value: '${trip.currency} ${_fmt(trip.totalSpent)}',
                                accentColor: c.accent,
                                subtitle: s.txCount(allExpenses.length),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MetricCard(
                                label: s.biggestExpense,
                                value: maxExpense == null
                                    ? '—'
                                    : '${trip.currency} ${_fmt(maxExpense.amount)}',
                                accentColor: AppTheme.blue,
                                subtitle: maxExpense?.name ?? '—',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Center(child: AppBannerAd()),
                        const SizedBox(height: 12),
                        // Search + filter bar
                        Row(
                          children: [
                            // Inline search field
                            Expanded(
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: c.surfaceHigher,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _nameFilter.isNotEmpty ? c.accent : c.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, size: 16, color: c.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (v) => setState(() => _nameFilter = v),
                                        style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: s.searchExpenseName,
                                          hintStyle: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_nameFilter.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _searchCtrl.clear();
                                          _nameFilter = '';
                                        }),
                                        child: Icon(Icons.close, size: 14, color: c.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Filter button
                            GestureDetector(
                              onTap: () => _openFilters(context, trip.allParticipants),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _hasFilters ? c.accentFill : c.surfaceHigher,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _hasFilters ? c.accent : c.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.filter_24_regular,
                                      size: 14,
                                      color: _hasFilters ? c.accent : c.textSecondary,
                                    ),
                                    if (_filterCount > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_filterCount',
                                        style: GoogleFonts.inter(
                                          color: c.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_hasFilters) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              s.resultCount(filtered.length),
                              style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // No results after filtering
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.filter_24_regular, size: 40, color: c.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            s.noResults,
                            style: GoogleFonts.inter(
                              color: c.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.tryOtherFilters,
                            style: GoogleFonts.inter(color: c.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        if (item is DateTime) {
                          final key = _dayKey(item);
                          return _DateHeader(
                            date: item,
                            isCollapsed: _collapsedDays.contains(key),
                            onToggle: () => setState(() {
                              if (_collapsedDays.contains(key)) {
                                _collapsedDays.remove(key);
                              } else {
                                _collapsedDays.add(key);
                              }
                            }),
                          );
                        }
                        final e = item as Expense;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ExpenseCard(
                            expense: e,
                            currency: trip.currency,
                            payerName: trip.memberName(e.payer),
                            memberNames: trip.allMembers.map((m) => m.name).toList(),
                            catLabel: s.catLabel(e.category),
                            catBg: _catFg(e.category, c).withValues(alpha: 0.15),
                            catFg: _catFg(e.category, c),
                            catIcon: _catIcons[e.category] ?? FluentIcons.box_24_regular,
                            onDelete: () => _delete(context, e.id),
                            onTap: () => _openSheet(context, trip, expense: e),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context, trip),
        icon: const Icon(Icons.add),
        label: Text(s.newTransaction, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  void _openSheet(BuildContext context, Trip trip, {Expense? expense}) {
    // When editing, include the original payer even if they were removed,
    // so the dropdown doesn't crash. For new expenses, active members only.
    final membersForSheet = expense != null
        ? trip.allMembers
            .where((m) => m.active || m.id == expense.payer || (expense.splits[m.id] ?? 0) > 0)
            .toList()
        : trip.members;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TripProvider>(),
        child: AddExpenseSheet(
          members: membersForSheet,
          currency: trip.currency,
          expense: expense,
        ),
      ),
    );
  }

  void _delete(BuildContext context, String id) {
    final c = AppColors.of(context);
    final s = context.read<SettingsProvider>().strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
        title: Text(
          s.deleteExpense,
          style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          s.deleteExpenseConfirm,
          style: GoogleFonts.inter(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TripProvider>().deleteExpense(id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            child: Text(s.eliminate),
          ),
        ],
      ),
    );
  }
}

// ── Date Header ───────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool isCollapsed;
  final VoidCallback onToggle;
  const _DateHeader({required this.date, required this.isCollapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final label = '${date.day} ${s.monthAbbr[date.month - 1]} ${date.year}';
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: c.border)),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isCollapsed
                      ? FluentIcons.chevron_right_24_regular
                      : FluentIcons.chevron_down_24_regular,
                  size: 11,
                  color: c.textMuted,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 1, color: c.border)),
          ],
        ),
      ),
    );
  }
}

// ── Filter Sheet ──────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String> catFilter;
  final Set<String> payerFilter;
  final double? minAmt;
  final double? maxAmt;
  final List<Member> members;
  final void Function(DateTime?, DateTime?, Set<String>, Set<String>, double?, double?) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.dateFrom,
    required this.dateTo,
    required this.catFilter,
    required this.payerFilter,
    required this.minAmt,
    required this.maxAmt,
    required this.members,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _from;
  DateTime? _to;
  late Set<String> _cats;
  late Set<String> _payers;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  static const List<String> _catKeys = [
    'food', 'lodging', 'transport', 'entertainment',
    'shopping', 'activities', 'health', 'flight', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _from = widget.dateFrom;
    _to = widget.dateTo;
    _cats = Set.from(widget.catFilter);
    _payers = Set.from(widget.payerFilter);
    if (widget.minAmt != null) _minCtrl.text = widget.minAmt!.toStringAsFixed(2);
    if (widget.maxAmt != null) _maxCtrl.text = widget.maxAmt!.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _from = picked;
        if (_to != null && _to!.isBefore(_from!)) _to = _from;
      });
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _from ?? DateTime.now(),
      firstDate: _from ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _apply() {
    final min = double.tryParse(_minCtrl.text.replaceAll(',', '.'));
    final max = double.tryParse(_maxCtrl.text.replaceAll(',', '.'));
    widget.onApply(_from, _to, _cats, _payers, min, max);
  }

  String _fmtDate(DateTime d, AppStrings s) {
    return '${d.day} ${s.monthAbbr[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.88,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  s.filterTransactions,
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
                    decoration: BoxDecoration(color: c.surfaceHigher, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Rango de fechas ──────────────────
                  _sectionLabel(s.dateRange, c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(onTap: _pickFrom, child: _dateBox(s.fromDate, _from, c, s)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(onTap: _pickTo, child: _dateBox(s.toDate, _to, c, s)),
                      ),
                    ],
                  ),
                  if (_from != null || _to != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() { _from = null; _to = null; }),
                      child: Text(
                        s.clearDates,
                        style: GoogleFonts.inter(color: c.accent, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Categorías ───────────────────────
                  _sectionLabel(s.filterDivider, c),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _catKeys.map((key) {
                      final label = s.catLabel(key);
                      final sel = _cats.contains(key);
                      return GestureDetector(
                        onTap: () => setState(() {
                          sel ? _cats.remove(key) : _cats.add(key);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? c.accentFill : c.surfaceHigher,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? c.accent : c.border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: sel ? c.accent : c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Pagadores ────────────────────────
                  _sectionLabel(s.payers, c),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.members.map((m) {
                      final sel = _payers.contains(m.id);
                      final memberNames = widget.members.map((x) => x.name).toList();
                      return GestureDetector(
                        onTap: () => setState(() {
                          sel ? _payers.remove(m.id) : _payers.add(m.id);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: sel ? c.accentFill : c.surfaceHigher,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? c.accent : c.border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MemberAvatar(name: m.name, allMembers: memberNames, size: 22),
                              const SizedBox(width: 7),
                              Text(
                                m.name,
                                style: GoogleFonts.inter(
                                  color: sel ? c.accent : c.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Rango de montos ──────────────────
                  _sectionLabel(s.amountRange, c),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: s.minimum,
                            labelStyle: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                            hintText: '0.00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: s.maximum,
                            labelStyle: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                            hintText: '0.00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Botones ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onClear,
                          child: Text(s.clearAll),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _apply,
                          child: Text(s.applyFilters),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date, AppColors c, AppStrings s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: c.surfaceHigher,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: date != null ? c.accent : c.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          date != null ? _fmtDate(date, s) : '—',
          style: GoogleFonts.inter(
            color: date != null ? c.textPrimary : c.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String t, AppColors c) => Text(
    t,
    style: GoogleFonts.inter(
      color: c.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

// ── Expense Card ──────────────────────────────────────
class _ExpenseCard extends StatefulWidget {
  final Expense expense;
  final String currency;
  final String payerName;
  final List<String> memberNames;
  final String catLabel;
  final Color catBg;
  final Color catFg;
  final IconData catIcon;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.payerName,
    required this.memberNames,
    required this.catLabel,
    required this.catBg,
    required this.catFg,
    required this.catIcon,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<_ExpenseCard> {
  bool _hovered = false;

  StatusBadge _modeBadge(AppStrings s) => switch (widget.expense.mode) {
    SplitMode.equal      => StatusBadge.blue(s.splitEqual),
    SplitMode.own        => StatusBadge.amber(s.splitOwn),
    SplitMode.custom     => StatusBadge.green(s.splitCustom),
    SplitMode.percentage => StatusBadge.blue(s.splitPercent),
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? c.surfaceHigh : c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? c.borderHover : c.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.catBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(widget.catIcon, size: 26, color: widget.catFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        MemberAvatar(
                          name: widget.payerName,
                          allMembers: widget.memberNames,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.payerName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: c.textSecondary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _modeBadge(s),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.currency} ${widget.expense.amount.toStringAsFixed(2)}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.expense.expenseCurrency != null &&
                      widget.expense.expenseCurrency != widget.currency &&
                      widget.expense.exchangeRate > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${widget.expense.expenseCurrency} '
                      '${(widget.expense.amount / widget.expense.exchangeRate).toStringAsFixed(2)}',
                      style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onDelete,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
