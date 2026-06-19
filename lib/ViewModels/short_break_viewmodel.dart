// // lib/ViewModels/short_break_viewmodel.dart
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
//
// import '../Models/short_break_model.dart';
// import '../Repositories/short_break_repository.dart';
//
// class ShortBreakViewModel extends GetxController {
//   // ── Repository ─────────────────────────────────────────────────────────────
//   final _repo = ShortBreakRepository();
//
//   // ── Observable state ───────────────────────────────────────────────────────
//   final RxList<ShortBreakModel> breakPolicies    = <ShortBreakModel>[].obs;
//   final RxBool   isLoading                       = false.obs;
//   final RxBool   isOnShortBreak                  = false.obs;
//   final RxBool   isEndingBreak                   = false.obs;
//
//   /// Countdown remaining (formatted "MM:SS")
//   final RxString timerDisplay                    = ''.obs;
//   /// Elapsed since break started (formatted "MM:SS")
//   final RxString elapsedDisplay                  = ''.obs;
//
//   final RxString activeBreakType                 = ''.obs;
//   final RxString statusMessage                   = ''.obs;
//
//   // ── Internal break session data ────────────────────────────────────────────
//   ShortBreakModel? _activeBreak;
//   DateTime?        _breakStartTime;
//   String?          _startTimestamp;
//   double?          _startLat;
//   double?          _startLng;
//
//   Timer?   _countdownTimer;
//   Timer?   _geofenceTimer;
//   int      _remainingSeconds = 0;
//   int      _elapsedSeconds   = 0;
//
//   // ── Cached user info ───────────────────────────────────────────────────────
//   String _empId       = '';
//   String _empName     = '';
//   String _companyCode = '';
//   String _depId       = '';
//
//   // ── Geo-fence settings ─────────────────────────────────────────────────────
//   bool   _geofenceEnabled = false;
//   double _fenceLat        = 0;
//   double _fenceLng        = 0;
//   double _fenceRadius     = 100; // metres
//
//   // ── SharedPrefs keys for active session persistence ────────────────────────
//   // These keys survive app kill/background so the timer can resume correctly.
//   static const String _kSessionActive     = 'sb_session_active';
//   static const String _kSessionBreakType  = 'sb_session_break_type';
//   static const String _kSessionStartTs    = 'sb_session_start_ts';
//   static const String _kSessionMaxSeconds = 'sb_session_max_seconds';
//   static const String _kSessionStartLat   = 'sb_session_start_lat';
//   static const String _kSessionStartLng   = 'sb_session_start_lng';
//
//   // ── Lifecycle ──────────────────────────────────────────────────────────────
//   @override
//   void onInit() {
//     super.onInit();
//     _loadUserData();
//   }
//
//   @override
//   void onClose() {
//     _countdownTimer?.cancel();
//     _geofenceTimer?.cancel();
//     super.onClose();
//   }
//
//   // ── Load user data from SharedPreferences ─────────────────────────────────
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     debugPrint('');
//     debugPrint('════════════════════════════════════════════════════════');
//     debugPrint('🔑 [SB-VM] _loadUserData() — reading SharedPreferences');
//
//     final allKeys = prefs.getKeys();
//     debugPrint('🔑 [SB-VM] ALL stored keys: $allKeys');
//     debugPrint('🔑 [SB-VM] ALL key-value dump:');
//     for (final k in allKeys) {
//       debugPrint('   "$k" = "${prefs.get(k)}"');
//     }
//     debugPrint('');
//
//     // ── emp_id: try every possible key ──────────────────────────────────────
//     _empId = _firstNonEmpty(prefs, [
//       'emp_id', 'userId', 'empId', 'user_id',
//       'employee_id', 'employeeId', 'EMP_ID',
//     ]);
//     debugPrint('🔑 [SB-VM] emp_id resolved      = "$_empId"');
//
//     // ── emp_name ─────────────────────────────────────────────────────────────
//     _empName = _firstNonEmpty(prefs, [
//       'emp_name', 'userName', 'empName', 'name',
//       'user_name', 'fullName', 'full_name',
//     ]);
//     debugPrint('🔑 [SB-VM] emp_name resolved     = "$_empName"');
//
//     // ── company_code: try every possible key ─────────────────────────────────
//     _companyCode = _firstNonEmpty(prefs, [
//       'company_code', 'companyCode', 'CompanyCode',
//       'COMPANY_CODE', 'company', 'comp_code',
//     ]);
//     debugPrint('🔑 [SB-VM] company_code resolved = "$_companyCode"');
//
//     // ── dep_id: try every possible key ───────────────────────────────────────
//     _depId = _firstNonEmpty(prefs, [
//       'cached_dep_id', 'dep_id', 'depId', 'DEP_ID',
//       'department_id', 'departmentId', 'dept_id', 'deptId',
//     ]);
//     debugPrint('🔑 [SB-VM] dep_id resolved       = "$_depId"');
//
//     // ── Diagnosis ────────────────────────────────────────────────────────────
//     debugPrint('');
//     if (_depId.isEmpty) {
//       debugPrint('❌ [SB-VM] dep_id  is EMPTY — none of the known keys matched');
//       debugPrint('   → Look at the ALL key-value dump above and find the correct key');
//       debugPrint('   → Add it to the _firstNonEmpty list for dep_id');
//     }
//     if (_companyCode.isEmpty) {
//       debugPrint('❌ [SB-VM] company_code is EMPTY — none of the known keys matched');
//       debugPrint('   → Look at the ALL key-value dump above and find the correct key');
//       debugPrint('   → Add it to the _firstNonEmpty list for company_code');
//     }
//     if (_depId.isNotEmpty && _companyCode.isNotEmpty) {
//       debugPrint('✅ [SB-VM] Both depId and companyCode resolved — will fetch policy');
//     }
//     debugPrint('════════════════════════════════════════════════════════');
//     debugPrint('');
//
//     _loadGeoFenceSettings(prefs);
//
//     // ── Restore active break session if app was killed/backgrounded ──────────
//     await _restoreActiveSession(prefs);
//
//     if (_depId.isNotEmpty && _companyCode.isNotEmpty) {
//       fetchBreakPolicy();
//     } else {
//       // Show a clear message with which field is missing
//       final missing = <String>[];
//       if (_depId.isEmpty)       missing.add('dep_id');
//       if (_companyCode.isEmpty) missing.add('company_code');
//       statusMessage.value =
//       'User data not found (${missing.join(', ')}). Please re-login.';
//       debugPrint('⚠️  [SB-VM] Skipping fetchBreakPolicy — missing: ${missing.join(', ')}');
//     }
//   }
//
//   /// Returns the first non-empty string value found among the given [keys].
//   /// Uses prefs.get() (not getString) to safely handle keys stored as int/bool.
//   String _firstNonEmpty(SharedPreferences prefs, List<String> keys) {
//     for (final key in keys) {
//       final raw = prefs.get(key); // works for String, int, bool, double
//       if (raw == null) continue;
//       final val = raw.toString().trim();
//       if (val.isNotEmpty) {
//         debugPrint('   ✅ key "$key" = "$val" (type: ${raw.runtimeType})');
//         return val;
//       }
//     }
//     return '';
//   }
//
//   void _loadGeoFenceSettings(SharedPreferences prefs) {
//     try {
//       final cached = prefs.getString('cached_locations');
//       if (cached == null || cached.isEmpty) return;
//
//       final items = jsonDecode(cached) as List<dynamic>;
//       if (items.isEmpty) return;
//
//       final loc = items.first as Map<String, dynamic>;
//
//       final lat = double.tryParse(
//         (loc['latitude'] ?? loc['LATITUDE'] ?? loc['lat'] ?? '0').toString(),
//       );
//       final lng = double.tryParse(
//         (loc['longitude'] ?? loc['LONGITUDE'] ?? loc['lng'] ?? '0').toString(),
//       );
//       final radius = double.tryParse(
//         (loc['radius'] ?? loc['RADIUS'] ?? '100').toString(),
//       );
//
//       final geofenceFlag =
//       (loc['geofence_enabled'] ?? loc['GEOFENCE_ENABLED'] ?? '').toString().toLowerCase();
//
//       if (lat != null && lng != null && lat != 0 && lng != 0) {
//         _fenceLat        = lat;
//         _fenceLng        = lng;
//         _fenceRadius     = radius ?? 100;
//         _geofenceEnabled =
//             geofenceFlag == 'yes' || geofenceFlag == 'true' || geofenceFlag == '1';
//         debugPrint('📍 [SB-VM] GeoFence: enabled=$_geofenceEnabled '
//             'lat=$_fenceLat lng=$_fenceLng radius=$_fenceRadius');
//       }
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] Could not load geo-fence settings: $e');
//     }
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // FETCH BREAK POLICY
//   // ═══════════════════════════════════════════════════════════════════════════
//   Future<void> fetchBreakPolicy() async {
//     // If values are still empty, re-read prefs before giving up
//     if (_depId.isEmpty || _companyCode.isEmpty) {
//       debugPrint('⚠️  [SB-VM] fetchBreakPolicy called but fields empty — re-reading prefs');
//       await _loadUserData();
//       return; // _loadUserData will call fetchBreakPolicy again if resolved
//     }
//
//     isLoading.value = true;
//     statusMessage.value = '';
//
//     debugPrint('🟢 [SB-VM] fetchBreakPolicy → depId="$_depId" companyCode="$_companyCode"');
//
//     final policies = await _repo.fetchBreakPolicy(
//       depId: _depId,
//       companyCode: _companyCode,
//     );
//
//     // ── Restore usedCount from previous session (same day) ───────────────────
//     final prefs = await SharedPreferences.getInstance();
//     final today = _today();
//
//     // ── Re-resolve _empId in case it was empty at onInit time ────────────────
//     // endBreak() saves with the resolved empId; we must use the same key here.
//     if (_empId.isEmpty) {
//       _empId = _firstNonEmpty(prefs, [
//         'emp_id', 'userId', 'empId', 'user_id',
//         'employee_id', 'employeeId', 'EMP_ID',
//       ]);
//       debugPrint('🔄 [SB-VM] fetchBreakPolicy: re-resolved empId="$_empId"');
//     }
//
//     debugPrint('🔄 [SB-VM] Restoring usedCounts for empId="$_empId" date="$today"');
//     for (final p in policies) {
//       final key   = 'sb_cnt_${_empId}_${p.breakType}_$today';
//       final saved = prefs.getInt(key) ?? 0;
//       p.usedCount = saved;
//       debugPrint('🔄 [SB-VM]   "${p.breakType}" → key="$key" restored=$saved');
//     }
//
//     breakPolicies.assignAll(policies);
//     isLoading.value = false;
//
//     if (policies.isEmpty) {
//       statusMessage.value = 'No short break policy configured for your department.';
//     }
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // START BREAK
//   // ═══════════════════════════════════════════════════════════════════════════
//   Future<void> startBreak(ShortBreakModel breakModel) async {
//     if (isOnShortBreak.value) {
//       Get.snackbar('Already on Break',
//           'Please end your current break before starting a new one.',
//           snackPosition: SnackPosition.BOTTOM);
//       return;
//     }
//     if (!breakModel.canTakeBreak) {
//       Get.snackbar('Limit Reached',
//           'You have used all ${breakModel.countLimit} ${breakModel.breakType}(s) for today.',
//           snackPosition: SnackPosition.BOTTOM);
//       return;
//     }
//
//     // ── Location validation: user must be inside the assigned work location ──
//     statusMessage.value = 'Verifying your location…';
//     final bool locationOk = await _isInsideAssignedLocation();
//     statusMessage.value = '';
//     if (!locationOk) {
//       Get.snackbar(
//         'Outside Work Location',
//         'You are not in the assigned work location.',
//         snackPosition: SnackPosition.BOTTOM,
//         duration: const Duration(seconds: 5),
//         backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
//         colorText: Colors.white,
//         icon: const Icon(Icons.location_off_rounded, color: Colors.white),
//       );
//       debugPrint('❌ [SB-VM] startBreak BLOCKED — user is outside assigned location');
//       return;
//     }
//     // ────────────────────────────────────────────────────────────────────────
//
//     // ── Get current GPS ────────────────────────────────────────────────────
//     final pos = await _getCurrentPosition();
//     _startLat = pos?.latitude  ?? 0;
//     _startLng = pos?.longitude ?? 0;
//
//     _activeBreak       = breakModel;
//     _breakStartTime    = DateTime.now();
//     _startTimestamp    = _breakStartTime!.toIso8601String();
//     _remainingSeconds  = breakModel.maxDuration.inSeconds;
//     _elapsedSeconds    = 0;
//
//     isOnShortBreak.value  = true;
//     activeBreakType.value = breakModel.breakType;
//     statusMessage.value   = '';
//
//     // ── Persist session so timer survives app kill / background ───────────────
//     await _saveActiveSession();
//
//     // ── POST to Apex ───────────────────────────────────────────────────────
//     _repo.postBreakStart(
//       empId:          _empId,
//       empName:        _empName,
//       companyCode:    _companyCode,
//       breakType:      breakModel.breakType,
//       startTimestamp: _startTimestamp!,
//       lat:            _startLat!,
//       lng:            _startLng!,
//     );
//
//     // ── Start countdown timer ──────────────────────────────────────────────
//     _startCountdownTimer();
//
//     // ── Start geo-fence watch (if enabled) ────────────────────────────────
//     if (_geofenceEnabled && _fenceLat != 0 && _fenceLng != 0) {
//       _startGeofenceWatch();
//     }
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // END BREAK  (manual or auto)
//   // ═══════════════════════════════════════════════════════════════════════════
//   Future<void> endBreak({bool captureSelfiee = true}) async {
//     if (!isOnShortBreak.value || _activeBreak == null) return;
//
//     // ── Location check: user must be at break-start location ─────────────────
//     // Check BEFORE cancelling timers so break continues if location is wrong.
//     if (_startLat != null && _startLng != null &&
//         _startLat != 0       && _startLng != 0) {
//       statusMessage.value = 'Verifying your location…';
//       final checkPos = await _getCurrentPosition();
//       if (checkPos != null) {
//         final dist = _haversineDistance(
//           checkPos.latitude, checkPos.longitude,
//           _startLat!, _startLng!,
//         );
//         debugPrint('📍 [SB-VM] endBreak location check: '
//             'dist=${dist.toStringAsFixed(1)} m from break-start point '
//             '(startLat=$_startLat, startLng=$_startLng)');
//         if (dist > 20) {
//           // ← location too far — block end, keep timers running
//           statusMessage.value = '';
//           Get.snackbar(
//             'Wrong Location',
//             'You must return to the location where you started your break. '
//                 'Please go back and try again.',
//             snackPosition: SnackPosition.BOTTOM,
//             duration: const Duration(seconds: 5),
//             backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
//             colorText: Colors.white,
//             icon: const Icon(Icons.location_off_rounded, color: Colors.white),
//           );
//           debugPrint('❌ [SB-VM] endBreak BLOCKED — user is ${dist.toStringAsFixed(0)} m away from start');
//           return; // timers are still running; break is NOT ended
//         }
//       }
//       statusMessage.value = '';
//     }
//     // ── Location OK — proceed to end break ───────────────────────────────────
//
//     _countdownTimer?.cancel();
//     _geofenceTimer?.cancel();
//     isEndingBreak.value = true;
//     statusMessage.value = 'Ending break…';
//
//     // ── Capture selfie ─────────────────────────────────────────────────────
//     String selfieBase64 = '';
//     if (captureSelfiee) {
//       statusMessage.value = 'Please take a selfie to confirm return.';
//       selfieBase64 = await _captureSelfie() ?? '';
//
//       // Selfie is required — break cannot end without it
//       if (selfieBase64.isEmpty) {
//         isEndingBreak.value = false;
//         statusMessage.value = '';
//         Get.snackbar(
//           'Selfie Required',
//           'A selfie is required to end your break. Please try again.',
//           snackPosition: SnackPosition.BOTTOM,
//           duration: const Duration(seconds: 4),
//           backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
//           colorText: Colors.white,
//           icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
//         );
//         debugPrint('❌ [SB-VM] endBreak BLOCKED — selfie not captured');
//         return; // break end nahi hogi
//       }
//     }
//
//     // ── Get end GPS ────────────────────────────────────────────────────────
//     statusMessage.value = 'Recording location…';
//     final endPos = await _getCurrentPosition();
//     final endLat = endPos?.latitude  ?? _startLat ?? 0;
//     final endLng = endPos?.longitude ?? _startLng ?? 0;
//     final endTimestamp = DateTime.now().toIso8601String();
//
//     // ── Re-validate critical user fields (they may have been empty at init) ──
//     if (_empId.isEmpty || _empName.isEmpty || _companyCode.isEmpty) {
//       debugPrint('⚠️  [SB-VM] endBreak: some user fields empty — re-reading prefs');
//       final prefs = await SharedPreferences.getInstance();
//       if (_empId.isEmpty) {
//         _empId = _firstNonEmpty(prefs, [
//           'emp_id', 'userId', 'empId', 'user_id', 'employee_id', 'employeeId', 'EMP_ID',
//         ]);
//       }
//       if (_empName.isEmpty) {
//         _empName = _firstNonEmpty(prefs, [
//           'emp_name', 'userName', 'empName', 'name', 'user_name', 'fullName', 'full_name',
//         ]);
//       }
//       if (_companyCode.isEmpty) {
//         _companyCode = _firstNonEmpty(prefs, [
//           'company_code', 'companyCode', 'CompanyCode', 'COMPANY_CODE', 'company', 'comp_code',
//         ]);
//       }
//       debugPrint('🔑 [SB-VM] endBreak re-resolved: '
//           'empId="$_empId" empName="$_empName" companyCode="$_companyCode"');
//     }
//
//     // ── Calculate total break time as "MM:SS" ─────────────────────────────
//     final totalMins = _elapsedSeconds ~/ 60;
//     final totalSecs = _elapsedSeconds  % 60;
//     final totalBreakTime =
//         '${totalMins.toString().padLeft(2, '0')}:${totalSecs.toString().padLeft(2, '0')}';
//     debugPrint('⏱️  [SB-VM] totalBreakTime="$totalBreakTime" (_elapsedSeconds=$_elapsedSeconds)');
//
//     // ── POST to Apex ───────────────────────────────────────────────────────
//     await _repo.postBreakEnd(
//       empId:          _empId,
//       empName:        _empName,
//       companyCode:    _companyCode,
//       depId:          _depId,
//       breakType:      _activeBreak!.breakType,
//       startTimestamp: _startTimestamp!,
//       endTimestamp:   endTimestamp,
//       totalBreakTime: totalBreakTime,
//       startLat:       _startLat ?? 0,
//       startLng:       _startLng ?? 0,
//       endLat:         endLat,
//       endLng:         endLng,
//       selfieBase64:   selfieBase64,
//     );
//
//     // ── Update used count & persist ────────────────────────────────────────
//     _activeBreak!.usedCount++;
//     await _persistUsedCounts();
//     breakPolicies.refresh();
//
//     // ── Reset state ────────────────────────────────────────────────────────
//     isOnShortBreak.value    = false;
//     isEndingBreak.value     = false;
//     activeBreakType.value   = '';
//     timerDisplay.value      = '';
//     elapsedDisplay.value    = '';
//     statusMessage.value     = 'Break ended successfully ✓';
//     _activeBreak            = null;
//     _breakStartTime         = null;
//     _startTimestamp         = null;
//     _startLat               = null;
//     _startLng               = null;
//
//     // ── Clear persisted session ────────────────────────────────────────────
//     await _clearActiveSession();
//
//     Future.delayed(const Duration(seconds: 3),
//             () => statusMessage.value = '');
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // ACTIVE SESSION PERSISTENCE — survives app kill & background
//   // ═══════════════════════════════════════════════════════════════════════════
//
//   /// Save all break session fields to SharedPreferences.
//   Future<void> _saveActiveSession() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool  (_kSessionActive,     true);
//       await prefs.setString(_kSessionBreakType,  _activeBreak!.breakType);
//       await prefs.setString(_kSessionStartTs,    _startTimestamp!);
//       await prefs.setInt   (_kSessionMaxSeconds, _activeBreak!.maxDuration.inSeconds);
//       await prefs.setDouble(_kSessionStartLat,   _startLat ?? 0);
//       await prefs.setDouble(_kSessionStartLng,   _startLng ?? 0);
//       debugPrint('💾 [SB-VM] Active session saved: '
//           'type="${_activeBreak!.breakType}" startTs="$_startTimestamp"');
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] _saveActiveSession error: $e');
//     }
//   }
//
//   /// Clear the persisted session (called when break ends normally).
//   Future<void> _clearActiveSession() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove(_kSessionActive);
//       await prefs.remove(_kSessionBreakType);
//       await prefs.remove(_kSessionStartTs);
//       await prefs.remove(_kSessionMaxSeconds);
//       await prefs.remove(_kSessionStartLat);
//       await prefs.remove(_kSessionStartLng);
//       debugPrint('🗑️ [SB-VM] Active session cleared');
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] _clearActiveSession error: $e');
//     }
//   }
//
//   /// On app reopen: if a session was active, calculate how much time has
//   /// elapsed since startTimestamp and resume the timer from that point.
//   Future<void> _restoreActiveSession(SharedPreferences prefs) async {
//     try {
//       final active = prefs.getBool(_kSessionActive) ?? false;
//       if (!active) return;
//
//       final breakType  = prefs.getString(_kSessionBreakType) ?? '';
//       final startTsStr = prefs.getString(_kSessionStartTs)   ?? '';
//       final maxSeconds = prefs.getInt   (_kSessionMaxSeconds) ?? 0;
//       final startLat   = prefs.getDouble(_kSessionStartLat)  ?? 0;
//       final startLng   = prefs.getDouble(_kSessionStartLng)  ?? 0;
//
//       if (breakType.isEmpty || startTsStr.isEmpty || maxSeconds == 0) {
//         debugPrint('⚠️ [SB-VM] _restoreActiveSession: incomplete data — clearing');
//         await _clearActiveSession();
//         return;
//       }
//
//       final startTime = DateTime.tryParse(startTsStr);
//       if (startTime == null) {
//         debugPrint('⚠️ [SB-VM] _restoreActiveSession: bad startTs "$startTsStr" — clearing');
//         await _clearActiveSession();
//         return;
//       }
//
//       // ── Calculate real elapsed time since break started ──────────────────
//       final elapsedSinceStart = DateTime.now().difference(startTime).inSeconds;
//       final remaining         = maxSeconds - elapsedSinceStart;
//
//       debugPrint('');
//       debugPrint('🔄 [SB-VM] Restoring active session...');
//       debugPrint('🔄 [SB-VM]   breakType     = "$breakType"');
//       debugPrint('🔄 [SB-VM]   startTs       = "$startTsStr"');
//       debugPrint('🔄 [SB-VM]   maxSeconds    = $maxSeconds');
//       debugPrint('🔄 [SB-VM]   elapsedSince  = ${elapsedSinceStart}s');
//       debugPrint('🔄 [SB-VM]   remaining     = ${remaining}s');
//
//       if (remaining <= 0) {
//         // Break time already expired while app was closed — end it silently
//         debugPrint('⚠️ [SB-VM] Break already expired while app was closed — ending silently');
//         await _clearActiveSession();
//         return;
//       }
//
//       // ── Find the matching policy in breakPolicies ────────────────────────
//       // breakPolicies may not be loaded yet — reconstruct a minimal model
//       ShortBreakModel? model;
//       try {
//         model = breakPolicies.firstWhere((p) => p.breakType == breakType);
//       } catch (_) {
//         // Policy not loaded yet; build a stub from saved data
//         model = ShortBreakModel(
//           breakType:      breakType,
//           countLimit:     99,
//           shortBreakTime: '${maxSeconds ~/ 60}:${(maxSeconds % 60).toString().padLeft(2, '0')}',
//         );
//       }
//
//       // ── Resume state ─────────────────────────────────────────────────────
//       _activeBreak      = model;
//       _breakStartTime   = startTime;
//       _startTimestamp   = startTsStr;
//       _startLat         = startLat;
//       _startLng         = startLng;
//       _remainingSeconds = remaining;
//       _elapsedSeconds   = elapsedSinceStart;
//
//       isOnShortBreak.value  = true;
//       activeBreakType.value = breakType;
//       statusMessage.value   = '';
//
//       _startCountdownTimer();
//
//       if (_geofenceEnabled && _fenceLat != 0 && _fenceLng != 0) {
//         _startGeofenceWatch();
//       }
//
//       debugPrint('✅ [SB-VM] Session restored — timer resumed with ${remaining}s remaining');
//       debugPrint('');
//     } catch (e, stack) {
//       debugPrint('❌ [SB-VM] _restoreActiveSession error: $e');
//       debugPrint('❌ [SB-VM] Stack: $stack');
//       await _clearActiveSession();
//     }
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // COUNTDOWN TIMER
//   // ═══════════════════════════════════════════════════════════════════════════
//   void _startCountdownTimer() {
//     _updateTimerDisplay();
//     _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (_remainingSeconds > 0) {
//         _remainingSeconds--;
//         _elapsedSeconds++;
//         _updateTimerDisplay();
//       } else {
//         t.cancel();
//         statusMessage.value = 'Break time expired!';
//         endBreak();
//       }
//     });
//   }
//
//   void _updateTimerDisplay() {
//     final m = _remainingSeconds ~/ 60;
//     final s = _remainingSeconds  % 60;
//     timerDisplay.value = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
//
//     final em = _elapsedSeconds ~/ 60;
//     final es = _elapsedSeconds  % 60;
//     elapsedDisplay.value =
//     '${em.toString().padLeft(2, '0')}:${es.toString().padLeft(2, '0')}';
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // GEO-FENCE WATCHER
//   // ═══════════════════════════════════════════════════════════════════════════
//   void _startGeofenceWatch() {
//     debugPrint('🗺️ [SB-VM] Starting geo-fence watch '
//         '(center=$_fenceLat,$_fenceLng  radius=$_fenceRadius m)');
//
//     _geofenceTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
//       if (!isOnShortBreak.value) return;
//       final pos = await _getCurrentPosition();
//       if (pos == null) return;
//
//       final dist = _haversineDistance(
//         pos.latitude, pos.longitude,
//         _fenceLat, _fenceLng,
//       );
//       debugPrint('📍 [SB-VM] Distance from fence center: ${dist.toStringAsFixed(1)} m');
//
//       if (dist <= _fenceRadius) {
//         debugPrint('✅ [SB-VM] Employee inside geo-fence → auto-ending break');
//         _geofenceTimer?.cancel();
//         statusMessage.value = 'You have returned to your area. Ending break…';
//         await endBreak();
//       }
//     });
//   }
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // HELPERS
//   // ═══════════════════════════════════════════════════════════════════════════
//
//   // ═══════════════════════════════════════════════════════════════════════════
//   // LOCATION VALIDATION — checks if user is inside the assigned work location
//   // Reads the location selected in LocationSelectionScreen (via SharedPrefs).
//   // Supports both circle-radius and polygon geofences, mirroring the logic
//   // in GeofenceViolationViewModel without touching any other module.
//   // ═══════════════════════════════════════════════════════════════════════════
//   Future<bool> _isInsideAssignedLocation() async {
//     try {
//       // ── 1. Read the selected location from SharedPreferences ───────────────
//       final prefs = await SharedPreferences.getInstance();
//
//       final assignedLat    = prefs.getDouble('selected_lat');
//       final assignedLng    = prefs.getDouble('selected_lng');
//       final assignedRadius = prefs.getDouble('selected_radius');
//       final shapeType      = prefs.getString('selected_shape_type');
//       final shapeCoords    = prefs.getString('selected_shape_coords');
//       final locationName   = prefs.getString('selected_location_name') ?? 'Work Location';
//
//       debugPrint('');
//       debugPrint('════════════════════════════════════════════════════════');
//       debugPrint('📍 [SB-VM] _isInsideAssignedLocation() — break start check');
//       debugPrint('📍 [SB-VM] assignedLat    = $assignedLat');
//       debugPrint('📍 [SB-VM] assignedLng    = $assignedLng');
//       debugPrint('📍 [SB-VM] assignedRadius = $assignedRadius m');
//       debugPrint('📍 [SB-VM] shapeType      = "$shapeType"');
//       debugPrint('📍 [SB-VM] locationName   = "$locationName"');
//
//       // ── 2. If no location was ever selected, allow break (fail-open) ───────
//       if (assignedLat == null || assignedLng == null ||
//           assignedLat == 0.0  || assignedLng == 0.0) {
//         debugPrint('⚠️  [SB-VM] No assigned location found in prefs — allowing break (fail-open)');
//         debugPrint('════════════════════════════════════════════════════════');
//         return true;
//       }
//
//       // ── 3. Get the current GPS position ────────────────────────────────────
//       final pos = await _getCurrentPosition();
//       if (pos == null) {
//         debugPrint('⚠️  [SB-VM] Could not get GPS position — allowing break (fail-open)');
//         debugPrint('════════════════════════════════════════════════════════');
//         return true; // GPS unavailable → fail-open so break is not wrongly blocked
//       }
//
//       debugPrint('📍 [SB-VM] Current GPS: lat=${pos.latitude}  lng=${pos.longitude}  '
//           'accuracy=${pos.accuracy.toStringAsFixed(1)} m');
//
//       // ── 4. Shape-aware inside check ────────────────────────────────────────
//       bool isInside;
//
//       if (shapeType == 'polygon' &&
//           shapeCoords != null &&
//           shapeCoords.isNotEmpty) {
//         // ── Polygon check (ray-casting) ─────────────────────────────────────
//         final polygon = _parsePolygonCoordsForBreak(shapeCoords);
//         if (polygon != null && polygon.isNotEmpty) {
//           isInside = _isPointInPolygonForBreak(pos.latitude, pos.longitude, polygon);
//           debugPrint('🔷 [SB-VM] Polygon check: inside=$isInside');
//         } else {
//           // Malformed polygon coords → fall back to radius
//           final dist = Geolocator.distanceBetween(
//               pos.latitude, pos.longitude, assignedLat, assignedLng);
//           isInside = dist <= (assignedRadius ?? 100);
//           debugPrint('📏 [SB-VM] Radius fallback (bad polygon): '
//               'dist=${dist.toStringAsFixed(1)} m  radius=${assignedRadius ?? 100} m  inside=$isInside');
//         }
//       } else {
//         // ── Circle-radius check ─────────────────────────────────────────────
//         final dist = Geolocator.distanceBetween(
//             pos.latitude, pos.longitude, assignedLat, assignedLng);
//         isInside = dist <= (assignedRadius ?? 100);
//         debugPrint('📏 [SB-VM] Radius check: '
//             'dist=${dist.toStringAsFixed(1)} m  radius=${assignedRadius ?? 100} m  inside=$isInside');
//       }
//
//       debugPrint('${isInside ? "✅" : "❌"} [SB-VM] Inside "$locationName" = $isInside');
//       debugPrint('════════════════════════════════════════════════════════');
//       debugPrint('');
//       return isInside;
//     } catch (e, stack) {
//       debugPrint('❌ [SB-VM] _isInsideAssignedLocation error: $e');
//       debugPrint('❌ [SB-VM] Stack: $stack');
//       return true; // fail-open on unexpected errors
//     }
//   }
//
//   /// Parses a shape_coords JSON string into a list of lat/lng maps.
//   /// Format: {"coordinates":[{"lat":…,"lng":…},…]}
//   List<Map<String, double>>? _parsePolygonCoordsForBreak(String raw) {
//     try {
//       final decoded = jsonDecode(raw) as Map<String, dynamic>;
//       final coords  = (decoded['coordinates'] as List<dynamic>)
//           .map((c) => {
//         'lat': double.parse(c['lat'].toString()),
//         'lng': double.parse(c['lng'].toString()),
//       })
//           .toList();
//       return coords;
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] _parsePolygonCoordsForBreak error: $e');
//       return null;
//     }
//   }
//
//   /// Ray-casting point-in-polygon check (convex & concave polygons).
//   bool _isPointInPolygonForBreak(
//       double lat, double lng, List<Map<String, double>> polygon) {
//     final int n      = polygon.length;
//     bool      inside = false;
//     int       j      = n - 1;
//     for (int i = 0; i < n; i++) {
//       final double xi = polygon[i]['lat']!;
//       final double yi = polygon[i]['lng']!;
//       final double xj = polygon[j]['lat']!;
//       final double yj = polygon[j]['lng']!;
//       if (((yi > lng) != (yj > lng)) &&
//           (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) {
//         inside = !inside;
//       }
//       j = i;
//     }
//     return inside;
//   }
//
//   Future<Position?> _getCurrentPosition() async {
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) return null;
//
//       LocationPermission perm = await Geolocator.checkPermission();
//       if (perm == LocationPermission.denied) {
//         perm = await Geolocator.requestPermission();
//         if (perm == LocationPermission.denied) return null;
//       }
//       if (perm == LocationPermission.deniedForever) return null;
//
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       ).timeout(const Duration(seconds: 10));
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] GPS error: $e');
//       return null;
//     }
//   }
//
//   Future<String?> _captureSelfie() async {
//     try {
//       // ── Step 1: Capture from front camera ─────────────────────────────────
//       final picker = ImagePicker();
//       final XFile? photo = await picker.pickImage(
//         source: ImageSource.camera,
//         preferredCameraDevice: CameraDevice.front,
//         imageQuality: 100, // capture full quality — we compress manually below
//         maxWidth: 1280,
//       );
//       if (photo == null) return null;
//
//       final originalBytes = await File(photo.path).readAsBytes();
//       debugPrint('📸 [SB-VM] Original size : ${(originalBytes.length / 1024).toStringAsFixed(1)} KB');
//
//       // ── Step 2: Compress ───────────────────────────────────────────────────
//       final compressed = await FlutterImageCompress.compressWithList(
//         originalBytes,
//         minWidth:  400,
//         minHeight: 400,
//         quality:   40,           // 0-100 — lower = smaller file
//         format:    CompressFormat.jpeg,
//         autoCorrectionAngle: true,
//       );
//
//       final savedKB = ((originalBytes.length - compressed.length) / 1024).toStringAsFixed(1);
//       debugPrint('📸 [SB-VM] Compressed to: ${(compressed.length / 1024).toStringAsFixed(1)} KB  (saved ${savedKB} KB)');
//
//       return base64Encode(compressed);
//     } catch (e) {
//       debugPrint('⚠️ [SB-VM] Selfie capture error: $e');
//       return null;
//     }
//   }
//
//   Future<void> _persistUsedCounts() async {
//     final prefs = await SharedPreferences.getInstance();
//     final today = _today();
//     debugPrint('💾 [SB-VM] Saving usedCounts for empId="$_empId" date="$today"');
//     for (final p in breakPolicies) {
//       final key = 'sb_cnt_${_empId}_${p.breakType}_$today';
//       await prefs.setInt(key, p.usedCount);
//       debugPrint('💾 [SB-VM]   "${p.breakType}" → key="$key" saved=${p.usedCount}');
//     }
//   }
//
//   /// Haversine formula — returns distance in metres
//   double _haversineDistance(
//       double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371000.0;
//     final dLat = _deg2rad(lat2 - lat1);
//     final dLon = _deg2rad(lon2 - lon1);
//     final a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(_deg2rad(lat1)) *
//             cos(_deg2rad(lat2)) *
//             sin(dLon / 2) *
//             sin(dLon / 2);
//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return R * c;
//   }
//
//   double _deg2rad(double deg) => deg * pi / 180;
//
//   String _today() {
//     final now = DateTime.now();
//     return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
//   }
//
//   // ── Expose active break model for UI ──────────────────────────────────────
//   ShortBreakModel? get activeBreakModel => _activeBreak;
// }


