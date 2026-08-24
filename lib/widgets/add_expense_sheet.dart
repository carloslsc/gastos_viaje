import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/banner_ad_widget.dart';

class AddExpenseSheet extends StatefulWidget {
  final List<Member> members; // active members only
  final String currency;
  final Expense? expense;

  const AddExpenseSheet({
    super.key,
    required this.members,
    required this.currency,
    this.expense,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();
  bool _showTip = false;
  String _cat = 'food';
  String? _payer; // member ID
  SplitMode _mode = SplitMode.equal;
  final Map<String, TextEditingController> _customCtrls = {}; // keyed by member ID
  final Map<String, TextEditingController> _pctCtrls = {}; // keyed by member ID, stores 0–100
  late Set<String> _activeMembers; // set of member IDs
  late DateTime _date;
  String? _expCurrency;    // null = trip currency
  double _exchangeRate = 1.0;
  bool _tipIsPercent = false;
  bool _rateFetching = false;
  final _rateCtrl = TextEditingController();

  static const List<String> _cats = [
    'food','lodging','transport','entertainment','shopping',
    'activities','health','flight','drinks','fuel','tips','parking','other',
  ];
  static const Map<String, IconData> _catIcons = {
    'food': FluentIcons.food_24_regular, 'lodging': FluentIcons.bed_24_regular,
    'transport': FluentIcons.vehicle_car_24_regular, 'entertainment': FluentIcons.balloon_24_regular,
    'shopping': FluentIcons.cart_24_regular, 'activities': FluentIcons.beach_24_regular,
    'health': FluentIcons.pill_24_regular, 'flight': FluentIcons.airplane_24_regular,
    'drinks': FluentIcons.drink_wine_24_regular, 'fuel': FluentIcons.gas_pump_24_regular,
    'tips': FluentIcons.money_hand_24_regular, 'parking': FluentIcons.vehicle_car_parking_24_regular,
    'other': FluentIcons.box_24_regular,
  };

  static const List<String> _allCurrencies = [
    'USD','EUR','GBP','JPY','CNY','KRW','MXN','BRL','CAD','AUD','CHF',
    'INR','THB','VND','IDR','TRY','AED','SAR','PLN','SEK','NOK','DKK',
    'CZK','HUF','COP','ARS','CLP','PEN','RUB','ZAR','MYR','SGD','PHP',
    'TWD','HKD','NZD','EGP','MAD','UAH','CRC','GTQ','BOB','UYU','PYG',
  ];

  static IconData _modeIcon(SplitMode m) => switch (m) {
    SplitMode.equal      => FluentIcons.people_24_regular,
    SplitMode.own        => FluentIcons.person_24_regular,
    SplitMode.custom     => FluentIcons.options_24_regular,
    SplitMode.percentage => FluentIcons.data_pie_24_regular,
  };

  List<String> get _memberNames => widget.members.map((m) => m.name).toList();
  String get _effectiveCurrency => _expCurrency ?? widget.currency;
  bool get _isForeignCurrency => _expCurrency != null && _expCurrency != widget.currency;

  double get _tipAmount {
    if (!_showTip) return 0.0;
    if (_tipIsPercent) {
      return _parse(_amountCtrl.text) * _parse(_tipCtrl.text) / 100;
    }
    return _parse(_tipCtrl.text);
  }

  String _payerName(AppStrings s) {
    if (_payer == null) return s.thePayerLabel;
    try { return widget.members.firstWhere((m) => m.id == _payer).name; }
    catch (_) { return _payer!; }
  }

  @override
  void initState() {
    super.initState();
    _payer = widget.members.first.id;
    _activeMembers = {for (final m in widget.members) m.id};
    _date = DateTime.now();
    for (final m in widget.members) {
      _customCtrls[m.id] = TextEditingController();
      _pctCtrls[m.id] = TextEditingController();
    }

    final e = widget.expense;
    if (e != null) {
      _nameCtrl.text = e.name;
      // base amount = total minus any stored tip
      final isForeign = e.expenseCurrency != null && e.expenseCurrency != widget.currency;
      if (isForeign) {
        _expCurrency = e.expenseCurrency;
        _exchangeRate = e.exchangeRate;
        _rateCtrl.text = e.exchangeRate.toStringAsFixed(4);
        _amountCtrl.text = ((e.amount - e.tip) / e.exchangeRate).toStringAsFixed(2);
        if (e.tip > 0) {
          _showTip = true;
          _tipCtrl.text = (e.tip / e.exchangeRate).toStringAsFixed(2);
        }
      } else {
        _amountCtrl.text = (e.amount - e.tip).toStringAsFixed(2);
        if (e.tip > 0) {
          _showTip = true;
          _tipCtrl.text = e.tip.toStringAsFixed(2);
        }
      }
      _cat = e.category;
      _payer = e.payer;
      _mode = e.mode;
      _date = e.date;
      if (e.mode == SplitMode.custom) {
        _activeMembers = e.splits.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key)
            .toSet();
        for (final m in widget.members) {
          final share = e.splits[m.id];
          if (share != null && share > 0) {
            _customCtrls[m.id]!.text = share.toStringAsFixed(2);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _tipCtrl.dispose();
    for (final c in _customCtrls.values) { c.dispose(); }
    for (final c in _pctCtrls.values) { c.dispose(); }
    _rateCtrl.dispose();
    super.dispose();
  }

  static double _parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  double get _totalAmount =>
      (_parse(_amountCtrl.text) + _tipAmount) * _exchangeRate;
  double get _customSum =>
      _activeMembers.fold(0.0, (s, id) => s + _parse(_customCtrls[id]?.text ?? ''));
  double _parsePct(String memberId) => _parse(_pctCtrls[memberId]?.text ?? '');
  double get _pctSum => _activeMembers.fold(0.0, (s, id) => s + _parsePct(id));

  void _autoFillCustom() {
    if (_totalAmount <= 0 || _activeMembers.isEmpty) return;
    final share = _totalAmount / _activeMembers.length;
    for (final m in widget.members) {
      _customCtrls[m.id]!.text =
          _activeMembers.contains(m.id) ? share.toStringAsFixed(2) : '';
    }
  }

  void _autoFillPct() {
    if (_activeMembers.isEmpty) return;
    final share = 100 / _activeMembers.length;
    for (final m in widget.members) {
      _pctCtrls[m.id]!.text =
          _activeMembers.contains(m.id) ? share.toStringAsFixed(1) : '';
    }
  }

  void _save() {
    final s = context.read<SettingsProvider>().strings;
    final name = _nameCtrl.text.trim();
    final base = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty) { _err(s.errorDescriptionEmpty); return; }
    if (base == null || base <= 0) { _err(s.errorAmountInvalid); return; }
    final amount = _totalAmount; // already in trip currency (applies exchangeRate)

    final splits = <String, double>{};
    switch (_mode) {
      case SplitMode.equal:
        final share = amount / widget.members.length;
        for (final m in widget.members) { splits[m.id] = share; }
      case SplitMode.own:
        for (final m in widget.members) { splits[m.id] = 0; }
        splits[_payer!] = amount;
      case SplitMode.custom:
        if (_activeMembers.isEmpty) { _err(s.errorSelectParticipant); return; }
        for (final m in widget.members) {
          splits[m.id] = _activeMembers.contains(m.id)
              ? _parse(_customCtrls[m.id]!.text)
              : 0;
        }
        if ((_customSum - amount).abs() > 0.01) {
          _err(s.splitMismatchMsg(widget.currency, _customSum, amount));
          return;
        }
      case SplitMode.percentage:
        if (_activeMembers.isEmpty) { _err(s.errorSelectParticipant); return; }
        if ((_pctSum - 100).abs() > 0.5) {
          _err(s.splitPercentErrorMsg(_pctSum));
          return;
        }
        for (final m in widget.members) {
          splits[m.id] = _activeMembers.contains(m.id)
              ? amount * (_parsePct(m.id) / 100)
              : 0;
        }
    }

    final tipAmount = _tipAmount * _exchangeRate; // always in trip currency
    final effectiveCur = _isForeignCurrency ? _expCurrency : null;
    final provider = context.read<TripProvider>();
    if (widget.expense != null) {
      provider.updateExpense(Expense(
        id: widget.expense!.id,
        name: name,
        amount: amount,
        tip: tipAmount,
        category: _cat,
        payer: _payer!,
        splits: splits,
        mode: _mode,
        date: _date,
        expenseCurrency: effectiveCur,
        exchangeRate: effectiveCur != null ? _exchangeRate : 1.0,
      ));
    } else {
      provider.addExpense(provider.buildExpense(
        name: name,
        amount: amount,
        tip: tipAmount,
        category: _cat,
        payer: _payer!,
        splits: splits,
        mode: _mode,
        date: _date,
        expenseCurrency: effectiveCur,
        exchangeRate: effectiveCur != null ? _exchangeRate : 1.0,
      ));
    }
    Navigator.pop(context);
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.red));

  Future<void> _fetchRate(String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return;
    setState(() => _rateFetching = true);
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final from = fromCurrency.toLowerCase();
      final to   = toCurrency.toLowerCase();
      final urls = [
        'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$from.json',
        'https://latest.currency-api.pages.dev/v1/currencies/$from.json',
      ];
      double? rate;
      for (final url in urls) {
        try {
          final req = await client.getUrl(Uri.parse(url));
          final res = await req.close();
          if (res.statusCode == 200) {
            final body = await res.transform(const Utf8Decoder()).join();
            final json  = jsonDecode(body) as Map<String, dynamic>;
            final rates = json[from] as Map<String, dynamic>?;
            rate = (rates?[to] as num?)?.toDouble();
            if (rate != null) break;
          }
        } catch (_) {
          continue; // intenta la URL de fallback
        }
      }
      if (rate != null && mounted) {
        setState(() {
          _exchangeRate = rate!;
          _rateCtrl.text = rate.toStringAsFixed(4);
        });
        return;
      }
      if (mounted) setState(() { _exchangeRate = 1.0; _rateCtrl.text = ''; });
    } catch (_) {
      if (mounted) setState(() { _exchangeRate = 1.0; _rateCtrl.text = ''; });
    } finally {
      client?.close();
      if (mounted) setState(() => _rateFetching = false);
    }
  }

  void _showCurrencyPicker(AppColors c, AppStrings s, Color accent, Color accentFill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final tripCurrency = widget.currency;
        final ordered = [tripCurrency, ..._allCurrencies.where((cur) => cur != tripCurrency)];
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(s.currency, style: GoogleFonts.inter(
                        color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
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
              Divider(height: 1, color: c.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ordered.map((cur) {
                      final isSelected = cur == tripCurrency
                          ? _expCurrency == null
                          : cur == _expCurrency;
                      return GestureDetector(
                        onTap: () {
                          if (cur == tripCurrency) {
                            setState(() {
                              _expCurrency = null;
                              _exchangeRate = 1.0;
                              _rateCtrl.clear();
                            });
                          } else {
                            setState(() {
                              _expCurrency = cur;
                              _rateCtrl.text = '...';
                            });
                            _fetchRate(cur, tripCurrency);
                          }
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? accentFill : c.surfaceHigher,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? accent : c.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            cur == tripCurrency ? '$cur ✦' : cur,
                            style: GoogleFonts.inter(
                              color: isSelected ? accent : c.textSecondary,
                              fontSize: 13, fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmtDate(DateTime d, AppStrings s) {
    return '${d.day} ${s.monthAbbr[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final accent = Theme.of(context).colorScheme.primary;
    final accentFill = c.accentFill;

    return Container(
      height: mq.size.height * 0.92,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  widget.expense != null ? s.editExpense : s.newExpense,
                  style: GoogleFonts.inter(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
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
                  const Center(child: AppBannerAd()),
                  const SizedBox(height: 16),
                  // ── Descripción ──────────────────────
                  _label(s.expenseName, c),
                  TextField(
                    controller: _nameCtrl,
                    style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                    decoration: InputDecoration(hintText: s.expenseNameHint),
                  ),
                  const SizedBox(height: 16),

                  // ── Monto + Pagador ──────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(s.amount, style: GoogleFonts.inter(
                                    color: c.textSecondary, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showCurrencyPicker(c, s, accent, accentFill),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _isForeignCurrency ? accentFill : c.surfaceHigher,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isForeignCurrency ? accent : c.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_effectiveCurrency, style: GoogleFonts.inter(
                                            color: _isForeignCurrency ? accent : c.textSecondary,
                                            fontSize: 11, fontWeight: FontWeight.w600)),
                                        Icon(Icons.arrow_drop_down, size: 14,
                                            color: _isForeignCurrency ? accent : c.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                              decoration: const InputDecoration(hintText: '0.00'),
                              onChanged: (_) => setState(() {
                                if (_mode == SplitMode.custom) _autoFillCustom();
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(s.paidByLabel, c),
                            DropdownButtonFormField<String>(
                              initialValue: _payer,
                              dropdownColor: c.surfaceHigh,
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(),
                              items: widget.members.map((m) => DropdownMenuItem(
                                value: m.id,
                                child: Row(
                                  children: [
                                    MemberAvatar(name: m.name, allMembers: _memberNames, size: 22),
                                    const SizedBox(width: 8),
                                    Text(m.name, overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13)),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (v) => setState(() => _payer = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Tasa de cambio (cuando moneda diferente) ──
                  if (_isForeignCurrency) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('1 $_expCurrency =',
                            style: GoogleFonts.inter(
                                color: c.textSecondary, fontSize: 13)),
                        const SizedBox(width: 8),
                        if (_rateFetching)
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.accent),
                          )
                        else
                          Expanded(
                            child: TextField(
                              controller: _rateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(
                                  color: c.textPrimary, fontSize: 15),
                              decoration: const InputDecoration(
                                  hintText: '1.0000', isDense: true),
                              onChanged: (v) => setState(() {
                                _exchangeRate =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        1.0;
                                if (_mode == SplitMode.custom) _autoFillCustom();
                              }),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(widget.currency,
                            style: GoogleFonts.inter(
                                color: c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (!_rateFetching &&
                        _parse(_amountCtrl.text) > 0 &&
                        _exchangeRate > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '≈ ${widget.currency} ${_totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                color: c.textMuted, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],

                  // ── Propina (opcional) ───────────────
                  GestureDetector(
                    onTap: () => setState(() => _showTip = !_showTip),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showTip
                              ? FluentIcons.subtract_circle_24_regular
                              : FluentIcons.add_circle_24_regular,
                          size: 13, color: c.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(s.addTip,
                            style: GoogleFonts.inter(color: c.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_showTip) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(s.tipLabel,
                            style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13)),
                        const SizedBox(width: 8),
                        // Toggle $/%
                        Container(
                          decoration: BoxDecoration(
                            color: c.surfaceHigher,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _tipToggleBtn('\$', !_tipIsPercent, c, accent,
                                  () => setState(() => _tipIsPercent = false)),
                              _tipToggleBtn('%', _tipIsPercent, c, accent,
                                  () => setState(() {
                                    _tipIsPercent = true;
                                    if (_mode == SplitMode.custom) _autoFillCustom();
                                  })),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_tipIsPercent) ...[
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: _tipCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(
                                  hintText: '0', suffixText: '%', isDense: true),
                              onChanged: (_) => setState(() {
                                if (_mode == SplitMode.custom) _autoFillCustom();
                              }),
                            ),
                          ),
                          if (_parse(_amountCtrl.text) > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '= $_effectiveCurrency ${_tipAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                            ),
                          ],
                        ] else
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _tipCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '$_effectiveCurrency ',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {
                                if (_mode == SplitMode.custom) _autoFillCustom();
                              }),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Fecha ────────────────────────────
                  _label(s.date, c),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        children: [
                          Icon(FluentIcons.calendar_24_regular, size: 16, color: c.textSecondary),
                          const SizedBox(width: 10),
                          Text(_fmtDate(_date, s),
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15)),
                          const Spacer(),
                          Icon(Icons.chevron_right, size: 16, color: c.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Categoría ────────────────────────
                  _label(s.category, c),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _cats.map((cat) {
                      final sel = cat == _cat;
                      return GestureDetector(
                        onTap: () => setState(() => _cat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? accentFill : c.surfaceHigher,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? accent : c.border, width: sel ? 1.5 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_catIcons[cat]!, size: 14,
                                  color: sel ? accent : c.textSecondary),
                              const SizedBox(width: 5),
                              Text(s.catLabel(cat),
                                  style: GoogleFonts.inter(
                                    color: sel ? accent : c.textSecondary,
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Forma de división ────────────────
                  _label(s.splitMode, c),
                  const SizedBox(height: 8),
                  ...SplitMode.values.map((m) {
                    final sel = m == _mode;
                    final modeLabel = switch (m) {
                      SplitMode.equal      => s.splitEqual,
                      SplitMode.own        => s.splitOwn,
                      SplitMode.custom     => s.splitCustom,
                      SplitMode.percentage => s.splitPercent,
                    };
                    final modeDesc = switch (m) {
                      SplitMode.equal      => s.splitEqualDesc,
                      SplitMode.own        => s.splitOwnDesc,
                      SplitMode.custom     => s.splitCustomDesc,
                      SplitMode.percentage => s.splitPercentDesc,
                    };
                    return GestureDetector(
                      onTap: () => setState(() {
                        final prev = _mode;
                        _mode = m;
                        if (m == SplitMode.custom && prev != SplitMode.custom) _autoFillCustom();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sel ? accentFill : c.surfaceHigher,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? accent : c.border, width: sel ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(_modeIcon(m), size: 20,
                                color: sel ? accent : c.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(modeLabel, style: GoogleFonts.inter(
                                      color: sel ? accent : c.textPrimary,
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(modeDesc, style: GoogleFonts.inter(
                                      color: c.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (sel) Icon(Icons.check_circle, color: accent, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Info: equal
                  if (_mode == SplitMode.equal && _totalAmount > 0)
                    _infoBox(Icons.call_split,
                      s.equalSplitInfo(widget.currency, _totalAmount, widget.members.length),
                      AppTheme.greenFill, AppTheme.green),

                  // Info: own
                  if (_mode == SplitMode.own)
                    _infoBox(Icons.person_outline,
                      s.ownSplitInfo(_payerName(s)),
                      AppTheme.amberFill, AppTheme.amber),

                  // Custom split
                  if (_mode == SplitMode.custom) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _label(s.amountPerPerson, c)),
                        TextButton.icon(
                          onPressed: _totalAmount > 0 ? () => setState(_autoFillCustom) : null,
                          icon: const Icon(Icons.auto_fix_high, size: 14),
                          label: Text(s.divideEqual, style: GoogleFonts.inter(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.members.map((m) {
                      final active = _activeMembers.contains(m.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                if (active) {
                                  _activeMembers.remove(m.id);
                                  _customCtrls[m.id]!.clear();
                                } else {
                                  _activeMembers.add(m.id);
                                }
                                _autoFillCustom();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: active ? accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active ? accent : c.border, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: active
                                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            MemberAvatar(name: m.name, allMembers: _memberNames, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(m.name, style: GoogleFonts.inter(
                                color: active ? c.textPrimary : c.textMuted,
                                fontSize: 14,
                                fontWeight: active ? FontWeight.w500 : FontWeight.w400)),
                            ),
                            const SizedBox(width: 10),
                            if (active)
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _customCtrls[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: '0.00', prefixText: '${widget.currency} '),
                                  onChanged: (_) => setState(() {}),
                                ),
                              )
                            else
                              SizedBox(
                                width: 120,
                                child: Text(s.notParticipating,
                                    style: GoogleFonts.inter(color: c.textMuted, fontSize: 12),
                                    textAlign: TextAlign.right),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_totalAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_customSum - _totalAmount).abs() < 0.01
                              ? AppTheme.greenFill : AppTheme.redFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (_customSum - _totalAmount).abs() < 0.01
                                  ? Icons.check_circle_outline : Icons.info_outline,
                              size: 16,
                              color: (_customSum - _totalAmount).abs() < 0.01
                                  ? AppTheme.green : AppTheme.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_customSum - _totalAmount).abs() < 0.01
                                    ? s.splitCorrect
                                    : s.splitMismatchMsg(widget.currency, _customSum, _totalAmount),
                                style: GoogleFonts.inter(
                                  color: (_customSum - _totalAmount).abs() < 0.01
                                      ? AppTheme.green : AppTheme.red,
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                  ],

                  // Percentage split
                  if (_mode == SplitMode.percentage) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _label(s.percentPerPerson, c)),
                        TextButton.icon(
                          onPressed: _activeMembers.isNotEmpty
                              ? () => setState(_autoFillPct)
                              : null,
                          icon: const Icon(Icons.auto_fix_high, size: 14),
                          label: Text(s.divideEqual, style: GoogleFonts.inter(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.members.map((m) {
                      final active = _activeMembers.contains(m.id);
                      final pct = _parsePct(m.id);
                      final computed = _totalAmount > 0 ? _totalAmount * pct / 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                if (active) {
                                  _activeMembers.remove(m.id);
                                  _pctCtrls[m.id]!.clear();
                                } else {
                                  _activeMembers.add(m.id);
                                }
                                _autoFillPct();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: active ? accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: active ? accent : c.border, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: active
                                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            MemberAvatar(name: m.name, allMembers: _memberNames, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(m.name,
                                  style: GoogleFonts.inter(
                                    color: active ? c.textPrimary : c.textMuted,
                                    fontSize: 14,
                                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                                  )),
                            ),
                            const SizedBox(width: 8),
                            if (active) ...[
                              SizedBox(
                                width: 82,
                                child: TextField(
                                  controller: _pctCtrls[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                                  decoration: const InputDecoration(
                                      hintText: '0', suffixText: '%'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              if (_totalAmount > 0) ...[
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '${widget.currency} ${computed.toStringAsFixed(2)}',
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.inter(
                                        color: c.textMuted, fontSize: 11),
                                  ),
                                ),
                              ],
                            ] else
                              SizedBox(
                                width: 82,
                                child: Text(s.notParticipating,
                                    style: GoogleFonts.inter(
                                        color: c.textMuted, fontSize: 12),
                                    textAlign: TextAlign.right),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_activeMembers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_pctSum - 100).abs() < 0.5
                              ? AppTheme.greenFill
                              : AppTheme.redFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (_pctSum - 100).abs() < 0.5
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              size: 16,
                              color: (_pctSum - 100).abs() < 0.5
                                  ? AppTheme.green
                                  : AppTheme.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_pctSum - 100).abs() < 0.5
                                    ? s.splitCorrect
                                    : s.splitPercentErrorMsg(_pctSum),
                                style: GoogleFonts.inter(
                                  color: (_pctSum - 100).abs() < 0.5
                                      ? AppTheme.green
                                      : AppTheme.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(s.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _save,
                          child: Text(widget.expense != null ? s.updateExpense : s.saveExpense),
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

  Widget _label(String t, AppColors c) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.inter(
        color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _tipToggleBtn(String label, bool active, AppColors c, Color accent, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : c.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
      );

  Widget _infoBox(IconData icon, String msg, Color bg, Color fg) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: GoogleFonts.inter(
            color: fg, fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}
