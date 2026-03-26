
import 'package:intl/intl.dart';

class AttendanceOutModel {
  dynamic attendance_out_id;
  String? emp_id;

  dynamic total_time;
  dynamic lat_out;
  dynamic lng_out;
  dynamic total_distance;
  dynamic address;

  dynamic attendance_out_date;
  dynamic attendance_out_time;

  int posted;
  String? reason;

  AttendanceOutModel({
    this.attendance_out_id,
    this.emp_id,
    this.total_time,
    this.lat_out,
    this.lng_out,
    this.total_distance,
    this.attendance_out_date,
    this.attendance_out_time,
    this.address,
    this.posted = 0,
    this.reason,
  });

  factory AttendanceOutModel.fromMap(Map<dynamic, dynamic> json) {
    return AttendanceOutModel(
      attendance_out_id: json['attendance_out_id'],
      emp_id: json['emp_id'],
      total_time: json['total_time'],
      lat_out: json['lat_out'],
      lng_out: json['lng_out'],
      total_distance: json['total_distance'],
      attendance_out_date: json['attendance_out_date'],
      attendance_out_time: json['attendance_out_time'],
      address: json['address'],
      posted: json['posted'] ?? 0,
      reason: json['reason'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {

    String dateString;
    if (attendance_out_date is DateTime) {
      dateString =
          DateFormat('dd-MMM-yyyy').format(attendance_out_date as DateTime);
    } else if (attendance_out_date is String &&
        (attendance_out_date as String).isNotEmpty) {
      // Re-parse ISO 8601 strings (e.g. from backup/fast-data restore)
      // and reformat to Oracle-expected format. If already formatted
      // (e.g. "11-Mar-2026"), DateTime.parse throws and we keep it as-is.
      try {
        final parsed = DateTime.parse(attendance_out_date as String);
        dateString = DateFormat('dd-MMM-yyyy').format(parsed);
      } catch (_) {
        dateString = attendance_out_date as String;
      }
    } else {
      assert(false,
      '⚠️ [MODEL] attendance_out_date is null/empty — check where model is created');
      dateString = '';
    }

    String timeString;
    if (attendance_out_time is DateTime) {
      timeString =
          DateFormat('HH:mm:ss').format(attendance_out_time as DateTime);
    } else if (attendance_out_time is String &&
        (attendance_out_time as String).isNotEmpty) {
      // Re-parse ISO 8601 strings (e.g. "2026-03-11T14:32:00.000")
      // and reformat to HH:mm:ss. If already formatted, keep as-is.
      try {
        final parsed = DateTime.parse(attendance_out_time as String);
        timeString = DateFormat('HH:mm:ss').format(parsed);
      } catch (_) {
        timeString = attendance_out_time as String;
      }
    } else {
      assert(false,
      '⚠️ [MODEL] attendance_out_time is null/empty — check where model is created');
      timeString = '';
    }

    return {
      'attendance_out_id': attendance_out_id,
      'emp_id': emp_id,
      'total_time': total_time,
      'lat_out': lat_out,
      'lng_out': lng_out,
      'total_distance': total_distance,
      'attendance_out_date': dateString,
      'attendance_out_time': timeString,
      'address': address,
      'posted': posted,
      'reason': reason ?? 'manual',
    };
  }
}