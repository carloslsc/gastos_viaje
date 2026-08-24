import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../l10n/app_strings.dart';

class ExportService {
  static const _channel = MethodChannel('com.garrobo.nivela/downloads');

  // ── Color palette ────────────────────────────────────
  static final _bgColor       = PdfColor.fromHex('F5F4F0');
  static final _accentColor   = PdfColor.fromHex('C8592A');
  static final _textDark      = PdfColor.fromHex('1A1816');
  static final _textMuted     = PdfColor.fromHex('8A8278');
  static final _textSecondary = PdfColor.fromHex('5A5550');
  static final _borderColor   = PdfColor.fromHex('DDD8D0');
  static final _greenColor    = PdfColor.fromHex('4CAF7D');
  static final _redColor      = PdfColor.fromHex('E05C5C');

  static String _modeLabel(SplitMode mode, AppStrings s) => switch (mode) {
    SplitMode.equal      => s.splitEqual,
    SplitMode.own        => s.splitOwn,
    SplitMode.custom     => s.splitCustom,
    SplitMode.percentage => s.splitPercent,
  };

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^\w\sÀ-ɏ]'), '_').trim().replaceAll(RegExp(r'\s+'), '_');

  // Writes [bytes] to a temp file and returns it.
  static Future<File> _writeTempFile(String fileName, Uint8List bytes) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _saveToDownloads(File tempFile, String fileName, String mimeType) =>
      _channel.invokeMethod<void>('saveToDownloads', {
        'filePath': tempFile.path,
        'fileName': fileName,
        'mimeType': mimeType,
      });

  // ── Shared export sheet ───────────────────────────────
  // Builds the file first, then shows ONE sheet with both actions instantly.
  static Future<void> _export(
    BuildContext context,
    AppStrings s,
    Future<Uint8List> Function() buildBytes,
    String fileName,
    String mimeType,
    String subject,
  ) async {
    Uint8List bytes;
    try {
      bytes = await buildBytes();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.pdfExportError}: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final tempFile = await _writeTempFile(fileName, bytes);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(s.exportSaveOption),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _saveToDownloads(tempFile, fileName, mimeType);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.exportSaved), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${s.pdfExportError}: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(s.exportShareOption),
              onTap: () {
                Navigator.pop(ctx);
                Share.shareXFiles(
                  [XFile(tempFile.path, mimeType: mimeType, name: fileName)],
                  subject: subject,
                );
              },
            ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── PDF export ────────────────────────────────────────
  static Future<void> exportPdf(BuildContext context, Trip trip, AppStrings s) =>
      _export(context, s, () => _buildPdfBytes(trip, s),
          '${_safeName(trip.name)}.pdf', 'application/pdf', trip.name);

  static Future<Uint8List> _buildPdfBytes(Trip trip, AppStrings s) async {
    await initializeDateFormatting(s.langCode);

    pw.Font regular, bold, medium;
    try {
      switch (s.langCode) {
        case 'zh':
          regular = await PdfGoogleFonts.notoSansSCRegular();
          bold    = await PdfGoogleFonts.notoSansSCBold();
          medium  = await PdfGoogleFonts.notoSansSCMedium();
        case 'ja':
          regular = await PdfGoogleFonts.notoSansJPRegular();
          bold    = await PdfGoogleFonts.notoSansJPBold();
          medium  = await PdfGoogleFonts.notoSansJPMedium();
        case 'ko':
          regular = await PdfGoogleFonts.notoSansKRRegular();
          bold    = await PdfGoogleFonts.notoSansKRBold();
          medium  = await PdfGoogleFonts.notoSansKRMedium();
        default:
          regular = await PdfGoogleFonts.interRegular();
          bold    = await PdfGoogleFonts.interBold();
          medium  = await PdfGoogleFonts.interMedium();
      }
    } catch (_) {
      regular = pw.Font.helvetica();
      bold    = pw.Font.helveticaBold();
      medium  = pw.Font.helveticaBold();
    }

    final doc          = pw.Document();
    final dateStr      = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final participants = trip.allParticipants;
    final balances     = trip.balances;
    final transfers    = trip.transfers;
    final total        = trip.totalSpent;
    final avg          = participants.isEmpty ? 0.0 : total / participants.length;
    final count        = trip.expenses.length;

    final expensesByDate = <DateTime, List<Expense>>{};
    for (final e in trip.expenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      expensesByDate.putIfAbsent(day, () => []).add(e);
    }
    final sortedDays = expensesByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    pw.TextStyle style({double size = 10, pw.Font? font, PdfColor? color}) =>
        pw.TextStyle(font: font ?? regular, fontSize: size, color: color ?? _textDark);

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 48, 36, 48),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: _bgColor),
        ),
      ),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 4, color: _accentColor),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [pw.Text('Nivela · ${trip.name}', style: style(size: 8, color: _textMuted))],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _borderColor, thickness: 0.5),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (ctx) => pw.Column(children: [
        pw.SizedBox(height: 8),
        pw.Divider(color: _borderColor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${s.pdfGeneratedBy} · $dateStr', style: style(size: 8, color: _textMuted)),
            pw.Text('pág. ${ctx.pageNumber} / ${ctx.pagesCount}', style: style(size: 8, color: _textMuted)),
          ],
        ),
      ]),
      build: (ctx) => [
        pw.Text(trip.name, style: style(size: 22, font: bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          [
            if (trip.dateLabel.isNotEmpty) trip.dateLabel,
            trip.currency,
            s.pdfPeople(participants.length),
          ].join(' · '),
          style: style(size: 11, color: _textSecondary),
        ),
        pw.SizedBox(height: 20),

        pw.Row(children: [
          _statBox(s.totalSpent,     '${trip.currency} ${total.toStringAsFixed(2)}', regular, bold),
          pw.SizedBox(width: 10),
          _statBox(s.pdfPerPerson,   '${trip.currency} ${avg.toStringAsFixed(2)}',   regular, bold),
          pw.SizedBox(width: 10),
          _statBox(s.pdfExpenseCount, '$count', regular, bold),
        ]),
        pw.SizedBox(height: 24),

        pw.Text(s.balancePerPerson.toUpperCase(), style: style(size: 9, font: medium, color: _textMuted)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _borderColor, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _accentColor),
              children: [
                _tableCell(s.pdfPerson,    bold, PdfColors.white),
                _tableCell(s.paidByLabel,  bold, PdfColors.white),
                _tableCell(s.consumedLabel,bold, PdfColors.white),
                _tableCell(s.pdfBalance,   bold, PdfColors.white),
              ],
            ),
            ...participants.map((m) {
              final paid = trip.expenses.where((e) => e.payer == m.id).fold(0.0, (s, e) => s + e.amount);
              final consumed = trip.expenses.fold(0.0, (s, e) => s + (e.splits[m.id] ?? 0));
              final bal = balances[m.id] ?? 0;
              final balColor = bal > 0.005 ? _greenColor : bal < -0.005 ? _redColor : _textMuted;
              final balText = bal > 0.005
                  ? '+${trip.currency} ${bal.toStringAsFixed(2)}'
                  : bal < -0.005
                  ? '-${trip.currency} ${bal.abs().toStringAsFixed(2)}'
                  : '${trip.currency} 0.00';
              return pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.white),
                children: [
                  _tableCell(m.name, regular, _textDark),
                  _tableCell('${trip.currency} ${paid.toStringAsFixed(2)}', regular, _textDark),
                  _tableCell('${trip.currency} ${consumed.toStringAsFixed(2)}', regular, _textDark),
                  _tableCell(balText, bold, balColor),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 24),

        pw.Text(s.necessaryTransfers.toUpperCase(), style: style(size: 9, font: medium, color: _textMuted)),
        pw.SizedBox(height: 8),
        if (transfers.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _borderColor, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(s.pdfAllSettled, style: style(color: _greenColor)),
          )
        else
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _borderColor, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: transfers.map((t) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(children: [
                  pw.Text(trip.memberName(t.from), style: style(font: bold)),
                  pw.Text('  →  ', style: style(color: _textMuted)),
                  pw.Text(trip.memberName(t.to), style: style(font: bold)),
                  pw.Spacer(),
                  pw.Text('${trip.currency} ${t.amount.toStringAsFixed(2)}', style: style(color: _accentColor, font: bold)),
                ]),
              )).toList(),
            ),
          ),
        pw.SizedBox(height: 24),

        pw.Text(s.pdfExpenseDetail, style: style(size: 9, font: medium, color: _textMuted)),
        pw.SizedBox(height: 8),

        ...sortedDays.expand((day) {
          final dayExpenses = expensesByDate[day]!..sort((a, b) => b.date.compareTo(a.date));
          final dayTotal = dayExpenses.fold(0.0, (s, e) => s + e.amount);
          final rawLabel = DateFormat('EEEE, d MMMM yyyy', s.langCode).format(day);
          final dayLabel = rawLabel[0].toUpperCase() + rawLabel.substring(1);

          return [
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor(_accentColor.red, _accentColor.green, _accentColor.blue, 0.08),
                border: pw.Border(left: pw.BorderSide(color: _accentColor, width: 3)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dayLabel, style: style(size: 10, font: medium)),
                  pw.Text('${trip.currency} ${dayTotal.toStringAsFixed(2)}', style: style(size: 10, font: bold, color: _accentColor)),
                ],
              ),
            ),
            ...dayExpenses.map((e) {
              final splitLine = e.mode == SplitMode.own
                  ? s.pdfOwnExpense
                  : e.splits.entries.where((en) => en.value > 0)
                      .map((en) => '${trip.memberName(en.key)} ${trip.currency} ${en.value.toStringAsFixed(2)}')
                      .join(' · ');
              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.5)),
                ),
                padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Expanded(child: pw.Text(e.name, style: style(font: bold))),
                      pw.Text(s.catLabel(e.category), style: style(size: 9, color: _textMuted)),
                      pw.SizedBox(width: 12),
                      pw.Text(trip.memberName(e.payer), style: style(size: 9, color: _textMuted)),
                      pw.SizedBox(width: 12),
                      pw.Text('${trip.currency} ${e.amount.toStringAsFixed(2)}', style: style(font: bold)),
                    ]),
                    pw.SizedBox(height: 3),
                    pw.Text(splitLine, style: style(size: 9, color: _textMuted)),
                    pw.SizedBox(height: 4),
                  ],
                ),
              );
            }),
            pw.Divider(color: _borderColor, thickness: 0.5),
          ];
        }),
      ],
    ));

    return Uint8List.fromList(await doc.save());
  }

  // ── CSV export ────────────────────────────────────────
  static Future<void> exportCsv(BuildContext context, Trip trip, AppStrings s) =>
      _export(context, s, () => _buildCsvBytes(trip, s),
          '${_safeName(trip.name)}.csv', 'text/csv', trip.name);

  static Future<Uint8List> _buildCsvBytes(Trip trip, AppStrings s) async {
    final dateStr      = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final participants = trip.allParticipants;
    final balances     = trip.balances;

    final buf = StringBuffer();
    buf.writeln('# ${trip.name}');
    buf.writeln('# ${s.csvExportedOn}: $dateStr');
    buf.writeln('# ${s.currency}: ${trip.currency}');
    buf.writeln('#');

    buf.writeln(s.tabExpenses.toUpperCase());
    final memberNames = participants.map((m) => _csvField(m.name)).join(',');
    buf.writeln('${s.date},${s.csvConceptCol},${s.category},${s.amount},${s.paidByLabel},${s.splitMode},$memberNames');

    for (final e in trip.expenses) {
      final splits = participants.map((m) => (e.splits[m.id] ?? 0.0).toStringAsFixed(2)).join(',');
      buf.writeln([
        DateFormat('yyyy-MM-dd').format(e.date),
        _csvField(e.name),
        _csvField(s.catLabel(e.category)),
        e.amount.toStringAsFixed(2),
        _csvField(trip.memberName(e.payer)),
        _modeLabel(e.mode, s),
        splits,
      ].join(','));
    }

    buf.writeln();
    buf.writeln(s.balancePerPerson.toUpperCase());
    buf.writeln('${s.pdfPerson},${s.paidByLabel},${s.consumedLabel},${s.pdfBalance}');

    for (final m in participants) {
      final paid     = trip.expenses.where((e) => e.payer == m.id).fold(0.0, (sum, e) => sum + e.amount);
      final consumed = trip.expenses.fold(0.0, (sum, e) => sum + (e.splits[m.id] ?? 0));
      final bal      = balances[m.id] ?? 0;
      final balStr   = bal >= 0 ? '+${bal.toStringAsFixed(2)}' : '-${bal.abs().toStringAsFixed(2)}';
      buf.writeln('${_csvField(m.name)},${paid.toStringAsFixed(2)},${consumed.toStringAsFixed(2)},$balStr');
    }

    // UTF-8 BOM ensures CJK characters render correctly in Excel and most viewers
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buf.toString())]);
  }

  // ── Helpers ───────────────────────────────────────────
  static pw.Widget _tableCell(String text, pw.Font font, PdfColor color) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10, color: color)),
      );

  static pw.Widget _statBox(String label, String value, pw.Font regular, pw.Font bold) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: PdfColor.fromHex('DDD8D0'), width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColor.fromHex('8A8278'))),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColor.fromHex('1A1816'))),
            ],
          ),
        ),
      );

  static String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
