// lib/Models/location_model.dart

import 'dart:typed_data';

class LocationModel {
  final String locationId;
  final String locationDate;
  final String locationTime;
  final String fileName;
  final String empId;
  final String totalDistance;
  final String empName;
  final int posted;
  final Uint8List? body; // GPX file bytes (BLOB)

  const LocationModel({
    required this.locationId,
    required this.locationDate,
    required this.locationTime,
    required this.fileName,
    required this.empId,
    required this.totalDistance,
    required this.empName,
    required this.posted,
    this.body,
  });

  // ── DB column names match your CREATE TABLE exactly ──────────────────────
  static const String tableName    = 'location_table';
  static const String colId        = 'location_id';
  static const String colDate      = 'location_date';
  static const String colTime      = 'location_time';
  static const String colFileName  = 'file_name';
  static const String colEmpId     = 'emp_id';
  static const String colDistance  = 'total_distance';
  static const String colEmpName   = 'emp_name';
  static const String colPosted    = 'posted';
  static const String colBody      = 'body';

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      locationId    : map[colId]       as String? ?? '',
      locationDate  : map[colDate]     as String? ?? '',
      locationTime  : map[colTime]     as String? ?? '',
      fileName      : map[colFileName] as String? ?? '',
      empId         : map[colEmpId]    as String? ?? '',
      totalDistance : map[colDistance] as String? ?? '0.000',
      empName       : map[colEmpName]  as String? ?? '',
      posted        : map[colPosted]   as int?    ?? 0,
      body          : map[colBody]     != null
          ? Uint8List.fromList(map[colBody] as List<int>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      colId       : locationId,
      colDate     : locationDate,
      colTime     : locationTime,
      colFileName : fileName,
      colEmpId    : empId,
      colDistance : totalDistance,
      colEmpName  : empName,
      colPosted   : posted,
      colBody     : body,
    };
  }

  /// JSON map for the REST API — body sent as base64 in a multipart or raw
  /// JSON field (adjust if your API expects multipart/form-data).
  Map<String, dynamic> toApiJson() {
    return {
      'location_id'    : locationId,
      'location_date'  : locationDate,
      'location_time'  : locationTime,
      'file_name'      : fileName,
      'emp_id'         : empId,
      'total_distance' : totalDistance,
      'emp_name'       : empName,
    };
  }

  LocationModel copyWith({int? posted}) {
    return LocationModel(
      locationId    : locationId,
      locationDate  : locationDate,
      locationTime  : locationTime,
      fileName      : fileName,
      empId         : empId,
      totalDistance : totalDistance,
      empName       : empName,
      posted        : posted ?? this.posted,
      body          : body,
    );
  }

  @override
  String toString() =>
      'LocationModel(id=$locationId, emp=$empId, dist=$totalDistance km, posted=$posted)';
}