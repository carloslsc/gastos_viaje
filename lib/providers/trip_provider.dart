import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';

const _uuid = Uuid();

class TripProvider extends ChangeNotifier {
  List<Trip> _trips = [];
  String? _activeTripId;
  bool _loaded = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  Trip? get activeTrip => _activeTripId == null
      ? null
      : _trips.firstWhere((t) => t.id == _activeTripId, orElse: () => _trips.first);
  bool get hasActive => _activeTripId != null && _trips.any((t) => t.id == _activeTripId);
  bool get loaded => _loaded;

  // ── Init ─────────────────────────────────────────
  Future<void> load() async {
    await DatabaseService.migrateFromSharedPrefs();
    _trips = await DatabaseService.loadAllTrips();
    _activeTripId = await DatabaseService.loadActiveId();
    if (_activeTripId != null && !_trips.any((t) => t.id == _activeTripId)) {
      _activeTripId = _trips.isNotEmpty ? _trips.first.id : null;
      await DatabaseService.saveActiveId(_activeTripId);
    }
    _loaded = true;
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  // ── Trips CRUD ────────────────────────────────────
  Future<Trip> createTrip({
    required String name,
    required String currency,
    required String dateLabel,
    required List<String> members,
  }) async {
    final memberObjs = members.asMap().entries.map((e) => Member(
      id: _uuid.v4(),
      name: e.value,
      colorIndex: AppTheme.memberColorOrder[e.key % AppTheme.memberColorOrder.length],
    )).toList();
    final trip = Trip(
      id: _uuid.v4(),
      name: name,
      currency: currency,
      dateLabel: dateLabel,
      allMembers: memberObjs,
      expenses: [],
    );
    _trips.add(trip);
    _activeTripId = trip.id;
    await DatabaseService.insertTrip(trip);
    await DatabaseService.saveActiveId(_activeTripId);
    notifyListeners();
    WidgetService.update(activeTrip);
    return trip;
  }

  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((t) => t.id == id);
    if (_activeTripId == id) {
      _activeTripId = _trips.isNotEmpty ? _trips.last.id : null;
    }
    await DatabaseService.deleteTrip(id);
    await DatabaseService.saveActiveId(_activeTripId);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  void setActiveTrip(String id) {
    _activeTripId = id;
    DatabaseService.saveActiveId(id);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  // ── Expenses CRUD ─────────────────────────────────
  Future<void> addExpense(Expense expense) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(expenses: [..._trips[idx].expenses, expense]);
    await DatabaseService.insertExpense(_activeTripId!, expense);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Future<void> deleteExpense(String expenseId) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(
      expenses: _trips[idx].expenses.where((e) => e.id != expenseId).toList(),
    );
    await DatabaseService.deleteExpense(expenseId);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Future<void> updateExpense(Expense updated) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(
      expenses: _trips[idx].expenses.map((e) => e.id == updated.id ? updated : e).toList(),
    );
    await DatabaseService.updateExpense(updated);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Future<void> setTripMembers(List<Member> members) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(allMembers: List.unmodifiable(members));
    await DatabaseService.upsertMembers(_activeTripId!, members);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Future<void> renameMember(String memberId, String newName) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    final updated = _trips[idx].allMembers
        .map((m) => m.id == memberId ? m.copyWith(name: newName) : m)
        .toList();
    _trips[idx] = _trips[idx].copyWith(allMembers: updated);
    await DatabaseService.upsertMembers(_activeTripId!, updated);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  // ── Payments CRUD ─────────────────────────────────
  Future<void> addPayment(Payment payment) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(payments: [..._trips[idx].payments, payment]);
    await DatabaseService.insertPayment(_activeTripId!, payment);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Future<void> deletePayment(String paymentId) async {
    final idx = _activeIdx;
    if (idx == -1) return;
    _trips[idx] = _trips[idx].copyWith(
      payments: _trips[idx].payments.where((p) => p.id != paymentId).toList(),
    );
    await DatabaseService.deletePayment(paymentId);
    notifyListeners();
    WidgetService.update(activeTrip);
  }

  Payment buildPayment({
    required String from,
    required String to,
    required double amount,
    String note = '',
    DateTime? date,
  }) => Payment(
    id: _uuid.v4(),
    from: from,
    to: to,
    amount: amount,
    note: note,
    date: date ?? DateTime.now(),
  );

  Expense buildExpense({
    required String name,
    required double amount,
    double tip = 0.0,
    required String category,
    required String payer,
    required Map<String, double> splits,
    required SplitMode mode,
    DateTime? date,
    String? expenseCurrency,
    double exchangeRate = 1.0,
  }) => Expense(
    id: _uuid.v4(),
    name: name,
    amount: amount,
    tip: tip,
    category: category,
    payer: payer,
    splits: splits,
    mode: mode,
    date: date ?? DateTime.now(),
    expenseCurrency: expenseCurrency,
    exchangeRate: exchangeRate,
  );

  int get _activeIdx => _trips.indexWhere((t) => t.id == _activeTripId);
}
