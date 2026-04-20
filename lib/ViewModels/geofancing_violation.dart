//
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/foundation.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Models/geofancing_violation_model.dart';
//
// class GeofenceViolationViewModel extends GetxController {
//   // ── API URL ───────────────────────────────────────────────────────────────
//   static const String _apiUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/geofencepost/post/';
//
//   // ── SharedPreferences keys ────────────────────────────────────────────────
//   static const String _kViolationsKey = 'geofence_violations_today';
//   static const String _kFailedPostsKey = 'geofence_failed_posts_queue';
//
//   // ── Observables ───────────────────────────────────────────────────────────
//   var violations     = <GeofenceViolation>[].obs;
//   var isOutside      = false.obs;
//   var outsideSeconds = 0.obs;
//   var postStatus     = 'idle'.obs;
//
//   // ── Internal ──────────────────────────────────────────────────────────────
//   Timer? _monitorTimer;
//   Timer? _outsideCounterTimer;
//   Timer? _retryPostTimer;
//   bool   _isMonitoring = false;
//
//   double? _watch_lat;
//   double? _watch_lng;
//   double? _watch_radius;
//   String  _location_name = '';
//   String  _emp_id        = '';
//   String  _emp_name      = '';
//   String  _company_code  = '';          // ← NEW
//
//   static const Duration _checkInterval = Duration(seconds: 10);
//   static const int _maxRetries = 5;
//   static const Duration _retryBaseDelay = Duration(seconds: 3);
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // LIFECYCLE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   @override
//   void onInit() {
//     super.onInit();
//     debugPrint('🔧 [GeofenceVM] ========== VIEW MODEL INITIALIZED ==========');
//     _restoreViolations();
//     _startRetryProcess();
//   }
//
//   @override
//   void onClose() {
//     debugPrint('🔧 [GeofenceVM] View Model closing, cleaning up timers');
//     _monitorTimer?.cancel();
//     _outsideCounterTimer?.cancel();
//     _retryPostTimer?.cancel();
//     super.onClose();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – START MONITORING
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> startMonitoring({
//     required double lat,
//     required double lng,
//     required double radiusMeters,
//     required String locationName,
//   }) async {
//     debugPrint('🚀 [GeofenceVM] ========== START MONITORING CALLED ==========');
//     debugPrint('🚀 [GeofenceVM] Parameters:');
//     debugPrint('🚀 [GeofenceVM]   - lat: $lat');
//     debugPrint('🚀 [GeofenceVM]   - lng: $lng');
//     debugPrint('🚀 [GeofenceVM]   - radiusMeters: $radiusMeters');
//     debugPrint('🚀 [GeofenceVM]   - locationName: "$locationName"');
//
//     if (lat == 0.0 && lng == 0.0) {
//       debugPrint('❌ [GeofenceVM] ABORTED — lat/lng are 0.0');
//       return;
//     }
//
//     _watch_lat     = lat;
//     _watch_lng     = lng;
//     _watch_radius  = radiusMeters;
//     _location_name = locationName;
//     _isMonitoring  = true;
//
//     final prefs = await SharedPreferences.getInstance();
//     debugPrint('🔧 [GeofenceVM] SharedPreferences instance obtained');
//
//     _emp_id   = _safeGet(prefs, 'emp_id');
//     _emp_name = _safeGetFallback(prefs, [
//       'emp_name', 'empName', 'employee_name', 'name', 'userName',
//     ]);
//     _company_code = _safeGetFallback(prefs, [       // ← NEW
//       'company_code', 'companyCode', 'company',     // ← NEW
//     ]);                                              // ← NEW
//
//     debugPrint('👤 [GeofenceVM] Employee Info:');
//     debugPrint('👤 [GeofenceVM]   - emp_id: "$_emp_id"');
//     debugPrint('👤 [GeofenceVM]   - emp_name: "$_emp_name"');
//     debugPrint('👤 [GeofenceVM]   - company_code: "$_company_code"');  // ← NEW
//
//     if (_emp_id.isEmpty) {
//       debugPrint('⚠️ [GeofenceVM] WARNING: emp_id is EMPTY!');
//     }
//     if (_emp_name.isEmpty) {
//       debugPrint('⚠️ [GeofenceVM] WARNING: emp_name is EMPTY!');
//     }
//
//     // Clear old day violations
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     debugPrint('📅 [GeofenceVM] Today\'s date: $today');
//
//     if (violations.isNotEmpty && violations.first.violation_date != today) {
//       debugPrint('🧹 [GeofenceVM] Clearing old violations (date mismatch)');
//       violations.clear();
//       await _persistViolations();
//     }
//
//     isOutside.value      = false;
//     outsideSeconds.value = 0;
//
//     _monitorTimer?.cancel();
//     _monitorTimer = Timer.periodic(_checkInterval, (_) {
//       if (_isMonitoring) _checkGeofence();
//     });
//
//     debugPrint('✅ [GeofenceVM] ══════════════════════════════════');
//     debugPrint('✅ [GeofenceVM] Monitoring STARTED');
//     debugPrint('✅ [GeofenceVM] location_name : "$locationName"');
//     debugPrint('✅ [GeofenceVM] Coords        : ($lat, $lng)');
//     debugPrint('✅ [GeofenceVM] Radius        : ${radiusMeters.toStringAsFixed(1)} m');
//     debugPrint('✅ [GeofenceVM] emp_id        : $_emp_id | emp_name: $_emp_name');
//     debugPrint('✅ [GeofenceVM] Interval      : ${_checkInterval.inSeconds}s');
//     debugPrint('✅ [GeofenceVM] API URL       : $_apiUrl');
//     debugPrint('✅ [GeofenceVM] ══════════════════════════════════');
//
//     // First check after 2s GPS warm-up
//     Future.delayed(const Duration(seconds: 2), () {
//       if (_isMonitoring) _checkGeofence();
//     });
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – STOP MONITORING
//   // ─────────────────────────────���───────────────────────────────────────────
//
//   Future<void> stopMonitoring() async {
//     debugPrint('🛑 [GeofenceVM] ========== STOP MONITORING CALLED ==========');
//     _isMonitoring = false;
//     _monitorTimer?.cancel();
//     _monitorTimer = null;
//     _outsideCounterTimer?.cancel();
//     _outsideCounterTimer = null;
//
//     if (isOutside.value) {
//       debugPrint('🛑 [GeofenceVM] User was outside, closing violation');
//       _closeCurrentViolation(DateTime.now());
//     }
//
//     isOutside.value      = false;
//     outsideSeconds.value = 0;
//
//     debugPrint('🛑 [GeofenceVM] Monitoring STOPPED');
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUBLIC – CLEAR
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> clearViolations() async {
//     debugPrint('🧹 [GeofenceVM] Clearing all violations');
//     violations.clear();
//     isOutside.value      = false;
//     outsideSeconds.value = 0;
//     await _persistViolations();
//     debugPrint('🧹 [GeofenceVM] Violations cleared');
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – GEOFENCE CHECK
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _checkGeofence() async {
//     if (_watch_lat == null || _watch_lng == null || _watch_radius == null) {
//       return;
//     }
//
//     try {
//       debugPrint('📍 [GeofenceVM] Geofence check...');
//       Position? pos;
//       try {
//         pos = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//           timeLimit: const Duration(seconds: 8),
//         );
//       } catch (e) {
//         debugPrint('⚠️ [GeofenceVM] getCurrentPosition failed: $e');
//         pos = await Geolocator.getLastKnownPosition();
//       }
//
//       if (pos == null) {
//         debugPrint('⚠️ [GeofenceVM] No position available');
//         return;
//       }
//
//       final distance_meters = Geolocator.distanceBetween(
//         pos.latitude, pos.longitude,
//         _watch_lat!,  _watch_lng!,
//       );
//
//       final within_radius = distance_meters <= _watch_radius!;
//
//       debugPrint('📏 [GeofenceVM] Distance: ${distance_meters.toStringAsFixed(1)}m | Radius: ${_watch_radius!.toStringAsFixed(1)}m | Within: $within_radius');
//
//       if (!within_radius && !isOutside.value) {
//         debugPrint('🚨 [GeofenceVM] TRIGGER: User EXITED geofence!');
//         _onUserExited(DateTime.now(), distance_meters);
//       } else if (within_radius && isOutside.value) {
//         debugPrint('✅ [GeofenceVM] TRIGGER: User RETURNED to geofence!');
//         _onUserReturned(DateTime.now());
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ [GeofenceVM] GPS check failed: $e');
//       debugPrint('❌ [GeofenceVM] Stack trace: $stackTrace');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – EXIT
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _onUserExited(DateTime out_time, double distance_meters) async {
//     debugPrint('🚨 [GeofenceVM] ========== USER EXITED ==========');
//
//     isOutside.value      = true;
//     outsideSeconds.value = 0;
//
//     final today        = DateFormat('yyyy-MM-dd').format(out_time);
//     // final violation_id = 'VIO-${_emp_id.padLeft(3, '0')}-${out_time.millisecondsSinceEpoch}';
//
//     final empPart      = _emp_id.padLeft(2, '0');
//     final day          = DateFormat('dd').format(out_time);
//     final month        = DateFormat('MMM').format(out_time);
//     final serial       = (out_time.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
//     final violation_id = _company_code.isNotEmpty
//         ? '$_company_code-VID-EMP-$empPart-$day-$month-$serial'
//         : 'VID-EMP-$empPart-$day-$month-$serial';
//
//     debugPrint('🆔 [GeofenceVM] Generated violation_id: $violation_id (company: $_company_code)');
//
//     final violation = GeofenceViolation(
//       violation_id   : violation_id,
//       emp_id         : _emp_id,
//       emp_name       : _emp_name,
//       event_type     : 'out',
//       location_name  : _location_name,
//       violation_date : today,
//       out_time       : out_time,
//       in_time        : null,
//       company_code   : _company_code,   // ← NEW
//     );
//
//     violations.add(violation);
//     await _persistViolations();
//     _startOutsideCounter();
//
//     debugPrint('🚨 [GeofenceVM] Created violation: ${violation.violation_id}');
//
//     // POST "out" row to backend
//     unawaited(_postWithRetry(violation, eventType: 'out', retryCount: 0));
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – RETURN
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _onUserReturned(DateTime in_time) {
//     debugPrint('✅ [GeofenceVM] ========== USER RETURNED ==========');
//
//     isOutside.value = false;
//     _outsideCounterTimer?.cancel();
//     _closeCurrentViolation(in_time);
//   }
//
//   void _closeCurrentViolation(DateTime in_time) {
//     debugPrint('🔒 [GeofenceVM] Closing current violation');
//
//     final idx = violations.lastIndexWhere((v) => v.in_time == null);
//     if (idx < 0) {
//       debugPrint('⚠️ [GeofenceVM] No open violation found to close!');
//       return;
//     }
//
//     final updated = violations[idx].copyWith(
//       in_time    : in_time,
//       event_type : 'in',
//     );
//     violations[idx] = updated;
//     violations.refresh();
//
//     debugPrint('🔒 [GeofenceVM] Updated violation with in_time: ${updated.inTimeLabel}');
//
//     _persistViolations();
//
//     // POST "in" row to backend
//     unawaited(_postWithRetry(updated, eventType: 'in', retryCount: 0));
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – POST WITH AUTOMATIC RETRY
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _postWithRetry(
//       GeofenceViolation violation, {
//         required String eventType,
//         required int retryCount,
//       }) async {
//     debugPrint('📡 [GeofenceVM] POST attempt ${retryCount + 1}/$_maxRetries for event: $eventType');
//
//     try {
//       postStatus.value = 'posting';
//       await _postViolationEvent(violation, eventType: eventType);
//       postStatus.value = 'success';
//       debugPrint('✅ [GeofenceVM] POST SUCCESS on attempt ${retryCount + 1}');
//     } catch (e) {
//       debugPrint('❌ [GeofenceVM] POST FAILED (attempt ${retryCount + 1}): $e');
//
//       if (retryCount < _maxRetries) {
//         final delaySeconds = _retryBaseDelay.inSeconds * (1 << retryCount);
//         final delay = Duration(seconds: delaySeconds);
//
//         debugPrint('⏰ [GeofenceVM] Retrying in ${delay.inSeconds}s...');
//
//         await _queueFailedPost(violation, eventType, retryCount + 1);
//
//         Future.delayed(delay, () {
//           if (_isMonitoring) {
//             _postWithRetry(violation, eventType: eventType, retryCount: retryCount + 1);
//           }
//         });
//       } else {
//         debugPrint('❌ [GeofenceVM] MAX RETRIES REACHED.');
//         postStatus.value = 'error';
//         await _queueFailedPost(violation, eventType, -1);
//       }
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – POST TO BACKEND (CORE) ✅ FIXED FOR ORACLE TABLE SCHEMA
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _postViolationEvent(
//       GeofenceViolation violation, {
//         required String eventType,
//       }) async {
//     debugPrint('📡 [GeofenceVM] ========== POSTING TO BACKEND ==========');
//     debugPrint('📡 [GeofenceVM] Event Type: $eventType');
//     debugPrint('📡 [GeofenceVM] Violation ID: ${violation.violation_id}');
//     debugPrint('📡 [GeofenceVM] emp_id: ${violation.emp_id} | emp_name: ${violation.emp_name}');
//
//     // Validate
//     if (violation.emp_id.isEmpty) {
//       throw Exception('❌ emp_id is empty');
//     }
//     if (violation.emp_name.isEmpty) {
//       throw Exception('❌ emp_name is empty');
//     }
//
//     // ✅ FIXED: Format dates according to Oracle table schema
//     // Table expects:
//     // - VIOLATION_DATE: DATE (Oracle DATE type) → send as DD-MMM-YYYY
//     // - OUT_TIME: VARCHAR2(10) → send as HH:MM:SS
//     // - IN_TIME: VARCHAR2(10) → send as HH:MM:SS
//     // - CREATED_AT: DATE with DEFAULT SYSDATE → DON'T SEND (let Oracle use SYSDATE)
//
//     final violationDate = DateFormat('dd-MMM-yyyy')
//         .format(DateTime.parse(violation.violation_date));
//     final outTime = violation.outTimeLabel; // Already HH:MM:SS
//     final inTime = violation.in_time != null ? violation.inTimeLabel : null;
//
//     debugPrint('📡 [DEBUG] Formatted dates:');
//     debugPrint('📡 [DEBUG]   violation_date: "$violationDate" (DD-MMM-YYYY)');
//     debugPrint('📡 [DEBUG]   out_time: "$outTime" (HH:MM:SS)');
//     if (inTime != null) {
//       debugPrint('📡 [DEBUG]   in_time: "$inTime" (HH:MM:SS)');
//     }
//
//     // Build payload - EXACTLY matching Oracle table columns
//     final payload = <String, dynamic>{
//       'violation_id'       : violation.violation_id,
//       'emp_id'             : violation.emp_id,
//       'emp_name'           : violation.emp_name,
//       'event_type'         : eventType,
//       'violation_date'     : violationDate,              // DD-MMM-YYYY
//       'out_time'           : outTime,                    // HH:MM:SS
//       'total_out_duration' : eventType == 'in' ? violation.total_out_duration : '',
//       'location_name'      : violation.location_name,
//       'company_code'       : violation.company_code,     // ← NEW
//       // ✅ IMPORTANT: Don't send created_at - let Oracle use DEFAULT SYSDATE
//     };
//
//     // Only add in_time if it exists
//     if (inTime != null) {
//       payload['in_time'] = inTime; // HH:MM:SS
//     }
//
//     debugPrint('📡 [GeofenceVM] Final Payload:');
//     final requestBody = jsonEncode(payload);
//     debugPrint('📡 [GeofenceVM] $requestBody');
//
//     // Send HTTP POST
//     final client = http.Client();
//     try {
//       debugPrint('📡 [GeofenceVM] Sending to: $_apiUrl');
//
//       final response = await client
//           .post(
//         Uri.parse(_apiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: requestBody,
//       )
//           .timeout(const Duration(seconds: 20));
//
//       debugPrint('📡 [GeofenceVM] Response Status: ${response.statusCode}');
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         debugPrint('✅ [GeofenceVM] ✅ SUCCESS: $eventType event posted');
//         debugPrint('📡 [GeofenceVM] Response: ${response.body}');
//         return;
//       } else {
//         debugPrint('📡 [GeofenceVM] Response Body: ${response.body}');
//
//         // Try to parse Oracle error
//         try {
//           final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
//           final cause = errorJson['cause'] ?? errorJson['message'] ?? 'Unknown error';
//           debugPrint('❌ [GeofenceVM] Oracle Error: $cause');
//           throw HttpException('Oracle Error: $cause');
//         } catch (e) {
//           throw HttpException('Server returned ${response.statusCode}');
//         }
//       }
//     } on TimeoutException {
//       throw TimeoutException('POST request timed out (20s)');
//     } on SocketException catch (e) {
//       throw SocketException('Socket error: $e');
//     } catch (e) {
//       rethrow;
//     } finally {
//       client.close();
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – FAILED POST QUEUE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _queueFailedPost(
//       GeofenceViolation violation,
//       String eventType,
//       int retryCount,
//       ) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final queueStr = prefs.getString(_kFailedPostsKey) ?? '[]';
//       final queue = List<Map<String, dynamic>>.from(
//         (jsonDecode(queueStr) as List).map((e) => e as Map<String, dynamic>),
//       );
//
//       queue.add({
//         'violation': violation.toStorageJson(),
//         'eventType': eventType,
//         'retryCount': retryCount,
//         'timestamp': DateTime.now().toIso8601String(),
//       });
//
//       await prefs.setString(_kFailedPostsKey, jsonEncode(queue));
//       debugPrint('💾 [GeofenceVM] Queued failed post. Queue size: ${queue.length}');
//     } catch (e) {
//       debugPrint('❌ [GeofenceVM] Queue error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – RETRY QUEUED POSTS (PERIODIC)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _startRetryProcess() {
//     _retryPostTimer?.cancel();
//     _retryPostTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
//       await _processFailedPostQueue();
//     });
//     debugPrint('⏱️ [GeofenceVM] Retry process started (every 1 minute)');
//
//     Future.delayed(const Duration(seconds: 2), () {
//       _processFailedPostQueue();
//     });
//   }
//
//   Future<void> _processFailedPostQueue() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final queueStr = prefs.getString(_kFailedPostsKey) ?? '[]';
//
//       if (queueStr == '[]') return;
//
//       final queue = List<Map<String, dynamic>>.from(
//         (jsonDecode(queueStr) as List).map((e) => e as Map<String, dynamic>),
//       );
//
//       if (queue.isEmpty) return;
//
//       debugPrint('🔄 [GeofenceVM] Processing ${queue.length} queued posts...');
//
//       final newQueue = <Map<String, dynamic>>[];
//
//       for (final item in queue) {
//         try {
//           final violation = GeofenceViolation.fromStorageJson(
//             item['violation'] as Map<String, dynamic>,
//           );
//           final eventType = item['eventType'] as String;
//
//           await _postViolationEvent(violation, eventType: eventType);
//           debugPrint('✅ [GeofenceVM] Retried post successful: ${violation.violation_id}');
//         } catch (e) {
//           debugPrint('⚠️ [GeofenceVM] Retry still failed: $e');
//           newQueue.add(item);
//         }
//       }
//
//       await prefs.setString(_kFailedPostsKey, jsonEncode(newQueue));
//       debugPrint('📊 [GeofenceVM] Queue processed. Remaining: ${newQueue.length}');
//     } catch (e) {
//       debugPrint('❌ [GeofenceVM] Queue process error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – OUTSIDE COUNTER
//   // ─────────────────────────────────────────────────────────────────────────
//
//   void _startOutsideCounter() {
//     _outsideCounterTimer?.cancel();
//     _outsideCounterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (!isOutside.value) {
//         _outsideCounterTimer?.cancel();
//         outsideSeconds.value = 0;
//         return;
//       }
//       outsideSeconds.value++;
//     });
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PRIVATE – PERSISTENCE
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<void> _persistViolations() async {
//     try {
//       final prefs   = await SharedPreferences.getInstance();
//       final encoded = GeofenceViolation.encodeList(violations);
//       await prefs.setString(_kViolationsKey, encoded);
//       debugPrint('💾 [GeofenceVM] Persisted ${violations.length} violations');
//     } catch (e) {
//       debugPrint('❌ [GeofenceVM] Persist error: $e');
//     }
//   }
//
//   Future<void> _restoreViolations() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final raw   = prefs.getString(_kViolationsKey);
//       if (raw == null || raw.isEmpty) return;
//
//       final list      = GeofenceViolation.decodeList(raw);
//       final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final todayList = list.where((v) => v.violation_date == today).toList();
//
//       violations.assignAll(todayList);
//       debugPrint('🔄 [GeofenceVM] Restored ${todayList.length} violations');
//
//       if (todayList.any((v) => v.in_time == null)) {
//         isOutside.value = true;
//         _startOutsideCounter();
//       }
//     } catch (e) {
//       debugPrint('❌ [GeofenceVM] Restore error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // HELPERS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   String _safeGet(SharedPreferences prefs, String key) {
//     try {
//       final v = prefs.get(key);
//       return v?.toString().trim() ?? '';
//     } catch (e) {
//       return '';
//     }
//   }
//
//   String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
//     for (final k in keys) {
//       final v = _safeGet(prefs, k);
//       if (v.isNotEmpty) return v;
//     }
//     return '';
//   }
//
//   String get currentOutsideDuration {
//     final s = outsideSeconds.value;
//     if (s < 60)   return '${s}s';
//     if (s < 3600) return '${s ~/ 60}m ${s.remainder(60)}s';
//     return '${s ~/ 3600}h ${(s ~/ 60).remainder(60)}m';
//   }
//
//   int get totalViolations  => violations.length;
//   int get openViolations   => violations.where((v) => v.in_time == null).length;
//   int get closedViolations => violations.where((v) => v.in_time != null).length;
// }

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
import '../Services/remote_config_service.dart';

class GeofenceViolationViewModel extends GetxController {
  // ── API URL ───────────────────────────────────────────────────────────────
  // static const String _apiUrl =
  //     'http://oracle.metaxperts.net/ords/gps_workforce/geofencepost/post/';

  ///firebase
  // WITH:
  static String get _apiUrl => RemoteConfigService.getGeofencePostUrl();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _kViolationsKey  = 'geofence_violations_today';
  static const String _kFailedPostsKey = 'geofence_failed_posts_queue';

  // ── Observables ───────────────────────────────────────────────────────────
  var violations     = <GeofenceViolation>[].obs;
  var isOutside      = false.obs;
  var outsideSeconds = 0.obs;
  var postStatus     = 'idle'.obs;

  // ── Internal ──────────────────────────────────────────────────────────────
  Timer? _monitorTimer;
  Timer? _outsideCounterTimer;
  Timer? _retryPostTimer;
  bool   _isMonitoring = false;

  double? _watch_lat;
  double? _watch_lng;
  double? _watch_radius;
  String  _location_name = '';
  String  _emp_id        = '';
  String  _emp_name      = '';
  String  _company_code  = '';

  static const Duration _checkInterval = Duration(seconds: 10);

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔧 [GeofenceVM] ========== VIEW MODEL INITIALIZED ==========');
    _restoreViolations();
    _startRetryProcess();
  }

  @override
  void onClose() {
    debugPrint('🔧 [GeofenceVM] View Model closing, cleaning up timers');
    _monitorTimer?.cancel();
    _outsideCounterTimer?.cancel();
    _retryPostTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – START MONITORING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> startMonitoring({
    required double lat,
    required double lng,
    required double radiusMeters,
    required String locationName,
  }) async {
    debugPrint('🚀 [GeofenceVM] ========== START MONITORING CALLED ==========');
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

    _emp_id = _safeGet(prefs, 'emp_id');
    _emp_name = _safeGetFallback(prefs, [
      'emp_name', 'empName', 'employee_name', 'name', 'userName',
    ]);
    _company_code = _safeGetFallback(prefs, [
      'company_code', 'companyCode', 'company',
    ]);

    debugPrint('👤 [GeofenceVM]   - emp_id: "$_emp_id"');
    debugPrint('👤 [GeofenceVM]   - emp_name: "$_emp_name"');
    debugPrint('👤 [GeofenceVM]   - company_code: "$_company_code"');

    if (_emp_id.isEmpty)   debugPrint('⚠️ [GeofenceVM] WARNING: emp_id is EMPTY!');
    if (_emp_name.isEmpty) debugPrint('⚠️ [GeofenceVM] WARNING: emp_name is EMPTY!');

    // Clear old day violations
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

    debugPrint('✅ [GeofenceVM] Monitoring STARTED | location: "$locationName" | '
        'coords: ($lat, $lng) | radius: ${radiusMeters.toStringAsFixed(1)}m | '
        'emp: $_emp_id / $_emp_name');

    // First check after 2s GPS warm-up
    Future.delayed(const Duration(seconds: 2), () {
      if (_isMonitoring) _checkGeofence();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – STOP MONITORING
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
    if (_watch_lat == null || _watch_lng == null || _watch_radius == null) return;

    try {
      debugPrint('📍 [GeofenceVM] Geofence check...');
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        debugPrint('⚠️ [GeofenceVM] getCurrentPosition failed: $e');
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        debugPrint('⚠️ [GeofenceVM] No position available');
        return;
      }

      final distance_meters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _watch_lat!,  _watch_lng!,
      );

      final within_radius = distance_meters <= _watch_radius!;

      debugPrint('📏 [GeofenceVM] Distance: ${distance_meters.toStringAsFixed(1)}m '
          '| Radius: ${_watch_radius!.toStringAsFixed(1)}m | Within: $within_radius');

      if (!within_radius && !isOutside.value) {
        debugPrint('🚨 [GeofenceVM] TRIGGER: User EXITED geofence!');
        _onUserExited(DateTime.now(), distance_meters);
      } else if (within_radius && isOutside.value) {
        debugPrint('✅ [GeofenceVM] TRIGGER: User RETURNED to geofence!');
        _onUserReturned(DateTime.now());
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

    isOutside.value      = true;
    outsideSeconds.value = 0;

    final today    = DateFormat('yyyy-MM-dd').format(out_time);
    final empPart  = _emp_id.padLeft(2, '0');
    final day      = DateFormat('dd').format(out_time);
    final month    = DateFormat('MMM').format(out_time);
    final serial   = (out_time.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');

    final violation_id = _company_code.isNotEmpty
        ? '$_company_code-VID-EMP-$empPart-$day-$month-$serial'
        : 'VID-EMP-$empPart-$day-$month-$serial';

    debugPrint('🆔 [GeofenceVM] Generated violation_id: $violation_id');

    final violation = GeofenceViolation(
      violation_id   : violation_id,
      emp_id         : _emp_id,
      emp_name       : _emp_name,
      event_type     : 'out',
      location_name  : _location_name,
      violation_date : today,
      out_time       : out_time,
      in_time        : null,
      company_code   : _company_code,
    );

    violations.add(violation);
    await _persistViolations();
    _startOutsideCounter();

    debugPrint('🚨 [GeofenceVM] Created violation: ${violation.violation_id}');

    // POST "out" row to backend
    unawaited(_postWithRetry(violation, eventType: 'out'));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – RETURN
  // ─────────────────────────────────────────────────────────────────────────

  void _onUserReturned(DateTime in_time) {
    debugPrint('✅ [GeofenceVM] ========== USER RETURNED ==========');
    isOutside.value = false;
    _outsideCounterTimer?.cancel();
    _closeCurrentViolation(in_time);
  }

  void _closeCurrentViolation(DateTime in_time) {
    debugPrint('🔒 [GeofenceVM] Closing current violation');

    final idx = violations.lastIndexWhere((v) => v.in_time == null);
    if (idx < 0) {
      debugPrint('⚠️ [GeofenceVM] No open violation found to close!');
      return;
    }

    final updated = violations[idx].copyWith(
      in_time    : in_time,
      event_type : 'in',
    );
    violations[idx] = updated;
    violations.refresh();

    debugPrint('🔒 [GeofenceVM] Updated violation with in_time: ${updated.inTimeLabel}');

    _persistViolations();

    // POST "in" row to backend
    unawaited(_postWithRetry(updated, eventType: 'in'));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – POST WITH RETRY
  //
  // FIX: Previously this method BOTH queued to SharedPrefs AND recursively
  // called itself via Future.delayed — causing the same post to be sent
  // 7-8 times when internet returned (in-memory chain + periodic queue
  // processor firing simultaneously).
  //
  // Now: one single attempt. On failure → queue ONCE to SharedPrefs.
  // The periodic _processFailedPostQueue() timer handles all retries.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _postWithRetry(
      GeofenceViolation violation, {
        required String eventType,
      }) async {
    debugPrint('📡 [GeofenceVM] Attempting POST for event: $eventType | id: ${violation.violation_id}');

    try {
      postStatus.value = 'posting';
      await _postViolationEvent(violation, eventType: eventType);
      postStatus.value = 'success';
      debugPrint('✅ [GeofenceVM] POST SUCCESS for: ${violation.violation_id}');
    } catch (e) {
      debugPrint('❌ [GeofenceVM] POST FAILED: $e');
      postStatus.value = 'error';

      // ✅ FIX: Queue ONCE only. Do NOT also start a Future.delayed retry loop.
      //    The _retryPostTimer (every 1 min) will pick this up and retry cleanly.
      await _queueFailedPost(violation, eventType);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – POST TO BACKEND (CORE)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _postViolationEvent(
      GeofenceViolation violation, {
        required String eventType,
      }) async {
    debugPrint('📡 [GeofenceVM] ========== POSTING TO BACKEND ==========');
    debugPrint('📡 [GeofenceVM] Event Type   : $eventType');
    debugPrint('📡 [GeofenceVM] Violation ID : ${violation.violation_id}');
    debugPrint('📡 [GeofenceVM] emp_id: ${violation.emp_id} | emp_name: ${violation.emp_name}');

    if (violation.emp_id.isEmpty)   throw Exception('❌ emp_id is empty');
    if (violation.emp_name.isEmpty) throw Exception('❌ emp_name is empty');

    final violationDate = DateFormat('dd-MMM-yyyy')
        .format(DateTime.parse(violation.violation_date));
    final outTime = violation.outTimeLabel;
    final inTime  = violation.in_time != null ? violation.inTimeLabel : null;

    debugPrint('📡 [DEBUG] violation_date: "$violationDate" | out_time: "$outTime"'
        '${inTime != null ? ' | in_time: "$inTime"' : ''}');

    final payload = <String, dynamic>{
      'violation_id'       : violation.violation_id,
      'emp_id'             : violation.emp_id,
      'emp_name'           : violation.emp_name,
      'event_type'         : eventType,
      'violation_date'     : violationDate,
      'out_time'           : outTime,
      'total_out_duration' : eventType == 'in' ? violation.total_out_duration : '',
      'location_name'      : violation.location_name,
      'company_code'       : violation.company_code,
    };

    if (inTime != null) payload['in_time'] = inTime;

    final requestBody = jsonEncode(payload);
    debugPrint('📡 [GeofenceVM] Payload: $requestBody');

    final client = http.Client();
    try {
      final response = await client
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: requestBody,
      )
          .timeout(const Duration(seconds: 20));

      debugPrint('📡 [GeofenceVM] Response Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [GeofenceVM] SUCCESS: $eventType posted');
        debugPrint('📡 [GeofenceVM] Response: ${response.body}');
        return;
      }

      // Non-2xx — try to extract Oracle error message
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        final cause     = errorJson['cause'] ?? errorJson['message'] ?? 'Unknown error';
        debugPrint('❌ [GeofenceVM] Oracle Error: $cause');
        throw HttpException('Oracle Error: $cause');
      } catch (_) {
        throw HttpException('Server returned ${response.statusCode}');
      }
    } on TimeoutException {
      throw TimeoutException('POST request timed out (20s)');
    } on SocketException catch (e) {
      throw SocketException('Socket error: $e');
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – FAILED POST QUEUE
  //
  // FIX: Added deduplication check. If the same violation_id + eventType is
  // already in the queue, we skip adding it again. This is a safety net
  // against any future code path accidentally calling this twice.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _queueFailedPost(
      GeofenceViolation violation,
      String eventType,
      ) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_kFailedPostsKey) ?? '[]';
      final queue    = List<Map<String, dynamic>>.from(
        (jsonDecode(queueStr) as List).map((e) => e as Map<String, dynamic>),
      );

      // ✅ FIX: Dedup — never queue the same violation_id + eventType twice
      final alreadyQueued = queue.any((item) =>
      item['violation']?['violation_id'] == violation.violation_id &&
          item['eventType'] == eventType);

      if (alreadyQueued) {
        debugPrint('⚠️ [GeofenceVM] Already queued: ${violation.violation_id} / $eventType — skipping duplicate');
        return;
      }

      queue.add({
        'violation' : violation.toStorageJson(),
        'eventType' : eventType,
        'timestamp' : DateTime.now().toIso8601String(),
      });

      await prefs.setString(_kFailedPostsKey, jsonEncode(queue));
      debugPrint('💾 [GeofenceVM] Queued failed post. Queue size: ${queue.length}');
    } catch (e) {
      debugPrint('❌ [GeofenceVM] Queue error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – RETRY QUEUED POSTS (PERIODIC — every 1 minute)
  //
  // This is now the SINGLE source of retries. When internet returns, this
  // timer fires, processes every queued item once, and removes successful
  // ones. No duplicate in-memory retry chains anywhere.
  // ─────────────────────────────────────────────────────────────────────────

  void _startRetryProcess() {
    _retryPostTimer?.cancel();
    _retryPostTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _processFailedPostQueue();
    });
    debugPrint('⏱️ [GeofenceVM] Retry process started (every 1 minute)');

    // Also try immediately on startup (catches queued items from previous session)
    Future.delayed(const Duration(seconds: 2), _processFailedPostQueue);
  }

  Future<void> _processFailedPostQueue() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final queueStr = prefs.getString(_kFailedPostsKey) ?? '[]';

      if (queueStr == '[]') return;

      final queue = List<Map<String, dynamic>>.from(
        (jsonDecode(queueStr) as List).map((e) => e as Map<String, dynamic>),
      );

      if (queue.isEmpty) return;

      debugPrint('🔄 [GeofenceVM] Processing ${queue.length} queued posts...');

      final newQueue = <Map<String, dynamic>>[];

      for (final item in queue) {
        try {
          final violation = GeofenceViolation.fromStorageJson(
            item['violation'] as Map<String, dynamic>,
          );
          final eventType = item['eventType'] as String;

          await _postViolationEvent(violation, eventType: eventType);
          debugPrint('✅ [GeofenceVM] Retry succeeded: ${violation.violation_id}');
          // Successfully posted → do NOT add back to newQueue (it is removed)
        } catch (e) {
          debugPrint('⚠️ [GeofenceVM] Retry still failed: $e — keeping in queue');
          newQueue.add(item); // Keep for next retry cycle
        }
      }

      await prefs.setString(_kFailedPostsKey, jsonEncode(newQueue));
      debugPrint('📊 [GeofenceVM] Queue processed. Remaining: ${newQueue.length}');
    } catch (e) {
      debugPrint('❌ [GeofenceVM] Queue process error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – OUTSIDE COUNTER
  // ─────────────────────────────────────────────────────────────────────────

  void _startOutsideCounter() {
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
      final prefs   = await SharedPreferences.getInstance();
      final encoded = GeofenceViolation.encodeList(violations);
      await prefs.setString(_kViolationsKey, encoded);
      debugPrint('💾 [GeofenceVM] Persisted ${violations.length} violations');
    } catch (e) {
      debugPrint('❌ [GeofenceVM] Persist error: $e');
    }
  }

  Future<void> _restoreViolations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kViolationsKey);
      if (raw == null || raw.isEmpty) return;

      final list      = GeofenceViolation.decodeList(raw);
      final today     = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayList = list.where((v) => v.violation_date == today).toList();

      violations.assignAll(todayList);
      debugPrint('🔄 [GeofenceVM] Restored ${todayList.length} violations');

      if (todayList.any((v) => v.in_time == null)) {
        isOutside.value = true;
        _startOutsideCounter();
      }
    } catch (e) {
      debugPrint('❌ [GeofenceVM] Restore error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _safeGet(SharedPreferences prefs, String key) {
    try {
      final v = prefs.get(key);
      return v?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
    for (final k in keys) {
      final v = _safeGet(prefs, k);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

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