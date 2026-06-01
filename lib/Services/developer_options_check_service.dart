// ════════════════════════════════════════════════════════════════════════════
// developer_options_check_service.dart
//
// PURPOSE:
//   1. Clock-In click par check karo ke user ka Android Developer Options ON hai ya OFF.
//   2. ON hai to → dialog show karo, clock-in BLOCK karo jab tak OFF na ho.
//   3. Har check par (ON ho ya OFF) — ek nai API mein yeh data POST karo:
//        emp_id, emp_name, company_code, timestamp, developer_options (on/off)
//   4. ✅ OFFLINE: Agar internet nahi to SharedPreferences queue mein save karo.
//      Online hone par syncPendingQueue() call karo.
//
// INTEGRATION (timer_card.dart):
//   Step 1 — top-level imports mein add karo:
//     import '../../Services/developer_options_check_service.dart';
//
//   Step 2 — _handleClockIn() mein, AutoTimeCheck ke BILKUL BAAD yeh lines add karo:
//
//     // ── Developer Options Check ──────────────────────────────────────────
//     final devResult = await DeveloperOptionsCheckService.checkAndPost();
//     if (devResult.isDeveloperOptionsEnabled) {
//       if (mounted) {
//         await DeveloperOptionsCheckService.showBlockingDialog(context);
//       }
//       return; // Clock-in rok lo
//     }
//
//   Step 3 — connectivity listener mein online hone par yeh add karo:
//     DeveloperOptionsCheckService.syncPendingQueue();
//
// KOTLIN (MainActivity.kt) — existing LOCATION_CHANNEL handler mein yeh case add karo:
//
//   "isDeveloperOptionsEnabled" -> {
//       val devOptions = android.provider.Settings.Global.getInt(
//           contentResolver,
//           android.provider.Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
//           0
//       )
//       result.success(devOptions != 0)
//   }
//
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODEL  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class DevOptionsCheckResult {
  /// true  → Developer Options ON  → Clock-in BLOCK karo
  /// false → Developer Options OFF → Clock-in allow karo
  final bool isDeveloperOptionsEnabled;

  const DevOptionsCheckResult({required this.isDeveloperOptionsEnabled});
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class DeveloperOptionsCheckService {
  // ✅ FIX: Correct channel — same jo MainActivity.kt mein LOCATION_CHANNEL hai
  static const _platform =
  MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor');

  // ✅ Oracle ORDS endpoint
  static const String _apiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/empdevsetting/post/';

  // ── Offline queue key ─────────────────────────────────────────────────────
  static const String _kPendingQueueKey = 'dev_options_log_pending_queue';

  // ────────────────────────────────────────────────────────────────────────
  // checkAndPost()  (unchanged signature & logic)
  // ────────────────────────────────────────────────────────────────────────
  static Future<DevOptionsCheckResult> checkAndPost() async {
    bool isEnabled = false;

    // ── Step 1: Native check (unchanged) ────────────────────────────────
    if (Platform.isAndroid) {
      try {
        final dynamic result =
        await _platform.invokeMethod('isDeveloperOptionsEnabled');
        isEnabled = result == true;
        debugPrint(
            '🛠️ [DEV OPTIONS] Status = ${isEnabled ? "ON" : "OFF"}');
      } on MissingPluginException catch (e) {
        debugPrint('❌ [DEV OPTIONS] MissingPluginException: $e');
        debugPrint(
            '❌ [DEV OPTIONS] Channel mismatch ya Kotlin method register nahi — check MainActivity.kt');
        return const DevOptionsCheckResult(isDeveloperOptionsEnabled: false);
      } catch (e) {
        debugPrint('⚠️ [DEV OPTIONS] Native check error: $e — allowing clock-in');
        return const DevOptionsCheckResult(isDeveloperOptionsEnabled: false);
      }
    } else {
      // iOS ya koi aur platform — block nahi karte
      debugPrint('ℹ️ [DEV OPTIONS] Non-Android platform — check skipped');
      return const DevOptionsCheckResult(isDeveloperOptionsEnabled: false);
    }

    // ── Step 2: API POST (online → post, offline → queue) ───────────────
    await _postToApi(isEnabled: isEnabled);

    return DevOptionsCheckResult(isDeveloperOptionsEnabled: isEnabled);
  }

  // ────────────────────────────────────────────────────────────────────────
  // syncPendingQueue()
  //
  // timer_card.dart ke connectivity listener mein online hone par call karo.
  // Pending records ek ek kar ke post karta hai.
  // Fail hone wale dobara queue mein rehte hain.
  // ────────────────────────────────────────────────────────────────────────
  static Future<void> syncPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingQueueKey);
    if (raw == null) return;

    List<dynamic> queue;
    try {
      queue = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await prefs.remove(_kPendingQueueKey);
      return;
    }

    if (queue.isEmpty) return;

    debugPrint('🔄 [DEV OPTIONS] Pending queue sync — ${queue.length} record(s)');

    final List<dynamic> failed = [];

    for (final item in queue) {
      final body = Map<String, dynamic>.from(item as Map);
      final ok = await _sendToApi(body);
      if (!ok) failed.add(item);
    }

    if (failed.isEmpty) {
      await prefs.remove(_kPendingQueueKey);
      debugPrint('✅ [DEV OPTIONS] Queue fully synced — cleared');
    } else {
      await prefs.setString(_kPendingQueueKey, jsonEncode(failed));
      debugPrint('⚠️ [DEV OPTIONS] ${failed.length} record(s) still pending');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // _postToApi()  — online check → post ya queue
  // ────────────────────────────────────────────────────────────────────────
  static Future<void> _postToApi({required bool isEnabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // emp_id
      final String empId =
          _safeGet(prefs, 'emp_id') ?? _safeGet(prefs, 'userId') ?? '';

      // emp_name — multiple key fallback (same order as timer_card.dart)
      final String empName = _safeGetFallback(prefs, [
        'emp_name',
        'empName',
        'employee_name',
        'name',
        'userName',
        'user_name',
      ]);

      // company_code
      final String companyCode = _safeGet(prefs, 'company_code') ??
          _safeGet(prefs, 'companyCode') ??
          '';

      final String timestamp = DateTime.now().toIso8601String();
      final String devStatus = isEnabled ? 'on' : 'off';

      // ⚠️ Key 'developer_opions' (intentional typo) — Oracle ORDS bind variable
      //    :developer_opions in INSERT. Must match exactly.
      final Map<String, dynamic> body = {
        'emp_id': empId,
        'emp_name': empName,
        'company_code': companyCode,
        'timestamp': timestamp,
        'developer_opions': devStatus,
      };

      debugPrint('📡 [DEV OPTIONS] Posting: $body');

      // ── Online check ─────────────────────────────────────────────────
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (isOnline) {
        final ok = await _sendToApi(body);
        if (!ok) {
          // Server error — queue mein save karo
          await _saveToQueue(prefs, body);
        } else {
          // Post success — purana pending queue bhi sync karo
          await syncPendingQueue();
        }
      } else {
        // Offline — queue mein save karo
        await _saveToQueue(prefs, body);
        debugPrint('📴 [DEV OPTIONS] Offline — data queued for later sync');
      }
    } catch (e) {
      // Silent fail — API error se clock-in block nahi hona chahiye
      debugPrint('⚠️ [DEV OPTIONS] _postToApi error (silent): $e');
    }
  }

  // ── HTTP POST helper — bool return karta hai (true = success) ────────────
  static Future<bool> _sendToApi(Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '📡 [DEV OPTIONS] API response: ${response.statusCode} ${response.body}');

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('⚠️ [DEV OPTIONS] _sendToApi error: $e');
      return false;
    }
  }

  // ── Offline queue mein record save karo ──────────────────────────────────
  static Future<void> _saveToQueue(
      SharedPreferences prefs, Map<String, dynamic> body) async {
    try {
      final raw = prefs.getString(_kPendingQueueKey);
      final List<dynamic> queue =
      raw != null ? jsonDecode(raw) as List<dynamic> : [];
      queue.add(body);
      await prefs.setString(_kPendingQueueKey, jsonEncode(queue));
      debugPrint(
          '💾 [DEV OPTIONS] Offline queue mein save hua. Size: ${queue.length}');
    } catch (e) {
      debugPrint('❌ [DEV OPTIONS] Queue save error: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // showBlockingDialog()  (unchanged)
  // ────────────────────────────────────────────────────────────────────────
  static Future<void> showBlockingDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.20),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ────────────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.50),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.developer_mode_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────────
              const Text(
                'Developer Options Enabled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              // ── Message ─────────────────────────────────────────────────
              Text(
                'Developer Options are currently ON.\nPlease turn them OFF to mark attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Settings → System → Developer Options → Turn Off',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Buttons ─────────────────────────────────────────────────
              Row(
                children: [
                  // Close
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        child: const Center(
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Open Settings
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        const MethodChannel(
                          'com.yourapp.attendance/location_monitor',
                        )
                            .invokeMethod('openDeveloperSettings')
                            .catchError((_) {});
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.shade700,
                              Colors.redAccent.shade200,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Open Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Internal helpers (unchanged) ────────────────────────────────────────

  static String? _safeGet(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return null;
      final String val = raw.toString().trim();
      return val.isEmpty ? null : val;
    } catch (_) {
      return null;
    }
  }

  static String _safeGetFallback(
      SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final val = _safeGet(prefs, key);
      if (val != null) return val;
    }
    return '';
  }
}