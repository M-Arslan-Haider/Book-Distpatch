import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../AppColors.dart';
import '../../Database/util.dart';
import '../../Repositories/LoginRepositories/login_repository.dart';
import '../../Services/Overtime_Clock_Out_Service.dart';
import '../../Services/selfie_notification_policy_service.dart';
import '../../ViewModels/attendance_out_view_model.dart';
import '../../ViewModels/attendance_view_model.dart';
import '../../ViewModels/geofancing_violation.dart';
import '../../ViewModels/location_tracker_bulk_viewmodel.dart';
import '../../ViewModels/location_tracker_viewmodel.dart';
import '../../ViewModels/location_view_model.dart';
import '../../ViewModels/travel_session_view_model.dart';
import '../../constants.dart';
import '../geofancing_violation_widgets.dart';
import '../location_session_screen.dart';

import '../mqtt_work.dart';


import 'package:battery_plus/battery_plus.dart'; // ✅ Battery monitoring


class TimerCard extends StatefulWidget {
  const TimerCard({super.key});

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> with WidgetsBindingObserver {
  // ─── ViewModels ────────────────────────────────────────────────────────────
  final locationViewModel      = Get.find<LocationViewModel>();
  final attendanceViewModel    = Get.find<AttendanceViewModel>();
  final attendanceOutViewModel = Get.find<AttendanceOutViewModel>();

  final TravelViewModel _travelVM = Get.find<TravelViewModel>();

  // Geofence violation tracker
  late GeofenceViolationViewModel _violationVM;

  // ✅ MQTT Tracker
  final MqttTracker _mqttTracker = MqttTracker();

  // ✅ Auto Location POST — har 5 min mein lat/lng server ko bhejta hai
  final LocationTrackerService _locationTrackerService = LocationTrackerService();

  // ─── Location / Connectivity ───────────────────────────────────────────────
  final loc.Location location     = loc.Location();
  final Connectivity _connectivity = Connectivity();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // ─── Method Channel (Native monitoring service) ────────────────────────────
  static const platform =
  MethodChannel('com.yourapp.attendance/location_monitor');

  // ─── Timer state ───────────────────────────────────────────────────────────
  Timer? _locationMonitorTimer;
  Timer? _midnightClockOutTimer;
  Timer? _shiftEndClockOutTimer;   // ✅ NEW: Shift end auto clock-out
  Timer? _permissionCheckTimer;
  Timer? _localBackupTimer;
  Timer? _autoSyncTimer;
  Timer? _distanceUpdateTimer;
  Timer? _employeeDataRefreshTimer; // ✅ Live employee data refresh (every 5 s)

  // ── ✅ OVERTIME Auto Clock-Out Service ─────────────────────────────────────
  // Jab overtime=yes user shift end ke baad clock-in kare to yeh service
  // API se DAILY_OT_CAP fetch karke auto clock-out schedule karti hai.
  // Koi doosra logic touch nahi hota — sirf overtime session ke liye kaam karta hai.
  final OvertimeClockOutService _overtimeService = OvertimeClockOutService();

  // ── Battery ────────────────────────────────────────────────────────────────
  final Battery _battery     = Battery();
  int    _batteryLevel       = 0;
  bool   _isCharging         = false;
  Timer? _batteryTimer;

  bool _wasLocationAvailable   = true;
  bool _autoClockOutInProgress = false;
  bool _isMidnightClockOutScheduled = false;
  bool _isOnline  = false;
  bool _isSyncing = false;

  DateTime? _localClockInTime;
  String    _localElapsedTime = '00:00:00';

  double _currentDistance = 0.0;
  int    _notificationId  = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ─── SharedPreferences Keys ───────────────────────────────────────────────
  static const String KEY_EVENT_TIMESTAMP    = 'critical_event_timestamp';
  static const String KEY_EVENT_REASON       = 'critical_event_reason';
  static const String KEY_EVENT_DISTANCE     = 'critical_event_distance';
  static const String KEY_HAS_CRITICAL_EVENT = 'has_critical_event_pending';
  static const String KEY_EVENT_LATITUDE     = 'critical_event_latitude';
  static const String KEY_EVENT_LONGITUDE    = 'critical_event_longitude';
  static const String KEY_EVENT_ELAPSED_TIME = 'critical_event_elapsed_time';
  static const String KEY_IS_TIMER_FROZEN    = 'is_timer_frozen';
  static const String KEY_FROZEN_DISPLAY_TIME = 'frozen_display_time';
  static const String KEY_GPX_FINALIZED      = 'gpx_finalized_at';
  static const String KEY_GPX_FILE_PATH      = 'currentGpxFilePath';
  static const String KEY_PENDING_GPX_CLOSE  = 'pending_gpx_close';

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _violationVM = Get.put(GeofenceViolationViewModel());
    WidgetsBinding.instance.addObserver(this);

    _initializeUrgentNotifications();
    _initializeFromPersistentState();
    _startAutoSyncMonitoring();
    _startDistanceUpdater();
    _scheduleMidnightClockOut();
    _scheduleShiftEndClockOut();   // ✅ NEW
    _startNativeMonitoringService();
    _startEmployeeDataRefresh();   // ✅ Live employee data refresh every 5 s

    // ✅ Initialize MQTT Tracker
    _mqttTracker.initialize().then((_) {
      debugPrint('✅ MQTT Tracker initialized');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndProcessCriticalEvent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreEverything();
    });
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
    _shiftEndClockOutTimer?.cancel();   // ✅ NEW: Shift end auto clock-out
    _permissionCheckTimer?.cancel();
    _employeeDataRefreshTimer?.cancel(); // ✅ Live employee data refresh
    // ✅ OVERTIME: Cancel overtime auto clock-out timers
    unawaited(_overtimeService.cancel());
    // ✅ Dispose MQTT
    _mqttTracker.dispose();
    // ✅ Stop auto location tracker
    _locationTrackerService.stop();
    // ✅ Stop battery monitoring
    _batteryTimer?.cancel();
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
      _scheduleShiftEndClockOut();       // ✅ NEW
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

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
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

    // ✅ NEW: Dedicated Shift End alarm channel — device alarm sound + 1-min vibration
    const AndroidNotificationChannel shiftEndAlarmChannel = AndroidNotificationChannel(
      'shift_end_alarm_channel',
      'Shift End Alarm',
      description: 'Full device alarm sound and vibration for shift end auto clockout',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Colors.red,
      // Uses the device default alarm sound URI — same as Android RingtoneManager.TYPE_ALARM
      sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(shiftEndAlarmChannel);
  }

  Future<void> _showUrgentNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _notificationId++;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

  // ✅ NEW: Shift End specific notification — device alarm sound + 1-min max vibration
  Future<void> _showShiftEndAlarmNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _notificationId++;

    // Vibration pattern: wait 0ms, then vibrate 60,000ms (1 full minute)
    final vibPattern = Int64List.fromList([0, 60000]);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'shift_end_alarm_channel',
      'Shift End Alarm',
      channelDescription: 'Full device alarm for shift end auto clockout',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      vibrationPattern: vibPattern,                                     // ✅ 1-minute vibration
      sound: const UriAndroidNotificationSound(                         // ✅ Device alarm sound
          'content://settings/system/alarm_alert'),
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
      interruptionLevel: InterruptionLevel.critical,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      _notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('⏰ [SHIFT END ALARM] Sent with device alarm sound + 60s vibration: $title');

    if (mounted) {
      Get.snackbar(
        title,
        body,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.alarm, color: Colors.white),
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

    String? eventTimeStr  = prefs.getString(KEY_EVENT_TIMESTAMP);
    String? eventReason   = prefs.getString(KEY_EVENT_REASON);
    double? eventDistance = prefs.getDouble(KEY_EVENT_DISTANCE);
    double? eventLat      = prefs.getDouble(KEY_EVENT_LATITUDE);
    double? eventLng      = prefs.getDouble(KEY_EVENT_LONGITUDE);

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
    required String   reason,
    required double   distance,
    required double   latitude,
    required double   longitude,
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
    required String   reason,
    required double   distance,
    required double   latitude,
    required double   longitude,
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

            DateTime eventTime = DateTime.now();
            double currentDist = await _getCurrentDistance();
            double lat         = locationViewModel.globalLatitude1.value;
            double lng         = locationViewModel.globalLongitude1.value;

            await _saveCriticalEventData(
              eventTime : eventTime,
              reason    : 'System Location - Off Clockout',
              distance  : currentDist,
              latitude  : lat,
              longitude : lng,
            );

            await _showUrgentNotification(
              title  : '⚠️ LOCATION TURNED OFF',
              body   : 'Auto clockout triggered because location was turned off',
              payload: 'System Clock out - Location Off',
            );

            await _handleAutoClockOut(
              reason   : 'System Clock out - Location Off',
              context  : context,
              eventTime: eventTime,
            );
            return;
          }
          _wasLocationAvailable = locationEnabled;
        });
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
          double lat         = locationViewModel.globalLatitude1.value;
          double lng         = locationViewModel.globalLongitude1.value;

          await _saveCriticalEventData(
            eventTime : eventTime,
            reason    : 'System Midnight - Clockout',
            distance  : currentDist,
            latitude  : lat,
            longitude : lng,
          );

          await _showUrgentNotification(
            title  : '⚠️ AUTO CLOCKOUT - 11:58 PM',
            body   : 'You have been automatically clocked out\nDuration: $_localElapsedTime',
            payload: 'System Midnight - Clockout',
          );

          await _handleAutoClockOut(
            reason   : 'System Midnight - Clockout',
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
  // SHIFT END AUTO CLOCKOUT  ✅ NEW
  // Reads END_TIME set during login (cached_end_time in SharedPreferences).
  // Schedules a one-shot Timer that fires when device clock reaches that time.
  // Works in foreground. Native LocationMonitorService handles background /
  // app-killed cases using the same SharedPreferences key (flutter.cached_end_time).
  // Reason stored: "shift_end_auto"
  // ══════════════════════════════════════════════════════════════════════════

  // ──────────────────────────────────────────────────────────────────────────
  // HELPER: Normalize any time string → [hour24, minute]
  //
  // Handles ALL server/device formats:
  //   "17:33"        → [17, 33]   (server 24-hour — primary format)
  //   "5:33 PM"      → [17, 33]   (12-hour with space)
  //   "5:33PM"       → [17, 33]   (12-hour without space)
  //   "05:33 pm"     → [17, 33]   (lowercase am/pm)
  //   "5:33"         → [5,  33]   (ambiguous — treated as 24-hour, i.e. 5 AM)
  //   "17:33:00"     → [17, 33]   (with seconds)
  //
  // Returns null if the string cannot be parsed at all.
  // ──────────────────────────────────────────────────────────────────────────
  List<int>? _parseTimeTo24h(String raw) {
    try {
      final String upper = raw.trim().toUpperCase();
      final bool isPM    = upper.contains('PM');
      final bool isAM    = upper.contains('AM');

      // Strip AM/PM and any trailing whitespace
      final String cleaned = upper
          .replaceAll('PM', '')
          .replaceAll('AM', '')
          .trim();

      final List<String> parts = cleaned.split(':');
      if (parts.length < 2) return null;

      int? hour       = int.tryParse(parts[0].trim());
      // parts[1] may be "33" or "33 " — take only digits
      int? minute = int.tryParse(parts[1].trim().split(RegExp(r'\s+'))[0]);

      if (hour == null || minute == null) return null;

      // Convert 12-hour → 24-hour
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour  = 0;

      return [hour, minute];
    } catch (e) {
      debugPrint('⚠️ [PARSE TIME] Error: $e  raw="$raw"');
      return null;
    }
  }

  void _scheduleShiftEndClockOut() {
    _shiftEndClockOutTimer?.cancel();

    if (!attendanceViewModel.isClockedIn.value) return;

    bool shiftEndFired = false;

    // ✅ FIX: Timer re-reads cached_end_time from SharedPreferences on EVERY tick.
    // This means if the backend admin changes end_time while the user is clocked in,
    // refreshEmployeeDataIfOnline() writes the new value to SharedPreferences and
    // the NEXT tick of this timer picks it up automatically — no timer restart needed.
    // Previous bug: endHour/endMinute were captured in the outer closure once and
    // never updated, so backend end_time changes were completely ignored by Flutter.
    _shiftEndClockOutTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (shiftEndFired) { timer.cancel(); return; }

      final p      = await SharedPreferences.getInstance();
      final frozen = p.getBool(KEY_IS_TIMER_FROZEN) ?? false;

      if (frozen) {
        shiftEndFired = true;
        timer.cancel();
        debugPrint('⏰ [SHIFT END] Native service already handled — processing in Flutter');
        if (mounted) _checkAndProcessCriticalEvent();
        return;
      }

      if (!attendanceViewModel.isClockedIn.value) {
        timer.cancel();
        return;
      }

      // ✅ FIX: Read fresh end_time on every tick (not captured in closure)
      final String? endTimeStr = p.getString('cached_end_time');
      if (endTimeStr == null || endTimeStr.isEmpty) return;

      final List<int>? parsed = _parseTimeTo24h(endTimeStr);
      if (parsed == null) return;

      final int endHour   = parsed[0];
      final int endMinute = parsed[1];

      // ✅ FIX: Read fresh overtime on every tick
      final String otStr = (p.getString('cached_overtime') ?? 'no').toLowerCase().trim();
      final bool isOvertimeUser = otStr == 'yes' || otStr == 'y' || otStr == 'true' || otStr == '1';

      final DateTime now    = DateTime.now();
      final int endTotalMin = endHour * 60 + endMinute;
      final int nowTotalMin = now.hour * 60 + now.minute;
      final int diffMinutes = nowTotalMin - endTotalMin;

      debugPrint('⏰ [SHIFT END] now=${now.hour}:${now.minute}  end=$endHour:$endMinute  diff=${diffMinutes}min  overtime=$otStr');

      // ✅ FIX: Overtime user — agar aaj ka shift-end clockout already ho chuka hai
      // (yani pehle clock-out hua, phir dobara clock-in kiya) to dobara auto-clockout mat karo.
      if (isOvertimeUser) {
        final String savedDate = p.getString('shift_end_clockout_done_date') ?? '';
        final String todayStr  = DateFormat('yyyy-MM-dd').format(now);
        if (savedDate == todayStr) {
          timer.cancel();
          debugPrint('⏰ [SHIFT END] Overtime user — shift_end_clockout_done_date=today — timer cancelled (re-clock-in protected)');
          return;
        }
      }

      if (diffMinutes >= 0 && diffMinutes < 480) {
        shiftEndFired = true;
        timer.cancel();

        // ✅ FIX: Overtime user ke liye aaj ki date save karo — re-clock-in ke baad dobara
        // shift-end auto-clockout na ho.
        if (isOvertimeUser) {
          await p.setString('shift_end_clockout_done_date', DateFormat('yyyy-MM-dd').format(now));
          debugPrint('⏰ [SHIFT END] shift_end_clockout_done_date saved for overtime user');
        }

        debugPrint('⏰ [SHIFT END] ✅ FIRING auto clockout — end=$endTimeStr diff=${diffMinutes}min');

        final DateTime eventTime = DateTime.now();
        final double currentDist = await _getCurrentDistance();
        final double lat         = locationViewModel.globalLatitude1.value;
        final double lng         = locationViewModel.globalLongitude1.value;

        await _saveCriticalEventData(
          eventTime : eventTime,
          reason    : 'System Shift End - Clockout',
          distance  : currentDist,
          latitude  : lat,
          longitude : lng,
        );

        // ✅ NEW: Use alarm notification with device alarm sound + 1-min max vibration
        await _showShiftEndAlarmNotification(
          title  : '⏰ SHIFT END AUTO CLOCKOUT',
          body   : 'You have been automatically clocked out at shift end ($endTimeStr)',
          payload: 'System Clock out - On Shift end',
        );

        // ✅ NEW: Shift end pe selfie grace window activate karo
        // (foreground aur background dono cases cover hote hain)
        _initializeSelfieServiceAfterShiftEnd();

        await _handleAutoClockOut(
          reason   : 'System Clock out - On Shift end',
          context  : context,
          eventTime: eventTime,
        );
      }
    });

    debugPrint('⏰ [SHIFT END] Wall-clock poll started (every 5s, re-reads end_time each tick)');
  }

  // ── Selfie service: shift end ke baad grace window aur notifications activate karo ──────────
  // Foreground (timer fire), background (app resume), aur app-killed (cold start) — teeno cases.
  void _initializeSelfieServiceAfterShiftEnd() {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();

        // ✅ FIX: Match EXACTLY the same key resolution home_screen._loadUserData uses.
        // home_screen tries 'emp_id' first, then falls back to 'userId'.
        // home_screen tries 'company_code' for companyCode.
        String empId = (prefs.get('emp_id') ?? '').toString().trim();
        if (empId.isEmpty) {
          empId = (prefs.get('userId') ?? '').toString().trim();
          debugPrint('📸 [SELFIE INIT] emp_id empty — fell back to userId="$empId"');
        }

        // ✅ FIX: Try multiple keys for companyCode (prefCompanyCode may differ from 'company_code')
        String companyCode = (prefs.get('company_code') ?? '').toString().trim();
        if (companyCode.isEmpty) {
          companyCode = (prefs.get(prefCompanyCode) ?? '').toString().trim();
          debugPrint('📸 [SELFIE INIT] company_code empty — fell back to prefCompanyCode key="$prefCompanyCode" value="$companyCode"');
        }
        if (companyCode.isEmpty) {
          companyCode = (prefs.get('companyCode') ?? '').toString().trim();
        }

        debugPrint('');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('📸 [SELFIE INIT] ===== START =====');
        debugPrint('📸 [SELFIE INIT] empId="$empId"  companyCode="$companyCode"');

        if (empId.isEmpty || companyCode.isEmpty) {
          debugPrint('❌ [SELFIE INIT] empId or companyCode is EMPTY — dumping all prefs:');
          final Set<String> allKeys = prefs.getKeys();
          for (final k in allKeys.toList()..sort()) {
            debugPrint('📦 [SELFIE INIT]   $k = ${prefs.get(k)}');
          }
          debugPrint('❌ [SELFIE INIT] Fix: use the correct key name from the dump above.');
          debugPrint('══════════════════════════════════════════════════════');
          return;
        }

        final bool isRegistered = Get.isRegistered<SelfieNotificationPolicyService>();
        debugPrint('📸 [SELFIE INIT] Service already registered = $isRegistered');

        if (!isRegistered) {
          debugPrint('⚠️ [SELFIE INIT] NOT registered — registering now with Get.put...');
          Get.put(SelfieNotificationPolicyService(), permanent: true);
          await Future.delayed(const Duration(milliseconds: 200));
          debugPrint('✅ [SELFIE INIT] Service registered');
        }

        debugPrint('📸 [SELFIE INIT] isButtonEnabled BEFORE = ${SelfieNotificationPolicyService.to.isButtonEnabled.value}');
        debugPrint('📸 [SELFIE INIT] graceSecondsLeft BEFORE = ${SelfieNotificationPolicyService.to.graceSecondsLeft.value}');
        debugPrint('📸 [SELFIE INIT] isFetching BEFORE = ${SelfieNotificationPolicyService.to.isFetching.value}');

        await SelfieNotificationPolicyService.to.initialize(empId, companyCode);

        debugPrint('📸 [SELFIE INIT] isButtonEnabled AFTER  = ${SelfieNotificationPolicyService.to.isButtonEnabled.value}');
        debugPrint('📸 [SELFIE INIT] graceSecondsLeft AFTER  = ${SelfieNotificationPolicyService.to.graceSecondsLeft.value}');
        debugPrint('✅ [SELFIE INIT] ===== DONE =====');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('');
      } catch (e, stack) {
        debugPrint('❌ [SELFIE INIT] EXCEPTION: $e');
        debugPrint('❌ [SELFIE INIT] Stack: $stack');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ OVERTIME HELPERS — No other logic touched
  // ══════════════════════════════════════════════════════════════════════════

  // ── 1. Detect overtime clock-in ──────────────────────────────────────────
  // Returns true ONLY when:
  //   • cached_overtime == "yes" (ya equivalent)     AND
  //   • shift_end_clockout_done_date == today
  //     (yani aaj shift end ke baad pehle clock-out ho chuka)
  // Doosra koi case overtime nahi maana jata.
  Future<bool> _isOvertimeClockIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Overtime flag check
      final String otStr =
      (prefs.getString('cached_overtime') ?? 'no').toLowerCase().trim();
      final bool isOvertimeUser =
          otStr == 'yes' || otStr == 'y' || otStr == 'true' || otStr == '1';

      debugPrint('⏰ [OT DETECT] cached_overtime="$otStr"  isOvertimeUser=$isOvertimeUser');

      if (!isOvertimeUser) {
        debugPrint('⏰ [OT DETECT] → NOT overtime user — return false');
        return false;
      }

      // Shift end already hua aaj?
      final String savedDate =
          prefs.getString('shift_end_clockout_done_date') ?? '';
      final DateTime now = DateTime.now();
      final String todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      debugPrint('⏰ [OT DETECT] shift_end_clockout_done_date="$savedDate"  today="$todayStr"');

      final bool isOvertimeSession = savedDate == todayStr;
      debugPrint('⏰ [OT DETECT] → isOvertimeClockIn=$isOvertimeSession');
      return isOvertimeSession;
    } catch (e) {
      debugPrint('❌ [OT DETECT] Error: $e — returning false');
      return false;
    }
  }

  // ── 2. Callback passed to OvertimeClockOutService ────────────────────────
  // DAILY_OT_CAP expire hone par service yahan call karti hai.
  // Existing _handleAutoClockOut() use karta hai — same logic, naya reason.
  Future<void> _triggerOvertimeClockOut() async {
    if (!attendanceViewModel.isClockedIn.value) {
      debugPrint('⏰ [OT TRIGGER] Already clocked out — skip');
      return;
    }

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('⏰ [OT TRIGGER] ===== OVERTIME CAP REACHED =====');
    debugPrint('⏰ [OT TRIGGER] Triggering auto clock-out now...');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    final DateTime eventTime   = DateTime.now();
    final double   currentDist = await _getCurrentDistance();
    final double   lat         = locationViewModel.globalLatitude1.value;
    final double   lng         = locationViewModel.globalLongitude1.value;

    // Save critical event (same mechanism as shift-end clock-out)
    await _saveCriticalEventData(
      eventTime : eventTime,
      reason    : 'Overtime End - Auto Clockout',
      distance  : currentDist,
      latitude  : lat,
      longitude : lng,
    );

    // Alarm notification — device alarm sound + vibration
    await _showShiftEndAlarmNotification(
      title  : '⏰ OVERTIME ENDED',
      body   : 'Your overtime period has ended. Auto clock-out triggered.',
      payload: 'Overtime End - Auto Clockout',
    );

    // Existing auto clock-out handler — data post bhi isi mein hota hai
    await _handleAutoClockOut(
      reason   : 'Overtime End - Auto Clockout',
      context  : context,
      eventTime: eventTime,
    );
  }

  // ── 3. App kill/restart ke baad restore ──────────────────────────────────
  // Agar app kill hone se pehle overtime session tha (SharedPreferences mein
  // overtime_session_clock_in_time saved hai) to service wapas start karo.
  Future<void> _checkAndRestoreOvertimeService() async {
    try {
      final DateTime? savedTime =
      await OvertimeClockOutService.getSavedOvertimeClockInTime();

      if (savedTime == null) {
        debugPrint('⏰ [OT RESTORE] No saved OT session — nothing to restore');
        return;
      }

      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('⏰ [OT RESTORE] Saved OT session found: $savedTime');
      debugPrint('⏰ [OT RESTORE] Restoring OvertimeClockOutService...');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');

      await _overtimeService.start(
        onOvertimeExpired   : _triggerOvertimeClockOut,
        restoredClockInTime : savedTime,
      );
      try {
        await platform.invokeMethod('startOvertimeMonitor');
        debugPrint('✅ [OT RESTORE] OvertimeMonitorService restarted (Kotlin)');
      } catch (e) {
        debugPrint('⚠️ [OT RESTORE] Could not restart OvertimeMonitorService: $e');
      }
    } catch (e) {
      debugPrint('❌ [OT RESTORE] Error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO CLOCKOUT HANDLER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleAutoClockOut({
    required String   reason,
    required BuildContext context,
    DateTime? eventTime,
  }) async {
    if (_autoClockOutInProgress || !attendanceViewModel.isClockedIn.value) {
      return;
    }
    _autoClockOutInProgress = true;

    DateTime clockOutTime = eventTime ?? DateTime.now();
    double finalLat      = locationViewModel.globalLatitude1.value;
    double finalLng      = locationViewModel.globalLongitude1.value;

    debugPrint('⚡ [AUTO CLOCKOUT] Reason: $reason at $clockOutTime');

    try {
      _stopLocationMonitoring();
      unawaited(_violationVM.stopMonitoring());
      _localBackupTimer?.cancel();
      _midnightClockOutTimer?.cancel();
      _shiftEndClockOutTimer?.cancel();   // ✅ NEW: Shift end auto clock-out
      _permissionCheckTimer?.cancel();
      // ✅ OVERTIME: Cancel overtime countdown on any clock-out (manual or auto)
      unawaited(_overtimeService.cancel());
      try {
        await platform.invokeMethod('stopOvertimeMonitor');
        debugPrint('🛑 [OT] OvertimeMonitorService stopped (Kotlin)');
      } catch (e) {
        debugPrint('⚠️ [OT] Could not stop OvertimeMonitorService: $e');
      }
      // ✅ Stop auto location POST tracker
      _locationTrackerService.stop();

      // ✅ Stop bulk GPS tracker and flush remaining buffered records
      unawaited(LocationBulkTracker.instance.stopAndFlush());

      // ✅ Stop battery monitoring
      _batteryTimer?.cancel();
      _batteryTimer = null;

      final service = FlutterBackgroundService();
      service.invoke('stopService');

      await _stopNativeMonitoringService();

      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        debugPrint('⚠️ Background mode disable error: $e');
      }

      // ✅ FIX: call onClockOut() so GPS stream stops, GPX is finalized,
      // and the location table record is written with the real distance.
      await locationViewModel.onClockOut();
      final double finalDistance = locationViewModel.totalDistance.value;

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

      attendanceViewModel.isClockedIn.value = false;
      locationViewModel.isClockedIn.value   = false;
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

      // ✅ OVERTIME: Clear any running overtime session on any clock-out path
      // (manual clock-out se bhi overtime timer cancel hona chahiye)
      unawaited(_overtimeService.cancel());

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
        _refreshOvertimeFromApi();       // ← Live overtime refresh on reconnect
        _refreshEmployeeDataFromApi();   // ← Full employee data refresh on reconnect
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

  // ══════════════════════════════════════════════════════════════════════════
  // OVERTIME LIVE REFRESH
  // Called whenever device comes online. Hits the live API for this employee
  // and updates cached_overtime in SharedPreferences.
  // No other fields are changed — purely overtime-only, side-effect-free.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _refreshOvertimeFromApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _safePrefsString(prefs, 'emp_id');
      final companyCode = prefs.getString(prefCompanyCode) ?? '';

      if (userId.isEmpty || companyCode.isEmpty) {
        debugPrint('⚠️ [OVERTIME REFRESH] emp_id or companyCode missing — skip');
        return;
      }

      final loginRepo = Get.find<LoginRepository>();
      final newOvertime = await loginRepo.refreshOvertimeIfOnline(userId, companyCode);

      if (newOvertime != null) {
        debugPrint('✅ [OVERTIME REFRESH] Timer card updated overtime: $newOvertime');
      }
    } catch (e) {
      debugPrint('⚠️ [OVERTIME REFRESH] Timer card error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMPLOYEE DATA LIVE REFRESH  (every 5 s)
  // Keeps end_time, overtime, shift, image_url, dep_id up to date from the
  // live API. If device is offline the API call fails silently and the last
  // cached values remain in SharedPreferences. When connectivity restores,
  // _startAutoSyncMonitoring also fires an immediate call via
  // _refreshEmployeeDataFromApi().
  // ══════════════════════════════════════════════════════════════════════════

  void _startEmployeeDataRefresh() {
    _employeeDataRefreshTimer?.cancel();
    _employeeDataRefreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) {
          _refreshEmployeeDataFromApi();
        });
    debugPrint('✅ [EMP REFRESH] 5-second refresh timer started');
  }

  Future<void> _refreshEmployeeDataFromApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX: Snapshot old end_time BEFORE the API call so we can detect changes.
      // refreshEmployeeDataIfOnline() writes the new value into the same SharedPreferences
      // singleton, so comparing before/after gives us an exact change detection.
      final String oldEndTime = prefs.getString('cached_end_time') ?? '';

      final userId      = _safePrefsString(prefs, 'emp_id');
      final companyCode = prefs.getString(prefCompanyCode) ?? '';

      if (userId.isEmpty || companyCode.isEmpty) {
        debugPrint('⚠️ [EMP REFRESH] emp_id or companyCode missing — skip');
        return;
      }

      final loginRepo = Get.find<LoginRepository>();
      await loginRepo.refreshEmployeeDataIfOnline(userId, companyCode);
      await loginRepo.checkServerLogout(userId, companyCode);

      // ✅ FIX: If backend changed end_time while user is clocked in, we must:
      //   1. Restart _scheduleShiftEndClockOut() so the Flutter timer uses the new time
      //      (the old timer had the old time captured; Fix 1 makes it re-read each tick,
      //       but cancelling + restarting ensures shiftEndFired=false for the new time)
      //   2. Call _startNativeMonitoringService() which triggers scheduleShiftEndAlarm()
      //      in Kotlin with the fresh cached_end_time → updates the AlarmManager wakeup
      final String newEndTime = prefs.getString('cached_end_time') ?? '';
      if (newEndTime.isNotEmpty &&
          newEndTime != oldEndTime &&
          attendanceViewModel.isClockedIn.value) {
        debugPrint('⏰ [END TIME CHANGED] "$oldEndTime" → "$newEndTime" — rescheduling shift-end timer + native alarm');
        _scheduleShiftEndClockOut();     // cancel old timer, start new one for new end_time
        _startNativeMonitoringService(); // triggers scheduleShiftEndAlarm() with new end_time
      }
    } catch (e) {
      debugPrint('⚠️ [EMP REFRESH] Timer card error: $e');
    }
  }

  void _triggerAutoSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint('🔒 [AUTO-SYNC] Starting...');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      bool hasPendingGpx     = prefs.getBool('hasPendingGpxData') ?? false;
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

      // NOTE: GPX consolidation is intentionally removed from here.
      // locationViewModel.onClockOut() now handles GPX finalization and
      // the location table record directly at the moment of clock-out.
      // This block is retained only to sync any legacy pending-GPX flags
      // left from a previous app session that crashed before clock-out.
      if (hasPendingGpx) {
        try {
          if (eventDate != null) {
            await locationViewModel.consolidateDailyGPXDataForDate(eventDate);
            await locationViewModel.saveLocationFromConsolidatedFileForDate(eventDate);
          } else {
            await locationViewModel.consolidateDailyGPXData();
            await locationViewModel.saveLocationFromConsolidatedFile();
          }
          debugPrint('✅ [AUTO-SYNC] Legacy GPX data processed');
        } catch (e) {
          debugPrint('⚠️ [AUTO-SYNC] GPX processing error: $e');
        }
      }

      await attendanceViewModel.syncUnposted();
      await attendanceOutViewModel.syncUnposted();

      // ✅ NEW: Sync pending location tracking records from offline storage
      try {
        final int syncedCount = await LocationBulkTracker.instance.syncPendingRecords();
        if (syncedCount > 0) {
          debugPrint('📍 [AUTO-SYNC] ✅ Synced $syncedCount location tracking records to server');
          if (mounted) {
            Get.snackbar(
              '📍 Location Sync',
              'Synced $syncedCount GPS records',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ [AUTO-SYNC] Location tracking sync error: $e');
      }

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
    // ✅ FIX: Run in background to avoid blocking initState
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
      // ✅ NEW: App restart after kill — shift end ho chuka, selfie grace activate karo
      _initializeSelfieServiceAfterShiftEnd();
      return;
    }

    locationViewModel.isClockedIn.value   = isClockedIn;
    attendanceViewModel.isClockedIn.value = isClockedIn;

    if (isClockedIn) {
      // ✅ Run service start in microtask
      Future.microtask(() {
        _startBackgroundServices();
      });
      _startLocationMonitoring();
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _scheduleShiftEndClockOut();
      _startPermissionMonitoring();
      // ✅ OVERTIME: Agar app kill hone se pehle overtime session tha to restore karo
      unawaited(_checkAndRestoreOvertimeService());
      debugPrint('✅ [INIT] Full clocked-in state restored');
    } else {
      // ✅ FIX: On cold start while not clocked in, guarantee the timer display
      // and all related local fields are zeroed — prevents stale state from a
      // previous session that did not clean up SharedPreferences correctly.
      _localElapsedTime = '00:00:00';
      _localClockInTime = null;
      attendanceViewModel.elapsedTime.value = '00:00:00';
      debugPrint('✅ [INIT] Clean state — not clocked in');
    }

    if (mounted) setState(() {});
  }

  // ADD THIS NEW METHOD
  void _restoreEverything() {
    // ✅ FIX: Run in microtask to avoid blocking UI
    Future.microtask(() async {
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
        _scheduleShiftEndClockOut();
        _startPermissionMonitoring();
        // ✅ OVERTIME: App resume par overtime session restore karo agar active tha
        unawaited(_checkAndRestoreOvertimeService());

        if (mounted) setState(() {});
        debugPrint('✅ [RESTORE] Everything restored');
      } else {
        // ✅ FIX: Explicitly wipe any lingering timer/UI state when the app
        // resumes and the user is NOT clocked in (e.g. after clock-out + reopen).
        _localBackupTimer?.cancel();
        _localBackupTimer = null;
        _localClockInTime = null;
        _localElapsedTime = '00:00:00';
        attendanceViewModel.elapsedTime.value = '00:00:00';
        attendanceViewModel.isClockedIn.value = false;
        locationViewModel.isClockedIn.value   = false;
        if (mounted) setState(() {});
        debugPrint('✅ [RESTORE] Clean state confirmed — not clocked in');
      }
    });
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
  // GEOFENCE — GPS distance check against saved location
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _isWithinGeofence({
    required double allowedLat,
    required double allowedLng,
    required double radiusMeters,
    String? shapeCoords,   // NEW
    String? shapeType,     // NEW
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
      debugPrint('   [GEOFENCE] Distance from location: ${distanceInMeters.toStringAsFixed(1)} m');

      // ── NEW: polygon check takes priority over radius ───────────────────
      if (shapeType == 'polygon' &&
          shapeCoords != null &&
          shapeCoords.isNotEmpty) {
        final polygon = _parsePolygonCoords(shapeCoords);
        if (polygon != null && polygon.isNotEmpty) {
          final inside = _isPointInPolygon(
              currentPosition.latitude, currentPosition.longitude, polygon);
          debugPrint('🔷 [GEOFENCE] Polygon check: inside=$inside');
          return inside;
        }
      }

      // Fallback: radius check
      debugPrint('📏 [GEOFENCE] Allowed radius: $radiusMeters m');
      debugPrint('📏 [GEOFENCE] Within geofence: ${distanceInMeters <= radiusMeters}');
      return distanceInMeters <= radiusMeters;
    } catch (e) {
      debugPrint('❌ [GEOFENCE] Distance check error: $e');
      return false;
    }
  }

  // ── NEW: Polygon helpers ────────────────────────────────────────────────────

  List<Map<String, double>>? _parsePolygonCoords(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j      = jsonDecode(raw) as Map<String, dynamic>;
      final coords = (j['coordinates'] as List<dynamic>)
          .map((c) => {
        'lat': double.parse(c['lat'].toString()),
        'lng': double.parse(c['lng'].toString()),
      })
          .toList();
      return coords;
    } catch (e) {
      debugPrint('⚠️ [GEOFENCE] _parsePolygonCoords error: $e');
      return null;
    }
  }

  bool _isPointInPolygon(
      double lat, double lng, List<Map<String, double>> polygon) {
    int  n      = polygon.length;
    bool inside = false;
    int  j      = n - 1;
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

      Uint8List bytes = await photo.readAsBytes();
      debugPrint('📸 [CAMERA] Original size: ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      // Compress if larger than 1 MB
      bytes = await _compressImageIfNeeded(bytes);

      if (bytes.isEmpty) {
        debugPrint('❌ [CAMERA] Bytes are 0');
        return null;
      }

      return bytes;
    } catch (e) {
      debugPrint('❌ [CAMERA] Error capturing / compressing photo: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE COMPRESSION HELPER
  // Agar image 60 KB se zyada ho to bar bar compress karta hai
  // jab tak 60 KB ya us se neeche na aa jaye — guaranteed!
  // ══════════════════════════════════════════════════════════════════════════

  Future<Uint8List> _compressImageIfNeeded(Uint8List bytes) async {
    const int maxBytes = 60 * 1024; // 60 KB

    if (bytes.length <= maxBytes) {
      debugPrint('📸 [COMPRESS] Image is within limit — no compression needed');
      return bytes;
    }

    debugPrint('📸 [COMPRESS] Image exceeds 60 KB (${(bytes.length / 1024).toStringAsFixed(1)} KB) — compressing...');

    try {
      Uint8List current = bytes;
      int attempt = 0;

      while (current.length > maxBytes) {
        attempt++;

        final codec = await ui.instantiateImageCodec(current);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        double scale = (maxBytes / current.length);
        scale = scale.clamp(0.1, 0.9);

        final int newWidth  = (image.width  * scale).toInt().clamp(1, image.width);
        final int newHeight = (image.height * scale).toInt().clamp(1, image.height);

        final recorder = ui.PictureRecorder();
        final canvas   = Canvas(recorder);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
          Paint(),
        );
        final picture  = recorder.endRecording();
        final resized  = await picture.toImage(newWidth, newHeight);
        final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) break;

        current = byteData.buffer.asUint8List();
        debugPrint('📸 [COMPRESS] Attempt $attempt → ${(current.length / 1024).toStringAsFixed(1)} KB (${newWidth}x$newHeight)');

        if (newWidth <= 50 || newHeight <= 50) {
          debugPrint('⚠️ [COMPRESS] Image too small to reduce further — stopping');
          break;
        }
      }

      debugPrint('📸 [COMPRESS] Final size: ${(current.length / 1024).toStringAsFixed(1)} KB after $attempt attempt(s)');
      return current;
    } catch (e) {
      debugPrint('❌ [COMPRESS] Compression failed: $e — returning original bytes');
    }

    return bytes;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ SHIFT END BLOCK CHECK
  //
  // Returns true  → clocking is BLOCKED (current time is past END_TIME and
  //                 OVER_TIME is not "yes"). Caller must abort.
  // Returns false → clocking is ALLOWED.
  //
  // Rules:
  //   • OVER_TIME = "yes" / "y" / "true"  → always allow (return false).
  //   • OVER_TIME = anything else / null   → treat as "No".
  //   • END_TIME missing or unparseable    → allow (fail-open, return false).
  //   • Device current time > END_TIME     → block  (return true).
  //
  // Snackbar is shown here so the caller only needs a single `if` guard.
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> _isShiftEndBlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Read overtime flag ────────────────────────────────────────────────
      final String overtime =
      (prefs.getString('cached_overtime') ?? 'no').toLowerCase().trim();
      // ✅ FIX: Handle all possible backend values ("1", "YES", "Yes", "y", "true")
      final bool overtimeAllowed =
          overtime == 'yes' || overtime == 'y' || overtime == 'true' || overtime == '1';

      if (overtimeAllowed) {
        debugPrint('✅ [SHIFT BLOCK] Overtime allowed — clocking permitted');
        return false;
      }

      // ── Read and parse END_TIME ───────────────────────────────────────────
      final String? endTimeStr = prefs.getString('cached_end_time');
      if (endTimeStr == null || endTimeStr.isEmpty) {
        debugPrint('⏰ [SHIFT BLOCK] No cached_end_time — clocking permitted');
        return false;
      }

      final List<int>? parsed = _parseTimeTo24h(endTimeStr);
      if (parsed == null) {
        debugPrint('⚠️ [SHIFT BLOCK] Cannot parse end_time "$endTimeStr" — clocking permitted');
        return false;
      }

      final int endHour   = parsed[0];
      final int endMinute = parsed[1];

      final DateTime now    = DateTime.now();
      final int endTotalMin = endHour * 60 + endMinute;
      final int nowTotalMin = now.hour * 60 + now.minute;

      debugPrint('⏰ [SHIFT BLOCK] now=${now.hour}:${now.minute}  '
          'end=$endHour:$endMinute  overtime=$overtime  '
          'blocked=${nowTotalMin > endTotalMin}');

      if (nowTotalMin > endTotalMin) {
        if (mounted) {
          Get.snackbar(
            '🚫 Clocking Not Allowed',
            'Clocking is not allowed after your shift end time',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
            icon: const Icon(Icons.access_time_filled_rounded, color: Colors.white),
          );
        }
        debugPrint('🚫 [SHIFT BLOCK] Clocking BLOCKED — past shift end ($endTimeStr)');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ [SHIFT BLOCK] Exception: $e — clocking permitted (fail-open)');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ CLOCK IN — with camera + geofencing + MQTT + GPS tracking
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleClockIn(BuildContext context) async {
    debugPrint('🎯 [TIMERCARD] ===== CLOCK-IN STARTED =====');
    final clockInStart = DateTime.now();

    // ── 0. SHIFT END BLOCK CHECK ───────────────────────────────────────────
    if (await _isShiftEndBlocked()) return;

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

      // ── Reset travel state BEFORE clocking in ─────────────────────────────
      final travelVM = Get.find<TravelViewModel>();
      if (travelVM.isTravelMode.value || travelVM.hasPendingLocation) {
        debugPrint('🔄 [TIMERCARD] Resetting stale travel state before clock-in');
        await travelVM.cancelTravel();
      }

      // ── 4. GEOFENCING CHECK ───────────────────────────────────────────────
      // Read geo_fencing flag saved at login time.
      // 'yes' → enforce location selection + GPS boundary check (default behaviour).
      // 'no'  → skip location selection & boundary check; employee clocks in freely.
      final String geoFencingFlag =
      (prefs.getString('geoFencing') ?? 'yes').toLowerCase().trim();
      final bool isGeoFencingRequired = geoFencingFlag != 'no';

      debugPrint('🔍 [GEOFENCE] geo_fencing flag = "$geoFencingFlag" '
          '| enforced = $isGeoFencingRequired');

      final double? savedLat        = prefs.getDouble('selected_lat');
      final double? savedLng        = prefs.getDouble('selected_lng');
      final double? savedRadius     = prefs.getDouble('selected_radius');
      final String  savedName       = prefs.getString('selected_location_name') ?? '';
      final String? savedShapeCoords = prefs.getString('selected_shape_coords'); // NEW
      final String? savedShapeType   = prefs.getString('selected_shape_type');   // NEW

      if (isGeoFencingRequired) {
        // ── 4a. No location selected ────────────────────────────────────────
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

        // ── 4b. GPS distance / polygon check ────────────────────────────────
        debugPrint('🔍 [GEOFENCE] Checking GPS distance from "$savedName" '
            '| shape_type=$savedShapeType');

        final bool withinGeofence = await _isWithinGeofence(
          allowedLat   : savedLat,
          allowedLng   : savedLng,
          radiusMeters : savedRadius,
          shapeCoords  : savedShapeCoords,   // NEW
          shapeType    : savedShapeType,     // NEW
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
      } else {
        // geo_fencing = 'no' — skip all location selection & boundary checks.
        debugPrint('✅ [GEOFENCE] Skipped — geo_fencing is NO for this employee');
      }

      // ── 5. CLEAR FROZEN STATE ─────────────────────────────────────────────
      await prefs.remove(KEY_IS_TIMER_FROZEN);
      await prefs.remove(KEY_FROZEN_DISPLAY_TIME);

      // ── 6. READ EMPLOYEE DATA ─────────────────────────────────────────────
      final String empId   = _safePrefsString(prefs, 'emp_id');
      final String empName = _safePrefsStringFallback(prefs, [
        'emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name',
      ]);
      final String job  = _safePrefsStringFallback(prefs, [
        'job', 'designation', 'role', 'emp_job', 'position', 'jobTitle',
      ]);
      final String city = _safePrefsStringFallback(prefs, [
        'city', 'emp_city', 'location',
      ]);

      debugPrint('👤 [CLOCK-IN] empId=$empId | empName=$empName | job=$job | city=$city');

      // ── 7. GPX PATH ────────────────────────────────────────────────────────
      final date              = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final downloadDirectory = await getDownloadsDirectory();
      final filePath          = '${downloadDirectory!.path}/track_${empId}_$date.gpx';
      await prefs.setString(KEY_GPX_FILE_PATH, filePath);

      // ── 8. ATTENDANCE CLOCK-IN ─────────────────────────────────────────────
      await attendanceViewModel.clockIn(
        empId     : empId,
        empName   : empName,
        job       : job,
        city      : city,
        photoBytes: clockInPhotoBytes,
      );

      // ── 9. ✅ FIX: START GPS TRACKING via LocationViewModel ────────────────
      // This initialises the GPX file, starts the position stream and the
      // Kalman-filtered distance accumulator. Without this call, totalDistance
      // stays 0 and no location table record is ever written on clock-out.
      await locationViewModel.onClockIn();
      debugPrint('✅ [CLOCK-IN] GPS tracking started via locationViewModel.onClockIn()');

      // ── 10. UI UPDATE ──────────────────────────────────────────────────────
      setState(() {
        _localElapsedTime = '00:00:00';
        locationViewModel.isClockedIn.value   = true;
        attendanceViewModel.isClockedIn.value = true;
      });

      // ── 11. START TIMERS ───────────────────────────────────────────────────
      _startLocalBackupTimer();
      _scheduleMidnightClockOut();
      _scheduleShiftEndClockOut();   // ✅ NEW: must be called here at actual clock-in
      _startPermissionMonitoring();

      // ── ✅ OVERTIME AUTO CLOCK-OUT ─────────────────────────────────────────
      // Detect karo kya yeh overtime session hai:
      //   - overtime = yes  AND
      //   - shift_end_clockout_done_date = aaj (matlab shift pehle end ho chuki hai)
      // Agar haan to OvertimeClockOutService start karo jo API se DAILY_OT_CAP
      // fetch karega aur cap expire hone par auto clock-out trigger karega.
      if (await _isOvertimeClockIn()) {
        debugPrint('');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('⏰ [CLOCK-IN] OVERTIME SESSION DETECTED');
        debugPrint('⏰ [CLOCK-IN] Starting OvertimeClockOutService...');
        debugPrint('══════════════════════════════════════════════════════');
        debugPrint('');
        unawaited(_overtimeService.start(
          onOvertimeExpired: _triggerOvertimeClockOut,
        ));
        try {
          await platform.invokeMethod('startOvertimeMonitor');
          debugPrint('✅ [OT] OvertimeMonitorService started (Kotlin)');
        } catch (e) {
          debugPrint('⚠️ [OT] Could not start OvertimeMonitorService: $e');
        }
      } else {
        debugPrint('⏰ [CLOCK-IN] Not an overtime session — OvertimeClockOutService not started');
      }

      // ✅ Auto location POST — clock-in ke baad har 5 min mein server ko bhejta hai
      _locationTrackerService.start();

      // ✅ Bulk GPS tracker — start only after actual clock-in
      LocationBulkTracker.instance.start();

      // ✅ Battery monitoring — clock-in ke baad har 10 sec snackbar
      _startBatteryMonitoring();

      // ── 12. CLOSE DIALOG ───────────────────────────────────────────────────
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      Get.snackbar(
        '✅ Clocked In',
        isGeoFencingRequired
            ? 'GPS tracking started at "$savedName"'
            : 'GPS tracking started',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1A2B6D),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // ── VIOLATION MONITORING START ─────────────────────────────────────────
      // Only monitor geofence violations for employees with geo_fencing = 'yes'.
      await _violationVM.clearViolations();
      if (isGeoFencingRequired && savedLat != null && savedLng != null && savedRadius != null) {
        final double monLat    = savedLat;
        final double monLng    = savedLng;
        final double monRadius = savedRadius;
        final String monName   = savedName;
        unawaited(_violationVM.startMonitoring(
          lat          : monLat,
          lng          : monLng,
          radiusMeters : monRadius,
          locationName : monName,
          shapeCoords  : savedShapeCoords,   // NEW
          shapeType    : savedShapeType,     // NEW
        ));
      } else {
        debugPrint('ℹ️ [GEOFENCE] Violation monitoring skipped — geo_fencing is NO');
      }

      // ── MQTT CLOCK IN ──────────────────────────────────────────────────────
      final mqttOk = await _mqttTracker.clockInMqtt(
        deviceId    : empId,
        companyCode : prefs.getString(prefCompanyCode) ?? '',  // ← use the same constant
        empName     : empName,
        empImage    : prefs.getString('cached_image_url') ?? '',// ← already in scope
        depId       : prefs.getString('cached_dep_id') ?? '',
      );
      if (!mqttOk) {
        debugPrint('⚠️ MQTT unavailable — will queue locations offline');
        Get.snackbar(
          '📶 Offline Mode',
          'GPS data will sync when connected',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        debugPrint('✅ MQTT Connected — publishing locations');
      }

      debugPrint('✅ [CLOCK-IN] UI completed in '
          '${DateTime.now().difference(clockInStart).inMilliseconds}ms');

      // ── 13. BACKGROUND TASKS ───────────────────────────────────────────────
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

        // ✅ FIX: Har nayi shift pe selfie_done flag reset karo —
        // warna pichhle shift ki "done" flag aaj ka button block kar deti hai.
        if (Get.isRegistered<SelfieNotificationPolicyService>()) {
          await SelfieNotificationPolicyService.to.resetSelfieDoneFlag();
          debugPrint('✅ [CLOCK-IN] selfie_done flag reset for new shift');
        }

        debugPrint('✅ [CLOCK-IN] Background tasks completed');
      } catch (e) {
        debugPrint('⚠️ [CLOCK-IN] Background task error: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ CLOCK OUT + MQTT
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH END TIME FROM API
  // ══════════════════════════════════════════════════════════════════════════

  Future<DateTime?> _fetchEmployeeEndTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Read cached end_time from login
      final cachedEndTime = prefs.getString('cached_end_time');
      final cachedOvertime = prefs.getString('cached_overtime');
      final cachedShift = prefs.getString('cached_shift');

      debugPrint('📦 [END TIME] Cached from login: end_time=$cachedEndTime, over_time=$cachedOvertime, shift=$cachedShift');

      if (cachedEndTime == null || cachedEndTime.isEmpty) {
        debugPrint('❌ [END TIME] No end time available from login data');
        return null;
      }

      // Parse the end time
      final endTime = _endTimeStringToDateTime(cachedEndTime);

      if (endTime != null) {
        debugPrint('✅ [END TIME] Using cached end time: $cachedEndTime (shift: ${cachedShift ?? 'Day'})');
        debugPrint('   [END TIME] Overtime allowed: ${cachedOvertime?.toLowerCase() == 'yes'}');
      }

      return endTime;
    } catch (e) {
      debugPrint('❌ [END TIME] Error reading cached data: $e');
      return null;
    }
  }

  /// Get shift info for display
  Future<Map<String, dynamic>> _getEmployeeShiftInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'end_time': prefs.getString('cached_end_time') ?? '',
      'over_time': prefs.getString('cached_overtime') ?? 'No',
      'shift': prefs.getString('cached_shift') ?? 'Day',
    };
  }
  /// Parses end-time string from a raw JSON response body.
  /// Handles: flat map, items array, bare array.
  String? _parseEndTimeFromBody(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final flat = _extractEndTimeFromMap(decoded);
        if (flat != null) return flat;

        final items = decoded['items'];
        if (items is List && items.isNotEmpty && items.first is Map<String, dynamic>) {
          return _extractEndTimeFromMap(items.first as Map<String, dynamic>);
        }
      }

      if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
        return _extractEndTimeFromMap(decoded.first as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ [END TIME] JSON parse error: $e');
    }
    return null;
  }

  String? _extractEndTimeFromMap(Map<String, dynamic> map) {
    for (final key in ['end_time', 'endTime', 'end_hour', 'shift_end', 'time']) {
      final val = map[key];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return null;
  }

  /// Converts "HH:mm:ss" (or "HH:mm") string to a DateTime for today.
  /// Converts time string to a DateTime for today.
  /// ✅ FIX: Uses _parseTimeTo24h so both 12-hour (e.g. "10:16 PM") and
  /// 24-hour (e.g. "22:16") formats from backend are handled correctly.
  DateTime? _endTimeStringToDateTime(String timeStr) {
    final parsed = _parseTimeTo24h(timeStr);
    if (parsed == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, parsed[0], parsed[1], 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EARLY CLOCK-OUT CONFIRMATION DIALOG
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _showEarlyClockOutDialog(BuildContext context, DateTime endTime) async {
    final shiftInfo = await _getEmployeeShiftInfo();
    final endStr = DateFormat('hh:mm a').format(endTime);
    final shift = shiftInfo['shift'];
    final overtime = shiftInfo['over_time'].toLowerCase() == 'yes' ? ' (Overtime allowed)' : '';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Early Clock Out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Your shift ends at $endStr ($shift shift$overtime).\n'
                    'You are clocking out before the end of your workday.\n'
                    'Do you want to proceed?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('No', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B4B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Yes, Clock Out',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }
  Future<void> _handleClockOut(BuildContext context) async {
    debugPrint('🎯 [TIMERCARD] ===== CLOCK-OUT STARTED =====');

    // ── 0. SHIFT END BLOCK CHECK ───────────────────────────────────────────
    if (await _isShiftEndBlocked()) return;

    // ── Check if clocking out early ───────────────────────────────────────
    final DateTime? endTime = await _fetchEmployeeEndTime();
    if (endTime != null && DateTime.now().isBefore(endTime)) {
      debugPrint('⏰ [CLOCK-OUT] Early clockout detected — showing dialog');
      final proceed = await _showEarlyClockOutDialog(context, endTime);
      if (!proceed) {
        debugPrint('🚫 [CLOCK-OUT] User cancelled early clockout');
        return;
      }
      debugPrint('✅ [CLOCK-OUT] User confirmed early clockout — proceeding');
    }

    // ── CAMERA CAPTURE FOR CLOCK-OUT ─────────────────────────────────────
    final Uint8List? clockOutPhotoBytes = await _captureClockInPhoto();

    if (clockOutPhotoBytes == null || clockOutPhotoBytes.isEmpty) {
      Get.snackbar(
        '📷 Photo Required',
        'Please capture a photo to clock out',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
      );
      return;
    }

    debugPrint('📸 [TIMERCARD] ✅ clockOutPhotoBytes ready: ${clockOutPhotoBytes.length} bytes');

    // ── Stop all UI-side timers immediately ───────────────────────────────
    setState(() {
      _localElapsedTime = '00:00:00';
      _currentDistance  = 0.0;
    });

    // ✅ Stop auto location POST tracker on clock-out
    _locationTrackerService.stop();

    // ✅ Stop bulk GPS tracker and flush remaining buffered records
    unawaited(LocationBulkTracker.instance.stopAndFlush());

    // ✅ Stop battery monitoring on clock-out
    _batteryTimer?.cancel();
    _batteryTimer = null;

    unawaited(_violationVM.stopMonitoring());
    _stopLocationMonitoring();
    _localBackupTimer?.cancel();
    _localBackupTimer = null;                          // ✅ FIX: nullify so next clock-in starts fresh
    _midnightClockOutTimer?.cancel();
    _shiftEndClockOutTimer?.cancel();                  // ✅ FIX: was missing — prevents ghost auto-clockout in next session
    _permissionCheckTimer?.cancel();
    _localClockInTime = null;

    attendanceViewModel.stopElapsedTimer();
    attendanceViewModel.elapsedTime.value = '00:00:00'; // ✅ FIX: reset ViewModel elapsed so UI shows 00:00:00
    attendanceViewModel.isClockedIn.value = false;
    locationViewModel.isClockedIn.value   = false;

    // Show loading dialog
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
      final clockOutTime = DateTime.now();
      final prefs        = await SharedPreferences.getInstance();
      final String empId = _safePrefsString(prefs, 'emp_id');

      // ── Handle travel mode if active ──────────────────────────────────────
      final travelVM = Get.find<TravelViewModel>();
      if (travelVM.isInTravelMode) {
        debugPrint('🚗 [TIMERCARD] Manual clockout while in travel mode - ending travel');
        await travelVM.handleManualClockOut(
          empId        : empId,
          clockOutTime : clockOutTime,
        );
      }

      // ── ✅ FIX: Stop GPS stream, finalize GPX, write location table record ─
      // onClockOut() stops the position stream, flushes the GPX file, computes
      // the authoritative distance from that file, and calls _saveLocationRecord
      // which writes to the location DB table and triggers a server sync.
      await locationViewModel.onClockOut();
      final double finalDistance = locationViewModel.totalDistance.value;

      debugPrint('📏 [CLOCK-OUT] Final distance from LocationViewModel: '
          '${finalDistance.toStringAsFixed(3)} km');

      // ── Clear SharedPreferences ────────────────────────────────────────────
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

      // ✅ FIX: Clear clock-in keyed state (prefClockInTime, etc.) so the next
      // app launch cannot accidentally restore this session's clock-in time.
      await attendanceViewModel.clearClockInState();

      // ── MQTT CLOCK OUT ─────────────────────────────────────────────────────
      await _mqttTracker.clockOutMqtt();

      // ── Close loading dialog ───────────────────────────────────────────────
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      // ── Success snackbar ───────────────────────────────────────────────────
      Get.snackbar(
        '✅ Clocked Out',
        travelVM.isInTravelMode ? 'Travel ended and data saved' : 'Data saved locally',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1A2B6D),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // ── Save attendance-out record (uses real distance) ───────────────────
      unawaited(attendanceOutViewModel.fastSaveAttendanceOut(
        empId        : empId,
        clockOutTime : clockOutTime,
        totalDistance: finalDistance,
        isAuto       : false,
        reason       : travelVM.isInTravelMode
            ? 'User - Clockout'
            : 'User - Clockout',
        photoBytes   : clockOutPhotoBytes,
      ));

      // ── Post clock-out background tasks ───────────────────────────────────
      _runPostClockOutTasks(clockOutTime, finalDistance);

      // ✅ Manual clock-out pe bhi selfie grace window activate karo
      debugPrint('📸 [CLOCK-OUT] Triggering selfie init after manual clock-out');
      _initializeSelfieServiceAfterShiftEnd();
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
        debugPrint('🏁 [CLOCK-OUT] Background: stopping services...');

        // NOTE: GPX consolidation and saveLocationFromConsolidatedFile are
        // intentionally NOT called here. locationViewModel.onClockOut() already
        // handles GPX finalization and the location table write at clock-out
        // time. Calling them again here would double-post a 0-distance record.

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
    double lat         = locationViewModel.globalLatitude1.value;
    double lng         = locationViewModel.globalLongitude1.value;

    await _saveCriticalEventData(
      eventTime : breakTime,
      reason    : 'Lunch Break: User Clock Out',
      distance  : currentDist,
      latitude  : lat,
      longitude : lng,
    );

    await _showUrgentNotification(
      title  : '⏸️ BREAK STARTED',
      body   : 'Auto clocked out because Break time started\nDuration: $_localElapsedTime',
      payload: 'Lunch Break: User Clock Out',
    );

    await _handleAutoClockOut(
      reason   : 'System Break  - Clockout',
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
    <n>Daily Track ${DateFormat('dd-MM-yyyy').format(DateTime.now())}</n>
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
      case 'System midnight auto - Clockout':
        return 'Automatically clocked out at 11:58 PM';
      case 'System Clock out - Location Off':
        return 'Auto clockout because location services were turned off';
      case 'User break - Clockout':
        return 'Auto clocked out because Break time started';
      case 'System Clock out - On Shift end':
        return 'System Clock Out – On Shift End';
      case 'System Clock out - Location Off':
        return 'Auto clockout because location permission was revoked';
    // ✅ Break reasons — sab variants handle kiye
      case 'break_clockout':
      case 'Lunch Break: User Clock Out':
      case 'System Break  - Clockout':
        return '⏸️ Break time shuru — Auto Clock-Out ho gaya';
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
  // BATTERY MONITORING
  // ══════════════════════════════════════════════════════════════════════════

  void _startBatteryMonitoring() async {
    // Pehla read abhi turant
    await _updateBattery();

    // // Phir har 10 second baad snackbar ke sath
    // _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    //   await _updateBattery();
    //   if (!mounted) return;
    //
    //   final String status   = _isCharging ? '⚡ Charging' : '🔋 On Battery';
    //   final Color snackColor = _batteryLevel <= 20
    //       ? Colors.red.shade700
    //       : _batteryLevel <= 50
    //       ? Colors.orange.shade700
    //       : Colors.green.shade700;
    //
    //   final IconData iconData = _isCharging
    //       ? Icons.battery_charging_full_rounded
    //       : _batteryLevel >= 80
    //       ? Icons.battery_full_rounded
    //       : _batteryLevel >= 50
    //       ? Icons.battery_5_bar_rounded
    //       : _batteryLevel >= 20
    //       ? Icons.battery_3_bar_rounded
    //       : Icons.battery_alert_rounded;
    //
    //   Get.snackbar(
    //     '$status — $_batteryLevel%',
    //     _batteryLevel <= 20
    //         ? '⚠️ Low battery! Please charge your device.'
    //         : _batteryLevel <= 50
    //         ? 'Battery moderate — consider charging soon.'
    //         : 'Battery is good ✅',
    //     snackPosition  : SnackPosition.BOTTOM,
    //     backgroundColor: snackColor,
    //     colorText      : Colors.white,
    //     duration       : const Duration(seconds: 8),
    //     margin         : const EdgeInsets.all(12),
    //     borderRadius   : 12,
    //     icon           : Icon(iconData, color: Colors.white, size: 22),
    //     isDismissible  : true,
    //   );
    //
    //   debugPrint('🔋 [BATTERY SNACKBAR] $_batteryLevel% | $status');
    // });

    debugPrint('🔋 [BATTERY] Monitoring started — snackbar every 10 sec');
  }

  Future<void> _updateBattery() async {
    try {
      final int level          = await _battery.batteryLevel;
      final BatteryState state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _isCharging   = state == BatteryState.charging ||
              state == BatteryState.full;
        });
      }
      debugPrint('🔋 [BATTERY] Level: $level% | Charging: $_isCharging');
    } catch (e) {
      debugPrint('❌ [BATTERY] Error reading battery: $e');
    }
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
            // ── Timer Display ──────────────────────────────────────────────
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

            const SizedBox(height: 4),

            // // ── Battery Indicator — sirf clock-in ke baad dikhao ──────────
            // Obx(() {
            //   if (!attendanceViewModel.isClockedIn.value) {
            //     return const SizedBox.shrink();
            //   }
            //   return Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //         _isCharging
            //             ? Icons.battery_charging_full_rounded
            //             : _batteryLevel >= 80
            //             ? Icons.battery_full_rounded
            //             : _batteryLevel >= 50
            //             ? Icons.battery_5_bar_rounded
            //             : _batteryLevel >= 20
            //             ? Icons.battery_3_bar_rounded
            //             : Icons.battery_alert_rounded,
            //         size: 14,
            //         color: _batteryLevel <= 20
            //             ? Colors.red
            //             : _isCharging
            //             ? Colors.green
            //             : Colors.grey.shade600,
            //       ),
            //       const SizedBox(width: 4),
            //       Text(
            //         '$_batteryLevel%${_isCharging ? " ⚡" : ""}',
            //         style: TextStyle(
            //           fontSize: 11,
            //           fontWeight: FontWeight.w600,
            //           color: _batteryLevel <= 20
            //               ? Colors.red
            //               : Colors.grey.shade600,
            //         ),
            //       ),
            //     ],
            //   );
            // }),
            //
            // const SizedBox(height: 8),

            // ── Location Selector ──────────────────────────────────────────
            FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, prefsSnap) {
                final geoFlag = (prefsSnap.data?.getString('geoFencing') ?? 'yes').toLowerCase().trim();
                if (geoFlag == 'no') return const SizedBox.shrink(); // ← hide for no-geofencing employees

                return Obx(() {
                  final isClockedIn = attendanceViewModel.isClockedIn.value;
                  return GestureDetector(
                    onTap: isClockedIn
                        ? null
                        : () async {
                      final result = await Get.to<Map<String, dynamic>>(
                            () => const LocationSelectionScreen(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 300),
                      );
                      if (result != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(
                            'selected_location_id', result['location_id'] ?? 0);
                        await prefs.setString(
                            'selected_location_name', result['location_name'] ?? '');
                        await prefs.setDouble(
                            'selected_lat', (result['lat'] ?? 0.0).toDouble());
                        await prefs.setDouble(
                            'selected_lng', (result['lng'] ?? 0.0).toDouble());
                        await prefs.setDouble(
                            'selected_radius', (result['radius'] ?? 100).toDouble());
                        // NEW – save shape data from location selection
                        final shapeC = result['shape_coords']?.toString();
                        final shapeT = result['shape_type']?.toString();
                        if (shapeC != null) {
                          await prefs.setString('selected_shape_coords', shapeC);
                        } else {
                          await prefs.remove('selected_shape_coords');
                        }
                        if (shapeT != null) {
                          await prefs.setString('selected_shape_type', shapeT);
                        } else {
                          await prefs.remove('selected_shape_type');
                        }
                        if (mounted) setState(() {});
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isClockedIn
                            ? AppColors.cardBg
                            : AppColors.cyan.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isClockedIn
                              ? AppColors.divider
                              : AppColors.cyan.withOpacity(0.30),
                          width: 1,
                        ),
                      ),
                      child: FutureBuilder<SharedPreferences>(
                        future: SharedPreferences.getInstance(),
                        builder: (context, snap) {
                          final prefs       = snap.data;
                          final name        = prefs?.getString('selected_location_name') ?? '';
                          final hasLocation = name.isNotEmpty;

                          return Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: hasLocation
                                      ? AppColors.cyan.withOpacity(0.12)
                                      : AppColors.divider.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  hasLocation
                                      ? Icons.location_on_rounded
                                      : Icons.location_off_rounded,
                                  size: 15,
                                  color: hasLocation
                                      ? AppColors.cyan
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasLocation ? name : 'No location selected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: hasLocation
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isClockedIn
                                          ? 'Active session location'
                                          : hasLocation
                                          ? 'Tap to change location'
                                          : 'Tap to select before clocking in',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isClockedIn)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: hasLocation
                                      ? AppColors.cyan
                                      : AppColors.textSecondary,
                                  size: 18,
                                )
                              else
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.textSecondary,
                                  size: 15,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                });   // closes Obx
              },
            ),

            const SizedBox(height: 10),

            // ── Clock In / Clock Out Buttons ───────────────────────────────
            Obx(() {
              final isClockedIn = attendanceViewModel.isClockedIn.value;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Row(
                  children: [
                    // ── Clock In ─────────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: isClockedIn
                            ? null
                            : () async => _handleClockIn(context),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: isClockedIn
                                ? null
                                : const LinearGradient(
                              colors: [
                                AppColors.greenTeal,
                                AppColors.cyanBright,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            color: isClockedIn
                                ? AppColors.greenTeal.withOpacity(0.07)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isClockedIn
                                  ? AppColors.greenTeal.withOpacity(0.20)
                                  : Colors.transparent,
                              width: 1,
                            ),
                            boxShadow: isClockedIn
                                ? []
                                : [
                              BoxShadow(
                                color: AppColors.greenTeal.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isClockedIn
                                      ? AppColors.greenTeal.withOpacity(0.12)
                                      : Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(Icons.login_rounded,
                                    size: 13,
                                    color: isClockedIn
                                        ? AppColors.greenTeal
                                        : Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Clock In',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: isClockedIn
                                      ? AppColors.greenTeal
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Clock Out ─────────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: isClockedIn
                            ? () async => _handleClockOut(context)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: isClockedIn
                                ? const LinearGradient(
                              colors: [
                                Color(0xFFFF4B4B),
                                Color(0xFFFF7676),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                                : null,
                            color: isClockedIn
                                ? null
                                : AppColors.error.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isClockedIn
                                  ? Colors.transparent
                                  : AppColors.error.withOpacity(0.20),
                              width: 1,
                            ),
                            boxShadow: isClockedIn
                                ? [
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isClockedIn
                                      ? Colors.white.withOpacity(0.18)
                                      : AppColors.error.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(Icons.logout_rounded,
                                    size: 13,
                                    color: isClockedIn
                                        ? Colors.white
                                        : AppColors.error),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Clock Out',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: isClockedIn
                                      ? Colors.white
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Geofence Violation Report ──────────────────────────────────
            FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snap) {
                final geoFlag = (snap.data?.getString('geoFencing') ?? 'yes').toLowerCase().trim();
                if (geoFlag == 'no') return const SizedBox.shrink();
                return const GeofenceViolationReportWidget();
              },
            ),
          ],
        ),
      ),
    );
  }
}