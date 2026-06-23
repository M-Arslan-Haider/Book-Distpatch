import 'package:flutter/cupertino.dart';

/// Login model - company filtering is handled by backend API
class LoginModels {
  int? emp_id;
  String? portal_password;
  String? emp_name;
  String? job;
  String? geo_fencing;
  String? company_code;
  String? dep_id;

  // New fields for end time, overtime, and shift
  String? end_time;
  String? over_time;
  String? shift;

  // Profile image URL (null if no image uploaded)
  String? image_url;

  // Whether the employee is allowed to check in before their shift starts
  String? allow_check_in_before_shift;

  // Shift entry/start time
  String? entry_time;

  // ── TimeKeeper role ───────────────────────────────────────────────────────
  // DB column: TIMEKEEPER VARCHAR2(100)
  // ORDS returns lowercase key: "timekeeper"
  // Truthy values: 'yes', '1', 'true'
  String? timekeeper;

  // ── Single Device Login ───────────────────────────────────────────────────
  // DB column: DEVICE_TOKEN VARCHAR2(200) in hr_emp_info
  // ORDS returns lowercase key: "device_token"
  // NULL means no device registered yet (first login)
  String? device_token;

  LoginModels({
    this.emp_id,
    this.portal_password,
    this.emp_name,
    this.job,
    this.geo_fencing,
    this.company_code,
    this.dep_id,
    this.end_time,
    this.over_time,
    this.shift,
    this.image_url,
    this.allow_check_in_before_shift,
    this.entry_time,
    this.timekeeper,
    this.device_token,
  });

  factory LoginModels.fromJson(Map<String, dynamic> json) {
    debugPrint('📝 [LOGIN MODELS] Parsing JSON: ${json.keys}');
    debugPrint('📝 [LOGIN MODELS] dep_id from JSON: ${json['dep_id'] ?? json['DEP_ID']}');
    debugPrint('📝 [LOGIN MODELS] allow_check_in_before_shift from JSON: ${json['ALLOW_CHECK_IN_BEFORE_SHIFT'] ?? json['allow_check_in_before_shift']}');
    debugPrint('📝 [LOGIN MODELS] entry_time from JSON: ${json['ENTRY_TIME'] ?? json['entry_time']}');
    debugPrint('📝 [LOGIN MODELS] timekeeper from JSON: ${json['timekeeper'] ?? json['TIMEKEEPER']}');
    debugPrint('📝 [LOGIN MODELS] device_token from JSON: ${json['device_token'] ?? json['DEVICE_TOKEN']}');

    return LoginModels(
      emp_id:          json['emp_id'],
      portal_password: json['portal_password'],
      emp_name:        json['emp_name'],
      job:             json['job'],
      geo_fencing:     json['geo_fencing'],
      company_code:    json['company_code'],
      dep_id:          json['dep_id']?.toString() ?? json['DEP_ID']?.toString(),
      end_time:        json['END_TIME']?.toString() ?? json['end_time']?.toString(),
      over_time:       json['OVER_TIME']?.toString() ?? json['over_time']?.toString(),
      shift:           json['SHIFT']?.toString() ?? json['shift']?.toString(),
      image_url:       json['image_url']?.toString(),
      allow_check_in_before_shift:
      json['ALLOW_CHECK_IN_BEFORE_SHIFT']?.toString() ?? json['allow_check_in_before_shift']?.toString(),
      entry_time:      json['ENTRY_TIME']?.toString() ?? json['entry_time']?.toString(),
      // ORDS lowercases column names → 'timekeeper'; fallback for uppercase just in case
      timekeeper:      json['timekeeper']?.toString() ?? json['TIMEKEEPER']?.toString(),
      // ORDS returns 'device_token'; fallback for uppercase just in case
      device_token:    json['device_token']?.toString() ?? json['DEVICE_TOKEN']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id':          emp_id,
      'portal_password': portal_password,
      'emp_name':        emp_name,
      'job':             job,
      'geo_fencing':     geo_fencing,
      'company_code':    company_code,
      'DEP_ID':          dep_id,
      'END_TIME':        end_time,
      'OVER_TIME':       over_time,
      'SHIFT':           shift,
      'image_url':       image_url,
      'ALLOW_CHECK_IN_BEFORE_SHIFT': allow_check_in_before_shift,
      'ENTRY_TIME':      entry_time,
      'TIMEKEEPER':      timekeeper,
      'DEVICE_TOKEN':    device_token,
    };
  }

  // Helper methods
  bool get isOvertimeAllowed {
    final overtime = over_time?.toLowerCase().trim();
    final allowed  = overtime != null &&
        overtime.isNotEmpty &&
        (overtime == 'yes' || overtime == 'y' || overtime == 'true');
    debugPrint('🔍 [LOGIN MODELS] Checking overtime: "$overtime" -> $allowed');
    return allowed;
  }

  String get effectiveShift {
    final shiftValue = shift?.toLowerCase().trim();
    if (shiftValue == 'night') {
      debugPrint('🌙 [LOGIN MODELS] Shift detected: Night');
      return 'Night';
    }
    debugPrint('☀️ [LOGIN MODELS] Shift detected: Day');
    return 'Day';
  }

  DateTime? get parsedEndTime {
    if (end_time == null || end_time!.isEmpty) {
      debugPrint('⏰ [LOGIN MODELS] No end_time provided');
      return null;
    }
    final now   = DateTime.now();
    final parts = end_time!.split(':');
    if (parts.length < 2) {
      debugPrint('⚠️ [LOGIN MODELS] Invalid end_time format: $end_time');
      return null;
    }
    final hour       = int.tryParse(parts[0]) ?? 0;
    final minute     = int.tryParse(parts[1]) ?? 0;
    final second     = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    final parsedTime = DateTime(now.year, now.month, now.day, hour, minute, second);
    debugPrint('⏰ [LOGIN MODELS] Parsed end_time: $parsedTime');
    return parsedTime;
  }
}
