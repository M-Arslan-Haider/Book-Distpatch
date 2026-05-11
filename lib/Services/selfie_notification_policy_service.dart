// // ============================================================
// //  selfie_notification_policy_service.dart
// //
// //  RESPONSIBILITIES:
// //    1. API se SELFIE_NOTIFICATION_POLICY data fetch karta hai
// //       (SHIFT_GRACE_TIME, SHIFT_NOTIF_COUNT)
// //    2. Shift-end ke baad grace window mein button enable karta hai
// //    3. SHIFT_NOTIF_COUNT notifications schedule karta hai —
// //       foreground, background, AND app-killed teeno cases mein
// //    4. Camera open karne ka method provide karta hai
// //    5. ✅ OFFLINE: Selfie locally save karta hai jab internet nahi
// //    6. ✅ OFFLINE: Internet aane par pending selfie auto-post karta hai
// //
// //  USAGE (home_screen.dart mein):
// //    initState:
// //      SelfieNotificationPolicyService.to.initialize(empId, companyCode);
// //    Widget:
// //      SelfieGraceButton()   ← bas yeh widget add karo
// //
// //  NOTE: pubspec.yaml mein ensure karo:
// //    flutter_local_notifications: ^17.x.x   (already present)
// //    timezone: ^0.9.x                        (add karo agar nahi hai)
// //    image_picker: ^1.x.x                    (already present)
// //    connectivity_plus: ^6.x.x               (already present)
// //    path_provider: ^2.x.x                   (already present)
// // ============================================================
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';                                    // ✅ OFFLINE: File I/O
// import 'dart:typed_data';
//
// import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ OFFLINE: Connectivity check
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';   // ✅ OFFLINE: Local path
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:timezone/data/latest_all.dart' as tzData;
// import 'package:timezone/timezone.dart' as tz;
//
// // ─────────────────────────────────────────────────────────────────────────────
// // MODEL
// // ─────────────────────────────────────────────────────────────────────────────
//
// class SelfiePolicy {
//   final int    id;
//   final String empId;
//   final String empName;
//   final int    shiftGraceMinutes; // parsed from SHIFT_GRACE_TIME
//   final int    shiftNotifCount;
//   final String companyCode;
//
//   const SelfiePolicy({
//     required this.id,
//     required this.empId,
//     required this.empName,
//     required this.shiftGraceMinutes,
//     required this.shiftNotifCount,
//     required this.companyCode,
//   });
//
//   @override
//   String toString() =>
//       'SelfiePolicy(id=$id empId=$empId grace=${shiftGraceMinutes}min notifCount=$shiftNotifCount)';
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // SERVICE
// // ─────────────────────────────────────────────────────────────────────────────
//
// class SelfieNotificationPolicyService extends GetxService {
//   // ── Singleton accessor ────────────────────────────────────────────────────
//   static SelfieNotificationPolicyService get to =>
//       Get.find<SelfieNotificationPolicyService>();
//
//   // ── Tag for debug logs ────────────────────────────────────────────────────
//   static const String _TAG = 'SelfiePolicy';
//
//   // ── API endpoint ──────────────────────────────────────────────────────────
//   static const String _API_URL =
//       'http://oracle.metaxperts.net/ords/gps_workforce/auto_clockout_notification/get/';
//
//   // ── Selfie POST API endpoint ───────────────────────────────────────────────
//   static const String _SELFIE_POST_URL =
//       'http://oracle.metaxperts.net/ords/gps_workforce/selfiepost/post/';
//
//   // ── Notification channel constants ────────────────────────────────────────
//   static const String _CHANNEL_ID   = 'selfie_grace_notif_channel';
//   static const String _CHANNEL_NAME = 'Selfie Grace Notifications';
//   static const int    _NOTIF_BASE_ID = 7000; // avoids collision with existing notif IDs
//
//   // ── SharedPreferences keys (prefixed flutter. per project convention) ──────
//   static const String _KEY_GRACE_END_MS    = 'flutter.selfie_grace_end_ms';
//   static const String _KEY_TOTAL_NOTIFS    = 'flutter.selfie_total_notifs';
//   static const String _KEY_SENT_NOTIFS     = 'flutter.selfie_notifs_sent';
//   static const String _KEY_GRACE_ACTIVE    = 'flutter.selfie_grace_active';
//   static const String _KEY_SELFIE_DONE     = 'flutter.selfie_done'; // ✅ selfie le li gayi
//
//   // ── Policy category live-update keys (stored in SharedPrefs) ─────────────
//   static const String _KEY_POLICY_GRACE_MIN  = 'flutter.selfie_policy_grace_min';
//   static const String _KEY_POLICY_NOTIF_COUNT= 'flutter.selfie_policy_notif_count';
//   static const String _KEY_POLICY_EMP_ID     = 'flutter.selfie_policy_emp_id';
//   static const String _KEY_POLICY_COMPANY    = 'flutter.selfie_policy_company';
//
//   // ── ✅ OFFLINE: Pending selfie keys ───────────────────────────────────────
//   static const String _KEY_SELFIE_PENDING      = 'flutter.selfie_pending';       // bool
//   static const String _KEY_SELFIE_PENDING_PATH = 'flutter.selfie_pending_path';  // local file path
//   static const String _KEY_SELFIE_PENDING_META = 'flutter.selfie_pending_meta';  // JSON metadata
//
//   // ── Observable state (consumed by SelfieGraceButton widget) ──────────────
//   final RxBool isButtonEnabled  = false.obs;
//   final RxInt  graceSecondsLeft = 0.obs;
//   final RxBool isFetching       = false.obs;
//
//   // ── Internals ─────────────────────────────────────────────────────────────
//   late final FlutterLocalNotificationsPlugin _notifPlugin;
//   Timer?      _countdownTimer;
//   Timer?      _policyRefreshTimer;          // ✅ ~1 min live policy refresh
//   String      _lastEmpId      = '';
//   String      _lastCompanyCode= '';
//   int         _notifIdCounter = _NOTIF_BASE_ID;
//
//   // ── ✅ OFFLINE: Connectivity ───────────────────────────────────────────────
//   final Connectivity _connectivity = Connectivity();
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//   bool _isOnline = false;
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LIFECYCLE
//   // ══════════════════════════════════════════════════════════════════════════
//
//   @override
//   Future<void> onInit() async {
//     super.onInit();
//     await _setupNotifications();
//     await _restoreGraceState();
//
//     // ── ✅ OFFLINE: Initial connectivity check ─────────────────────────────
//     try {
//       final results = await _connectivity.checkConnectivity();
//       _isOnline = results.any((r) => r != ConnectivityResult.none);
//       debugPrint('🌐 [$_TAG] Initial connectivity: ${_isOnline ? "ONLINE" : "OFFLINE"}');
//     } catch (_) {}
//
//     // ── ✅ OFFLINE: Listen for connectivity changes ────────────────────────
//     _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
//       final bool wasOnline = _isOnline;
//       _isOnline = results.any((r) => r != ConnectivityResult.none);
//       debugPrint('🌐 [$_TAG] Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
//
//       if (_isOnline && !wasOnline) {
//         debugPrint('🔄 [$_TAG] Internet restored — syncing pending selfie...');
//         _syncPendingSelfie();
//
//         // Also refresh policy data when connectivity restores
//         if (_lastEmpId.isNotEmpty && _lastCompanyCode.isNotEmpty) {
//           _fetchAndStorePolicyCategory(_lastEmpId, _lastCompanyCode);
//         }
//       }
//     });
//
//     // ── ✅ OFFLINE: Sync any pending selfie on startup (if online) ─────────
//     _syncPendingSelfie();
//
//     debugPrint('✅ [$_TAG] Service ready');
//   }
//
//   @override
//   void onClose() {
//     _countdownTimer?.cancel();
//     _policyRefreshTimer?.cancel();
//     _connectivitySubscription?.cancel();  // ✅ OFFLINE: Cancel connectivity listener
//     super.onClose();
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // PUBLIC: called from HomeScreen.initState  (or after _loadUserData)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   /// Main entry point — fetch policy then activate grace window if applicable.
//   Future<void> initialize(String empId, String companyCode) async {
//     debugPrint('🚀 [$_TAG] initialize(empId=$empId companyCode=$companyCode)');
//     _lastEmpId       = empId;
//     _lastCompanyCode = companyCode;
//     await fetchPolicy(empId, companyCode);
//     _startPolicyRefreshTimer();
//   }
//
//   // ── Policy category live refresh (every ~1 minute) ────────────────────────
//   void _startPolicyRefreshTimer() {
//     _policyRefreshTimer?.cancel();
//     _policyRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
//       if (_lastEmpId.isEmpty || _lastCompanyCode.isEmpty) return;
//       debugPrint('🔄 [$_TAG] [POLICY REFRESH] Fetching live policy at ${DateTime.now()}');
//       await _fetchAndStorePolicyCategory(_lastEmpId, _lastCompanyCode);
//     });
//     debugPrint('✅ [$_TAG] Policy refresh timer started (every 60s)');
//   }
//
//   /// Fetches only the policy category fields and stores them in SharedPrefs.
//   /// Does NOT re-activate the grace window — that is handled separately.
//   /// ✅ OFFLINE: If offline, uses cached policy from SharedPrefs silently.
//   Future<void> _fetchAndStorePolicyCategory(String empId, String companyCode) async {
//     // ── ✅ OFFLINE: Skip API call if offline, use cached values ──────────
//     if (!_isOnline) {
//       debugPrint('📴 [$_TAG] [POLICY REFRESH] Offline — using cached policy');
//       return;
//     }
//
//     try {
//       final Uri uri = Uri.parse(_API_URL).replace(queryParameters: {
//         'emp_id'      : empId,
//         'company_code': companyCode,
//       });
//       debugPrint('🌐 [$_TAG] [POLICY REFRESH] GET $uri');
//
//       final response = await http
//           .get(uri, headers: {'Accept': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('📥 [$_TAG] [POLICY REFRESH] Status=${response.statusCode}  Body=${response.body}');
//
//       if (response.statusCode < 200 || response.statusCode >= 300) {
//         debugPrint('❌ [$_TAG] [POLICY REFRESH] Non-2xx — skip');
//         return;
//       }
//
//       final dynamic decoded = jsonDecode(response.body);
//       Map<String, dynamic>? row;
//       if (decoded is Map<String, dynamic>) {
//         final List? items = decoded['items'] as List?;
//         if (items != null && items.isNotEmpty) {
//           row = items.first as Map<String, dynamic>;
//         } else if (decoded.containsKey('SHIFT_GRACE_TIME') ||
//             decoded.containsKey('shift_grace_time')) {
//           row = decoded;
//         }
//       } else if (decoded is List && decoded.isNotEmpty) {
//         row = decoded.first as Map<String, dynamic>;
//       }
//
//       if (row == null) {
//         debugPrint('⚠️ [$_TAG] [POLICY REFRESH] No row found');
//         return;
//       }
//
//       final String graceRaw  = _pickField(row, ['shift_grace_time', 'SHIFT_GRACE_TIME']) ?? '0';
//       final String notifRaw  = _pickField(row, ['shift_notif_count', 'SHIFT_NOTIF_COUNT']) ?? '0';
//       final int graceMinutes = _parseGraceTimeToMinutes(graceRaw);
//       final int notifCount   = int.tryParse(notifRaw.trim()) ?? 0;
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setInt(_KEY_POLICY_GRACE_MIN,   graceMinutes);
//       await prefs.setInt(_KEY_POLICY_NOTIF_COUNT, notifCount);
//       await prefs.setString(_KEY_POLICY_EMP_ID,   empId);
//       await prefs.setString(_KEY_POLICY_COMPANY,  companyCode);
//
//       debugPrint('✅ [$_TAG] [POLICY REFRESH] Stored → graceMin=$graceMinutes  notifCount=$notifCount');
//     } catch (e) {
//       debugPrint('❌ [$_TAG] [POLICY REFRESH] Error: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // NOTIFICATION SETUP
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _setupNotifications() async {
//     _notifPlugin = FlutterLocalNotificationsPlugin();
//
//     const AndroidInitializationSettings androidInit =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//     const DarwinInitializationSettings iosInit =
//     DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//     const InitializationSettings initSettings =
//     InitializationSettings(android: androidInit, iOS: iosInit);
//
//     await _notifPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (res) =>
//           debugPrint('📲 [$_TAG] Notification tapped: ${res.payload}'),
//     );
//
//     // Create dedicated notification channel
//     await _notifPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(
//       const AndroidNotificationChannel(
//         _CHANNEL_ID,
//         _CHANNEL_NAME,
//         description: 'Reminders to take attendance selfie during grace period',
//         importance: Importance.high,
//         enableVibration: true,
//         playSound: true,
//       ),
//     );
//
//     // Initialize timezone (needed for zonedSchedule — works even when app killed)
//     try {
//       tzData.initializeTimeZones();
//       debugPrint('✅ [$_TAG] Timezone initialized (${tz.local.name})');
//     } catch (e) {
//       debugPrint('⚠️ [$_TAG] Timezone init failed: $e — will use timer-only fallback');
//     }
//
//     debugPrint('✅ [$_TAG] Notifications channel ready: $_CHANNEL_ID');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // API CALL  (with full debug logs as requested)
//   // ✅ OFFLINE: Uses cached policy when offline
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> fetchPolicy(String empId, String companyCode) async {
//     if (empId.isEmpty || companyCode.isEmpty) {
//       debugPrint('⚠️ [$_TAG] fetchPolicy: empId or companyCode empty — skip');
//       return;
//     }
//
//     isFetching.value = true;
//
//     try {
//       // ── ✅ OFFLINE: If no internet, use cached policy to activate grace ─
//       if (!_isOnline) {
//         debugPrint('📴 [$_TAG] fetchPolicy: OFFLINE — trying cached policy');
//         await _activateGraceWindowFromCache(empId, companyCode);
//         return;
//       }
//
//       final Uri uri = Uri.parse(_API_URL).replace(
//         queryParameters: {
//           'emp_id'      : empId,
//           'company_code': companyCode,
//         },
//       );
//
//       debugPrint('🌐 [$_TAG] ── API REQUEST ──────────────────────────────');
//       debugPrint('🌐 [$_TAG] GET  $uri');
//       debugPrint('🌐 [$_TAG] ─────────────────────────────────────────────');
//
//       final response = await http
//           .get(uri, headers: {'Accept': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('📥 [$_TAG] ── API RESPONSE ─────────────────────────────');
//       debugPrint('📥 [$_TAG] Status : ${response.statusCode}');
//       debugPrint('📥 [$_TAG] Body   : ${response.body}');
//       debugPrint('📥 [$_TAG] ─────────────────────────────────────────────');
//
//       if (response.statusCode < 200 || response.statusCode >= 300) {
//         debugPrint('❌ [$_TAG] Non-2xx response — aborting');
//         return;
//       }
//
//       final dynamic decoded = jsonDecode(response.body);
//
//       // ── Parse response (handles: flat map, {items:[]}, bare list) ─────────
//       Map<String, dynamic>? row;
//
//       if (decoded is Map<String, dynamic>) {
//         final List? items = decoded['items'] as List?;
//         if (items != null && items.isNotEmpty) {
//           row = items.first as Map<String, dynamic>;
//           debugPrint('📦 [$_TAG] Found row in items[]');
//         } else if (decoded.containsKey('SHIFT_GRACE_TIME') ||
//             decoded.containsKey('shift_grace_time')) {
//           row = decoded;
//           debugPrint('📦 [$_TAG] Found row as flat map');
//         }
//       } else if (decoded is List && decoded.isNotEmpty) {
//         row = decoded.first as Map<String, dynamic>;
//         debugPrint('📦 [$_TAG] Found row as bare array[0]');
//       }
//
//       if (row == null) {
//         debugPrint('⚠️ [$_TAG] No policy row found in response');
//         return;
//       }
//
//       // ── Extract fields (case-insensitive) ─────────────────────────────────
//       final String graceRaw    = _pickField(row, ['shift_grace_time', 'SHIFT_GRACE_TIME']) ?? '0';
//       final String notifRaw    = _pickField(row, ['shift_notif_count', 'SHIFT_NOTIF_COUNT']) ?? '0';
//       final String idRaw       = _pickField(row, ['id', 'ID']) ?? '0';
//       final String empNameRaw  = _pickField(row, ['emp_name', 'EMP_NAME']) ?? '';
//       final String companyRaw  = _pickField(row, ['company_code', 'COMPANY_CODE']) ?? companyCode;
//
//       final int graceMinutes = _parseGraceTimeToMinutes(graceRaw);
//       final int notifCount   = int.tryParse(notifRaw.trim()) ?? 0;
//       final int policyId     = int.tryParse(idRaw.trim()) ?? 0;
//
//       final policy = SelfiePolicy(
//         id                : policyId,
//         empId             : empId,
//         empName           : empNameRaw,
//         shiftGraceMinutes : graceMinutes,
//         shiftNotifCount   : notifCount,
//         companyCode       : companyRaw,
//       );
//
//       debugPrint('📋 [$_TAG] Policy parsed: $policy');
//       debugPrint('📋 [$_TAG]   graceRaw="$graceRaw"  → ${graceMinutes}min');
//       debugPrint('📋 [$_TAG]   notifRaw="$notifRaw"  → $notifCount notifications');
//
//       // ── ✅ OFFLINE: Cache policy values for offline use ─────────────────
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setInt(_KEY_POLICY_GRACE_MIN,   graceMinutes);
//       await prefs.setInt(_KEY_POLICY_NOTIF_COUNT, notifCount);
//       await prefs.setString(_KEY_POLICY_EMP_ID,   empId);
//       await prefs.setString(_KEY_POLICY_COMPANY,  companyCode);
//
//       if (graceMinutes <= 0 || notifCount <= 0) {
//         debugPrint('⚠️ [$_TAG] graceMinutes=$graceMinutes notifCount=$notifCount — nothing to schedule');
//         return;
//       }
//
//       await _activateGraceWindow(policy);
//     } catch (e) {
//       debugPrint('❌ [$_TAG] fetchPolicy error: $e');
//       // ── ✅ OFFLINE: On network error, fall back to cached policy ─────────
//       debugPrint('📴 [$_TAG] Falling back to cached policy after error');
//       await _activateGraceWindowFromCache(empId, companyCode);
//     } finally {
//       isFetching.value = false;
//     }
//   }
//
//   // ── ✅ OFFLINE: Activate grace window using cached policy from SharedPrefs ─
//   Future<void> _activateGraceWindowFromCache(String empId, String companyCode) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final int graceMinutes = prefs.getInt(_KEY_POLICY_GRACE_MIN) ?? 0;
//       final int notifCount   = prefs.getInt(_KEY_POLICY_NOTIF_COUNT) ?? 0;
//
//       if (graceMinutes <= 0 || notifCount <= 0) {
//         debugPrint('📴 [$_TAG] [CACHE] No cached policy — cannot activate grace window offline');
//         return;
//       }
//
//       debugPrint('📴 [$_TAG] [CACHE] Using cached policy: graceMin=$graceMinutes  notifCount=$notifCount');
//
//       final policy = SelfiePolicy(
//         id                : 0,
//         empId             : empId,
//         empName           : '',
//         shiftGraceMinutes : graceMinutes,
//         shiftNotifCount   : notifCount,
//         companyCode       : companyCode,
//       );
//
//       await _activateGraceWindow(policy);
//     } catch (e) {
//       debugPrint('❌ [$_TAG] [CACHE] _activateGraceWindowFromCache error: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // GRACE WINDOW ACTIVATION
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _activateGraceWindow(SelfiePolicy policy) async {
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('🪟 [$_TAG] [GRACE WINDOW] ===== _activateGraceWindow =====');
//     debugPrint('🪟 [$_TAG] Policy: graceMin=${policy.shiftGraceMinutes}  notifCount=${policy.shiftNotifCount}');
//
//     final prefs = await SharedPreferences.getInstance();
//
//     // ✅ Selfie already le li — grace window dobara activate mat karo
//     final bool selfieDone = prefs.getBool(_KEY_SELFIE_DONE) ?? false;
//     debugPrint('🪟 [$_TAG] selfie_done flag = $selfieDone');
//     if (selfieDone) {
//       debugPrint('ℹ️ [$_TAG] [GRACE WINDOW] Selfie already taken — skipping. '
//           'To reset: call resetSelfieDoneFlag() on next clock-in.');
//       debugPrint('══════════════════════════════════════════════════════');
//       return;
//     }
//
//     // Get shift end time
//     final String? endTimeStr = prefs.getString('cached_end_time');
//     debugPrint('⏰ [$_TAG] [GRACE WINDOW] cached_end_time = "$endTimeStr"');
//
//     final DateTime? shiftEnd = _parseTimeToToday(endTimeStr);
//     final DateTime  now      = DateTime.now();
//
//     debugPrint('⏰ [$_TAG] [GRACE WINDOW] shiftEnd (parsed) = $shiftEnd');
//     debugPrint('⏰ [$_TAG] [GRACE WINDOW] now               = $now');
//
//     if (policy.shiftGraceMinutes <= 0) {
//       debugPrint('❌ [$_TAG] [GRACE WINDOW] graceMinutes = ${policy.shiftGraceMinutes} — nothing to do. '
//           'Check SHIFT_GRACE_TIME in the policy API response.');
//       debugPrint('══════════════════════════════════════════════════════');
//       return;
//     }
//     if (policy.shiftNotifCount <= 0) {
//       debugPrint('❌ [$_TAG] [GRACE WINDOW] notifCount = ${policy.shiftNotifCount} — nothing to do. '
//           'Check SHIFT_NOTIF_COUNT in the policy API response.');
//       debugPrint('══════════════════════════════════════════════════════');
//       return;
//     }
//
//     // ✅ SHIFT END GUARD
//     if (shiftEnd != null && now.isBefore(shiftEnd)) {
//       final Duration untilShiftEnd = shiftEnd.difference(now);
//       debugPrint('⏳ [$_TAG] [GRACE WINDOW] Shift NOT ended yet.');
//       debugPrint('⏳ [$_TAG]   Shift ends in: ${untilShiftEnd.inMinutes}min ${untilShiftEnd.inSeconds % 60}s');
//       debugPrint('⏳ [$_TAG]   Button will appear at: $shiftEnd');
//       debugPrint('⏳ [$_TAG]   Scheduling internal Timer to fire at shift end...');
//       Timer(untilShiftEnd, () async {
//         debugPrint('✅ [$_TAG] [GRACE WINDOW] Timer fired — shift end reached at ${DateTime.now()}. Activating now.');
//         final refreshedPrefs = await SharedPreferences.getInstance();
//         final DateTime graceStart = shiftEnd;
//         final DateTime graceEnd   = graceStart.add(Duration(minutes: policy.shiftGraceMinutes));
//         debugPrint('⏰ [$_TAG] [GRACE WINDOW] graceStart=$graceStart  graceEnd=$graceEnd');
//         await refreshedPrefs.setInt(_KEY_GRACE_END_MS, graceEnd.millisecondsSinceEpoch);
//         await refreshedPrefs.setInt(_KEY_TOTAL_NOTIFS,  policy.shiftNotifCount);
//         await refreshedPrefs.setInt(_KEY_SENT_NOTIFS,   0);
//         await refreshedPrefs.setBool(_KEY_GRACE_ACTIVE, true);
//         _enableButtonWithCountdown(graceEnd, refreshedPrefs);
//         _scheduleNotifications(graceStart, graceEnd, policy.shiftNotifCount, refreshedPrefs, sentAlready: 0);
//       });
//       debugPrint('══════════════════════════════════════════════════════');
//       return;
//     }
//
//     // Shift already ended
//     final DateTime graceBase = shiftEnd ?? now;
//     final DateTime graceEnd  = graceBase.add(Duration(minutes: policy.shiftGraceMinutes));
//
//     debugPrint('⏰ [$_TAG] [GRACE WINDOW] Shift already ended.');
//     debugPrint('⏰ [$_TAG]   graceBase = $graceBase');
//     debugPrint('⏰ [$_TAG]   graceEnd  = $graceEnd  (grace = ${policy.shiftGraceMinutes}min)');
//     debugPrint('⏰ [$_TAG]   now       = $now');
//
//     if (now.isAfter(graceEnd)) {
//       debugPrint('❌ [$_TAG] [GRACE WINDOW] Grace window ALREADY EXPIRED.');
//       debugPrint('❌ [$_TAG]   graceEnd was: $graceEnd');
//       debugPrint('❌ [$_TAG]   now is      : $now');
//       debugPrint('❌ [$_TAG]   Expired ${now.difference(graceEnd).inMinutes}min ago.');
//       debugPrint('❌ [$_TAG]   Button will NOT appear. Increase SHIFT_GRACE_TIME or initialize earlier.');
//       debugPrint('══════════════════════════════════════════════════════');
//       return;
//     }
//
//     final int remainingSec = graceEnd.difference(now).inSeconds;
//     debugPrint('✅ [$_TAG] [GRACE WINDOW] Grace window ACTIVE — ${remainingSec}s remaining');
//
//     await prefs.setInt(_KEY_GRACE_END_MS, graceEnd.millisecondsSinceEpoch);
//     await prefs.setInt(_KEY_TOTAL_NOTIFS,  policy.shiftNotifCount);
//     await prefs.setInt(_KEY_SENT_NOTIFS,   0);
//     await prefs.setBool(_KEY_GRACE_ACTIVE, true);
//
//     debugPrint('✅ [$_TAG] [GRACE WINDOW] Prefs saved. Enabling button now...');
//
//     final int alreadyElapsedSec = now.difference(graceBase).inSeconds;
//     _enableButtonWithCountdown(graceEnd, prefs);
//
//     final int totalNotifs  = policy.shiftNotifCount;
//     final int totalSecs    = graceEnd.difference(graceBase).inSeconds;
//     final int interval     = totalSecs ~/ totalNotifs;
//     final int sentAlready  = (alreadyElapsedSec ~/ interval).clamp(0, totalNotifs);
//     debugPrint('📲 [$_TAG] [GRACE WINDOW] Scheduling notifications: sentAlready=$sentAlready/$totalNotifs');
//     await prefs.setInt(_KEY_SENT_NOTIFS, sentAlready);
//     _scheduleNotifications(graceBase, graceEnd, totalNotifs, prefs, sentAlready: sentAlready);
//
//     debugPrint('✅ [$_TAG] [GRACE WINDOW] ===== COMPLETE =====');
//     debugPrint('══════════════════════════════════════════════════════');
//   }
//
//   // ── Enable button + start second-by-second countdown ─────────────────────
//
//   void _enableButtonWithCountdown(DateTime graceEnd, SharedPreferences prefs) {
//     debugPrint('');
//     debugPrint('🟢 [$_TAG] [BUTTON] _enableButtonWithCountdown called');
//     debugPrint('🟢 [$_TAG] [BUTTON] graceEnd = $graceEnd');
//     debugPrint('🟢 [$_TAG] [BUTTON] isButtonEnabled BEFORE = ${isButtonEnabled.value}');
//
//     isButtonEnabled.value  = true;
//     graceSecondsLeft.value = graceEnd.difference(DateTime.now()).inSeconds.clamp(0, 999999);
//
//     debugPrint('🟢 [$_TAG] [BUTTON] isButtonEnabled SET TO = ${isButtonEnabled.value}');
//     debugPrint('🟢 [$_TAG] [BUTTON] graceSecondsLeft = ${graceSecondsLeft.value}s');
//     debugPrint('🟢 [$_TAG] [BUTTON] Starting countdown timer...');
//
//     _countdownTimer?.cancel();
//     _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       final rem = graceEnd.difference(DateTime.now()).inSeconds;
//       if (rem <= 0) {
//         graceSecondsLeft.value = 0;
//         isButtonEnabled.value  = false;
//         t.cancel();
//         _clearSavedState(prefs);
//         debugPrint('⏰ [$_TAG] [BUTTON] Grace window expired — button DISABLED');
//       } else {
//         graceSecondsLeft.value = rem;
//       }
//     });
//     debugPrint('🟢 [$_TAG] [BUTTON] Countdown timer started ✅');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // NOTIFICATION SCHEDULING
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _scheduleNotifications(
//       DateTime graceStart,
//       DateTime graceEnd,
//       int count,
//       SharedPreferences prefs, {
//         required int sentAlready,
//       }) {
//     if (count <= 0) return;
//
//     final int totalMs   = graceEnd.difference(graceStart).inMilliseconds;
//     final int intervalMs = (totalMs / count).round();
//     final DateTime now   = DateTime.now();
//
//     debugPrint('📲 [$_TAG] Scheduling ${count - sentAlready} notifications '
//         '(interval=${intervalMs ~/ 1000}s, sentAlready=$sentAlready/$count)');
//
//     for (int i = sentAlready; i < count; i++) {
//       final DateTime fireAt = graceStart.add(Duration(milliseconds: intervalMs * (i + 1)));
//       final int     seqNum  = i + 1;
//
//       if (fireAt.isAfter(graceEnd)) {
//         debugPrint('📲 [$_TAG] Notif $seqNum would exceed graceEnd — skip');
//         break;
//       }
//
//       final int remaining = count - seqNum;
//       final String title  = 'Attendance Selfie';
//       final String body   = 'Your shift has ended. Please take your selfie.';
//
//       final Duration delay = fireAt.difference(now);
//
//       if (delay.isNegative || delay.inSeconds < 2) {
//         debugPrint('📲 [$_TAG] Notif $seqNum/$count: firing immediately (past $fireAt)');
//         _showNotification(_notifIdCounter++, title, body, seqNum, count, prefs);
//       } else {
//         debugPrint('📲 [$_TAG] Notif $seqNum/$count: in ${delay.inSeconds}s at $fireAt');
//
//         final int timerNotifId  = _notifIdCounter++;
//         final int zonedNotifId  = _notifIdCounter++;
//
//         Timer(delay, () {
//           _showNotification(timerNotifId, title, body, seqNum, count, prefs);
//         });
//
//         _scheduleZoned(
//           id     : zonedNotifId,
//           at     : fireAt,
//           title  : title,
//           body   : body,
//           seqNum : seqNum,
//           total  : count,
//         );
//       }
//     }
//   }
//
//   Future<void> _showNotification(
//       int id,
//       String title,
//       String body,
//       int seqNum,
//       int total,
//       SharedPreferences prefs,
//       ) async {
//     debugPrint('🔔 [$_TAG] Showing notification $seqNum/$total  id=$id');
//     try {
//       await _notifPlugin.show(
//         id,
//         title,
//         body,
//         const NotificationDetails(
//           android: AndroidNotificationDetails(
//             _CHANNEL_ID,
//             _CHANNEL_NAME,
//             channelDescription : 'Selfie attendance grace period reminder',
//             importance         : Importance.high,
//             priority           : Priority.high,
//             enableVibration    : true,
//             autoCancel         : true,
//             category           : AndroidNotificationCategory.reminder,
//           ),
//           iOS: DarwinNotificationDetails(
//             presentAlert : true,
//             presentBadge : true,
//             presentSound : true,
//             interruptionLevel: InterruptionLevel.timeSensitive,
//           ),
//         ),
//         payload: 'selfie_grace_$seqNum',
//       );
//
//       final int newSent = (prefs.getInt(_KEY_SENT_NOTIFS) ?? 0) + 1;
//       await prefs.setInt(_KEY_SENT_NOTIFS, newSent);
//       debugPrint('✅ [$_TAG] Notification sent: $newSent/$total');
//     } catch (e) {
//       debugPrint('❌ [$_TAG] _showNotification error: $e');
//     }
//   }
//
//   void _scheduleZoned(
//       {required int id,
//         required DateTime at,
//         required String title,
//         required String body,
//         required int seqNum,
//         required int total}) {
//     try {
//       final tz.TZDateTime tzAt = tz.TZDateTime.from(at, tz.local);
//       _notifPlugin.zonedSchedule(
//         id,
//         title,
//         body,
//         tzAt,
//         const NotificationDetails(
//           android: AndroidNotificationDetails(
//             _CHANNEL_ID,
//             _CHANNEL_NAME,
//             importance     : Importance.high,
//             priority       : Priority.high,
//             enableVibration: true,
//             autoCancel     : true,
//             category       : AndroidNotificationCategory.reminder,
//           ),
//           iOS: DarwinNotificationDetails(
//             presentAlert   : true,
//             presentSound   : true,
//             interruptionLevel: InterruptionLevel.timeSensitive,
//           ),
//         ),
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//         uiLocalNotificationDateInterpretation:
//         UILocalNotificationDateInterpretation.absoluteTime,
//         payload: 'selfie_grace_zoned_$seqNum',
//       ).then((_) {
//         debugPrint(
//             '📲 [$_TAG] zonedSchedule OK: id=$id at=$at notif=$seqNum/$total');
//       }).catchError((e) {
//         debugPrint('⚠️ [$_TAG] zonedSchedule failed: $e (timer fallback covers it)');
//       });
//     } catch (e) {
//       debugPrint('⚠️ [$_TAG] _scheduleZoned setup error: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // STATE RESTORATION
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _restoreGraceState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//
//       if (prefs.getBool(_KEY_SELFIE_DONE) ?? false) {
//         debugPrint('ℹ️ [$_TAG] Selfie already taken — button stays hidden');
//         return;
//       }
//
//       if (!(prefs.getBool(_KEY_GRACE_ACTIVE) ?? false)) {
//         debugPrint('ℹ️ [$_TAG] No saved grace state to restore');
//         return;
//       }
//
//       final int?  graceEndMs  = prefs.getInt(_KEY_GRACE_END_MS);
//       final int?  totalNotifs = prefs.getInt(_KEY_TOTAL_NOTIFS);
//       final int   sentNotifs  = prefs.getInt(_KEY_SENT_NOTIFS) ?? 0;
//
//       if (graceEndMs == null || totalNotifs == null) {
//         debugPrint('⚠️ [$_TAG] Incomplete saved state — clearing');
//         await _clearSavedState(prefs);
//         return;
//       }
//
//       final DateTime graceEnd = DateTime.fromMillisecondsSinceEpoch(graceEndMs);
//       final DateTime now      = DateTime.now();
//
//       if (now.isAfter(graceEnd)) {
//         debugPrint('⚠️ [$_TAG] Restored grace period already expired — clearing');
//         await _clearSavedState(prefs);
//         return;
//       }
//
//       final int remainSec = graceEnd.difference(now).inSeconds;
//       debugPrint('✅ [$_TAG] Restored grace period: ${remainSec}s left '
//           '| sent=$sentNotifs/$totalNotifs');
//
//       _enableButtonWithCountdown(graceEnd, prefs);
//
//       final int missed = totalNotifs - sentNotifs;
//       if (missed > 0) {
//         debugPrint('📲 [$_TAG] Sending $missed missed notifications on restore');
//         for (int i = 0; i < missed; i++) {
//           await Future.delayed(Duration(seconds: i));
//           await _showNotification(
//             _notifIdCounter++,
//             'Attendance Selfie',
//             'Your shift has ended. Please take your selfie.',
//             sentNotifs + i + 1,
//             totalNotifs,
//             prefs,
//           );
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ [$_TAG] _restoreGraceState error: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // ✅ OFFLINE: CONNECTIVITY HELPER
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _checkCurrentConnectivity() async {
//     try {
//       final results = await _connectivity.checkConnectivity();
//       return results.any((r) => r != ConnectivityResult.none);
//     } catch (_) {
//       return false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // ✅ OFFLINE: SAVE SELFIE LOCALLY
//   // Selfie image ko app ke documents folder mein save karta hai.
//   // Metadata (emp_id, company_code, lat, lng, etc.) SharedPrefs mein store.
//   // Returns true if save successful, false otherwise.
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _saveSelfieLocally(Uint8List imageBytes) async {
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== START =====');
//
//     try {
//       // ── Get local storage directory ───────────────────────────────────────
//       final Directory appDir = await getApplicationDocumentsDirectory();
//       final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
//       final String fileName  = 'selfie_pending_$timestamp.jpg';
//       final String filePath  = '${appDir.path}/$fileName';
//
//       // ── Write image bytes to file ─────────────────────────────────────────
//       final File imageFile = File(filePath);
//       await imageFile.writeAsBytes(imageBytes, flush: true);
//       debugPrint('💾 [$_TAG] [LOCAL SAVE] Image written: $filePath (${imageBytes.length} bytes)');
//
//       // ── Read SharedPreferences for metadata ───────────────────────────────
//       final prefs = await SharedPreferences.getInstance();
//
//       // emp_id
//       String empId = '';
//       for (final k in ['emp_id', 'userId', 'user_id', 'empId', 'EMP_ID']) {
//         final v = prefs.get(k);
//         if (v != null && v.toString().trim().isNotEmpty) {
//           empId = v.toString().trim();
//           break;
//         }
//       }
//
//       // emp_name
//       String empName = 'Unknown';
//       for (final k in ['emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name']) {
//         final v = prefs.get(k);
//         if (v != null && v.toString().trim().isNotEmpty) {
//           empName = v.toString().trim();
//           break;
//         }
//       }
//
//       // company_code
//       String companyCode = '';
//       for (final k in ['company_code', 'companyCode', 'COMPANY_CODE', 'comp_code']) {
//         final v = prefs.get(k);
//         if (v != null && v.toString().trim().isNotEmpty) {
//           companyCode = v.toString().trim();
//           break;
//         }
//       }
//
//       // attendance_out_id
//       final String attendanceOutId = (prefs.get('attendanceId') ?? '').toString().trim();
//
//       // captured_at timestamp
//       final String capturedAt = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
//
//       // GPS — best effort (short timeout to not block UI)
//       double lat = 0.0;
//       double lng = 0.0;
//       try {
//         final LocationPermission perm = await Geolocator.checkPermission();
//         if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
//           final bool serviceOn = await Geolocator.isLocationServiceEnabled();
//           if (serviceOn) {
//             final Position pos = await Geolocator.getCurrentPosition(
//               desiredAccuracy: LocationAccuracy.medium,
//             ).timeout(const Duration(seconds: 5));
//             lat = pos.latitude;
//             lng = pos.longitude;
//             debugPrint('💾 [$_TAG] [LOCAL SAVE] GPS: lat=$lat  lng=$lng');
//           }
//         }
//       } catch (locErr) {
//         debugPrint('⚠️ [$_TAG] [LOCAL SAVE] GPS unavailable: $locErr — saving with lat=0 lng=0');
//       }
//
//       // ── Build metadata map ────────────────────────────────────────────────
//       final Map<String, dynamic> meta = {
//         'emp_id'           : empId,
//         'emp_name'         : empName,
//         'company_code'     : companyCode,
//         'latitude'         : lat,
//         'longitude'        : lng,
//         'captured_at'      : capturedAt,
//         'created_at'       : capturedAt,
//         'attendance_out_id': attendanceOutId,
//         'image_mime_type'  : 'image/jpeg',
//         'local_file'       : filePath,
//         'saved_at'         : DateTime.now().toIso8601String(),
//       };
//
//       // ── Store pending info in SharedPreferences ───────────────────────────
//       await prefs.setBool(_KEY_SELFIE_PENDING, true);
//       await prefs.setString(_KEY_SELFIE_PENDING_PATH, filePath);
//       await prefs.setString(_KEY_SELFIE_PENDING_META, jsonEncode(meta));
//
//       debugPrint('💾 [$_TAG] [LOCAL SAVE] Metadata saved to SharedPrefs');
//       debugPrint('💾 [$_TAG] [LOCAL SAVE]   emp_id=$empId  company=$companyCode  file=$fileName');
//       debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== SUCCESS =====');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       return true;
//     } catch (e) {
//       debugPrint('❌ [$_TAG] [LOCAL SAVE] Error: $e');
//       debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== FAILED =====');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       return false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // ✅ OFFLINE: SYNC PENDING SELFIE
//   // Internet aane par locally saved selfie server pe post karta hai.
//   // Grace window expire ho chuki ho tab bhi sync hota hai.
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _syncPendingSelfie() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final bool pending = prefs.getBool(_KEY_SELFIE_PENDING) ?? false;
//       if (!pending) return;
//
//       debugPrint('');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('🔄 [$_TAG] [OFFLINE SYNC] ===== Syncing pending selfie =====');
//
//       // ── Check connectivity ────────────────────────────────────────────────
//       final bool online = await _checkCurrentConnectivity();
//       if (!online) {
//         debugPrint('📴 [$_TAG] [OFFLINE SYNC] Still offline — sync deferred');
//         debugPrint('══════════════════════════════════════════════════════');
//         return;
//       }
//
//       // ── Read saved file path and metadata ────────────────────────────────
//       final String? filePath = prefs.getString(_KEY_SELFIE_PENDING_PATH);
//       final String? metaStr  = prefs.getString(_KEY_SELFIE_PENDING_META);
//
//       if (filePath == null || metaStr == null) {
//         debugPrint('⚠️ [$_TAG] [OFFLINE SYNC] Missing path or metadata — clearing stale flag');
//         await _clearPendingSelfieData(prefs);
//         return;
//       }
//
//       // ── Read local image file ─────────────────────────────────────────────
//       final File imageFile = File(filePath);
//       if (!await imageFile.exists()) {
//         debugPrint('⚠️ [$_TAG] [OFFLINE SYNC] Local image file not found: $filePath — clearing');
//         await _clearPendingSelfieData(prefs);
//         return;
//       }
//
//       final Uint8List imageBytes = await imageFile.readAsBytes();
//       debugPrint('🔄 [$_TAG] [OFFLINE SYNC] Image loaded: ${imageBytes.length} bytes');
//
//       // ── Parse metadata ────────────────────────────────────────────────────
//       final Map<String, dynamic> meta = jsonDecode(metaStr) as Map<String, dynamic>;
//       debugPrint('🔄 [$_TAG] [OFFLINE SYNC] Metadata: emp_id=${meta['emp_id']}  company=${meta['company_code']}');
//
//       // ── POST selfie using saved metadata ──────────────────────────────────
//       final bool posted = await _postSelfieWithMetadata(imageBytes, meta);
//
//       if (posted) {
//         // ── Delete local file and clear pending flag ──────────────────────
//         try { await imageFile.delete(); } catch (_) {}
//         await _clearPendingSelfieData(prefs);
//
//         debugPrint('✅ [$_TAG] [OFFLINE SYNC] Pending selfie uploaded successfully');
//         debugPrint('✅ [$_TAG] [OFFLINE SYNC] Local file deleted: $filePath');
//
//         // Show snackbar (safe — app may or may not be in foreground)
//         try {
//           Get.snackbar(
//             '✅ Selfie Synced',
//             'Offline selfie has been uploaded successfully',
//             snackPosition  : SnackPosition.TOP,
//             backgroundColor: Colors.green.shade700,
//             colorText      : Colors.white,
//             duration       : const Duration(seconds: 3),
//             icon           : const Icon(Icons.cloud_done_outlined, color: Colors.white),
//           );
//         } catch (_) {}
//       } else {
//         debugPrint('❌ [$_TAG] [OFFLINE SYNC] Upload failed — will retry on next connection');
//       }
//
//       debugPrint('🔄 [$_TAG] [OFFLINE SYNC] ===== END =====');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//     } catch (e) {
//       debugPrint('❌ [$_TAG] [OFFLINE SYNC] Error: $e');
//     }
//   }
//
//   // ── Clear pending selfie SharedPrefs keys ─────────────────────────────────
//   Future<void> _clearPendingSelfieData(SharedPreferences prefs) async {
//     await prefs.remove(_KEY_SELFIE_PENDING);
//     await prefs.remove(_KEY_SELFIE_PENDING_PATH);
//     await prefs.remove(_KEY_SELFIE_PENDING_META);
//     debugPrint('🧹 [$_TAG] Pending selfie data cleared from SharedPrefs');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // ✅ OFFLINE: POST SELFIE WITH PRE-BUILT METADATA
//   // Pending selfie sync ke liye — metadata pehle se JSON mein hai.
//   // Same multipart POST logic, sirf metadata map se fields lete hai.
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _postSelfieWithMetadata(Uint8List imageBytes, Map<String, dynamic> meta) async {
//     debugPrint('');
//     debugPrint('📤 [$_TAG] [OFFLINE POST] ===== Posting pending selfie =====');
//
//     try {
//       final String empId           = meta['emp_id']?.toString() ?? '';
//       final String empName         = meta['emp_name']?.toString() ?? 'Unknown';
//       final String companyCode     = meta['company_code']?.toString() ?? '';
//       final String capturedAt      = meta['captured_at']?.toString() ?? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
//       final String attendanceOutId = meta['attendance_out_id']?.toString() ?? '';
//       final String latStr          = (meta['latitude']  ?? 0.0).toString();
//       final String lngStr          = (meta['longitude'] ?? 0.0).toString();
//
//       if (empId.isEmpty || companyCode.isEmpty) {
//         debugPrint('❌ [$_TAG] [OFFLINE POST] emp_id or company_code empty — cannot post');
//         return false;
//       }
//
//       if (imageBytes.isEmpty) {
//         debugPrint('❌ [$_TAG] [OFFLINE POST] imageBytes empty — cannot post');
//         return false;
//       }
//
//       final String filename = 'selfie_${empId}_$capturedAt.jpg';
//
//       debugPrint('📤 [$_TAG] [OFFLINE POST] URL = $_SELFIE_POST_URL');
//       debugPrint('📤 [$_TAG] [OFFLINE POST] emp_id=$empId  company=$companyCode  file=$filename');
//
//       final uri = Uri.parse(_SELFIE_POST_URL);
//       final request = http.MultipartRequest('POST', uri)
//         ..headers['Accept'] = 'application/json'
//         ..fields['emp_id']             = empId
//         ..fields['emp_name']           = empName
//         ..fields['company_code']       = companyCode
//         ..fields['latitude']           = latStr
//         ..fields['longitude']          = lngStr
//         ..fields['captured_at']        = capturedAt
//         ..fields['created_at']         = capturedAt
//         ..fields['attendance_out_id']  = attendanceOutId
//         ..fields['image_mime_type']    = 'image/jpeg'
//         ..files.add(
//           http.MultipartFile.fromBytes(
//             'selfie_image',
//             imageBytes,
//             filename: filename,
//           ),
//         );
//
//       final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
//       final response = await http.Response.fromStream(streamedResponse);
//
//       debugPrint('📥 [$_TAG] [OFFLINE POST] Status: ${response.statusCode}');
//       debugPrint('📥 [$_TAG] [OFFLINE POST] Body: ${response.body}');
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         debugPrint('✅ [$_TAG] [OFFLINE POST] ===== SUCCESS =====');
//         return true;
//       } else {
//         debugPrint('❌ [$_TAG] [OFFLINE POST] ===== FAILED — status ${response.statusCode} =====');
//         return false;
//       }
//     } catch (e) {
//       debugPrint('💥 [$_TAG] [OFFLINE POST] Exception: $e');
//       return false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // CAMERA OPEN  (called from SelfieGraceButton widget)
//   // ✅ OFFLINE: Offline hone par locally save karta hai, online par POST.
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> openCamera(BuildContext context) async {
//     debugPrint('📷 [$_TAG] Opening camera for selfie...');
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? photo = await picker.pickImage(
//         source              : ImageSource.camera,
//         preferredCameraDevice: CameraDevice.front,
//         imageQuality        : 40,
//         maxWidth            : 800,
//         maxHeight           : 800,
//       );
//
//       if (photo == null) {
//         debugPrint('📷 [$_TAG] User cancelled camera — no photo taken');
//         return;
//       }
//
//       debugPrint('📸 [$_TAG] Selfie captured: ${photo.path}');
//
//       // ── Read image bytes ───────────────────────────────────────────────────
//       final Uint8List imageBytes = await photo.readAsBytes();
//       debugPrint('📸 [$_TAG] Image size: ${imageBytes.length} bytes');
//
//       // ── ✅ OFFLINE: Check connectivity before deciding how to proceed ──────
//       final bool online = await _checkCurrentConnectivity();
//       debugPrint('🌐 [$_TAG] Connectivity at selfie time: ${online ? "ONLINE" : "OFFLINE"}');
//
//       bool posted      = false;
//       bool savedLocally = false;
//
//       if (online) {
//         // ── ONLINE: Try to upload immediately ─────────────────────────────
//         if (context.mounted) {
//           Get.snackbar(
//             '📤 Uploading Selfie',
//             'Please wait, uploading to server...',
//             snackPosition  : SnackPosition.TOP,
//             backgroundColor: Colors.blueGrey.shade700,
//             colorText      : Colors.white,
//             duration       : const Duration(seconds: 60),
//             showProgressIndicator: true,
//             icon           : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
//           );
//         }
//
//         posted = await _postSelfieToApi(imageBytes, context);
//         debugPrint('📤 [$_TAG] POST result: $posted');
//
//         // ── Dismiss uploading snackbar ────────────────────────────────────
//         Get.closeAllSnackbars();
//
//         if (!posted) {
//           // Online but API failed — save locally as fallback
//           debugPrint('⚠️ [$_TAG] Online POST failed — saving locally as fallback');
//           savedLocally = await _saveSelfieLocally(imageBytes);
//         }
//       } else {
//         // ── OFFLINE: Save locally, sync later ────────────────────────────
//         debugPrint('📴 [$_TAG] Device OFFLINE — saving selfie locally for later sync');
//         savedLocally = await _saveSelfieLocally(imageBytes);
//       }
//
//       // ── Always hide button and clear grace state after selfie attempt ──────
//       _countdownTimer?.cancel();
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool(_KEY_SELFIE_DONE, true);
//       await _clearSavedState(prefs);
//       debugPrint('✅ [$_TAG] Selfie done — button hidden, grace state cleared, done flag saved');
//
//       // ── Show appropriate result snackbar ───────────────────────────────────
//       if (context.mounted) {
//         if (posted) {
//           // Uploaded immediately
//           Get.snackbar(
//             '✅ Selfie Posted',
//             'Attendance selfie uploaded successfully',
//             snackPosition  : SnackPosition.TOP,
//             backgroundColor: Colors.green.shade700,
//             colorText      : Colors.white,
//             duration       : const Duration(seconds: 3),
//             icon           : const Icon(Icons.check_circle_outline, color: Colors.white),
//           );
//         } else if (savedLocally) {
//           // Saved locally (offline or online-but-failed)
//           Get.snackbar(
//             '💾 Selfie Saved Offline',
//             online
//                 ? 'Upload failed. Selfie saved locally — will auto-sync when connection is stable.'
//                 : 'No internet. Selfie saved locally — will upload automatically when online.',
//             snackPosition  : SnackPosition.TOP,
//             backgroundColor: Colors.orange.shade700,
//             colorText      : Colors.white,
//             duration       : const Duration(seconds: 4),
//             icon           : const Icon(Icons.save_alt_outlined, color: Colors.white),
//           );
//         } else {
//           // Both upload and local save failed
//           Get.snackbar(
//             '⚠️ Selfie Failed',
//             'Could not save selfie. Please try again.',
//             snackPosition  : SnackPosition.TOP,
//             backgroundColor: Colors.red.shade700,
//             colorText      : Colors.white,
//             duration       : const Duration(seconds: 4),
//             icon           : const Icon(Icons.warning_amber_rounded, color: Colors.white),
//           );
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ [$_TAG] openCamera error: $e');
//       if (context.mounted) {
//         Get.snackbar(
//           'Camera Error',
//           'Could not open camera: $e',
//           backgroundColor: Colors.red.shade700,
//           colorText      : Colors.white,
//         );
//       }
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // SELFIE POST API  — ultra-detailed debug version
//   // (Original method — unchanged. Called only when online.)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _postSelfieToApi(Uint8List imageBytes, BuildContext context) async {
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('📤 [$_TAG] [SELFIE POST] ===== START =====');
//     debugPrint('══════════════════════════════════════════════════════');
//
//     try {
//
//       // ── STEP 1: Dump ALL SharedPreferences keys ────────────────────────────
//       debugPrint('');
//       debugPrint('📦 [$_TAG] [STEP-1] Reading SharedPreferences...');
//       final prefs = await SharedPreferences.getInstance();
//       final Set<String> allKeys = prefs.getKeys();
//       debugPrint('📦 [$_TAG] [STEP-1] Total keys in SharedPreferences: ${allKeys.length}');
//       debugPrint('📦 [$_TAG] [STEP-1] ── ALL KEYS DUMP ──────────────────────');
//       for (final k in allKeys.toList()..sort()) {
//         debugPrint('📦 [$_TAG]    $k = ${prefs.get(k)}');
//       }
//       debugPrint('📦 [$_TAG] [STEP-1] ── END KEYS DUMP ─────────────────────');
//
//       // ── STEP 2: Extract emp_id ─────────────────────────────────────────────
//       debugPrint('');
//       debugPrint('👤 [$_TAG] [STEP-2] Extracting emp_id...');
//       final List<String> empIdKeys = ['emp_id', 'userId', 'user_id', 'empId', 'EMP_ID'];
//       String empId = '';
//       for (final k in empIdKeys) {
//         final v = prefs.get(k);
//         debugPrint('👤 [$_TAG] [STEP-2]   trying "$k" → ${v == null ? "null" : '"$v"'}');
//         if (v != null && v.toString().trim().isNotEmpty) {
//           empId = v.toString().trim();
//           debugPrint('👤 [$_TAG] [STEP-2]   ✅ Found in "$k": "$empId"');
//           break;
//         }
//       }
//       debugPrint('👤 [$_TAG] [STEP-2] emp_id = "$empId"');
//       if (empId.isEmpty) {
//         debugPrint('❌ [$_TAG] [STEP-2] emp_id is EMPTY — cannot post selfie. Check key name in SharedPreferences above.');
//         debugPrint('══════════════════════════════════════════════════════');
//         return false;
//       }
//       debugPrint('✅ [$_TAG] [STEP-2] emp_id OK');
//
//       // ── STEP 3: Extract emp_name ───────────────────────────────────────────
//       debugPrint('');
//       debugPrint('👤 [$_TAG] [STEP-3] Extracting emp_name (trying multiple keys)...');
//       final List<String> nameKeys = [
//         'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
//       ];
//       String empName = '';
//       for (final k in nameKeys) {
//         final v = prefs.get(k);
//         debugPrint('👤 [$_TAG] [STEP-3]   trying "$k" → ${v == null ? "null" : '"$v"'}');
//         if (v != null && v.toString().trim().isNotEmpty) {
//           empName = v.toString().trim();
//           debugPrint('👤 [$_TAG] [STEP-3]   ✅ Found in "$k": "$empName"');
//           break;
//         }
//       }
//       if (empName.isEmpty) {
//         empName = 'Unknown';
//         debugPrint('⚠️ [$_TAG] [STEP-3] emp_name not found — using "Unknown". Add correct key to nameKeys list above.');
//       }
//       debugPrint('👤 [$_TAG] [STEP-3] emp_name = "$empName"');
//
//       // ── STEP 4: Extract company_code ──────────────────────────────────────
//       debugPrint('');
//       debugPrint('🏢 [$_TAG] [STEP-4] Extracting company_code...');
//       final List<String> companyKeys = [
//         'company_code', 'companyCode', 'COMPANY_CODE', 'comp_code',
//       ];
//       String companyCode = '';
//       for (final k in companyKeys) {
//         final v = prefs.get(k);
//         debugPrint('🏢 [$_TAG] [STEP-4]   trying "$k" → ${v == null ? "null" : '"$v"'}');
//         if (v != null && v.toString().trim().isNotEmpty) {
//           companyCode = v.toString().trim();
//           debugPrint('🏢 [$_TAG] [STEP-4]   ✅ Found in "$k": "$companyCode"');
//           break;
//         }
//       }
//       if (companyCode.isEmpty) {
//         debugPrint('❌ [$_TAG] [STEP-4] company_code is EMPTY — check key name in SharedPreferences dump above.');
//         debugPrint('══════════════════════════════════════════════════════');
//         return false;
//       }
//       debugPrint('🏢 [$_TAG] [STEP-4] company_code = "$companyCode"');
//
//       // ── STEP 5: Image bytes validation ────────────────────────────────────
//       debugPrint('');
//       debugPrint('🖼️ [$_TAG] [STEP-5] Validating image bytes...');
//       debugPrint('🖼️ [$_TAG] [STEP-5] imageBytes.length = ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
//       if (imageBytes.isEmpty) {
//         debugPrint('❌ [$_TAG] [STEP-5] imageBytes is EMPTY — aborting');
//         debugPrint('══════════════════════════════════════════════════════');
//         return false;
//       }
//       if (imageBytes.length >= 3) {
//         debugPrint('🖼️ [$_TAG] [STEP-5] First 4 bytes (hex): '
//             '${imageBytes[0].toRadixString(16).padLeft(2,'0').toUpperCase()} '
//             '${imageBytes[1].toRadixString(16).padLeft(2,'0').toUpperCase()} '
//             '${imageBytes[2].toRadixString(16).padLeft(2,'0').toUpperCase()} '
//             '${imageBytes.length > 3 ? imageBytes[3].toRadixString(16).padLeft(2,'0').toUpperCase() : "--"}'
//             ' (JPEG starts with FF D8 FF)');
//       }
//       debugPrint('✅ [$_TAG] [STEP-5] Image bytes OK');
//
//       // ── STEP 6: Get GPS location ───────────────────────────────────────────
//       debugPrint('');
//       debugPrint('📍 [$_TAG] [STEP-6] Getting GPS location...');
//       double latitude  = 0.0;
//       double longitude = 0.0;
//
//       try {
//         LocationPermission permission = await Geolocator.checkPermission();
//         debugPrint('📍 [$_TAG] [STEP-6] Current permission = $permission');
//
//         if (permission == LocationPermission.denied) {
//           debugPrint('📍 [$_TAG] [STEP-6] Permission denied — requesting...');
//           permission = await Geolocator.requestPermission();
//           debugPrint('📍 [$_TAG] [STEP-6] After request = $permission');
//         }
//
//         if (permission == LocationPermission.deniedForever) {
//           debugPrint('⚠️ [$_TAG] [STEP-6] Permission DENIED FOREVER — posting with lat=0 lng=0');
//         } else if (permission == LocationPermission.denied) {
//           debugPrint('⚠️ [$_TAG] [STEP-6] Permission still DENIED — posting with lat=0 lng=0');
//         } else {
//           debugPrint('📍 [$_TAG] [STEP-6] Permission OK — fetching position (timeout 10s)...');
//           final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//           debugPrint('📍 [$_TAG] [STEP-6] Location service enabled = $serviceEnabled');
//
//           if (!serviceEnabled) {
//             debugPrint('⚠️ [$_TAG] [STEP-6] Location SERVICE is OFF — posting with lat=0 lng=0');
//           } else {
//             final Position pos = await Geolocator.getCurrentPosition(
//               desiredAccuracy: LocationAccuracy.high,
//             ).timeout(const Duration(seconds: 10));
//             latitude  = pos.latitude;
//             longitude = pos.longitude;
//             debugPrint('✅ [$_TAG] [STEP-6] GPS OK → lat=$latitude  lng=$longitude  accuracy=${pos.accuracy}m');
//           }
//         }
//       } catch (locErr, locStack) {
//         debugPrint('⚠️ [$_TAG] [STEP-6] Location ERROR: $locErr');
//         debugPrint('⚠️ [$_TAG] [STEP-6] Stack: $locStack');
//         debugPrint('⚠️ [$_TAG] [STEP-6] Proceeding with lat=0 lng=0');
//       }
//
//       // ── STEP 7: Build fields ───────────────────────────────────────────────
//       debugPrint('');
//       debugPrint('📋 [$_TAG] [STEP-7] Building request fields...');
//       final String capturedAt = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
//       final String filename   = 'selfie_${empId}_$capturedAt.jpg';
//
//       final String attendanceOutId = (prefs.get('attendanceId') ?? '').toString().trim();
//       debugPrint('📋 [$_TAG] [STEP-7] attendance_out_id = "$attendanceOutId"');
//
//       debugPrint('📋 [$_TAG] [STEP-7] ── FIELDS TO BE SENT ──────────────────');
//       debugPrint('📋 [$_TAG]   emp_id             = "$empId"');
//       debugPrint('📋 [$_TAG]   emp_name           = "$empName"');
//       debugPrint('📋 [$_TAG]   company_code       = "$companyCode"');
//       debugPrint('📋 [$_TAG]   latitude           = "${latitude.toStringAsFixed(7)}"');
//       debugPrint('📋 [$_TAG]   longitude          = "${longitude.toStringAsFixed(7)}"');
//       debugPrint('📋 [$_TAG]   captured_at        = "$capturedAt"');
//       debugPrint('📋 [$_TAG]   created_at         = "$capturedAt"');
//       debugPrint('📋 [$_TAG]   attendance_out_id  = "$attendanceOutId"');
//       debugPrint('📋 [$_TAG]   image_mime_type    = "image/jpeg"');
//       debugPrint('📋 [$_TAG]   selfie_image       = $filename (${imageBytes.length} bytes)');
//       debugPrint('📋 [$_TAG] ── END FIELDS ────────────────────────────────────');
//
//       // ── STEP 8: Build and send multipart request ───────────────────────────
//       debugPrint('');
//       debugPrint('🌐 [$_TAG] [STEP-8] Building MultipartRequest...');
//       debugPrint('🌐 [$_TAG] [STEP-8] URL = $_SELFIE_POST_URL');
//
//       final uri = Uri.parse(_SELFIE_POST_URL);
//       final request = http.MultipartRequest('POST', uri)
//         ..headers['Accept'] = 'application/json'
//         ..fields['emp_id']             = empId
//         ..fields['emp_name']           = empName
//         ..fields['company_code']       = companyCode
//         ..fields['latitude']           = latitude.toStringAsFixed(7)
//         ..fields['longitude']          = longitude.toStringAsFixed(7)
//         ..fields['captured_at']        = capturedAt
//         ..fields['created_at']         = capturedAt
//         ..fields['attendance_out_id']  = attendanceOutId
//         ..fields['image_mime_type']    = 'image/jpeg'
//         ..files.add(
//           http.MultipartFile.fromBytes(
//             'selfie_image',
//             imageBytes,
//             filename: filename,
//           ),
//         );
//
//       debugPrint('🌐 [$_TAG] [STEP-8] Request built. Sending... (timeout 30s)');
//       final stopwatch = Stopwatch()..start();
//
//       final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
//       final response = await http.Response.fromStream(streamedResponse);
//
//       stopwatch.stop();
//
//       // ── STEP 9: Log full response ─────────────────────────────────────────
//       debugPrint('');
//       debugPrint('📥 [$_TAG] [STEP-9] ── RESPONSE ───────────────────────────');
//       debugPrint('📥 [$_TAG]   Time taken   : ${stopwatch.elapsedMilliseconds}ms');
//       debugPrint('📥 [$_TAG]   Status code  : ${response.statusCode}');
//       debugPrint('📥 [$_TAG]   Reason phrase: ${response.reasonPhrase}');
//       debugPrint('📥 [$_TAG]   Headers      : ${response.headers}');
//       debugPrint('📥 [$_TAG]   Body (raw)   : ${response.body}');
//       debugPrint('📥 [$_TAG] ── END RESPONSE ─────────────────────────────────');
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         debugPrint('');
//         debugPrint('✅ [$_TAG] [SELFIE POST] ===== SUCCESS — data posted to server =====');
//         debugPrint('');
//         debugPrint('══════════════════════════════════════════════════════');
//         debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
//         debugPrint('══════════════════════════════════════════════════════');
//         debugPrint('');
//         return true;
//       } else {
//         debugPrint('');
//         debugPrint('❌ [$_TAG] [SELFIE POST] ===== FAILED — status ${response.statusCode} =====');
//         debugPrint('❌ [$_TAG] Check: Is the endpoint correct? Is Oracle ORDS running?');
//         debugPrint('❌ [$_TAG] Is field name "selfie_image" matching the ORDS handler parameter?');
//         debugPrint('');
//         debugPrint('══════════════════════════════════════════════════════');
//         debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
//         debugPrint('══════════════════════════════════════════════════════');
//         debugPrint('');
//         return false;
//       }
//
//     } catch (e, stack) {
//       debugPrint('');
//       debugPrint('💥 [$_TAG] [SELFIE POST] ===== EXCEPTION =====');
//       debugPrint('💥 [$_TAG] Error type : ${e.runtimeType}');
//       debugPrint('💥 [$_TAG] Error      : $e');
//       debugPrint('💥 [$_TAG] Stacktrace : $stack');
//       debugPrint('💥 [$_TAG] Common causes:');
//       debugPrint('💥 [$_TAG]   • No internet / server unreachable → SocketException');
//       debugPrint('💥 [$_TAG]   • Request took > 60s → TimeoutException');
//       debugPrint('💥 [$_TAG]   • Wrong URL scheme (http vs https) → HandshakeException');
//       debugPrint('💥 [$_TAG]   • Android cleartext blocked → add network_security_config.xml');
//       debugPrint('');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       return false;
//     }
//   }
//
//   // ── Safe SharedPreferences reader (tries multiple key variants) ───────────
//   String _safePrefsAny(SharedPreferences prefs, List<String> keys) {
//     for (final k in keys) {
//       try {
//         final v = prefs.get(k);
//         if (v != null) {
//           final s = v.toString().trim();
//           if (s.isNotEmpty) return s;
//         }
//       } catch (_) {}
//     }
//     return '';
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // HELPERS
//   // ══════════════════════════════════════════════════════════════════════════
//
//   /// Parses SHIFT_GRACE_TIME to minutes.
//   int _parseGraceTimeToMinutes(String raw) {
//     final String trimmed = raw.trim().toUpperCase();
//
//     final int? asInt = int.tryParse(trimmed);
//     if (asInt != null) {
//       debugPrint('📐 [$_TAG] Grace="$raw" → int → $asInt min');
//       return asInt;
//     }
//
//     final RegExp minSuffix = RegExp(r'^(\d+)\s*M(?:IN)?$');
//     final Match? minMatch  = minSuffix.firstMatch(trimmed);
//     if (minMatch != null) {
//       final int mins = int.tryParse(minMatch.group(1)!) ?? 0;
//       debugPrint('📐 [$_TAG] Grace="$raw" → XminSuffix → $mins min');
//       return mins;
//     }
//
//     final RegExp hrSuffix = RegExp(r'^(\d+(?:\.\d+)?)\s*H(?:R|OUR)?S?$');
//     final Match? hrMatch  = hrSuffix.firstMatch(trimmed);
//     if (hrMatch != null) {
//       final double hrs  = double.tryParse(hrMatch.group(1)!) ?? 0;
//       final int    mins = (hrs * 60).round();
//       debugPrint('📐 [$_TAG] Grace="$raw" → XhrSuffix → $mins min');
//       return mins;
//     }
//
//     if (trimmed.contains(':')) {
//       final parts = trimmed.split(':');
//       if (parts.length >= 2) {
//         final int h     = int.tryParse(parts[0].trim()) ?? 0;
//         final int m     = int.tryParse(parts[1].trim()) ?? 0;
//         final int total = h * 60 + m;
//         debugPrint('📐 [$_TAG] Grace="$raw" → HH:MM → $total min');
//         return total;
//       }
//     }
//
//     final double? asDouble = double.tryParse(trimmed);
//     if (asDouble != null) {
//       final int mins = (asDouble * 60).round();
//       debugPrint('📐 [$_TAG] Grace="$raw" → double-hours → $mins min');
//       return mins;
//     }
//
//     debugPrint('⚠️ [$_TAG] Cannot parse grace time "$raw" — defaulting to 0');
//     return 0;
//   }
//
//   /// Converts "HH:MM", "HH:MM:SS", "hh:mm a" etc. to DateTime today.
//   DateTime? _parseTimeToToday(String? raw) {
//     if (raw == null || raw.trim().isEmpty) return null;
//     try {
//       final String upper   = raw.trim().toUpperCase();
//       final bool   isPM    = upper.contains('PM');
//       final bool   isAM    = upper.contains('AM');
//       final String cleaned = upper.replaceAll('PM', '').replaceAll('AM', '').trim();
//       final parts          = cleaned.split(':');
//       if (parts.length < 2) return null;
//       int  hour   = int.tryParse(parts[0].trim()) ?? 0;
//       final int min = int.tryParse(parts[1].trim().split(RegExp(r'\s+'))[0]) ?? 0;
//       if (isPM && hour != 12) hour += 12;
//       if (isAM && hour == 12) hour  = 0;
//       final now = DateTime.now();
//       return DateTime(now.year, now.month, now.day, hour, min, 0);
//     } catch (e) {
//       debugPrint('⚠️ [$_TAG] _parseTimeToToday error: $e  raw="$raw"');
//       return null;
//     }
//   }
//
//   /// Case-insensitive field picker
//   String? _pickField(Map<String, dynamic> map, List<String> keys) {
//     for (final k in keys) {
//       final v = map[k];
//       if (v != null) return v.toString();
//     }
//     return null;
//   }
//
//   Future<void> _clearSavedState(SharedPreferences prefs) async {
//     await prefs.remove(_KEY_GRACE_END_MS);
//     await prefs.remove(_KEY_TOTAL_NOTIFS);
//     await prefs.remove(_KEY_SENT_NOTIFS);
//     await prefs.remove(_KEY_GRACE_ACTIVE);
//     isButtonEnabled.value  = false;
//     graceSecondsLeft.value = 0;
//   }
//
//   /// Next clock-in pe selfie done flag reset karo — taake agla shift end button show kare
//   Future<void> resetSelfieDoneFlag() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_KEY_SELFIE_DONE);
//     debugPrint('🔄 [$_TAG] Selfie done flag reset — ready for next shift');
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // WIDGET  — drop this anywhere in your widget tree
// // ─────────────────────────────────────────────────────────────────────────────
//
// class SelfieGraceButton extends StatelessWidget {
//   const SelfieGraceButton({super.key});
//
//   String _formatCountdown(int totalSeconds) {
//     final int m = totalSeconds ~/ 60;
//     final int s = totalSeconds % 60;
//     return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool registered = Get.isRegistered<SelfieNotificationPolicyService>();
//     debugPrint('🔲 [SelfieGraceButton] build() called — service registered=$registered');
//
//     if (!registered) {
//       debugPrint('🔲 [SelfieGraceButton] Service NOT registered → returning SizedBox.shrink()');
//       debugPrint('🔲 [SelfieGraceButton] Fix: call Get.put(SelfieNotificationPolicyService()) '
//           'in your bindings/main before this widget is rendered.');
//       return const SizedBox.shrink();
//     }
//
//     final service = SelfieNotificationPolicyService.to;
//     debugPrint('🔲 [SelfieGraceButton] Service found. '
//         'isButtonEnabled=${service.isButtonEnabled.value}  '
//         'isFetching=${service.isFetching.value}  '
//         'graceSecondsLeft=${service.graceSecondsLeft.value}');
//
//     return Obx(() {
//       final bool enabled  = service.isButtonEnabled.value;
//       final int  secs     = service.graceSecondsLeft.value;
//       final bool fetching = service.isFetching.value;
//
//       debugPrint('🔲 [SelfieGraceButton] Obx rebuild → enabled=$enabled  fetching=$fetching  secs=$secs');
//
//       if (!enabled && !fetching) {
//         debugPrint('🔲 [SelfieGraceButton] Not enabled & not fetching → hidden (SizedBox.shrink)');
//         return const SizedBox.shrink();
//       }
//
//       const Color activeColor   = Color(0xFF00C6AD);
//       const Color disabledColor = Color(0xFF4A5568);
//
//       final Color btnColor   = enabled ? activeColor : disabledColor;
//       final String countdown = _formatCountdown(secs);
//
//       return AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         margin : const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
//         child  : Material(
//           color       : Colors.transparent,
//           borderRadius: BorderRadius.circular(14),
//           child       : InkWell(
//             borderRadius: BorderRadius.circular(14),
//             onTap: enabled
//                 ? () => service.openCamera(context)
//                 : null,
//             child: Ink(
//               decoration: BoxDecoration(
//                 gradient: enabled
//                     ? const LinearGradient(
//                   colors: [Color(0xFF00B4D8), Color(0xFF00C6AD)],
//                   begin  : Alignment.centerLeft,
//                   end    : Alignment.centerRight,
//                 )
//                     : null,
//                 color           : enabled ? null : disabledColor.withOpacity(0.1),
//                 borderRadius    : BorderRadius.circular(14),
//                 border          : Border.all(
//                   color: btnColor.withOpacity(enabled ? 0.0 : 0.3),
//                   width: 1,
//                 ),
//                 boxShadow: enabled
//                     ? [
//                   BoxShadow(
//                     color      : activeColor.withOpacity(0.3),
//                     blurRadius : 12,
//                     offset     : const Offset(0, 4),
//                   )
//                 ]
//                     : [],
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Container(
//                       width      : 40,
//                       height     : 40,
//                       decoration : BoxDecoration(
//                         color        : (enabled ? Colors.white : btnColor).withOpacity(0.15),
//                         borderRadius : BorderRadius.circular(10),
//                       ),
//                       child: Icon(
//                         Icons.camera_alt_rounded,
//                         color : enabled ? Colors.white : btnColor,
//                         size  : 20,
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisSize      : MainAxisSize.min,
//                         children          : [
//                           Text(
//                             'Attendance Selfie',
//                             style: TextStyle(
//                               fontSize  : 14,
//                               fontWeight: FontWeight.w700,
//                               color     : enabled ? Colors.white : btnColor,
//                               letterSpacing: 0.2,
//                             ),
//                           ),
//                           const SizedBox(height: 2),
//                           Text(
//                             enabled
//                                 ? 'Grace window: $countdown remaining — tap to capture'
//                                 : fetching
//                                 ? 'Fetching policy...'
//                                 : 'Grace period not active',
//                             style: TextStyle(
//                               fontSize  : 11,
//                               fontWeight: FontWeight.w400,
//                               color     : (enabled ? Colors.white : btnColor)
//                                   .withOpacity(0.75),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     if (fetching)
//                       SizedBox(
//                         width : 18,
//                         height: 18,
//                         child : CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: enabled ? Colors.white : btnColor,
//                         ),
//                       )
//                     else if (enabled)
//                       const Icon(
//                         Icons.chevron_right_rounded,
//                         color: Colors.white,
//                         size : 20,
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     });
//   }
// }


///fireabse
// ============================================================
//  selfie_notification_policy_service.dart
//
//  RESPONSIBILITIES:
//    1. API se SELFIE_NOTIFICATION_POLICY data fetch karta hai
//       (SHIFT_GRACE_TIME, SHIFT_NOTIF_COUNT)
//    2. Shift-end ke baad grace window mein button enable karta hai
//    3. SHIFT_NOTIF_COUNT notifications schedule karta hai —
//       foreground, background, AND app-killed teeno cases mein
//    4. Camera open karne ka method provide karta hai
//    5. ✅ OFFLINE: Selfie locally save karta hai jab internet nahi
//    6. ✅ OFFLINE: Internet aane par pending selfie auto-post karta hai
//
//  USAGE (home_screen.dart mein):
//    initState:
//      SelfieNotificationPolicyService.to.initialize(empId, companyCode);
//    Widget:
//      SelfieGraceButton()   ← bas yeh widget add karo
//
//  NOTE: pubspec.yaml mein ensure karo:
//    flutter_local_notifications: ^17.x.x   (already present)
//    timezone: ^0.9.x                        (add karo agar nahi hai)
//    image_picker: ^1.x.x                    (already present)
//    connectivity_plus: ^6.x.x               (already present)
//    path_provider: ^2.x.x                   (already present)
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';                                    // ✅ OFFLINE: File I/O
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ OFFLINE: Connectivity check
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';   // ✅ OFFLINE: Local path
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import '../../Services/remote_config_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class SelfiePolicy {
  final int    id;
  final String empId;
  final String empName;
  final int    shiftGraceMinutes; // parsed from SHIFT_GRACE_TIME
  final int    shiftNotifCount;
  final String companyCode;

  const SelfiePolicy({
    required this.id,
    required this.empId,
    required this.empName,
    required this.shiftGraceMinutes,
    required this.shiftNotifCount,
    required this.companyCode,
  });

  @override
  String toString() =>
      'SelfiePolicy(id=$id empId=$empId grace=${shiftGraceMinutes}min notifCount=$shiftNotifCount)';
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class SelfieNotificationPolicyService extends GetxService {
  // ── Singleton accessor ────────────────────────────────────────────────────
  static SelfieNotificationPolicyService get to =>
      Get.find<SelfieNotificationPolicyService>();

  // ── Tag for debug logs ────────────────────────────────────────────────────
  static const String _TAG = 'SelfiePolicy';

  // ── Notification channel constants ────────────────────────────────────────
  static const String _CHANNEL_ID   = 'selfie_grace_notif_channel';
  static const String _CHANNEL_NAME = 'Selfie Grace Notifications';
  static const int    _NOTIF_BASE_ID = 7000; // avoids collision with existing notif IDs

  // ── SharedPreferences keys (prefixed flutter. per project convention) ──────
  static const String _KEY_GRACE_END_MS    = 'flutter.selfie_grace_end_ms';
  static const String _KEY_TOTAL_NOTIFS    = 'flutter.selfie_total_notifs';
  static const String _KEY_SENT_NOTIFS     = 'flutter.selfie_notifs_sent';
  static const String _KEY_GRACE_ACTIVE    = 'flutter.selfie_grace_active';
  static const String _KEY_SELFIE_DONE     = 'flutter.selfie_done'; // ✅ selfie le li gayi

  // ── Policy category live-update keys (stored in SharedPrefs) ─────────────
  static const String _KEY_POLICY_GRACE_MIN  = 'flutter.selfie_policy_grace_min';
  static const String _KEY_POLICY_NOTIF_COUNT= 'flutter.selfie_policy_notif_count';
  static const String _KEY_POLICY_EMP_ID     = 'flutter.selfie_policy_emp_id';
  static const String _KEY_POLICY_COMPANY    = 'flutter.selfie_policy_company';

  // ── ✅ OFFLINE: Pending selfie keys ───────────────────────────────────────
  static const String _KEY_SELFIE_PENDING      = 'flutter.selfie_pending';       // bool
  static const String _KEY_SELFIE_PENDING_PATH = 'flutter.selfie_pending_path';  // local file path
  static const String _KEY_SELFIE_PENDING_META = 'flutter.selfie_pending_meta';  // JSON metadata

  // ── Observable state (consumed by SelfieGraceButton widget) ──────────────
  final RxBool isButtonEnabled  = false.obs;
  final RxInt  graceSecondsLeft = 0.obs;
  final RxBool isFetching       = false.obs;

  // ── Internals ─────────────────────────────────────────────────────────────
  late final FlutterLocalNotificationsPlugin _notifPlugin;
  Timer?      _countdownTimer;
  Timer?      _policyRefreshTimer;          // ✅ ~1 min live policy refresh
  String      _lastEmpId      = '';
  String      _lastCompanyCode= '';
  int         _notifIdCounter = _NOTIF_BASE_ID;

  // ── ✅ OFFLINE: Connectivity ───────────────────────────────────────────────
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> onInit() async {
    super.onInit();
    await _setupNotifications();
    await _restoreGraceState();

    // ── ✅ OFFLINE: Initial connectivity check ─────────────────────────────
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      debugPrint('🌐 [$_TAG] Initial connectivity: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    } catch (_) {}

    // ── ✅ OFFLINE: Listen for connectivity changes ────────────────────────
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final bool wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      debugPrint('🌐 [$_TAG] Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');

      if (_isOnline && !wasOnline) {
        debugPrint('🔄 [$_TAG] Internet restored — syncing pending selfie...');
        _syncPendingSelfie();

        // Also refresh policy data when connectivity restores
        if (_lastEmpId.isNotEmpty && _lastCompanyCode.isNotEmpty) {
          _fetchAndStorePolicyCategory(_lastEmpId, _lastCompanyCode);
        }
      }
    });

    // ── ✅ OFFLINE: Sync any pending selfie on startup (if online) ─────────
    _syncPendingSelfie();

    debugPrint('✅ [$_TAG] Service ready');
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _policyRefreshTimer?.cancel();
    _connectivitySubscription?.cancel();  // ✅ OFFLINE: Cancel connectivity listener
    super.onClose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC: called from HomeScreen.initState  (or after _loadUserData)
  // ══════════════════════════════════════════════════════════════════════════

  /// Main entry point — fetch policy then activate grace window if applicable.
  Future<void> initialize(String empId, String companyCode) async {
    debugPrint('🚀 [$_TAG] initialize(empId=$empId companyCode=$companyCode)');
    _lastEmpId       = empId;
    _lastCompanyCode = companyCode;
    await fetchPolicy(empId, companyCode);
    _startPolicyRefreshTimer();
  }

  // ── Policy category live refresh (every ~1 minute) ────────────────────────
  void _startPolicyRefreshTimer() {
    _policyRefreshTimer?.cancel();
    _policyRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_lastEmpId.isEmpty || _lastCompanyCode.isEmpty) return;
      debugPrint('🔄 [$_TAG] [POLICY REFRESH] Fetching live policy at ${DateTime.now()}');
      await _fetchAndStorePolicyCategory(_lastEmpId, _lastCompanyCode);
    });
    debugPrint('✅ [$_TAG] Policy refresh timer started (every 60s)');
  }

  /// Fetches only the policy category fields and stores them in SharedPrefs.
  /// Does NOT re-activate the grace window — that is handled separately.
  /// ✅ OFFLINE: If offline, uses cached policy from SharedPrefs silently.
  Future<void> _fetchAndStorePolicyCategory(String empId, String companyCode) async {
    // ── ✅ OFFLINE: Skip API call if offline, use cached values ──────────
    if (!_isOnline) {
      debugPrint('📴 [$_TAG] [POLICY REFRESH] Offline — using cached policy');
      return;
    }

    try {
      final Uri uri = Uri.parse(RemoteConfigService.getSelfiePolicyUrl(empId, companyCode));
      debugPrint('🌐 [$_TAG] [POLICY REFRESH] GET $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [$_TAG] [POLICY REFRESH] Status=${response.statusCode}  Body=${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('❌ [$_TAG] [POLICY REFRESH] Non-2xx — skip');
        return;
      }

      final dynamic decoded = jsonDecode(response.body);
      Map<String, dynamic>? row;
      if (decoded is Map<String, dynamic>) {
        final List? items = decoded['items'] as List?;
        if (items != null && items.isNotEmpty) {
          row = items.first as Map<String, dynamic>;
        } else if (decoded.containsKey('SHIFT_GRACE_TIME') ||
            decoded.containsKey('shift_grace_time')) {
          row = decoded;
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        row = decoded.first as Map<String, dynamic>;
      }

      if (row == null) {
        debugPrint('⚠️ [$_TAG] [POLICY REFRESH] No row found');
        return;
      }

      final String graceRaw  = _pickField(row, ['shift_grace_time', 'SHIFT_GRACE_TIME']) ?? '0';
      final String notifRaw  = _pickField(row, ['shift_notif_count', 'SHIFT_NOTIF_COUNT']) ?? '0';
      final int graceMinutes = _parseGraceTimeToMinutes(graceRaw);
      final int notifCount   = int.tryParse(notifRaw.trim()) ?? 0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_KEY_POLICY_GRACE_MIN,   graceMinutes);
      await prefs.setInt(_KEY_POLICY_NOTIF_COUNT, notifCount);
      await prefs.setString(_KEY_POLICY_EMP_ID,   empId);
      await prefs.setString(_KEY_POLICY_COMPANY,  companyCode);

      debugPrint('✅ [$_TAG] [POLICY REFRESH] Stored → graceMin=$graceMinutes  notifCount=$notifCount');
    } catch (e) {
      debugPrint('❌ [$_TAG] [POLICY REFRESH] Error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION SETUP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _setupNotifications() async {
    _notifPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _notifPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (res) =>
          debugPrint('📲 [$_TAG] Notification tapped: ${res.payload}'),
    );

    // Create dedicated notification channel
    await _notifPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _CHANNEL_ID,
        _CHANNEL_NAME,
        description: 'Reminders to take attendance selfie during grace period',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    // Initialize timezone (needed for zonedSchedule — works even when app killed)
    try {
      tzData.initializeTimeZones();
      debugPrint('✅ [$_TAG] Timezone initialized (${tz.local.name})');
    } catch (e) {
      debugPrint('⚠️ [$_TAG] Timezone init failed: $e — will use timer-only fallback');
    }

    debugPrint('✅ [$_TAG] Notifications channel ready: $_CHANNEL_ID');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API CALL  (with full debug logs as requested)
  // ✅ OFFLINE: Uses cached policy when offline
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> fetchPolicy(String empId, String companyCode) async {
    if (empId.isEmpty || companyCode.isEmpty) {
      debugPrint('⚠️ [$_TAG] fetchPolicy: empId or companyCode empty — skip');
      return;
    }

    isFetching.value = true;

    try {
      // ── ✅ OFFLINE: If no internet, use cached policy to activate grace ─
      if (!_isOnline) {
        debugPrint('📴 [$_TAG] fetchPolicy: OFFLINE — trying cached policy');
        await _activateGraceWindowFromCache(empId, companyCode);
        return;
      }

      final Uri uri = Uri.parse(RemoteConfigService.getSelfiePolicyUrl(empId, companyCode));

      debugPrint('🌐 [$_TAG] ── API REQUEST ──────────────────────────────');
      debugPrint('🌐 [$_TAG] GET  $uri');
      debugPrint('🌐 [$_TAG] ─────────────────────────────────────────────');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [$_TAG] ── API RESPONSE ─────────────────────────────');
      debugPrint('📥 [$_TAG] Status : ${response.statusCode}');
      debugPrint('📥 [$_TAG] Body   : ${response.body}');
      debugPrint('📥 [$_TAG] ─────────────────────────────────────────────');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('❌ [$_TAG] Non-2xx response — aborting');
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      // ── Parse response (handles: flat map, {items:[]}, bare list) ─────────
      Map<String, dynamic>? row;

      if (decoded is Map<String, dynamic>) {
        final List? items = decoded['items'] as List?;
        if (items != null && items.isNotEmpty) {
          row = items.first as Map<String, dynamic>;
          debugPrint('📦 [$_TAG] Found row in items[]');
        } else if (decoded.containsKey('SHIFT_GRACE_TIME') ||
            decoded.containsKey('shift_grace_time')) {
          row = decoded;
          debugPrint('📦 [$_TAG] Found row as flat map');
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        row = decoded.first as Map<String, dynamic>;
        debugPrint('📦 [$_TAG] Found row as bare array[0]');
      }

      if (row == null) {
        debugPrint('⚠️ [$_TAG] No policy row found in response');
        return;
      }

      // ── Extract fields (case-insensitive) ─────────────────────────────────
      final String graceRaw    = _pickField(row, ['shift_grace_time', 'SHIFT_GRACE_TIME']) ?? '0';
      final String notifRaw    = _pickField(row, ['shift_notif_count', 'SHIFT_NOTIF_COUNT']) ?? '0';
      final String idRaw       = _pickField(row, ['id', 'ID']) ?? '0';
      final String empNameRaw  = _pickField(row, ['emp_name', 'EMP_NAME']) ?? '';
      final String companyRaw  = _pickField(row, ['company_code', 'COMPANY_CODE']) ?? companyCode;

      final int graceMinutes = _parseGraceTimeToMinutes(graceRaw);
      final int notifCount   = int.tryParse(notifRaw.trim()) ?? 0;
      final int policyId     = int.tryParse(idRaw.trim()) ?? 0;

      final policy = SelfiePolicy(
        id                : policyId,
        empId             : empId,
        empName           : empNameRaw,
        shiftGraceMinutes : graceMinutes,
        shiftNotifCount   : notifCount,
        companyCode       : companyRaw,
      );

      debugPrint('📋 [$_TAG] Policy parsed: $policy');
      debugPrint('📋 [$_TAG]   graceRaw="$graceRaw"  → ${graceMinutes}min');
      debugPrint('📋 [$_TAG]   notifRaw="$notifRaw"  → $notifCount notifications');

      // ── ✅ OFFLINE: Cache policy values for offline use ─────────────────
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_KEY_POLICY_GRACE_MIN,   graceMinutes);
      await prefs.setInt(_KEY_POLICY_NOTIF_COUNT, notifCount);
      await prefs.setString(_KEY_POLICY_EMP_ID,   empId);
      await prefs.setString(_KEY_POLICY_COMPANY,  companyCode);

      if (graceMinutes <= 0 || notifCount <= 0) {
        debugPrint('⚠️ [$_TAG] graceMinutes=$graceMinutes notifCount=$notifCount — nothing to schedule');
        return;
      }

      await _activateGraceWindow(policy);
    } catch (e) {
      debugPrint('❌ [$_TAG] fetchPolicy error: $e');
      // ── ✅ OFFLINE: On network error, fall back to cached policy ─────────
      debugPrint('📴 [$_TAG] Falling back to cached policy after error');
      await _activateGraceWindowFromCache(empId, companyCode);
    } finally {
      isFetching.value = false;
    }
  }

  // ── ✅ OFFLINE: Activate grace window using cached policy from SharedPrefs ─
  Future<void> _activateGraceWindowFromCache(String empId, String companyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int graceMinutes = prefs.getInt(_KEY_POLICY_GRACE_MIN) ?? 0;
      final int notifCount   = prefs.getInt(_KEY_POLICY_NOTIF_COUNT) ?? 0;

      if (graceMinutes <= 0 || notifCount <= 0) {
        debugPrint('📴 [$_TAG] [CACHE] No cached policy — cannot activate grace window offline');
        return;
      }

      debugPrint('📴 [$_TAG] [CACHE] Using cached policy: graceMin=$graceMinutes  notifCount=$notifCount');

      final policy = SelfiePolicy(
        id                : 0,
        empId             : empId,
        empName           : '',
        shiftGraceMinutes : graceMinutes,
        shiftNotifCount   : notifCount,
        companyCode       : companyCode,
      );

      await _activateGraceWindow(policy);
    } catch (e) {
      debugPrint('❌ [$_TAG] [CACHE] _activateGraceWindowFromCache error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRACE WINDOW ACTIVATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _activateGraceWindow(SelfiePolicy policy) async {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🪟 [$_TAG] [GRACE WINDOW] ===== _activateGraceWindow =====');
    debugPrint('🪟 [$_TAG] Policy: graceMin=${policy.shiftGraceMinutes}  notifCount=${policy.shiftNotifCount}');

    final prefs = await SharedPreferences.getInstance();

    // ✅ Selfie already le li — grace window dobara activate mat karo
    final bool selfieDone = prefs.getBool(_KEY_SELFIE_DONE) ?? false;
    debugPrint('🪟 [$_TAG] selfie_done flag = $selfieDone');
    if (selfieDone) {
      debugPrint('ℹ️ [$_TAG] [GRACE WINDOW] Selfie already taken — skipping. '
          'To reset: call resetSelfieDoneFlag() on next clock-in.');
      debugPrint('══════════════════════════════════════════════════════');
      return;
    }

    // Get shift end time
    final String? endTimeStr = prefs.getString('cached_end_time');
    debugPrint('⏰ [$_TAG] [GRACE WINDOW] cached_end_time = "$endTimeStr"');

    final DateTime? shiftEnd = _parseTimeToToday(endTimeStr);
    final DateTime  now      = DateTime.now();

    debugPrint('⏰ [$_TAG] [GRACE WINDOW] shiftEnd (parsed) = $shiftEnd');
    debugPrint('⏰ [$_TAG] [GRACE WINDOW] now               = $now');

    if (policy.shiftGraceMinutes <= 0) {
      debugPrint('❌ [$_TAG] [GRACE WINDOW] graceMinutes = ${policy.shiftGraceMinutes} — nothing to do. '
          'Check SHIFT_GRACE_TIME in the policy API response.');
      debugPrint('══════════════════════════════════════════════════════');
      return;
    }
    if (policy.shiftNotifCount <= 0) {
      debugPrint('❌ [$_TAG] [GRACE WINDOW] notifCount = ${policy.shiftNotifCount} — nothing to do. '
          'Check SHIFT_NOTIF_COUNT in the policy API response.');
      debugPrint('══════════════════════════════════════════════════════');
      return;
    }

    // ✅ SHIFT END GUARD
    if (shiftEnd != null && now.isBefore(shiftEnd)) {
      final Duration untilShiftEnd = shiftEnd.difference(now);
      debugPrint('⏳ [$_TAG] [GRACE WINDOW] Shift NOT ended yet.');
      debugPrint('⏳ [$_TAG]   Shift ends in: ${untilShiftEnd.inMinutes}min ${untilShiftEnd.inSeconds % 60}s');
      debugPrint('⏳ [$_TAG]   Button will appear at: $shiftEnd');
      debugPrint('⏳ [$_TAG]   Scheduling internal Timer to fire at shift end...');
      Timer(untilShiftEnd, () async {
        debugPrint('✅ [$_TAG] [GRACE WINDOW] Timer fired — shift end reached at ${DateTime.now()}. Activating now.');
        final refreshedPrefs = await SharedPreferences.getInstance();
        final DateTime graceStart = shiftEnd;
        final DateTime graceEnd   = graceStart.add(Duration(minutes: policy.shiftGraceMinutes));
        debugPrint('⏰ [$_TAG] [GRACE WINDOW] graceStart=$graceStart  graceEnd=$graceEnd');
        await refreshedPrefs.setInt(_KEY_GRACE_END_MS, graceEnd.millisecondsSinceEpoch);
        await refreshedPrefs.setInt(_KEY_TOTAL_NOTIFS,  policy.shiftNotifCount);
        await refreshedPrefs.setInt(_KEY_SENT_NOTIFS,   0);
        await refreshedPrefs.setBool(_KEY_GRACE_ACTIVE, true);
        _enableButtonWithCountdown(graceEnd, refreshedPrefs);
        _scheduleNotifications(graceStart, graceEnd, policy.shiftNotifCount, refreshedPrefs, sentAlready: 0);
      });
      debugPrint('══════════════════════════════════════════════════════');
      return;
    }

    // Shift already ended
    final DateTime graceBase = shiftEnd ?? now;
    final DateTime graceEnd  = graceBase.add(Duration(minutes: policy.shiftGraceMinutes));

    debugPrint('⏰ [$_TAG] [GRACE WINDOW] Shift already ended.');
    debugPrint('⏰ [$_TAG]   graceBase = $graceBase');
    debugPrint('⏰ [$_TAG]   graceEnd  = $graceEnd  (grace = ${policy.shiftGraceMinutes}min)');
    debugPrint('⏰ [$_TAG]   now       = $now');

    if (now.isAfter(graceEnd)) {
      debugPrint('❌ [$_TAG] [GRACE WINDOW] Grace window ALREADY EXPIRED.');
      debugPrint('❌ [$_TAG]   graceEnd was: $graceEnd');
      debugPrint('❌ [$_TAG]   now is      : $now');
      debugPrint('❌ [$_TAG]   Expired ${now.difference(graceEnd).inMinutes}min ago.');
      debugPrint('❌ [$_TAG]   Button will NOT appear. Increase SHIFT_GRACE_TIME or initialize earlier.');
      debugPrint('══════════════════════════════════════════════════════');
      return;
    }

    final int remainingSec = graceEnd.difference(now).inSeconds;
    debugPrint('✅ [$_TAG] [GRACE WINDOW] Grace window ACTIVE — ${remainingSec}s remaining');

    await prefs.setInt(_KEY_GRACE_END_MS, graceEnd.millisecondsSinceEpoch);
    await prefs.setInt(_KEY_TOTAL_NOTIFS,  policy.shiftNotifCount);
    await prefs.setInt(_KEY_SENT_NOTIFS,   0);
    await prefs.setBool(_KEY_GRACE_ACTIVE, true);

    debugPrint('✅ [$_TAG] [GRACE WINDOW] Prefs saved. Enabling button now...');

    final int alreadyElapsedSec = now.difference(graceBase).inSeconds;
    _enableButtonWithCountdown(graceEnd, prefs);

    final int totalNotifs  = policy.shiftNotifCount;
    final int totalSecs    = graceEnd.difference(graceBase).inSeconds;
    final int interval     = totalSecs ~/ totalNotifs;
    final int sentAlready  = (alreadyElapsedSec ~/ interval).clamp(0, totalNotifs);
    debugPrint('📲 [$_TAG] [GRACE WINDOW] Scheduling notifications: sentAlready=$sentAlready/$totalNotifs');
    await prefs.setInt(_KEY_SENT_NOTIFS, sentAlready);
    _scheduleNotifications(graceBase, graceEnd, totalNotifs, prefs, sentAlready: sentAlready);

    debugPrint('✅ [$_TAG] [GRACE WINDOW] ===== COMPLETE =====');
    debugPrint('══════════════════════════════════════════════════════');
  }

  // ── Enable button + start second-by-second countdown ─────────────────────

  void _enableButtonWithCountdown(DateTime graceEnd, SharedPreferences prefs) {
    debugPrint('');
    debugPrint('🟢 [$_TAG] [BUTTON] _enableButtonWithCountdown called');
    debugPrint('🟢 [$_TAG] [BUTTON] graceEnd = $graceEnd');
    debugPrint('🟢 [$_TAG] [BUTTON] isButtonEnabled BEFORE = ${isButtonEnabled.value}');

    isButtonEnabled.value  = true;
    graceSecondsLeft.value = graceEnd.difference(DateTime.now()).inSeconds.clamp(0, 999999);

    debugPrint('🟢 [$_TAG] [BUTTON] isButtonEnabled SET TO = ${isButtonEnabled.value}');
    debugPrint('🟢 [$_TAG] [BUTTON] graceSecondsLeft = ${graceSecondsLeft.value}s');
    debugPrint('🟢 [$_TAG] [BUTTON] Starting countdown timer...');

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final rem = graceEnd.difference(DateTime.now()).inSeconds;
      if (rem <= 0) {
        graceSecondsLeft.value = 0;
        isButtonEnabled.value  = false;
        t.cancel();
        _clearSavedState(prefs);
        debugPrint('⏰ [$_TAG] [BUTTON] Grace window expired — button DISABLED');
      } else {
        graceSecondsLeft.value = rem;
      }
    });
    debugPrint('🟢 [$_TAG] [BUTTON] Countdown timer started ✅');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION SCHEDULING
  // ══════════════════════════════════════════════════════════════════════════

  void _scheduleNotifications(
      DateTime graceStart,
      DateTime graceEnd,
      int count,
      SharedPreferences prefs, {
        required int sentAlready,
      }) {
    if (count <= 0) return;

    final int totalMs   = graceEnd.difference(graceStart).inMilliseconds;
    final int intervalMs = (totalMs / count).round();
    final DateTime now   = DateTime.now();

    debugPrint('📲 [$_TAG] Scheduling ${count - sentAlready} notifications '
        '(interval=${intervalMs ~/ 1000}s, sentAlready=$sentAlready/$count)');

    for (int i = sentAlready; i < count; i++) {
      final DateTime fireAt = graceStart.add(Duration(milliseconds: intervalMs * (i + 1)));
      final int     seqNum  = i + 1;

      if (fireAt.isAfter(graceEnd)) {
        debugPrint('📲 [$_TAG] Notif $seqNum would exceed graceEnd — skip');
        break;
      }

      final int remaining = count - seqNum;
      final String title  = 'Attendance Selfie';
      final String body   = 'Your shift has ended. Please take your selfie.';

      final Duration delay = fireAt.difference(now);

      if (delay.isNegative || delay.inSeconds < 2) {
        debugPrint('📲 [$_TAG] Notif $seqNum/$count: firing immediately (past $fireAt)');
        _showNotification(_notifIdCounter++, title, body, seqNum, count, prefs);
      } else {
        debugPrint('📲 [$_TAG] Notif $seqNum/$count: in ${delay.inSeconds}s at $fireAt');

        final int timerNotifId  = _notifIdCounter++;
        final int zonedNotifId  = _notifIdCounter++;

        Timer(delay, () {
          _showNotification(timerNotifId, title, body, seqNum, count, prefs);
        });

        _scheduleZoned(
          id     : zonedNotifId,
          at     : fireAt,
          title  : title,
          body   : body,
          seqNum : seqNum,
          total  : count,
        );
      }
    }
  }

  Future<void> _showNotification(
      int id,
      String title,
      String body,
      int seqNum,
      int total,
      SharedPreferences prefs,
      ) async {
    debugPrint('🔔 [$_TAG] Showing notification $seqNum/$total  id=$id');
    try {
      await _notifPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _CHANNEL_ID,
            _CHANNEL_NAME,
            channelDescription : 'Selfie attendance grace period reminder',
            importance         : Importance.high,
            priority           : Priority.high,
            enableVibration    : true,
            autoCancel         : true,
            category           : AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert : true,
            presentBadge : true,
            presentSound : true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: 'selfie_grace_$seqNum',
      );

      final int newSent = (prefs.getInt(_KEY_SENT_NOTIFS) ?? 0) + 1;
      await prefs.setInt(_KEY_SENT_NOTIFS, newSent);
      debugPrint('✅ [$_TAG] Notification sent: $newSent/$total');
    } catch (e) {
      debugPrint('❌ [$_TAG] _showNotification error: $e');
    }
  }

  void _scheduleZoned(
      {required int id,
        required DateTime at,
        required String title,
        required String body,
        required int seqNum,
        required int total}) {
    try {
      final tz.TZDateTime tzAt = tz.TZDateTime.from(at, tz.local);
      _notifPlugin.zonedSchedule(
        id,
        title,
        body,
        tzAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _CHANNEL_ID,
            _CHANNEL_NAME,
            importance     : Importance.high,
            priority       : Priority.high,
            enableVibration: true,
            autoCancel     : true,
            category       : AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert   : true,
            presentSound   : true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'selfie_grace_zoned_$seqNum',
      ).then((_) {
        debugPrint(
            '📲 [$_TAG] zonedSchedule OK: id=$id at=$at notif=$seqNum/$total');
      }).catchError((e) {
        debugPrint('⚠️ [$_TAG] zonedSchedule failed: $e (timer fallback covers it)');
      });
    } catch (e) {
      debugPrint('⚠️ [$_TAG] _scheduleZoned setup error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATE RESTORATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _restoreGraceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(_KEY_SELFIE_DONE) ?? false) {
        debugPrint('ℹ️ [$_TAG] Selfie already taken — button stays hidden');
        return;
      }

      if (!(prefs.getBool(_KEY_GRACE_ACTIVE) ?? false)) {
        debugPrint('ℹ️ [$_TAG] No saved grace state to restore');
        return;
      }

      final int?  graceEndMs  = prefs.getInt(_KEY_GRACE_END_MS);
      final int?  totalNotifs = prefs.getInt(_KEY_TOTAL_NOTIFS);
      final int   sentNotifs  = prefs.getInt(_KEY_SENT_NOTIFS) ?? 0;

      if (graceEndMs == null || totalNotifs == null) {
        debugPrint('⚠️ [$_TAG] Incomplete saved state — clearing');
        await _clearSavedState(prefs);
        return;
      }

      final DateTime graceEnd = DateTime.fromMillisecondsSinceEpoch(graceEndMs);
      final DateTime now      = DateTime.now();

      if (now.isAfter(graceEnd)) {
        debugPrint('⚠️ [$_TAG] Restored grace period already expired — clearing');
        await _clearSavedState(prefs);
        return;
      }

      final int remainSec = graceEnd.difference(now).inSeconds;
      debugPrint('✅ [$_TAG] Restored grace period: ${remainSec}s left '
          '| sent=$sentNotifs/$totalNotifs');

      _enableButtonWithCountdown(graceEnd, prefs);

      final int missed = totalNotifs - sentNotifs;
      if (missed > 0) {
        debugPrint('📲 [$_TAG] Sending $missed missed notifications on restore');
        for (int i = 0; i < missed; i++) {
          await Future.delayed(Duration(seconds: i));
          await _showNotification(
            _notifIdCounter++,
            'Attendance Selfie',
            'Your shift has ended. Please take your selfie.',
            sentNotifs + i + 1,
            totalNotifs,
            prefs,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [$_TAG] _restoreGraceState error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ OFFLINE: CONNECTIVITY HELPER
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _checkCurrentConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ OFFLINE: SAVE SELFIE LOCALLY
  // Selfie image ko app ke documents folder mein save karta hai.
  // Metadata (emp_id, company_code, lat, lng, etc.) SharedPrefs mein store.
  // Returns true if save successful, false otherwise.
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _saveSelfieLocally(Uint8List imageBytes) async {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== START =====');

    try {
      // ── Get local storage directory ───────────────────────────────────────
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName  = 'selfie_pending_$timestamp.jpg';
      final String filePath  = '${appDir.path}/$fileName';

      // ── Write image bytes to file ─────────────────────────────────────────
      final File imageFile = File(filePath);
      await imageFile.writeAsBytes(imageBytes, flush: true);
      debugPrint('💾 [$_TAG] [LOCAL SAVE] Image written: $filePath (${imageBytes.length} bytes)');

      // ── Read SharedPreferences for metadata ───────────────────────────────
      final prefs = await SharedPreferences.getInstance();

      // emp_id
      String empId = '';
      for (final k in ['emp_id', 'userId', 'user_id', 'empId', 'EMP_ID']) {
        final v = prefs.get(k);
        if (v != null && v.toString().trim().isNotEmpty) {
          empId = v.toString().trim();
          break;
        }
      }

      // emp_name
      String empName = 'Unknown';
      for (final k in ['emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name']) {
        final v = prefs.get(k);
        if (v != null && v.toString().trim().isNotEmpty) {
          empName = v.toString().trim();
          break;
        }
      }

      // company_code
      String companyCode = '';
      for (final k in ['company_code', 'companyCode', 'COMPANY_CODE', 'comp_code']) {
        final v = prefs.get(k);
        if (v != null && v.toString().trim().isNotEmpty) {
          companyCode = v.toString().trim();
          break;
        }
      }

      // attendance_out_id
      final String attendanceOutId = (prefs.get('attendanceId') ?? '').toString().trim();

      // captured_at timestamp
      final String capturedAt = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());

      // GPS — best effort (short timeout to not block UI)
      double lat = 0.0;
      double lng = 0.0;
      try {
        final LocationPermission perm = await Geolocator.checkPermission();
        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          final bool serviceOn = await Geolocator.isLocationServiceEnabled();
          if (serviceOn) {
            final Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            ).timeout(const Duration(seconds: 5));
            lat = pos.latitude;
            lng = pos.longitude;
            debugPrint('💾 [$_TAG] [LOCAL SAVE] GPS: lat=$lat  lng=$lng');
          }
        }
      } catch (locErr) {
        debugPrint('⚠️ [$_TAG] [LOCAL SAVE] GPS unavailable: $locErr — saving with lat=0 lng=0');
      }

      // ── Build metadata map ────────────────────────────────────────────────
      final Map<String, dynamic> meta = {
        'emp_id'           : empId,
        'emp_name'         : empName,
        'company_code'     : companyCode,
        'latitude'         : lat,
        'longitude'        : lng,
        'captured_at'      : capturedAt,
        'created_at'       : capturedAt,
        'attendance_out_id': attendanceOutId,
        'image_mime_type'  : 'image/jpeg',
        'local_file'       : filePath,
        'saved_at'         : DateTime.now().toIso8601String(),
      };

      // ── Store pending info in SharedPreferences ───────────────────────────
      await prefs.setBool(_KEY_SELFIE_PENDING, true);
      await prefs.setString(_KEY_SELFIE_PENDING_PATH, filePath);
      await prefs.setString(_KEY_SELFIE_PENDING_META, jsonEncode(meta));

      debugPrint('💾 [$_TAG] [LOCAL SAVE] Metadata saved to SharedPrefs');
      debugPrint('💾 [$_TAG] [LOCAL SAVE]   emp_id=$empId  company=$companyCode  file=$fileName');
      debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== SUCCESS =====');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return true;
    } catch (e) {
      debugPrint('❌ [$_TAG] [LOCAL SAVE] Error: $e');
      debugPrint('💾 [$_TAG] [LOCAL SAVE] ===== FAILED =====');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ OFFLINE: SYNC PENDING SELFIE
  // Internet aane par locally saved selfie server pe post karta hai.
  // Grace window expire ho chuki ho tab bhi sync hota hai.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _syncPendingSelfie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool pending = prefs.getBool(_KEY_SELFIE_PENDING) ?? false;
      if (!pending) return;

      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('🔄 [$_TAG] [OFFLINE SYNC] ===== Syncing pending selfie =====');

      // ── Check connectivity ────────────────────────────────────────────────
      final bool online = await _checkCurrentConnectivity();
      if (!online) {
        debugPrint('📴 [$_TAG] [OFFLINE SYNC] Still offline — sync deferred');
        debugPrint('══════════════════════════════════════════════════════');
        return;
      }

      // ── Read saved file path and metadata ────────────────────────────────
      final String? filePath = prefs.getString(_KEY_SELFIE_PENDING_PATH);
      final String? metaStr  = prefs.getString(_KEY_SELFIE_PENDING_META);

      if (filePath == null || metaStr == null) {
        debugPrint('⚠️ [$_TAG] [OFFLINE SYNC] Missing path or metadata — clearing stale flag');
        await _clearPendingSelfieData(prefs);
        return;
      }

      // ── Read local image file ─────────────────────────────────────────────
      final File imageFile = File(filePath);
      if (!await imageFile.exists()) {
        debugPrint('⚠️ [$_TAG] [OFFLINE SYNC] Local image file not found: $filePath — clearing');
        await _clearPendingSelfieData(prefs);
        return;
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      debugPrint('🔄 [$_TAG] [OFFLINE SYNC] Image loaded: ${imageBytes.length} bytes');

      // ── Parse metadata ────────────────────────────────────────────────────
      final Map<String, dynamic> meta = jsonDecode(metaStr) as Map<String, dynamic>;
      debugPrint('🔄 [$_TAG] [OFFLINE SYNC] Metadata: emp_id=${meta['emp_id']}  company=${meta['company_code']}');

      // ── POST selfie using saved metadata ──────────────────────────────────
      final bool posted = await _postSelfieWithMetadata(imageBytes, meta);

      if (posted) {
        // ── Delete local file and clear pending flag ──────────────────────
        try { await imageFile.delete(); } catch (_) {}
        await _clearPendingSelfieData(prefs);

        debugPrint('✅ [$_TAG] [OFFLINE SYNC] Pending selfie uploaded successfully');
        debugPrint('✅ [$_TAG] [OFFLINE SYNC] Local file deleted: $filePath');

        // Show snackbar (safe — app may or may not be in foreground)
        try {
          Get.snackbar(
            '✅ Selfie Synced',
            'Offline selfie has been uploaded successfully',
            snackPosition  : SnackPosition.TOP,
            backgroundColor: Colors.green.shade700,
            colorText      : Colors.white,
            duration       : const Duration(seconds: 3),
            icon           : const Icon(Icons.cloud_done_outlined, color: Colors.white),
          );
        } catch (_) {}
      } else {
        debugPrint('❌ [$_TAG] [OFFLINE SYNC] Upload failed — will retry on next connection');
      }

      debugPrint('🔄 [$_TAG] [OFFLINE SYNC] ===== END =====');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ [$_TAG] [OFFLINE SYNC] Error: $e');
    }
  }

  // ── Clear pending selfie SharedPrefs keys ─────────────────────────────────
  Future<void> _clearPendingSelfieData(SharedPreferences prefs) async {
    await prefs.remove(_KEY_SELFIE_PENDING);
    await prefs.remove(_KEY_SELFIE_PENDING_PATH);
    await prefs.remove(_KEY_SELFIE_PENDING_META);
    debugPrint('🧹 [$_TAG] Pending selfie data cleared from SharedPrefs');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ OFFLINE: POST SELFIE WITH PRE-BUILT METADATA
  // Pending selfie sync ke liye — metadata pehle se JSON mein hai.
  // Same multipart POST logic, sirf metadata map se fields lete hai.
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _postSelfieWithMetadata(Uint8List imageBytes, Map<String, dynamic> meta) async {
    debugPrint('');
    debugPrint('📤 [$_TAG] [OFFLINE POST] ===== Posting pending selfie =====');

    try {
      final String empId           = meta['emp_id']?.toString() ?? '';
      final String empName         = meta['emp_name']?.toString() ?? 'Unknown';
      final String companyCode     = meta['company_code']?.toString() ?? '';
      final String capturedAt      = meta['captured_at']?.toString() ?? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
      final String attendanceOutId = meta['attendance_out_id']?.toString() ?? '';
      final String latStr          = (meta['latitude']  ?? 0.0).toString();
      final String lngStr          = (meta['longitude'] ?? 0.0).toString();

      if (empId.isEmpty || companyCode.isEmpty) {
        debugPrint('❌ [$_TAG] [OFFLINE POST] emp_id or company_code empty — cannot post');
        return false;
      }

      if (imageBytes.isEmpty) {
        debugPrint('❌ [$_TAG] [OFFLINE POST] imageBytes empty — cannot post');
        return false;
      }

      final String filename = 'selfie_${empId}_$capturedAt.jpg';

      debugPrint('📤 [$_TAG] [OFFLINE POST] URL = ${RemoteConfigService.getSelfiePostUrl()}');
      debugPrint('📤 [$_TAG] [OFFLINE POST] emp_id=$empId  company=$companyCode  file=$filename');

      final uri = Uri.parse(RemoteConfigService.getSelfiePostUrl());
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..fields['emp_id']             = empId
        ..fields['emp_name']           = empName
        ..fields['company_code']       = companyCode
        ..fields['latitude']           = latStr
        ..fields['longitude']          = lngStr
        ..fields['captured_at']        = capturedAt
        ..fields['created_at']         = capturedAt
        ..fields['attendance_out_id']  = attendanceOutId
        ..fields['image_mime_type']    = 'image/jpeg'
        ..files.add(
          http.MultipartFile.fromBytes(
            'selfie_image',
            imageBytes,
            filename: filename,
          ),
        );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 [$_TAG] [OFFLINE POST] Status: ${response.statusCode}');
      debugPrint('📥 [$_TAG] [OFFLINE POST] Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [$_TAG] [OFFLINE POST] ===== SUCCESS =====');
        return true;
      } else {
        debugPrint('❌ [$_TAG] [OFFLINE POST] ===== FAILED — status ${response.statusCode} =====');
        return false;
      }
    } catch (e) {
      debugPrint('💥 [$_TAG] [OFFLINE POST] Exception: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CAMERA OPEN  (called from SelfieGraceButton widget)
  // ✅ OFFLINE: Offline hone par locally save karta hai, online par POST.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> openCamera(BuildContext context) async {
    debugPrint('📷 [$_TAG] Opening camera for selfie...');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source              : ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality        : 40,
        maxWidth            : 800,
        maxHeight           : 800,
      );

      if (photo == null) {
        debugPrint('📷 [$_TAG] User cancelled camera — no photo taken');
        return;
      }

      debugPrint('📸 [$_TAG] Selfie captured: ${photo.path}');

      // ── Read image bytes ───────────────────────────────────────────────────
      final Uint8List imageBytes = await photo.readAsBytes();
      debugPrint('📸 [$_TAG] Image size: ${imageBytes.length} bytes');

      // ── ✅ OFFLINE: Check connectivity before deciding how to proceed ──────
      final bool online = await _checkCurrentConnectivity();
      debugPrint('🌐 [$_TAG] Connectivity at selfie time: ${online ? "ONLINE" : "OFFLINE"}');

      bool posted      = false;
      bool savedLocally = false;

      if (online) {
        // ── ONLINE: Try to upload immediately ─────────────────────────────
        if (context.mounted) {
          Get.snackbar(
            '📤 Uploading Selfie',
            'Please wait, uploading to server...',
            snackPosition  : SnackPosition.TOP,
            backgroundColor: Colors.blueGrey.shade700,
            colorText      : Colors.white,
            duration       : const Duration(seconds: 60),
            showProgressIndicator: true,
            icon           : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
          );
        }

        posted = await _postSelfieToApi(imageBytes, context);
        debugPrint('📤 [$_TAG] POST result: $posted');

        // ── Dismiss uploading snackbar ────────────────────────────────────
        Get.closeAllSnackbars();

        if (!posted) {
          // Online but API failed — save locally as fallback
          debugPrint('⚠️ [$_TAG] Online POST failed — saving locally as fallback');
          savedLocally = await _saveSelfieLocally(imageBytes);
        }
      } else {
        // ── OFFLINE: Save locally, sync later ────────────────────────────
        debugPrint('📴 [$_TAG] Device OFFLINE — saving selfie locally for later sync');
        savedLocally = await _saveSelfieLocally(imageBytes);
      }

      // ── Always hide button and clear grace state after selfie attempt ──────
      _countdownTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_KEY_SELFIE_DONE, true);
      await _clearSavedState(prefs);
      debugPrint('✅ [$_TAG] Selfie done — button hidden, grace state cleared, done flag saved');

      // ── Show appropriate result snackbar ───────────────────────────────────
      if (context.mounted) {
        if (posted) {
          // Uploaded immediately
          Get.snackbar(
            '✅ Selfie Posted',
            'Attendance selfie uploaded successfully',
            snackPosition  : SnackPosition.TOP,
            backgroundColor: Colors.green.shade700,
            colorText      : Colors.white,
            duration       : const Duration(seconds: 3),
            icon           : const Icon(Icons.check_circle_outline, color: Colors.white),
          );
        } else if (savedLocally) {
          // Saved locally (offline or online-but-failed)
          Get.snackbar(
            '💾 Selfie Saved Offline',
            online
                ? 'Upload failed. Selfie saved locally — will auto-sync when connection is stable.'
                : 'No internet. Selfie saved locally — will upload automatically when online.',
            snackPosition  : SnackPosition.TOP,
            backgroundColor: Colors.orange.shade700,
            colorText      : Colors.white,
            duration       : const Duration(seconds: 4),
            icon           : const Icon(Icons.save_alt_outlined, color: Colors.white),
          );
        } else {
          // Both upload and local save failed
          Get.snackbar(
            '⚠️ Selfie Failed',
            'Could not save selfie. Please try again.',
            snackPosition  : SnackPosition.TOP,
            backgroundColor: Colors.red.shade700,
            colorText      : Colors.white,
            duration       : const Duration(seconds: 4),
            icon           : const Icon(Icons.warning_amber_rounded, color: Colors.white),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [$_TAG] openCamera error: $e');
      if (context.mounted) {
        Get.snackbar(
          'Camera Error',
          'Could not open camera: $e',
          backgroundColor: Colors.red.shade700,
          colorText      : Colors.white,
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SELFIE POST API  — ultra-detailed debug version
  // (Original method — unchanged. Called only when online.)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _postSelfieToApi(Uint8List imageBytes, BuildContext context) async {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📤 [$_TAG] [SELFIE POST] ===== START =====');
    debugPrint('══════════════════════════════════════════════════════');

    try {

      // ── STEP 1: Dump ALL SharedPreferences keys ────────────────────────────
      debugPrint('');
      debugPrint('📦 [$_TAG] [STEP-1] Reading SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final Set<String> allKeys = prefs.getKeys();
      debugPrint('📦 [$_TAG] [STEP-1] Total keys in SharedPreferences: ${allKeys.length}');
      debugPrint('📦 [$_TAG] [STEP-1] ── ALL KEYS DUMP ──────────────────────');
      for (final k in allKeys.toList()..sort()) {
        debugPrint('📦 [$_TAG]    $k = ${prefs.get(k)}');
      }
      debugPrint('📦 [$_TAG] [STEP-1] ── END KEYS DUMP ─────────────────────');

      // ── STEP 2: Extract emp_id ─────────────────────────────────────────────
      debugPrint('');
      debugPrint('👤 [$_TAG] [STEP-2] Extracting emp_id...');
      final List<String> empIdKeys = ['emp_id', 'userId', 'user_id', 'empId', 'EMP_ID'];
      String empId = '';
      for (final k in empIdKeys) {
        final v = prefs.get(k);
        debugPrint('👤 [$_TAG] [STEP-2]   trying "$k" → ${v == null ? "null" : '"$v"'}');
        if (v != null && v.toString().trim().isNotEmpty) {
          empId = v.toString().trim();
          debugPrint('👤 [$_TAG] [STEP-2]   ✅ Found in "$k": "$empId"');
          break;
        }
      }
      debugPrint('👤 [$_TAG] [STEP-2] emp_id = "$empId"');
      if (empId.isEmpty) {
        debugPrint('❌ [$_TAG] [STEP-2] emp_id is EMPTY — cannot post selfie. Check key name in SharedPreferences above.');
        debugPrint('══════════════════════════════════════════════════════');
        return false;
      }
      debugPrint('✅ [$_TAG] [STEP-2] emp_id OK');

      // ── STEP 3: Extract emp_name ───────────────────────────────────────────
      debugPrint('');
      debugPrint('👤 [$_TAG] [STEP-3] Extracting emp_name (trying multiple keys)...');
      final List<String> nameKeys = [
        'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
      ];
      String empName = '';
      for (final k in nameKeys) {
        final v = prefs.get(k);
        debugPrint('👤 [$_TAG] [STEP-3]   trying "$k" → ${v == null ? "null" : '"$v"'}');
        if (v != null && v.toString().trim().isNotEmpty) {
          empName = v.toString().trim();
          debugPrint('👤 [$_TAG] [STEP-3]   ✅ Found in "$k": "$empName"');
          break;
        }
      }
      if (empName.isEmpty) {
        empName = 'Unknown';
        debugPrint('⚠️ [$_TAG] [STEP-3] emp_name not found — using "Unknown". Add correct key to nameKeys list above.');
      }
      debugPrint('👤 [$_TAG] [STEP-3] emp_name = "$empName"');

      // ── STEP 4: Extract company_code ──────────────────────────────────────
      debugPrint('');
      debugPrint('🏢 [$_TAG] [STEP-4] Extracting company_code...');
      final List<String> companyKeys = [
        'company_code', 'companyCode', 'COMPANY_CODE', 'comp_code',
      ];
      String companyCode = '';
      for (final k in companyKeys) {
        final v = prefs.get(k);
        debugPrint('🏢 [$_TAG] [STEP-4]   trying "$k" → ${v == null ? "null" : '"$v"'}');
        if (v != null && v.toString().trim().isNotEmpty) {
          companyCode = v.toString().trim();
          debugPrint('🏢 [$_TAG] [STEP-4]   ✅ Found in "$k": "$companyCode"');
          break;
        }
      }
      if (companyCode.isEmpty) {
        debugPrint('❌ [$_TAG] [STEP-4] company_code is EMPTY — check key name in SharedPreferences dump above.');
        debugPrint('══════════════════════════════════════════════════════');
        return false;
      }
      debugPrint('🏢 [$_TAG] [STEP-4] company_code = "$companyCode"');

      // ── STEP 5: Image bytes validation ────────────────────────────────────
      debugPrint('');
      debugPrint('🖼️ [$_TAG] [STEP-5] Validating image bytes...');
      debugPrint('🖼️ [$_TAG] [STEP-5] imageBytes.length = ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
      if (imageBytes.isEmpty) {
        debugPrint('❌ [$_TAG] [STEP-5] imageBytes is EMPTY — aborting');
        debugPrint('══════════════════════════════════════════════════════');
        return false;
      }
      if (imageBytes.length >= 3) {
        debugPrint('🖼️ [$_TAG] [STEP-5] First 4 bytes (hex): '
            '${imageBytes[0].toRadixString(16).padLeft(2,'0').toUpperCase()} '
            '${imageBytes[1].toRadixString(16).padLeft(2,'0').toUpperCase()} '
            '${imageBytes[2].toRadixString(16).padLeft(2,'0').toUpperCase()} '
            '${imageBytes.length > 3 ? imageBytes[3].toRadixString(16).padLeft(2,'0').toUpperCase() : "--"}'
            ' (JPEG starts with FF D8 FF)');
      }
      debugPrint('✅ [$_TAG] [STEP-5] Image bytes OK');

      // ── STEP 6: Get GPS location ───────────────────────────────────────────
      debugPrint('');
      debugPrint('📍 [$_TAG] [STEP-6] Getting GPS location...');
      double latitude  = 0.0;
      double longitude = 0.0;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        debugPrint('📍 [$_TAG] [STEP-6] Current permission = $permission');

        if (permission == LocationPermission.denied) {
          debugPrint('📍 [$_TAG] [STEP-6] Permission denied — requesting...');
          permission = await Geolocator.requestPermission();
          debugPrint('📍 [$_TAG] [STEP-6] After request = $permission');
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint('⚠️ [$_TAG] [STEP-6] Permission DENIED FOREVER — posting with lat=0 lng=0');
        } else if (permission == LocationPermission.denied) {
          debugPrint('⚠️ [$_TAG] [STEP-6] Permission still DENIED — posting with lat=0 lng=0');
        } else {
          debugPrint('📍 [$_TAG] [STEP-6] Permission OK — fetching position (timeout 10s)...');
          final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          debugPrint('📍 [$_TAG] [STEP-6] Location service enabled = $serviceEnabled');

          if (!serviceEnabled) {
            debugPrint('⚠️ [$_TAG] [STEP-6] Location SERVICE is OFF — posting with lat=0 lng=0');
          } else {
            final Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 10));
            latitude  = pos.latitude;
            longitude = pos.longitude;
            debugPrint('✅ [$_TAG] [STEP-6] GPS OK → lat=$latitude  lng=$longitude  accuracy=${pos.accuracy}m');
          }
        }
      } catch (locErr, locStack) {
        debugPrint('⚠️ [$_TAG] [STEP-6] Location ERROR: $locErr');
        debugPrint('⚠️ [$_TAG] [STEP-6] Stack: $locStack');
        debugPrint('⚠️ [$_TAG] [STEP-6] Proceeding with lat=0 lng=0');
      }

      // ── STEP 7: Build fields ───────────────────────────────────────────────
      debugPrint('');
      debugPrint('📋 [$_TAG] [STEP-7] Building request fields...');
      final String capturedAt = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now());
      final String filename   = 'selfie_${empId}_$capturedAt.jpg';

      final String attendanceOutId = (prefs.get('attendanceId') ?? '').toString().trim();
      debugPrint('📋 [$_TAG] [STEP-7] attendance_out_id = "$attendanceOutId"');

      debugPrint('📋 [$_TAG] [STEP-7] ── FIELDS TO BE SENT ──────────────────');
      debugPrint('📋 [$_TAG]   emp_id             = "$empId"');
      debugPrint('📋 [$_TAG]   emp_name           = "$empName"');
      debugPrint('📋 [$_TAG]   company_code       = "$companyCode"');
      debugPrint('📋 [$_TAG]   latitude           = "${latitude.toStringAsFixed(7)}"');
      debugPrint('📋 [$_TAG]   longitude          = "${longitude.toStringAsFixed(7)}"');
      debugPrint('📋 [$_TAG]   captured_at        = "$capturedAt"');
      debugPrint('📋 [$_TAG]   created_at         = "$capturedAt"');
      debugPrint('📋 [$_TAG]   attendance_out_id  = "$attendanceOutId"');
      debugPrint('📋 [$_TAG]   image_mime_type    = "image/jpeg"');
      debugPrint('📋 [$_TAG]   selfie_image       = $filename (${imageBytes.length} bytes)');
      debugPrint('📋 [$_TAG] ── END FIELDS ────────────────────────────────────');

      // ── STEP 8: Build and send multipart request ───────────────────────────
      debugPrint('');
      debugPrint('🌐 [$_TAG] [STEP-8] Building MultipartRequest...');
      debugPrint('🌐 [$_TAG] [STEP-8] URL = ${RemoteConfigService.getSelfiePostUrl()}');

      final uri = Uri.parse(RemoteConfigService.getSelfiePostUrl());
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..fields['emp_id']             = empId
        ..fields['emp_name']           = empName
        ..fields['company_code']       = companyCode
        ..fields['latitude']           = latitude.toStringAsFixed(7)
        ..fields['longitude']          = longitude.toStringAsFixed(7)
        ..fields['captured_at']        = capturedAt
        ..fields['created_at']         = capturedAt
        ..fields['attendance_out_id']  = attendanceOutId
        ..fields['image_mime_type']    = 'image/jpeg'
        ..files.add(
          http.MultipartFile.fromBytes(
            'selfie_image',
            imageBytes,
            filename: filename,
          ),
        );

      debugPrint('🌐 [$_TAG] [STEP-8] Request built. Sending... (timeout 30s)');
      final stopwatch = Stopwatch()..start();

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      stopwatch.stop();

      // ── STEP 9: Log full response ─────────────────────────────────────────
      debugPrint('');
      debugPrint('📥 [$_TAG] [STEP-9] ── RESPONSE ───────────────────────────');
      debugPrint('📥 [$_TAG]   Time taken   : ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📥 [$_TAG]   Status code  : ${response.statusCode}');
      debugPrint('📥 [$_TAG]   Reason phrase: ${response.reasonPhrase}');
      debugPrint('📥 [$_TAG]   Headers      : ${response.headers}');
      debugPrint('📥 [$_TAG]   Body (raw)   : ${response.body}');
      debugPrint('📥 [$_TAG] ── END RESPONSE ─────────────────────────────────');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('');
        debugPrint('✅ [$_TAG] [SELFIE POST] ===== SUCCESS — data posted to server =====');
        debugPrint('');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('');
        return true;
      } else {
        debugPrint('');
        debugPrint('❌ [$_TAG] [SELFIE POST] ===== FAILED — status ${response.statusCode} =====');
        debugPrint('❌ [$_TAG] Check: Is the endpoint correct? Is Oracle ORDS running?');
        debugPrint('❌ [$_TAG] Is field name "selfie_image" matching the ORDS handler parameter?');
        debugPrint('');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('');
        return false;
      }

    } catch (e, stack) {
      debugPrint('');
      debugPrint('💥 [$_TAG] [SELFIE POST] ===== EXCEPTION =====');
      debugPrint('💥 [$_TAG] Error type : ${e.runtimeType}');
      debugPrint('💥 [$_TAG] Error      : $e');
      debugPrint('💥 [$_TAG] Stacktrace : $stack');
      debugPrint('💥 [$_TAG] Common causes:');
      debugPrint('💥 [$_TAG]   • No internet / server unreachable → SocketException');
      debugPrint('💥 [$_TAG]   • Request took > 60s → TimeoutException');
      debugPrint('💥 [$_TAG]   • Wrong URL scheme (http vs https) → HandshakeException');
      debugPrint('💥 [$_TAG]   • Android cleartext blocked → add network_security_config.xml');
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📤 [$_TAG] [SELFIE POST] ===== END =====');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return false;
    }
  }

  // ── Safe SharedPreferences reader (tries multiple key variants) ───────────
  String _safePrefsAny(SharedPreferences prefs, List<String> keys) {
    for (final k in keys) {
      try {
        final v = prefs.get(k);
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      } catch (_) {}
    }
    return '';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Parses SHIFT_GRACE_TIME to minutes.
  int _parseGraceTimeToMinutes(String raw) {
    final String trimmed = raw.trim().toUpperCase();

    final int? asInt = int.tryParse(trimmed);
    if (asInt != null) {
      debugPrint('📐 [$_TAG] Grace="$raw" → int → $asInt min');
      return asInt;
    }

    final RegExp minSuffix = RegExp(r'^(\d+)\s*M(?:IN)?$');
    final Match? minMatch  = minSuffix.firstMatch(trimmed);
    if (minMatch != null) {
      final int mins = int.tryParse(minMatch.group(1)!) ?? 0;
      debugPrint('📐 [$_TAG] Grace="$raw" → XminSuffix → $mins min');
      return mins;
    }

    final RegExp hrSuffix = RegExp(r'^(\d+(?:\.\d+)?)\s*H(?:R|OUR)?S?$');
    final Match? hrMatch  = hrSuffix.firstMatch(trimmed);
    if (hrMatch != null) {
      final double hrs  = double.tryParse(hrMatch.group(1)!) ?? 0;
      final int    mins = (hrs * 60).round();
      debugPrint('📐 [$_TAG] Grace="$raw" → XhrSuffix → $mins min');
      return mins;
    }

    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final int h     = int.tryParse(parts[0].trim()) ?? 0;
        final int m     = int.tryParse(parts[1].trim()) ?? 0;
        final int total = h * 60 + m;
        debugPrint('📐 [$_TAG] Grace="$raw" → HH:MM → $total min');
        return total;
      }
    }

    final double? asDouble = double.tryParse(trimmed);
    if (asDouble != null) {
      final int mins = (asDouble * 60).round();
      debugPrint('📐 [$_TAG] Grace="$raw" → double-hours → $mins min');
      return mins;
    }

    debugPrint('⚠️ [$_TAG] Cannot parse grace time "$raw" — defaulting to 0');
    return 0;
  }

  /// Converts "HH:MM", "HH:MM:SS", "hh:mm a" etc. to DateTime today.
  DateTime? _parseTimeToToday(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final String upper   = raw.trim().toUpperCase();
      final bool   isPM    = upper.contains('PM');
      final bool   isAM    = upper.contains('AM');
      final String cleaned = upper.replaceAll('PM', '').replaceAll('AM', '').trim();
      final parts          = cleaned.split(':');
      if (parts.length < 2) return null;
      int  hour   = int.tryParse(parts[0].trim()) ?? 0;
      final int min = int.tryParse(parts[1].trim().split(RegExp(r'\s+'))[0]) ?? 0;
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour  = 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, min, 0);
    } catch (e) {
      debugPrint('⚠️ [$_TAG] _parseTimeToToday error: $e  raw="$raw"');
      return null;
    }
  }

  /// Case-insensitive field picker
  String? _pickField(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null) return v.toString();
    }
    return null;
  }

  Future<void> _clearSavedState(SharedPreferences prefs) async {
    await prefs.remove(_KEY_GRACE_END_MS);
    await prefs.remove(_KEY_TOTAL_NOTIFS);
    await prefs.remove(_KEY_SENT_NOTIFS);
    await prefs.remove(_KEY_GRACE_ACTIVE);
    isButtonEnabled.value  = false;
    graceSecondsLeft.value = 0;
  }

  /// Next clock-in pe selfie done flag reset karo — taake agla shift end button show kare
  Future<void> resetSelfieDoneFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_KEY_SELFIE_DONE);
    debugPrint('🔄 [$_TAG] Selfie done flag reset — ready for next shift');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET  — drop this anywhere in your widget tree
// ─────────────────────────────────────────────────────────────────────────────

class SelfieGraceButton extends StatelessWidget {
  const SelfieGraceButton({super.key});

  String _formatCountdown(int totalSeconds) {
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool registered = Get.isRegistered<SelfieNotificationPolicyService>();
    debugPrint('🔲 [SelfieGraceButton] build() called — service registered=$registered');

    if (!registered) {
      debugPrint('🔲 [SelfieGraceButton] Service NOT registered → returning SizedBox.shrink()');
      debugPrint('🔲 [SelfieGraceButton] Fix: call Get.put(SelfieNotificationPolicyService()) '
          'in your bindings/main before this widget is rendered.');
      return const SizedBox.shrink();
    }

    final service = SelfieNotificationPolicyService.to;
    debugPrint('🔲 [SelfieGraceButton] Service found. '
        'isButtonEnabled=${service.isButtonEnabled.value}  '
        'isFetching=${service.isFetching.value}  '
        'graceSecondsLeft=${service.graceSecondsLeft.value}');

    return Obx(() {
      final bool enabled  = service.isButtonEnabled.value;
      final int  secs     = service.graceSecondsLeft.value;
      final bool fetching = service.isFetching.value;

      debugPrint('🔲 [SelfieGraceButton] Obx rebuild → enabled=$enabled  fetching=$fetching  secs=$secs');

      if (!enabled && !fetching) {
        debugPrint('🔲 [SelfieGraceButton] Not enabled & not fetching → hidden (SizedBox.shrink)');
        return const SizedBox.shrink();
      }

      const Color activeColor   = Color(0xFF00C6AD);
      const Color disabledColor = Color(0xFF4A5568);

      final Color btnColor   = enabled ? activeColor : disabledColor;
      final String countdown = _formatCountdown(secs);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin : const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child  : Material(
          color       : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child       : InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled
                ? () => service.openCamera(context)
                : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                  colors: [Color(0xFF00B4D8), Color(0xFF00C6AD)],
                  begin  : Alignment.centerLeft,
                  end    : Alignment.centerRight,
                )
                    : null,
                color           : enabled ? null : disabledColor.withOpacity(0.1),
                borderRadius    : BorderRadius.circular(14),
                border          : Border.all(
                  color: btnColor.withOpacity(enabled ? 0.0 : 0.3),
                  width: 1,
                ),
                boxShadow: enabled
                    ? [
                  BoxShadow(
                    color      : activeColor.withOpacity(0.3),
                    blurRadius : 12,
                    offset     : const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width      : 40,
                      height     : 40,
                      decoration : BoxDecoration(
                        color        : (enabled ? Colors.white : btnColor).withOpacity(0.15),
                        borderRadius : BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color : enabled ? Colors.white : btnColor,
                        size  : 20,
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize      : MainAxisSize.min,
                        children          : [
                          Text(
                            'Attendance Selfie',
                            style: TextStyle(
                              fontSize  : 14,
                              fontWeight: FontWeight.w700,
                              color     : enabled ? Colors.white : btnColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            enabled
                                ? 'Grace window: $countdown remaining — tap to capture'
                                : fetching
                                ? 'Fetching policy...'
                                : 'Grace period not active',
                            style: TextStyle(
                              fontSize  : 11,
                              fontWeight: FontWeight.w400,
                              color     : (enabled ? Colors.white : btnColor)
                                  .withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (fetching)
                      SizedBox(
                        width : 18,
                        height: 18,
                        child : CircularProgressIndicator(
                          strokeWidth: 2,
                          color: enabled ? Colors.white : btnColor,
                        ),
                      )
                    else if (enabled)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size : 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}