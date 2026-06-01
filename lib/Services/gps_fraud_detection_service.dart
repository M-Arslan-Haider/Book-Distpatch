import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart'; // contains prefCompanyCode — adjust path if needed

// ══════════════════════════════════════════════════════════════════════════
// GPS FRAUD DETECTION SERVICE
//
// CHECK 1 — Satellite Count (GnssStatus API, Android only)
//   RULE A: satellites_used == 0  AND accuracy < 10 m
//           → FAKE_GPS  (physically impossible combination)
//   RULE B: satellites_used < 4  (and != -1 / unavailable)
//           → SUSPICIOUS  (too few satellites for a real outdoor fix)
//
// Usage (inside _handleClockIn, AFTER geofence check, BEFORE clockIn API):
//   final GpsFraudResult fraudResult = await GpsFraudDetectionService.runChecks(
//     accuracyMeters: currentPosition.accuracy, // from Geolocator
//   );
//   // fraudResult is posted to the server automatically (fire-and-forget).
//   // The caller may inspect fraudResult.isSuspicious / fraudLevel if needed.
// ══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────

class GpsFraudResult {
  /// true  → at least one fraud rule fired
  final bool isSuspicious;

  /// Human-readable description.  Empty string when CLEAN.
  final String reason;

  /// Raw satellite count from the device.  −1 = unavailable / not Android.
  final int satellitesUsed;

  /// GPS accuracy in metres passed in by the caller.
  final double accuracyMeters;

  /// 'FAKE_GPS' | 'SUSPICIOUS' | 'CLEAN'
  final String fraudLevel;

  const GpsFraudResult({
    required this.isSuspicious,
    required this.reason,
    required this.satellitesUsed,
    required this.accuracyMeters,
    required this.fraudLevel,
  });

  @override
  String toString() =>
      'GpsFraudResult(level=$fraudLevel, satellites=$satellitesUsed, '
          'accuracy=${accuracyMeters.toStringAsFixed(1)}m, '
          'suspicious=$isSuspicious, reason="$reason")';
}

// ─────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────

class GpsFraudDetectionService {
  // ── MethodChannel ─────────────────────────────────────────────────────
  // Native Android side must implement 'getSatelliteCount' on this channel.
  // It should return the int count from the most-recent GnssStatus callback.
  // (Kotlin example is in README / inline comments below.)
  static const MethodChannel _channel =
  MethodChannel('com.metaxperts.GPS_Workforce_Monitor/gps_fraud');

  // ── Oracle fixed URL ───────────────────────────────────────────────────
  static const String _satelliteApiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/emp_fraud_log/post/';

  // ════════════════════════════════════════════════════════════════════════
  // PUBLIC entry point
  // ════════════════════════════════════════════════════════════════════════

