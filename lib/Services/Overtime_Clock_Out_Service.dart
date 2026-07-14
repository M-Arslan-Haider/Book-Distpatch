// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// // ════════════════════════════════════════════════════════════════════════════
// // OvertimeClockOutService
// // ════════════════════════════════════════════════════════════════════════════
// //
// // PURPOSE:
// //   Jab overtime=yes wala user apni shift end ke baad dobara clock-in kare,
// //   yeh service:
// //     1. Backend API se DAILY_OT_CAP (hours) fetch karti hai
// //     2. Har 5 minute mein live re-fetch karti hai (backend change detect)
// //     3. DAILY_OT_CAP expire hone par onOvertimeExpired() callback fire karta hai
// //        → timer_card.dart us callback mein auto clock-out trigger karta hai
// //
// // API:
// //   GET http://oracle.metaxperts.net/ords/gps_workforce/maxot/get?dep_id=XXX
// //   DB:  SELECT DAILY_OT_CAP FROM OVERTIME_SCHEDULE WHERE dep_id = :dep_id
// //   Response (ORDS format):
// //     { "items": [{ "DAILY_OT_CAP": 2 }], "hasMore": false, ... }
// //   DAILY_OT_CAP = hours (e.g. 2 = 2 hours = 120 minutes)
// //
// // USAGE in timer_card.dart:
// //   final OvertimeClockOutService _overtimeService = OvertimeClockOutService();
// //
// //   // Overtime clock-in detect hone par:
// //   await _overtimeService.start(onOvertimeExpired: _triggerOvertimeClockOut);
// //
// //   // Clock-out / dispose par:
// //   await _overtimeService.cancel();
// //
// //   // App kill / resume restore par:
// //   final saved = await OvertimeClockOutService.getSavedOvertimeClockInTime();
// //   if (saved != null) {
// //     await _overtimeService.start(
// //       onOvertimeExpired: _triggerOvertimeClockOut,
// //       restoredClockInTime: saved,
// //     );
// //   }
// // ════════════════════════════════════════════════════════════════════════════
//
// typedef OvertimeExpiredCallback = Future<void> Function();
//
// class OvertimeClockOutService {
//
//   // ── API endpoint ──────────────────────────────────────────────────────────
//   static const String _apiUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/maxot/get';
//
//   // ── SharedPreferences key — saved so timer survives app kill/restart ──────
//   static const String _keyOtClockInTime = 'overtime_session_clock_in_time';
//
//   // ── Internal state ────────────────────────────────────────────────────────
//   Timer?    _countdownTimer;        // fires when OT cap expires
//   Timer?    _liveFetchTimer;        // re-fetches API every 5 min
//   DateTime? _overtimeClockInTime;   // timestamp of overtime clock-in
//   int       _currentOtCapMinutes = 0;
//   bool      _isRunning = false;
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // PUBLIC API
//   // ══════════════════════════════════════════════════════════════════════════
//
//   /// Overtime session start karo.
//   /// [restoredClockInTime] — app kill ke baad restore karte waqt purana time pass karo.
//   Future<void> start({
//     required OvertimeExpiredCallback onOvertimeExpired,
//     DateTime? restoredClockInTime,
//   }) async {
//     // Pehle koi purana session cancel karo
//     await cancel(clearPrefs: false);
//
//     _isRunning           = true;
//     _overtimeClockInTime = restoredClockInTime ?? DateTime.now();
//
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('⏰ [OT SERVICE] ===== OVERTIME SESSION STARTED =====');
//     debugPrint('⏰ [OT SERVICE] Clock-in time : $_overtimeClockInTime');
//     debugPrint('⏰ [OT SERVICE] Is restored   : ${restoredClockInTime != null}');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('');
//
//     // Clock-in time SharedPreferences mein save karo (restore ke liye)
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(
//         _keyOtClockInTime,
//         _overtimeClockInTime!.toIso8601String(),
//       );
//       debugPrint('💾 [OT SERVICE] Clock-in time saved to prefs: ${_overtimeClockInTime!.toIso8601String()}');
//     } catch (e) {
//       debugPrint('⚠️ [OT SERVICE] Failed to save clock-in time: $e');
//     }
//
//     // ── Kotlin OvertimeMonitorService ko directly start karo ───────────────
//     // Background + app-killed teeno cases mein Dart Timer kaam nahi karta.
//     // Kotlin foreground service + AlarmManager yeh handle karta hai.
//     // Directly start karo taake timer_card ka invokeMethod pe depend na karna pade.
//     _startKotlinOvertimeService();
//
//     // ── Initial fetch + countdown set ──────────────────────────────────────
//     await _fetchAndReschedule(onOvertimeExpired);
//
//     // ── Live re-fetch har 1 min ─────────────────────────────────────────────
//     _liveFetchTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
//       if (!_isRunning) {
//         _liveFetchTimer?.cancel();
//         return;
//       }
//       debugPrint('🔄 [OT SERVICE] ── Live fetch tick (5-min) ─────────────────────');
//       await _fetchAndReschedule(onOvertimeExpired);
//     });
//
//     debugPrint('✅ [OT SERVICE] Live re-fetch timer started (every 5 min)');
//   }
//
//   /// Saari timers cancel karo aur state clear karo.
//   Future<void> cancel({bool clearPrefs = true}) async {
//     _isRunning = false;
//     _countdownTimer?.cancel();
//     _countdownTimer = null;
//     _liveFetchTimer?.cancel();
//     _liveFetchTimer = null;
//     _overtimeClockInTime   = null;
//     _currentOtCapMinutes   = 0;
//
//     // ── Kotlin OvertimeMonitorService stop karo ─────────────────────────────
//     _stopKotlinOvertimeService();
//
//     if (clearPrefs) {
//       try {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.remove(_keyOtClockInTime);
//         await prefs.remove(_keyOtEndTime);
//         debugPrint('🧹 [OT SERVICE] Cancelled — prefs keys "$_keyOtClockInTime" & "$_keyOtEndTime" removed');
//       } catch (e) {
//         debugPrint('⚠️ [OT SERVICE] Prefs remove error on cancel: $e');
//       }
//     }
//
//     debugPrint('🛑 [OT SERVICE] Service cancelled (clearPrefs=$clearPrefs)');
//   }
//
//   /// App kill/restart ke baad check karo kya overtime session restore karna hai.
//   /// Returns saved clock-in DateTime if a session was active, otherwise null.
//   static Future<DateTime?> getSavedOvertimeClockInTime() async {
//     try {
//       final prefs  = await SharedPreferences.getInstance();
//       final String? saved = prefs.getString(_keyOtClockInTime);
//       if (saved == null || saved.isEmpty) {
//         debugPrint('📦 [OT SERVICE] getSavedOvertimeClockInTime: no saved session');
//         return null;
//       }
//       final DateTime? dt = DateTime.tryParse(saved);
//       debugPrint('📦 [OT SERVICE] getSavedOvertimeClockInTime: "$saved" → $dt');
//       return dt;
//     } catch (e) {
//       debugPrint('❌ [OT SERVICE] getSavedOvertimeClockInTime error: $e');
//       return null;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // PRIVATE: Fetch cap then reschedule countdown timer
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _fetchAndReschedule(OvertimeExpiredCallback onOvertimeExpired) async {
//     debugPrint('');
//     debugPrint('── [OT SERVICE] _fetchAndReschedule() START ───────────────────');
//
//     final int? capMinutes = await _fetchOtCapMinutes();
//
//     if (capMinutes == null) {
//       debugPrint('⚠️ [OT SERVICE] API returned null — keeping current timer unchanged');
//       debugPrint('   [OT SERVICE] Will retry on next 5-min live-fetch tick');
//       debugPrint('── [OT SERVICE] _fetchAndReschedule() END (no-op) ─────────────');
//       debugPrint('');
//       return;
//     }
//
//     // Backend ne naya value diya — log change
//     if (_currentOtCapMinutes != capMinutes) {
//       debugPrint('📢 [OT SERVICE] Cap CHANGED: ${_currentOtCapMinutes}min → ${capMinutes}min');
//     }
//     _currentOtCapMinutes = capMinutes;
//
//     final DateTime clockInTime = _overtimeClockInTime ?? DateTime.now();
//     final DateTime endTime     = clockInTime.add(Duration(minutes: capMinutes));
//     final Duration remaining   = endTime.difference(DateTime.now());
//
//     // ── OT end time prefs mein save karo — Kotlin AlarmManager (kill-safe) isi ko padh ke
//     //    exact RTC_WAKEUP alarm set karta hai. Format: ISO-8601 string.
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(_keyOtEndTime, endTime.toIso8601String());
//       debugPrint('💾 [OT SERVICE] OT end time saved to prefs (for Kotlin alarm): ${endTime.toIso8601String()}');
//     } catch (e) {
//       debugPrint('⚠️ [OT SERVICE] Failed to save OT end time: $e');
//     }
//
//     debugPrint('⏰ [OT SERVICE] Cap         : ${capMinutes}min');
//     debugPrint('⏰ [OT SERVICE] Clock-in    : $clockInTime');
//     debugPrint('⏰ [OT SERVICE] OT ends at  : $endTime');
//     debugPrint('⏰ [OT SERVICE] Remaining   : ${remaining.inMinutes}min ${remaining.inSeconds.remainder(60)}s');
//
//     // Agar already expire ho chuka
//     if (remaining.inSeconds <= 0) {
//       debugPrint('🔴 [OT SERVICE] Overtime ALREADY expired → firing callback immediately');
//       debugPrint('── [OT SERVICE] _fetchAndReschedule() END (expired) ───────────');
//       debugPrint('');
//       _isRunning = false;
//       _countdownTimer?.cancel();
//       _liveFetchTimer?.cancel();
//       await onOvertimeExpired();
//       return;
//     }
//
//     // Purana countdown cancel karo, naya set karo
//     _countdownTimer?.cancel();
//     _countdownTimer = Timer(remaining, () async {
//       debugPrint('');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('⏰ [OT SERVICE] ===== OVERTIME CAP EXPIRED =====');
//       debugPrint('⏰ [OT SERVICE] Cap was: ${capMinutes}min');
//       debugPrint('⏰ [OT SERVICE] Fired at: ${DateTime.now()}');
//       debugPrint('⏰ [OT SERVICE] Calling onOvertimeExpired() callback...');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       _isRunning = false;
//       _liveFetchTimer?.cancel();
//       await onOvertimeExpired();
//     });
//
//     debugPrint('✅ [OT SERVICE] Countdown timer SET → fires in '
//         '${remaining.inMinutes}min ${remaining.inSeconds.remainder(60)}s '
//         '(at $endTime)');
//     debugPrint('── [OT SERVICE] _fetchAndReschedule() END ─────────────────────');
//     debugPrint('');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // PRIVATE: Kotlin OvertimeMonitorService directly start/stop
//   // ──────────────────────────────────────────────────────────────────────────
//   // Yeh directly Android platform channel se service start karta hai.
//   // timer_card.dart ka invokeMethod('startOvertimeMonitor') additional call hai —
//   // yeh method ensure karta hai ke service ZAROOR start ho, chahe invokeMethod
//   // kaam kare ya na kare (MainActivity not ready, MissingPluginException etc.)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   static const _platform = MethodChannel('com.metaxperts.bookdispatch/location_monitor');
//
//   void _startKotlinOvertimeService() {
//     Future.microtask(() async {
//       try {
//         await _platform.invokeMethod('startOvertimeMonitor');
//         debugPrint('✅ [OT SERVICE] Kotlin OvertimeMonitorService started via platform channel');
//       } on MissingPluginException {
//         debugPrint('ℹ️ [OT SERVICE] Platform channel not available — Kotlin service not started');
//       } catch (e) {
//         debugPrint('⚠️ [OT SERVICE] Could not start Kotlin OvertimeMonitorService: $e');
//       }
//     });
//   }
//
//   void _stopKotlinOvertimeService() {
//     Future.microtask(() async {
//       try {
//         await _platform.invokeMethod('stopOvertimeMonitor');
//         debugPrint('🛑 [OT SERVICE] Kotlin OvertimeMonitorService stopped via platform channel');
//       } on MissingPluginException {
//         debugPrint('ℹ️ [OT SERVICE] Platform channel not available — Kotlin stop skipped');
//       } catch (e) {
//         debugPrint('⚠️ [OT SERVICE] Could not stop Kotlin OvertimeMonitorService: $e');
//       }
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // PRIVATE: HTTP GET → DAILY_OT_CAP in minutes (null on any failure)
//   //
//   // API   : GET http://oracle.metaxperts.net/ords/gps_workforce/maxot/get
//   // Param : dep_id  (SharedPreferences key: 'cached_dep_id')
//   //
//   // ORDS response:
//   //   {
//   //     "items": [{ "DAILY_OT_CAP": 2 }],
//   //     "hasMore": false,
//   //     "limit": 25, "offset": 0, "count": 1
//   //   }
//   //
//   // DAILY_OT_CAP = hours  →  minutes = DAILY_OT_CAP × 60
//   // ══════════════════════════════════════════════════════════════════════════
//
//   // SharedPreferences key — API response store karne ke liye (dep_id wise)
//   static const String _keyOtApiResponse = 'cached_ot_cap_api_response';
//
//   // SharedPreferences key — OT session end time (Kotlin AlarmManager reads this for kill-safe alarm)
//   static const String _keyOtEndTime = 'overtime_session_end_time';
//
//   Future<int?> _fetchOtCapMinutes() async {
//     try {
//       final prefs  = await SharedPreferences.getInstance();
//       final String depId = (prefs.getString('cached_dep_id') ?? '').trim();
//
//       debugPrint('');
//       debugPrint('🌐 [OT SERVICE] _fetchOtCapMinutes() ─────────────────────────');
//       debugPrint('🌐 [OT SERVICE] dep_id from prefs = "$depId"');
//
//       // ── Print ALL currently stored SharedPreferences ──────────────────────
//       debugPrint('📋 [OT SERVICE] ── Stored SharedPreferences (all keys) ───────');
//       for (final key in prefs.getKeys()) {
//         debugPrint('   [OT SERVICE] PREF  $key = ${prefs.get(key)}');
//       }
//       debugPrint('📋 [OT SERVICE] ────────────────────────────────────────────');
//
//       if (depId.isEmpty) {
//         debugPrint('❌ [OT SERVICE] dep_id is EMPTY — cannot call API');
//         debugPrint('   [OT SERVICE] Ensure "cached_dep_id" is saved at login time');
//         debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//         debugPrint('');
//         return null;
//       }
//
//       final Uri uri = Uri.parse(_apiUrl).replace(
//         queryParameters: {'dep_id': depId},
//       );
//
//       debugPrint('🌐 [OT SERVICE] Fetching OT cap for dep_id = "$depId"');
//       debugPrint('🌐 [OT SERVICE] Request URL : $uri');
//
//       final http.Response response = await http
//           .get(uri, headers: {'Accept': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('🌐 [OT SERVICE] HTTP status : ${response.statusCode}');
//       debugPrint('📦 [OT SERVICE] Raw body    : ${response.body}');
//
//       if (response.statusCode != 200) {
//         debugPrint('❌ [OT SERVICE] Non-200 response — returning null');
//         debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//         debugPrint('');
//         return null;
//       }
//
//       // ── API response SharedPreferences mein store karo (dep_id wise key) ──
//       final String responseKey = '${_keyOtApiResponse}_dep_$depId';
//       await prefs.setString(responseKey, response.body);
//       debugPrint('💾 [OT SERVICE] API response stored in prefs');
//       debugPrint('💾 [OT SERVICE] Prefs key   : "$responseKey"');
//       debugPrint('💾 [OT SERVICE] Stored value: ${prefs.getString(responseKey)}');
//
//       final dynamic decoded = jsonDecode(response.body);
//
//       // ── Parse DAILY_OT_CAP ────────────────────────────────────────────────
//       dynamic capRaw;
//
//       // Helper: case-insensitive key lookup (API uppercase ya lowercase dono handle karo)
//       dynamic getCapKey(Map<String, dynamic> map) =>
//           map['DAILY_OT_CAP'] ?? map['daily_ot_cap'];
//
//       if (decoded is Map<String, dynamic>) {
//         // ORDS standard: { "items": [...], "hasMore": ... }
//         final dynamic items = decoded['items'];
//         if (items is List && items.isNotEmpty && items.first is Map<String, dynamic>) {
//           capRaw = getCapKey(items.first as Map<String, dynamic>);
//           debugPrint('📦 [OT SERVICE] Parsed from items[0].daily_ot_cap = $capRaw');
//         } else {
//           // Flat map fallback
//           capRaw = getCapKey(decoded);
//           debugPrint('📦 [OT SERVICE] Parsed from flat map.daily_ot_cap = $capRaw');
//         }
//       } else if (decoded is List && decoded.isNotEmpty) {
//         // Bare array fallback
//         capRaw = getCapKey(decoded.first as Map<String, dynamic>);
//         debugPrint('📦 [OT SERVICE] Parsed from array[0].daily_ot_cap = $capRaw');
//       }
//
//       if (capRaw == null) {
//         debugPrint('❌ [OT SERVICE] DAILY_OT_CAP key NOT FOUND in response');
//         debugPrint('   [OT SERVICE] Full decoded: $decoded');
//         debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//         debugPrint('');
//         return null;
//       }
//
//       // DAILY_OT_CAP = hours → convert to minutes
//       final double capHours   = double.tryParse(capRaw.toString()) ?? 0.0;
//       final int    capMinutes = (capHours * 60).toInt();
//
//       debugPrint('✅ [OT SERVICE] DAILY_OT_CAP = $capHours hours = $capMinutes minutes');
//       debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//       debugPrint('');
//
//       return capMinutes > 0 ? capMinutes : null;
//
//     } on TimeoutException {
//       debugPrint('❌ [OT SERVICE] API request TIMED OUT (15s)');
//       debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//       debugPrint('');
//       return null;
//     } catch (e, stack) {
//       debugPrint('❌ [OT SERVICE] Unexpected error: $e');
//       debugPrint('❌ [OT SERVICE] Stack trace: $stack');
//       debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
//       debugPrint('');
//       return null;
//     }
//   }
// }


///fireabse
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/remote_config_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// OvertimeClockOutService
// ════════════════════════════════════════════════════════════════════════════
//
// PURPOSE:
//   Jab overtime=yes wala user apni shift end ke baad dobara clock-in kare,
//   yeh service:
//     1. Backend API se DAILY_OT_CAP (hours) fetch karti hai
//     2. Har 5 minute mein live re-fetch karti hai (backend change detect)
//     3. DAILY_OT_CAP expire hone par onOvertimeExpired() callback fire karta hai
//        → timer_card.dart us callback mein auto clock-out trigger karta hai
//
// API:
//   GET http://oracle.metaxperts.net/ords/gps_workforce/maxot/get?dep_id=XXX
//   DB:  SELECT DAILY_OT_CAP FROM OVERTIME_SCHEDULE WHERE dep_id = :dep_id
//   Response (ORDS format):
//     { "items": [{ "DAILY_OT_CAP": 2 }], "hasMore": false, ... }
//   DAILY_OT_CAP = hours (e.g. 2 = 2 hours = 120 minutes)
//
// USAGE in timer_card.dart:
//   final OvertimeClockOutService _overtimeService = OvertimeClockOutService();
//
//   // Overtime clock-in detect hone par:
//   await _overtimeService.start(onOvertimeExpired: _triggerOvertimeClockOut);
//
//   // Clock-out / dispose par:
//   await _overtimeService.cancel();
//
//   // App kill / resume restore par:
//   final saved = await OvertimeClockOutService.getSavedOvertimeClockInTime();
//   if (saved != null) {
//     await _overtimeService.start(
//       onOvertimeExpired: _triggerOvertimeClockOut,
//       restoredClockInTime: saved,
//     );
//   }
// ════════════════════════════════════════════════════════════════════════════

typedef OvertimeExpiredCallback = Future<void> Function();

class OvertimeClockOutService {

  // ── SharedPreferences key — saved so timer survives app kill/restart ──────
  static const String _keyOtClockInTime = 'overtime_session_clock_in_time';

  // ── Internal state ────────────────────────────────────────────────────────
  Timer?    _countdownTimer;        // fires when OT cap expires
  Timer?    _liveFetchTimer;        // re-fetches API every 5 min
  DateTime? _overtimeClockInTime;   // timestamp of overtime clock-in
  int       _currentOtCapMinutes = 0;
  bool      _isRunning = false;

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  /// Overtime session start karo.
  /// [restoredClockInTime] — app kill ke baad restore karte waqt purana time pass karo.
  Future<void> start({
    required OvertimeExpiredCallback onOvertimeExpired,
    DateTime? restoredClockInTime,
  }) async {
    // Pehle koi purana session cancel karo
    await cancel(clearPrefs: false);

    _isRunning           = true;
    _overtimeClockInTime = restoredClockInTime ?? DateTime.now();

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('⏰ [OT SERVICE] ===== OVERTIME SESSION STARTED =====');
    debugPrint('⏰ [OT SERVICE] Clock-in time : $_overtimeClockInTime');
    debugPrint('⏰ [OT SERVICE] Is restored   : ${restoredClockInTime != null}');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    // Clock-in time SharedPreferences mein save karo (restore ke liye)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyOtClockInTime,
        _overtimeClockInTime!.toIso8601String(),
      );
      debugPrint('💾 [OT SERVICE] Clock-in time saved to prefs: ${_overtimeClockInTime!.toIso8601String()}');
    } catch (e) {
      debugPrint('⚠️ [OT SERVICE] Failed to save clock-in time: $e');
    }

    // ── Kotlin OvertimeMonitorService ko directly start karo ───────────────
    // Background + app-killed teeno cases mein Dart Timer kaam nahi karta.
    // Kotlin foreground service + AlarmManager yeh handle karta hai.
    // Directly start karo taake timer_card ka invokeMethod pe depend na karna pade.
    _startKotlinOvertimeService();

    // ── Initial fetch + countdown set ──────────────────────────────────────
    await _fetchAndReschedule(onOvertimeExpired);

    // ── Live re-fetch har 1 min ─────────────────────────────────────────────
    _liveFetchTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_isRunning) {
        _liveFetchTimer?.cancel();
        return;
      }
      debugPrint('🔄 [OT SERVICE] ── Live fetch tick (5-min) ─────────────────────');
      await _fetchAndReschedule(onOvertimeExpired);
    });

    debugPrint('✅ [OT SERVICE] Live re-fetch timer started (every 5 min)');
  }

  /// Saari timers cancel karo aur state clear karo.
  Future<void> cancel({bool clearPrefs = true}) async {
    _isRunning = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _liveFetchTimer?.cancel();
    _liveFetchTimer = null;
    _overtimeClockInTime   = null;
    _currentOtCapMinutes   = 0;

    // ── Kotlin OvertimeMonitorService stop karo ─────────────────────────────
    _stopKotlinOvertimeService();

    if (clearPrefs) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyOtClockInTime);
        await prefs.remove(_keyOtEndTime);
        debugPrint('🧹 [OT SERVICE] Cancelled — prefs keys "$_keyOtClockInTime" & "$_keyOtEndTime" removed');
      } catch (e) {
        debugPrint('⚠️ [OT SERVICE] Prefs remove error on cancel: $e');
      }
    }

    debugPrint('🛑 [OT SERVICE] Service cancelled (clearPrefs=$clearPrefs)');
  }

  /// App kill/restart ke baad check karo kya overtime session restore karna hai.
  /// Returns saved clock-in DateTime if a session was active, otherwise null.
  static Future<DateTime?> getSavedOvertimeClockInTime() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_keyOtClockInTime);
      if (saved == null || saved.isEmpty) {
        debugPrint('📦 [OT SERVICE] getSavedOvertimeClockInTime: no saved session');
        return null;
      }
      final DateTime? dt = DateTime.tryParse(saved);
      debugPrint('📦 [OT SERVICE] getSavedOvertimeClockInTime: "$saved" → $dt');
      return dt;
    } catch (e) {
      debugPrint('❌ [OT SERVICE] getSavedOvertimeClockInTime error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE: Fetch cap then reschedule countdown timer
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchAndReschedule(OvertimeExpiredCallback onOvertimeExpired) async {
    debugPrint('');
    debugPrint('── [OT SERVICE] _fetchAndReschedule() START ───────────────────');

    final int? capMinutes = await _fetchOtCapMinutes();

    if (capMinutes == null) {
      debugPrint('⚠️ [OT SERVICE] API returned null — keeping current timer unchanged');
      debugPrint('   [OT SERVICE] Will retry on next 5-min live-fetch tick');
      debugPrint('── [OT SERVICE] _fetchAndReschedule() END (no-op) ─────────────');
      debugPrint('');
      return;
    }

    // Backend ne naya value diya — log change
    if (_currentOtCapMinutes != capMinutes) {
      debugPrint('📢 [OT SERVICE] Cap CHANGED: ${_currentOtCapMinutes}min → ${capMinutes}min');
    }
    _currentOtCapMinutes = capMinutes;

    final DateTime clockInTime = _overtimeClockInTime ?? DateTime.now();
    final DateTime endTime     = clockInTime.add(Duration(minutes: capMinutes));
    final Duration remaining   = endTime.difference(DateTime.now());

    // ── OT end time prefs mein save karo — Kotlin AlarmManager (kill-safe) isi ko padh ke
    //    exact RTC_WAKEUP alarm set karta hai. Format: ISO-8601 string.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyOtEndTime, endTime.toIso8601String());
      debugPrint('💾 [OT SERVICE] OT end time saved to prefs (for Kotlin alarm): ${endTime.toIso8601String()}');
    } catch (e) {
      debugPrint('⚠️ [OT SERVICE] Failed to save OT end time: $e');
    }

    debugPrint('⏰ [OT SERVICE] Cap         : ${capMinutes}min');
    debugPrint('⏰ [OT SERVICE] Clock-in    : $clockInTime');
    debugPrint('⏰ [OT SERVICE] OT ends at  : $endTime');
    debugPrint('⏰ [OT SERVICE] Remaining   : ${remaining.inMinutes}min ${remaining.inSeconds.remainder(60)}s');

    // Agar already expire ho chuka
    if (remaining.inSeconds <= 0) {
      debugPrint('🔴 [OT SERVICE] Overtime ALREADY expired → firing callback immediately');
      debugPrint('── [OT SERVICE] _fetchAndReschedule() END (expired) ───────────');
      debugPrint('');
      _isRunning = false;
      _countdownTimer?.cancel();
      _liveFetchTimer?.cancel();
      await onOvertimeExpired();
      return;
    }

    // Purana countdown cancel karo, naya set karo
    _countdownTimer?.cancel();
    _countdownTimer = Timer(remaining, () async {
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('⏰ [OT SERVICE] ===== OVERTIME CAP EXPIRED =====');
      debugPrint('⏰ [OT SERVICE] Cap was: ${capMinutes}min');
      debugPrint('⏰ [OT SERVICE] Fired at: ${DateTime.now()}');
      debugPrint('⏰ [OT SERVICE] Calling onOvertimeExpired() callback...');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      _isRunning = false;
      _liveFetchTimer?.cancel();
      await onOvertimeExpired();
    });

    debugPrint('✅ [OT SERVICE] Countdown timer SET → fires in '
        '${remaining.inMinutes}min ${remaining.inSeconds.remainder(60)}s '
        '(at $endTime)');
    debugPrint('── [OT SERVICE] _fetchAndReschedule() END ─────────────────────');
    debugPrint('');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE: Kotlin OvertimeMonitorService directly start/stop
  // ──────────────────────────────────────────────────────────────────────────
  // Yeh directly Android platform channel se service start karta hai.
  // timer_card.dart ka invokeMethod('startOvertimeMonitor') additional call hai —
  // yeh method ensure karta hai ke service ZAROOR start ho, chahe invokeMethod
  // kaam kare ya na kare (MainActivity not ready, MissingPluginException etc.)
  // ══════════════════════════════════════════════════════════════════════════

  static const _platform = MethodChannel('com.metaxperts.bookdispatch/location_monitor');

  void _startKotlinOvertimeService() {
    Future.microtask(() async {
      try {
        await _platform.invokeMethod('startOvertimeMonitor');
        debugPrint('✅ [OT SERVICE] Kotlin OvertimeMonitorService started via platform channel');
      } on MissingPluginException {
        debugPrint('ℹ️ [OT SERVICE] Platform channel not available — Kotlin service not started');
      } catch (e) {
        debugPrint('⚠️ [OT SERVICE] Could not start Kotlin OvertimeMonitorService: $e');
      }
    });
  }

  void _stopKotlinOvertimeService() {
    Future.microtask(() async {
      try {
        await _platform.invokeMethod('stopOvertimeMonitor');
        debugPrint('🛑 [OT SERVICE] Kotlin OvertimeMonitorService stopped via platform channel');
      } on MissingPluginException {
        debugPrint('ℹ️ [OT SERVICE] Platform channel not available — Kotlin stop skipped');
      } catch (e) {
        debugPrint('⚠️ [OT SERVICE] Could not stop Kotlin OvertimeMonitorService: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE: HTTP GET → DAILY_OT_CAP in minutes (null on any failure)
  //
  // API   : GET http://oracle.metaxperts.net/ords/gps_workforce/maxot/get
  // Param : dep_id  (SharedPreferences key: 'cached_dep_id')
  //
  // ORDS response:
  //   {
  //     "items": [{ "DAILY_OT_CAP": 2 }],
  //     "hasMore": false,
  //     "limit": 25, "offset": 0, "count": 1
  //   }
  //
  // DAILY_OT_CAP = hours  →  minutes = DAILY_OT_CAP × 60
  // ══════════════════════════════════════════════════════════════════════════

  // SharedPreferences key — API response store karne ke liye (dep_id wise)
  static const String _keyOtApiResponse = 'cached_ot_cap_api_response';

  // SharedPreferences key — OT session end time (Kotlin AlarmManager reads this for kill-safe alarm)
  static const String _keyOtEndTime = 'overtime_session_end_time';

  Future<int?> _fetchOtCapMinutes() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final String depId = (prefs.getString('cached_dep_id') ?? '').trim();

      debugPrint('');
      debugPrint('🌐 [OT SERVICE] _fetchOtCapMinutes() ─────────────────────────');
      debugPrint('🌐 [OT SERVICE] dep_id from prefs = "$depId"');

      // ── Print ALL currently stored SharedPreferences ──────────────────────
      debugPrint('📋 [OT SERVICE] ── Stored SharedPreferences (all keys) ───────');
      for (final key in prefs.getKeys()) {
        debugPrint('   [OT SERVICE] PREF  $key = ${prefs.get(key)}');
      }
      debugPrint('📋 [OT SERVICE] ────────────────────────────────────────────');

      if (depId.isEmpty) {
        debugPrint('❌ [OT SERVICE] dep_id is EMPTY — cannot call API');
        debugPrint('   [OT SERVICE] Ensure "cached_dep_id" is saved at login time');
        debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
        debugPrint('');
        return null;
      }

      final Uri uri = Uri.parse(RemoteConfigService.getMaxOtUrl(depId));

      debugPrint('🌐 [OT SERVICE] Fetching OT cap for dep_id = "$depId"');
      debugPrint('🌐 [OT SERVICE] Request URL : $uri');

      final http.Response response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('🌐 [OT SERVICE] HTTP status : ${response.statusCode}');
      debugPrint('📦 [OT SERVICE] Raw body    : ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('❌ [OT SERVICE] Non-200 response — returning null');
        debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
        debugPrint('');
        return null;
      }

      // ── API response SharedPreferences mein store karo (dep_id wise key) ──
      final String responseKey = '${_keyOtApiResponse}_dep_$depId';
      await prefs.setString(responseKey, response.body);
      debugPrint('💾 [OT SERVICE] API response stored in prefs');
      debugPrint('💾 [OT SERVICE] Prefs key   : "$responseKey"');
      debugPrint('💾 [OT SERVICE] Stored value: ${prefs.getString(responseKey)}');

      final dynamic decoded = jsonDecode(response.body);

      // ── Parse DAILY_OT_CAP ────────────────────────────────────────────────
      dynamic capRaw;

      // Helper: case-insensitive key lookup (API uppercase ya lowercase dono handle karo)
      dynamic getCapKey(Map<String, dynamic> map) =>
          map['DAILY_OT_CAP'] ?? map['daily_ot_cap'];

      if (decoded is Map<String, dynamic>) {
        // ORDS standard: { "items": [...], "hasMore": ... }
        final dynamic items = decoded['items'];
        if (items is List && items.isNotEmpty && items.first is Map<String, dynamic>) {
          capRaw = getCapKey(items.first as Map<String, dynamic>);
          debugPrint('📦 [OT SERVICE] Parsed from items[0].daily_ot_cap = $capRaw');
        } else {
          // Flat map fallback
          capRaw = getCapKey(decoded);
          debugPrint('📦 [OT SERVICE] Parsed from flat map.daily_ot_cap = $capRaw');
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        // Bare array fallback
        capRaw = getCapKey(decoded.first as Map<String, dynamic>);
        debugPrint('📦 [OT SERVICE] Parsed from array[0].daily_ot_cap = $capRaw');
      }

      if (capRaw == null) {
        debugPrint('❌ [OT SERVICE] DAILY_OT_CAP key NOT FOUND in response');
        debugPrint('   [OT SERVICE] Full decoded: $decoded');
        debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
        debugPrint('');
        return null;
      }

      // DAILY_OT_CAP = hours → convert to minutes
      final double capHours   = double.tryParse(capRaw.toString()) ?? 0.0;
      final int    capMinutes = (capHours * 60).toInt();

      debugPrint('✅ [OT SERVICE] DAILY_OT_CAP = $capHours hours = $capMinutes minutes');
      debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
      debugPrint('');

      return capMinutes > 0 ? capMinutes : null;

    } on TimeoutException {
      debugPrint('❌ [OT SERVICE] API request TIMED OUT (15s)');
      debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
      debugPrint('');
      return null;
    } catch (e, stack) {
      debugPrint('❌ [OT SERVICE] Unexpected error: $e');
      debugPrint('❌ [OT SERVICE] Stack trace: $stack');
      debugPrint('🌐 [OT SERVICE] ─────────────────────────────────────────────');
      debugPrint('');
      return null;
    }
  }
}