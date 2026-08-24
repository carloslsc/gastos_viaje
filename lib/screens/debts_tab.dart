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
import '../widgets/add_payment_sheet.dart';
import '../widgets/banner_ad_widget.dart';

class DebtsTab extends StatelessWidget {
  const DebtsTab({super.key});

  void _openPaymentSheet(
    BuildContext context, {
    String? from,
    String? to,
    double? amount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TripProvider>(),
        child: AddPaymentSheet(
          initialFrom: from,
          initialTo: to,
          initialAmount: amount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final trip = context.watch<TripProvider>().activeTrip!;

    Widget content;

    if (trip.expenses.isEmpty) {
      content = EmptyState(
        icon: FluentIcons.handshake_24_regular,
        title: s.noDebts,
        subtitle: s.noDebtsHint,
      );
    } else {
      final transfers = trip.transfers;
      final balances = trip.balances;

      if (transfers.isEmpty && trip.payments.isEmpty) {
        content = EmptyState(
          icon: FluentIcons.checkmark_circle_24_regular,
          title: s.everyoneUpToDate,
          subtitle: s.everyoneUpToDateHint,
        );
      } else {
        content = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom + 72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: AppBannerAd()),
              const SizedBox(height: 16),

              // Header summary
              if (transfers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.accentFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(FluentIcons.lightbulb_24_regular, size: 20, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.transfersMsg(transfers.length),
                        style: GoogleFonts.inter(
                          color: c.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]),
                ),
              if (transfers.isNotEmpty) const SizedBox(height: 20),

              if (transfers.isNotEmpty) ...[
                SectionHeader(
                  title: s.necessaryTransfers,
                  trailing: StatusBadge(
                    label: s.movementBadge(transfers.length),
                    color: c.accent,
                    bgColor: c.accentFill,
                  ),
                ),
                ...transfers.map((t) => _TransferCard(
                  transfer: t,
                  trip: trip,
                  onRegisterPayment: () => _openPaymentSheet(
                    context,
                    from: t.from,
                    to: t.to,
                    amount: t.amount,
                  ),
                )),
                const SizedBox(height: 24),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.greenFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(FluentIcons.checkmark_circle_24_regular, size: 20, color: AppTheme.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.allCurrent,
                        style: GoogleFonts.inter(
                          color: AppTheme.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // Registered payments
              if (trip.payments.isNotEmpty) ...[
                SectionHeader(
                  title: s.registeredPayments,
                  trailing: StatusBadge.blue(s.paymentBadge(trip.payments.length)),
                ),
                FluentCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: trip.payments.reversed.map((p) => _PaymentRow(
                      payment: p,
                      trip: trip,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              SectionHeader(title: s.individualBalance),

              FluentCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: trip.allParticipants.map((m) {
                    final b = balances[m.id] ?? 0;
                    final memberNames = trip.allParticipants.map((x) => x.name).toList();
                    final badge = b > 0.005
                        ? StatusBadge.green('+ ${trip.currency} ${b.toStringAsFixed(2)}')
                        : b < -0.005
                        ? StatusBadge.red('− ${trip.currency} ${b.abs().toStringAsFixed(2)}')
                        : StatusBadge.blue(s.upToDate);

                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          MemberAvatar(name: m.name, allMembers: memberNames, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(fit: FlexFit.loose, child: badge),
                        ]),
                      ),
                      const Divider(height: 1),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }
    }

    return SizedBox.expand(
      child: ColoredBox(
        color: c.background,
        child: Stack(
          children: [
            content,
            if (trip.expenses.isNotEmpty)
              Positioned(
                right: 20,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
                child: FloatingActionButton.extended(
                  heroTag: 'payment_fab',
                  onPressed: () => _openPaymentSheet(context),
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  icon: const Icon(FluentIcons.money_24_regular, size: 20),
                  label: Text(
                    s.registerPayment,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Transfer Card ─────────────────────────────────────
class _TransferCard extends StatefulWidget {
  final Transfer transfer;
  final Trip trip;
  final VoidCallback onRegisterPayment;

  const _TransferCard({
    required this.transfer,
    required this.trip,
    required this.onRegisterPayment,
  });

  @override
  State<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends State<_TransferCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final t = widget.transfer;
    final trip = widget.trip;
    final fromName = trip.memberName(t.from);
    final toName = trip.memberName(t.to);
    final memberNames = trip.allParticipants.map((m) => m.name).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _hovered ? c.surfaceHigh : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hovered ? c.borderHover : c.border),
        ),
        child: Column(
          children: [
            Row(children: [
              // FROM
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MemberAvatar(name: fromName, allMembers: memberNames, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      fromName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      s.mustPay,
                      style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Arrow + amount
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      '${trip.currency} ${t.amount.toStringAsFixed(2)}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 24, height: 1.5, color: c.border),
                    Icon(Icons.arrow_forward, size: 16, color: c.accent),
                    Container(width: 24, height: 1.5, color: c.border),
                  ]),
                ]),
              ),

              // TO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MemberAvatar(name: toName, allMembers: memberNames, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      toName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      s.receivesLabel,
                      style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onRegisterPayment,
                icon: const Icon(FluentIcons.money_24_regular, size: 16),
                label: Text(s.registerThisPayment),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.accent,
                  side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment Row ───────────────────────────────────────
class _PaymentRow extends StatelessWidget {
  final Payment payment;
  final Trip trip;

  const _PaymentRow({required this.payment, required this.trip});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = context.watch<SettingsProvider>().strings;
    final fromName = trip.memberName(payment.from);
    final toName = trip.memberName(payment.to);
    final allNames = trip.allParticipants.map((m) => m.name).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              MemberAvatar(name: fromName, allMembers: allNames, size: 34),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              MemberAvatar(name: toName, allMembers: allNames, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fromName → $toName',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (payment.note.isNotEmpty)
                      Text(
                        payment.note,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: c.textMuted, fontSize: 11),
                      )
                    else
                      Text(
                        '${payment.date.day}/${payment.date.month}/${payment.date.year}',
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
                    '${trip.currency} ${payment.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: AppTheme.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (payment.note.isNotEmpty)
                    Text(
                      '${payment.date.day}/${payment.date.month}/${payment.date.year}',
                      style: GoogleFonts.inter(color: c.textMuted, fontSize: 10),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, s),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surfaceHigher,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline, size: 14, color: c.textMuted),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _confirmDelete(BuildContext context, AppStrings s) {
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
          s.deletePayment,
          style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '¿Eliminar el pago de ${trip.memberName(payment.from)} a ${trip.memberName(payment.to)} por ${trip.currency} ${payment.amount.toStringAsFixed(2)}?',
          style: GoogleFonts.inter(color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TripProvider>().deletePayment(payment.id);
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
