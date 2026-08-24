import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/models.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return databaseFactory.openDatabase(
        'gastos_viaje.db',
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'gastos_viaje.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE members ADD COLUMN color_index INTEGER');
      await db.execute('ALTER TABLE expenses ADD COLUMN tip REAL NOT NULL DEFAULT 0.0');
      await db.execute('ALTER TABLE expenses ADD COLUMN expense_currency TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 1.0');
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency TEXT NOT NULL,
        date_label TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        color_index INTEGER,
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        tip REAL NOT NULL DEFAULT 0.0,
        expense_currency TEXT,
        exchange_rate REAL NOT NULL DEFAULT 1.0,
        category TEXT NOT NULL,
        payer_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_splits (
        expense_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        amount REAL NOT NULL,
        PRIMARY KEY (expense_id, member_id),
        FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ── One-time migration from SharedPreferences ─────

  static const _kTripsKey = 'gv_trips_v1';
  static const _kActiveKey = 'gv_active_trip_v1';

  static Future<void> migrateFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTripsKey);
    if (raw == null) return;

    final database = await db;
    final List tripList = jsonDecode(raw);
    for (final tripJson in tripList) {
      final trip = Trip.fromJson(tripJson as Map<String, dynamic>);
      await _insertTripFull(database, trip);
    }

    final activeId = prefs.getString(_kActiveKey);
    if (activeId != null) {
      await database.insert(
        'app_state',
        {'key': 'active_trip', 'value': activeId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await prefs.remove(_kTripsKey);
    await prefs.remove(_kActiveKey);
  }

  // ── Load ──────────────────────────────────────────

  static Future<List<Trip>> loadAllTrips() async {
    final database = await db;
    final tripRows = await database.query('trips');
    final result = <Trip>[];

    for (final row in tripRows) {
      final tripId = row['id'] as String;

      final memberRows = await database.query(
        'members',
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      final allMembers = memberRows
          .map((r) => Member(
                id: r['id'] as String,
                name: r['name'] as String,
                active: (r['active'] as int) == 1,
                colorIndex: r['color_index'] as int?,
              ))
          .toList();

      final expenseRows = await database.query(
        'expenses',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'date ASC',
      );
      final expenses = <Expense>[];
      for (final er in expenseRows) {
        final expId = er['id'] as String;
        final splitRows = await database.query(
          'expense_splits',
          where: 'expense_id = ?',
          whereArgs: [expId],
        );
        final splits = <String, double>{
          for (final sr in splitRows)
            sr['member_id'] as String: sr['amount'] as double,
        };
        expenses.add(Expense(
          id: expId,
          name: er['name'] as String,
          amount: er['amount'] as double,
          tip: (er['tip'] as num?)?.toDouble() ?? 0.0,
          category: er['category'] as String,
          payer: er['payer_id'] as String,
          splits: splits,
          mode: SplitMode.values.firstWhere(
            (m) => m.name == er['mode'],
            orElse: () => SplitMode.equal,
          ),
          date: DateTime.parse(er['date'] as String),
          expenseCurrency: er['expense_currency'] as String?,
          exchangeRate: (er['exchange_rate'] as num?)?.toDouble() ?? 1.0,
        ));
      }

      final paymentRows = await database.query(
        'payments',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'date ASC',
      );
      final payments = paymentRows
          .map((pr) => Payment(
                id: pr['id'] as String,
                from: pr['from_id'] as String,
                to: pr['to_id'] as String,
                amount: pr['amount'] as double,
                date: DateTime.parse(pr['date'] as String),
                note: pr['note'] as String? ?? '',
              ))
          .toList();

      result.add(Trip(
        id: tripId,
        name: row['name'] as String,
        currency: row['currency'] as String,
        dateLabel: row['date_label'] as String,
        allMembers: allMembers,
        expenses: expenses,
        payments: payments,
      ));
    }
    return result;
  }

  // ── Active trip state ─────────────────────────────

  static Future<String?> loadActiveId() async {
    final database = await db;
    final rows = await database.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['active_trip'],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> saveActiveId(String? id) async {
    final database = await db;
    if (id == null) {
      await database.delete('app_state', where: 'key = ?', whereArgs: ['active_trip']);
    } else {
      await database.insert(
        'app_state',
        {'key': 'active_trip', 'value': id},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ── Trips ─────────────────────────────────────────

  static Future<void> insertTrip(Trip trip) async {
    final database = await db;
    await _insertTripFull(database, trip);
  }

  static Future<void> deleteTrip(String tripId) async {
    final database = await db;
    await database.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  static Future<void> deleteAllTrips() async {
    final database = await db;
    await database.delete('trips'); // CASCADE removes members, expenses, payments
    await database.delete('app_state', where: 'key = ?', whereArgs: ['active_trip']);
  }

  // ── Members ───────────────────────────────────────

  static Future<void> upsertMembers(String tripId, List<Member> members) async {
    final database = await db;
    final existing = await database.query(
      'members',
      columns: ['id'],
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
    final existingIds = existing.map((r) => r['id'] as String).toSet();

    for (final m in members) {
      if (existingIds.contains(m.id)) {
        await database.update(
          'members',
          {'name': m.name, 'active': m.active ? 1 : 0, 'color_index': m.colorIndex},
          where: 'id = ?',
          whereArgs: [m.id],
        );
      } else {
        await database.insert('members', {
          'id': m.id,
          'trip_id': tripId,
          'name': m.name,
          'active': m.active ? 1 : 0,
          'color_index': m.colorIndex,
        });
      }
    }
  }

  // ── Expenses ──────────────────────────────────────

  static Future<void> insertExpense(String tripId, Expense e) async {
    final database = await db;
    await database.insert('expenses', {
      'id': e.id,
      'trip_id': tripId,
      'name': e.name,
      'amount': e.amount,
      'tip': e.tip,
      'expense_currency': e.expenseCurrency,
      'exchange_rate': e.exchangeRate,
      'category': e.category,
      'payer_id': e.payer,
      'mode': e.mode.name,
      'date': e.date.toIso8601String(),
    });
    for (final entry in e.splits.entries) {
      await database.insert('expense_splits', {
        'expense_id': e.id,
        'member_id': entry.key,
        'amount': entry.value,
      });
    }
  }

  static Future<void> updateExpense(Expense e) async {
    final database = await db;
    await database.update(
      'expenses',
      {
        'name': e.name,
        'amount': e.amount,
        'tip': e.tip,
        'expense_currency': e.expenseCurrency,
        'exchange_rate': e.exchangeRate,
        'category': e.category,
        'payer_id': e.payer,
        'mode': e.mode.name,
        'date': e.date.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
    await database.delete('expense_splits', where: 'expense_id = ?', whereArgs: [e.id]);
    for (final entry in e.splits.entries) {
      await database.insert('expense_splits', {
        'expense_id': e.id,
        'member_id': entry.key,
        'amount': entry.value,
      });
    }
  }

  static Future<void> deleteExpense(String expenseId) async {
    final database = await db;
    await database.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
    // expense_splits deleted automatically via CASCADE
  }

  // ── Payments ──────────────────────────────────────

  static Future<void> insertPayment(String tripId, Payment pay) async {
    final database = await db;
    await database.insert('payments', {
      'id': pay.id,
      'trip_id': tripId,
      'from_id': pay.from,
      'to_id': pay.to,
      'amount': pay.amount,
      'date': pay.date.toIso8601String(),
      'note': pay.note,
    });
  }

  static Future<void> deletePayment(String paymentId) async {
    final database = await db;
    await database.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  // ── Private helpers ───────────────────────────────

  static Future<void> _insertTripFull(Database database, Trip trip) async {
    await database.insert(
      'trips',
      {
        'id': trip.id,
        'name': trip.name,
        'currency': trip.currency,
        'date_label': trip.dateLabel,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    for (final m in trip.allMembers) {
      await database.insert(
        'members',
        {
          'id': m.id,
          'trip_id': trip.id,
          'name': m.name,
          'active': m.active ? 1 : 0,
          'color_index': m.colorIndex,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final e in trip.expenses) {
      await database.insert(
        'expenses',
        {
          'id': e.id,
          'trip_id': trip.id,
          'name': e.name,
          'amount': e.amount,
          'tip': e.tip,
          'expense_currency': e.expenseCurrency,
          'exchange_rate': e.exchangeRate,
          'category': e.category,
          'payer_id': e.payer,
          'mode': e.mode.name,
          'date': e.date.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final entry in e.splits.entries) {
        await database.insert(
          'expense_splits',
          {
            'expense_id': e.id,
            'member_id': entry.key,
            'amount': entry.value,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    for (final pay in trip.payments) {
      await database.insert(
        'payments',
        {
          'id': pay.id,
          'trip_id': trip.id,
          'from_id': pay.from,
          'to_id': pay.to,
          'amount': pay.amount,
          'date': pay.date.toIso8601String(),
          'note': pay.note,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
