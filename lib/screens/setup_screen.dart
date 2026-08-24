import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameCtrl   = TextEditingController();
  final _dateCtrl   = TextEditingController();
  final _memberCtrl = TextEditingController();
  String _currency = 'MXN';
  final List<String> _members = [];
  bool _loading = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  static const List<String> _currencyCodes = [
    'MXN', 'USD', 'EUR', 'GBP', 'JPY', 'CNY', 'KRW', 'CHF', 'RUB',
    'CAD', 'AUD', 'INR', 'BRL', 'COP', 'ARS', 'TRY', 'GTQ',
  ];

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty || _members.contains(name)) {
      _memberCtrl.clear();
      return;
    }
    setState(() {
      _members.add(name);
      _memberCtrl.clear();
    });
  }

  Future<void> _start(String errorNeedName, String errorNeedTwo) async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError(errorNeedName);
      return;
    }
    if (_members.length < 2) {
      _showError(errorNeedTwo);
      return;
    }
    setState(() => _loading = true);
    await context.read<TripProvider>().createTrip(
      name: _nameCtrl.text.trim(),
      currency: _currency,
      dateLabel: _dateCtrl.text.trim(),
      members: List.from(_members),
    );
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppTheme.red),
  );

  Future<void> _showMonthYearPicker(BuildContext context) async {
    final s = context.read<SettingsProvider>().strings;
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.border),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: c.textSecondary),
                    onPressed: () => setDlg(() => tempYear--),
                  ),
                  Text(
                    '$tempYear',
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: c.textSecondary),
                    onPressed: () => setDlg(() => tempYear++),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(3, (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: List.generate(4, (col) {
                    final i = row * 4 + col;
                    final month = i + 1;
                    final selected = month == tempMonth;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: col == 0 ? 0 : 6),
                        child: GestureDetector(
                          onTap: () => setDlg(() => tempMonth = month),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? accent : c.surfaceHigher,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s.monthAbbr[i],
                              style: GoogleFonts.inter(
                                color: selected ? Colors.white : c.textSecondary,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel, style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _selectedMonth = tempMonth;
                    _selectedYear = tempYear;
                    _dateCtrl.text = '${s.monthAbbr[tempMonth - 1]} $tempYear';
                  });
                }
              },
              child: Text(s.ok),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final s = context.watch<SettingsProvider>().strings;
    final c = AppColors.of(context);
    final hasTrips = provider.trips.isNotEmpty;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTrips) ...[
                  TextButton.icon(
                    onPressed: () =>
                        provider.setActiveTrip(provider.trips.last.id),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(s.backToTrips,
                        style: GoogleFonts.inter(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: c.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Logo
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: c.textPrimary,
                    ),
                    children: [
                      const TextSpan(text: 'Ni'),
                      TextSpan(
                        text: 'vela',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTrips ? s.configureNewTrip : s.divideExpenses,
                  style: GoogleFonts.inter(color: c.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 36),

                FluentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, s.tripName),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                        decoration: InputDecoration(hintText: s.tripNameHint),
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, s.currency),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _currency,
                              dropdownColor: c.surfaceHigh,
                              style: GoogleFonts.inter(
                                  color: c.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(),
                              selectedItemBuilder: (_) => _currencyCodes
                                  .map((code) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          code,
                                          style: GoogleFonts.inter(
                                            color: c.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              items: _currencyCodes
                                  .map((code) => DropdownMenuItem(
                                        value: code,
                                        child: Text(
                                          s.currencyLabel(code),
                                          style: GoogleFonts.inter(
                                            color: c.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _currency = v!),
                            ),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, s.date),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _dateCtrl,
                              readOnly: true,
                              onTap: () => _showMonthYearPicker(context),
                              style: GoogleFonts.inter(
                                  color: c.textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: s.dateHint,
                                suffixIcon: Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                          ],
                        )),
                      ]),
                      const SizedBox(height: 20),

                      _label(context, s.editParticipants),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _memberCtrl,
                            style: GoogleFonts.inter(
                                color: c.textPrimary, fontSize: 15),
                            decoration: InputDecoration(hintText: s.participantHint),
                            onSubmitted: (_) => _addMember(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addMember,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ]),

                      if (_members.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _members.map((m) {
                            final pos = _members.indexOf(m);
                            final paletteIdx = AppTheme.memberColorOrder[
                                pos % AppTheme.memberColorOrder.length];
                            final colors = AppTheme.avatarPalette[paletteIdx];
                            return Container(
                              padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                              decoration: BoxDecoration(
                                color: c.surfaceHigher,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: colors[0],
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      m[0].toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: colors[1],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(m,
                                      style: GoogleFonts.inter(
                                        color: c.textPrimary,
                                        fontSize: 13,
                                      )),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _members.remove(m)),
                                    child: Icon(Icons.close,
                                        size: 15, color: c.textMuted),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => _start(s.errorNeedName, s.errorNeedTwo),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  s.startTrip,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String t) {
    final c = AppColors.of(context);
    return Text(
      t,
      style: GoogleFonts.inter(
        color: c.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
