import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/trip_provider.dart';
import 'database_service.dart';

class BackupService {
  static const int _version = 2;
  static const _channel = MethodChannel('com.garrobo.nivela/downloads');

  // ── Export ─────────────────────────────────────────────
  static Future<void> exportAll(BuildContext context, AppStrings s) async {
    final tripProvider = context.read<TripProvider>();
    final trips = tripProvider.trips;
    final activeId = tripProvider.activeTrip?.id;

    final payload = {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeId': activeId,
      'trips': trips.map((t) => t.toJson()).toList(),
    };

    // Build file
    final bytes = utf8.encode(jsonEncode(payload));
    final now = DateTime.now();
    final filename =
        'nivela_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';

    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$filename');
    await tempFile.writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;

    // Bottom sheet identical to ExportService
    await showModalBottomSheet<void>(
      context: context, // ignore: use_build_context_synchronously
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
                    await _channel.invokeMethod<void>('saveToDownloads', {
                      'filePath': tempFile.path,
                      'fileName': filename,
                      'mimeType': 'application/json',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar( // ignore: use_build_context_synchronously
                        SnackBar(
                          content: Text(s.backupExportSaved),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar( // ignore: use_build_context_synchronously
                        SnackBar(
                          content: Text('${s.backupError}: $e'),
                          backgroundColor: Colors.red,
                        ),
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
                    [XFile(tempFile.path, mimeType: 'application/json', name: filename)],
                    subject: filename,
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

  // ── Import ─────────────────────────────────────────────
  static Future<bool> importAll(BuildContext context, AppStrings s) async {
    // Capture messenger before any await so snackbars never touch a stale context.
    final messenger = ScaffoldMessenger.maybeOf(context);
    void showSnack(String msg) => messenger?.showSnackBar(
          SnackBar(content: Text(msg, style: GoogleFonts.inter())),
        );

    // 1. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return false;
    final path = result.files.first.path;
    if (path == null) return false;

    // 2. Parse JSON
    String content;
    try {
      content = await File(path).readAsString();
    } catch (_) {
      showSnack(s.backupInvalidFile);
      return false;
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      showSnack(s.backupInvalidFile);
      return false;
    }

    // 3. Validate version + structure
    final version = payload['version'] as int?;
    if (version == null || version < 1 || version > _version) {
      showSnack(s.backupInvalidFile);
      return false;
    }
    final tripsJson = payload['trips'] as List?;
    if (tripsJson == null) {
      showSnack(s.backupInvalidFile);
      return false;
    }

    // 4. Confirmation dialog — context is safe here (mounted-checked)
    if (!context.mounted) return false;
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>( // ignore: use_build_context_synchronously
      context: context, // ignore: use_build_context_synchronously
      builder: (ctx) => AlertDialog(
        title: Text(s.backupConfirmTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(s.backupConfirmBody, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(s.backupReplace),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    // 5. Parse trips
    List<Trip> trips;
    try {
      trips = tripsJson
          .map((t) => Trip.fromJson(t as Map<String, dynamic>))
          .toList();
    } catch (_) {
      showSnack(s.backupInvalidFile);
      return false;
    }
    final activeId = payload['activeId'] as String?;

    // 6. Replace DB and reload
    try {
      await DatabaseService.deleteAllTrips();
      for (final trip in trips) {
        await DatabaseService.insertTrip(trip);
      }
      if (activeId != null) await DatabaseService.saveActiveId(activeId);
      if (context.mounted) {
        await context.read<TripProvider>().load(); // ignore: use_build_context_synchronously
        showSnack(s.backupSuccess);
      }
      return true;
    } catch (_) {
      showSnack(s.backupError);
      return false;
    }
  }
}
