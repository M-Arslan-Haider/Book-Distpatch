import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashLogService {
  // ✅ REAL API — Sir Afaq ka endpoint
  static const String _apiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/crashlogs/post/';

  // ── Post crash/error to Oracle server ────────────────────────────────────
  static Future<void> postCrashToServer({
    required String error,
    required String stack,
    required String errorType,  // 'flutter_error' | 'async_error' | 'non_fatal'
    String screenName = '',
  }) async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo  = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      final String empId       = prefs.getInt('emp_id')?.toString()  ?? prefs.getString('emp_id')  ?? '';
      final String empName     = prefs.getString('emp_name')          ?? prefs.getString('userName') ?? '';
      final String companyCode = prefs.getString('company_code')      ?? '';
      final String appVersion  = packageInfo.version;
      final String deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      final String osVersion   = 'Android ${androidInfo.version.release}';
      final String crashTime   = DateTime.now().toIso8601String();

      // Stack trace ko 4000 char tak limit karo (Oracle VARCHAR2 limit)
      final String shortStack  = stack.length > 3900
          ? stack.substring(0, 3900)
          : stack;

      final body = {
        'emp_id'       : empId,
        'emp_name'     : empName,
        'company_code' : companyCode,
        'app_version'  : appVersion,
        'device_model' : deviceModel,
        'os_version'   : osVersion,
        'error_type'   : errorType,
        'error_message': error.length > 3900 ? error.substring(0, 3900) : error,
        'stack_trace'  : shortStack,
        'screen_name'  : screenName,
        'crash_time'   : crashTime,
      };

      debugPrint('📡 [CrashLog] Posting to Oracle: $errorType');
      debugPrint('   emp_id=$empId | device=$deviceModel | os=$osVersion');
      debugPrint('   error=${error.substring(0, error.length.clamp(0, 100))}...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [CrashLog] Posted to Oracle successfully');
      } else {
        debugPrint('⚠️ [CrashLog] Oracle response: ${response.statusCode}');
      }
    } catch (e) {
      // Silent fail — crash reporting should never cause another crash
      debugPrint('⚠️ [CrashLog] Failed to post to Oracle (silent): $e');
    }
  }
}