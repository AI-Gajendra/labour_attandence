import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/money.dart';

class Advance {
  final String advanceId;
  final String workerId;

  /// Whole rupees.
  final int amount;
  final String date;
  final String month;
  final String createdBy;

  Advance({
    required this.advanceId,
    required this.workerId,
    required this.amount,
    required this.date,
    required this.month,
    required this.createdBy,
  });

  factory Advance.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return Advance(
      advanceId: doc.id,
      workerId: (data['workerId'] as String?) ?? '',
      amount: asRupees(data['amount']),
      date: (data['date'] as String?) ?? '',
      month: (data['month'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? 'admin_1',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'amount': amount,
      'date': date,
      'month': month,
      'createdBy': createdBy,
    };
  }
}
