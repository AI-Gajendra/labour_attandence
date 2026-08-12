import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/money.dart';

/// A closed month for one worker.
///
/// Settlements are what make balances carry forward. Previously the summary
/// recomputed `salary − advances` inside a single calendar month, so a worker
/// who over-drew ₹2,000 in July started August clean and the debt vanished.
///
/// A settlement records the arithmetic **as it stood when the month was paid
/// out**, including the explicit [closing] balance. The next month reads that
/// one number as its [opening]. Nothing has to be re-derived from history —
/// which matters because a worker's daily wage can change over time, so
/// replaying old attendance against today's rate would produce the wrong answer.
///
/// Document id is `{workerId}_{YYYY-MM}`, so writing one is idempotent.
class Settlement {
  final String settlementId;
  final String workerId;
  final String month;

  /// Balance carried in from the previous month (may be negative).
  final int opening;

  /// Earnings for this month at the wage in force when it was settled.
  final int salary;

  /// Kharchi drawn during this month.
  final int advances;

  /// Cash actually handed over / transferred at settlement.
  final int paid;

  /// `opening + salary − advances − paid`. Carried into the next month.
  final int closing;

  /// `cash` | `upi` | `bank`.
  final String mode;
  final String note;
  final String createdBy;
  final DateTime settledAt;

  Settlement({
    required this.settlementId,
    required this.workerId,
    required this.month,
    required this.opening,
    required this.salary,
    required this.advances,
    required this.paid,
    required this.closing,
    required this.mode,
    required this.note,
    required this.createdBy,
    required this.settledAt,
  });

  static const String modeCash = 'cash';
  static const String modeUpi = 'upi';
  static const String modeBank = 'bank';
  static const List<String> modes = [modeCash, modeUpi, modeBank];

  static String idFor(String workerId, String month) => '${workerId}_$month';

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return Settlement(
      settlementId: doc.id,
      workerId: (data['workerId'] as String?) ?? '',
      month: (data['month'] as String?) ?? '',
      opening: asRupees(data['opening']),
      salary: asRupees(data['salary']),
      advances: asRupees(data['advances']),
      paid: asRupees(data['paid']),
      closing: asRupees(data['closing']),
      mode: (data['mode'] as String?) ?? modeCash,
      note: (data['note'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? 'admin_1',
      settledAt: (data['settledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'month': month,
      'opening': opening,
      'salary': salary,
      'advances': advances,
      'paid': paid,
      'closing': closing,
      'mode': mode,
      'note': note,
      'createdBy': createdBy,
      'settledAt': Timestamp.fromDate(settledAt),
    };
  }
}
