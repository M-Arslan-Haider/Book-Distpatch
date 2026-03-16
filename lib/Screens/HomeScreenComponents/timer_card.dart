//
// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data'; // ✅ ADDED: Uint8List for photo bytes
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/get.dart';
// import 'package:location/location.dart' as loc;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:image_picker/image_picker.dart'; // ✅ ADDED: For camera
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import '../../AppColors.dart';
// import '../../Database/util.dart';
// import '../../ViewModels/attendance_out_view_model.dart';
// import '../../ViewModels/attendance_view_model.dart';
// import '../../ViewModels/location_view_model.dart';
// import '../../constants.dart';
//
// class TimerCard extends StatefulWidget {
//   const TimerCard({super.key});
//
//   @override
//   State<TimerCard> createState() => _TimerCardState();
// }
//
// class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {
//   // ─── ViewModels ────────────────────────────────────────────────────────────
//   final locationViewModel = Get.find<LocationViewModel>();
//   final attendanceViewModel = Get.find<AttendanceViewModel>();
//   final attendanceOutViewModel = Get.find<AttendanceOutViewModel>();
//
//   // ─── Location / Connectivity ───────────────────────────────────────────────
//   final loc.Location location = loc.Location();
//   final Connectivity _connectivity = Connectivity();
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//
//   // ─── Method Channel (Native monitoring service) ────────────────────────────
//   static const platform =
//   MethodChannel('com.yourapp.attendance/location_monitor');
//
//   // ─── Timer state ───────────────────────────────────────────────────────────
//   Timer? _locationMonitorTimer;
//   Timer? _midnightClockOutTimer;
//   Timer? _permissionCheckTimer;
//   Timer? _localBackupTimer;
//   Timer? _autoSyncTimer;
//   Timer? _distanceUpdateTimer;
//
//   bool _wasLocationAvailable = true;
//   bool _autoClockOutInProgress = false;
//   bool _isMidnightClockOutScheduled = false;
//   bool _isOnline = false;
//   bool _isSyncing = false;
//
//   DateTime? _localClockInTime;
//   String _localElapsedTime = '00:00:00';
//   DateTime? _lastKnownTime; // ✅ ADDED: For date/time change detection
//
//   double _currentDistance = 0.0;
//   int _notificationId = 0;
//
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//
//   // ─── SharedPreferences Keys ───────────────────────────────────────────────
//   static const String KEY_EVENT_TIMESTAMP = 'critical_event_timestamp';
//   static const String KEY_EVENT_REASON = 'critical_event_reason';
//   static const String KEY_EVENT_DISTANCE = 'critical_event_distance';
//   static const String KEY_HAS_CRITICAL_EVENT = 'has_critical_event_pending';
//   static const String KEY_EVENT_LATITUDE = 'critical_event_latitude';
//   static const String KEY_EVENT_LONGITUDE = 'critical_event_longitude';
//   static const String KEY_EVENT_ELAPSED_TIME = 'critical_event_elapsed_time';
//   static const String KEY_IS_TIMER_FROZEN = 'is_timer_frozen';
//   static const String KEY_FROZEN_DISPLAY_TIME = 'frozen_display_time';
//   static const String KEY_GPX_FINALIZED = 'gpx_finalized_at';
//   static const String KEY_GPX_FILE_PATH = 'currentGpxFilePath';
//   static const String KEY_PENDING_GPX_CLOSE = 'pending_gpx_close';
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LIFECYCLE
//   // ══════════════════════════════════════════════════════════════════════════
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     _initializeUrgentNotifications();
//     _initializeFromPersistentState();
//     _startAutoSyncMonitoring();
//     _startDistanceUpdater();
//     _scheduleMidnightClockOut();
//     _startNativeMonitoringService();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkAndProcessCriticalEvent();
//     });
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _restoreEverything();
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _autoSyncTimer?.cancel();
//     _connectivitySubscription?.cancel();
//     _distanceUpdateTimer?.cancel();
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     debugPrint('🔄 [LIFECYCLE] App state: $state');
//     if (state == AppLifecycleState.resumed) {
//       _checkAndProcessCriticalEvent();
//       _restoreEverything();
//       _checkConnectivityAndSync();
//       _rescheduleMidnightClockOut();
//       _startNativeMonitoringService();
//     } else if (state == AppLifecycleState.paused) {
//       debugPrint('✅ [LIFECYCLE] Paused - native service continues monitoring');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // NATIVE MONITORING SERVICE
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _startNativeMonitoringService() async {
//     try {
//       if (Platform.isAndroid) {
//         final bool result = await platform.invokeMethod('startMonitoring');
//         debugPrint('✅ [NATIVE SERVICE] Started: $result');
//       }
//     } on MissingPluginException {
//       debugPrint('ℹ️ [NATIVE SERVICE] Not implemented — skipping');
//     } catch (e) {
//       debugPrint('⚠️ [NATIVE SERVICE] Error starting: $e');
//     }
//   }
//
//   Future<void> _stopNativeMonitoringService() async {
//     try {
//       if (Platform.isAndroid) {
//         final bool result = await platform.invokeMethod('stopMonitoring');
//         debugPrint('🛑 [NATIVE SERVICE] Stopped: $result');
//       }
//     } on MissingPluginException {
//       debugPrint('ℹ️ [NATIVE SERVICE] Not implemented — skipping');
//     } catch (e) {
//       debugPrint('⚠️ [NATIVE SERVICE] Error stopping: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // NOTIFICATIONS
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _initializeUrgentNotifications() async {
//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//
//     const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
//       'urgent_auto_clockout_channel',
//       'URGENT Auto Clockout Notifications',
//       description: 'High-priority channel for auto clockout notifications',
//       importance: Importance.max,
//       enableVibration: true,
//       playSound: true,
//       enableLights: true,
//       ledColor: Colors.red,
//     );
//
//     const AndroidInitializationSettings androidSettings =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const DarwinInitializationSettings iosSettings =
//     DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//
//     const InitializationSettings initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) async {
//         debugPrint('Notification tapped: ${response.payload}');
//       },
//     );
//
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(urgentChannel);
//   }
//
//   Future<void> _showUrgentNotification({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     _notificationId++;
//
//     const AndroidNotificationDetails androidDetails =
//     AndroidNotificationDetails(
//       'urgent_auto_clockout_channel',
//       'URGENT Auto Clockout Notifications',
//       channelDescription: 'High-priority auto clockout notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//       enableVibration: true,
//       playSound: true,
//       category: AndroidNotificationCategory.alarm,
//       visibility: NotificationVisibility.public,
//       color: Colors.red,
//       fullScreenIntent: true,
//       autoCancel: true,
//     );
//
//     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//       interruptionLevel: InterruptionLevel.timeSensitive,
//     );
//
//     const NotificationDetails notificationDetails =
//     NotificationDetails(android: androidDetails, iOS: iosDetails);
//
//     await flutterLocalNotificationsPlugin.show(
//       _notificationId,
//       title,
//       body,
//       notificationDetails,
//       payload: payload,
//     );
//
//     debugPrint('🔔 [NOTIFICATION] Sent: $title');
//
//     if (mounted) {
//       Get.snackbar(
//         title,
//         body,
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Colors.red.shade700,
//         colorText: Colors.white,
//         duration: const Duration(seconds: 5),
//         icon: const Icon(Icons.warning, color: Colors.white),
//       );
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // GPX FILE FINALIZATION (ADDED from File 1)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _finalizeGPXFile({
//     required DateTime eventTime,
//     required double finalDistance,
//     required double latitude,
//     required double longitude,
//   }) async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? gpxFilePath = prefs.getString(KEY_GPX_FILE_PATH);
//
//       if (gpxFilePath == null || gpxFilePath.isEmpty) {
//         debugPrint('⚠️ [GPX FINALIZE] No GPX file path found');
//         return;
//       }
//
//       File gpxFile = File(gpxFilePath);
//       if (!await gpxFile.exists()) {
//         debugPrint('⚠️ [GPX FINALIZE] File does not exist: $gpxFilePath');
//         return;
//       }
//
//       String content = await gpxFile.readAsString();
//       content = content.replaceAll('</trkseg>\n  </trk>\n</gpx>', '');
//       content = content.replaceAll('</trkseg></trk></gpx>', '');
//
//       String finalTrackPoint = '''
//     <trkpt lat="$latitude" lon="$longitude">
//       <time>${eventTime.toIso8601String()}</time>
//       <desc>Auto-clockout: Location tracking stopped</desc>
//     </trkpt>''';
//
//       String finalContent =
//       content.replaceAll('</trkseg>', '$finalTrackPoint\n    </trkseg>');
//
//       if (!finalContent.contains('</trk>')) {
//         finalContent += '\n  </trk>\n</gpx>';
//       }
//       if (!finalContent.contains('</gpx>')) {
//         finalContent += '\n</gpx>';
//       }
//
//       await gpxFile.writeAsString(finalContent, flush: true);
//
//       await prefs.setString(KEY_GPX_FINALIZED, eventTime.toIso8601String());
//       await prefs.setBool(KEY_PENDING_GPX_CLOSE, false);
//       await prefs.setString('gpx_finalized_time', eventTime.toIso8601String());
//       await prefs.setDouble('gpx_final_distance', finalDistance);
//       await prefs.setString('gpx_final_file', gpxFilePath);
//       await prefs.setBool('hasPendingGpxData', true);
//
//       debugPrint('✅ [GPX FINALIZE] File finalized at $eventTime');
//       debugPrint('✅ [GPX FINALIZE] Distance: $finalDistance km');
//     } catch (e) {
//       debugPrint('❌ [GPX FINALIZE] Error: $e');
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // CRITICAL EVENT HANDLING (Enhanced from File 1)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _checkAndProcessCriticalEvent() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool hasCriticalEvent = prefs.getBool(KEY_HAS_CRITICAL_EVENT) ?? false;
//     bool isTimerFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//     String? bgPayloadStr = prefs.getString('bg_clockout_payload');
//
//     if (!hasCriticalEvent &&
//         !isTimerFrozen &&
//         (bgPayloadStr == null || bgPayloadStr.isEmpty)) {
//       return;
//     }
//
//     debugPrint('🚨 [CRITICAL EVENT] Found pending event on startup');
//
//     _localElapsedTime = '00:00:00';
//     attendanceViewModel.elapsedTime.value = '00:00:00';
//     _localBackupTimer?.cancel();
//     _localBackupTimer = null;
//     if (mounted) setState(() {});
//
//     bool needsGpxFinalization = prefs.getBool(KEY_PENDING_GPX_CLOSE) ?? false;
//
//     String? eventTimeStr = prefs.getString(KEY_EVENT_TIMESTAMP);
//     String? eventReason = prefs.getString(KEY_EVENT_REASON);
//     double? eventDistance = prefs.getDouble(KEY_EVENT_DISTANCE);
//     double? eventLat = prefs.getDouble(KEY_EVENT_LATITUDE);
//     double? eventLng = prefs.getDouble(KEY_EVENT_LONGITUDE);
//
//     if (eventTimeStr != null) {
//       DateTime eventTime = DateTime.parse(eventTimeStr);
//       debugPrint(
//           '🚨 [CRITICAL EVENT] Occurred at: $eventTime, Reason: $eventReason');
//
//       if (needsGpxFinalization) {
//         await _finalizeGPXFile(
//           eventTime: eventTime,
//           finalDistance: eventDistance ?? 0.0,
//           latitude: eventLat ?? 0.0,
//           longitude: eventLng ?? 0.0,
//         );
//       }
//
//       Get.snackbar(
//         '⚠️ Auto Clock-Out Occurred',
//         'Event: ${_getReasonMessage(eventReason ?? 'unknown')}\nTime: ${DateFormat('HH:mm:ss').format(eventTime)}',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Colors.orange.shade700,
//         colorText: Colors.white,
//         duration: const Duration(seconds: 5),
//         icon: const Icon(Icons.warning, color: Colors.white),
//       );
//
//       await _syncCriticalEventData(
//         eventTime: eventTime,
//         reason: eventReason ?? 'unknown',
//         distance: eventDistance ?? 0.0,
//         latitude: eventLat ?? 0.0,
//         longitude: eventLng ?? 0.0,
//       );
//
//       await _clearCriticalEventData();
//       await prefs.remove('bg_clockout_payload');
//       _triggerAutoSync();
//     }
//   }
//
//   String? _extractJsonValue(String json, String key) {
//     try {
//       final pattern = '"$key":"';
//       int start = json.indexOf(pattern);
//       if (start == -1) return null;
//       start += pattern.length;
//       int end = json.indexOf('"', start);
//       if (end == -1) return null;
//       return json.substring(start, end);
//     } catch (_) {
//       return null;
//     }
//   }
//
//   Future<void> _syncCriticalEventData({
//     required DateTime eventTime,
//     required String reason,
//     required double distance,
//     required double latitude,
//     required double longitude,
//   }) async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       final String empId = _safePrefsString(prefs, 'emp_id');
//
//       await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
//       await prefs.setDouble('fastClockOutDistance', distance);
//       await prefs.setString('fastClockOutReason', reason);
//       await prefs.setBool('hasFastClockOutData', true);
//       await prefs.setBool('clockOutPending', true);
//       await prefs.setString(
//           'pendingGpxDate', DateFormat('dd-MM-yyyy').format(eventTime));
//
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         empId: empId,
//         clockOutTime: eventTime,
//         totalDistance: distance,
//         isAuto: true,
//         reason: reason,
//       );
//
//       debugPrint(
//           '✅ [SYNC] Critical event data saved. empId=$empId, timestamp=$eventTime');
//       _triggerAutoSync();
//     } catch (e) {
//       debugPrint('❌ [SYNC] Error: $e');
//     }
//   }
//
//   Future<void> _saveCriticalEventData({
//     required DateTime eventTime,
//     required String reason,
//     required double distance,
//     required double latitude,
//     required double longitude,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String elapsedAtEvent = _localElapsedTime;
//
//     await prefs.setBool(KEY_HAS_CRITICAL_EVENT, true);
//     await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
//     await prefs.setString(KEY_EVENT_TIMESTAMP, eventTime.toIso8601String());
//     await prefs.setString(KEY_EVENT_REASON, reason);
//     await prefs.setDouble(KEY_EVENT_DISTANCE, distance);
//     await prefs.setDouble(KEY_EVENT_LATITUDE, latitude);
//     await prefs.setDouble(KEY_EVENT_LONGITUDE, longitude);
//     await prefs.setString(KEY_FROZEN_DISPLAY_TIME, '00:00:00');
//     await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);
//
//     String? gpxPath = prefs.getString(KEY_GPX_FILE_PATH);
//     if (gpxPath != null) {
//       await prefs.setString('event_gpx_file_path', gpxPath);
//     }
//
//     await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
//     await prefs.setDouble('fastClockOutDistance', distance);
//     await prefs.setString('fastClockOutReason', reason);
//     await prefs.setBool('hasFastClockOutData', true);
//     await prefs.setBool('clockOutPending', true);
//     await prefs.setBool('isClockedIn', false);
//
//     await prefs.setString(
//         'bg_clockout_payload',
//         '{"timestamp":"${eventTime.toIso8601String()}","reason":"$reason",'
//             '"elapsed_at_event":"$elapsedAtEvent","distance":$distance,'
//             '"latitude":$latitude,"longitude":$longitude,"source":"flutter_foreground"}');
//
//     debugPrint('💾 [CRITICAL EVENT] Saved at: $eventTime, reason: $reason');
//   }
//
//   Future<void> _clearCriticalEventData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.remove(KEY_HAS_CRITICAL_EVENT);
//     await prefs.remove(KEY_EVENT_TIMESTAMP);
//     await prefs.remove(KEY_EVENT_REASON);
//     await prefs.remove(KEY_EVENT_DISTANCE);
//     await prefs.remove(KEY_EVENT_LATITUDE);
//     await prefs.remove(KEY_EVENT_LONGITUDE);
//     debugPrint('🧹 [CLEAR] Critical event data cleared');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LOCATION MONITORING
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _startLocationMonitoring() {
//     _locationMonitorTimer?.cancel();
//     _locationMonitorTimer =
//         Timer.periodic(const Duration(seconds: 30), (_) async {
//           if (!attendanceViewModel.isClockedIn.value) return;
//           await _updateCurrentDistance();
//         });
//     debugPrint('✅ [LOCATION MONITOR] Started');
//   }
//
//   void _stopLocationMonitoring() {
//     _locationMonitorTimer?.cancel();
//     _locationMonitorTimer = null;
//     debugPrint('🛑 [LOCATION MONITOR] Stopped');
//   }
//
//   void _startPermissionMonitoring() {
//     _permissionCheckTimer?.cancel();
//     _permissionCheckTimer = null;
//     _lastKnownTime = null; // ✅ Reset for date/time detection
//     _wasLocationAvailable = true;
//
//     _permissionCheckTimer =
//         Timer.periodic(const Duration(seconds: 2), (timer) async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//           if (isFrozen) {
//             timer.cancel();
//             return;
//           }
//
//           if (!attendanceViewModel.isClockedIn.value) return;
//
//           // Check location services
//           bool locationEnabled = await attendanceViewModel.isLocationAvailable();
//           if (_wasLocationAvailable && !locationEnabled) {
//             debugPrint('📍 [MONITOR] Location OFF - auto clockout');
//
//             DateTime eventTime = DateTime.now();
//             double currentDist = await _getCurrentDistance();
//             double lat = locationViewModel.globalLatitude1.value;
//             double lng = locationViewModel.globalLongitude1.value;
//
//             await _saveCriticalEventData(
//               eventTime: eventTime,
//               reason: 'location_off_auto',
//               distance: currentDist,
//               latitude: lat,
//               longitude: lng,
//             );
//
//             await _showUrgentNotification(
//               title: '⚠️ LOCATION TURNED OFF',
//               body: 'Auto clockout triggered because location was turned off',
//               payload: 'location_off_auto',
//             );
//
//             await _handleAutoClockOut(
//               reason: 'location_off_auto',
//               context: context,
//               eventTime: eventTime,
//             );
//             return;
//           }
//           _wasLocationAvailable = locationEnabled;
//
//           // ✅ ADDED: Check date/time change (from File 1)
//           await _checkForDateTimeChange();
//         });
//   }
//
//   // ✅ ADDED: Date/time change detection (from File 1)
//   Future<void> _checkForDateTimeChange() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//     if (isFrozen || !attendanceViewModel.isClockedIn.value) return;
//
//     final now = DateTime.now();
//     if (_lastKnownTime == null) {
//       _lastKnownTime = now;
//       return;
//     }
//
//     final expectedDiff = now.difference(_lastKnownTime!).inSeconds;
//     if (expectedDiff < -30 || expectedDiff > 120) {
//       debugPrint(
//           '⏰ [IN-APP] Date/Time change detected! Diff: ${expectedDiff}s');
//
//       DateTime eventTime = _lastKnownTime!;
//       _lastKnownTime = null;
//       _permissionCheckTimer?.cancel();
//       _permissionCheckTimer = null;
//
//       double currentDist = await _getCurrentDistance();
//       double lat = locationViewModel.globalLatitude1.value;
//       double lng = locationViewModel.globalLongitude1.value;
//
//       await _saveCriticalEventData(
//         eventTime: eventTime,
//         reason: 'time_changed_auto',
//         distance: currentDist,
//         latitude: lat,
//         longitude: lng,
//       );
//
//       await _showUrgentNotification(
//         title: '⚠️ DATE/TIME CHANGED',
//         body: 'Auto clockout triggered because device date/time was changed',
//         payload: 'time_changed_auto',
//       );
//
//       await _handleAutoClockOut(
//         reason: 'time_changed_auto',
//         context: context,
//         eventTime: eventTime,
//       );
//       return;
//     }
//
//     _lastKnownTime = now;
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // MIDNIGHT AUTO CLOCKOUT (11:58 PM)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _scheduleMidnightClockOut() {
//     SharedPreferences.getInstance().then((prefs) {
//       bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//       if (isFrozen || !attendanceViewModel.isClockedIn.value) return;
//
//       _midnightClockOutTimer?.cancel();
//
//       final now = DateTime.now();
//       final scheduledTime = DateTime(now.year, now.month, now.day, 23, 58);
//
//       Duration timeUntil = now.isAfter(scheduledTime)
//           ? scheduledTime.add(const Duration(days: 1)).difference(now)
//           : scheduledTime.difference(now);
//
//       _midnightClockOutTimer = Timer(timeUntil, () async {
//         if (attendanceViewModel.isClockedIn.value) {
//           debugPrint('⏰ [MIDNIGHT] Auto clockout at 11:58 PM');
//
//           DateTime eventTime = DateTime.now();
//           double currentDist = await _getCurrentDistance();
//           double lat = locationViewModel.globalLatitude1.value;
//           double lng = locationViewModel.globalLongitude1.value;
//
//           await _saveCriticalEventData(
//             eventTime: eventTime,
//             reason: 'midnight_auto',
//             distance: currentDist,
//             latitude: lat,
//             longitude: lng,
//           );
//
//           await _showUrgentNotification(
//             title: '⚠️ AUTO CLOCKOUT - 11:58 PM',
//             body:
//             'You have been automatically clocked out\nDuration: $_localElapsedTime',
//             payload: 'midnight_auto',
//           );
//
//           await _handleAutoClockOut(
//             reason: 'midnight_auto',
//             context: context,
//             eventTime: eventTime,
//           );
//         }
//       });
//
//       _isMidnightClockOutScheduled = true;
//       debugPrint(
//           '⏰ [MIDNIGHT] Scheduled for ${scheduledTime.hour}:${scheduledTime.minute}');
//     });
//   }
//
//   void _rescheduleMidnightClockOut() {
//     SharedPreferences.getInstance().then((prefs) {
//       bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//       if (!isFrozen && attendanceViewModel.isClockedIn.value) {
//         _scheduleMidnightClockOut();
//       }
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // AUTO CLOCKOUT HANDLER (Enhanced with GPX finalization)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _handleAutoClockOut({
//     required String reason,
//     required BuildContext context,
//     DateTime? eventTime,
//   }) async {
//     if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) {
//       return;
//     }
//     _autoClockOutInProgress = true;
//
//     DateTime clockOutTime = eventTime ?? DateTime.now();
//     double finalLat = locationViewModel.globalLatitude1.value;
//     double finalLng = locationViewModel.globalLongitude1.value;
//     double finalDistance = _currentDistance > 0 ? _currentDistance : 0.0;
//
//     debugPrint('⚡ [AUTO CLOCKOUT] Reason: $reason at $clockOutTime');
//
//     try {
//       // Stop all monitors
//       _stopLocationMonitoring();
//       _localBackupTimer?.cancel();
//       _midnightClockOutTimer?.cancel();
//       _permissionCheckTimer?.cancel();
//       _lastKnownTime = null;
//
//       // Stop background service
//       final service = FlutterBackgroundService();
//       service.invoke('stopService');
//
//       await _stopNativeMonitoringService();
//
//       try {
//         await location.enableBackgroundMode(enable: false);
//       } catch (e) {
//         debugPrint('⚠️ Background mode disable error: $e');
//       }
//
//       // ✅ ADDED: Finalize GPX file with exact event data
//       await _finalizeGPXFile(
//         eventTime: clockOutTime,
//         finalDistance: finalDistance,
//         latitude: finalLat,
//         longitude: finalLng,
//       );
//
//       // Persist clock-out state
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isClockedIn', false);
//       await prefs.setDouble('fastClockOutDistance', finalDistance);
//       await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
//       await prefs.setBool('clockOutPending', true);
//       await prefs.setBool('hasFastClockOutData', true);
//       await prefs.setDouble('pendingLatOut', finalLat);
//       await prefs.setDouble('pendingLngOut', finalLng);
//       await prefs.setString(
//           'pendingAddress', locationViewModel.shopAddress.value);
//
//       // Reset UI state
//       if (mounted) {
//         setState(() {
//           _localElapsedTime = '00:00:00';
//           _currentDistance = 0.0;
//           _localClockInTime = null;
//         });
//       }
//
//       attendanceViewModel.isClockedIn.value = false;
//       locationViewModel.isClockedIn.value = false;
//       attendanceViewModel.stopElapsedTimer();
//
//       final String empId = _safePrefsString(prefs, 'emp_id');
//
//       // Save attendance out record with empId
//       await attendanceOutViewModel.fastSaveAttendanceOut(
//         empId: empId,
//         clockOutTime: clockOutTime,
//         totalDistance: finalDistance,
//         isAuto: true,
//         reason: reason,
//       );
//
//       await attendanceViewModel.clearClockInState();
//
//       _triggerAutoSync();
//
//       if (mounted) {
//         Get.snackbar(
//           'Auto Clock-Out',
//           _getReasonMessage(reason),
//           snackPosition: SnackPosition.TOP,
//           backgroundColor: Colors.orange.shade700,
//           colorText: Colors.white,
//           duration: const Duration(seconds: 5),
//         );
//       }
//     } catch (e) {
//       debugPrint('❌ [AUTO CLOCKOUT] Error: $e');
//     } finally {
//       _autoClockOutInProgress = false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // DISTANCE TRACKING
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _startDistanceUpdater() {
//     _distanceUpdateTimer =
//         Timer.periodic(const Duration(seconds: 5), (timer) async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//           if (isFrozen) {
//             timer.cancel();
//             return;
//           }
//           if (attendanceViewModel.isClockedIn.value) {
//             await _updateCurrentDistance();
//           }
//         });
//   }
//
//   Future<void> _updateCurrentDistance() async {
//     try {
//       double distance = await locationViewModel.getImmediateDistance();
//       if (mounted) {
//         setState(() {
//           _currentDistance = distance;
//         });
//       }
//       attendanceViewModel.updateCachedDistance(distance);
//     } catch (e) {
//       debugPrint('❌ Distance update error: $e');
//     }
//   }
//
//   Future<double> _getCurrentDistance() async {
//     if (_currentDistance > 0) return _currentDistance;
//     try {
//       return await locationViewModel.getImmediateDistance();
//     } catch (e) {
//       return 0.0;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // AUTO SYNC
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _startAutoSyncMonitoring() {
//     _connectivitySubscription = _connectivity.onConnectivityChanged
//         .listen((List<ConnectivityResult> results) {
//       bool wasOnline = _isOnline;
//       _isOnline = results.isNotEmpty &&
//           results.any((r) => r != ConnectivityResult.none);
//
//       debugPrint('🌐 [CONNECTIVITY] ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
//
//       if (_isOnline && !wasOnline && !_isSyncing) {
//         debugPrint('🔄 [AUTO-SYNC] Internet connected - syncing...');
//         _triggerAutoSync();
//       }
//     });
//
//     _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
//       if (!_isSyncing) _checkConnectivityAndSync();
//     });
//
//     _checkConnectivityAndSync();
//   }
//
//   void _checkConnectivityAndSync() async {
//     if (_isSyncing) return;
//     try {
//       var results = await _connectivity.checkConnectivity();
//       bool wasOnline = _isOnline;
//       _isOnline = results.isNotEmpty &&
//           results.any((r) => r != ConnectivityResult.none);
//
//       if (_isOnline && !wasOnline && !_isSyncing) {
//         _triggerAutoSync();
//       }
//     } catch (e) {
//       debugPrint('❌ [CONNECTIVITY] Error: $e');
//     }
//   }
//
//   void _triggerAutoSync() async {
//     if (_isSyncing) return;
//     _isSyncing = true;
//     debugPrint('🔒 [AUTO-SYNC] Starting...');
//
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//
//       bool hasPendingGpx = prefs.getBool('hasPendingGpxData') ?? false;
//       String? pendingGpxDate = prefs.getString('pendingGpxDate');
//       DateTime? eventDate;
//
//       if (pendingGpxDate != null && pendingGpxDate.isNotEmpty) {
//         try {
//           eventDate = DateFormat('dd-MM-yyyy').parse(pendingGpxDate);
//           debugPrint('📅 [AUTO-SYNC] Using pending GPX date: $pendingGpxDate');
//         } catch (e) {
//           debugPrint('⚠️ [AUTO-SYNC] Error parsing pendingGpxDate: $e');
//         }
//       }
//
//       Get.snackbar(
//         'Syncing Data',
//         hasPendingGpx
//             ? 'Syncing attendance & GPS data...'
//             : 'Syncing attendance data...',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Color(0xFF1A2B6D),
//         colorText: Colors.white,
//         duration: const Duration(seconds: 3),
//       );
//
//       // ✅ Consolidate and save GPX with correct date
//       if (hasPendingGpx) {
//         try {
//           if (eventDate != null) {
//             await locationViewModel
//                 .consolidateDailyGPXDataForDate(eventDate);
//             await locationViewModel
//                 .saveLocationFromConsolidatedFileForDate(eventDate);
//           } else {
//             await locationViewModel.consolidateDailyGPXData();
//             await locationViewModel.saveLocationFromConsolidatedFile();
//           }
//           debugPrint('✅ [AUTO-SYNC] GPX data processed');
//         } catch (e) {
//           debugPrint('⚠️ [AUTO-SYNC] GPX processing error: $e');
//         }
//       }
//
//       // ✅ Sync all unposted attendance records
//       await attendanceViewModel.syncUnposted();
//       await attendanceOutViewModel.syncUnposted();
//
//       // Clear pending flags
//       await prefs.setBool('hasPendingClockOutData', false);
//       await prefs.setBool('clockOutPending', false);
//       await prefs.setBool('hasFastClockOutData', false);
//       await prefs.setBool('hasPendingGpxData', false);
//       await prefs.remove(KEY_PENDING_GPX_CLOSE);
//       await prefs.remove('pendingGpxDate');
//
//       debugPrint('✅ [AUTO-SYNC] Completed');
//
//       if (mounted) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           Get.snackbar(
//             'Sync Complete',
//             'All data synchronized to server',
//             snackPosition: SnackPosition.BOTTOM,
//             backgroundColor: Colors.green,
//             colorText: Colors.white,
//             duration: const Duration(seconds: 2),
//           );
//         });
//       }
//     } catch (e) {
//       debugPrint('❌ [AUTO-SYNC] Error: $e');
//     } finally {
//       _isSyncing = false;
//       debugPrint('🔓 [AUTO-SYNC] Unlocked');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // STATE RESTORATION
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _initializeFromPersistentState() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool isClockedIn = prefs.getBool(prefIsClockedIn) ?? false;
//     bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//
//     debugPrint('🔄 [INIT] isClockedIn=$isClockedIn, isFrozen=$isFrozen');
//
//     if (isFrozen) {
//       _localElapsedTime = '00:00:00';
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       locationViewModel.isClockedIn.value = false;
//       attendanceViewModel.isClockedIn.value = false;
//       if (mounted) setState(() {});
//       return;
//     }
//
//     locationViewModel.isClockedIn.value = isClockedIn;
//     attendanceViewModel.isClockedIn.value = isClockedIn;
//
//     if (isClockedIn) {
//       _startBackgroundServices();
//       _startLocationMonitoring();
//       _startLocalBackupTimer();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//       debugPrint('✅ [INIT] Full clocked-in state restored');
//     }
//
//     if (mounted) setState(() {});
//   }
//
//   void _restoreEverything() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool isClockedIn = prefs.getBool(prefIsClockedIn) ?? false;
//     bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//
//     if (isFrozen) {
//       _localElapsedTime = '00:00:00';
//       attendanceViewModel.elapsedTime.value = '00:00:00';
//       locationViewModel.isClockedIn.value = false;
//       attendanceViewModel.isClockedIn.value = false;
//       if (mounted) setState(() {});
//       return;
//     }
//
//     if (isClockedIn) {
//       locationViewModel.isClockedIn.value = true;
//       attendanceViewModel.isClockedIn.value = true;
//
//       _startLocalBackupTimer();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//
//       if (mounted) setState(() {});
//       debugPrint('✅ [RESTORE] Everything restored');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LOCAL BACKUP TIMER
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _startLocalBackupTimer() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//     if (isFrozen) return;
//
//     String? clockInTimeString = prefs.getString(prefClockInTime);
//     if (clockInTimeString == null) return;
//
//     _localClockInTime = DateTime.parse(clockInTimeString);
//     _localBackupTimer?.cancel();
//
//     _localBackupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       SharedPreferences.getInstance().then((prefs) {
//         bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
//         if (isFrozen) {
//           timer.cancel();
//           return;
//         }
//       });
//
//       if (_localClockInTime == null) return;
//
//       final duration = DateTime.now().difference(_localClockInTime!);
//       String twoDigits(int n) => n.toString().padLeft(2, '0');
//       _localElapsedTime =
//       '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
//
//       attendanceViewModel.elapsedTime.value = _localElapsedTime;
//
//       SharedPreferences.getInstance().then((prefs) {
//         prefs.setString('elapsed_time', _localElapsedTime);
//       });
//
//       if (mounted) setState(() {});
//     });
//
//     debugPrint('✅ [BACKUP TIMER] Started');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // BACKGROUND SERVICES
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _startBackgroundServices() async {
//     try {
//       debugPrint('🛰 [BACKGROUND] Starting services...');
//       final service = FlutterBackgroundService();
//       await location.enableBackgroundMode(enable: true);
//       service.startService().catchError(
//               (e) => debugPrint('Service start error: $e'));
//       location
//           .changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high)
//           .catchError((e) => debugPrint('Location settings error: $e'));
//       debugPrint('✅ [BACKGROUND] Services started');
//     } catch (e) {
//       debugPrint('⚠ [BACKGROUND] Error: $e');
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LOCATION PERMISSION CHECK
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _checkLocationPermission(BuildContext context) async {
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       await showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (ctx) => Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.location_off,
//                     size: 50, color: Colors.redAccent),
//                 const SizedBox(height: 15),
//                 const Text('Location Permission Required',
//                     style: TextStyle(
//                         fontSize: 18, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 10),
//                 const Text(
//                   'We need location access to continue.\nPlease enable location permission from app settings.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.grey),
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextButton(
//                         onPressed: () => Navigator.of(ctx).pop(),
//                         child: const Text('Cancel',
//                             style: TextStyle(color: Colors.grey)),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.blueGrey,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12)),
//                         ),
//                         onPressed: () async {
//                           Navigator.of(ctx).pop();
//                           await Geolocator.openAppSettings();
//                         },
//                         child: const Text('Open Settings',
//                             style: TextStyle(color: Colors.white)),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//       return false;
//     }
//     return true;
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // 🚀 ULTRA-FAST CLOCK IN - WITH CAMERA INTEGRATION
//   // ══════════════════════════════════════════════════════════════════════════
//
//   // ✅ ADDED: Camera capture function (from File 1)
//   Future<Uint8List?> _captureClockInPhoto() async {
//     try {
//       final ImagePicker picker = ImagePicker();
//       final XFile? photo = await picker.pickImage(
//         source: ImageSource.camera,
//         preferredCameraDevice: CameraDevice.front,
//         imageQuality: 80,
//       );
//
//       if (photo == null) {
//         debugPrint('📷 [CAMERA] User cancelled — no photo taken');
//         return null;
//       }
//
//       debugPrint('📷 [CAMERA] Photo path: ${photo.path}');
//
//       // ✅ XFile.readAsBytes() works for BOTH content:// AND file:// URIs.
//       final Uint8List bytes = await photo.readAsBytes();
//       debugPrint('📸 [CAMERA] ✅ ${bytes.length} bytes read via XFile.readAsBytes()');
//
//       if (bytes.isEmpty) {
//         debugPrint('❌ [CAMERA] readAsBytes() returned 0 bytes — path: ${photo.path}');
//         return null;
//       }
//
//       return bytes;
//     } catch (e) {
//       debugPrint('❌ [CAMERA] Error capturing / reading photo bytes: $e');
//       return null;
//     }
//   }
//
//   Future<void> _handleClockIn(BuildContext context) async {
//     debugPrint('🎯 [TIMERCARD] ===== CLOCK-IN STARTED =====');
//     final clockInStart = DateTime.now();
//
//     // 1. CAMERA CAPTURE
//     final Uint8List? clockInPhotoBytes = await _captureClockInPhoto();
//
//     if (clockInPhotoBytes == null || clockInPhotoBytes.isEmpty) {
//       Get.snackbar(
//         '📷 Photo Required',
//         'Please capture a photo to clock in',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Colors.orange.shade700,
//         colorText: Colors.white,
//         duration: const Duration(seconds: 3),
//         icon: const Icon(Icons.camera_alt, color: Colors.white),
//       );
//       return;
//     }
//
//     debugPrint('📸 [TIMERCARD] ✅ clockInPhotoBytes ready: ${clockInPhotoBytes.length} bytes');
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(
//         child: SizedBox(
//           width: 80,
//           height: 80,
//           child: CircularProgressIndicator(
//             strokeWidth: 3,
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//           ),
//         ),
//       ),
//     );
//
//     try {
//       final results = await Future.wait([
//         SharedPreferences.getInstance(),
//         _checkLocationPermission(context),
//         attendanceViewModel.isLocationAvailable(),
//       ]);
//
//       final prefs = results[0] as SharedPreferences;
//       final hasPermission = results[1] as bool;
//       final locationAvailable = results[2] as bool;
//
//       if (!hasPermission || !locationAvailable) {
//         Navigator.of(context).pop();
//         Get.snackbar(
//           'Location Required',
//           'Please enable Location Services and Permissions',
//           snackPosition: SnackPosition.TOP,
//           backgroundColor: Colors.red.shade700,
//           colorText: Colors.white,
//         );
//         return;
//       }
//
//       await prefs.remove(KEY_IS_TIMER_FROZEN);
//       await prefs.remove(KEY_FROZEN_DISPLAY_TIME);
//       _lastKnownTime = null; // Reset for date/time detection
//
//       final String empId = _safePrefsString(prefs, 'emp_id');
//
//       final String empName = _safePrefsStringFallback(prefs, [
//         'emp_name',
//         'empName',
//         'employee_name',
//         'name',
//         'userName',
//         'user_name',
//       ]);
//
//       final String job = _safePrefsStringFallback(prefs, [
//         'job',
//         'designation',
//         'role',
//         'emp_job',
//         'position',
//         'jobTitle',
//       ]);
//
//       final String city = _safePrefsStringFallback(prefs, [
//         'city',
//         'emp_city',
//         'location',
//       ]);
//
//       debugPrint(
//           '👤 [CLOCK-IN] empId=$empId | empName=$empName | job=$job | city=$city');
//
//       final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
//       final downloadDirectory = await getDownloadsDirectory();
//       final filePath = '${downloadDirectory!.path}/track_${empId}_$date.gpx';
//
//       await prefs.setString(KEY_GPX_FILE_PATH, filePath);
//
//       // ✅ Pass photo bytes to clockIn
//       await attendanceViewModel.clockIn(
//         empId: empId,
//         empName: empName,
//         job: job,
//         city: city,
//         photoBytes: clockInPhotoBytes, // Pass the captured photo bytes
//       );
//
//       setState(() {
//         _localElapsedTime = '00:00:00';
//         locationViewModel.isClockedIn.value = true;
//         attendanceViewModel.isClockedIn.value = true;
//       });
//
//       _startLocalBackupTimer();
//       _scheduleMidnightClockOut();
//       _startPermissionMonitoring();
//
//       if (Navigator.of(context).canPop()) {
//         Navigator.of(context).pop();
//       }
//
//       Get.snackbar(
//         '✅ Clocked In',
//         'GPS tracking started',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Color(0xFF1A2B6D),
//         colorText: Colors.white,
//         duration: const Duration(seconds: 2),
//       );
//
//       debugPrint(
//           '✅ [CLOCK-IN] UI completed in ${DateTime.now().difference(clockInStart).inMilliseconds}ms');
//
//       _runPostClockInTasks(filePath);
//     } catch (e) {
//       debugPrint('❌ [CLOCK-IN] Error: $e');
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//
//       Get.snackbar(
//         'Error',
//         'Failed to clock in: ${e.toString()}',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     }
//   }
//
//   void _runPostClockInTasks(String filePath) {
//     Future.microtask(() async {
//       try {
//         _createGpxFileInBackground(filePath);
//         _startBackgroundServices();
//         _startNativeMonitoringService();
//         _updateCurrentDistance();
//
//         debugPrint('✅ [CLOCK-IN] Background tasks completed');
//       } catch (e) {
//         debugPrint('⚠️ [CLOCK-IN] Background task error: $e');
//       }
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // 🚀 ULTRA-FAST CLOCK OUT WITH GPX SAVE
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<void> _handleClockOut(BuildContext context) async {
//     debugPrint('🎯 [TIMERCARD] ===== CLOCK-OUT STARTED =====');
//
//     // ✅ CAPTURE DISTANCE FIRST before any reset
//     final double capturedDistance = _currentDistance > 0
//         ? _currentDistance
//         : await locationViewModel.getImmediateDistance();
//
//     debugPrint('📏 [CLOCK-OUT] Captured distance: ${capturedDistance.toStringAsFixed(3)} km');
//
//     setState(() {
//       _localElapsedTime = '00:00:00';
//       _currentDistance = 0.0;
//     });
//
//     _stopLocationMonitoring();
//     _localBackupTimer?.cancel();
//     _midnightClockOutTimer?.cancel();
//     _permissionCheckTimer?.cancel();
//     _localClockInTime = null;
//     _lastKnownTime = null;
//
//     attendanceViewModel.stopElapsedTimer();
//     attendanceViewModel.isClockedIn.value = false;
//     locationViewModel.isClockedIn.value = false;
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(
//         child: SizedBox(
//           width: 80,
//           height: 80,
//           child: CircularProgressIndicator(
//             strokeWidth: 3,
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
//           ),
//         ),
//       ),
//     );
//
//     try {
//       final clockOutTime = DateTime.now();
//       final finalDistance = capturedDistance;
//
//       final prefs = await SharedPreferences.getInstance();
//       await Future.wait([
//         prefs.remove(KEY_IS_TIMER_FROZEN),
//         prefs.remove(KEY_FROZEN_DISPLAY_TIME),
//         prefs.remove(KEY_PENDING_GPX_CLOSE),
//         prefs.remove('hasPendingGpxData'),
//         prefs.setBool('isClockedIn', false),
//         prefs.setDouble('fastClockOutDistance', finalDistance),
//         prefs.setString('fastClockOutTime', clockOutTime.toIso8601String()),
//         prefs.setBool('clockOutPending', true),
//         prefs.setBool('hasFastClockOutData', true),
//       ]);
//
//       final String empId = _safePrefsString(prefs, 'emp_id');
//       debugPrint('👤 [CLOCK-OUT] empId=$empId | distance=${finalDistance.toStringAsFixed(3)} km');
//
//       if (Navigator.of(context).canPop()) {
//         Navigator.of(context).pop();
//       }
//
//       Get.snackbar(
//         '✅ Clocked Out',
//         'Data saved locally',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Color(0xFF1A2B6D),
//         colorText: Colors.white,
//         duration: const Duration(seconds: 2),
//       );
//
//       unawaited(attendanceOutViewModel.fastSaveAttendanceOut(
//         empId: empId,
//         clockOutTime: clockOutTime,
//         totalDistance: finalDistance,
//         isAuto: false,
//         reason: 'manual_clockout',
//       ));
//
//       _runPostClockOutTasks(clockOutTime, finalDistance);
//     } catch (e) {
//       debugPrint('❌ [CLOCK-OUT] Error: $e');
//       if (Navigator.of(context).canPop()) Navigator.of(context).pop();
//       Get.snackbar(
//         'Clock Out Issue',
//         'Data saved locally, sync pending',
//         snackPosition: SnackPosition.TOP,
//         backgroundColor: Colors.orange,
//         colorText: Colors.white,
//       );
//     }
//   }
//
//   /// 🔥 BACKGROUND TASKS AFTER CLOCK-OUT
//   void _runPostClockOutTasks(DateTime clockOutTime, double distance) {
//     Future.microtask(() async {
//       try {
//         debugPrint('🏁 [CLOCK-OUT] Background: Saving GPX location data...');
//
//         // ✅ STEP 1: Consolidate all GPX segments into one daily file
//         await locationViewModel.consolidateDailyGPXDataForDate(clockOutTime);
//         debugPrint('✅ [GPX] Consolidated GPX file');
//
//         // ✅ STEP 2: Save consolidated GPX to location table + sync to API
//         await locationViewModel
//             .saveLocationFromConsolidatedFileForDate(clockOutTime);
//         debugPrint('✅ [GPX] Saved LocationModel to DB + API');
//
//         // ✅ STEP 3: Stop background services
//         final service = FlutterBackgroundService();
//         service.invoke('stopService');
//         await _stopNativeMonitoringService();
//
//         try {
//           await location.enableBackgroundMode(enable: false);
//         } catch (e) {
//           debugPrint('⚠️ Background mode disable error: $e');
//         }
//
//         // ✅ STEP 4: Trigger sync to post data to server
//         _triggerAutoSync();
//
//         debugPrint('✅ [CLOCK-OUT] All background tasks completed');
//       } catch (e) {
//         debugPrint('❌ [CLOCK-OUT] Background error: $e');
//       }
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // 🆕 BREAK CLOCKOUT SUPPORT - Public method for Break feature
//   // ══════════════════════════════════════════════════════════════════════════
//
//   /// Public method that can be called from Break screen/module
//   /// This allows the Break feature to trigger auto clock-out when user starts a break
//   Future<void> triggerBreakClockOut(BuildContext context) async {
//     debugPrint('⏸️ [BREAK] Break clockout triggered');
//
//     if (!attendanceViewModel.isClockedIn.value) {
//       debugPrint('⏸️ [BREAK] Cannot clock out - not clocked in');
//       return;
//     }
//
//     if (_autoClockOutInProgress) {
//       debugPrint('⏸️ [BREAK] Auto clockout already in progress');
//       return;
//     }
//
//     DateTime breakTime = DateTime.now();
//     double currentDist = await _getCurrentDistance();
//     double lat = locationViewModel.globalLatitude1.value;
//     double lng = locationViewModel.globalLongitude1.value;
//
//     // Save critical event data for break clockout
//     await _saveCriticalEventData(
//       eventTime: breakTime,
//       reason: 'break_clockout',
//       distance: currentDist,
//       latitude: lat,
//       longitude: lng,
//     );
//
//     // Show urgent notification for break
//     await _showUrgentNotification(
//       title: '⏸️ BREAK STARTED',
//       body: 'Auto clocked out because Break time started\nDuration: $_localElapsedTime',
//       payload: 'break_clockout',
//     );
//
//     // Handle auto clockout with break reason
//     await _handleAutoClockOut(
//       reason: 'break_clockout',
//       context: context,
//       eventTime: breakTime,
//     );
//
//     debugPrint('⏸️ [BREAK] Break clockout completed');
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // HELPER METHODS
//   // ══════════════════════════════════════════════════════════════════════════
//
//   void _createGpxFileInBackground(String filePath) {
//     Future.microtask(() async {
//       try {
//         File file = File(filePath);
//         if (!await file.exists()) {
//           String initialGPX = '''<?xml version="1.0" encoding="UTF-8"?>
// <gpx version="1.1" creator="AttendanceApp">
//   <trk>
//     <name>Daily Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}</name>
//     <trkseg>
//     </trkseg>
//   </trk>
// </gpx>''';
//           await file.writeAsString(initialGPX);
//           debugPrint('✅ Created GPX file in background');
//         }
//       } catch (e) {
//         debugPrint('⚠️ GPX creation error: $e');
//       }
//     });
//   }
//
//   String _getReasonMessage(String reason) {
//     switch (reason) {
//       case 'midnight_auto':
//         return 'Automatically clocked out at 11:58 PM';
//       case 'location_off_auto':
//         return 'Auto clockout because location services were turned off';
//       case 'time_changed_auto':
//         return 'Auto clockout because device date/time was changed';
//       case 'break_clockout': // ✅ ADDED: Break clockout reason
//         return 'Auto clocked out because Break time started';
//       default:
//         return 'Auto clockout completed successfully';
//     }
//   }
//
//   void _checkAndSyncPendingData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool hasPendingClockOut = prefs.getBool('hasPendingClockOutData') ?? false;
//     bool clockOutPending = prefs.getBool('clockOutPending') ?? false;
//
//     if (hasPendingClockOut || clockOutPending) {
//       debugPrint(
//           '🔄 [PENDING SYNC] Found pending clock-out data - syncing...');
//       _triggerAutoSync();
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   // SAFE PREFS READERS
//   // ──────────────────────────────────────────────────────────────────────────
//
//   /// Read a single key safely regardless of stored type.
//   String _safePrefsString(SharedPreferences prefs, String key) {
//     try {
//       final dynamic raw = prefs.get(key);
//       if (raw == null) return '';
//       return raw.toString();
//     } catch (_) {
//       return '';
//     }
//   }
//
//   /// Try each key in [keys] in order; return the first non-empty value found.
//   String _safePrefsStringFallback(SharedPreferences prefs, List<String> keys) {
//     for (final key in keys) {
//       try {
//         final dynamic raw = prefs.get(key);
//         if (raw != null) {
//           final String val = raw.toString().trim();
//           if (val.isNotEmpty) {
//             debugPrint('   ✅ [PREFS] Found "$key" = "$val"');
//             return val;
//           }
//         }
//       } catch (_) {}
//     }
//     debugPrint('   ⚠️ [PREFS] None of the fallback keys found: $keys');
//     return '';
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // BUILD
//   // ══════════════════════════════════════════════════════════════════════════
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // ── Timer Display ──
//             Obx(() {
//               String displayTime = _localElapsedTime;
//               if (displayTime == '00:00:00' &&
//                   attendanceViewModel.isClockedIn.value) {
//                 displayTime = attendanceViewModel.elapsedTime.value;
//               }
//
//               return Text(
//                 displayTime,
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: attendanceViewModel.isClockedIn.value
//                       ? Colors.black87
//                       : Colors.grey,
//                 ),
//               );
//             }),
//
//             const SizedBox(height: 5),
//
//             // ── Clock In / Clock Out Buttons ──
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Clock In
//                 Obx(() => SizedBox(
//                   width: 120,
//                   height: 35,
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(
//                       gradient: attendanceViewModel.isClockedIn.value
//                           ? null
//                           : AppColors.successGradient,
//                       color: attendanceViewModel.isClockedIn.value
//                           ? AppColors.greenTealLt
//                           : null,
//                       borderRadius: BorderRadius.circular(32),
//                       boxShadow: attendanceViewModel.isClockedIn.value
//                           ? []
//                           : AppColors.greenGlow,
//                     ),
//                     child: ElevatedButton(
//                       onPressed: attendanceViewModel.isClockedIn.value
//                           ? null
//                           : () async => _handleClockIn(context),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.transparent,
//                         shadowColor: Colors.transparent,
//                         disabledBackgroundColor: Colors.transparent,
//                         elevation: 0,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(32),
//                         ),
//                       ),
//                       child: Text(
//                         'Clock In',
//                         style: TextStyle(
//                           color: attendanceViewModel.isClockedIn.value
//                               ? AppColors.greenTeal
//                               : Colors.white,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                     ),
//                   ),
//                 )),
//
//                 const SizedBox(width: 8),
//
//                 // Clock Out
//                 Obx(() => SizedBox(
//                   width: 120,
//                   height: 35,
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(
//                       gradient: attendanceViewModel.isClockedIn.value
//                           ? const LinearGradient(
//                         colors: [AppColors.error, Color(0xFFFF6B6B)],
//                         begin: Alignment.centerLeft,
//                         end: Alignment.centerRight,
//                       )
//                           : null,
//                       color: attendanceViewModel.isClockedIn.value
//                           ? null
//                           : AppColors.error.withOpacity(0.10),
//                       borderRadius: BorderRadius.circular(32),
//                       boxShadow: attendanceViewModel.isClockedIn.value
//                           ? [
//                         BoxShadow(
//                           color: AppColors.error.withOpacity(0.35),
//                           blurRadius: 12,
//                           offset: const Offset(0, 4),
//                         ),
//                       ]
//                           : [],
//                     ),
//                     child: ElevatedButton(
//                       onPressed: attendanceViewModel.isClockedIn.value
//                           ? () async => _handleClockOut(context)
//                           : null,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.transparent,
//                         shadowColor: Colors.transparent,
//                         disabledBackgroundColor: Colors.transparent,
//                         elevation: 0,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(32),
//                         ),
//                       ),
//                       child: Text(
//                         'Clock Out',
//                         style: TextStyle(
//                           color: attendanceViewModel.isClockedIn.value
//                               ? Colors.white
//                               : AppColors.error,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                     ),
//                   ),
//                 )),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../AppColors.dart';
import '../../Database/util.dart';
import '../../ViewModels/attendance_out_view_model.dart';
import '../../ViewModels/attendance_view_model.dart';
import '../../ViewModels/location_view_model.dart';
import '../../constants.dart';

class TimerCard extends StatefulWidget {
  const TimerCard({super.key});

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {
  // ─── ViewModels ────────────────────────────────────────────────────────────
  final locationViewModel    = Get.find<LocationViewModel>();
  final attendanceViewModel  = Get.find<AttendanceViewModel>();
  final attendanceOutViewModel = Get.find<AttendanceOutViewModel>();

  // ─── Location / Connectivity ───────────────────────────────────────────────
  final loc.Location location   = loc.Location();
  final Connectivity _connectivity = Connectivity();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // ─── Method Channel (Native monitoring service) ────────────────────────────
  static const platform =
  MethodChannel('com.yourapp.attendance/location_monitor');

  // ─── Timer state ───────────────────────────────────────────────────────────
  Timer? _locationMonitorTimer;
  Timer? _midnightClockOutTimer;
  Timer? _permissionCheckTimer;
  Timer? _localBackupTimer;
  Timer? _autoSyncTimer;
  Timer? _distanceUpdateTimer;

  bool _wasLocationAvailable  = true;
  bool _autoClockOutInProgress = false;
  bool _isMidnightClockOutScheduled = false;
  bool _isOnline   = false;
  bool _isSyncing  = false;

  DateTime? _localClockInTime;
  String    _localElapsedTime = '00:00:00';
  DateTime? _lastKnownTime;

  double _currentDistance = 0.0;
  int    _notificationId  = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ─── SharedPreferences Keys ───────────────────────────────────────────────
  static const String KEY_EVENT_TIMESTAMP   = 'critical_event_timestamp';
  static const String KEY_EVENT_REASON      = 'critical_event_reason';
  static const String KEY_EVENT_DISTANCE    = 'critical_event_distance';
  static const String KEY_HAS_CRITICAL_EVENT = 'has_critical_event_pending';
  static const String KEY_EVENT_LATITUDE    = 'critical_event_latitude';
  static const String KEY_EVENT_LONGITUDE   = 'critical_event_longitude';
  static const String KEY_EVENT_ELAPSED_TIME = 'critical_event_elapsed_time';
  static const String KEY_IS_TIMER_FROZEN   = 'is_timer_frozen';
  static const String KEY_FROZEN_DISPLAY_TIME = 'frozen_display_time';
  static const String KEY_GPX_FINALIZED     = 'gpx_finalized_at';
  static const String KEY_GPX_FILE_PATH     = 'currentGpxFilePath';
  static const String KEY_PENDING_GPX_CLOSE = 'pending_gpx_close';

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeUrgentNotifications();
    _initializeFromPersistentState();
    _startAutoSyncMonitoring();
    _startDistanceUpdater();
    _scheduleMidnightClockOut();
    _startNativeMonitoringService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndProcessCriticalEvent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreEverything();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationMonitoring();
    _localBackupTimer?.cancel();
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _distanceUpdateTimer?.cancel();
    _midnightClockOutTimer?.cancel();
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔄 [LIFECYCLE] App state: $state');
    if (state == AppLifecycleState.resumed) {
      _checkAndProcessCriticalEvent();
      _restoreEverything();
      _checkConnectivityAndSync();
      _rescheduleMidnightClockOut();
      _startNativeMonitoringService();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('✅ [LIFECYCLE] Paused - native service continues monitoring');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE MONITORING SERVICE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final bool result = await platform.invokeMethod('startMonitoring');
        debugPrint('✅ [NATIVE SERVICE] Started: $result');
      }
    } on MissingPluginException {
      debugPrint('ℹ️ [NATIVE SERVICE] Not implemented — skipping');
    } catch (e) {
      debugPrint('⚠️ [NATIVE SERVICE] Error starting: $e');
    }
  }

  Future<void> _stopNativeMonitoringService() async {
    try {
      if (Platform.isAndroid) {
        final bool result = await platform.invokeMethod('stopMonitoring');
        debugPrint('🛑 [NATIVE SERVICE] Stopped: $result');
      }
    } on MissingPluginException {
      debugPrint('ℹ️ [NATIVE SERVICE] Not implemented — skipping');
    } catch (e) {
      debugPrint('⚠️ [NATIVE SERVICE] Error stopping: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initializeUrgentNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
      'urgent_auto_clockout_channel',
      'URGENT Auto Clockout Notifications',
      description: 'High-priority channel for auto clockout notifications',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Colors.red,
    );

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(urgentChannel);
  }

  Future<void> _showUrgentNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _notificationId++;

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'urgent_auto_clockout_channel',
      'URGENT Auto Clockout Notifications',
      channelDescription: 'High-priority auto clockout notifications',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      color: Colors.red,
      fullScreenIntent: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('🔔 [NOTIFICATION] Sent: $title');

    if (mounted) {
      Get.snackbar(
        title,
        body,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.warning, color: Colors.white),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GPX FILE FINALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finalizeGPXFile({
    required DateTime eventTime,
    required double finalDistance,
    required double latitude,
    required double longitude,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? gpxFilePath = prefs.getString(KEY_GPX_FILE_PATH);

      if (gpxFilePath == null || gpxFilePath.isEmpty) {
        debugPrint('⚠️ [GPX FINALIZE] No GPX file path found');
        return;
      }

      File gpxFile = File(gpxFilePath);
      if (!await gpxFile.exists()) {
        debugPrint('⚠️ [GPX FINALIZE] File does not exist: $gpxFilePath');
        return;
      }

      String content = await gpxFile.readAsString();
      content = content.replaceAll('</trkseg>\n  </trk>\n</gpx>', '');
      content = content.replaceAll('</trkseg></trk></gpx>', '');

      String finalTrackPoint = '''
    <trkpt lat="$latitude" lon="$longitude">
      <time>${eventTime.toIso8601String()}</time>
      <desc>Auto-clockout: Location tracking stopped</desc>
    </trkpt>''';

      String finalContent =
      content.replaceAll('</trkseg>', '$finalTrackPoint\n    </trkseg>');

      if (!finalContent.contains('</trk>')) {
        finalContent += '\n  </trk>\n</gpx>';
      }
      if (!finalContent.contains('</gpx>')) {
        finalContent += '\n</gpx>';
      }

      await gpxFile.writeAsString(finalContent, flush: true);

      await prefs.setString(KEY_GPX_FINALIZED, eventTime.toIso8601String());
      await prefs.setBool(KEY_PENDING_GPX_CLOSE, false);
      await prefs.setString('gpx_finalized_time', eventTime.toIso8601String());
      await prefs.setDouble('gpx_final_distance', finalDistance);
      await prefs.setString('gpx_final_file', gpxFilePath);
      await prefs.setBool('hasPendingGpxData', true);

      debugPrint('✅ [GPX FINALIZE] File finalized at $eventTime');
      debugPrint('✅ [GPX FINALIZE] Distance: $finalDistance km');
    } catch (e) {
      debugPrint('❌ [GPX FINALIZE] Error: $e');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRITICAL EVENT HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _checkAndProcessCriticalEvent() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasCriticalEvent = prefs.getBool(KEY_HAS_CRITICAL_EVENT) ?? false;
    bool isTimerFrozen    = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
    String? bgPayloadStr  = prefs.getString('bg_clockout_payload');

    if (!hasCriticalEvent &&
        !isTimerFrozen &&
        (bgPayloadStr == null || bgPayloadStr.isEmpty)) {
      return;
    }

    debugPrint('🚨 [CRITICAL EVENT] Found pending event on startup');

    _localElapsedTime = '00:00:00';
    attendanceViewModel.elapsedTime.value = '00:00:00';
    _localBackupTimer?.cancel();
    _localBackupTimer = null;
    if (mounted) setState(() {});

    bool needsGpxFinalization = prefs.getBool(KEY_PENDING_GPX_CLOSE) ?? false;

    String? eventTimeStr = prefs.getString(KEY_EVENT_TIMESTAMP);
    String? eventReason  = prefs.getString(KEY_EVENT_REASON);
    double? eventDistance = prefs.getDouble(KEY_EVENT_DISTANCE);
    double? eventLat     = prefs.getDouble(KEY_EVENT_LATITUDE);
    double? eventLng     = prefs.getDouble(KEY_EVENT_LONGITUDE);

    if (eventTimeStr != null) {
      DateTime eventTime = DateTime.parse(eventTimeStr);
      debugPrint('🚨 [CRITICAL EVENT] Occurred at: $eventTime, Reason: $eventReason');

      if (needsGpxFinalization) {
        await _finalizeGPXFile(
          eventTime     : eventTime,
          finalDistance : eventDistance ?? 0.0,
          latitude      : eventLat ?? 0.0,
          longitude     : eventLng ?? 0.0,
        );
      }

      Get.snackbar(
        '⚠️ Auto Clock-Out Occurred',
        'Event: ${_getReasonMessage(eventReason ?? 'unknown')}\nTime: ${DateFormat('HH:mm:ss').format(eventTime)}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.warning, color: Colors.white),
      );

      await _syncCriticalEventData(
        eventTime : eventTime,
        reason    : eventReason ?? 'unknown',
        distance  : eventDistance ?? 0.0,
        latitude  : eventLat ?? 0.0,
        longitude : eventLng ?? 0.0,
      );

      await _clearCriticalEventData();
      await prefs.remove('bg_clockout_payload');
      _triggerAutoSync();
    }
  }

  String? _extractJsonValue(String json, String key) {
    try {
      final pattern = '"$key":"';
      int start = json.indexOf(pattern);
      if (start == -1) return null;
      start += pattern.length;
      int end = json.indexOf('"', start);
      if (end == -1) return null;
      return json.substring(start, end);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncCriticalEventData({
    required DateTime eventTime,
    required String reason,
    required double distance,
    required double latitude,
    required double longitude,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String empId = _safePrefsString(prefs, 'emp_id');

      await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
      await prefs.setDouble('fastClockOutDistance', distance);
      await prefs.setString('fastClockOutReason', reason);
      await prefs.setBool('hasFastClockOutData', true);
      await prefs.setBool('clockOutPending', true);
      await prefs.setString(
          'pendingGpxDate', DateFormat('dd-MM-yyyy').format(eventTime));

      await attendanceOutViewModel.fastSaveAttendanceOut(
        empId        : empId,
        clockOutTime : eventTime,
        totalDistance: distance,
        isAuto       : true,
        reason       : reason,
      );

      debugPrint('✅ [SYNC] Critical event data saved. empId=$empId, timestamp=$eventTime');
      _triggerAutoSync();
    } catch (e) {
      debugPrint('❌ [SYNC] Error: $e');
    }
  }

  Future<void> _saveCriticalEventData({
    required DateTime eventTime,
    required String reason,
    required double distance,
    required double latitude,
    required double longitude,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String elapsedAtEvent = _localElapsedTime;

    await prefs.setBool(KEY_HAS_CRITICAL_EVENT, true);
    await prefs.setBool(KEY_IS_TIMER_FROZEN, true);
    await prefs.setString(KEY_EVENT_TIMESTAMP, eventTime.toIso8601String());
    await prefs.setString(KEY_EVENT_REASON, reason);
    await prefs.setDouble(KEY_EVENT_DISTANCE, distance);
    await prefs.setDouble(KEY_EVENT_LATITUDE, latitude);
    await prefs.setDouble(KEY_EVENT_LONGITUDE, longitude);
    await prefs.setString(KEY_FROZEN_DISPLAY_TIME, '00:00:00');
    await prefs.setBool(KEY_PENDING_GPX_CLOSE, true);

    String? gpxPath = prefs.getString(KEY_GPX_FILE_PATH);
    if (gpxPath != null) {
      await prefs.setString('event_gpx_file_path', gpxPath);
    }

    await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
    await prefs.setDouble('fastClockOutDistance', distance);
    await prefs.setString('fastClockOutReason', reason);
    await prefs.setBool('hasFastClockOutData', true);
    await prefs.setBool('clockOutPending', true);
    await prefs.setBool('isClockedIn', false);

    await prefs.setString(
        'bg_clockout_payload',
        '{"timestamp":"${eventTime.toIso8601String()}","reason":"$reason",'
            '"elapsed_at_event":"$elapsedAtEvent","distance":$distance,'
            '"latitude":$latitude,"longitude":$longitude,"source":"flutter_foreground"}');

    debugPrint('💾 [CRITICAL EVENT] Saved at: $eventTime, reason: $reason');
  }

  Future<void> _clearCriticalEventData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_HAS_CRITICAL_EVENT);
    await prefs.remove(KEY_EVENT_TIMESTAMP);
    await prefs.remove(KEY_EVENT_REASON);
    await prefs.remove(KEY_EVENT_DISTANCE);
    await prefs.remove(KEY_EVENT_LATITUDE);
    await prefs.remove(KEY_EVENT_LONGITUDE);
    debugPrint('🧹 [CLEAR] Critical event data cleared');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCATION MONITORING
  // ══════════════════════════════════════════════════════════════════════════

  void _startLocationMonitoring() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
          if (!attendanceViewModel.isClockedIn.value) return;
          await _updateCurrentDistance();
        });
    debugPrint('✅ [LOCATION MONITOR] Started');
  }

  void _stopLocationMonitoring() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer = null;
    debugPrint('🛑 [LOCATION MONITOR] Stopped');
  }

  void _startPermissionMonitoring() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    _lastKnownTime = null;
    _wasLocationAvailable = true;

    _permissionCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) {
            timer.cancel();
            return;
          }

          if (!attendanceViewModel.isClockedIn.value) return;

          bool locationEnabled = await attendanceViewModel.isLocationAvailable();
          if (_wasLocationAvailable && !locationEnabled) {
            debugPrint('📍 [MONITOR] Location OFF - auto clockout');

            DateTime eventTime   = DateTime.now();
            double currentDist   = await _getCurrentDistance();
            double lat           = locationViewModel.globalLatitude1.value;
            double lng           = locationViewModel.globalLongitude1.value;

            await _saveCriticalEventData(
              eventTime : eventTime,
              reason    : 'location_off_auto',
              distance  : currentDist,
              latitude  : lat,
              longitude : lng,
            );

            await _showUrgentNotification(
              title  : '⚠️ LOCATION TURNED OFF',
              body   : 'Auto clockout triggered because location was turned off',
              payload: 'location_off_auto',
            );

            await _handleAutoClockOut(
              reason   : 'location_off_auto',
              context  : context,
              eventTime: eventTime,
            );
            return;
          }
          _wasLocationAvailable = locationEnabled;

          await _checkForDateTimeChange();
        });
  }

  Future<void> _checkForDateTimeChange() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
    if (isFrozen || !attendanceViewModel.isClockedIn.value) return;

    final now = DateTime.now();
    if (_lastKnownTime == null) {
      _lastKnownTime = now;
      return;
    }

    final expectedDiff = now.difference(_lastKnownTime!).inSeconds;
    if (expectedDiff < -30 || expectedDiff > 120) {
      debugPrint('⏰ [IN-APP] Date/Time change detected! Diff: ${expectedDiff}s');

      DateTime eventTime = _lastKnownTime!;
      _lastKnownTime = null;
      _permissionCheckTimer?.cancel();
      _permissionCheckTimer = null;

      double currentDist = await _getCurrentDistance();
      double lat = locationViewModel.globalLatitude1.value;
      double lng = locationViewModel.globalLongitude1.value;

      await _saveCriticalEventData(
        eventTime : eventTime,
        reason    : 'time_changed_auto',
        distance  : currentDist,
        latitude  : lat,
        longitude : lng,
      );

      await _showUrgentNotification(
        title  : '⚠️ DATE/TIME CHANGED',
        body   : 'Auto clockout triggered because device date/time was changed',
        payload: 'time_changed_auto',
      );

      await _handleAutoClockOut(
        reason   : 'time_changed_auto',
        context  : context,
        eventTime: eventTime,
      );
      return;
    }

    _lastKnownTime = now;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MIDNIGHT AUTO CLOCKOUT (11:58 PM)
  // ══════════════════════════════════════════════════════════════════════════

  void _scheduleMidnightClockOut() {
    SharedPreferences.getInstance().then((prefs) {
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (isFrozen || !attendanceViewModel.isClockedIn.value) return;

      _midnightClockOutTimer?.cancel();

      final now           = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, 23, 58);

      Duration timeUntil = now.isAfter(scheduledTime)
          ? scheduledTime.add(const Duration(days: 1)).difference(now)
          : scheduledTime.difference(now);

      _midnightClockOutTimer = Timer(timeUntil, () async {
        if (attendanceViewModel.isClockedIn.value) {
          debugPrint('⏰ [MIDNIGHT] Auto clockout at 11:58 PM');

          DateTime eventTime = DateTime.now();
          double currentDist = await _getCurrentDistance();
          double lat = locationViewModel.globalLatitude1.value;
          double lng = locationViewModel.globalLongitude1.value;

          await _saveCriticalEventData(
            eventTime : eventTime,
            reason    : 'midnight_auto',
            distance  : currentDist,
            latitude  : lat,
            longitude : lng,
          );

          await _showUrgentNotification(
            title  : '⚠️ AUTO CLOCKOUT - 11:58 PM',
            body   : 'You have been automatically clocked out\nDuration: $_localElapsedTime',
            payload: 'midnight_auto',
          );

          await _handleAutoClockOut(
            reason   : 'midnight_auto',
            context  : context,
            eventTime: eventTime,
          );
        }
      });

      _isMidnightClockOutScheduled = true;
      debugPrint('⏰ [MIDNIGHT] Scheduled for ${scheduledTime.hour}:${scheduledTime.minute}');
    });
  }

  void _rescheduleMidnightClockOut() {
    SharedPreferences.getInstance().then((prefs) {
      bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
      if (!isFrozen && attendanceViewModel.isClockedIn.value) {
        _scheduleMidnightClockOut();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO CLOCKOUT HANDLER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleAutoClockOut({
    required String reason,
    required BuildContext context,
    DateTime? eventTime,
  }) async {
    if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) {
      return;
    }
    _autoClockOutInProgress = true;

    DateTime clockOutTime = eventTime ?? DateTime.now();
    double finalLat       = locationViewModel.globalLatitude1.value;
    double finalLng       = locationViewModel.globalLongitude1.value;
    double finalDistance  = _currentDistance > 0 ? _currentDistance : 0.0;

    debugPrint('⚡ [AUTO CLOCKOUT] Reason: $reason at $clockOutTime');

    try {
      _stopLocationMonitoring();
      _localBackupTimer?.cancel();
      _midnightClockOutTimer?.cancel();
      _permissionCheckTimer?.cancel();
      _lastKnownTime = null;

      final service = FlutterBackgroundService();
      service.invoke('stopService');

      await _stopNativeMonitoringService();

      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        debugPrint('⚠️ Background mode disable error: $e');
      }

      await _finalizeGPXFile(
        eventTime     : clockOutTime,
        finalDistance : finalDistance,
        latitude      : finalLat,
        longitude     : finalLng,
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isClockedIn', false);
      await prefs.setDouble('fastClockOutDistance', finalDistance);
      await prefs.setString('fastClockOutTime', clockOutTime.toIso8601String());
      await prefs.setBool('clockOutPending', true);
      await prefs.setBool('hasFastClockOutData', true);
      await prefs.setDouble('pendingLatOut', finalLat);
      await prefs.setDouble('pendingLngOut', finalLng);
      await prefs.setString('pendingAddress', locationViewModel.shopAddress.value);

      if (mounted) {
        setState(() {
          _localElapsedTime = '00:00:00';
          _currentDistance  = 0.0;
          _localClockInTime = null;
        });
      }

      attendanceViewModel.isClockedIn.value  = false;
      locationViewModel.isClockedIn.value    = false;
      attendanceViewModel.stopElapsedTimer();

      final String empId = _safePrefsString(prefs, 'emp_id');

      await attendanceOutViewModel.fastSaveAttendanceOut(
        empId        : empId,
        clockOutTime : clockOutTime,
        totalDistance: finalDistance,
        isAuto       : true,
        reason       : reason,
      );

      await attendanceViewModel.clearClockInState();
      _triggerAutoSync();

      if (mounted) {
        Get.snackbar(
          'Auto Clock-Out',
          _getReasonMessage(reason),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      debugPrint('❌ [AUTO CLOCKOUT] Error: $e');
    } finally {
      _autoClockOutInProgress = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISTANCE TRACKING
  // ══════════════════════════════════════════════════════════════════════════

  void _startDistanceUpdater() {
    _distanceUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
          if (isFrozen) {
            timer.cancel();
            return;
          }
          if (attendanceViewModel.isClockedIn.value) {
            await _updateCurrentDistance();
          }
        });
  }

  Future<void> _updateCurrentDistance() async {
    try {
      double distance = await locationViewModel.getImmediateDistance();
      if (mounted) {
        setState(() {
          _currentDistance = distance;
        });
      }
      attendanceViewModel.updateCachedDistance(distance);
    } catch (e) {
      debugPrint('❌ Distance update error: $e');
    }
  }

  Future<double> _getCurrentDistance() async {
    if (_currentDistance > 0) return _currentDistance;
    try {
      return await locationViewModel.getImmediateDistance();
    } catch (e) {
      return 0.0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO SYNC
  // ══════════════════════════════════════════════════════════════════════════

  void _startAutoSyncMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      bool wasOnline = _isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      debugPrint('🌐 [CONNECTIVITY] ${_isOnline ? 'ONLINE' : 'OFFLINE'}');

      if (_isOnline && !wasOnline && !_isSyncing) {
        debugPrint('🔄 [AUTO-SYNC] Internet connected - syncing...');
        _triggerAutoSync();
      }
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isSyncing) _checkConnectivityAndSync();
    });

    _checkConnectivityAndSync();
  }

  void _checkConnectivityAndSync() async {
    if (_isSyncing) return;
    try {
      var results = await _connectivity.checkConnectivity();
      bool wasOnline = _isOnline;
      _isOnline = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (_isOnline && !wasOnline && !_isSyncing) {
        _triggerAutoSync();
      }
    } catch (e) {
      debugPrint('❌ [CONNECTIVITY] Error: $e');
    }
  }

  void _triggerAutoSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint('🔒 [AUTO-SYNC] Starting...');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      bool hasPendingGpx    = prefs.getBool('hasPendingGpxData') ?? false;
      String? pendingGpxDate = prefs.getString('pendingGpxDate');
      DateTime? eventDate;

      if (pendingGpxDate != null && pendingGpxDate.isNotEmpty) {
        try {
          eventDate = DateFormat('dd-MM-yyyy').parse(pendingGpxDate);
          debugPrint('📅 [AUTO-SYNC] Using pending GPX date: $pendingGpxDate');
        } catch (e) {
          debugPrint('⚠️ [AUTO-SYNC] Error parsing pendingGpxDate: $e');
        }
      }

      Get.snackbar(
        'Syncing Data',
        hasPendingGpx
            ? 'Syncing attendance & GPS data...'
            : 'Syncing attendance data...',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1A2B6D),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      if (hasPendingGpx) {
        try {
          if (eventDate != null) {
            await locationViewModel.consolidateDailyGPXDataForDate(eventDate);
            await locationViewModel.saveLocationFromConsolidatedFileForDate(eventDate);
          } else {
            await locationViewModel.consolidateDailyGPXData();
            await locationViewModel.saveLocationFromConsolidatedFile();
          }
          debugPrint('✅ [AUTO-SYNC] GPX data processed');
        } catch (e) {
          debugPrint('⚠️ [AUTO-SYNC] GPX processing error: $e');
        }
      }

      await attendanceViewModel.syncUnposted();
      await attendanceOutViewModel.syncUnposted();

      await prefs.setBool('hasPendingClockOutData', false);
      await prefs.setBool('clockOutPending', false);
      await prefs.setBool('hasFastClockOutData', false);
      await prefs.setBool('hasPendingGpxData', false);
      await prefs.remove(KEY_PENDING_GPX_CLOSE);
      await prefs.remove('pendingGpxDate');

      debugPrint('✅ [AUTO-SYNC] Completed');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.snackbar(
            'Sync Complete',
            'All data synchronized to server',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        });
      }
    } catch (e) {
      debugPrint('❌ [AUTO-SYNC] Error: $e');
    } finally {
      _isSyncing = false;
      debugPrint('🔓 [AUTO-SYNC] Unlocked');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATE RESTORATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initializeFromPersistentState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isClockedIn = prefs.getBool(prefIsClockedIn) ?? false;
    bool isFrozen    = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;

    debugPrint('🔄 [INIT] isClockedIn=$isClockedIn, isFrozen=$isFrozen');

    if (isFrozen) {
      _localElapsedTime = '00:00:00';
      attendanceViewModel.elapsedTime.value = '00:00:00';
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      if (mounted) setState(() {});
      return;
    }

    locationViewModel.isClockedIn.value   = isClockedIn;
    attendanceViewModel.isClockedIn.value = isClockedIn;

    if (isClockedIn) {
      _startBackgroundServices();
      _startLocationMonitoring();
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();
      debugPrint('✅ [INIT] Full clocked-in state restored');
    }

    if (mounted) setState(() {});
  }

  void _restoreEverything() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isClockedIn = prefs.getBool(prefIsClockedIn) ?? false;
    bool isFrozen    = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;

    if (isFrozen) {
      _localElapsedTime = '00:00:00';
      attendanceViewModel.elapsedTime.value = '00:00:00';
      locationViewModel.isClockedIn.value   = false;
      attendanceViewModel.isClockedIn.value = false;
      if (mounted) setState(() {});
      return;
    }

    if (isClockedIn) {
      locationViewModel.isClockedIn.value   = true;
      attendanceViewModel.isClockedIn.value = true;

      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      if (mounted) setState(() {});
      debugPrint('✅ [RESTORE] Everything restored');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCAL BACKUP TIMER
  // ══════════════════════════════════════════════════════════════════════════

  void _startLocalBackupTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
    if (isFrozen) return;

    String? clockInTimeString = prefs.getString(prefClockInTime);
    if (clockInTimeString == null) return;

    _localClockInTime = DateTime.parse(clockInTimeString);
    _localBackupTimer?.cancel();

    _localBackupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      SharedPreferences.getInstance().then((prefs) {
        bool isFrozen = prefs.getBool(KEY_IS_TIMER_FROZEN) ?? false;
        if (isFrozen) {
          timer.cancel();
          return;
        }
      });

      if (_localClockInTime == null) return;

      final duration = DateTime.now().difference(_localClockInTime!);
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      _localElapsedTime =
      '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';

      attendanceViewModel.elapsedTime.value = _localElapsedTime;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('elapsed_time', _localElapsedTime);
      });

      if (mounted) setState(() {});
    });

    debugPrint('✅ [BACKUP TIMER] Started');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BACKGROUND SERVICES
  // ══════════════════════════════════════════════════════════════════════════

  void _startBackgroundServices() async {
    try {
      debugPrint('🛰 [BACKGROUND] Starting services...');
      final service = FlutterBackgroundService();
      await location.enableBackgroundMode(enable: true);
      service.startService().catchError(
              (e) => debugPrint('Service start error: $e'));
      location
          .changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high)
          .catchError((e) => debugPrint('Location settings error: $e'));
      debugPrint('✅ [BACKGROUND] Services started');
    } catch (e) {
      debugPrint('⚠ [BACKGROUND] Error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCATION PERMISSION CHECK
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 50, color: Colors.redAccent),
                const SizedBox(height: 15),
                const Text('Location Permission Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  'We need location access to continue.\nPlease enable location permission from app settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await Geolocator.openAppSettings();
                        },
                        child: const Text('Open Settings',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ GEOFENCE — GPS distance check against saved location
  // Keys written by LocationSelectionScreen._saveAndGoBack():
  //   selected_lat, selected_lng, selected_radius, selected_location_name
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _isWithinGeofence({
    required double allowedLat,
    required double allowedLng,
    required double radiusMeters,
  }) async {
    try {
      final Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        allowedLat,
        allowedLng,
      );

      debugPrint('📏 [GEOFENCE] User: ${currentPosition.latitude}, ${currentPosition.longitude}');
      debugPrint('📏 [GEOFENCE] Distance from location: ${distanceInMeters.toStringAsFixed(1)} m');
      debugPrint('📏 [GEOFENCE] Allowed radius: $radiusMeters m');
      debugPrint('📏 [GEOFENCE] Within geofence: ${distanceInMeters <= radiusMeters}');

      return distanceInMeters <= radiusMeters;
    } catch (e) {
      debugPrint('❌ [GEOFENCE] Distance check error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CAMERA CAPTURE FOR CLOCK IN
  // ══════════════════════════════════════════════════════════════════════════

  Future<Uint8List?> _captureClockInPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (photo == null) {
        debugPrint('📷 [CAMERA] User cancelled — no photo taken');
        return null;
      }

      debugPrint('📷 [CAMERA] Photo path: ${photo.path}');

      final Uint8List bytes = await photo.readAsBytes();
      debugPrint('📸 [CAMERA] ✅ ${bytes.length} bytes read via XFile.readAsBytes()');

      if (bytes.isEmpty) {
        debugPrint('❌ [CAMERA] readAsBytes() returned 0 bytes — path: ${photo.path}');
        return null;
      }

      return bytes;
    } catch (e) {
      debugPrint('❌ [CAMERA] Error capturing / reading photo bytes: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLOCK IN — with camera + geofencing
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleClockIn(BuildContext context) async {
    debugPrint('🎯 [TIMERCARD] ===== CLOCK-IN STARTED =====');
    final clockInStart = DateTime.now();

    // ── 1. CAMERA CAPTURE ──────────────────────────────────────────────────
    final Uint8List? clockInPhotoBytes = await _captureClockInPhoto();

    if (clockInPhotoBytes == null || clockInPhotoBytes.isEmpty) {
      Get.snackbar(
        '📷 Photo Required',
        'Please capture a photo to clock in',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
      );
      return;
    }

    debugPrint('📸 [TIMERCARD] ✅ clockInPhotoBytes ready: ${clockInPhotoBytes.length} bytes');

    // ── 2. LOADING DIALOG ──────────────────────────────────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ),
    );

    try {
      // ── 3. PARALLEL CHECKS (prefs + permission + location service) ────────
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        _checkLocationPermission(context),
        attendanceViewModel.isLocationAvailable(),
      ]);

      final prefs             = results[0] as SharedPreferences;
      final hasPermission     = results[1] as bool;
      final locationAvailable = results[2] as bool;

      if (!hasPermission || !locationAvailable) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        Get.snackbar(
          'Location Required',
          'Please enable Location Services and Permissions',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      // ══════════════════════════════════════════════════════════════════════
      // ✅ 4. GEOFENCING CHECK
      //    Reads the location saved by LocationSelectionScreen.
      //    • No location selected  → block with informative message
      //    • Location selected but user is outside radius → block
      //    • User is inside radius → allow clock-in
      // ══════════════════════════════════════════════════════════════════════
      final double? savedLat    = prefs.getDouble('selected_lat');
      final double? savedLng    = prefs.getDouble('selected_lng');
      final double? savedRadius = prefs.getDouble('selected_radius');
      final String  savedName   = prefs.getString('selected_location_name') ?? '';

      debugPrint('🔍 [GEOFENCE] Saved location: "$savedName" '
          'lat=$savedLat, lng=$savedLng, radius=$savedRadius');

      // ── 4a. No location selected at all ───────────────────────────────────
      if (savedLat == null || savedLng == null || savedRadius == null || savedName.isEmpty) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        Get.snackbar(
          '📍 Location Required',
          'Please select a customer location first before clocking in.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.location_off, color: Colors.white),
        );
        debugPrint('❌ [GEOFENCE] Clock-in BLOCKED — no location selected');
        return;
      }

      // ── 4b. GPS distance check against saved location ─────────────────────
      debugPrint('🔍 [GEOFENCE] Checking GPS distance from "$savedName"...');

      final bool withinGeofence = await _isWithinGeofence(
        allowedLat   : savedLat,
        allowedLng   : savedLng,
        radiusMeters : savedRadius,
      );

      if (!withinGeofence) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        Get.snackbar(
          '📍 Outside Location',
          'You are not near "$savedName".\nPlease reach the designated location to clock in.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.location_off, color: Colors.white),
        );
        debugPrint('❌ [GEOFENCE] Clock-in BLOCKED — user is outside "$savedName"');
        return;
      }

      debugPrint('✅ [GEOFENCE] GPS check passed — user is within "$savedName"');
      // ══════════════════════════════════════════════════════════════════════
      // GEOFENCING CHECK END
      // ══════════════════════════════════════════════════════════════════════

      // ── 5. CLEAR FROZEN STATE ─────────────────────────────────────────────
      await prefs.remove(KEY_IS_TIMER_FROZEN);
      await prefs.remove(KEY_FROZEN_DISPLAY_TIME);
      _lastKnownTime = null;

      // ── 6. READ EMPLOYEE DATA ─────────────────────────────────────────────
      final String empId = _safePrefsString(prefs, 'emp_id');
      final String empName = _safePrefsStringFallback(prefs, [
        'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
      ]);
      final String job = _safePrefsStringFallback(prefs, [
        'job', 'designation', 'role', 'emp_job', 'position', 'jobTitle',
      ]);
      final String city = _safePrefsStringFallback(prefs, [
        'city', 'emp_city', 'location',
      ]);

      debugPrint('👤 [CLOCK-IN] empId=$empId | empName=$empName | job=$job | city=$city');

      // ── 7. GPX PATH ────────────────────────────────────────────────────────
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final filePath = '${downloadDirectory!.path}/track_${empId}_$date.gpx';
      await prefs.setString(KEY_GPX_FILE_PATH, filePath);

      // ── 8. CLOCK IN ────────────────────────────────────────────────────────
      await attendanceViewModel.clockIn(
        empId     : empId,
        empName   : empName,
        job       : job,
        city      : city,
        photoBytes: clockInPhotoBytes,
      );

      // ── 9. UI UPDATE ───────────────────────────────────────────────────────
      setState(() {
        _localElapsedTime = '00:00:00';
        locationViewModel.isClockedIn.value   = true;
        attendanceViewModel.isClockedIn.value = true;
      });

      // ── 10. START TIMERS ───────────────────────────────────────────────────
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _startPermissionMonitoring();

      // ── 11. CLOSE DIALOG ───────────────────────────────────────────────────
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        '✅ Clocked In',
        'GPS tracking started at "$savedName"',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1A2B6D),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      debugPrint('✅ [CLOCK-IN] UI completed in '
          '${DateTime.now().difference(clockInStart).inMilliseconds}ms');

      // ── 12. BACKGROUND TASKS ───────────────────────────────────────────────
      _runPostClockInTasks(filePath);
    } catch (e) {
      debugPrint('❌ [CLOCK-IN] Error: $e');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        'Error',
        'Failed to clock in: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _runPostClockInTasks(String filePath) {
    Future.microtask(() async {
      try {
        _createGpxFileInBackground(filePath);
        _startBackgroundServices();
        _startNativeMonitoringService();
        _updateCurrentDistance();
        debugPrint('✅ [CLOCK-IN] Background tasks completed');
      } catch (e) {
        debugPrint('⚠️ [CLOCK-IN] Background task error: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLOCK OUT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleClockOut(BuildContext context) async {
    debugPrint('🎯 [TIMERCARD] ===== CLOCK-OUT STARTED =====');

    // Capture distance BEFORE any reset
    final double capturedDistance = _currentDistance > 0
        ? _currentDistance
        : await locationViewModel.getImmediateDistance();

    debugPrint('📏 [CLOCK-OUT] Captured distance: ${capturedDistance.toStringAsFixed(3)} km');

    setState(() {
      _localElapsedTime = '00:00:00';
      _currentDistance  = 0.0;
    });

    _stopLocationMonitoring();
    _localBackupTimer?.cancel();
    _midnightClockOutTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _localClockInTime = null;
    _lastKnownTime    = null;

    attendanceViewModel.stopElapsedTimer();
    attendanceViewModel.isClockedIn.value = false;
    locationViewModel.isClockedIn.value   = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
      ),
    );

    try {
      final clockOutTime  = DateTime.now();
      final finalDistance = capturedDistance;

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(KEY_IS_TIMER_FROZEN),
        prefs.remove(KEY_FROZEN_DISPLAY_TIME),
        prefs.remove(KEY_PENDING_GPX_CLOSE),
        prefs.remove('hasPendingGpxData'),
        prefs.setBool('isClockedIn', false),
        prefs.setDouble('fastClockOutDistance', finalDistance),
        prefs.setString('fastClockOutTime', clockOutTime.toIso8601String()),
        prefs.setBool('clockOutPending', true),
        prefs.setBool('hasFastClockOutData', true),
      ]);

      final String empId = _safePrefsString(prefs, 'emp_id');
      debugPrint('👤 [CLOCK-OUT] empId=$empId | distance=${finalDistance.toStringAsFixed(3)} km');

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        '✅ Clocked Out',
        'Data saved locally',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1A2B6D),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      unawaited(attendanceOutViewModel.fastSaveAttendanceOut(
        empId        : empId,
        clockOutTime : clockOutTime,
        totalDistance: finalDistance,
        isAuto       : false,
        reason       : 'manual_clockout',
      ));

      _runPostClockOutTasks(clockOutTime, finalDistance);
    } catch (e) {
      debugPrint('❌ [CLOCK-OUT] Error: $e');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      Get.snackbar(
        'Clock Out Issue',
        'Data saved locally, sync pending',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  void _runPostClockOutTasks(DateTime clockOutTime, double distance) {
    Future.microtask(() async {
      try {
        debugPrint('🏁 [CLOCK-OUT] Background: Saving GPX location data...');

        await locationViewModel.consolidateDailyGPXDataForDate(clockOutTime);
        debugPrint('✅ [GPX] Consolidated GPX file');

        await locationViewModel.saveLocationFromConsolidatedFileForDate(clockOutTime);
        debugPrint('✅ [GPX] Saved LocationModel to DB + API');

        final service = FlutterBackgroundService();
        service.invoke('stopService');
        await _stopNativeMonitoringService();

        try {
          await location.enableBackgroundMode(enable: false);
        } catch (e) {
          debugPrint('⚠️ Background mode disable error: $e');
        }

        _triggerAutoSync();

        debugPrint('✅ [CLOCK-OUT] All background tasks completed');
      } catch (e) {
        debugPrint('❌ [CLOCK-OUT] Background error: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BREAK CLOCKOUT SUPPORT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> triggerBreakClockOut(BuildContext context) async {
    debugPrint('⏸️ [BREAK] Break clockout triggered');

    if (!attendanceViewModel.isClockedIn.value) {
      debugPrint('⏸️ [BREAK] Cannot clock out - not clocked in');
      return;
    }

    if (_autoClockOutInProgress) {
      debugPrint('⏸️ [BREAK] Auto clockout already in progress');
      return;
    }

    DateTime breakTime = DateTime.now();
    double currentDist = await _getCurrentDistance();
    double lat = locationViewModel.globalLatitude1.value;
    double lng = locationViewModel.globalLongitude1.value;

    await _saveCriticalEventData(
      eventTime : breakTime,
      reason    : 'break_clockout',
      distance  : currentDist,
      latitude  : lat,
      longitude : lng,
    );

    await _showUrgentNotification(
      title  : '⏸️ BREAK STARTED',
      body   : 'Auto clocked out because Break time started\nDuration: $_localElapsedTime',
      payload: 'break_clockout',
    );

    await _handleAutoClockOut(
      reason   : 'break_clockout',
      context  : context,
      eventTime: breakTime,
    );

    debugPrint('⏸️ [BREAK] Break clockout completed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  void _createGpxFileInBackground(String filePath) {
    Future.microtask(() async {
      try {
        File file = File(filePath);
        if (!await file.exists()) {
          String initialGPX = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="AttendanceApp">
  <trk>
    <name>Daily Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}</name>
    <trkseg>
    </trkseg>
  </trk>
</gpx>''';
          await file.writeAsString(initialGPX);
          debugPrint('✅ Created GPX file in background');
        }
      } catch (e) {
        debugPrint('⚠️ GPX creation error: $e');
      }
    });
  }

  String _getReasonMessage(String reason) {
    switch (reason) {
      case 'midnight_auto':
        return 'Automatically clocked out at 11:58 PM';
      case 'location_off_auto':
        return 'Auto clockout because location services were turned off';
      case 'time_changed_auto':
        return 'Auto clockout because device date/time was changed';
      case 'break_clockout':
        return 'Auto clocked out because Break time started';
      default:
        return 'Auto clockout completed successfully';
    }
  }

  void _checkAndSyncPendingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasPendingClockOut = prefs.getBool('hasPendingClockOutData') ?? false;
    bool clockOutPending    = prefs.getBool('clockOutPending') ?? false;

    if (hasPendingClockOut || clockOutPending) {
      debugPrint('🔄 [PENDING SYNC] Found pending clock-out data - syncing...');
      _triggerAutoSync();
    }
  }

  String _safePrefsString(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return '';
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  String _safePrefsStringFallback(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      try {
        final dynamic raw = prefs.get(key);
        if (raw != null) {
          final String val = raw.toString().trim();
          if (val.isNotEmpty) {
            debugPrint('   ✅ [PREFS] Found "$key" = "$val"');
            return val;
          }
        }
      } catch (_) {}
    }
    debugPrint('   ⚠️ [PREFS] None of the fallback keys found: $keys');
    return '';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Timer Display ──
            Obx(() {
              String displayTime = _localElapsedTime;
              if (displayTime == '00:00:00' &&
                  attendanceViewModel.isClockedIn.value) {
                displayTime = attendanceViewModel.elapsedTime.value;
              }
              return Text(
                displayTime,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: attendanceViewModel.isClockedIn.value
                      ? Colors.black87
                      : Colors.grey,
                ),
              );
            }),

            const SizedBox(height: 5),

            // ── Clock In / Clock Out Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Clock In ──
                Obx(() => SizedBox(
                  width: 120,
                  height: 35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: attendanceViewModel.isClockedIn.value
                          ? null
                          : AppColors.successGradient,
                      color: attendanceViewModel.isClockedIn.value
                          ? AppColors.greenTealLt
                          : null,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: attendanceViewModel.isClockedIn.value
                          ? []
                          : AppColors.greenGlow,
                    ),
                    child: ElevatedButton(
                      onPressed: attendanceViewModel.isClockedIn.value
                          ? null
                          : () async => _handleClockIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                      ),
                      child: Text(
                        'Clock In',
                        style: TextStyle(
                          color: attendanceViewModel.isClockedIn.value
                              ? AppColors.greenTeal
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                )),

                const SizedBox(width: 8),

                // ── Clock Out ──
                Obx(() => SizedBox(
                  width: 120,
                  height: 35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: attendanceViewModel.isClockedIn.value
                          ? const LinearGradient(
                        colors: [AppColors.error, Color(0xFFFF6B6B)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                          : null,
                      color: attendanceViewModel.isClockedIn.value
                          ? null
                          : AppColors.error.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: attendanceViewModel.isClockedIn.value
                          ? [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: attendanceViewModel.isClockedIn.value
                          ? () async => _handleClockOut(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                      ),
                      child: Text(
                        'Clock Out',
                        style: TextStyle(
                          color: attendanceViewModel.isClockedIn.value
                              ? Colors.white
                              : AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}