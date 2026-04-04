// // lib/Models/geofence_violation_model.dart
//
// import 'dart:convert';
//
// class GeofenceViolation {
//   // ── Dart field names = Oracle column names (lowercase) ────────────────────
//   final String    violation_id;
//   final String    emp_id;
//   final String    emp_name;
//   final String    event_type;          // "out" / "in"
//   final String    location_name;
//   final String    violation_date;      // yyyy-MM-dd
//   final DateTime  out_time;
//   final DateTime? in_time;
//
//   const GeofenceViolation({
//     required this.violation_id,
//     required this.emp_id,
//     required this.emp_name,
//     required this.event_type,
//     required this.location_name,
//     required this.violation_date,
//     required this.out_time,
//     this.in_time,
//   });
//
//   // ── Computed ──────────────────────────────────────────────────────────────
//
//   bool get isStillOutside => in_time == null;
//
//   Duration get outsideDuration {
//     final end = in_time ?? DateTime.now();
//     return end.difference(out_time);
//   }
//
//   String get total_out_duration {
//     final d = outsideDuration;
//     if (d.inHours > 0)   return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
//     if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
//     return '${d.inSeconds}s';
//   }
//
//   String get outTimeLabel => fmt(out_time);
//   String get inTimeLabel  => in_time != null ? fmt(in_time!) : '—';
//   String get durationLabel => total_out_duration;
//
//   static String fmt(DateTime dt) =>
//       '${dt.hour.toString().padLeft(2, '0')}:'
//           '${dt.minute.toString().padLeft(2, '0')}:'
//           '${dt.second.toString().padLeft(2, '0')}';
//
//   // ── API payload — keys match Oracle columns exactly ───────────────────────
//   Map<String, dynamic> toJson() => {
//     'violation_id'       : violation_id,
//     'emp_id'             : emp_id,
//     'emp_name'           : emp_name,
//     'event_type'         : event_type,
//     'location_name'      : location_name,
//     'violation_date'     : violation_date,
//     'out_time'           : outTimeLabel,
//     'in_time'            : in_time != null ? inTimeLabel : '',
//     'total_out_duration' : in_time != null ? total_out_duration : '',
//   };
//
//   // ── SharedPreferences storage (ISO strings for DateTime) ─────────────────
//   Map<String, dynamic> toStorageJson() => {
//     'violation_id'    : violation_id,
//     'emp_id'          : emp_id,
//     'emp_name'        : emp_name,
//     'event_type'      : event_type,
//     'location_name'   : location_name,
//     'violation_date'  : violation_date,
//     'out_time_iso'    : out_time.toIso8601String(),
//     'in_time_iso'     : in_time?.toIso8601String(),
//   };
//
//   factory GeofenceViolation.fromStorageJson(Map<String, dynamic> j) {
//     return GeofenceViolation(
//       violation_id   : j['violation_id']   as String,
//       emp_id         : j['emp_id']         as String,
//       emp_name       : (j['emp_name']      as String?) ?? '',
//       event_type     : (j['event_type']    as String?) ?? 'out',
//       location_name  : j['location_name']  as String,
//       violation_date : j['violation_date'] as String,
//       out_time       : DateTime.parse(j['out_time_iso'] as String),
//       in_time        : j['in_time_iso'] != null
//           ? DateTime.parse(j['in_time_iso'] as String)
//           : null,
//     );
//   }
//
//   GeofenceViolation copyWith({DateTime? in_time, String? event_type}) =>
//       GeofenceViolation(
//         violation_id   : violation_id,
//         emp_id         : emp_id,
//         emp_name       : emp_name,
//         event_type     : event_type ?? this.event_type,
//         location_name  : location_name,
//         violation_date : violation_date,
//         out_time       : out_time,
//         in_time        : in_time ?? this.in_time,
//       );
//
//   // ── List encode / decode for SharedPreferences ────────────────────────────
//   static String encodeList(List<GeofenceViolation> list) =>
//       jsonEncode(list.map((v) => v.toStorageJson()).toList());
//
//   static List<GeofenceViolation> decodeList(String raw) {
//     try {
//       final arr = jsonDecode(raw) as List<dynamic>;
//       return arr
//           .map((e) => GeofenceViolation.fromStorageJson(
//           e as Map<String, dynamic>))
//           .toList();
//     } catch (_) {
//       return [];
//     }
//   }
// }

