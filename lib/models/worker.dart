import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/money.dart';

/// A daily wage and the date it took effect.
///
/// Stored newest-first on the worker document. [from] is an inclusive
/// `YYYY-MM-DD` key: the rate applies to that day and every day after it, until
/// a newer entry takes over.
class WageRate {
  final String from;
  final int wage;

  const WageRate({required this.from, required this.wage});

  /// Sentinel for "since the beginning of time". Sorts before any real date key.
  static const String beginning = '0000-01-01';

  factory WageRate.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    return WageRate(
      from: (map['from'] as String?) ?? beginning,
      wage: asRupees(map['wage']),
    );
  }

  Map<String, dynamic> toMap() => {'from': from, 'wage': wage};
}

class Worker {
  final String workerId;
  final String name;
  final String type;

  /// The **current** rate, in whole rupees per full day. Used for display, for
  /// pricing new work, and as the fallback for workers whose rate has never
  /// changed. See [wageOn] for what historical days are worth.
  final int dailyWage;
  final String createdBy;
  final DateTime createdAt;

  /// Soft-delete flag. Removed workers stay in the database so historical
  /// payroll keeps resolving their name — a worker who left in March must
  /// still appear in March's report.
  final bool isActive;

  /// Rate changes, newest first.
  ///
  /// Empty for a worker whose rate has never been changed. The moment one *is*
  /// changed, a baseline entry at [WageRate.beginning] carrying the old rate is
  /// written alongside the new one, so every past day still prices at the rate
  /// that was actually agreed then.
  final List<WageRate> wageHistory;

  Worker({
    required this.workerId,
    required this.name,
    required this.type,
    required this.dailyWage,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
    this.wageHistory = const [],
  });

  /// The rate that applied on [dateKey] (`YYYY-MM-DD`).
  ///
  /// Without this, raising someone's rate re-priced **every past month they had
  /// not been paid for** — put Jagdish up from ₹600 to ₹650 in August and his
  /// July earnings silently became ₹650/day too. Historical earnings are a
  /// record of what was agreed, and must not move because of a decision taken
  /// later.
  int wageOn(String dateKey) {
    for (final rate in wageHistory) {
      if (dateKey.compareTo(rate.from) >= 0) return rate.wage;
    }
    // No history at all: the rate has never changed, so it has always been this.
    return dailyWage;
  }

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

    final history =
        (data['wageHistory'] as List?)?.map(WageRate.fromMap).toList() ??
        <WageRate>[];
    // Newest first, so wageOn can return the first match.
    history.sort((a, b) => b.from.compareTo(a.from));

    return Worker(
      workerId: doc.id,
      name: (data['name'] as String?) ?? '',
      type: (data['type'] as String?) ?? '',
      dailyWage: asRupees(data['dailyWage']),
      createdBy: (data['createdBy'] as String?) ?? 'admin_1',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Documents written before soft delete existed have no flag; treat the
      // absence as active.
      isActive: data['isActive'] != false,
      wageHistory: history,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'dailyWage': dailyWage,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'wageHistory': wageHistory.map((r) => r.toMap()).toList(),
    };
  }

  /// Fields an edit is allowed to touch — deliberately excludes provenance.
  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    'type': type,
    'dailyWage': dailyWage,
  };
}
