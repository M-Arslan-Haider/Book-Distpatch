
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsModel {
  final int?   id;
  final String empId;
  final String empName;
  final String companyCode;

  final double realLatitude;
  final double realLongitude;
  final String realAddress;

  final double fakeLatitude;
  final double fakeLongitude;
  final String fakeAddress;

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
    'posted':         posted,
  };

  factory FakeGpsModel.fromMap(Map<String, dynamic> m) => FakeGpsModel(
    id:             m['id'] as int?,
    empId:          (m['emp_id']          as String?) ?? '',
    empName:        (m['emp_name']        as String?) ?? '',
    companyCode:    (m['company_code']    as String?) ?? '',
    realLatitude:   (m['real_latitude']   as num?)?.toDouble() ?? 0.0,
    realLongitude:  (m['real_longitude']  as num?)?.toDouble() ?? 0.0,
    realAddress:    (m['real_address']    as String?) ?? '',
    fakeLatitude:   (m['fake_latitude']   as num?)?.toDouble() ?? 0.0,
    fakeLongitude:  (m['fake_longitude']  as num?)?.toDouble() ?? 0.0,
    fakeAddress:    (m['fake_address']    as String?) ?? '',
    distanceKm:     (m['distance_km']     as num?)?.toDouble() ?? 0.0,
    detectedAt:     (m['detected_at']     as String?) ?? '',
    posted:         (m['posted']          as int?)    ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id':             id,
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
// LOGIC — detect · save locally · post when online
// ══════════════════════════════════════════════════════════════════════════════

class FakeGpsLog {
  FakeGpsLog._();

  static const String _apiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/';

  static const String _table = DBHelper.fakeGpsTable;

  // ── Cooldown — prevents flooding DB if mock fires on every tick ───────────
  static DateTime? _lastDetected;
  static const Duration _cooldown = Duration(seconds: 30);

  // ── Connectivity subscription — kept alive for the app's lifetime ─────────
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── FIX: Cache the last REAL (non-mocked) position ───────────────────────
  //
  // This is the KEY fix for the bug where both real and fake showed fake coords.
  //
  // HOW THE BUG HAPPENED:
  //   When fake GPS is active, ALL location providers are poisoned — including
  //   forceLocationManager and getLastKnownPosition. So when we detected a fake
  //   position and then tried to get the "real" position, we got the fake one
  //   again. Both real_lat/lon and fake_lat/lon ended up being identical fake coords.
  //
  // THE FIX:
  //   Every time checkAndReport() is called with a REAL (non-mocked) position,
  //   we save it here. When a fake position is detected later, we use this
  //   cached real position instead of trying to query location (which is poisoned).
  //   This way real_lat/lon is always genuinely real.
  static Position? _lastRealPosition;

  // ── Call once in main() ───────────────────────────────────────────────────
  static void startConnectivityListener() {
    _connectivitySub?.cancel(); // guard against duplicate calls

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('🌐 [FakeGPS] Internet restored — syncing pending records…');
        await _postUnsynced();
      }
    });

    debugPrint('✅ [FakeGPS] Connectivity listener started');
  }

  // ── Stop listener (call on logout / app dispose) ──────────────────────────
  static void stopConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    debugPrint('🛑 [FakeGPS] Connectivity listener stopped');
  }

  // ── Call this on EVERY GPS position update (real and fake) ───────────────
  //
  // IMPORTANT: You must call this for every position, not just suspicious ones.
  // That way _lastRealPosition is always kept fresh with genuine coordinates
  // before the mock GPS app starts injecting fake ones.
  static Future<void> checkAndReport(Position pos) async {
    if (!Platform.isAndroid) return; // iOS has no reliable mock flag

    // ── FIX: Always cache real positions as they come in ─────────────────────
    // If this position is NOT mocked, save it. This must happen before the
    // early return below so we always have a fresh real position cached.
    if (!pos.isMocked) {
      _lastRealPosition = pos;
      debugPrint(
          '📍 [FakeGPS] Real position cached: (${pos.latitude}, ${pos.longitude})');
      return; // Nothing else to do for real positions
    }

    // ── From here down: pos.isMocked == true ─────────────────────────────────

    final now = DateTime.now();
    if (_lastDetected != null &&
        now.difference(_lastDetected!) < _cooldown) {
      debugPrint('⚠️ [FakeGPS] Mock detected — within cooldown, skipping');
      return;
    }
    _lastDetected = now;

    final fakeLat = pos.latitude;
    final fakeLon = pos.longitude;
    debugPrint('🚨 [FakeGPS] FAKE GPS detected! fake=($fakeLat, $fakeLon)');

    // ── FIX: Use the cached real position instead of querying location ────────
    //
    // We do NOT call Geolocator.getCurrentPosition() or getLastKnownPosition()
    // here anymore. When fake GPS is active, both of those return fake coords.
    // Instead we use _lastRealPosition which was saved before the mock started.
    double realLat;
    double realLon;

    if (_lastRealPosition != null) {
      realLat = _lastRealPosition!.latitude;
      realLon = _lastRealPosition!.longitude;
      debugPrint('📍 [FakeGPS] Using cached real position: ($realLat, $realLon)');
    } else {
      // No real position ever captured (app started with mock already active).
      // Fall back to fake coords and log a warning — distance will be 0.
      realLat = fakeLat;
      realLon = fakeLon;
      debugPrint(
          '⚠️ [FakeGPS] No real position cached yet — mock may have been active '
              'before first real fix. Using fake coords as fallback.');
    }

    // ── Reverse geocode both locations ────────────────────────────────────────
    final fakeAddress = await _getAddress(fakeLat, fakeLon);
    final realAddress = (realLat != fakeLat || realLon != fakeLon)
        ? await _getAddress(realLat, realLon)
        : fakeAddress; // same coords → no need to geocode twice

    // ── Distance (km) ─────────────────────────────────────────────────────────
    final distanceKm =
        Geolocator.distanceBetween(realLat, realLon, fakeLat, fakeLon) / 1000.0;

    debugPrint(
        '📏 [FakeGPS] Distance real↔fake: ${distanceKm.toStringAsFixed(3)} km');
    debugPrint('🏠 [FakeGPS] Real address : $realAddress ($realLat, $realLon)');
    debugPrint('🎭 [FakeGPS] Fake address : $fakeAddress ($fakeLat, $fakeLon)');

    final prefs = await SharedPreferences.getInstance();
    final model = FakeGpsModel(
      empId:         _pref(prefs, 'emp_id'),
      empName:       _pref(prefs, 'emp_name',
          fallbacks: ['empName', 'employee_name', 'userName']),
      companyCode:   DBHelper.getCompanyCode() ?? '',
      realLatitude:  realLat,
      realLongitude: realLon,
      realAddress:   realAddress,
      fakeLatitude:  fakeLat,
      fakeLongitude: fakeLon,
      fakeAddress:   fakeAddress,
      distanceKm:    double.parse(distanceKm.toStringAsFixed(3)),
      detectedAt:    now.toIso8601String(),
    );

    // Always save locally first (works offline)
    await _saveLocal(model);

    // Then attempt to post — if offline it stays posted=0 and the
    // connectivity listener will pick it up when internet returns.
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
      return '$lat, $lon';
    }
  }

  // ── Call on app start to upload any events that failed while offline ───────
  static Future<void> syncPending() async => _postUnsynced();

  // ── Save to local SQLite ───────────────────────────────────────────────────
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
    // Quick connectivity check before hitting the network
    final connectivityResults = await Connectivity().checkConnectivity();
    final isOnline =
    connectivityResults.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      debugPrint('📴 [FakeGPS] Offline — skipping sync, will retry when online');
      return;
    }

    try {
      final db   = DBHelper();
      final rows = await db.getUnposted(_table);
      if (rows.isEmpty) {
        debugPrint('✅ [FakeGPS] No pending records to sync');
        return;
      }

      debugPrint('🔄 [FakeGPS] Syncing ${rows.length} unposted record(s)…');

      for (final row in rows) {
        final model = FakeGpsModel.fromMap(row);
        final ok    = await _post(model);
        if (ok && model.id != null) {
          await db.markAsPosted(_table, 'id', model.id.toString());
          debugPrint('✅ [FakeGPS] Marked id=${model.id} as posted');
        }
      }
    } catch (e) {
      debugPrint('❌ [FakeGPS] _postUnsynced error: $e');
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
      debugPrint(
          '⚠️ [FakeGPS] Server rejected → ${res.statusCode}: ${res.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [FakeGPS] POST failed (offline?): $e');
      return false; // stays posted=0, retried on next _postUnsynced()
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