// lib/ViewModels/geofence_violation_view_model.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/geofancing_violation_model.dart';

class GeofenceViolationViewModel extends GetxController {
  // ── API URL ───────────────────────────────────────────────────────────────
  static const String _apiUrl =
      'http://oracle.metaxperts.net/ords/production/geofencepost/post/';

  // ── SharedPreferences key ─────────────────────────────────────────────────
  static const String _kViolationsKey = 'geofence_violations_today';

  // ── Observables ───────────────────────────────────────────────────────────
  var violations     = <GeofenceViolation>[].obs;
  var isOutside      = false.obs;
  var outsideSeconds = 0.obs;

  // ── Internal ──────────────────────────────────────────────────────────────
  Timer? _monitorTimer;
  Timer? _outsideCounterTimer;
  bool   _isMonitoring = false;

  double? _watch_lat;
  double? _watch_lng;
  double? _watch_radius;
  String  _location_name = '';
  String  _emp_id        = '';
  String  _emp_name      = '';

  static const Duration _checkInterval = Duration(seconds: 10);

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔧 [GeofenceVM] ========== VIEW MODEL INITIALIZED ==========');
    _restoreViolations();
  }

  @override
  void onClose() {
    debugPrint('🔧 [GeofenceVM] View Model closing, cleaning up timers');
    _monitorTimer?.cancel();
    _outsideCounterTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – START
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> startMonitoring({
    required double lat,
    required double lng,
    required double radiusMeters,
    required String locationName,
  }) async {
    debugPrint('🚀 [GeofenceVM] ========== START MONITORING CALLED ==========');
    debugPrint('🚀 [GeofenceVM] Parameters:');
    debugPrint('🚀 [GeofenceVM]   - lat: $lat');
    debugPrint('🚀 [GeofenceVM]   - lng: $lng');
    debugPrint('🚀 [GeofenceVM]   - radiusMeters: $radiusMeters');
    debugPrint('🚀 [GeofenceVM]   - locationName: "$locationName"');

    if (lat == 0.0 && lng == 0.0) {
      debugPrint('❌ [GeofenceVM] ABORTED — lat/lng are 0.0');
      return;
    }

    _watch_lat     = lat;
    _watch_lng     = lng;
    _watch_radius  = radiusMeters;
    _location_name = locationName;
    _isMonitoring  = true;

    final prefs = await SharedPreferences.getInstance();
    debugPrint('🔧 [GeofenceVM] SharedPreferences instance obtained');

    _emp_id   = _safeGet(prefs, 'emp_id');
    _emp_name = _safeGetFallback(prefs, [
      'emp_name', 'empName', 'employee_name', 'name', 'userName',
    ]);

    debugPrint('👤 [GeofenceVM] Employee Info:');
    debugPrint('👤 [GeofenceVM]   - emp_id: "$_emp_id"');
    debugPrint('👤 [GeofenceVM]   - emp_name: "$_emp_name"');

    if (_emp_id.isEmpty) {
      debugPrint('⚠️ [GeofenceVM] WARNING: emp_id is EMPTY! Backend posts may fail!');
    }
    if (_emp_name.isEmpty) {
      debugPrint('⚠️ [GeofenceVM] WARNING: emp_name is EMPTY! Backend posts may fail!');
    }

    // Clear old day violations
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    debugPrint('📅 [GeofenceVM] Today\'s date: $today');

    if (violations.isNotEmpty && violations.first.violation_date != today) {
      debugPrint('🧹 [GeofenceVM] Clearing old violations (date mismatch)');
      violations.clear();
      await _persistViolations();
    }

    isOutside.value      = false;
    outsideSeconds.value = 0;

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_checkInterval, (_) {
      if (_isMonitoring) _checkGeofence();
    });

    debugPrint('✅ [GeofenceVM] ══════════════════════════════════');
    debugPrint('✅ [GeofenceVM] Monitoring STARTED');
    debugPrint('✅ [GeofenceVM] location_name : "$locationName"');
    debugPrint('✅ [GeofenceVM] Coords        : ($lat, $lng)');
    debugPrint('✅ [GeofenceVM] Radius        : ${radiusMeters.toStringAsFixed(1)} m');
    debugPrint('✅ [GeofenceVM] emp_id        : $_emp_id | emp_name: $_emp_name');
    debugPrint('✅ [GeofenceVM] Interval      : ${_checkInterval.inSeconds}s');
    debugPrint('✅ [GeofenceVM] API URL       : $_apiUrl');
    debugPrint('✅ [GeofenceVM] ══════════════════════════════════');

    // First check after 2s GPS warm-up
    Future.delayed(const Duration(seconds: 2), () {
      if (_isMonitoring) _checkGeofence();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – STOP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> stopMonitoring() async {
    debugPrint('🛑 [GeofenceVM] ========== STOP MONITORING CALLED ==========');
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _outsideCounterTimer?.cancel();
    _outsideCounterTimer = null;

    if (isOutside.value) {
      debugPrint('🛑 [GeofenceVM] User was outside, closing violation');
      _closeCurrentViolation(DateTime.now());
    }

    isOutside.value      = false;
    outsideSeconds.value = 0;

    debugPrint('🛑 [GeofenceVM] Monitoring STOPPED');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLEAR
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clearViolations() async {
    debugPrint('🧹 [GeofenceVM] Clearing all violations');
    violations.clear();
    isOutside.value      = false;
    outsideSeconds.value = 0;
    await _persistViolations();
    debugPrint('🧹 [GeofenceVM] Violations cleared');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – GEOFENCE CHECK
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkGeofence() async {
    debugPrint('📍 [GeofenceVM] ========== GEOFENCE CHECK ==========');

    if (_watch_lat == null || _watch_lng == null || _watch_radius == null) {
      debugPrint('⚠️ [GeofenceVM] Missing geofence parameters:');
      debugPrint('   - _watch_lat: $_watch_lat');
      debugPrint('   - _watch_lng: $_watch_lng');
      debugPrint('   - _watch_radius: $_watch_radius');
      return;
    }

    try {
      debugPrint('📍 [GeofenceVM] Getting current position...');
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        debugPrint('📍 [GeofenceVM] Got position via getCurrentPosition');
      } catch (e) {
        debugPrint('⚠️ [GeofenceVM] getCurrentPosition failed: $e');
        pos = await Geolocator.getLastKnownPosition();
        debugPrint('📍 [GeofenceVM] Using last known position: ${pos != null ? "success" : "failed"}');
      }

      if (pos == null) {
        debugPrint('⚠️ [GeofenceVM] No position available — skipping check');
        return;
      }

      debugPrint('📍 [GeofenceVM] Current position:');
      debugPrint('   - latitude: ${pos.latitude}');
      debugPrint('   - longitude: ${pos.longitude}');
      debugPrint('   - accuracy: ${pos.accuracy} m');

      final distance_meters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _watch_lat!,  _watch_lng!,
      );

      final within_radius = distance_meters <= _watch_radius!;

      debugPrint('📏 [GeofenceVM] Distance calculation:');
      debugPrint('   - distance: ${distance_meters.toStringAsFixed(1)} m');
      debugPrint('   - radius: ${_watch_radius!.toStringAsFixed(1)} m');
      debugPrint('   - within_radius: $within_radius');
      debugPrint('   - isOutside currently: ${isOutside.value}');

      if (!within_radius && !isOutside.value) {
        debugPrint('🚨 [GeofenceVM] TRIGGER: User EXITED geofence!');
        _onUserExited(DateTime.now(), distance_meters);
      } else if (within_radius && isOutside.value) {
        debugPrint('✅ [GeofenceVM] TRIGGER: User RETURNED to geofence!');
        _onUserReturned(DateTime.now());
      } else {
        debugPrint('ℹ️ [GeofenceVM] No state change needed');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [GeofenceVM] GPS check failed: $e');
      debugPrint('❌ [GeofenceVM] Stack trace: $stackTrace');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – EXIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onUserExited(DateTime out_time, double distance_meters) async {
    debugPrint('🚨 [GeofenceVM] ========== USER EXITED ==========');
    debugPrint('🚨 [GeofenceVM] Time: ${GeofenceViolation.fmt(out_time)}');
    debugPrint('🚨 [GeofenceVM] Distance from center: ${distance_meters.toStringAsFixed(1)} m');

    isOutside.value      = true;
    outsideSeconds.value = 0;

    final today        = DateFormat('yyyy-MM-dd').format(out_time);
    final violation_id = 'VIO-${_emp_id.padLeft(3, '0')}-${out_time.millisecondsSinceEpoch}';

    debugPrint('📝 [GeofenceVM] Creating violation record:');
    debugPrint('   - violation_id: $violation_id');
    debugPrint('   - emp_id: $_emp_id');
    debugPrint('   - emp_name: $_emp_name');
    debugPrint('   - location_name: $_location_name');
    debugPrint('   - violation_date: $today');
    debugPrint('   - out_time: ${GeofenceViolation.fmt(out_time)}');

    final violation = GeofenceViolation(
      violation_id   : violation_id,
      emp_id         : _emp_id,
      emp_name       : _emp_name,
      event_type     : 'out',
      location_name  : _location_name,
      violation_date : today,
      out_time       : out_time,
      in_time        : null,
    );

    violations.add(violation);
    debugPrint('📊 [GeofenceVM] Violations count: ${violations.length}');

    await _persistViolations();
    _startOutsideCounter();

    debugPrint('🚨 [GeofenceVM] VIOLATION — out at ${violation.outTimeLabel} '
        '| distance: ${distance_meters.toStringAsFixed(1)} m');

    // POST "out" row to backend
    await _postViolationEvent(violation, eventType: 'out');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – RETURN
  // ─────────────────────────────────────────────────────────────────────────

  void _onUserReturned(DateTime in_time) {
    debugPrint('✅ [GeofenceVM] ========== USER RETURNED ==========');
    debugPrint('✅ [GeofenceVM] Time: ${GeofenceViolation.fmt(in_time)}');

    isOutside.value = false;
    _outsideCounterTimer?.cancel();
    _closeCurrentViolation(in_time);

    debugPrint('✅ [GeofenceVM] User RETURNED at ${GeofenceViolation.fmt(in_time)}');
  }

  void _closeCurrentViolation(DateTime in_time) {
    debugPrint('🔒 [GeofenceVM] Closing current violation');

    final idx = violations.lastIndexWhere((v) => v.in_time == null);
    if (idx < 0) {
      debugPrint('⚠️ [GeofenceVM] No open violation found to close!');
      return;
    }

    debugPrint('🔒 [GeofenceVM] Found open violation at index $idx');
    debugPrint('   - violation_id: ${violations[idx].violation_id}');
    debugPrint('   - out_time: ${violations[idx].outTimeLabel}');

    final updated = violations[idx].copyWith(
      in_time    : in_time,
      event_type : 'in',
    );
    violations[idx] = updated;
    violations.refresh();

    debugPrint('🔒 [GeofenceVM] Updated violation with in_time: ${updated.inTimeLabel}');

    _persistViolations();

    debugPrint('📝 [GeofenceVM] Closed: out=${updated.outTimeLabel} '
        '→ in=${updated.inTimeLabel} (${updated.total_out_duration})');

    // POST "in" row to backend
    _postViolationEvent(updated, eventType: 'in');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – POST TO BACKEND
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _postViolationEvent(
      GeofenceViolation violation, {
        required String eventType,
      }) async {
    debugPrint('📡 [GeofenceVM] ========== POSTING TO BACKEND ==========');
    debugPrint('📡 [GeofenceVM] Event Type: $eventType');
    debugPrint('📡 [GeofenceVM] Violation ID: ${violation.violation_id}');
    debugPrint('📡 [GeofenceVM] API URL: $_apiUrl');

    try {
      // Format dates for Oracle database
      // Oracle expects: DD-MON-YYYY for dates and HH24:MI:SS for times
      final dateFormat   = DateFormat('dd-MMM-yyyy').format(DateTime.parse(violation.violation_date));
      final outTimeFormatted = violation.outTimeLabel; // Already HH:MM:SS

      // FIX 1 — created_at: Oracle DEFAULT SYSDATE is ignored when ORDS
      // explicitly binds a NULL for the column.  Send the value from Flutter.
      final createdAt = DateFormat('dd-MMM-yyyy HH:mm:ss')
          .format(DateTime.now())
          .toUpperCase(); // "02-APR-2026 18:21:47"

      // FIX 2 — in_time: Never send an empty string to Oracle.
      // Oracle treats '' as NULL, which would override any value.
      // Only include the key when there is an actual time.
      final payload = <String, dynamic>{
        'violation_id'      : violation.violation_id,
        'emp_id'            : violation.emp_id,
        'emp_name'          : violation.emp_name,
        'event_type'        : eventType,
        'violation_date'    : dateFormat,
        'out_time'          : outTimeFormatted,
        // FIX 3 — total_out_duration: use model's human-readable string
        // (e.g. "8m 43s") instead of raw seconds for the 'in' event.
        // For the 'out' event, duration is not yet known — send empty.
        'total_out_duration': eventType == 'in'
            ? violation.total_out_duration
            : '',
        'location_name'     : violation.location_name,
        'created_at'        : createdAt,
      };

      // Only add in_time when the employee has actually returned.
      // Omitting the key entirely avoids Oracle treating '' as NULL.
      if (violation.in_time != null) {
        payload['in_time'] = violation.inTimeLabel; // "HH:MM:SS"
      }

      debugPrint('📡 [GeofenceVM] Payload being sent (Oracle format):');
      debugPrint('📡 [GeofenceVM] ${jsonEncode(payload)}');
      debugPrint('📡 [GeofenceVM]   in_time present: ${payload.containsKey('in_time')}');
      debugPrint('📡 [GeofenceVM]   created_at     : ${payload['created_at']}');

      // Validate payload
      if (payload['emp_id'] == null || payload['emp_id'].toString().isEmpty) {
        debugPrint('❌ [GeofenceVM] CRITICAL: emp_id is null or empty in payload!');
      }
      if (payload['emp_name'] == null || payload['emp_name'].toString().isEmpty) {
        debugPrint('❌ [GeofenceVM] CRITICAL: emp_name is null or empty in payload!');
      }
      if (payload['violation_id'] == null || payload['violation_id'].toString().isEmpty) {
        debugPrint('❌ [GeofenceVM] CRITICAL: violation_id is null or empty in payload!');
      }

      final requestBody = jsonEncode(payload);
      debugPrint('📡 [GeofenceVM] Request body length: ${requestBody.length} bytes');

      final client = http.Client();
      final response = await client
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [GeofenceVM] Response received:');
      debugPrint('📡 [GeofenceVM] Status code: ${response.statusCode}');
      debugPrint('📡 [GeofenceVM] Response body: ${response.body}');
      debugPrint('📡 [GeofenceVM] Response headers: ${response.headers}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [GeofenceVM] SUCCESS! Posted "$eventType" — '
            'violation_id=${violation.violation_id} (${response.statusCode})');
      } else {
        debugPrint('⚠️ [GeofenceVM] SERVER ERROR: Status ${response.statusCode}');
        debugPrint('⚠️ [GeofenceVM] Response: ${response.body}');
      }

      client.close();
    } catch (e, stackTrace) {
      debugPrint('❌ [GeofenceVM] ========== POST FAILED ==========');
      debugPrint('❌ [GeofenceVM] Exception: $e');
      debugPrint('❌ [GeofenceVM] Stack trace: $stackTrace');
      debugPrint('❌ [GeofenceVM] Event type: $eventType');
      debugPrint('❌ [GeofenceVM] Violation ID: ${violation.violation_id}');

      // Check for specific error types
      if (e is http.ClientException) {
        debugPrint('❌ [GeofenceVM] Network error - Check internet connection or server URL');
        debugPrint('❌ [GeofenceVM] Server URL: $_apiUrl');
      } else if (e is SocketException) {
        debugPrint('❌ [GeofenceVM] Socket error - Server unreachable');
        debugPrint('❌ [GeofenceVM] Check if server is running and accessible');
      } else if (e is TimeoutException) {
        debugPrint('❌ [GeofenceVM] Timeout - Server took too long to respond');
      }
    }

    debugPrint('📡 [GeofenceVM] ========== POST ATTEMPT COMPLETE ==========');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – OUTSIDE COUNTER
  // ─────────────────────────────────────────────────────────────────────────

  void _startOutsideCounter() {
    debugPrint('⏱️ [GeofenceVM] Starting outside duration counter');
    _outsideCounterTimer?.cancel();
    _outsideCounterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isOutside.value) {
        _outsideCounterTimer?.cancel();
        outsideSeconds.value = 0;
        return;
      }
      outsideSeconds.value++;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – PERSISTENCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _persistViolations() async {
    try {
      debugPrint('💾 [GeofenceVM] Persisting ${violations.length} violations to SharedPreferences');
      final prefs   = await SharedPreferences.getInstance();
      final encoded = GeofenceViolation.encodeList(violations);
      await prefs.setString(_kViolationsKey, encoded);
      debugPrint('💾 [GeofenceVM] Successfully persisted ${violations.length} violations');
    } catch (e) {
      debugPrint('❌ [GeofenceVM] Persist error: $e');
    }
  }

  Future<void> _restoreViolations() async {
    try {
      debugPrint('🔄 [GeofenceVM] Restoring violations from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kViolationsKey);
      if (raw == null || raw.isEmpty) {
        debugPrint('🔄 [GeofenceVM] No stored violations found');
        return;
      }

      debugPrint('🔄 [GeofenceVM] Raw data length: ${raw.length} characters');
      final list      = GeofenceViolation.decodeList(raw);
      final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayList = list
          .where((v) => v.violation_date == today)
          .toList();

      violations.assignAll(todayList);
      debugPrint('🔄 [GeofenceVM] Restored ${todayList.length} violation(s) for today');

      if (todayList.any((v) => v.in_time == null)) {
        debugPrint('🔄 [GeofenceVM] Found open violation, setting isOutside=true');
        isOutside.value = true;
        _startOutsideCounter();
      }

      debugPrint('🔄 [GeofenceVM] Restored ${todayList.length} violation(s)');
    } catch (e, stackTrace) {
      debugPrint('❌ [GeofenceVM] Restore error: $e');
      debugPrint('❌ [GeofenceVM] Stack trace: $stackTrace');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _safeGet(SharedPreferences prefs, String key) {
    try {
      final v = prefs.get(key);
      final value = v?.toString().trim() ?? '';
      debugPrint('🔍 [GeofenceVM] _safeGet("$key") = "$value"');
      return value;
    } catch (e) {
      debugPrint('⚠️ [GeofenceVM] _safeGet("$key") error: $e');
      return '';
    }
  }

  String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
    debugPrint('🔍 [GeofenceVM] Looking for employee name with fallback keys: $keys');
    for (final k in keys) {
      final v = _safeGet(prefs, k);
      if (v.isNotEmpty) {
        debugPrint('✅ [GeofenceVM] Found emp_name using key "$k": "$v"');
        return v;
      }
    }
    debugPrint('⚠️ [GeofenceVM] No emp_name found in any fallback keys!');
    return '';
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  String get currentOutsideDuration {
    final s = outsideSeconds.value;
    if (s < 60)   return '${s}s';
    if (s < 3600) return '${s ~/ 60}m ${s.remainder(60)}s';
    return '${s ~/ 3600}h ${(s ~/ 60).remainder(60)}m';
  }

  int get totalViolations  => violations.length;
  int get openViolations   => violations.where((v) => v.in_time == null).length;
  int get closedViolations => violations.where((v) => v.in_time != null).length;
}