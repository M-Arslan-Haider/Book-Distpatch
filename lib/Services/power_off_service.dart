// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// class PowerOffService {
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/';
//
//   // ✅ These keys match PowerOffReceiver.kt (NO "flutter." prefix)
//   static const String _keyPowerOff = 'pending_power_off';
//   static const String _keyPowerOffTime = 'pending_power_off_time';
//   static const String _keyLastActive = 'last_active_time';
//
//   /// Har 60 second mein call karo — timer_card se
//   static Future<void> saveLastActiveTime() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final now = DateTime.now();
//       final time =
//           '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
//           'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
//       await prefs.setString(_keyLastActive, time);
//       debugPrint('[PowerOff] last_active_time saved: $time');
//     } catch (e) {
//       debugPrint('[PowerOff] saveLastActiveTime error: $e');
//     }
//   }
//
//   static Future<void> checkAndPostPowerOffEvent() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.reload();
//
//       final pendingJson = prefs.getString(_keyPowerOff);
//
//       if (pendingJson == null || pendingJson.isEmpty) {
//         debugPrint('[PowerOff] No pending power off event.');
//         return;
//       }
//
//       debugPrint('[PowerOff] Pending event found: $pendingJson');
//
//       final Map<String, dynamic> data = jsonDecode(pendingJson);
//
//       // event_time = exact power off (shutdown) waqt
//       final storedPowerOffTime = prefs.getString(_keyPowerOffTime);
//       if (storedPowerOffTime != null && storedPowerOffTime.isNotEmpty) {
//         data['event_time'] = storedPowerOffTime;
//         debugPrint('[PowerOff] event_time set to stored time: $storedPowerOffTime');
//       }
//
//       // ✅ synced_time = abhi ka waqt, jab app open hoke sync/post kar raha hai
//       final now = DateTime.now();
//       final syncedTime =
//           '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
//           'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
//       data['synced_time'] = syncedTime;
//       debugPrint('[PowerOff] synced_time set to: $syncedTime');
//
//       final response = await http
//           .post(
//         Uri.parse('${_baseUrl}gpspoweroffevent/post/'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(data),
//       )
//           .timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('[PowerOff] Posted successfully → HTTP ${response.statusCode}');
//         await prefs.remove(_keyPowerOff);
//         await prefs.remove(_keyPowerOffTime);
//         await prefs.remove(_keyLastActive);
//         debugPrint('[PowerOff] Local pending event cleared.');
//       } else {
//         debugPrint('[PowerOff] Server error → HTTP ${response.statusCode}. Will retry next open.');
//       }
//     } catch (e) {
//       debugPrint('[PowerOff] checkAndPostPowerOffEvent error: $e');
//     }
//   }
// }


import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../Database/db_helper.dart';

