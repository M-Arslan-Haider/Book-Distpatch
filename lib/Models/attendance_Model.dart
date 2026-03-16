import 'package:intl/intl.dart';

class AttendanceModel {
  dynamic attendance_in_id;
  String? emp_id;
  dynamic emp_name;
  dynamic job;
  dynamic lat_in;
  dynamic lng_in;
  dynamic city;
  dynamic address;

  dynamic attendance_in_date;
  dynamic attendance_in_time;
  String? profile;

  int posted;

  AttendanceModel({
    this.attendance_in_id,
    this.emp_id,
    this.emp_name,
    this.job,
    this.lat_in,
    this.lng_in,
    this.city,
    this.address,
    this.attendance_in_date,
    this.attendance_in_time,
    this.profile,
    this.posted = 0,
  });

  factory AttendanceModel.fromMap(Map<dynamic, dynamic> json) {
    return AttendanceModel(
      attendance_in_id: json['attendance_in_id'],
      emp_id: json['emp_id'],
      emp_name: json['emp_name'],
      job: json['job'],
      lat_in: json['lat_in'],
      lng_in: json['lng_in'],
      city: json['city'],
      address: json['address'],
      attendance_in_date: json['attendance_in_date'],
      attendance_in_time: json['attendance_in_time'],
      profile: json['profile'],
      posted: json['posted'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {

    String dateString;
    if (attendance_in_date is DateTime) {
      dateString = DateFormat('dd-MMM-yyyy').format(attendance_in_date);
    } else if (attendance_in_date is String) {
      dateString = attendance_in_date;
    } else {
      dateString = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    }

    String timeString;
    if (attendance_in_time is DateTime) {
      timeString = DateFormat('HH:mm:ss').format(attendance_in_time);
    } else if (attendance_in_time is String) {
      timeString = attendance_in_time;
    } else {
      timeString = DateFormat('HH:mm:ss').format(DateTime.now());
    }

    return {
      'attendance_in_id': attendance_in_id,
      'emp_id': emp_id,
      'emp_name': emp_name,
      'job': job,
      'lat_in': lat_in,
      'lng_in': lng_in,
      'city': city,
      'address': address,
      'attendance_in_date': dateString,
      'attendance_in_time': timeString,
      'profile' : profile,
      'posted': posted,
    };
  }
}