// lib/ViewModels/short_break_viewmodel.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/short_break_model.dart';
import '../Repositories/short_break_repository.dart';

class ShortBreakViewModel extends GetxController {
  // ── Repository ─────────────────────────────────────────────────────────────
  final _repo = ShortBreakRepository();

  // ── Observable state ───────────────────────────────────────────────────────
  final RxList<ShortBreakModel> breakPolicies    = <ShortBreakModel>[].obs;
  final RxBool   isLoading                       = false.obs;
  final RxBool   isOnShortBreak                  = false.obs;
  final RxBool   isEndingBreak                   = false.obs;

  /// Countdown remaining (formatted "MM:SS")
  final RxString timerDisplay                    = ''.obs;
  /// Elapsed since break started (formatted "MM:SS")
  final RxString elapsedDisplay                  = ''.obs;

  final RxString activeBreakType                 = ''.obs;
  final RxString statusMessage                   = ''.obs;

  // ── Internal break session data ────────────────────────────────────────────
  ShortBreakModel? _activeBreak;
  DateTime?        _breakStartTime;
  String?          _startTimestamp;
  double?          _startLat;
  double?          _startLng;

  Timer?   _countdownTimer;
  Timer?   _geofenceTimer;
  int      _remainingSeconds = 0;
  int      _elapsedSeconds   = 0;

