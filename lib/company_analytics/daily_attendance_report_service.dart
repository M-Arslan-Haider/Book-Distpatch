import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Database/db_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// daily_attendance_report_service.dart
//
// Fetches the day-by-day attendance report from Oracle ORDS endpoint:
// http://oracle.metaxperts.net/ords/gps_workforce/gpsattendancereport/get/
//
// Parameters: emp_id, company_code, month (YYYY-MM format)
// Returns one record per day for the requested month.
// ═══════════════════════════════════════════════════════════════════════════

class DailyAttendanceReportService extends GetxService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/gpsattendancereport/get';

  // ─── Fetch the full daily attendance report for a specific month ────────
  Future<List<DailyAttendanceRecord>?> fetchDailyAttendance({
    required String month, // YYYY-MM format, e.g., "2026-05"
  }) async {
    try {
      // Get emp_id from SharedPreferences (same lookup pattern used across
      // the rest of the app)
      final prefs = await SharedPreferences.getInstance();

      String empId = '';

      String? safeGetString(String key) {
        try {
          return prefs.getString(key);
        } catch (e) {
          return null;
        }
      }

      int? safeGetInt(String key) {
        try {
          return prefs.getInt(key);
        } catch (e) {
          return null;
        }
      }

      final stringKeys = [
        'emp_id',
        'empId',
        'employee_id',
        'employeeId',
        'userId',
        'user_id'
      ];

      for (var key in stringKeys) {
        final value = safeGetString(key);
        if (value != null && value.isNotEmpty) {
          empId = value;
          break;
        }
      }

      if (empId.isEmpty) {
        final intKeys = [
          'emp_id',
          'empId',
          'employee_id',
          'employeeId',
          'userId',
          'user_id'
        ];

        for (var key in intKeys) {
          final value = safeGetInt(key);
          if (value != null) {
            empId = value.toString();
            break;
          }
        }
      }

      // Get company_code from DBHelper
      final companyCode = DBHelper.getCompanyCode() ?? '';

      if (empId.isEmpty || companyCode.isEmpty) {
        debugPrint(
            '❌ [DailyAttendanceReportService] Missing emp_id or company_code (emp: $empId, co: $companyCode)');
        return null;
      }

      debugPrint(
          '📡 [DailyAttendanceReportService] Fetching data: emp_id=$empId, company_code=$companyCode, month=$month');

      // Build query string. limit=100 ensures every day of the month is
      // returned in a single page (ORDS default page size is smaller).
      final queryParams = {
        'emp_id': empId,
        'company_code': companyCode,
        'month': month,
        'limit': '100',
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('📡 [DailyAttendanceReportService] Full URL: $uri');

      final response = await GetConnect().get(uri.toString());

      debugPrint(
          '📡 [DailyAttendanceReportService] Response status: ${response.statusCode}');
      debugPrint(
          '📡 [DailyAttendanceReportService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = response.body;
        final List<DailyAttendanceRecord> records = [];

        if (data is Map<String, dynamic>) {
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                records.add(DailyAttendanceRecord.fromJson(item));
              }
            }
            debugPrint(
                '✅ [DailyAttendanceReportService] Parsed ${records.length} daily records');
            return records;
          } else {
            debugPrint(
                '⚠️  [DailyAttendanceReportService] Response had no items array: $data');
            return records;
          }
        } else if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              records.add(DailyAttendanceRecord.fromJson(item));
            }
          }
          debugPrint(
              '✅ [DailyAttendanceReportService] Parsed ${records.length} daily records (list response)');
          return records;
        } else {
          debugPrint(
              '⚠️  [DailyAttendanceReportService] Unexpected response format: $data (type: ${data.runtimeType})');
          return records;
        }
      } else {
        debugPrint(
            '❌ [DailyAttendanceReportService] Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [DailyAttendanceReportService] Exception: $e');
      debugPrint('❌ [DailyAttendanceReportService] StackTrace: $stackTrace');
      return null;
    }
  }
}

