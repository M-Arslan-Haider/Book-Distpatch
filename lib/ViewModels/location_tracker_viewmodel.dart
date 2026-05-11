//
//
// import 'dart:async';
// import 'dart:convert';
// import 'package:battery_plus/battery_plus.dart';
// import 'package:flutter/foundation.dart';
// import 'package:geocoding/geocoding.dart';          // ← NEW
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../constants.dart';
//
// class LocationTrackerService {
//   static const String _apiUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/';
//
//   static const String _keyEmpId       = 'emp_id';
//   static const String _keyEmpName     = 'emp_name';
//   static const String _keyCompanyCode = 'company_code';
//
//   static const List<String> _empNameFallbacks = [
//     'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
//   ];
//
//   String _getCompanyCode(SharedPreferences prefs) {
//     return prefs.getString(prefCompanyCode) ?? '';
//   }
//
//   Timer?    _timer;
//   bool      _isRunning = false;
//   int       _postCount = 0;
//   DateTime? _startedAt;
//
//   final Battery _battery = Battery();
//
//   // ════════════════════════════════════════════════════════════════════════════
//   // PUBLIC API
//   // ════════════════════════════════════════════════════════════════════════════
//
//   void start() {
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//     debugPrint('🚀 [TRACKER] start() called');
//
//     if (_isRunning) {
//       debugPrint('⚠️  [TRACKER] Already running — skipping duplicate start()');
//       debugPrint('    Started at  : $_startedAt');
//       debugPrint('    Posts sent  : $_postCount');
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       return;
//     }
//
//     _isRunning = true;
//     _postCount = 0;
//     _startedAt = DateTime.now();
//
//     debugPrint('✅ [TRACKER] Service started successfully');
//     debugPrint('    Started at  : $_startedAt');
//     debugPrint('    Interval    : every 5 minutes');
//     debugPrint('    API URL     : $_apiUrl');
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//     debugPrint('📍 [TRACKER] Firing immediate first POST on clock-in...');
//     _postLocation();
//
//     _timer = Timer.periodic(const Duration(minutes: 2
//     ), (timer) {
//       debugPrint('⏰ [TRACKER] Timer tick #${timer.tick} fired — starting POST #${_postCount + 1}');
//       _postLocation();
//     });
//
//     debugPrint('✅ [TRACKER] Periodic timer registered (5 min interval)');
//   }
//
//   void stop() {
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//     debugPrint('🛑 [TRACKER] stop() called');
//
//     if (!_isRunning) {
//       debugPrint('ℹ️  [TRACKER] Was not running — nothing to stop');
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       return;
//     }
//
//     _timer?.cancel();
//     _timer     = null;
//     _isRunning = false;
//
//     final Duration? runDuration = _startedAt != null
//         ? DateTime.now().difference(_startedAt!)
//         : null;
//
//     debugPrint('✅ [TRACKER] Service stopped');
//     debugPrint('    Total POSTs sent : $_postCount');
//     if (runDuration != null) {
//       debugPrint(
//         '    Total run time   : '
//             '${runDuration.inMinutes} min '
//             '${runDuration.inSeconds.remainder(60)} sec',
//       );
//     }
//     debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//     _postCount = 0;
//     _startedAt = null;
//   }
//
//   Future<void> postNow() {
//     debugPrint('🔁 [TRACKER] postNow() called manually');
//     return _postLocation();
//   }
//
//   // ════════════════════════════════════════════════════════════════════════════
//   // CORE LOGIC
//   // ════════════════════════════════════════════════════════════════════════════
//
//   Future<void> _postLocation() async {
//     _postCount++;
//     final int    thisPost = _postCount;
//     final String postTime = DateFormat('HH:mm:ss').format(DateTime.now());
//
//     debugPrint('┌───────────────────────────────────────────────────────');
//     debugPrint('│ 📡 [TRACKER] POST #$thisPost started at $postTime');
//     debugPrint('└───────────────────────────────────────────────────────');
//
//     try {
//       // ── STEP 1: SharedPreferences se employee data lo ───────────────────────
//       debugPrint('🔑 [TRACKER] Step 1 — Reading employee data from SharedPreferences...');
//       final prefs = await SharedPreferences.getInstance();
//
//       final String empId       = _safeGet(prefs, _keyEmpId);
//       final String empName     = _safeGetFallback(prefs, _empNameFallbacks);
//       final String companyCode = _getCompanyCode(prefs);
//
//       debugPrint('   emp_id       : ${empId.isEmpty       ? "❌ NOT FOUND" : "✅ $empId"}');
//       debugPrint('   emp_name     : ${empName.isEmpty     ? "⚠️  empty"    : "✅ $empName"}');
//       debugPrint('   company_code : ${companyCode.isEmpty ? "⚠️  empty"    : "✅ $companyCode"}');
//
//       if (empId.isEmpty) {
//         debugPrint('❌ [TRACKER] emp_id is empty — cannot POST without employee ID');
//         _postCount--;
//         return;
//       }
//
//       // ── STEP 2: GPS position lo ─────────────────────────────────────────────
//       debugPrint('📍 [TRACKER] Step 2 — Getting GPS position...');
//       final Stopwatch gpsWatch = Stopwatch()..start();
//
//       final Position? position = await _getCurrentPosition();
//       gpsWatch.stop();
//
//       if (position == null) {
//         debugPrint('❌ [TRACKER] GPS position is null — cannot POST without location');
//         _postCount--;
//         return;
//       }
//
//       final double lat = position.latitude;
//       final double lng = position.longitude;
//
//       debugPrint('✅ [TRACKER] GPS acquired in ${gpsWatch.elapsedMilliseconds}ms');
//       debugPrint('   lat      : $lat');
//       debugPrint('   lng      : $lng');
//       debugPrint('   accuracy : ${position.accuracy.toStringAsFixed(1)} meters');
//
//       // ── STEP 3: Battery level lo ────────────────────────────────────────────
//       debugPrint('🔋 [TRACKER] Step 3 — Reading battery level...');
//       int batteryPercent = 0;
//       try {
//         batteryPercent = await _battery.batteryLevel;
//         debugPrint('   battery_percent : $batteryPercent%');
//       } catch (e) {
//         debugPrint('   ⚠️  Battery read failed: $e — defaulting to 0');
//       }
//
//       // ── STEP 3.5: Reverse geocode address ───────────────────────────────────  ← NEW
//       debugPrint('🏠 [TRACKER] Step 3.5 — Reverse geocoding address...');
//       final String address = await _getAddress(lat, lng);
//       debugPrint('   address : ${address.isEmpty ? "⚠️  not found" : "✅ $address"}');
//
//       // ── STEP 4: Date format karo ────────────────────────────────────────────
//       debugPrint('📅 [TRACKER] Step 4 — Formatting date...');
//       final String date =
//       DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
//       debugPrint('   date     : $date');
//
//       // ── STEP 5: POST body banao ─────────────────────────────────────────────
//       debugPrint('📦 [TRACKER] Step 5 — Building request body...');
//       final Map<String, dynamic> body = {
//         'lat'            : lat,
//         'lng'            : lng,
//         'emp_id'         : empId,
//         'emp_name'       : empName,
//         'company_code'   : companyCode,
//         'track_date'     : date,
//         'battery_percent': batteryPercent,
//         'address'        : address,           // ← NEW
//       };
//
//       final String jsonBody = jsonEncode(body);
//       debugPrint('   JSON body : $jsonBody');
//
//       // ── STEP 6: HTTP POST bhejo ─────────────────────────────────────────────
//       debugPrint('🌐 [TRACKER] Step 6 — Sending HTTP POST...');
//       final Stopwatch httpWatch = Stopwatch()..start();
//
//       final http.Response response = await http
//           .post(
//         Uri.parse(_apiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept'      : 'application/json',
//         },
//         body: jsonBody,
//       )
//           .timeout(
//         const Duration(seconds: 15),
//         onTimeout: () {
//           debugPrint('⏱️  [TRACKER] HTTP timeout after 15 seconds');
//           return http.Response('{"error":"timeout"}', 408);
//         },
//       );
//
//       httpWatch.stop();
//
//       // ── STEP 7: Response handle karo ────────────────────────────────────────
//       debugPrint('📥 [TRACKER] Step 7 — Response received in ${httpWatch.elapsedMilliseconds}ms');
//       debugPrint('   Status code   : ${response.statusCode}');
//       debugPrint('   Response body : ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [TRACKER] POST #$thisPost SUCCESS ─────────────────────');
//         debugPrint('   emp_id          : $empId');
//         debugPrint('   emp_name        : $empName');
//         debugPrint('   company_code    : $companyCode');
//         debugPrint('   lat             : $lat');
//         debugPrint('   lng             : $lng');
//         debugPrint('   address         : $address');
//         debugPrint('   battery_percent : $batteryPercent%');
//         debugPrint('   date            : $date');
//         debugPrint('   HTTP status     : ${response.statusCode}');
//       } else if (response.statusCode == 408) {
//         debugPrint('⏱️  [TRACKER] POST #$thisPost TIMEOUT (408)');
//       } else if (response.statusCode >= 400 && response.statusCode < 500) {
//         debugPrint('❌ [TRACKER] POST #$thisPost CLIENT ERROR ${response.statusCode}');
//         debugPrint('   Response: ${response.body}');
//       } else if (response.statusCode >= 500) {
//         debugPrint('❌ [TRACKER] POST #$thisPost SERVER ERROR ${response.statusCode}');
//         debugPrint('   Response: ${response.body}');
//       } else {
//         debugPrint('⚠️  [TRACKER] POST #$thisPost unexpected status ${response.statusCode}');
//       }
//
//     } catch (e, stackTrace) {
//       debugPrint('❌ [TRACKER] POST #$thisPost EXCEPTION ──────────────────────');
//       debugPrint('   Error      : $e');
//       debugPrint('   StackTrace : $stackTrace');
//     }
//
//     debugPrint('┌───────────────────────────────────────────────────────');
//     debugPrint('│ ✔  [TRACKER] POST #$thisPost finished | Total so far: $_postCount');
//     debugPrint('└───────────────────────────────────────────────────────');
//   }
//
//   // ════════════════════════════════════════════════════════════════════════════
//   // REVERSE GEOCODING  ← NEW METHOD
//   // ════════════════════════════════════════════════════════════════════════════
//
//   /// lat/lng se human-readable address return karta hai.
//   /// Format: "Street, SubLocality, City, Country"
//   /// Agar koi error aaye to empty string return karta hai.
//   Future<String> _getAddress(double lat, double lng) async {
//     try {
//       final List<Placemark> placemarks =
//       await placemarkFromCoordinates(lat, lng)
//           .timeout(const Duration(seconds: 10));
//
//       if (placemarks.isEmpty) {
//         debugPrint('   ⚠️  [GEOCODE] No placemarks returned for ($lat, $lng)');
//         return '';
//       }
//
//       final Placemark p = placemarks.first;
//
//       debugPrint('   🗺️  [GEOCODE] Raw placemark:');
//       debugPrint('       name          : ${p.name}');
//       debugPrint('       street        : ${p.street}');
//       debugPrint('       subLocality   : ${p.subLocality}');
//       debugPrint('       locality      : ${p.locality}');
//       debugPrint('       subAdminArea  : ${p.subAdministrativeArea}');
//       debugPrint('       adminArea     : ${p.administrativeArea}');
//       debugPrint('       postalCode    : ${p.postalCode}');
//       debugPrint('       country       : ${p.country}');
//
//       // Non-empty parts join karo
//       final List<String> parts = [
//         if (p.street?.isNotEmpty       == true) p.street!,
//         if (p.subLocality?.isNotEmpty  == true) p.subLocality!,
//         if (p.locality?.isNotEmpty     == true) p.locality!,
//         if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
//         if (p.country?.isNotEmpty      == true) p.country!,
//       ];
//
//       final String address = parts.join(', ');
//       debugPrint('   ✅ [GEOCODE] Formatted address: "$address"');
//       return address;
//
//     } catch (e) {
//       debugPrint('   ❌ [GEOCODE] Reverse geocode failed: $e');
//       return '';
//     }
//   }
//
//   // ════════════════════════════════════════════════════════════════════════════
//   // HELPERS (unchanged)
//   // ════════════════════════════════════════════════════════════════════════════
//
//   Future<Position?> _getCurrentPosition() async {
//     debugPrint('🛰️  [TRACKER GPS] Checking location permission...');
//     try {
//       final LocationPermission permission = await Geolocator.checkPermission();
//       debugPrint('    Permission status : $permission');
//
//       if (permission == LocationPermission.denied) {
//         debugPrint('⚠️  [TRACKER GPS] Permission denied');
//         return null;
//       }
//
//       if (permission == LocationPermission.deniedForever) {
//         debugPrint('❌ [TRACKER GPS] Permission permanently denied');
//         return null;
//       }
//
//       final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         debugPrint('❌ [TRACKER GPS] Location service is OFF');
//         return null;
//       }
//
//       final Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       ).timeout(
//         const Duration(seconds: 10),
//         onTimeout: () async {
//           debugPrint('⚠️  [TRACKER GPS] Timed out — falling back to last known position');
//           final Position? last = await Geolocator.getLastKnownPosition();
//           if (last != null) return last;
//           throw Exception('GPS timeout and no last known position');
//         },
//       );
//
//       return position;
//
//     } catch (e) {
//       debugPrint('❌ [TRACKER GPS] Exception: $e');
//       try {
//         return await Geolocator.getLastKnownPosition();
//       } catch (_) {
//         return null;
//       }
//     }
//   }
//
//   String _safeGet(SharedPreferences prefs, String key) {
//     try {
//       final dynamic raw = prefs.get(key);
//       if (raw == null) return '';
//       return raw.toString().trim();
//     } catch (e) {
//       return '';
//     }
//   }
//
//   String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
//     for (final String key in keys) {
//       try {
//         final dynamic raw = prefs.get(key);
//         if (raw != null) {
//           final String val = raw.toString().trim();
//           if (val.isNotEmpty) return val;
//         }
//       } catch (_) {}
//     }
//     return '';
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';          // ← NEW
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/remote_config_service.dart';
import '../constants.dart';