  // ── Cached user info ───────────────────────────────────────────────────────
  String _empId       = '';
  String _empName     = '';
  String _companyCode = '';
  String _depId       = '';

  // ── Geo-fence settings ─────────────────────────────────────────────────────
  bool   _geofenceEnabled = false;
  double _fenceLat        = 0;
  double _fenceLng        = 0;
  double _fenceRadius     = 100; // metres

  // ── SharedPrefs keys for active session persistence ────────────────────────
  // These keys survive app kill/background so the timer can resume correctly.
  static const String _kSessionActive     = 'sb_session_active';
  static const String _kSessionBreakType  = 'sb_session_break_type';
  static const String _kSessionStartTs    = 'sb_session_start_ts';
  static const String _kSessionMaxSeconds = 'sb_session_max_seconds';
  static const String _kSessionStartLat   = 'sb_session_start_lat';
  static const String _kSessionStartLng   = 'sb_session_start_lng';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadUserData();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _geofenceTimer?.cancel();
    super.onClose();
  }

  // ── Load user data from SharedPreferences ─────────────────────────────────
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    debugPrint('');
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('🔑 [SB-VM] _loadUserData() — reading SharedPreferences');

    final allKeys = prefs.getKeys();
    debugPrint('🔑 [SB-VM] ALL stored keys: $allKeys');
    debugPrint('🔑 [SB-VM] ALL key-value dump:');
    for (final k in allKeys) {
      debugPrint('   "$k" = "${prefs.get(k)}"');
    }
    debugPrint('');

    // ── emp_id: try every possible key ──────────────────────────────────────
    _empId = _firstNonEmpty(prefs, [
      'emp_id', 'userId', 'empId', 'user_id',
      'employee_id', 'employeeId', 'EMP_ID',
    ]);
    debugPrint('🔑 [SB-VM] emp_id resolved      = "$_empId"');

    // ── emp_name ─────────────────────────────────────────────────────────────
    _empName = _firstNonEmpty(prefs, [
      'emp_name', 'userName', 'empName', 'name',
      'user_name', 'fullName', 'full_name',
    ]);
    debugPrint('🔑 [SB-VM] emp_name resolved     = "$_empName"');

    // ── company_code: try every possible key ─────────────────────────────────
    _companyCode = _firstNonEmpty(prefs, [
      'company_code', 'companyCode', 'CompanyCode',
      'COMPANY_CODE', 'company', 'comp_code',
    ]);
    debugPrint('🔑 [SB-VM] company_code resolved = "$_companyCode"');

    // ── dep_id: try every possible key ───────────────────────────────────────
    _depId = _firstNonEmpty(prefs, [
      'cached_dep_id', 'dep_id', 'depId', 'DEP_ID',
      'department_id', 'departmentId', 'dept_id', 'deptId',
    ]);
    debugPrint('🔑 [SB-VM] dep_id resolved       = "$_depId"');

    // ── Diagnosis ────────────────────────────────────────────────────────────
    debugPrint('');
    if (_depId.isEmpty) {
      debugPrint('❌ [SB-VM] dep_id  is EMPTY — none of the known keys matched');
      debugPrint('   → Look at the ALL key-value dump above and find the correct key');
      debugPrint('   → Add it to the _firstNonEmpty list for dep_id');
    }
    if (_companyCode.isEmpty) {
      debugPrint('❌ [SB-VM] company_code is EMPTY — none of the known keys matched');
      debugPrint('   → Look at the ALL key-value dump above and find the correct key');
      debugPrint('   → Add it to the _firstNonEmpty list for company_code');
    }
    if (_depId.isNotEmpty && _companyCode.isNotEmpty) {
      debugPrint('✅ [SB-VM] Both depId and companyCode resolved — will fetch policy');
    }
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('');

    _loadGeoFenceSettings(prefs);

    // ── Restore active break session if app was killed/backgrounded ──────────
    await _restoreActiveSession(prefs);

    if (_depId.isNotEmpty && _companyCode.isNotEmpty) {
      fetchBreakPolicy();
    } else {
      // Show a clear message with which field is missing
      final missing = <String>[];
      if (_depId.isEmpty)       missing.add('dep_id');
      if (_companyCode.isEmpty) missing.add('company_code');
      statusMessage.value =
      'User data not found (${missing.join(', ')}). Please re-login.';
      debugPrint('⚠️  [SB-VM] Skipping fetchBreakPolicy — missing: ${missing.join(', ')}');
    }
  }

  /// Returns the first non-empty string value found among the given [keys].
  /// Uses prefs.get() (not getString) to safely handle keys stored as int/bool.
  String _firstNonEmpty(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final raw = prefs.get(key); // works for String, int, bool, double
      if (raw == null) continue;
      final val = raw.toString().trim();
      if (val.isNotEmpty) {
        debugPrint('   ✅ key "$key" = "$val" (type: ${raw.runtimeType})');
        return val;
      }
    }
    return '';
  }

  void _loadGeoFenceSettings(SharedPreferences prefs) {
    try {
      final cached = prefs.getString('cached_locations');
      if (cached == null || cached.isEmpty) return;

      final items = jsonDecode(cached) as List<dynamic>;
      if (items.isEmpty) return;

      final loc = items.first as Map<String, dynamic>;

      final lat = double.tryParse(
        (loc['latitude'] ?? loc['LATITUDE'] ?? loc['lat'] ?? '0').toString(),
      );
      final lng = double.tryParse(
        (loc['longitude'] ?? loc['LONGITUDE'] ?? loc['lng'] ?? '0').toString(),
      );
      final radius = double.tryParse(
        (loc['radius'] ?? loc['RADIUS'] ?? '100').toString(),
      );

      final geofenceFlag =
      (loc['geofence_enabled'] ?? loc['GEOFENCE_ENABLED'] ?? '').toString().toLowerCase();

      if (lat != null && lng != null && lat != 0 && lng != 0) {
        _fenceLat        = lat;
        _fenceLng        = lng;
        _fenceRadius     = radius ?? 100;
        _geofenceEnabled =
            geofenceFlag == 'yes' || geofenceFlag == 'true' || geofenceFlag == '1';
        debugPrint('📍 [SB-VM] GeoFence: enabled=$_geofenceEnabled '
            'lat=$_fenceLat lng=$_fenceLng radius=$_fenceRadius');
      }
    } catch (e) {
      debugPrint('⚠️ [SB-VM] Could not load geo-fence settings: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH BREAK POLICY
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> fetchBreakPolicy() async {
    // If values are still empty, re-read prefs before giving up
    if (_depId.isEmpty || _companyCode.isEmpty) {
      debugPrint('⚠️  [SB-VM] fetchBreakPolicy called but fields empty — re-reading prefs');
      await _loadUserData();
      return; // _loadUserData will call fetchBreakPolicy again if resolved
    }

    isLoading.value = true;
    statusMessage.value = '';

    debugPrint('🟢 [SB-VM] fetchBreakPolicy → depId="$_depId" companyCode="$_companyCode"');

    final policies = await _repo.fetchBreakPolicy(
      depId: _depId,
      companyCode: _companyCode,
    );

    // ── Restore usedCount from previous session (same day) ───────────────────
    final prefs = await SharedPreferences.getInstance();
    final today = _today();

    // ── Re-resolve _empId in case it was empty at onInit time ────────────────
    // endBreak() saves with the resolved empId; we must use the same key here.
    if (_empId.isEmpty) {
      _empId = _firstNonEmpty(prefs, [
        'emp_id', 'userId', 'empId', 'user_id',
        'employee_id', 'employeeId', 'EMP_ID',
      ]);
      debugPrint('🔄 [SB-VM] fetchBreakPolicy: re-resolved empId="$_empId"');
    }

    debugPrint('🔄 [SB-VM] Restoring usedCounts for empId="$_empId" date="$today"');
    for (final p in policies) {
      final key   = 'sb_cnt_${_empId}_${p.breakType}_$today';
      final saved = prefs.getInt(key) ?? 0;
      p.usedCount = saved;
      debugPrint('🔄 [SB-VM]   "${p.breakType}" → key="$key" restored=$saved');
    }

    breakPolicies.assignAll(policies);
    isLoading.value = false;

    if (policies.isEmpty) {
      statusMessage.value = 'No short break policy configured for your department.';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // START BREAK  ← ✅ MODIFIED: clock-in check added
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> startBreak(ShortBreakModel breakModel) async {
    if (isOnShortBreak.value) {
      Get.snackbar('Already on Break',
          'Please end your current break before starting a new one.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!breakModel.canTakeBreak) {
      Get.snackbar('Limit Reached',
          'You have used all ${breakModel.countLimit} ${breakModel.breakType}(s) for today.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // ✅ NEW: Clock-in check — without clock-in, break cannot start
    // ──────────────────────────────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final bool isClockedIn = prefs.getBool('isClockedIn') ?? false;

    if (!isClockedIn) {
      Get.snackbar(
        '⛔ Clock-In Required',
        'You must clock in before starting a break.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
        colorText: Colors.white,
        icon: const Icon(Icons.login_rounded, color: Colors.white),
      );
      debugPrint('❌ [SB-VM] startBreak BLOCKED — user is not clocked in');
      return;
    }
    // ──────────────────────────────────────────────────────────────────────────

    // ── Location validation: user must be inside the assigned work location ──
    statusMessage.value = 'Verifying your location…';
    final bool locationOk = await _isInsideAssignedLocation();
    statusMessage.value = '';
    if (!locationOk) {
      Get.snackbar(
        'Outside Work Location',
        'You are not in the assigned work location.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
        colorText: Colors.white,
        icon: const Icon(Icons.location_off_rounded, color: Colors.white),
      );
      debugPrint('❌ [SB-VM] startBreak BLOCKED — user is outside assigned location');
      return;
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Get current GPS ────────────────────────────────────────────────────
    final pos = await _getCurrentPosition();
    _startLat = pos?.latitude  ?? 0;
    _startLng = pos?.longitude ?? 0;

    _activeBreak       = breakModel;
    _breakStartTime    = DateTime.now();
    _startTimestamp    = _breakStartTime!.toIso8601String();
    _remainingSeconds  = breakModel.maxDuration.inSeconds;
    _elapsedSeconds    = 0;

    isOnShortBreak.value  = true;
    activeBreakType.value = breakModel.breakType;
    statusMessage.value   = '';

    // ── Persist session so timer survives app kill / background ───────────────
    await _saveActiveSession();

    // ── POST to Apex ───────────────────────────────────────────────────────
    _repo.postBreakStart(
      empId:          _empId,
      empName:        _empName,
      companyCode:    _companyCode,
      breakType:      breakModel.breakType,
      startTimestamp: _startTimestamp!,
      lat:            _startLat!,
      lng:            _startLng!,
    );

    // ── Start countdown timer ──────────────────────────────────────────────
    _startCountdownTimer();

    // ── Start geo-fence watch (if enabled) ────────────────────────────────
    if (_geofenceEnabled && _fenceLat != 0 && _fenceLng != 0) {
      _startGeofenceWatch();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // END BREAK  (manual or auto)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> endBreak({bool captureSelfiee = true}) async {
    if (!isOnShortBreak.value || _activeBreak == null) return;

    // ── Location check: user must be at break-start location ─────────────────
    // Check BEFORE cancelling timers so break continues if location is wrong.
    if (_startLat != null && _startLng != null &&
        _startLat != 0       && _startLng != 0) {
      statusMessage.value = 'Verifying your location…';
      final checkPos = await _getCurrentPosition();
      if (checkPos != null) {
        final dist = _haversineDistance(
          checkPos.latitude, checkPos.longitude,
          _startLat!, _startLng!,
        );
        debugPrint('📍 [SB-VM] endBreak location check: '
            'dist=${dist.toStringAsFixed(1)} m from break-start point '
            '(startLat=$_startLat, startLng=$_startLng)');
        if (dist > 20) {
          // ← location too far — block end, keep timers running
          statusMessage.value = '';
          Get.snackbar(
            'Wrong Location',
            'You must return to the location where you started your break. '
                'Please go back and try again.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
            colorText: Colors.white,
            icon: const Icon(Icons.location_off_rounded, color: Colors.white),
          );
          debugPrint('❌ [SB-VM] endBreak BLOCKED — user is ${dist.toStringAsFixed(0)} m away from start');
          return; // timers are still running; break is NOT ended
        }
      }
      statusMessage.value = '';
    }
    // ── Location OK — proceed to end break ───────────────────────────────────

    _countdownTimer?.cancel();
    _geofenceTimer?.cancel();
    isEndingBreak.value = true;
    statusMessage.value = 'Ending break…';

    // ── Capture selfie ─────────────────────────────────────────────────────
    String selfieBase64 = '';
    if (captureSelfiee) {
      statusMessage.value = 'Please take a selfie to confirm return.';
      selfieBase64 = await _captureSelfie() ?? '';

      // Selfie is required — break cannot end without it
      if (selfieBase64.isEmpty) {
        isEndingBreak.value = false;
        statusMessage.value = '';
        Get.snackbar(
          'Selfie Required',
          'A selfie is required to end your break. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
          colorText: Colors.white,
          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        );
        debugPrint('❌ [SB-VM] endBreak BLOCKED — selfie not captured');
        return; // break end nahi hogi
      }
    }

    // ── Get end GPS ────────────────────────────────────────────────────────
    statusMessage.value = 'Recording location…';
    final endPos = await _getCurrentPosition();
    final endLat = endPos?.latitude  ?? _startLat ?? 0;
    final endLng = endPos?.longitude ?? _startLng ?? 0;
    final endTimestamp = DateTime.now().toIso8601String();

    // ── Re-validate critical user fields (they may have been empty at init) ──
    if (_empId.isEmpty || _empName.isEmpty || _companyCode.isEmpty) {
      debugPrint('⚠️  [SB-VM] endBreak: some user fields empty — re-reading prefs');
      final prefs = await SharedPreferences.getInstance();
      if (_empId.isEmpty) {
        _empId = _firstNonEmpty(prefs, [
          'emp_id', 'userId', 'empId', 'user_id', 'employee_id', 'employeeId', 'EMP_ID',
        ]);
      }
      if (_empName.isEmpty) {
        _empName = _firstNonEmpty(prefs, [
          'emp_name', 'userName', 'empName', 'name', 'user_name', 'fullName', 'full_name',
        ]);
      }
      if (_companyCode.isEmpty) {
        _companyCode = _firstNonEmpty(prefs, [
          'company_code', 'companyCode', 'CompanyCode', 'COMPANY_CODE', 'company', 'comp_code',
        ]);
      }
      debugPrint('🔑 [SB-VM] endBreak re-resolved: '
          'empId="$_empId" empName="$_empName" companyCode="$_companyCode"');
    }

    // ── Calculate total break time as "MM:SS" ─────────────────────────────
    final totalMins = _elapsedSeconds ~/ 60;
    final totalSecs = _elapsedSeconds  % 60;
    final totalBreakTime =
        '${totalMins.toString().padLeft(2, '0')}:${totalSecs.toString().padLeft(2, '0')}';
    debugPrint('⏱️  [SB-VM] totalBreakTime="$totalBreakTime" (_elapsedSeconds=$_elapsedSeconds)');

    // ── POST to Apex ───────────────────────────────────────────────────────
    await _repo.postBreakEnd(
      empId:          _empId,
      empName:        _empName,
      companyCode:    _companyCode,
      depId:          _depId,
      breakType:      _activeBreak!.breakType,
      startTimestamp: _startTimestamp!,
      endTimestamp:   endTimestamp,
      totalBreakTime: totalBreakTime,
      startLat:       _startLat ?? 0,
      startLng:       _startLng ?? 0,
      endLat:         endLat,
      endLng:         endLng,
      selfieBase64:   selfieBase64,
    );

    // ── Update used count & persist ────────────────────────────────────────
    _activeBreak!.usedCount++;
    await _persistUsedCounts();
    breakPolicies.refresh();

    // ── Reset state ────────────────────────────────────────────────────────
    isOnShortBreak.value    = false;
    isEndingBreak.value     = false;
    activeBreakType.value   = '';
    timerDisplay.value      = '';
    elapsedDisplay.value    = '';
    statusMessage.value     = 'Break ended successfully ✓';
    _activeBreak            = null;
    _breakStartTime         = null;
    _startTimestamp         = null;
    _startLat               = null;
    _startLng               = null;

    // ── Clear persisted session ────────────────────────────────────────────
    await _clearActiveSession();

    Future.delayed(const Duration(seconds: 3),
            () => statusMessage.value = '');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVE SESSION PERSISTENCE — survives app kill & background
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save all break session fields to SharedPreferences.
  Future<void> _saveActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool  (_kSessionActive,     true);
      await prefs.setString(_kSessionBreakType,  _activeBreak!.breakType);
      await prefs.setString(_kSessionStartTs,    _startTimestamp!);
      await prefs.setInt   (_kSessionMaxSeconds, _activeBreak!.maxDuration.inSeconds);
      await prefs.setDouble(_kSessionStartLat,   _startLat ?? 0);
      await prefs.setDouble(_kSessionStartLng,   _startLng ?? 0);
      debugPrint('💾 [SB-VM] Active session saved: '
          'type="${_activeBreak!.breakType}" startTs="$_startTimestamp"');
    } catch (e) {
      debugPrint('⚠️ [SB-VM] _saveActiveSession error: $e');
    }
  }

  /// Clear the persisted session (called when break ends normally).
  Future<void> _clearActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionActive);
      await prefs.remove(_kSessionBreakType);
      await prefs.remove(_kSessionStartTs);
      await prefs.remove(_kSessionMaxSeconds);
      await prefs.remove(_kSessionStartLat);
      await prefs.remove(_kSessionStartLng);
      debugPrint('🗑️ [SB-VM] Active session cleared');
    } catch (e) {
      debugPrint('⚠️ [SB-VM] _clearActiveSession error: $e');
    }
  }

  /// On app reopen: if a session was active, calculate how much time has
  /// elapsed since startTimestamp and resume the timer from that point.
  Future<void> _restoreActiveSession(SharedPreferences prefs) async {
    try {
      final active = prefs.getBool(_kSessionActive) ?? false;
      if (!active) return;

      final breakType  = prefs.getString(_kSessionBreakType) ?? '';
      final startTsStr = prefs.getString(_kSessionStartTs)   ?? '';
      final maxSeconds = prefs.getInt   (_kSessionMaxSeconds) ?? 0;
      final startLat   = prefs.getDouble(_kSessionStartLat)  ?? 0;
      final startLng   = prefs.getDouble(_kSessionStartLng)  ?? 0;

      if (breakType.isEmpty || startTsStr.isEmpty || maxSeconds == 0) {
        debugPrint('⚠️ [SB-VM] _restoreActiveSession: incomplete data — clearing');
        await _clearActiveSession();
        return;
      }

      final startTime = DateTime.tryParse(startTsStr);
      if (startTime == null) {
        debugPrint('⚠️ [SB-VM] _restoreActiveSession: bad startTs "$startTsStr" — clearing');
        await _clearActiveSession();
        return;
      }

      // ── Calculate real elapsed time since break started ──────────────────
      final elapsedSinceStart = DateTime.now().difference(startTime).inSeconds;
      final remaining         = maxSeconds - elapsedSinceStart;

      debugPrint('');
      debugPrint('🔄 [SB-VM] Restoring active session...');
      debugPrint('🔄 [SB-VM]   breakType     = "$breakType"');
      debugPrint('🔄 [SB-VM]   startTs       = "$startTsStr"');
      debugPrint('🔄 [SB-VM]   maxSeconds    = $maxSeconds');
      debugPrint('🔄 [SB-VM]   elapsedSince  = ${elapsedSinceStart}s');
      debugPrint('🔄 [SB-VM]   remaining     = ${remaining}s');

      if (remaining <= 0) {
        // Break time already expired while app was closed — end it silently
        debugPrint('⚠️ [SB-VM] Break already expired while app was closed — ending silently');
        await _clearActiveSession();
        return;
      }

      // ── Find the matching policy in breakPolicies ────────────────────────
      // breakPolicies may not be loaded yet — reconstruct a minimal model
      ShortBreakModel? model;
      try {
        model = breakPolicies.firstWhere((p) => p.breakType == breakType);
      } catch (_) {
        // Policy not loaded yet; build a stub from saved data
        model = ShortBreakModel(
          breakType:      breakType,
          countLimit:     99,
          shortBreakTime: '${maxSeconds ~/ 60}:${(maxSeconds % 60).toString().padLeft(2, '0')}',
        );
      }

      // ── Resume state ─────────────────────────────────────────────────────
      _activeBreak      = model;
      _breakStartTime   = startTime;
      _startTimestamp   = startTsStr;
      _startLat         = startLat;
      _startLng         = startLng;
      _remainingSeconds = remaining;
      _elapsedSeconds   = elapsedSinceStart;

      isOnShortBreak.value  = true;
      activeBreakType.value = breakType;
      statusMessage.value   = '';

      _startCountdownTimer();

      if (_geofenceEnabled && _fenceLat != 0 && _fenceLng != 0) {
        _startGeofenceWatch();
      }

      debugPrint('✅ [SB-VM] Session restored — timer resumed with ${remaining}s remaining');
      debugPrint('');
    } catch (e, stack) {
      debugPrint('❌ [SB-VM] _restoreActiveSession error: $e');
      debugPrint('❌ [SB-VM] Stack: $stack');
      await _clearActiveSession();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COUNTDOWN TIMER
  // ═══════════════════════════════════════════════════════════════════════════
  void _startCountdownTimer() {
    _updateTimerDisplay();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        _updateTimerDisplay();
      } else {
        t.cancel();
        statusMessage.value = 'Break time expired!';
        endBreak();
      }
    });
  }

  void _updateTimerDisplay() {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds  % 60;
    timerDisplay.value = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final em = _elapsedSeconds ~/ 60;
    final es = _elapsedSeconds  % 60;
    elapsedDisplay.value =
    '${em.toString().padLeft(2, '0')}:${es.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GEO-FENCE WATCHER
  // ═══════════════════════════════════════════════════════════════════════════
  void _startGeofenceWatch() {
    debugPrint('🗺️ [SB-VM] Starting geo-fence watch '
        '(center=$_fenceLat,$_fenceLng  radius=$_fenceRadius m)');

    _geofenceTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!isOnShortBreak.value) return;
      final pos = await _getCurrentPosition();
      if (pos == null) return;

      final dist = _haversineDistance(
        pos.latitude, pos.longitude,
        _fenceLat, _fenceLng,
      );
      debugPrint('📍 [SB-VM] Distance from fence center: ${dist.toStringAsFixed(1)} m');

      if (dist <= _fenceRadius) {
        debugPrint('✅ [SB-VM] Employee inside geo-fence → auto-ending break');
        _geofenceTimer?.cancel();
        statusMessage.value = 'You have returned to your area. Ending break…';
        await endBreak();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION VALIDATION — checks if user is inside the assigned work location
  // Reads the location selected in LocationSelectionScreen (via SharedPrefs).
  // Supports both circle-radius and polygon geofences, mirroring the logic
  // in GeofenceViolationViewModel without touching any other module.
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> _isInsideAssignedLocation() async {
    try {
      // ── 1. Read the selected location from SharedPreferences ───────────────
      final prefs = await SharedPreferences.getInstance();

      final assignedLat    = prefs.getDouble('selected_lat');
      final assignedLng    = prefs.getDouble('selected_lng');
      final assignedRadius = prefs.getDouble('selected_radius');
      final shapeType      = prefs.getString('selected_shape_type');
      final shapeCoords    = prefs.getString('selected_shape_coords');
      final locationName   = prefs.getString('selected_location_name') ?? 'Work Location';

      debugPrint('');
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('📍 [SB-VM] _isInsideAssignedLocation() — break start check');
      debugPrint('📍 [SB-VM] assignedLat    = $assignedLat');
      debugPrint('📍 [SB-VM] assignedLng    = $assignedLng');
      debugPrint('📍 [SB-VM] assignedRadius = $assignedRadius m');
      debugPrint('📍 [SB-VM] shapeType      = "$shapeType"');
      debugPrint('📍 [SB-VM] locationName   = "$locationName"');

      // ── 2. If no location was ever selected, allow break (fail-open) ───────
      if (assignedLat == null || assignedLng == null ||
          assignedLat == 0.0  || assignedLng == 0.0) {
        debugPrint('⚠️  [SB-VM] No assigned location found in prefs — allowing break (fail-open)');
        debugPrint('════════════════════════════════════════════════════════');
        return true;
      }

      // ── 3. Get the current GPS position ────────────────────────────────────
      final pos = await _getCurrentPosition();
      if (pos == null) {
        debugPrint('⚠️  [SB-VM] Could not get GPS position — allowing break (fail-open)');
        debugPrint('════════════════════════════════════════════════════════');
        return true; // GPS unavailable → fail-open so break is not wrongly blocked
      }

      debugPrint('📍 [SB-VM] Current GPS: lat=${pos.latitude}  lng=${pos.longitude}  '
          'accuracy=${pos.accuracy.toStringAsFixed(1)} m');

      // ── 4. Shape-aware inside check ────────────────────────────────────────
      bool isInside;

      if (shapeType == 'polygon' &&
          shapeCoords != null &&
          shapeCoords.isNotEmpty) {
        // ── Polygon check (ray-casting) ─────────────────────────────────────
        final polygon = _parsePolygonCoordsForBreak(shapeCoords);
        if (polygon != null && polygon.isNotEmpty) {
          isInside = _isPointInPolygonForBreak(pos.latitude, pos.longitude, polygon);
          debugPrint('🔷 [SB-VM] Polygon check: inside=$isInside');
        } else {
          // Malformed polygon coords → fall back to radius
          final dist = Geolocator.distanceBetween(
              pos.latitude, pos.longitude, assignedLat, assignedLng);
          isInside = dist <= (assignedRadius ?? 100);
          debugPrint('📏 [SB-VM] Radius fallback (bad polygon): '
              'dist=${dist.toStringAsFixed(1)} m  radius=${assignedRadius ?? 100} m  inside=$isInside');
        }
      } else {
        // ── Circle-radius check ─────────────────────────────────────────────
        final dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, assignedLat, assignedLng);
        isInside = dist <= (assignedRadius ?? 100);
        debugPrint('📏 [SB-VM] Radius check: '
            'dist=${dist.toStringAsFixed(1)} m  radius=${assignedRadius ?? 100} m  inside=$isInside');
      }

      debugPrint('${isInside ? "✅" : "❌"} [SB-VM] Inside "$locationName" = $isInside');
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('');
      return isInside;
    } catch (e, stack) {
      debugPrint('❌ [SB-VM] _isInsideAssignedLocation error: $e');
      debugPrint('❌ [SB-VM] Stack: $stack');
      return true; // fail-open on unexpected errors
    }
  }

  /// Parses a shape_coords JSON string into a list of lat/lng maps.
  /// Format: {"coordinates":[{"lat":…,"lng":…},…]}
  List<Map<String, double>>? _parsePolygonCoordsForBreak(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final coords  = (decoded['coordinates'] as List<dynamic>)
          .map((c) => {
        'lat': double.parse(c['lat'].toString()),
        'lng': double.parse(c['lng'].toString()),
      })
          .toList();
      return coords;
    } catch (e) {
      debugPrint('⚠️ [SB-VM] _parsePolygonCoordsForBreak error: $e');
      return null;
    }
  }

  /// Ray-casting point-in-polygon check (convex & concave polygons).
  bool _isPointInPolygonForBreak(
      double lat, double lng, List<Map<String, double>> polygon) {
    final int n      = polygon.length;
    bool      inside = false;
    int       j      = n - 1;
    for (int i = 0; i < n; i++) {
      final double xi = polygon[i]['lat']!;
      final double yi = polygon[i]['lng']!;
      final double xj = polygon[j]['lat']!;
      final double yj = polygon[j]['lng']!;
      if (((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ [SB-VM] GPS error: $e');
      return null;
    }
  }

  Future<String?> _captureSelfie() async {
    try {
      // ── Step 1: Capture from front camera ─────────────────────────────────
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 100, // capture full quality — we compress manually below
        maxWidth: 1280,
      );
      if (photo == null) return null;

      final originalBytes = await File(photo.path).readAsBytes();
      debugPrint('📸 [SB-VM] Original size : ${(originalBytes.length / 1024).toStringAsFixed(1)} KB');

      // ── Step 2: Compress ───────────────────────────────────────────────────
      final compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth:  400,
        minHeight: 400,
        quality:   40,           // 0-100 — lower = smaller file
        format:    CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      final savedKB = ((originalBytes.length - compressed.length) / 1024).toStringAsFixed(1);
      debugPrint('📸 [SB-VM] Compressed to: ${(compressed.length / 1024).toStringAsFixed(1)} KB  (saved ${savedKB} KB)');

      return base64Encode(compressed);
    } catch (e) {
      debugPrint('⚠️ [SB-VM] Selfie capture error: $e');
      return null;
    }
  }

  Future<void> _persistUsedCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    debugPrint('💾 [SB-VM] Saving usedCounts for empId="$_empId" date="$today"');
    for (final p in breakPolicies) {
      final key = 'sb_cnt_${_empId}_${p.breakType}_$today';
      await prefs.setInt(key, p.usedCount);
      debugPrint('💾 [SB-VM]   "${p.breakType}" → key="$key" saved=${p.usedCount}');
    }
  }

  /// Haversine formula — returns distance in metres
  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Expose active break model for UI ──────────────────────────────────────
  ShortBreakModel? get activeBreakModel => _activeBreak;
}