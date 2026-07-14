// ============================================================
// lib/Services/auto_time_log_service.dart
// ============================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String _kAutoTimeCheckUrl =
    'http://oracle.metaxperts.net/ords/gps_workforce/autotimecheck/post/';

// ── SharedPreferences key jahan pending (offline) records store honge ──────
// Value: JSON-encoded List of Maps
const String _kPendingQueueKey = 'auto_time_log_pending_queue';

const MethodChannel _autoTimeChannel =
MethodChannel('com.metaxperts.bookdispatch/auto_time_check');

// ════════════════════════════════════════════════════════════════════════════
// AutoTimeCheckResult  (unchanged)
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

  // ── STEP 1: Native Android AUTO_TIME check (unchanged) ───────────────────
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

  // ── Internet connection check ─────────────────────────────────────────────
  static Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  // ── STEP 2: Oracle APEX POST (unchanged logic, extracted for reuse) ───────
  static Future<bool> _postToApi(Map<String, dynamic> body) async {
    try {
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
        debugPrint('❌ [AutoTime] API error: ${response.statusCode} — ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AutoTime] API Error: $e');
      return false;
    }
  }

  // ── Body builder (same fields as before) ─────────────────────────────────
  static Map<String, dynamic> _buildBody({
    required dynamic empId,
    required String empName,
    required String companyCode,
    required bool autoTimeEnabled,
    String? phoneTime, // optional: offline mein saved time use karo
  }) {
    final dynamic empIdValue =
    (empId is int) ? empId : int.tryParse(empId.toString()) ?? empId.toString();

    return {
      'emp_id':            empIdValue,
      'emp_name':          empName,
      'company_code':      companyCode,
      'auto_time_enabled': autoTimeEnabled ? 'YES' : 'NO',
      'phone_time':        phoneTime ??
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };
  }

  // ── Offline queue mein record save karo ──────────────────────────────────
  static Future<void> _saveToQueue(Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPendingQueueKey);
      final List<dynamic> queue =
      raw != null ? jsonDecode(raw) as List<dynamic> : [];

      queue.add(body);
      await prefs.setString(_kPendingQueueKey, jsonEncode(queue));
      debugPrint('💾 [AutoTime] Offline mein save hua. Queue size: ${queue.length}');
    } catch (e) {
      debugPrint('❌ [AutoTime] Queue save error: $e');
    }
  }

  // ── PUBLIC: Pending offline records sync karo (online hone par call karo) ─
  // timer_card.dart mein connectivity listener se yeh call karo — koi aur change nahi.
  static Future<void> syncPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kPendingQueueKey);
    if (raw == null) return;

    List<dynamic> queue;
    try {
      queue = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await prefs.remove(_kPendingQueueKey);
      return;
    }

    if (queue.isEmpty) return;

    debugPrint('🔄 [AutoTime] Pending queue sync start — ${queue.length} record(s)');

    final List<dynamic> failed = [];

    for (final item in queue) {
      final body = Map<String, dynamic>.from(item as Map);
      final ok   = await _postToApi(body);
      if (!ok) {
        failed.add(item); // fail hua to dobara queue mein raho
      }
    }

    // Sirf failed records queue mein bachao
    if (failed.isEmpty) {
      await prefs.remove(_kPendingQueueKey);
      debugPrint('✅ [AutoTime] Queue fully synced — cleared');
    } else {
      await prefs.setString(_kPendingQueueKey, jsonEncode(failed));
      debugPrint('⚠️ [AutoTime] ${failed.length} record(s) still pending');
    }
  }

  // ── PUBLIC: Clock In button press par yeh call karo (unchanged signature) ─
  static Future<AutoTimeCheckResult> checkAndPost() async {
    final prefs = await SharedPreferences.getInstance();

    // ── emp_id: int ya String dono safe handle (unchanged) ──
    final dynamic empIdRaw = prefs.get('emp_id') ?? prefs.get('userId');
    final dynamic empId    = empIdRaw ?? '';
    debugPrint('🔍 [AutoTime] emp_id raw type: ${empIdRaw.runtimeType}  value: $empIdRaw');

    // ── emp_name: multiple keys try karo (unchanged) ──
    final String empName =
        prefs.getString('emp_name')      ??
            prefs.getString('empName')       ??
            prefs.getString('userName')      ??
            prefs.getString('employee_name') ??
            prefs.getString('name')          ?? '';

    final String companyCode = prefs.getString('company_code') ?? '';

    debugPrint('🔍 [AutoTime] empId=$empId  empName=$empName  company=$companyCode');

    // ── 1. Native Android check (unchanged) ──
    final bool autoTimeOn = await _isAutoTimeEnabled();

    // ── 2. Body banao ──
    final body = _buildBody(
      empId:           empId,
      empName:         empName,
      companyCode:     companyCode,
      autoTimeEnabled: autoTimeOn,
    );

    // ── 3. Online check → post karo ya queue mein save karo ──
    final online = await _isOnline();
    bool posted  = false;

    if (online) {
      // Online: seedha post karo + agar koi purana pending hai to sync karo
      posted = await _postToApi(body);
      if (!posted) {
        // Post fail hua (server error) to queue mein save karo
        await _saveToQueue(body);
      } else {
        // Online aur post success — purana queue bhi sync kar do
        await syncPendingQueue();
      }
    } else {
      // Offline: queue mein save karo, posted = false rakhte hain
      await _saveToQueue(body);
      debugPrint('📴 [AutoTime] Offline — data queued for later sync');
    }

    return AutoTimeCheckResult(
      isAutoTimeEnabled: autoTimeOn,
      apiPostSuccess:    posted,
    );
  }
}