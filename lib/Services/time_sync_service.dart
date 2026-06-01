import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TimeSyncService {
  // Your Oracle ORDS API endpoint
  static const String serverTimeApi =
      'http://oracle.metaxperts.net/ords/gps_workforce/servertime/get/';

  // ✅ POST endpoint — jab time mismatch ho tab yahan log karo
  static const String _timeMismatchLogApi =
      'http://oracle.metaxperts.net/ords/gps_workforce/timedifference/post/';

  // 2 minutes tolerance in milliseconds
  static const int timeToleranceMs = 2 * 60 * 1000; // 120,000 ms

  /// Validates if device time is in sync with server time.
  /// Returns TimeSyncResult:
  ///   isValid = true   if difference <= 2 minutes  → Clock-In allowed
  ///   isValid = false  if difference >  2 minutes  → Clock-In blocked
  static Future<TimeSyncResult> validateDeviceTime() async {
    try {
      final response = await http
          .get(
        Uri.parse(serverTimeApi),
        headers: {'Accept': 'application/json'},
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Server request timed out'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // ── Parse Oracle ORDS response ────────────────────────────────────
        String rawServerTime;

        if (jsonData is Map && jsonData.containsKey('items')) {
          final items = jsonData['items'] as List<dynamic>;
          if (items.isEmpty) {
            return _error('Server returned empty items array');
          }
          rawServerTime = items[0]['server_time'] as String;
        } else if (jsonData is Map && jsonData.containsKey('server_time')) {
          rawServerTime = jsonData['server_time'] as String;
        } else {
          return _error('Unexpected API response: ${response.body}');
        }

        // ── Parse "2026-05-19 10:11:35" ──────────────────────────────────
        final serverDateTime =
        DateTime.parse(rawServerTime.replaceFirst(' ', 'T'));

        final deviceDateTime = DateTime.now();

        final differenceMs =
        (serverDateTime.millisecondsSinceEpoch -
            deviceDateTime.millisecondsSinceEpoch)
            .abs();

        final isValid = differenceMs <= timeToleranceMs;

        // ✅ Sirf mismatch hone par POST karo
        if (!isValid) {
          await _postMismatchLog(
            serverTime: rawServerTime,
            deviceTime: _fmt(deviceDateTime),
          );
        }

        return TimeSyncResult(
          isValid: isValid,
          serverTime: rawServerTime,
          deviceTime: _fmt(deviceDateTime),
          differenceMs: differenceMs,
          message: isValid
              ? 'Time synced ✓  (Difference: ${_fmtDiff(differenceMs)})'
              : 'Time mismatch ✗  Difference: ${_fmtDiff(differenceMs)} — Clock-In blocked!',
        );
      } else {
        return _error('HTTP ${response.statusCode} from server');
      }
    } catch (e) {
      return _error('Error: $e');
    }
  }

  /// Quick boolean — call this before starting Clock-In
  static Future<bool> canClockIn() async {
    final result = await validateDeviceTime();
    return result.isValid;
  }

  // ────────────────────────────────────────────────────────────────────────
  // _postMismatchLog()
  //
  // Table : TIME_DIFFERENCE_WITH_SERVER
  // Fields: emp_id, emp_name, company_code, mobile_timestamp, server_timestamp
  // Sirf tab call hota hai jab time mismatch ho.
  // Silent fail — agar post nahi hua to clock-in block nahi hoga.
  // ────────────────────────────────────────────────────────────────────────
  static Future<void> _postMismatchLog({
    required String serverTime,
    required String deviceTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // emp_id
      final dynamic empIdRaw = prefs.get('emp_id') ?? prefs.get('userId');
      final dynamic empId = (empIdRaw is int)
          ? empIdRaw
          : int.tryParse(empIdRaw?.toString() ?? '') ?? (empIdRaw?.toString() ?? '');

      // emp_name — multiple key fallback
      final String empName =
          prefs.getString('emp_name')      ??
              prefs.getString('empName')       ??
              prefs.getString('userName')      ??
              prefs.getString('employee_name') ??
              prefs.getString('name')          ?? '';

      // company_code
      final String companyCode =
          prefs.getString('company_code') ??
              prefs.getString('companyCode')  ?? '';

      final Map<String, dynamic> body = {
        'emp_id':           empId,
        'emp_name':         empName,
        'company_code':     companyCode,
        'mobile_timestamp': deviceTime,        // phone ka time
        'server_timestamp': serverTime,        // server ka time
      };

      print('📤 [TimeSync] Mismatch POST → $_timeMismatchLogApi');
      print('📤 [TimeSync] Body → ${jsonEncode(body)}');

      final response = await http
          .post(
        Uri.parse(_timeMismatchLogApi),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      print('📥 [TimeSync] Response: ${response.statusCode} — ${response.body}');
    } catch (e) {
      // Silent fail — log karo bas
      print('⚠️ [TimeSync] Mismatch log POST error (silent): $e');
    }
  }

  // ─── Helpers (unchanged) ──────────────────────────────────────────────────

  static TimeSyncResult _error(String msg) => TimeSyncResult(
    isValid: false,
    serverTime: '—',
    deviceTime: _fmt(DateTime.now()),
    differenceMs: 0,
    message: msg,
  );

  static String _fmt(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} '
          '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';

  static String _p(int n) => n.toString().padLeft(2, '0');

  static String _fmtDiff(int ms) {
    if (ms < 1000) return '${ms} ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(0)} sec';
    return '${(ms / 60000).toStringAsFixed(1)} min';
  }
}

// ─── Result model (unchanged) ─────────────────────────────────────────────────

class TimeSyncResult {
  final bool isValid;
  final String serverTime;  // e.g. "2026-05-19 10:11:35"
  final String deviceTime;  // e.g. "2026-05-19 10:11:38"
  final int differenceMs;   // absolute difference in milliseconds
  final String message;

  TimeSyncResult({
    required this.isValid,
    required this.serverTime,
    required this.deviceTime,
    required this.differenceMs,
    required this.message,
  });
}