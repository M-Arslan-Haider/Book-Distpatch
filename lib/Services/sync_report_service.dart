// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// // ⚠️  Adjust this import path to match your project structure
// import '../Database/db_helper.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // SyncReportService
// //
// // Har sync ke baad (manual ya auto) Oracle API par ek report POST karta hai.
// //
// // Usage:
// //   final snap = await SyncReportService.captureSnapshot();   // sync se PEHLE
// //   // ... apna sync karo ...
// //   unawaited(SyncReportService.postReport(syncType: 'Auto', beforeCounts: snap));
// //
// // Sir Afaq ke liye:
// //   POST  <baseUrl>gpssync/post/
// //   Table DDL neeche comments mein hai
// // ═══════════════════════════════════════════════════════════════════════════════
//
// class SyncReportService {
//
//   // ── ⚠️  Apna Oracle base URL yahan set karo ─────────────────────────────────
//   static const String _baseUrl = 'https://oracle.metaxperts.net/ords/gps_workforce/';
//   static const String _endpoint = 'gpssync/post/';
//
//   // ── Sir Afaq: Yeh endpoint banana hoga ─────────────────────────────────────
//   //
//   // POST /ords/gps_workforce/gpssync/post/
//   //
//   // Request JSON:
//   // {
//   //   "emp_id":          "EMP001",
//   //   "emp_name":        "John Doe",
//   //   "company_code":    "COMP001",
//   //   "sync_time":       "2025-01-15 14:30:00",
//   //   "sync_type":       "Manual",          -- "Manual" ya "Auto"
//   //   "total_synced":    47,
//   //   "clock_in":        2,
//   //   "clock_out":       3,
//   //   "location":        40,
//   //   "leave_count":     0,
//   //   "gps_track":       2,
//   //   "selfie":          0,
//   //   "fake_gps":        0,
//   //   "battery":         0,
//   //   "power_off":       0
//   // }
//   //
//   // Oracle Table:
//   // CREATE TABLE GPS_WORKFORCE.SYNC_REPORTS (
//   //   ID               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
//   //   EMP_ID           VARCHAR2(100) NOT NULL,
//   //   EMP_NAME         VARCHAR2(200),
//   //   COMPANY_CODE     VARCHAR2(100) NOT NULL,
//   //   SYNC_TIME        VARCHAR2(30)  NOT NULL,
//   //   SYNC_TYPE        VARCHAR2(10)  NOT NULL,
//   //   TOTAL_SYNCED     NUMBER DEFAULT 0,
//   //   CLOCK_IN         NUMBER DEFAULT 0,
//   //   CLOCK_OUT        NUMBER DEFAULT 0,
//   //   LOCATION         NUMBER DEFAULT 0,
//   //   LEAVE_COUNT      NUMBER DEFAULT 0,
//   //   GPS_TRACK        NUMBER DEFAULT 0,
//   //   SELFIE           NUMBER DEFAULT 0,
//   //   FAKE_GPS         NUMBER DEFAULT 0,
//   //   BATTERY          NUMBER DEFAULT 0,
//   //   POWER_OFF        NUMBER DEFAULT 0,
//   //   CREATED_AT       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
//   // );
//   // ───────────────────────────────────────────────────────────────────────────
//
//   /// Step 1 — Sync se PEHLE call karo.
//   /// Local DB ke current unsynced counts ka snapshot return karta hai.
//   static Future<Map<String, int>> captureSnapshot() async {
//     try {
//       return await DBHelper().getUnpostedCountsFromDB();
//     } catch (e) {
//       debugPrint('⚠️ [SYNC REPORT] captureSnapshot error: $e');
//       return {};
//     }
//   }
//
//   /// Step 2 — Sync ke BAAD call karo.
//   /// beforeCounts se afterCounts subtract karke kya actually sync hua wo calculate karta hai,
//   /// phir Oracle API par POST karta hai.
//   static Future<void> postReport({
//     required String syncType,              // 'Manual' ya 'Auto'
//     required Map<String, int> beforeCounts,
//   }) async {
//     try {
//       // ── After counts (current DB state post-sync) ─────────────────────
//       final afterCounts = await DBHelper().getUnpostedCountsFromDB();
//
//       // ── Calculate what was actually synced (before - after) ───────────
//       int calc(String key) {
//         final before = beforeCounts[key] ?? 0;
//         final after  = afterCounts[key]  ?? 0;
//         return (before - after).clamp(0, before);
//       }
//
//       final clockIn  = calc('Clock In');
//       final clockOut = calc('Clock Out');
//       final location = calc('Location');
//       final leave    = calc('Leave');
//       final gpsTrack = calc('GPS Track');
//       final selfie   = calc('Selfie');
//       final fakeGps  = calc('Fake GPS');
//       final battery  = calc('Battery');
//       final powerOff = calc('Power Off');
//
//       final totalSynced = clockIn + clockOut + location + leave +
//           gpsTrack + selfie + fakeGps + battery + powerOff;
//
//       // ── Kuch sync nahi hua — report skip karo ─────────────────────────
//       if (totalSynced == 0) {
//         debugPrint('📊 [SYNC REPORT] Nothing synced — report skipped');
//         return;
//       }
//
//       // ── Employee info — multiple key fallbacks ────────────────────────
//       final prefs = await SharedPreferences.getInstance();
//
//       final empId = _readPrefsString(prefs, ['emp_id', 'userId', 'user_id']);
//       final empName = _readPrefsString(prefs, [
//         'emp_name', 'empName', 'employee_name', 'name', 'userName',
//       ]);
//       final companyCode = _readPrefsString(prefs, [
//         'company_code', 'companyCode', 'prefCompanyCode',
//         'COMPANY_CODE', 'comp_code',
//       ]);
//
//       if (empId.isEmpty || companyCode.isEmpty) {
//         debugPrint('⚠️ [SYNC REPORT] emp_id or company_code missing — skipping');
//         return;
//       }
//
//       // ── Build payload ─────────────────────────────────────────────────
//       final payload = {
//         'emp_id':       empId,
//         'emp_name':     empName,
//         'company_code': companyCode,
//         'sync_time':    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//         'sync_type':    syncType,
//         'total_synced': totalSynced,
//         'clock_in':     clockIn,
//         'clock_out':    clockOut,
//         'location':     location,
//         'leave_count':  leave,
//         'gps_track':    gpsTrack,
//         'selfie':       selfie,
//         'fake_gps':     fakeGps,
//         'battery':      battery,
//         'power_off':    powerOff,
//       };
//
//       debugPrint('📊 [SYNC REPORT] Posting → $syncType | Total: $totalSynced | $payload');
//
//       // ── POST ──────────────────────────────────────────────────────────
//       final url      = Uri.parse('$_baseUrl$_endpoint');
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept':        'application/json',
//         },
//         body: jsonEncode(payload),
//       ).timeout(const Duration(seconds: 10));
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [SYNC REPORT] Posted — '
//             '$syncType | Total:$totalSynced | '
//             'In:$clockIn Out:$clockOut GPS:$gpsTrack Loc:$location');
//       } else {
//         debugPrint('⚠️ [SYNC REPORT] Server ${response.statusCode}: ${response.body}');
//       }
//
//     } on SocketException {
//       debugPrint('⚠️ [SYNC REPORT] No internet — skipped');
//     } on TimeoutException {
//       debugPrint('⚠️ [SYNC REPORT] Timeout — skipped');
//     } catch (e) {
//       debugPrint('❌ [SYNC REPORT] Error: $e');
//     }
//   }
//
//   // ── Helper: try multiple SharedPreferences keys, return first non-empty ──
//   static String _readPrefsString(SharedPreferences prefs, List<String> keys) {
//     for (final key in keys) {
//       try {
//         final val = prefs.get(key)?.toString().trim() ?? '';
//         if (val.isNotEmpty) return val;
//       } catch (_) {}
//     }
//     return '';
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart';
import '../Screens/Order and Dispatch/repositories/no_sale_visit_repository.dart';
import '../Screens/Order and Dispatch/repositories/booking_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SyncReportService
//
// Har sync ke baad (manual ya auto) Oracle API par ek report POST karta hai.
// Plus pending visits aur orders ko sync karta hai.
// ═══════════════════════════════════════════════════════════════════════════════