  /// Runs CHECK 1 (satellite count) and POSTs the result to the server.
  ///
  /// [accuracyMeters] — the GPS accuracy (in metres) that was already
  ///   obtained during the geofence check.  Pass
  ///   `currentPosition.accuracy` from Geolocator.
  ///
  /// Always returns a [GpsFraudResult]; never throws.
  static Future<GpsFraudResult> runChecks({
    required double accuracyMeters,
  }) async {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🛰️  [GPS FRAUD] ===== CHECK 1: Satellite Count =====');
    debugPrint('🛰️  [GPS FRAUD] Accuracy from geofence step: '
        '${accuracyMeters.toStringAsFixed(1)} m');

    // ── 1. Query native layer for satellite count ─────────────────────────
    final int satellitesUsed = await _getSatelliteCount();
    debugPrint('🛰️  [GPS FRAUD] Satellites used in fix: $satellitesUsed '
        '(−1 = unavailable)');

    // ── 2. Apply fraud rules ──────────────────────────────────────────────
    final GpsFraudResult result = _applyRules(
      satellitesUsed: satellitesUsed,
      accuracyMeters: accuracyMeters,
    );

    debugPrint('🛰️  [GPS FRAUD] Final result → $result');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    // ── 3. POST to server — fire-and-forget, never blocks caller ──────────
    unawaited(_postSatelliteLog(result));

    return result;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE: satellite count via MethodChannel
  // ════════════════════════════════════════════════════════════════════════

  /// Invokes `getSatelliteCount` on the native channel.
  ///
  /// Kotlin stub (add to MainActivity or your LocationMonitorService):
  /// ```kotlin
  /// MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
  ///               "com.yourapp.attendance/gps_fraud").setMethodCallHandler { call, result ->
  ///   if (call.method == "getSatelliteCount") {
  ///     result.success(lastSatelliteCount)   // int stored from GnssStatus.Callback
  ///   } else {
  ///     result.notImplemented()
  ///   }
  /// }
  /// ```
  static Future<int> _getSatelliteCount() async {
    if (!Platform.isAndroid) {
      // GnssStatus is an Android-only API; iOS uses CoreLocation which does
      // not expose satellite counts publicly.
      debugPrint('🛰️  [GPS FRAUD] Non-Android platform — '
          'satellite check not available, returning -1');
      return -1;
    }

    try {
      debugPrint('🛰️  [GPS FRAUD] Invoking native getSatelliteCount via MethodChannel...');
      final dynamic rawResult =
      await _channel.invokeMethod<dynamic>('getSatelliteCount');

      final int count = rawResult is int
          ? rawResult
          : int.tryParse(rawResult.toString()) ?? -1;

      debugPrint('🛰️  [GPS FRAUD] Native getSatelliteCount → $count');
      return count;
    } on MissingPluginException {
      // Native side has not implemented this channel yet.
      // Treat as "unavailable" so the app keeps working.
      debugPrint(
          'ℹ️  [GPS FRAUD] MethodChannel getSatelliteCount not implemented — '
              'returning -1 (add Kotlin stub to enable this check)');
      return -1;
    } catch (e) {
      debugPrint('⚠️  [GPS FRAUD] getSatelliteCount error: $e — returning -1');
      return -1;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE: fraud rules
  // ════════════════════════════════════════════════════════════════════════

  static GpsFraudResult _applyRules({
    required int    satellitesUsed,
    required double accuracyMeters,
  }) {
    debugPrint('🛰️  [GPS FRAUD] Evaluating rules...');
    debugPrint('🛰️  [GPS FRAUD]   satellites_used  = $satellitesUsed');
    debugPrint('🛰️  [GPS FRAUD]   accuracy_meters  = '
        '${accuracyMeters.toStringAsFixed(2)}');

    // ── RULE A: FAKE GPS ──────────────────────────────────────────────────
    // A real GPS fix with 0 active satellites is physically impossible.
    // A mock/fake-GPS app can inject a position without any satellite fix
    // and still report sub-10-metre accuracy because it fabricates the value.
    // Combination: satellites_used == 0  AND  accuracy < 10 m  → FAKE_GPS.
    if (satellitesUsed == 0 && accuracyMeters < 10.0) {
      debugPrint('🚨 [GPS FRAUD] RULE A FIRED: '
          'satellites=0 but accuracy=${accuracyMeters.toStringAsFixed(2)}m '
          '— impossible without real fix → FAKE_GPS');
      return GpsFraudResult(
        isSuspicious  : true,
        reason        : 'Fake GPS detected: 0 satellites used but GPS accuracy '
            'reported as ${accuracyMeters.toStringAsFixed(1)} m '
            '(physically impossible combination)',
        satellitesUsed: satellitesUsed,
        accuracyMeters: accuracyMeters,
        fraudLevel    : 'FAKE_GPS',
      );
    }

    // ── RULE B: SUSPICIOUS — low satellite count ──────────────────────────
    // A genuine outdoor GPS fix requires signals from at least 4 satellites
    // (3 for position + 1 for clock correction).  Fewer satellites suggests:
    //   • Device is using network/cell-tower location instead of GPS, OR
    //   • A mock provider is partially simulating GPS.
    // Skip check when satellitesUsed == -1 (unavailable / not Android).
    if (satellitesUsed != -1 && satellitesUsed < 4) {
      debugPrint('⚠️  [GPS FRAUD] RULE B FIRED: '
          'satellites=$satellitesUsed < 4 (minimum for outdoor fix) → SUSPICIOUS');
      return GpsFraudResult(
        isSuspicious  : true,
        reason        : 'Suspicious GPS: only $satellitesUsed satellite(s) used '
            '(≥ 4 required for a reliable outdoor fix)',
        satellitesUsed: satellitesUsed,
        accuracyMeters: accuracyMeters,
        fraudLevel    : 'SUSPICIOUS',
      );
    }

    // ── CLEAN ──────────────────────────────────────────────────────────────
    debugPrint('✅  [GPS FRAUD] No fraud rules triggered → CLEAN');
    return GpsFraudResult(
      isSuspicious  : false,
      reason        : '',
      satellitesUsed: satellitesUsed,
      accuracyMeters: accuracyMeters,
      fraudLevel    : 'CLEAN',
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE: POST to server
  // ════════════════════════════════════════════════════════════════════════

  /// Posts the fraud detection result to the oracle endpoint.
  /// Intentionally fire-and-forget: any network failure is logged and
  /// swallowed — it must NEVER block or cancel the clock-in flow.
  static Future<void> _postSatelliteLog(GpsFraudResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String empId   = _safeString(prefs, 'emp_id');
      final String empName     = _safeString(prefs, 'emp_name').isNotEmpty
          ? _safeString(prefs, 'emp_name')
          : _safeString(prefs, 'empName');

      debugPrint('');
      debugPrint('🛰️  [GPS FRAUD POST] ===== Posting fraud log =====');
      debugPrint('🛰️  [GPS FRAUD POST] URL          = $_satelliteApiUrl');
      debugPrint('🛰️  [GPS FRAUD POST] empId        = "$empId"');
      debugPrint('🛰️  [GPS FRAUD POST] empName      = "$empName"');
      debugPrint('🛰️  [GPS FRAUD POST] fraudLevel   = ${result.fraudLevel}');
      debugPrint('🛰️  [GPS FRAUD POST] satellites   = ${result.satellitesUsed}');
      debugPrint('🛰️  [GPS FRAUD POST] accuracy     = '
          '${result.accuracyMeters.toStringAsFixed(1)} m');
      debugPrint('🛰️  [GPS FRAUD POST] isSuspicious = ${result.isSuspicious}');
      debugPrint('🛰️  [GPS FRAUD POST] reason       = "${result.reason}"');

      if (empId.isEmpty) {
        debugPrint('⚠️  [GPS FRAUD POST] emp_id is empty — skipping post');
        return;
      }

      final Map<String, dynamic> payload = {
        'emp_id'         : int.tryParse(empId) ?? 0,          // NUMBER
        'emp_name'       : empName,
        'fraud_level'    : result.fraudLevel,
        'is_suspicious'  : result.isSuspicious ? 'Y' : 'N',   // VARCHAR2(1)
        'satellites_used': result.satellitesUsed,
        'accuracy_meters': result.accuracyMeters,
        'reason'         : result.reason,
        'timestamp'      : DateTime.now().toIso8601String(),
        'platform'       : Platform.isAndroid ? 'android' : 'ios',
        'check_version'  : 1,
      };

      debugPrint('🛰️  [GPS FRAUD POST] Payload: $payload');

      final response = await http
          .post(
        Uri.parse(_satelliteApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 10));

      debugPrint('🛰️  [GPS FRAUD POST] HTTP ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅  [GPS FRAUD POST] Server accepted the log');
      } else {
        debugPrint('⚠️  [GPS FRAUD POST] Server returned ${response.statusCode} '
            '— body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      }
      debugPrint('🛰️  [GPS FRAUD POST] ===========================');
      debugPrint('');
    } catch (e) {
      // NEVER propagate — this is purely informational logging
      debugPrint('⚠️  [GPS FRAUD POST] Non-blocking error: $e');
    }
  }

  // ── util ──────────────────────────────────────────────────────────────────
  static String _safeString(SharedPreferences prefs, String key) {
    try {
      return prefs.get(key)?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }
}