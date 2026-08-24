import 'dart:convert';

// ── Member ────────────────────────────────────────────
class Member {
  final String id;
  final String name;
  final bool active;
  final int? colorIndex; // null = auto-assign by position in palette

  const Member({required this.id, required this.name, this.active = true, this.colorIndex});

  Member copyWith({String? id, String? name, bool? active, int? colorIndex, bool clearColor = false}) => Member(
    id: id ?? this.id,
    name: name ?? this.name,
    active: active ?? this.active,
    colorIndex: clearColor ? null : (colorIndex ?? this.colorIndex),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'active': active,
    if (colorIndex != null) 'colorIndex': colorIndex,
  };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'] as String,
    name: j['name'] as String,
    active: j['active'] as bool? ?? true,
    colorIndex: j['colorIndex'] as int?,
  );
}

// ── Split mode ────────────────────────────────────────
enum SplitMode { equal, own, custom, percentage }

extension SplitModeLabel on SplitMode {
  String get label => switch (this) {
    SplitMode.equal => 'Dividir',
    SplitMode.own => 'Propio',
    SplitMode.custom => 'Custom',
    SplitMode.percentage => 'Porcentaje',
  };
  String get description => switch (this) {
    SplitMode.equal => 'Una persona pagó todo, se divide entre todos por igual',
    SplitMode.own => 'El pagador lo asume solo, sin generar deuda',
    SplitMode.custom => 'Cada quien paga un monto diferente',
    SplitMode.percentage => 'Cada quien paga un porcentaje del total',
  };
}

// ── Expense ───────────────────────────────────────────
class Expense {
  final String id;
  final String name;
  final double amount;
  final double tip;
  final String category;
  final String payer;           // member ID
  final Map<String, double> splits; // member ID → share
  final SplitMode mode;
  final DateTime date;
  final String? expenseCurrency; // null = same as trip currency
  final double exchangeRate;     // trip units per 1 foreign unit; 1.0 if same currency