class PowerOffService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/';

  // Bridge keys — written once by PowerOffReceiver.kt (native side) or by
  // _capturePendingShutdownTime() in main.dart. These are only read ONCE,
  // moved into the local DB, then cleared. The DB — not SharedPreferences —
  // is now the source of truth for retry/offline safety.
  static const String _keyPowerOff = 'pending_power_off';
  static const String _keyPowerOffTime = 'pending_power_off_time';
  static const String _keyLastActive = 'last_active_time';

  static StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Call once (e.g. from main()) to auto-sync pending power-off events the
  /// moment connectivity is restored — not just on app start.
  static void startConnectivityListener() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet) {
        debugPrint('[PowerOff] Connectivity restored — attempting sync...');
        await syncPendingPowerOffEvents();
      }
    });
  }

  /// Har 60 second mein call karo — timer_card se
  static Future<void> saveLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final time = _fmt(now);
      await prefs.setString(_keyLastActive, time);
      debugPrint('[PowerOff] last_active_time saved: $time');
    } catch (e) {
      debugPrint('[PowerOff] saveLastActiveTime error: $e');
    }
  }

  /// Step 1: Move whatever the native PowerOffReceiver left in
  /// SharedPreferences into the local DB (durable, queryable, retry-safe).
  /// Safe to call anytime — no-op if there's nothing pending.
  static Future<void> migratePendingEventToDb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final pendingJson = prefs.getString(_keyPowerOff);
      if (pendingJson == null || pendingJson.isEmpty) {
        return;
      }

      debugPrint('[PowerOff] Found pending bridge event: $pendingJson');

      final Map<String, dynamic> data = jsonDecode(pendingJson);

      // event_time = exact power-off (shutdown) moment. Prefer the dedicated
      // stored time key, fall back to whatever was embedded in the JSON.
      final storedTime = prefs.getString(_keyPowerOffTime);
      final eventTime = (storedTime != null && storedTime.isNotEmpty)
          ? storedTime
          : (data['event_time']?.toString() ?? _fmt(DateTime.now()));

      final empId = data['emp_id']?.toString() ?? '';
      final empName = data['emp_name']?.toString() ?? '';
      final companyCode = data['company_code']?.toString() ?? '';

      if (empId.isEmpty) {
        debugPrint('[PowerOff] emp_id empty — discarding bridge event');
      } else {
        await DBHelper().insertPowerOffEvent(
          empId: empId,
          empName: empName,
          companyCode: companyCode,
          eventTime: eventTime,
        );
        debugPrint('[PowerOff] Migrated to DB → empId=$empId eventTime=$eventTime');
      }

      // Clear the bridge keys now that it's safely in the DB.
      await prefs.remove(_keyPowerOff);
      await prefs.remove(_keyPowerOffTime);
      await prefs.remove(_keyLastActive);
    } catch (e) {
      debugPrint('[PowerOff] migratePendingEventToDb error: $e');
    }
  }

  /// Step 2: Post every unsynced DB row to the server. Rows that fail
  /// (offline, timeout, server error) simply stay unsynced and are retried
  /// next time this is called — from app start, connectivity-restore, or
  /// a periodic timer. event_time is NEVER overwritten; only synced_time
  /// and the synced flag change once a row is posted successfully.
  static Future<void> syncPendingPowerOffEvents() async {
    try {
      final db = DBHelper();
      final pending = await db.getPendingPowerOffEvents();

      if (pending.isEmpty) {
        debugPrint('[PowerOff] No pending power-off events to sync.');
        return;
      }

      debugPrint('[PowerOff] ${pending.length} pending power-off event(s) to sync.');

      for (final row in pending) {
        final id = row['id'] as int;
        final syncedTime = _fmt(DateTime.now());

        final payload = {
          'emp_id': row['emp_id'],
          'emp_name': row['emp_name'],
          'company_code': row['company_code'],
          'power_off': 'yes',
          'event_time': row['event_time'],
          'synced_time': syncedTime,
        };

        try {
          final response = await http
              .post(
            Uri.parse('${_baseUrl}gpspoweroffevent/post/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 || response.statusCode == 201) {
            await db.markPowerOffEventSynced(id, syncedTime);
            debugPrint('[PowerOff] id=$id synced OK → HTTP ${response.statusCode}');
          } else {
            debugPrint('[PowerOff] id=$id server error → HTTP ${response.statusCode}. Will retry.');
          }
        } catch (e) {
          debugPrint('[PowerOff] id=$id post failed (offline?): $e. Will retry.');
          // Stop trying the rest this round if we're clearly offline —
          // avoids burning through timeouts for every pending row.
          break;
        }
      }
    } catch (e) {
      debugPrint('[PowerOff] syncPendingPowerOffEvents error: $e');
    }
  }

  /// Convenience wrapper: migrate bridge event (if any) then attempt sync.
  /// Call this from app start, connectivity-restored callback, and any
  /// periodic background check.
  static Future<void> checkAndPostPowerOffEvent() async {
    await migratePendingEventToDb();
    await syncPendingPowerOffEvents();
  }

  static String _fmt(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}'
        'T${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }
}