// lib/Models/geofence_violation_model.dart

import 'dart:convert';

class GeofenceViolation {
  // ── Dart field names = Oracle column names (lowercase) ────────────────────
  final String    violation_id;
  final String    emp_id;
  final String    emp_name;
  final String    event_type;          // "out" / "in"
  final String    location_name;
  final String    violation_date;      // yyyy-MM-dd
  final DateTime  out_time;
  final DateTime? in_time;
  final String    company_code;        // ← NEW

  const GeofenceViolation({
    required this.violation_id,
    required this.emp_id,
    required this.emp_name,
    required this.event_type,
    required this.location_name,
    required this.violation_date,
    required this.out_time,
    required this.company_code,        // ← NEW
    this.in_time,
  });

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get isStillOutside => in_time == null;

  Duration get outsideDuration {
    final end = in_time ?? DateTime.now();
    return end.difference(out_time);
  }

  String get total_out_duration {
    final d = outsideDuration;
    if (d.inHours > 0)   return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  String get outTimeLabel => fmt(out_time);
  String get inTimeLabel  => in_time != null ? fmt(in_time!) : '—';
  String get durationLabel => total_out_duration;

  static String fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';

  // ── API payload — keys match Oracle columns exactly ───────────────────────
  Map<String, dynamic> toJson() => {
    'violation_id'       : violation_id,
    'emp_id'             : emp_id,
    'emp_name'           : emp_name,
    'event_type'         : event_type,
    'location_name'      : location_name,
    'violation_date'     : violation_date,
    'out_time'           : outTimeLabel,
    'in_time'            : in_time != null ? inTimeLabel : '',
    'total_out_duration' : in_time != null ? total_out_duration : '',
    'company_code'       : company_code,   // ← NEW
  };

  // ── SharedPreferences storage (ISO strings for DateTime) ─────────────────
  Map<String, dynamic> toStorageJson() => {
    'violation_id'    : violation_id,
    'emp_id'          : emp_id,
    'emp_name'        : emp_name,
    'event_type'      : event_type,
    'location_name'   : location_name,
    'violation_date'  : violation_date,
    'out_time_iso'    : out_time.toIso8601String(),
    'in_time_iso'     : in_time?.toIso8601String(),
    'company_code'    : company_code,      // ← NEW
  };

  factory GeofenceViolation.fromStorageJson(Map<String, dynamic> j) {
    return GeofenceViolation(
      violation_id   : j['violation_id']   as String,
      emp_id         : j['emp_id']         as String,
      emp_name       : (j['emp_name']      as String?) ?? '',
      event_type     : (j['event_type']    as String?) ?? 'out',
      location_name  : j['location_name']  as String,
      violation_date : j['violation_date'] as String,
      out_time       : DateTime.parse(j['out_time_iso'] as String),
      in_time        : j['in_time_iso'] != null
          ? DateTime.parse(j['in_time_iso'] as String)
          : null,
      company_code   : (j['company_code']  as String?) ?? '', // ← NEW
    );
  }

  GeofenceViolation copyWith({
    DateTime? in_time,
    String?   event_type,
    String?   company_code,             // ← NEW
  }) =>
      GeofenceViolation(
        violation_id   : violation_id,
        emp_id         : emp_id,
        emp_name       : emp_name,
        event_type     : event_type   ?? this.event_type,
        location_name  : location_name,
        violation_date : violation_date,
        out_time       : out_time,
        in_time        : in_time      ?? this.in_time,
        company_code   : company_code ?? this.company_code, // ← NEW
      );

  // ── List encode / decode for SharedPreferences ────────────────────────────
  static String encodeList(List<GeofenceViolation> list) =>
      jsonEncode(list.map((v) => v.toStorageJson()).toList());

  static List<GeofenceViolation> decodeList(String raw) {
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return arr
          .map((e) => GeofenceViolation.fromStorageJson(
          e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}