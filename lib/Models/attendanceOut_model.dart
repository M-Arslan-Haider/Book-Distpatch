
import 'package:intl/intl.dart';

class AttendanceOutModel {
  dynamic attendance_out_id;
  String? emp_id;

  dynamic total_time;
  dynamic lat_out;
  dynamic lng_out;
  dynamic total_distance;
  dynamic address;
  String? company_code; // ✅ ADDED

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
    this.company_code, // ✅ ADDED
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
      company_code: json['company_code'], // ✅ ADDED
      posted: json['posted'] ?? 0,
      reason: json['reason'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    String dateString;
    if (attendance_out_date is DateTime) {
      dateString = DateFormat('dd-MMM-yyyy').format(attendance_out_date as DateTime);
    } else if (attendance_out_date is String && (attendance_out_date as String).isNotEmpty) {
      try {
        final parsed = DateTime.parse(attendance_out_date as String);
        dateString = DateFormat('dd-MMM-yyyy').format(parsed);
      } catch (_) {
        dateString = attendance_out_date as String;
      }
    } else {
      dateString = '';
    }

    String timeString;
    if (attendance_out_time is DateTime) {
      timeString = DateFormat('HH:mm:ss').format(attendance_out_time as DateTime);
    } else if (attendance_out_time is String && (attendance_out_time as String).isNotEmpty) {
      try {
        final parsed = DateTime.parse(attendance_out_time as String);
        timeString = DateFormat('HH:mm:ss').format(parsed);
      } catch (_) {
        timeString = attendance_out_time as String;
      }
    } else {
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
      'company_code': company_code, // ✅ ADDED - this was missing!
      'posted': posted,
      'reason': reason ?? 'manual',
    };
  }
}