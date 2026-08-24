import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';
import 'banner_ad_widget.dart';

class AddPaymentSheet extends StatefulWidget {
  final String? initialFrom;
  final String? initialTo;
  final double? initialAmount;

  const AddPaymentSheet({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialAmount,
  });

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String? _from;
  String? _to;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    if (widget.initialAmount != null) {
      _amountCtrl.text = widget.initialAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip!;
    // Use allParticipants so soft-deleted members with open balances can still receive/send payments
    final members = trip.allParticipants;
    final allNames = members.map((m) => m.name).toList();
    final mq = MediaQuery.of(context);
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final accent = Theme.of(context).colorScheme.primary;

    final enteredAmount = double.tryParse(_amountCtrl.text) ?? 0;
    final suggestedTransfer = (_from != null && _to != null)
        ? trip.transfers.where((t) => t.from == _from && t.to == _to).firstOrNull
        : null;
    final showOverpayment = _from != null &&
        _to != null &&
        enteredAmount > 0.005 &&
        suggestedTransfer != null &&
        enteredAmount > suggestedTransfer.amount + 0.005;
    final showNoDirectDebt = _from != null &&
        _to != null &&
        enteredAmount > 0.005 &&
        suggestedTransfer == null;

    return Container(
      height: mq.size.height * 0.80,
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
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(FluentIcons.money_24_regular, size: 20, color: accent),
                const SizedBox(width: 10),
                Text(
                  s.newPayment,
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
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, mq.viewInsets.bottom + 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: AppBannerAd()),
                    const SizedBox(height: 16),
                    // Visual arrow card
                    if (_from != null || _to != null)
                      _PaymentPreview(
                        fromName: _from != null ? trip.memberName(_from!) : null,
                        toName: _to != null ? trip.memberName(_to!) : null,
                        allNames: allNames,
                        currency: trip.currency,
                        amount: double.tryParse(_amountCtrl.text),
                      ),
                    if (showOverpayment || showNoDirectDebt) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.amberFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(FluentIcons.warning_24_regular, size: 16, color: AppTheme.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                showOverpayment ? s.warningOverpayment : s.warningNoDirectDebt,
                                style: GoogleFonts.inter(color: AppTheme.amber, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_from != null || _to != null) const SizedBox(height: 16),

                    _label(s.from, c),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('from-$_from'),
                      initialValue: _from,
                      decoration: InputDecoration(hintText: s.selectPayer),
                      dropdownColor: c.surface,
                      items: members.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Row(
                          children: [
                            MemberAvatar(name: m.name, allMembers: allNames, size: 24),
                            const SizedBox(width: 10),
                            Text(m.name, style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14)),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) => setState(() {
                        _from = v;
                        if (_to == v) _to = null;
                      }),
                      validator: (v) => v == null ? s.errorSelectPayer : null,
                    ),
                    const SizedBox(height: 16),

                    _label(s.to, c),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('to-$_from-$_to'),
                      initialValue: _to,
                      decoration: InputDecoration(hintText: s.selectReceiver),
                      dropdownColor: c.surface,
                      items: members
                          .where((m) => m.id != _from)
                          .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Row(
                              children: [
                                MemberAvatar(name: m.name, allMembers: allNames, size: 24),
                                const SizedBox(width: 10),
                                Text(m.name, style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14)),
                              ],
                            ),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _to = v),
                      validator: (v) => v == null ? s.errorSelectReceiver : null,
                    ),
                    const SizedBox(height: 16),

                    _label('${s.amount} (${trip.currency})', c),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(hintText: '0.00'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return s.errorEnterAmount;
                        final d = double.tryParse(v);
                        if (d == null || d <= 0) return s.errorInvalidAmount;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _label(s.note, c),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteCtrl,
                      style: GoogleFonts.inter(color: c.textPrimary, fontSize: 15),
                      decoration: InputDecoration(hintText: s.noteHint),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),

                    _label(s.date, c),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: accent,
                                surface: c.surface,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: c.surfaceHigher,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(FluentIcons.calendar_24_regular, size: 18, color: c.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              '${_date.day}/${_date.month}/${_date.year}',
                              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(s.savePayment),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TripProvider>();
    provider.addPayment(provider.buildPayment(
      from: _from!,
      to: _to!,
      amount: double.parse(_amountCtrl.text),
      note: _noteCtrl.text.trim(),
      date: _date,
    ));
    Navigator.pop(context);
  }

  Widget _label(String t, AppColors c) => Text(
    t,
    style: GoogleFonts.inter(
      color: c.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PaymentPreview extends StatelessWidget {
  final String? fromName;
  final String? toName;
  final List<String> allNames;
  final String currency;
  final double? amount;

  const _PaymentPreview({
    required this.fromName,
    required this.toName,
    required this.allNames,
    required this.currency,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accentFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (fromName != null)
            MemberAvatar(name: fromName!, allMembers: allNames, size: 36)
          else
            _placeholder(c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                if (amount != null && amount! > 0)
                  Text(
                    '$currency ${amount!.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 20, height: 1.5, color: accent.withValues(alpha: 0.5)),
                    Icon(Icons.arrow_forward, size: 16, color: accent),
                    Container(width: 20, height: 1.5, color: accent.withValues(alpha: 0.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (toName != null)
            MemberAvatar(name: toName!, allMembers: allNames, size: 36)
          else
            _placeholder(c),
        ],
      ),
    );
  }

  Widget _placeholder(AppColors c) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: c.surfaceHigher,
      shape: BoxShape.circle,
      border: Border.all(color: c.border),
    ),
    child: Icon(Icons.person_outline, size: 18, color: c.textMuted),
  );
}
