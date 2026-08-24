import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class WidgetService {
  static const _androidProvider         = 'TripWidgetProvider';
  static const _donutProvider           = 'DonutWidgetProvider';
  static const _categoryAndroidProvider = 'CategoryTripWidgetProvider';
  static const _categoryDonutProvider   = 'CategoryDonutWidgetProvider';

  static Future<void> update(Trip? trip) async {
    try {
      await _update(trip);
    } catch (_) {
      // Widget update is non-critical — ignore silently
    }
  }

  static Future<void> _update(Trip? trip) async {
    final prefs = await SharedPreferences.getInstance();

    if (trip == null || (trip.expenses.isEmpty && trip.payments.isEmpty)) {
      await prefs.setString('widget_trip_name', trip?.name ?? '');
      await prefs.setString('widget_total', '—');
      await prefs.setString('widget_balances', '');
      await prefs.setString('widget_consumption', '');
      await prefs.setString('widget_categories', '');
      await prefs.setString('widget_updated', _timestamp());
    } else {
      final balances = trip.balances;
      final lines = trip.allParticipants
          .where((m) => (balances[m.id] ?? 0).abs() > 0.005)
          .toList()
        ..sort((a, b) => (balances[b.id] ?? 0).compareTo(balances[a.id] ?? 0));

      final balanceText = lines.map((m) {
        final bal = balances[m.id] ?? 0;
        final sign = bal >= 0 ? '+' : '-';
        final name = m.name.length > 8 ? m.name.substring(0, 7) : m.name;
        return '$name $sign${bal.abs().toStringAsFixed(0)}';
      }).take(4).join('  ');

      // Per-person consumption for donut widget: "name:amount|..."
      // All participants are included (even at 0.00) so the Kotlin mapIndexedNotNull
      // preserves the original palette index — zero-amount entries are skipped by
      // the Kotlin parser's takeIf { it > 0 } but i stays anchored to the full list.
      final allParticipants = trip.allParticipants;
      final consumptionParts = <String>[];
      for (int i = 0; i < allParticipants.length; i++) {
        final m = allParticipants[i];
        final amt = trip.expenses.fold(0.0, (s, e) => s + (e.splits[m.id] ?? 0));
        final defaultIdx = AppTheme.memberColorOrder[i % AppTheme.memberColorOrder.length];
        final colorIdx = (m.colorIndex ?? defaultIdx) % AppTheme.avatarPalette.length;
        consumptionParts.add('${m.name}:${amt.toStringAsFixed(2)}:$colorIdx');
      }
      final consumptionText = consumptionParts.join('|');

      // Per-category totals for category widgets: "key:amount|..." sorted desc
      final catTotals = <String, double>{};
      for (final e in trip.expenses) {
        catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
      }
      final sortedCats = catTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final categoryText = sortedCats
          .where((e) => e.value > 0.005)
          .map((e) => '${e.key}:${e.value.toStringAsFixed(2)}')
          .join('|');

      await prefs.setString('widget_trip_name', trip.name);
      await prefs.setString(
          'widget_total', '${trip.currency} ${trip.totalSpent.toStringAsFixed(2)}');
      await prefs.setString(
          'widget_balances', balanceText);
      await prefs.setString('widget_consumption', consumptionText);
      await prefs.setString('widget_categories', categoryText);
      await prefs.setString('widget_updated', _timestamp());
    }

    await HomeWidget.updateWidget(
      androidName: _androidProvider,
      qualifiedAndroidName: 'com.example.gastos_viaje.TripWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: _donutProvider,
      qualifiedAndroidName: 'com.example.gastos_viaje.DonutWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: _categoryAndroidProvider,
      qualifiedAndroidName: 'com.example.gastos_viaje.CategoryTripWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: _categoryDonutProvider,
      qualifiedAndroidName: 'com.example.gastos_viaje.CategoryDonutWidgetProvider',
    );
  }

  static Future<void> triggerUpdate() async {
    try {
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        qualifiedAndroidName: 'com.example.gastos_viaje.TripWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: _donutProvider,
        qualifiedAndroidName: 'com.example.gastos_viaje.DonutWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: _categoryAndroidProvider,
        qualifiedAndroidName: 'com.example.gastos_viaje.CategoryTripWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: _categoryDonutProvider,
        qualifiedAndroidName: 'com.example.gastos_viaje.CategoryDonutWidgetProvider',
      );
    } catch (_) {}
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