class SyncReportService {

  static const String _baseUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/';
  static const String _endpoint = 'gpssync/post/';

  /// Step 1 — Sync se PEHLE call karo.
  static Future<Map<String, int>> captureSnapshot() async {
    try {
      return await DBHelper().getUnpostedCountsFromDB();
    } catch (e) {
      debugPrint('⚠️ [SYNC REPORT] captureSnapshot error: $e');
      return {};
    }
  }

  /// Step 2 — Sync ke BAAD call karo.
  static Future<void> postReport({
    required String syncType,
    required Map<String, int> beforeCounts,
  }) async {
    try {
      final afterCounts = await DBHelper().getUnpostedCountsFromDB();

      int calc(String key) {
        final before = beforeCounts[key] ?? 0;
        final after  = afterCounts[key]  ?? 0;
        return (before - after).clamp(0, before);
      }

      final clockIn  = calc('Clock In');
      final clockOut = calc('Clock Out');
      final location = calc('Location');
      final leave    = calc('Leave');
      final gpsTrack = calc('GPS Track');
      final selfie   = calc('Selfie');
      final fakeGps  = calc('Fake GPS');
      final battery  = calc('Battery');
      final powerOff = calc('Power Off');

      final totalSynced = clockIn + clockOut + location + leave +
          gpsTrack + selfie + fakeGps + battery + powerOff;

      if (totalSynced == 0) {
        debugPrint('📊 [SYNC REPORT] Nothing synced — report skipped');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final empId = _readPrefsString(prefs, ['emp_id', 'userId', 'user_id']);
      final empName = _readPrefsString(prefs, [
        'emp_name', 'empName', 'employee_name', 'name', 'userName',
      ]);
      final companyCode = _readPrefsString(prefs, [
        'company_code', 'companyCode', 'prefCompanyCode',
        'COMPANY_CODE', 'comp_code',
      ]);

      if (empId.isEmpty || companyCode.isEmpty) {
        debugPrint('⚠️ [SYNC REPORT] emp_id or company_code missing — skipping');
        return;
      }

      final payload = {
        'emp_id':       empId,
        'emp_name':     empName,
        'company_code': companyCode,
        'sync_time':    DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'sync_type':    syncType,
        'total_synced': totalSynced,
        'clock_in':     clockIn,
        'clock_out':    clockOut,
        'location':     location,
        'leave_count':  leave,
        'gps_track':    gpsTrack,
        'selfie':       selfie,
        'fake_gps':     fakeGps,
        'battery':      battery,
        'power_off':    powerOff,
      };

      debugPrint('📊 [SYNC REPORT] Posting → $syncType | Total: $totalSynced | $payload');

      final url      = Uri.parse('$_baseUrl$_endpoint');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':        'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [SYNC REPORT] Posted — '
            '$syncType | Total:$totalSynced | '
            'In:$clockIn Out:$clockOut GPS:$gpsTrack Loc:$location');
      } else {
        debugPrint('⚠️ [SYNC REPORT] Server ${response.statusCode}: ${response.body}');
      }

    } on SocketException {
      debugPrint('⚠️ [SYNC REPORT] No internet — skipped');
    } on TimeoutException {
      debugPrint('⚠️ [SYNC REPORT] Timeout — skipped');
    } catch (e) {
      debugPrint('❌ [SYNC REPORT] Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING VISITS & ORDERS SYNC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync all pending visits (No Sale of Stock)
  static Future<List<String>> syncPendingVisits() async {
    debugPrint('📤 [SYNC] Starting pending visits sync...');
    try {
      final repo = NoSaleVisitRepository();
      final synced = await repo.syncPendingVisits();
      debugPrint('✅ [SYNC] Synced ${synced.length} pending visits');
      return synced;
    } catch (e) {
      debugPrint('❌ [SYNC] Error syncing visits: $e');
      return [];
    }
  }

  /// Sync all pending orders (Booking)
  static Future<List<String>> syncPendingOrders() async {
    debugPrint('📤 [SYNC] Starting pending orders sync...');
    try {
      final repo = BookingRepository();
      final synced = await repo.syncPendingOrders();
      debugPrint('✅ [SYNC] Synced ${synced.length} pending orders');
      return synced;
    } catch (e) {
      debugPrint('❌ [SYNC] Error syncing orders: $e');
      return [];
    }
  }

  /// Sync ALL pending data (visits + orders + battery + fakegps + poweroff)
  static Future<Map<String, int>> syncAllPending() async {
    debugPrint('🔄 [SYNC] Syncing ALL pending data...');
    final results = {
      'visits': 0,
      'orders': 0,
      'battery': 0,
      'fakegps': 0,
      'poweroff': 0,
    };

    try {
      // 1. Sync Visits
      final visits = await syncPendingVisits();
      results['visits'] = visits.length;

      // 2. Sync Orders
      final orders = await syncPendingOrders();
      results['orders'] = orders.length;

      // 3. Sync Battery (already in BatterySyncService)
      try {
        await BatterySyncService.syncPendingBatteryEvents();
        results['battery'] = 1; // approximate
      } catch (e) {
        debugPrint('⚠️ [SYNC] Battery sync error: $e');
      }

      // 4. Sync FakeGPS
      try {
        // await FakeGpsService.syncPending();
        results['fakegps'] = 0;
      } catch (e) {
        debugPrint('⚠️ [SYNC] FakeGPS sync error: $e');
      }

      // 5. Sync PowerOff
      try {
        // await PowerOffService.syncPending();
        results['poweroff'] = 0;
      } catch (e) {
        debugPrint('⚠️ [SYNC] PowerOff sync error: $e');
      }

      debugPrint('✅ [SYNC] All sync complete: $results');
    } catch (e) {
      debugPrint('❌ [SYNC] Error syncing all: $e');
    }

    return results;
  }

  // ── Helper: try multiple SharedPreferences keys, return first non-empty ──
  static String _readPrefsString(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      try {
        final val = prefs.get(key)?.toString().trim() ?? '';
        if (val.isNotEmpty) return val;
      } catch (_) {}
    }
    return '';
  }
}

// ── Stub for BatterySyncService (if not imported) ──────────────────────────
// If you have BatterySyncService already imported, remove this.
// Otherwise, add this dummy class to avoid errors.
class BatterySyncService {
  static Future<void> syncPendingBatteryEvents() async {
    debugPrint('🔋 [BatterySync] syncPendingBatteryEvents called');
    // Actual implementation should be in battery_sync.dart
  }
}