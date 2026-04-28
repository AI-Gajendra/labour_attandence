import 'package:cloud_firestore/cloud_firestore.dart';

class Advance {
  final String advanceId;
  final String workerId;
  final double amount;
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
    Map data = doc.data() as Map<String, dynamic>;
    return Advance(
      advanceId: doc.id,
      workerId: data['workerId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: data['date'] ?? '',
      month: data['month'] ?? '',
      createdBy: data['createdBy'] ?? 'admin_1',
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
