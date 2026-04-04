// // // lib/FakeGps/fake_gps_log.dart
// // //
// // // ONE FILE — model + local save + server POST
// // //
// // // ── BACKEND TABLE ─────────────────────────────────────────────────────────────
// // //
// // //  CREATE TABLE fake_gps_logs (
// // //    id           INT AUTO_INCREMENT PRIMARY KEY,
// // //    emp_id       VARCHAR(20) NOT NULL,
// // //    emp_name     VARCHAR(100),
// // //    company_code VARCHAR(30),
// // //    latitude     DECIMAL(10,7),
// // //    longitude    DECIMAL(10,7),
// // //    detected_at  DATETIME NOT NULL
// // //  );
// // //
// // // ─────────────────────────────────────────────────────────────────────────────
// //
// // import 'dart:convert';
// // import 'dart:io';
// //
// // import 'package:flutter/foundation.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../Database/db_helper.dart'; // adjust path if your file is elsewhere
// //
// // // ══════════════════════════════════════════════════════════════════════════════
// // // MODEL
// // // ══════════════════════════════════════════════════════════════════════════════
// //
// // class FakeGpsModel {
// //   final int?   id;
// //   final String empId;
// //   final String empName;
// //   final String companyCode;
// //   final double latitude;
// //   final double longitude;
// //   final String detectedAt; // ISO-8601  e.g. "2026-04-04T10:30:00"
// //   final int    posted;     // 0 = not sent, 1 = sent
// //
// //   const FakeGpsModel({
// //     this.id,
// //     required this.empId,
// //     required this.empName,
// //     required this.companyCode,
// //     required this.latitude,
// //     required this.longitude,
// //     required this.detectedAt,
// //     this.posted = 0,
// //   });
// //
// //   Map<String, dynamic> toMap() => {
// //     if (id != null) 'id': id,
// //     'emp_id':       empId,
// //     'emp_name':     empName,
// //     'company_code': companyCode,
// //     'latitude':     latitude,
// //     'longitude':    longitude,
// //     'detected_at':  detectedAt,
// //     'posted':       posted,
// //   };
// //
// //   factory FakeGpsModel.fromMap(Map<String, dynamic> m) => FakeGpsModel(
// //     id:          m['id'] as int?,
// //     empId:       (m['emp_id']      as String?) ?? '',
// //     empName:     (m['emp_name']    as String?) ?? '',
// //     companyCode: (m['company_code']as String?) ?? '',
// //     latitude:    (m['latitude']    as num?)?.toDouble() ?? 0.0,
// //     longitude:   (m['longitude']   as num?)?.toDouble() ?? 0.0,
// //     detectedAt:  (m['detected_at'] as String?) ?? '',
// //     posted:      (m['posted']      as int?)    ?? 0,
// //   );
// //
// //   Map<String, dynamic> toJson() => {
// //     'emp_id':       empId,
// //     'emp_name':     empName,
// //     'company_code': companyCode,
// //     'latitude':     latitude,
// //     'longitude':    longitude,
// //     'detected_at':  detectedAt,
// //   };
// // }
// //
// // // ══════════════════════════════════════════════════════════════════════════════
// // // LOGIC  — detect · save locally · post to server
// // // ══════════════════════════════════════════════════════════════════════════════
// //
// // class FakeGpsLog {
// //   FakeGpsLog._();
// //
// //   static const String _apiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/';
// //
// //   static const String _table = 'fake_gps_logs';
// //
// //   // Cooldown — prevents flooding DB if mock GPS fires on every position tick
// //   static DateTime? _lastDetected;
// //   static const Duration _cooldown = Duration(seconds: 30);
// //
// //   // ── Call this on every GPS position update ─────────────────────────────────
// //   static Future<void> checkAndReport(Position pos) async {
// //     if (!Platform.isAndroid) return;  // iOS has no reliable mock flag
// //     if (!pos.isMocked) return;        // real GPS — nothing to do
// //
// //     final now = DateTime.now();
// //     if (_lastDetected != null && now.difference(_lastDetected!) < _cooldown) {
// //       debugPrint('⚠️ [FakeGPS] Mock detected — within cooldown, skipping');
// //       return;
// //     }
// //     _lastDetected = now;
// //
// //     debugPrint('🚨 [FakeGPS] FAKE GPS detected! lat=${pos.latitude} lon=${pos.longitude}');
// //
// //     final prefs = await SharedPreferences.getInstance();
// //     final model = FakeGpsModel(
// //       empId:       _pref(prefs, 'emp_id'),
// //       empName:     _pref(prefs, 'emp_name',
// //           fallbacks: ['empName', 'employee_name', 'userName']),
// //       companyCode: DBHelper.getCompanyCode() ?? '',
// //       latitude:    pos.latitude,
// //       longitude:   pos.longitude,
// //       detectedAt:  now.toIso8601String(),
// //     );
// //
// //     // Step 1 — save locally first (always, even if offline)
// //     await _saveLocal(model);
// //
// //     // Step 2 — try to POST immediately
// //     await _postUnsynced();
// //   }
// //
// //   // ── Call on app start to upload any events that failed while offline ────────
// //   static Future<void> syncPending() async => _postUnsynced();
// //
// //   // ── Save to local SQLite via your existing DBHelper ────────────────────────
// //   static Future<void> _saveLocal(FakeGpsModel model) async {
// //     try {
// //       await DBHelper().insert(_table, model.toMap());
// //       debugPrint('💾 [FakeGPS] Saved locally at ${model.detectedAt}');
// //     } catch (e) {
// //       debugPrint('❌ [FakeGPS] Local save failed: $e');
// //     }
// //   }
// //
// //   // ── POST all unsynced rows to server ──────────────────────────────────────
// //   static Future<void> _postUnsynced() async {
// //     try {
// //       final db   = DBHelper();
// //       final rows = await db.getUnposted(_table);
// //       if (rows.isEmpty) return;
// //
// //       debugPrint('🔄 [FakeGPS] Syncing ${rows.length} unposted record(s)');
// //
// //       for (final row in rows) {
// //         final model = FakeGpsModel.fromMap(row);
// //         final ok    = await _post(model);
// //         if (ok && model.id != null) {
// //           await db.markAsPosted(_table, 'id', model.id.toString());
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint('❌ [FakeGPS] syncPending error: $e');
// //     }
// //   }
// //
// //   static Future<bool> _post(FakeGpsModel model) async {
// //     try {
// //       final res = await http
// //           .post(
// //         Uri.parse(_apiUrl),
// //         headers: {'Content-Type': 'application/json'},
// //         body:    jsonEncode(model.toJson()),
// //       )
// //           .timeout(const Duration(seconds: 15));
// //
// //       if (res.statusCode == 200 || res.statusCode == 201) {
// //         debugPrint('✅ [FakeGPS] Posted id=${model.id} → ${res.statusCode}');
// //         return true;
// //       }
// //       debugPrint('⚠️ [FakeGPS] Server rejected → ${res.statusCode}: ${res.body}');
// //       return false;
// //     } catch (e) {
// //       debugPrint('❌ [FakeGPS] POST failed (offline?): $e');
// //       return false; // stays posted=0, retried on next syncPending()
// //     }
// //   }
// //
// //   static String _pref(SharedPreferences prefs, String key,
// //       {List<String> fallbacks = const []}) {
// //     for (final k in [key, ...fallbacks]) {
// //       try {
// //         final raw = prefs.get(k);
// //         if (raw != null) {
// //           final val = raw.toString().trim();
// //           if (val.isNotEmpty) return val;
// //         }
// //       } catch (_) {}
// //     }
// //     return '';
// //   }
// // }
//
// // lib/FakeGps/fake_gps_log.dart
// //
// // ONE FILE — model + local save + server POST
// //
// // ── BACKEND TABLE ─────────────────────────────────────────────────────────────
// //
// //  CREATE TABLE fake_gps_logs (
// //    id           INT AUTO_INCREMENT PRIMARY KEY,
// //    emp_id       VARCHAR(20) NOT NULL,
// //    emp_name     VARCHAR(100),
// //    company_code VARCHAR(30),
// //    latitude     DECIMAL(10,7),
// //    longitude    DECIMAL(10,7),
// //    detected_at  DATETIME NOT NULL
// //  );
// //
// // ─────────────────────────────────────────────────────────────────────────────
//
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/foundation.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Database/db_helper.dart'; // adjust path if your file is elsewhere
//
// // ══════════════════════════════════════════════════════════════════════════════
// // MODEL
// // ══════════════════════════════════════════════════════════════════════════════
//
// class FakeGpsModel {
//   final int?   id;
//   final String empId;
//   final String empName;
//   final String companyCode;
//
//   // Real location — where employee actually is
//   final double realLatitude;
//   final double realLongitude;
//   final String realAddress;
//
//   // Fake location — what the mock GPS app injected
//   final double fakeLatitude;
//   final double fakeLongitude;
//   final String fakeAddress;
//
//   // Distance between real and fake (km)
//   final double distanceKm;
//
//   final String detectedAt;
//   final int    posted;
//
//   const FakeGpsModel({
//     this.id,
//     required this.empId,
//     required this.empName,
//     required this.companyCode,
//     required this.realLatitude,
//     required this.realLongitude,
//     required this.realAddress,
//     required this.fakeLatitude,
//     required this.fakeLongitude,
//     required this.fakeAddress,
//     required this.distanceKm,
//     required this.detectedAt,
//     this.posted = 0,
//   });
//
//   Map<String, dynamic> toMap() => {
//     if (id != null) 'id': id,
//     'emp_id':        empId,
//     'emp_name':      empName,
//     'company_code':  companyCode,
//     'real_latitude':  realLatitude,
//     'real_longitude': realLongitude,
//     'real_address':   realAddress,
//     'fake_latitude':  fakeLatitude,
//     'fake_longitude': fakeLongitude,
//     'fake_address':   fakeAddress,
//     'distance_km':    distanceKm,
//     'detected_at':   detectedAt,
//     'posted':        posted,
//   };
//
//   factory FakeGpsModel.fromMap(Map<String, dynamic> m) => FakeGpsModel(
//     id:             m['id'] as int?,
//     empId:          (m['emp_id']       as String?) ?? '',
//     empName:        (m['emp_name']     as String?) ?? '',
//     companyCode:    (m['company_code'] as String?) ?? '',
//     realLatitude:   (m['real_latitude']  as num?)?.toDouble() ?? 0.0,
//     realLongitude:  (m['real_longitude'] as num?)?.toDouble() ?? 0.0,
//     realAddress:    (m['real_address']   as String?) ?? '',
//     fakeLatitude:   (m['fake_latitude']  as num?)?.toDouble() ?? 0.0,
//     fakeLongitude:  (m['fake_longitude'] as num?)?.toDouble() ?? 0.0,
//     fakeAddress:    (m['fake_address']   as String?) ?? '',
//     distanceKm:     (m['distance_km']    as num?)?.toDouble() ?? 0.0,
//     detectedAt:     (m['detected_at']  as String?) ?? '',
//     posted:         (m['posted']       as int?)    ?? 0,
//   );
//
//   Map<String, dynamic> toJson() => {
//     'emp_id':        empId,
//     'emp_name':      empName,
//     'company_code':  companyCode,
//     'real_latitude':  realLatitude,
//     'real_longitude': realLongitude,
//     'real_address':   realAddress,
//     'fake_latitude':  fakeLatitude,
//     'fake_longitude': fakeLongitude,
//     'fake_address':   fakeAddress,
//     'distance_km':    distanceKm,
//     'detected_at':   detectedAt,
//   };
// }
//
// // ══════════════════════════════════════════════════════════════════════════════
// // LOGIC  — detect · save locally · post to server
// // ══════════════════════════════════════════════════════════════════════════════
//
// class FakeGpsLog {
//   FakeGpsLog._();
//
//   static const String _apiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/';
//
//   static const String _table = 'fake_gps_logs';
//
//   // Cooldown — prevents flooding DB if mock GPS fires on every position tick
//   static DateTime? _lastDetected;
//   static const Duration _cooldown = Duration(seconds: 30);
//
//   // ── Call this on every GPS position update ─────────────────────────────────
//   static Future<void> checkAndReport(Position pos) async {
//     if (!Platform.isAndroid) return;  // iOS has no reliable mock flag
//     if (!pos.isMocked) return;        // real GPS — nothing to do
//
//     final now = DateTime.now();
//     if (_lastDetected != null && now.difference(_lastDetected!) < _cooldown) {
//       debugPrint('⚠️ [FakeGPS] Mock detected — within cooldown, skipping');
//       return;
//     }
//     _lastDetected = now;
//
//     // pos is the FAKE location injected by the mock app
//     final fakeLat = pos.latitude;
//     final fakeLon = pos.longitude;
//
//     debugPrint('🚨 [FakeGPS] FAKE GPS detected! fake=($fakeLat, $fakeLon)');
//
//     // ── Get REAL location by forcing GPS provider (bypasses mock) ────────────
//     double realLat = 0.0;
//     double realLon = 0.0;
//     try {
//       final realPos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 10),
//         // forceAndroidLocationManager bypasses FusedLocationProvider
//         // which is what fake GPS apps typically hook into
//       );
//       // If real position is also mocked, we still record it as best-known
//       realLat = realPos.latitude;
//       realLon = realPos.longitude;
//       debugPrint('📍 [FakeGPS] Real location: ($realLat, $realLon)');
//     } catch (e) {
//       debugPrint('⚠️ [FakeGPS] Could not get real location: $e');
//     }
//
//     // ── Reverse geocode both locations ────────────────────────────────────────
//     final fakeAddress = await _getAddress(fakeLat, fakeLon);
//     final realAddress = realLat != 0.0
//         ? await _getAddress(realLat, realLon)
//         : 'Unknown';
//
//     // ── Distance between real and fake (km) ───────────────────────────────────
//     final distanceKm = realLat != 0.0
//         ? Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0
//         : 0.0;
//
//     debugPrint('📏 [FakeGPS] Distance real↔fake: ${distanceKm.toStringAsFixed(3)} km');
//     debugPrint('🏠 [FakeGPS] Real address: $realAddress');
//     debugPrint('🎭 [FakeGPS] Fake address: $fakeAddress');
//
//     final prefs = await SharedPreferences.getInstance();
//     final model = FakeGpsModel(
//       empId:        _pref(prefs, 'emp_id'),
//       empName:      _pref(prefs, 'emp_name',
//           fallbacks: ['empName', 'employee_name', 'userName']),
//       companyCode:  DBHelper.getCompanyCode() ?? '',
//       realLatitude:  realLat,
//       realLongitude: realLon,
//       realAddress:   realAddress,
//       fakeLatitude:  fakeLat,
//       fakeLongitude: fakeLon,
//       fakeAddress:   fakeAddress,
//       distanceKm:    double.parse(distanceKm.toStringAsFixed(3)),
//       detectedAt:   now.toIso8601String(),
//     );
//
//     await _saveLocal(model);
//     await _postUnsynced();
//   }
//
//   // ── Reverse geocode lat/lon → address string ──────────────────────────────
//   static Future<String> _getAddress(double lat, double lon) async {
//     try {
//       final marks = await placemarkFromCoordinates(lat, lon)
//           .timeout(const Duration(seconds: 8));
//       if (marks.isEmpty) return '$lat, $lon';
//       final p = marks.first;
//       final parts = [
//         p.thoroughfare,
//         p.subLocality,
//         p.locality,
//         p.administrativeArea,
//         p.country,
//       ].where((s) => s != null && s.isNotEmpty).join(', ');
//       return parts.isEmpty ? '$lat, $lon' : parts;
//     } catch (e) {
//       debugPrint('⚠️ [FakeGPS] Geocoding failed: $e');
//       return '$lat, $lon'; // fallback to raw coords
//     }
//   }
//
//   // ── Call on app start to upload any events that failed while offline ────────
//   static Future<void> syncPending() async => _postUnsynced();
//
//   // ── Save to local SQLite via your existing DBHelper ────────────────────────
//   static Future<void> _saveLocal(FakeGpsModel model) async {
//     try {
//       await DBHelper().insert(_table, model.toMap());
//       debugPrint('💾 [FakeGPS] Saved locally at ${model.detectedAt}');
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] Local save failed: $e');
//     }
//   }
//
//   // ── POST all unsynced rows to server ──────────────────────────────────────
//   static Future<void> _postUnsynced() async {
//     try {
//       final db   = DBHelper();
//       final rows = await db.getUnposted(_table);
//       if (rows.isEmpty) return;
//
//       debugPrint('🔄 [FakeGPS] Syncing ${rows.length} unposted record(s)');
//
//       for (final row in rows) {
//         final model = FakeGpsModel.fromMap(row);
//         final ok    = await _post(model);
//         if (ok && model.id != null) {
//           await db.markAsPosted(_table, 'id', model.id.toString());
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] syncPending error: $e');
//     }
//   }
//
//   static Future<bool> _post(FakeGpsModel model) async {
//     try {
//       final res = await http
//           .post(
//         Uri.parse(_apiUrl),
//         headers: {'Content-Type': 'application/json'},
//         body:    jsonEncode(model.toJson()),
//       )
//           .timeout(const Duration(seconds: 15));
//
//       if (res.statusCode == 200 || res.statusCode == 201) {
//         debugPrint('✅ [FakeGPS] Posted id=${model.id} → ${res.statusCode}');
//         return true;
//       }
//       debugPrint('⚠️ [FakeGPS] Server rejected → ${res.statusCode}: ${res.body}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [FakeGPS] POST failed (offline?): $e');
//       return false; // stays posted=0, retried on next syncPending()
//     }
//   }
//
//   static String _pref(SharedPreferences prefs, String key,
//       {List<String> fallbacks = const []}) {
//     for (final k in [key, ...fallbacks]) {
//       try {
//         final raw = prefs.get(k);
//         if (raw != null) {
//           final val = raw.toString().trim();
//           if (val.isNotEmpty) return val;
//         }
//       } catch (_) {}
//     }
//     return '';
//   }
// }


