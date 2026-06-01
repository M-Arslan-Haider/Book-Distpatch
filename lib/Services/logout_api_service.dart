import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoutApiService {
  static const String _logoutUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/emplogouts/post/';

  /// Pending offline logouts yahan store honge
  static const String pendingLogoutsKey = 'pending_logouts_queue';

  // ───────────────────────────────────────────────────────────────────────────
  // postLogout — same call, same signature, kuch nahi badla
  // • Online  → seedha POST
  // • Offline → SharedPreferences queue mein save
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> postLogout(SharedPreferences prefs) async {
    try {
      final String empId       = _firstNonEmpty(prefs, ['emp_id', 'userId']);
      final String empName     = _firstNonEmpty(prefs, ['emp_name', 'userName', 'user_name']);
      final String companyCode = _firstNonEmpty(prefs, ['company_code', 'companyCode']);

      // Oracle VARCHAR2(100) — readable format
      final String logoutTime =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final Map<String, dynamic> body = {
        'emp_id'      : empId,
        'emp_name'    : empName,
        'company_code': companyCode,
        'logout_time' : logoutTime,
      };

      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('🚪 [LOGOUT API] POST → $_logoutUrl');
      debugPrint('🚪 [LOGOUT API] Body: $body');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');

      final response = await http
          .post(
        Uri.parse(_logoutUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [LOGOUT API] Inserted successfully — ${response.statusCode}');
      } else {
        debugPrint('⚠️ [LOGOUT API] Failed — ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      // ── OFFLINE: queue mein save karo ──────────────────────────────────────
      debugPrint('⚠️ [LOGOUT API] No internet — saving to offline queue');
      await _enqueue(prefs);
    } catch (e) {
      debugPrint('⚠️ [LOGOUT API] Error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // flushPendingLogouts — jab bhi online ho, yeh call karo
  // Sidebar ke onConfirm mein ya login success ke baad call kar sakte hain
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> flushPendingLogouts(SharedPreferences prefs) async {
    final List<Map<String, dynamic>> queue = _loadQueue(prefs);

    if (queue.isEmpty) return;

    debugPrint('🔄 [LOGOUT QUEUE] ${queue.length} pending logout(s) mil gaye — flush ho rahe hain...');

    final List<Map<String, dynamic>> stillPending = [];

    for (final body in queue) {
      try {
        final response = await http
            .post(
          Uri.parse(_logoutUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept'      : 'application/json',
          },
          body: jsonEncode(body),
        )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('✅ [LOGOUT QUEUE] Flushed: ${body['emp_id']} @ ${body['logout_time']}');
        } else {
          debugPrint('⚠️ [LOGOUT QUEUE] Server error ${response.statusCode} — queue mein rakhte hain');
          stillPending.add(body);
        }
      } on SocketException {
        debugPrint('⚠️ [LOGOUT QUEUE] Abhi bhi offline — queue mein rakhte hain');
        stillPending.add(body);
      } catch (e) {
        debugPrint('⚠️ [LOGOUT QUEUE] Error: $e');
        stillPending.add(body);
      }
    }

    await _saveQueue(prefs, stillPending);

    if (stillPending.isEmpty) {
      debugPrint('✅ [LOGOUT QUEUE] Sab pending logouts successfully flush ho gaye');
    } else {
      debugPrint('⚠️ [LOGOUT QUEUE] ${stillPending.length} logout(s) abhi bhi pending hain');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  /// Current user ka data queue mein add karo
  static Future<void> _enqueue(SharedPreferences prefs) async {
    final String empId       = _firstNonEmpty(prefs, ['emp_id', 'userId']);
    final String empName     = _firstNonEmpty(prefs, ['emp_name', 'userName', 'user_name']);
    final String companyCode = _firstNonEmpty(prefs, ['company_code', 'companyCode']);
    final String logoutTime  =
    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final Map<String, dynamic> body = {
      'emp_id'      : empId,
      'emp_name'    : empName,
      'company_code': companyCode,
      'logout_time' : logoutTime,
    };

    final List<Map<String, dynamic>> queue = _loadQueue(prefs);
    queue.add(body);
    await _saveQueue(prefs, queue);

    debugPrint('📦 [LOGOUT QUEUE] Queued: $body');
  }

  /// SharedPreferences se queue load karo
  static List<Map<String, dynamic>> _loadQueue(SharedPreferences prefs) {
    final String? raw = prefs.getString(pendingLogoutsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Queue SharedPreferences mein save karo
  static Future<void> _saveQueue(
      SharedPreferences prefs,
      List<Map<String, dynamic>> queue,
      ) async {
    await prefs.setString(pendingLogoutsKey, jsonEncode(queue));
  }

  static String _firstNonEmpty(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final val = (prefs.get(key) ?? '').toString().trim();
      if (val.isNotEmpty) return val;
    }
    return '';
  }
}