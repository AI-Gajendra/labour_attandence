import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String attendanceId;
  final String workerId;
  final String date;
  final String month;
  final String status;
  final String createdBy;

  Attendance({
    required this.attendanceId,
    required this.workerId,
    required this.date,
    required this.month,
    required this.status,
    required this.createdBy,
  });

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Attendance(
      attendanceId: doc.id,
      workerId: data['workerId'] ?? '',
      date: data['date'] ?? '',
      month: data['month'] ?? '',
      status: data['status'] ?? 'absent',
      createdBy: data['createdBy'] ?? 'admin_1',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'date': date,
      'month': month,
      'status': status,
      'createdBy': createdBy,
    };
  }
}