import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart'; // adjust path if your file is elsewhere

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsModel {
  final int?   id;
  final String empId;
  final String empName;
  final String companyCode;

  // Real location — where employee actually is
  final double realLatitude;
  final double realLongitude;
  final String realAddress;

  // Fake location — what the mock GPS app injected
  final double fakeLatitude;
  final double fakeLongitude;
  final String fakeAddress;

  // Distance between real and fake (km)
  final double distanceKm;

  final String detectedAt;
  final int    posted;

  const FakeGpsModel({
    this.id,
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.realLatitude,
    required this.realLongitude,
    required this.realAddress,
    required this.fakeLatitude,
    required this.fakeLongitude,
    required this.fakeAddress,
    required this.distanceKm,
    required this.detectedAt,
    this.posted = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'emp_id':        empId,
    'emp_name':      empName,
    'company_code':  companyCode,
    'real_latitude':  realLatitude,
    'real_longitude': realLongitude,
    'real_address':   realAddress,
    'fake_latitude':  fakeLatitude,
    'fake_longitude': fakeLongitude,
    'fake_address':   fakeAddress,
    'distance_km':    distanceKm,
    'detected_at':   detectedAt,
    'posted':        posted,
  };

  factory FakeGpsModel.fromMap(Map<String, dynamic> m) => FakeGpsModel(
    id:             m['id'] as int?,
    empId:          (m['emp_id']       as String?) ?? '',
    empName:        (m['emp_name']     as String?) ?? '',
    companyCode:    (m['company_code'] as String?) ?? '',
    realLatitude:   (m['real_latitude']  as num?)?.toDouble() ?? 0.0,
    realLongitude:  (m['real_longitude'] as num?)?.toDouble() ?? 0.0,
    realAddress:    (m['real_address']   as String?) ?? '',
    fakeLatitude:   (m['fake_latitude']  as num?)?.toDouble() ?? 0.0,
    fakeLongitude:  (m['fake_longitude'] as num?)?.toDouble() ?? 0.0,
    fakeAddress:    (m['fake_address']   as String?) ?? '',
    distanceKm:     (m['distance_km']    as num?)?.toDouble() ?? 0.0,
    detectedAt:     (m['detected_at']  as String?) ?? '',
    posted:         (m['posted']       as int?)    ?? 0,
  );

  // JSON payload for Oracle backend — matches FAKEGPSTABLE columns (without ID)
  Map<String, dynamic> toJson() => {
    'id':             id,          // ← add this
    'emp_id':         empId,
    'emp_name':       empName,
    'company_code':   companyCode,
    'real_latitude':  realLatitude,
    'real_longitude': realLongitude,
    'real_address':   realAddress,
    'fake_latitude':  fakeLatitude,
    'fake_longitude': fakeLongitude,
    'fake_address':   fakeAddress,
    'distance_km':    distanceKm,
    'detected_at':    detectedAt,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGIC  — detect · save locally · post to server
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsLog {
  FakeGpsLog._();

  // UPDATE THIS URL to match your Oracle ORDS endpoint for FAKEGPSTABLE
  static const String _apiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/';

  static const String _table = 'fake_gps_logs';

  // Cooldown — prevents flooding DB if mock GPS fires on every position tick
  static DateTime? _lastDetected;
  static const Duration _cooldown = Duration(seconds: 30);

  // ── Call this on every GPS position update ─────────────────────────────────
  static Future<void> checkAndReport(Position pos) async {
    if (!Platform.isAndroid) return;  // iOS has no reliable mock flag
    if (!pos.isMocked) return;        // real GPS — nothing to do

    final now = DateTime.now();
    if (_lastDetected != null && now.difference(_lastDetected!) < _cooldown) {
      debugPrint('⚠️ [FakeGPS] Mock detected — within cooldown, skipping');
      return;
    }
    _lastDetected = now;

    // pos is the FAKE location injected by the mock app
    final fakeLat = pos.latitude;
    final fakeLon = pos.longitude;

    debugPrint('🚨 [FakeGPS] FAKE GPS detected! fake=($fakeLat, $fakeLon)');

    // ── Get REAL location by forcing GPS provider (bypasses mock) ────────────
    // ── Get REAL location by forcing GPS provider (bypasses mock) ────────────
    double realLat = 0.0;
    double realLon = 0.0;
    try {
      Position? realPos;

      // Try 1: force hardware GPS (bypasses FusedLocationProvider)
      try {
        realPos = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
            forceLocationManager: true,
          ),
        );
      } catch (_) {}

      // Try 2: fallback to last known position
      realPos ??= await Geolocator.getLastKnownPosition();

      realLat = realPos?.latitude ?? fakeLat;
      realLon = realPos?.longitude ?? fakeLon;
      debugPrint('📍 [FakeGPS] Real location: ($realLat, $realLon)');
    } catch (e) {
      debugPrint('⚠️ [FakeGPS] Could not get real location: $e');
      realLat = fakeLat;
      realLon = fakeLon;
    }

    // ── Reverse geocode both locations ────────────────────────────────────────
    final fakeAddress = await _getAddress(fakeLat, fakeLon);
    final realAddress = realLat != 0.0
        ? await _getAddress(realLat, realLon)
        : 'Unknown';

    // ── Distance between real and fake (km) ───────────────────────────────────
    final distanceKm = realLat != 0.0
        ? Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0
        : 0.0;

    debugPrint('📏 [FakeGPS] Distance real↔fake: ${distanceKm.toStringAsFixed(3)} km');
    debugPrint('🏠 [FakeGPS] Real address: $realAddress');
    debugPrint('🎭 [FakeGPS] Fake address: $fakeAddress');

    final prefs = await SharedPreferences.getInstance();
    final model = FakeGpsModel(
      empId:        _pref(prefs, 'emp_id'),
      empName:      _pref(prefs, 'emp_name',
          fallbacks: ['empName', 'employee_name', 'userName']),
      companyCode:  DBHelper.getCompanyCode() ?? '',
      realLatitude:  realLat,
      realLongitude: realLon,
      realAddress:   realAddress,
      fakeLatitude:  fakeLat,
      fakeLongitude: fakeLon,
      fakeAddress:   fakeAddress,
      distanceKm:    double.parse(distanceKm.toStringAsFixed(3)),
      detectedAt:   now.toIso8601String(),
    );

    await _saveLocal(model);
    await _postUnsynced();
  }

  // ── Reverse geocode lat/lon → address string ──────────────────────────────
  static Future<String> _getAddress(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return '$lat, $lon';
      final p = marks.first;
      final parts = [
        p.thoroughfare,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
      return parts.isEmpty ? '$lat, $lon' : parts;
    } catch (e) {
      debugPrint('⚠️ [FakeGPS] Geocoding failed: $e');
      return '$lat, $lon'; // fallback to raw coords
    }
  }

  // ── Call on app start to upload any events that failed while offline ────────
  static Future<void> syncPending() async => _postUnsynced();

  // ── Save to local SQLite via your existing DBHelper ────────────────────────
  static Future<void> _saveLocal(FakeGpsModel model) async {
    try {
      await DBHelper().insert(_table, model.toMap());
      debugPrint('💾 [FakeGPS] Saved locally at ${model.detectedAt}');
    } catch (e) {
      debugPrint('❌ [FakeGPS] Local save failed: $e');
    }
  }

  // ── POST all unsynced rows to server ──────────────────────────────────────
  static Future<void> _postUnsynced() async {
    try {
      final db   = DBHelper();
      final rows = await db.getUnposted(_table);
      if (rows.isEmpty) return;

      debugPrint('🔄 [FakeGPS] Syncing ${rows.length} unposted record(s)');

      for (final row in rows) {
        final model = FakeGpsModel.fromMap(row);
        final ok    = await _post(model);
        if (ok && model.id != null) {
          await db.markAsPosted(_table, 'id', model.id.toString());
        }
      }
    } catch (e) {
      debugPrint('❌ [FakeGPS] syncPending error: $e');
    }
  }

  static Future<bool> _post(FakeGpsModel model) async {
    try {
      final res = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode(model.toJson()),
      )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('✅ [FakeGPS] Posted id=${model.id} → ${res.statusCode}');
        return true;
      }
      debugPrint('⚠️ [FakeGPS] Server rejected → ${res.statusCode}: ${res.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [FakeGPS] POST failed (offline?): $e');
      return false; // stays posted=0, retried on next syncPending()
    }
  }

  static String _pref(SharedPreferences prefs, String key,
      {List<String> fallbacks = const []}) {
    for (final k in [key, ...fallbacks]) {
      try {
        final raw = prefs.get(k);
        if (raw != null) {
          final val = raw.toString().trim();
          if (val.isNotEmpty) return val;
        }
      } catch (_) {}
    }
    return '';
  }
}