import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LocationTrackerService
///
/// Alag file — timer_card.dart mein koi doosra logic change nahi hai.
///
/// Kya karta hai:
///   • Clock-in par  → start() call karein → immediately ek post karta hai
///     phir har 5 minute baad automatically POST karta rehta hai.
///   • Clock-out par → stop()  call karein → timer band ho jata hai.
///
/// POST body (JSON):
///   {
///     "lat":           <double>,
///     "lng":           <double>,
///     "emp_id":        <string>,   ← SharedPreferences se
///     "emp_name":      <string>,   ← SharedPreferences se
///     "company_code":  <string>,   ← SharedPreferences se
///     "date":          "dd-MM-yyyy HH:mm:ss",
///     "battery_percent": <int>     ← real device battery level (0-100)
///   }
/// ─────────────────────────────────────────────────────────────────────────────

class LocationTrackerService {
  // ── API endpoint — apna asli URL yahan lagaein ─────────────────────────────
  static const String _apiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/';// ← CHANGE THIS

  // ── SharedPreferences keys (timer_card.dart ke sath match) ─────────────────
  static const String _keyEmpId       = 'emp_id';
  static const String _keyEmpName     = 'emp_name';
  static const String _keyCompanyCode = 'company_code';

  // ── Fallback keys for emp_name ──────────────────────────────────────────────
  static const List<String> _empNameFallbacks = [
    'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
  ];

  // ── Fallback keys for company_code ─────────────────────────────────────────
  String _getCompanyCode(SharedPreferences prefs) {
    return prefs.getString(prefCompanyCode) ?? '';
  }

  // ── Timer + state ───────────────────────────────────────────────────────────
  Timer?    _timer;
  bool      _isRunning = false;
  int       _postCount = 0;      // kitni baar POST hua — debug ke liye
  DateTime? _startedAt;          // kab start hua

  // ── Battery ─────────────────────────────────────────────────────────────────
  final Battery _battery = Battery();

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════════

  /// Clock-in hone par call karein.
  /// Pehli post turant bhejta hai, phir har 5 minute baad.
  void start() {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 [TRACKER] start() called');

    if (_isRunning) {
      debugPrint('⚠️  [TRACKER] Already running — skipping duplicate start()');
      debugPrint('    Started at  : $_startedAt');
      debugPrint('    Posts sent  : $_postCount');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    _isRunning = true;
    _postCount = 0;
    _startedAt = DateTime.now();

    debugPrint('✅ [TRACKER] Service started successfully');
    debugPrint('    Started at  : $_startedAt');
    debugPrint('    Interval    : every 5 minutes');
    debugPrint('    API URL     : $_apiUrl');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Pehla POST abhi bhej dein
    debugPrint('📍 [TRACKER] Firing immediate first POST on clock-in...');
    _postLocation();

    // Phir har 5 minute baad automatically
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      debugPrint('⏰ [TRACKER] Timer tick #${timer.tick} fired — starting POST #${_postCount + 1}');
      _postLocation();
    });

