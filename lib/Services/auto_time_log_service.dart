// ============================================================
// lib/Services/auto_time_check_service.dart
// ============================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

const String _kAutoTimeCheckUrl =
    'http://oracle.metaxperts.net/ords/gps_workforce/autotimecheck/post/';

const MethodChannel _autoTimeChannel =
MethodChannel('com.metaxperts.GPS_Workforce_Monitor/auto_time_check');

// ════════════════════════════════════════════════════════════════════════════
// AutoTimeCheckResult
// ════════════════════════════════════════════════════════════════════════════
class AutoTimeCheckResult {
  final bool isAutoTimeEnabled;
  final bool apiPostSuccess;
  final String? errorMessage;

  const AutoTimeCheckResult({
    required this.isAutoTimeEnabled,
    required this.apiPostSuccess,
    this.errorMessage,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// AutoTimeCheckService
// ════════════════════════════════════════════════════════════════════════════
class AutoTimeCheckService {

  // ── STEP 1: Native Android AUTO_TIME check ────────────────────────────────
  static Future<bool> _isAutoTimeEnabled() async {
    try {
      final bool result =
          await _autoTimeChannel.invokeMethod<bool>('isAutoTimeEnabled') ?? false;
      debugPrint('📱 [AutoTime] isAutoTimeEnabled = $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ [AutoTime] PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ [AutoTime] Unknown error: $e');
      return false;
    }
  }

  // ── STEP 2: Oracle APEX POST ───────────────────────────────────────────────
  // Table: EMP_AUTO_TIME_LOG
  // Columns: EMP_ID, EMP_NAME, COMPANY_CODE, AUTO_TIME_ENABLED, PHONE_TIME
  static Future<bool> _postToApi({
    required dynamic empId,       // int ya String — as-is bhejo
    required String empName,
    required String companyCode,
    required bool autoTimeEnabled,
  }) async {
    try {
      final String phoneTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // emp_id — agar int hai to int bhejo, String hai to String
      // Oracle APEX NUMBER column ke liye int prefer karo
      final dynamic empIdValue = (empId is int) ? empId : int.tryParse(empId.toString()) ?? empId.toString();

      final Map<String, dynamic> body = {
        'emp_id':            empIdValue,
        'emp_name':          empName,
        'company_code':      companyCode,
        'auto_time_enabled': autoTimeEnabled ? 'YES' : 'NO',
        'phone_time':        phoneTime,
      };

      debugPrint('📤 [AutoTime] POST → $_kAutoTimeCheckUrl');
      debugPrint('📤 [AutoTime] Body → ${jsonEncode(body)}');

      final response = await http
          .post(
        Uri.parse(_kAutoTimeCheckUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [AutoTime] Response: ${response.statusCode} — ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [AutoTime] Data posted successfully');
        return true;
      } else {
        debugPrint('❌ [AutoTime] API returned error: ${response.statusCode} — ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AutoTime] API Error: $e');
      return false;
    }
  }

  // ── PUBLIC: Clock In button press par yeh call karo ───────────────────────
  static Future<AutoTimeCheckResult> checkAndPost() async {
    final prefs = await SharedPreferences.getInstance();

    // ── emp_id: int ya String dono safe handle ──
    final dynamic empIdRaw = prefs.get('emp_id') ?? prefs.get('userId');
    final dynamic empId    = empIdRaw ?? '';
    debugPrint('🔍 [AutoTime] emp_id raw type: ${empIdRaw.runtimeType}  value: $empIdRaw');

    // ── emp_name: multiple keys try karo ──
    final String empName =
        prefs.getString('emp_name')      ??
            prefs.getString('empName')       ??
            prefs.getString('userName')      ??
            prefs.getString('employee_name') ??
            prefs.getString('name')          ?? '';

    final String companyCode = prefs.getString('company_code') ?? '';

    debugPrint('🔍 [AutoTime] empId=$empId  empName=$empName  company=$companyCode');

    // ── 1. Native Android check ──
    final bool autoTimeOn = await _isAutoTimeEnabled();

    // ── 2. API POST ──
    final bool posted = await _postToApi(
      empId:           empId,
      empName:         empName,
      companyCode:     companyCode,
      autoTimeEnabled: autoTimeOn,
    );

    return AutoTimeCheckResult(
      isAutoTimeEnabled: autoTimeOn,
      apiPostSuccess:    posted,
    );
  }
}