import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical attendance statuses.
///
/// `absent` is deliberately kept as a *marked* state distinct from "not marked
/// at all" — an unmarked day is silence, an absent day is a decision.
class AttendanceStatus {
  AttendanceStatus._();

  static const String present = 'present';
  static const String halfDay = 'half_day';
  static const String absent = 'absent';

  static const List<String> all = [present, halfDay, absent];

  /// Fraction of a day's wage this status earns. See CLAUDE.md §6.
  static double dayValue(String? status) {
    switch (status) {
      case present:
        return 1.0;
      case halfDay:
        return 0.5;
      default:
        return 0.0;
    }
  }
}

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

  /// Fraction of a day this record earns.
  double get dayValue => AttendanceStatus.dayValue(status);

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return Attendance(
      attendanceId: doc.id,
      workerId: (data['workerId'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      month: (data['month'] as String?) ?? '',
      status: (data['status'] as String?) ?? AttendanceStatus.absent,
      createdBy: (data['createdBy'] as String?) ?? 'admin_1',
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
