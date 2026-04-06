

import 'dart:typed_data';
import 'package:intl/intl.dart';

class LocationModel {
  static const String tableName = 'location';

  // Column names
  static const String colId          = 'location_id';
  static const String colDate        = 'location_date';
  static const String colTime        = 'location_time';
  static const String colFileName    = 'file_name';
  static const String colEmpId       = 'emp_id';
  static const String colDistance    = 'total_distance';
  static const String colEmpName     = 'emp_name';
  static const String colPosted      = 'posted';
  static const String colBody        = 'body';
  static const String colCompanyCode = 'company_code'; // ← ADDED

  final String locationId;
  final String locationDate;
  final String locationTime;
  final String fileName;
  final String empId;
  final String totalDistance;
  final String empName;
  int posted;
  final Uint8List? body;
  final String? company_code; // ← ADDED

  LocationModel({
    required this.locationId,
    required this.locationDate,
    required this.locationTime,
    required this.fileName,
    required this.empId,
    required this.totalDistance,
    required this.empName,
    this.posted = 0,
    this.body,
    this.company_code, // ← ADDED
  });

  Map<String, dynamic> toMap() {
    return {
      colId: locationId,
      colDate: locationDate,
      colTime: locationTime,
      colFileName: fileName,
      colEmpId: empId,
      colDistance: totalDistance,
      colEmpName: empName,
      colPosted: posted,
      colBody: body,
      colCompanyCode: company_code, // ← ADDED
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      locationId: map[colId] ?? '',
      locationDate: map[colDate] ?? '',
      locationTime: map[colTime] ?? '',
      fileName: map[colFileName] ?? '',
      empId: map[colEmpId] ?? '',
      totalDistance: map[colDistance] ?? '0',
      empName: map[colEmpName] ?? '',
      posted: map[colPosted] ?? 0,
      body: map[colBody] is Uint8List
          ? map[colBody] as Uint8List?
          : map[colBody] != null
          ? Uint8List.fromList(List<int>.from(map[colBody]))
          : null,
      company_code: map[colCompanyCode], // ← ADDED
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'location_id': locationId,
      'location_date': locationDate,
      'location_time': locationTime,
      'file_name': fileName,
      'emp_id': empId,
      'total_distance': totalDistance,
      'emp_name': empName,
      'company_code': company_code ?? '', // ← ADDED
      'COMPANY_CODE': company_code ?? '', // ← ADDED (both cases for API)
    };
  }
}