    debugPrint('✅ [TRACKER] Periodic timer registered (5 min interval)');
  }

  /// Clock-out ya app dispose par call karein.
  void stop() {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🛑 [TRACKER] stop() called');

    if (!_isRunning) {
      debugPrint('ℹ️  [TRACKER] Was not running — nothing to stop');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    _timer?.cancel();
    _timer     = null;
    _isRunning = false;

    final Duration? runDuration = _startedAt != null
        ? DateTime.now().difference(_startedAt!)
        : null;

    debugPrint('✅ [TRACKER] Service stopped');
    debugPrint('    Total POSTs sent : $_postCount');
    if (runDuration != null) {
      debugPrint(
        '    Total run time   : '
            '${runDuration.inMinutes} min '
            '${runDuration.inSeconds.remainder(60)} sec',
      );
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    _postCount = 0;
    _startedAt = null;
  }

  /// Bahar se bhi ek dafa manually POST kar sakte hain (optional use).
  Future<void> postNow() {
    debugPrint('🔁 [TRACKER] postNow() called manually');
    return _postLocation();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CORE LOGIC
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _postLocation() async {
    _postCount++;
    final int    thisPost = _postCount;
    final String postTime = DateFormat('HH:mm:ss').format(DateTime.now());

    debugPrint('┌───────────────────────────────────────────────────────');
    debugPrint('│ 📡 [TRACKER] POST #$thisPost started at $postTime');
    debugPrint('└───────────────────────────────────────────────────────');

    try {

      // ── STEP 1: SharedPreferences se employee data lo ───────────────────────
      debugPrint('🔑 [TRACKER] Step 1 — Reading employee data from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();

      final String empId       = _safeGet(prefs, _keyEmpId);
      final String empName     = _safeGetFallback(prefs, _empNameFallbacks);
      final String companyCode = _getCompanyCode(prefs);

      debugPrint('   emp_id       : ${empId.isEmpty       ? "❌ NOT FOUND" : "✅ $empId"}');
      debugPrint('   emp_name     : ${empName.isEmpty     ? "⚠️  empty"    : "✅ $empName"}');
      debugPrint('   company_code : ${companyCode.isEmpty ? "⚠️  empty"    : "✅ $companyCode"}');

      if (empId.isEmpty) {
        debugPrint('❌ [TRACKER] emp_id is empty — cannot POST without employee ID');
        debugPrint('   Hint: Make sure "emp_id" is saved in SharedPreferences on login');
        _postCount--; // count se hatao kyunke actually bheja nahi
        return;
      }

      // ── STEP 2: GPS position lo ─────────────────────────────────────────────
      debugPrint('📍 [TRACKER] Step 2 — Getting GPS position...');
      final Stopwatch gpsWatch = Stopwatch()..start();

      final Position? position = await _getCurrentPosition();
      gpsWatch.stop();

      if (position == null) {
        debugPrint('❌ [TRACKER] GPS position is null — cannot POST without location');
        debugPrint('   GPS elapsed : ${gpsWatch.elapsedMilliseconds}ms');
        _postCount--;
        return;
      }

      final double lat = position.latitude;
      final double lng = position.longitude;

      debugPrint('✅ [TRACKER] GPS acquired in ${gpsWatch.elapsedMilliseconds}ms');
      debugPrint('   lat      : $lat');
      debugPrint('   lng      : $lng');
      debugPrint('   accuracy : ${position.accuracy.toStringAsFixed(1)} meters');
      debugPrint('   altitude : ${position.altitude.toStringAsFixed(1)} m');
      debugPrint('   speed    : ${position.speed.toStringAsFixed(2)} m/s');

      // ── STEP 3: Battery level lo ────────────────────────────────────────────
      debugPrint('🔋 [TRACKER] Step 3 — Reading battery level...');
      int batteryPercent = 0;
      try {
        batteryPercent = await _battery.batteryLevel;
        debugPrint('   battery_percent : $batteryPercent%');
      } catch (e) {
        debugPrint('   ⚠️  Battery read failed: $e — defaulting to 0');
      }

      // ── STEP 4: Date format karo ────────────────────────────────────────────
      debugPrint('📅 [TRACKER] Step 4 — Formatting date...');
      final String date =
      DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      debugPrint('   date     : $date');

      // ── STEP 5: POST body banao ─────────────────────────────────────────────
      debugPrint('📦 [TRACKER] Step 5 — Building request body...');
      final Map<String, dynamic> body = {
        'lat'            : lat,
        'lng'            : lng,
        'emp_id'         : empId,
        'emp_name'       : empName,
        'company_code'   : companyCode,
        'track_date'     : date,
        'battery_percent': batteryPercent,
      };

      final String jsonBody = jsonEncode(body);
      debugPrint('   JSON body : $jsonBody');

      // ── STEP 6: HTTP POST bhejo ─────────────────────────────────────────────
      debugPrint('🌐 [TRACKER] Step 6 — Sending HTTP POST...');
      debugPrint('   URL         : $_apiUrl');
      debugPrint('   Method      : POST');
      debugPrint('   Content-Type: application/json');

      final Stopwatch httpWatch = Stopwatch()..start();

      final http.Response response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonBody,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏱️  [TRACKER] HTTP timeout after 15 seconds — server not responding');
          return http.Response('{"error":"timeout"}', 408);
        },
      );

      httpWatch.stop();

      // ── STEP 7: Response handle karo ────────────────────────────────────────
      debugPrint('📥 [TRACKER] Step 7 — Response received in ${httpWatch.elapsedMilliseconds}ms');
      debugPrint('   Status code   : ${response.statusCode}');
      debugPrint('   Response body : ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [TRACKER] POST #$thisPost SUCCESS ─────────────────────');
        debugPrint('   emp_id          : $empId');
        debugPrint('   emp_name        : $empName');
        debugPrint('   company_code    : $companyCode');
        debugPrint('   lat             : $lat');
        debugPrint('   lng             : $lng');
        debugPrint('   battery_percent : $batteryPercent%');
        debugPrint('   date            : $date');
        debugPrint('   HTTP status     : ${response.statusCode}');
        debugPrint('   Round-trip      : ${httpWatch.elapsedMilliseconds}ms');
      } else if (response.statusCode == 408) {
        debugPrint('⏱️  [TRACKER] POST #$thisPost TIMEOUT (408)');
        debugPrint('   Will retry automatically on next 5-minute tick');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        debugPrint('❌ [TRACKER] POST #$thisPost CLIENT ERROR ${response.statusCode}');
        debugPrint('   Check: API URL sahi hai? Request format sahi hai?');
        debugPrint('   Response: ${response.body}');
      } else if (response.statusCode >= 500) {
        debugPrint('❌ [TRACKER] POST #$thisPost SERVER ERROR ${response.statusCode}');
        debugPrint('   Server side issue — will retry on next tick');
        debugPrint('   Response: ${response.body}');
      } else {
        debugPrint('⚠️  [TRACKER] POST #$thisPost unexpected status ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }

    } catch (e, stackTrace) {
      debugPrint('❌ [TRACKER] POST #$thisPost EXCEPTION ──────────────────────');
      debugPrint('   Error      : $e');
      debugPrint('   StackTrace : $stackTrace');
    }

    debugPrint('┌───────────────────────────────────────────────────────');
    debugPrint('│ ✔  [TRACKER] POST #$thisPost finished | Total so far: $_postCount');
    debugPrint('└───────────────────────────────────────────────────────');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Geolocator se current position lata hai.
  Future<Position?> _getCurrentPosition() async {
    debugPrint('🛰️  [TRACKER GPS] Checking location permission...');
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('    Permission status : $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️  [TRACKER GPS] Permission denied — not requesting again (clock-in already checked)');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ [TRACKER GPS] Permission permanently denied — user must enable from Settings');
        return null;
      }

      debugPrint('🛰️  [TRACKER GPS] Checking if location service is enabled...');
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('    Location service enabled : $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('❌ [TRACKER GPS] Location service is OFF — cannot get position');
        return null;
      }

      debugPrint('🛰️  [TRACKER GPS] Requesting current position (high accuracy)...');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          debugPrint('⚠️  [TRACKER GPS] getCurrentPosition timed out after 10s');
          debugPrint('🔄 [TRACKER GPS] Falling back to last known position...');
          final Position? last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            final int ageSeconds =
                DateTime.now().difference(last.timestamp).inSeconds;
            debugPrint('✅ [TRACKER GPS] Last known position found:');
            debugPrint('    lat : ${last.latitude}  lng : ${last.longitude}');
            debugPrint('    age : ${ageSeconds}s ago');
            return last;
          }
          debugPrint('❌ [TRACKER GPS] No last known position available');
          throw Exception('GPS timeout and no last known position');
        },
      );

      debugPrint('✅ [TRACKER GPS] Live position acquired successfully');
      return position;

    } catch (e) {
      debugPrint('❌ [TRACKER GPS] Exception: $e');
      debugPrint('🔄 [TRACKER GPS] Final fallback — trying getLastKnownPosition...');
      try {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          debugPrint('✅ [TRACKER GPS] Fallback last-known position used');
          debugPrint('    lat : ${last.latitude}  lng : ${last.longitude}');
        } else {
          debugPrint('❌ [TRACKER GPS] No fallback position available — returning null');
        }
        return last;
      } catch (fallbackError) {
        debugPrint('❌ [TRACKER GPS] Fallback also failed: $fallbackError');
        return null;
      }
    }
  }

  /// SharedPreferences se safely ek single key ki value lata hai.
  String _safeGet(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) {
        debugPrint('    🔍 [PREFS] key="$key" → null');
        return '';
      }
      final String val = raw.toString().trim();
      debugPrint('    🔍 [PREFS] key="$key" → "$val"');
      return val;
    } catch (e) {
      debugPrint('    ❌ [PREFS] key="$key" exception: $e');
      return '';
    }
  }

  /// Multiple fallback keys mein se pehli milne wali non-empty value lata hai.
  String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
    debugPrint('    🔍 [PREFS] Searching keys: $keys');
    for (final String key in keys) {
      try {
        final dynamic raw = prefs.get(key);
        if (raw != null) {
          final String val = raw.toString().trim();
          if (val.isNotEmpty) {
            debugPrint('    ✅ [PREFS] Found at key="$key" → "$val"');
            return val;
          }
        }
      } catch (e) {
        debugPrint('    ⚠️  [PREFS] Error reading key="$key": $e');
      }
    }
    debugPrint('    ⚠️  [PREFS] None of the fallback keys had a value');
    return '';
  }
}