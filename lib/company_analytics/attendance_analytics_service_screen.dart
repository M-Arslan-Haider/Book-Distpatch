import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Database/db_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// attendance_analytics_service.dart
//
// Fetches attendance analytics data from Oracle ORDS endpoint:
// http://oracle.metaxperts.net/ords/gps_workforce/attendanceanalytics/get/
//
// Parameters: emp_id, company_code, month (YYYY-MM format)
// ═══════════════════════════════════════════════════════════════════════════

class AttendanceAnalyticsService extends GetxService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/attendanceanalytics/get';

  // ─── Fetch attendance data for a specific month ─────────────────────────
  Future<AttendanceAnalyticsData?> fetchAttendanceData({
    required String month, // YYYY-MM format, e.g., "2026-05"
  }) async {
    try {
      // Get emp_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      String empId = '';

      // Helper function to safely get string value
      String? safeGetString(String key) {
        try {
          return prefs.getString(key);
        } catch (e) {
          return null;
        }
      }

      // Helper function to safely get int value
      int? safeGetInt(String key) {
        try {
          return prefs.getInt(key);
        } catch (e) {
          return null;
        }
      }

      // Try all possible keys as String first
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

      // If not found as String, try as int
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
            '❌ [AttendanceService] Missing emp_id or company_code (emp: $empId, co: $companyCode)');
        return null;
      }

      debugPrint(
          '📡 [AttendanceService] Fetching data: emp_id=$empId, company_code=$companyCode, month=$month');

      // Build query string
      final queryParams = {
        'emp_id': empId,
        'company_code': companyCode,
        'month': month,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('📡 [AttendanceService] Full URL: $uri');

      // Make GET request
      final response = await GetConnect().get(uri.toString());

      debugPrint('📡 [AttendanceService] Response status: ${response.statusCode}');
      debugPrint('📡 [AttendanceService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = response.body;

        // Handle the response format with 'items' array
        if (data is Map<String, dynamic>) {
          // Check if response has 'items' array
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            if (items.isNotEmpty) {
              final item = items[0];
              if (item is Map<String, dynamic>) {
                debugPrint('✅ [AttendanceService] Data received from items array: $item');
                final result = AttendanceAnalyticsData.fromJson(item);
                debugPrint('✅ [AttendanceService] Parsed data: present=${result.presentDays}, late=${result.lateArrivalDays}');
                return result;
              }
            } else {
              debugPrint('⚠️  [AttendanceService] Items array is empty');
              return null;
            }
          } else {
            // Fallback: treat the entire response as the data object
            debugPrint('✅ [AttendanceService] Data received (single object): $data');
            final result = AttendanceAnalyticsData.fromJson(data);
            debugPrint('✅ [AttendanceService] Parsed data: present=${result.presentDays}, late=${result.lateArrivalDays}');
            return result;
          }
        } else if (data is List && data.isNotEmpty) {
          // Handle case where response is directly a list
          final item = data[0];
          if (item is Map<String, dynamic>) {
            debugPrint('✅ [AttendanceService] Data received (list): $item');
            final result = AttendanceAnalyticsData.fromJson(item);
            debugPrint('✅ [AttendanceService] Parsed data: present=${result.presentDays}, late=${result.lateArrivalDays}');
            return result;
          }
        } else {
          debugPrint('⚠️  [AttendanceService] Unexpected response format: $data (type: ${data.runtimeType})');
          return null;
        }
      } else {
        debugPrint(
            '❌ [AttendanceService] Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AttendanceService] Exception: $e');
      debugPrint('❌ [AttendanceService] StackTrace: $stackTrace');
      return null;
    }
    return null;
  }
}

// ─── Data model ──────────────────────────────────────────────────────────
class AttendanceAnalyticsData {
  final String empId;
  final String month;
  final int presentDays;
  final int lateArrivalDays;
  final int onTimeArrivalDays;
  final int earlyExitDays;
  final int halfDays;
  final String totalLateTime;
  final String totalEarlyExitTime;
  final String totalWorkingHours;
  final int totalGeoViolations;
  final int totalOfflineEvents;
  final int totalHolidays;
  final int totalLeaveDays;
  // NOTE: these 2 fields are read defensively from several possible
  // column-name variants since the exact column name on this endpoint
  // wasn't confirmed yet — check debug logs / live device logs to see the
  // raw JSON keys and tell me if a different key needs to be added.
  final int totalMockLocationEvents;
  final int totalGpsOffEvents;

  AttendanceAnalyticsData({
    required this.empId,
    required this.month,
    required this.presentDays,
    required this.lateArrivalDays,
    required this.onTimeArrivalDays,
    required this.earlyExitDays,
    required this.halfDays,
    required this.totalLateTime,
    required this.totalEarlyExitTime,
    required this.totalWorkingHours,
    required this.totalGeoViolations,
    required this.totalOfflineEvents,
    required this.totalHolidays,
    required this.totalLeaveDays,
    required this.totalMockLocationEvents,
    required this.totalGpsOffEvents,
  });