class LocationTrackerService {
  // static const String _apiUrl =
  //     'http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/';

  ///firebase
  // WITH:
  static String get _apiUrl => RemoteConfigService.getEmpLocationUrl();

  static const String _keyEmpId       = 'emp_id';
  static const String _keyEmpName     = 'emp_name';
  static const String _keyCompanyCode = 'company_code';

  static const List<String> _empNameFallbacks = [
    'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
  ];

  String _getCompanyCode(SharedPreferences prefs) {
    return prefs.getString(prefCompanyCode) ?? '';
  }

  Timer?    _timer;
  bool      _isRunning = false;
  int       _postCount = 0;
  DateTime? _startedAt;

  final Battery _battery = Battery();

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════════

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

    debugPrint('📍 [TRACKER] Firing immediate first POST on clock-in...');
    _postLocation();

    _timer = Timer.periodic(const Duration(minutes: 3), (timer) {
      debugPrint('⏰ [TRACKER] Timer tick #${timer.tick} fired — starting POST #${_postCount + 1}');
      _postLocation();
    });

    debugPrint('✅ [TRACKER] Periodic timer registered (5 min interval)');
  }

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
        _postCount--;
        return;
      }

      // ── STEP 2: GPS position lo ─────────────────────────────────────────────
      debugPrint('📍 [TRACKER] Step 2 — Getting GPS position...');
      final Stopwatch gpsWatch = Stopwatch()..start();

      final Position? position = await _getCurrentPosition();
      gpsWatch.stop();

      if (position == null) {
        debugPrint('❌ [TRACKER] GPS position is null — cannot POST without location');
        _postCount--;
        return;
      }

      final double lat = position.latitude;
      final double lng = position.longitude;

      debugPrint('✅ [TRACKER] GPS acquired in ${gpsWatch.elapsedMilliseconds}ms');
      debugPrint('   lat      : $lat');
      debugPrint('   lng      : $lng');
      debugPrint('   accuracy : ${position.accuracy.toStringAsFixed(1)} meters');

      // ── STEP 3: Battery level lo ────────────────────────────────────────────
      debugPrint('🔋 [TRACKER] Step 3 — Reading battery level...');
      int batteryPercent = 0;
      try {
        batteryPercent = await _battery.batteryLevel;
        debugPrint('   battery_percent : $batteryPercent%');
      } catch (e) {
        debugPrint('   ⚠️  Battery read failed: $e — defaulting to 0');
      }

      // ── STEP 3.5: Reverse geocode address ───────────────────────────────────  ← NEW
      debugPrint('🏠 [TRACKER] Step 3.5 — Reverse geocoding address...');
      final String address = await _getAddress(lat, lng);
      debugPrint('   address : ${address.isEmpty ? "⚠️  not found" : "✅ $address"}');

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
        'address'        : address,           // ← NEW
      };

      final String jsonBody = jsonEncode(body);
      debugPrint('   JSON body : $jsonBody');

      // ── STEP 6: HTTP POST bhejo ─────────────────────────────────────────────
      debugPrint('🌐 [TRACKER] Step 6 — Sending HTTP POST...');
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
          debugPrint('⏱️  [TRACKER] HTTP timeout after 15 seconds');
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
        debugPrint('   address         : $address');
        debugPrint('   battery_percent : $batteryPercent%');
        debugPrint('   date            : $date');
        debugPrint('   HTTP status     : ${response.statusCode}');
      } else if (response.statusCode == 408) {
        debugPrint('⏱️  [TRACKER] POST #$thisPost TIMEOUT (408)');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        debugPrint('❌ [TRACKER] POST #$thisPost CLIENT ERROR ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      } else if (response.statusCode >= 500) {
        debugPrint('❌ [TRACKER] POST #$thisPost SERVER ERROR ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      } else {
        debugPrint('⚠️  [TRACKER] POST #$thisPost unexpected status ${response.statusCode}');
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
  // REVERSE GEOCODING  ← NEW METHOD
  // ════════════════════════════════════════════════════════════════════════════

  /// lat/lng se human-readable address return karta hai.
  /// Format: "Street, SubLocality, City, Country"
  /// Agar koi error aaye to empty string return karta hai.
  Future<String> _getAddress(double lat, double lng) async {
    try {
      final List<Placemark> placemarks =
      await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) {
        debugPrint('   ⚠️  [GEOCODE] No placemarks returned for ($lat, $lng)');
        return '';
      }

      final Placemark p = placemarks.first;

      debugPrint('   🗺️  [GEOCODE] Raw placemark:');
      debugPrint('       name          : ${p.name}');
      debugPrint('       street        : ${p.street}');
      debugPrint('       subLocality   : ${p.subLocality}');
      debugPrint('       locality      : ${p.locality}');
      debugPrint('       subAdminArea  : ${p.subAdministrativeArea}');
      debugPrint('       adminArea     : ${p.administrativeArea}');
      debugPrint('       postalCode    : ${p.postalCode}');
      debugPrint('       country       : ${p.country}');

      // Non-empty parts join karo
      final List<String> parts = [
        if (p.street?.isNotEmpty       == true) p.street!,
        if (p.subLocality?.isNotEmpty  == true) p.subLocality!,
        if (p.locality?.isNotEmpty     == true) p.locality!,
        if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
        if (p.country?.isNotEmpty      == true) p.country!,
      ];

      final String address = parts.join(', ');
      debugPrint('   ✅ [GEOCODE] Formatted address: "$address"');
      return address;

    } catch (e) {
      debugPrint('   ❌ [GEOCODE] Reverse geocode failed: $e');
      return '';
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS (unchanged)
  // ════════════════════════════════════════════════════════════════════════════

  Future<Position?> _getCurrentPosition() async {
    debugPrint('🛰️  [TRACKER GPS] Checking location permission...');
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('    Permission status : $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️  [TRACKER GPS] Permission denied');
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ [TRACKER GPS] Permission permanently denied');
        return null;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ [TRACKER GPS] Location service is OFF');
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          debugPrint('⚠️  [TRACKER GPS] Timed out — falling back to last known position');
          final Position? last = await Geolocator.getLastKnownPosition();
          if (last != null) return last;
          throw Exception('GPS timeout and no last known position');
        },
      );

      return position;

    } catch (e) {
      debugPrint('❌ [TRACKER GPS] Exception: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  String _safeGet(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return '';
      return raw.toString().trim();
    } catch (e) {
      return '';
    }
  }

  String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
    for (final String key in keys) {
      try {
        final dynamic raw = prefs.get(key);
        if (raw != null) {
          final String val = raw.toString().trim();
          if (val.isNotEmpty) return val;
        }
      } catch (_) {}
    }
    return '';
  }
}