  const Expense({
    required this.id,
    required this.name,
    required this.amount,
    this.tip = 0.0,
    required this.category,
    required this.payer,
    required this.splits,
    required this.mode,
    required this.date,
    this.expenseCurrency,
    this.exchangeRate = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'tip': tip,
    'category': category,
    'payer': payer,
    'splits': splits,
    'mode': mode.name,
    'date': date.toIso8601String(),
    if (expenseCurrency != null) 'expenseCurrency': expenseCurrency,
    if (exchangeRate != 1.0) 'exchangeRate': exchangeRate,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    name: j['name'],
    amount: (j['amount'] as num).toDouble(),
    tip: (j['tip'] as num?)?.toDouble() ?? 0.0,
    category: j['category'],
    payer: j['payer'],
    splits: Map<String, double>.from(
      (j['splits'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
    ),
    mode: SplitMode.values.firstWhere(
      (e) => e.name == j['mode'],
      orElse: () => SplitMode.equal,
    ),
    date: DateTime.parse(j['date']),
    expenseCurrency: j['expenseCurrency'] as String?,
    exchangeRate: (j['exchangeRate'] as num?)?.toDouble() ?? 1.0,
  );
}

// ── Payment ───────────────────────────────────────────
// Records a direct money transfer from one person to another to settle debts.
class Payment {
  final String id;
  final String from;   // member ID who pays
  final String to;     // member ID who receives
  final double amount;
  final DateTime date;
  final String note;

  const Payment({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'],
    from: j['from'],
    to: j['to'],
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    note: j['note'] as String? ?? '',
  );
}

// ── Trip ─────────────────────────────────────────────
class Trip {
  final String id;
  final String name;
  final String currency;
  final String dateLabel;
  final List<Member> allMembers;
  final List<Expense> expenses;
  final List<Payment> payments;

  const Trip({
    required this.id,
    required this.name,
    required this.currency,
    required this.dateLabel,
    required this.allMembers,
    required this.expenses,
    this.payments = const [],
  });

  List<Member> get members => allMembers.where((m) => m.active).toList();

  String memberName(String memberId) {
    try {
      return allMembers.firstWhere((m) => m.id == memberId).name;
    } catch (_) {
      return memberId;
    }
  }

  Trip copyWith({
    String? name,
    String? currency,
    String? dateLabel,
    List<Member>? allMembers,
    List<Expense>? expenses,
    List<Payment>? payments,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    dateLabel: dateLabel ?? this.dateLabel,
    allMembers: allMembers ?? this.allMembers,
    expenses: expenses ?? this.expenses,
    payments: payments ?? this.payments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currency': currency,
    'dateLabel': dateLabel,
    'members': allMembers.map((m) => m.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> j) {
    final rawMembers = j['members'] as List;
    final allMembers = rawMembers.isEmpty || rawMembers.first is String
        ? rawMembers.map((s) { final n = s as String; return Member(id: n, name: n); }).toList()
        : rawMembers.map((m) => Member.fromJson(m as Map<String, dynamic>)).toList();

    return Trip(
      id: j['id'],
      name: j['name'],
      currency: j['currency'],
      dateLabel: j['dateLabel'] ?? '',
      allMembers: allMembers,
      expenses: (j['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: (j['payments'] as List? ?? [])
          .map((p) => Payment.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Computed balances ─────────────────────────────
  // Positive = person is owed money. Negative = person owes money.
  // Includes expense splits AND direct payments.
  Map<String, double> get balances {
    final map = <String, double>{for (final m in members) m.id: 0.0};
    for (final e in expenses) {
      map[e.payer] = (map[e.payer] ?? 0) + e.amount;
      for (final entry in e.splits.entries) {
        if (entry.value > 0) {
          map[entry.key] = (map[entry.key] ?? 0) - entry.value;
        }
      }
    }
    // Payments: payer's balance increases (they paid off debt), receiver's decreases
    for (final p in payments) {
      map[p.from] = (map[p.from] ?? 0) + p.amount;
      map[p.to] = (map[p.to] ?? 0) - p.amount;
    }
    return map;
  }

  List<Member> get allParticipants {
    final participantIds = <String>{};
    for (final e in expenses) {
      participantIds.add(e.payer);
      for (final entry in e.splits.entries) {
        if (entry.value > 0) participantIds.add(entry.key);
      }
    }
    for (final p in payments) {
      participantIds.add(p.from);
      participantIds.add(p.to);
    }
    return allMembers
        .where((m) => m.active || participantIds.contains(m.id))
        .toList();
  }

  double get totalSpent => expenses.fold(0.0, (s, e) => s + e.amount);
  double get perPersonShare =>
      members.isEmpty ? 0 : totalSpent / members.length;

  List<Transfer> get transfers {
    final bal = Map<String, double>.from(balances);
    final debtors = bal.entries
        .where((e) => e.value < -0.005)
        .map((e) => _Mutable(e.key, e.value.abs()))
        .toList();
    final creditors = bal.entries
        .where((e) => e.value > 0.005)
        .map((e) => _Mutable(e.key, e.value))
        .toList();
    final result = <Transfer>[];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final amt = debtors[i].value < creditors[j].value
          ? debtors[i].value
          : creditors[j].value;
      if (amt > 0.005) {
        result.add(Transfer(from: debtors[i].name, to: creditors[j].name, amount: amt));
      }
      debtors[i].value -= amt;
      creditors[j].value -= amt;
      if (debtors[i].value < 0.005) i++;
      if (creditors[j].value < 0.005) j++;
    }
    return result;
  }

  String toJsonString() => jsonEncode(toJson());
  factory Trip.fromJsonString(String s) => Trip.fromJson(jsonDecode(s));
}

class _Mutable {
  String name;
  double value;
  _Mutable(this.name, this.value);
}

class Transfer {
  final String from; // member ID
  final String to;   // member ID
  final double amount;
  const Transfer({required this.from, required this.to, required this.amount});
}