  // ─── Computed properties ──────────────────────────────────────────────
  int get absentDays => presentDays > 0 ? 0 : lateArrivalDays;

  /// Compute attendance score (0-100%)
  int get attendanceScore {
    final total = presentDays + lateArrivalDays + earlyExitDays;
    if (total == 0) return 100;
    return ((presentDays / total) * 100).toInt().clamp(0, 100);
  }

  /// Main issue (most common problem)
  String get mainIssue {
    if (lateArrivalDays > earlyExitDays && lateArrivalDays > 0) {
      return '$lateArrivalDays late arrivals this month';
    } else if (earlyExitDays > 0) {
      return '$earlyExitDays early exits this month';
    } else if (halfDays > 0) {
      return '$halfDays half days this month';
    } else {
      return 'No major issues detected';
    }
  }

  /// Suggested action
  String get suggestedAction {
    if (lateArrivalDays > 0) {
      return 'Try to arrive on time to improve your score.';
    } else if (earlyExitDays > 0) {
      return 'Complete your full working hours for better attendance.';
    } else {
      return 'Keep up the great attendance record!';
    }
  }

  /// Compliance risk level — auto-derived from geo-fence violations and
  /// device-offline events for the month.
  /// Thresholds below are a starting point — adjust the numbers if real
  /// usage shows they should be stricter/looser.
  String get complianceRiskLevel {
    final riskScore = totalGeoViolations + totalOfflineEvents;
    if (riskScore >= 13) return 'High';
    if (riskScore >= 5) return 'Medium';
    return 'Low';
  }

  // ─── JSON parsing ────────────────────────────────────────────────────
  factory AttendanceAnalyticsData.fromJson(Map<String, dynamic> json) {
    // Debug the raw values
    debugPrint('📊 [fromJson] Raw JSON: $json');

    // Parse each value with explicit type checking
    final empId = json['emp_id']?.toString() ?? '';
    final month = json['month']?.toString() ?? '';

    // Parse integers with explicit handling
    int parseInteger(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      if (value is double) return value.toInt();
      debugPrint('⚠️ [fromJson] Unexpected type for value: $value (${value.runtimeType})');
      return 0;
    }

    final presentDays = parseInteger(json['present_days']);
    final lateArrivalDays = parseInteger(json['late_arrival_days']);
    final onTimeArrivalDays = parseInteger(json['on_time_arrival_days']);
    final earlyExitDays = parseInteger(json['early_exit_days']);
    final halfDays = parseInteger(json['half_days']);
    final totalGeoViolations = parseInteger(json['total_geo_violations']);
    final totalOfflineEvents = parseInteger(json['total_offline_events']);
    final totalHolidays = parseInteger(json['total_holidays']);
    final totalLeaveDays = parseInteger(json['total_leave_days']);

    // Try several likely column-name variants for these 2 (exact column
    // name not confirmed yet) — first matching key in the JSON wins.
    int parseFirstMatch(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return parseInteger(json[key]);
        }
      }
      return 0;
    }

    final totalMockLocationEvents = parseFirstMatch([
      'total_mock_location_events',
      'total_mock_location',
      'mock_location_events',
      'total_mock_gps_events',
      'mock_location_count',
      'mock_location',
    ]);
    final totalGpsOffEvents = parseFirstMatch([
      'total_gps_off_events',
      'total_gps_off',
      'gps_off_events',
      'total_gps_disabled_events',
      'gps_off_count',
      'gps_off',
    ]);

    // Parse time strings
    final totalLateTime = json['total_late_time']?.toString() ?? '00:00:00';
    final totalEarlyExitTime = json['total_early_exit_time']?.toString() ?? '00:00:00';
    final totalWorkingHours = json['total_working_hours']?.toString() ?? '00:00:00';

    debugPrint('📊 [fromJson] Parsed: present=$presentDays, late=$lateArrivalDays, onTime=$onTimeArrivalDays, early=$earlyExitDays');
    debugPrint('📊 [fromJson] Compliance: mockLocation=$totalMockLocationEvents, gpsOff=$totalGpsOffEvents (verify these against raw JSON keys above)');

    return AttendanceAnalyticsData(
      empId: empId,
      month: month,
      presentDays: presentDays,
      lateArrivalDays: lateArrivalDays,
      onTimeArrivalDays: onTimeArrivalDays,
      earlyExitDays: earlyExitDays,
      halfDays: halfDays,
      totalLateTime: totalLateTime,
      totalEarlyExitTime: totalEarlyExitTime,
      totalWorkingHours: totalWorkingHours,
      totalGeoViolations: totalGeoViolations,
      totalOfflineEvents: totalOfflineEvents,
      totalHolidays: totalHolidays,
      totalLeaveDays: totalLeaveDays,
      totalMockLocationEvents: totalMockLocationEvents,
      totalGpsOffEvents: totalGpsOffEvents,
    );
  }
}