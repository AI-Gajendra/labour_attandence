import 'package:cloud_firestore/cloud_firestore.dart';

class Worker {
  final String workerId;
  final String name;
  final String type;
  final double dailyWage;
  final String createdBy;
  final DateTime createdAt;

  Worker({
    required this.workerId,
    required this.name,
    required this.type,
    required this.dailyWage,
    required this.createdBy,
    required this.createdAt,
  });

  factory Worker.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Worker(
      workerId: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      dailyWage: (data['dailyWage'] ?? 0).toDouble(),
      createdBy: data['createdBy'] ?? 'admin_1',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'dailyWage': dailyWage,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