// ─── Data model ──────────────────────────────────────────────────────────
class DailyAttendanceRecord {
  final String empId;
  final String workDate; // YYYY-MM-DD
  final String dayName; // e.g. "FRIDAY"
  final String shiftStart; // HH:MM
  final String shiftEnd; // HH:MM
  final String firstIn; // HH:MM:SS
  final String lastOut; // HH:MM:SS
  final int totalLogs;
  final String totalStay; // H:MM:SS
  final String lateTime; // HH:MM:SS
  final String earlyExit; // HH:MM:SS
  final String statusText; // Present / Late / Absent / Leave / Holiday / Half Day...
  final String isGrace; // Yes / No
  final String holidayName; // e.g. "Labour Day" or "None"
  final String dayType; // Working / Weekend / ...
  final String onLeave; // Yes / No
  final int geoViolations;
  final int offlineEvents;
  // NOTE: column names not confirmed for this endpoint yet — parsed
  // defensively from several likely variants, defaulting to 0 if absent.
  // Check live logs for the raw JSON keys and tell me if a different key
  // needs to be added.
  final int mockLocationEvents;
  final int gpsOffEvents;

  DailyAttendanceRecord({
    required this.empId,
    required this.workDate,
    required this.dayName,
    required this.shiftStart,
    required this.shiftEnd,
    required this.firstIn,
    required this.lastOut,
    required this.totalLogs,
    required this.totalStay,
    required this.lateTime,
    required this.earlyExit,
    required this.statusText,
    required this.isGrace,
    required this.holidayName,
    required this.dayType,
    required this.onLeave,
    required this.geoViolations,
    required this.offlineEvents,
    required this.mockLocationEvents,
    required this.gpsOffEvents,
  });

  // ─── Display helpers ──────────────────────────────────────────────────

  /// 3-letter day abbreviation for the calendar tile, e.g. "FRI"
  String get dayAbbrev =>
      dayName.length >= 3 ? dayName.substring(0, 3).toUpperCase() : dayName.toUpperCase();

  /// Day-of-month without a leading zero, e.g. "30" or "1"
  String get dayNumber {
    final parts = workDate.split('-');
    if (parts.length == 3) {
      final parsed = int.tryParse(parts[2]);
      if (parsed != null) return parsed.toString();
    }
    return workDate;
  }

  /// HH:MM view of an HH:MM:SS time string (falls back to '-')
  static String shortTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String get displayFirstIn => shortTime(firstIn);
  String get displayLastOut => shortTime(lastOut);
  String get displayHours => shortTime(totalStay);

  /// Italic note shown under the time row
  String get displayNote {
    if (holidayName.trim().isNotEmpty && holidayName.toLowerCase() != 'none') {
      return holidayName;
    }
    if (onLeave.toLowerCase() == 'yes') {
      return 'On approved leave';
    }
    if (dayType.toLowerCase() == 'weekend') {
      return 'Weekend';
    }
    return 'Regular working day';
  }

  // ─── JSON parsing ────────────────────────────────────────────────────
  factory DailyAttendanceRecord.fromJson(Map<String, dynamic> json) {
    int parseInteger(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String parseString(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      return value.toString();
    }

    // Try several likely column-name variants — first matching key wins.
    int parseFirstMatch(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return parseInteger(json[key]);
        }
      }
      return 0;
    }

    final mockLocationEvents = parseFirstMatch([
      'mock_location_events',
      'mock_location',
      'mock_location_count',
      'is_mock_location',
    ]);
    final gpsOffEvents = parseFirstMatch([
      'gps_off_events',
      'gps_off',
      'gps_off_count',
      'gps_disabled_events',
    ]);

    return DailyAttendanceRecord(
      empId: parseString(json['emp_id']),
      workDate: parseString(json['work_date']),
      dayName: parseString(json['day_name']),
      shiftStart: parseString(json['shift_start']),
      shiftEnd: parseString(json['shift_end']),
      firstIn: parseString(json['first_in']),
      lastOut: parseString(json['last_out']),
      totalLogs: parseInteger(json['total_logs']),
      totalStay: parseString(json['total_stay']),
      lateTime: parseString(json['late_time'], '00:00:00'),
      earlyExit: parseString(json['early_exit'], '00:00:00'),
      statusText: parseString(json['status_text'], 'Unknown'),
      isGrace: parseString(json['is_grace'], 'No'),
      holidayName: parseString(json['holiday_name'], 'None'),
      dayType: parseString(json['day_type']),
      onLeave: parseString(json['on_leave'], 'No'),
      geoViolations: parseInteger(json['geo_violations']),
      offlineEvents: parseInteger(json['offline_events']),
      mockLocationEvents: mockLocationEvents,
      gpsOffEvents: gpsOffEvents,
    );
  }
}
