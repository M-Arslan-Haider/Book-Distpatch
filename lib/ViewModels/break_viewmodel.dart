import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/geofancing_violation.dart';
import '../ViewModels/location_tracker_bulk_viewmodel.dart';
import '../ViewModels/location_view_model.dart';
import '../Services/remote_config_service.dart';

// ─────────────────────────────────────────────
// Scheduled Break Window
// ─────────────────────────────────────────────
class ScheduledBreak {
  final String breakStart;
  final String breakEnd;
  ScheduledBreak({required this.breakStart, required this.breakEnd});
}

// ─────────────────────────────────────────────
// Break Record Model
// ─────────────────────────────────────────────
class BreakRecord {
  final String userId;
  final String breakDate;
  final String startTime;
  final double startLat;
  final double startLng;
  String? endTime;
  double? endLat;
  double? endLng;
  int? durationMinutes;
  bool isSynced;

  BreakRecord({
    required this.userId,
    required this.breakDate,
    required this.startTime,
    required this.startLat,
    required this.startLng,
    this.endTime,
    this.endLat,
    this.endLng,
    this.durationMinutes,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'breakDate': breakDate,
    'startTime': startTime,
    'startLat': startLat,
    'startLng': startLng,
    'endTime': endTime ?? '',
    'endLat': endLat ?? 0.0,
    'endLng': endLng ?? 0.0,
    'durationMinutes': durationMinutes ?? 0,
    'isSynced': isSynced ? 1 : 0,
  };

  factory BreakRecord.fromMap(Map<String, dynamic> map) => BreakRecord(
    userId: map['userId'] ?? '',
    breakDate: map['breakDate'] ?? '',
    startTime: map['startTime'] ?? '',
    startLat: (map['startLat'] ?? 0.0).toDouble(),
    startLng: (map['startLng'] ?? 0.0).toDouble(),
    endTime: map['endTime'],
    endLat: map['endLat'] != null ? (map['endLat']).toDouble() : null,
    endLng: map['endLng'] != null ? (map['endLng']).toDouble() : null,
    durationMinutes: map['durationMinutes'],
    isSynced: (map['isSynced'] ?? 0) == 1,
  );
}

// ─────────────────────────────────────────────
// ViewModel
// ─────────────────────────────────────────────
class BreakViewModel extends GetxController {
  final RxBool isOnBreak = false.obs;
  final RxBool isLoading = false.obs;
  final Rx<BreakRecord?> activeBreak = Rx<BreakRecord?>(null);
  final RxList<BreakRecord> todayBreaks = <BreakRecord>[].obs;
  final RxString breakElapsed = '00:00'.obs;
  final Rx<ScheduledBreak?> scheduledBreak = Rx<ScheduledBreak?>(null);
  final RxString scheduledBreakInfo = 'Loading...'.obs;

  DateTime? _breakStartTime;
  late String _userId;
  String _empName = '';
  String _depId   = '';   // 🆕 dep_id — SharedPreferences se load hoga (cached_dep_id)
  Timer? _autoStartTimer;
  Timer? _breakScheduleRefreshTimer; // 🆕 har 10 sec mein API se break time fetch karo

  static const _keyScheduledBreakStart = 'break_scheduled_start'; // 🆕 local save
  static const _keyScheduledBreakEnd   = 'break_scheduled_end';   // 🆕 local save

  // ─────────────────────────────────────────────────────────────────────────
  // 🔔 NOTIFICATION — only new addition, no other logic changed
  // ─────────────────────────────────────────────────────────────────────────
  static const _breakEndNotifId   = 2001;
  static const _breakEndChannelId = 'break_end_channel';
  final _notifPlugin = FlutterLocalNotificationsPlugin();

  static const _keyIsOnBreak   = 'break_is_on_break';
  static const _keyBreakJson   = 'break_active_record';
  static const _keyTodayBreaks = 'break_today_list';

  static const List<String> _startFields = [
    'window_start', 'break_start_time', 'breakstarttime', 'break_start',
    'breakstart', 'b_start', 'start_break', 'break_from', 'breakfrom',
    'from_time', 'break_time_from', 'lunchstart', 'lunch_start', 'rest_start',
    'lunch_from', 'rest_from', 'shift_break_start', 'break_start_hour',
    'break_start_minutes', 'brkstart', 'brk_start', 'break_begin', 'breakbegin',
    'lunch_time', 'lunchtime', 'break_time', 'breaktime', 'interval_start',
    'intervalstart', 'pause_start', 'pausestart', 'start_time_break',
    'time_break_start', 'emp_break_start',
  ];

  static const List<String> _endFields = [
    'window_end', 'break_end_time', 'breakendtime', 'break_end', 'breakend',
    'b_end', 'end_break', 'break_to', 'breakto', 'to_time', 'break_time_to',
    'lunchend', 'lunch_end', 'rest_end', 'lunch_to', 'rest_to', 'shift_break_end',
    'break_end_hour', 'break_end_minutes', 'brkend', 'brk_end', 'break_finish',
    'breakfinish', 'lunch_end_time', 'interval_end', 'intervalend', 'pause_end',
    'pauseend', 'end_time_break', 'time_break_end', 'emp_break_end',
  ];

  @override
  void onInit() {
    super.onInit();
    _initBreakNotifications(); // 🔔 NEW: init plugin + create channel
    _loadUserId().then((_) {
      _restoreState();
      _restoreCachedSchedule();          // 🆕 pehle local cache se load karo
      fetchScheduledBreakTime();
      _startBreakScheduleRefreshTimer(); // 🆕 har 10 sec API poll shuru
    });
    ever(isOnBreak, (bool onBreak) {
      if (onBreak) _startElapsedTimer();
    });
  }

  @override
  void onClose() {
    _autoStartTimer?.cancel();
    _breakScheduleRefreshTimer?.cancel(); // 🆕 cleanup
    super.onClose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔔 NEW: Initialize flutter_local_notifications + dedicated break channel
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _initBreakNotifications() async {
    try {
      tz_data.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      );
      await _notifPlugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      // Create the break-end notification channel
      const breakEndChannel = AndroidNotificationChannel(
        _breakEndChannelId,
        'Break Notifications',
        description: 'Notifies when your scheduled break time is over',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      await _notifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(breakEndChannel);

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await _notifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      debugPrint('[BreakNotif] ✅ Notification plugin ready');
    } catch (e) {
      debugPrint('[BreakNotif] ⚠️ Init error (non-fatal): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔔 NEW: Schedule break-end alarm via Android AlarmManager
  //   Works in-app, background, AND when app is killed (exactAllowWhileIdle)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _scheduleBreakEndNotification() async {
    try {
      if (scheduledBreak.value == null) return;
      final end = _parseTime(scheduledBreak.value!.breakEnd);
      if (end == null) return;

      final now = DateTime.now();
      final scheduledDateTime = DateTime(
        now.year, now.month, now.day,
        end.hour, end.minute, 0,
      );

      // Skip if break end time has already passed
      if (!scheduledDateTime.isAfter(now)) {
        debugPrint('[BreakNotif] ⏭ Break end already passed — no alarm scheduled');
        return;
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        _breakEndChannelId,
        'Break Notifications',
        channelDescription: 'Notifies when your scheduled break time is over',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      await _notifPlugin.zonedSchedule(
        _breakEndNotifId,
        '⏰ Break Time Ended',
        'Aapki break khatam ho gayi — kaam par wapis aa jayein!',
        tzScheduled,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('[BreakNotif] 🔔 Alarm set for ${_formatTimeOfDay(end)}');
    } catch (e) {
      debugPrint('[BreakNotif] ⚠️ Schedule error (non-fatal): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🔔 NEW: Cancel the break-end alarm (user ended break manually early)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _cancelBreakEndNotification() async {
    try {
      await _notifPlugin.cancel(_breakEndNotifId);
      debugPrint('[BreakNotif] 🔕 Break-end alarm cancelled');
    } catch (e) {
      debugPrint('[BreakNotif] ⚠️ Cancel error (non-fatal): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🆕 Restore break schedule from local SharedPreferences cache
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _restoreCachedSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final start = prefs.getString(_keyScheduledBreakStart) ?? '';
      final end   = prefs.getString(_keyScheduledBreakEnd)   ?? '';
      if (start.isNotEmpty && end.isNotEmpty) {
        scheduledBreak.value = ScheduledBreak(breakStart: start, breakEnd: end);
        final startTod = _parseTime(start);
        final endTod   = _parseTime(end);
        final startFmt = startTod != null ? _formatTimeOfDay(startTod) : start;
        final endFmt   = endTod   != null ? _formatTimeOfDay(endTod)   : end;
        scheduledBreakInfo.value = '$startFmt – $endFmt';
        debugPrint('[BreakSchedule] ✅ Restored from cache: $startFmt – $endFmt');
      }
    } catch (e) {
      debugPrint('[BreakSchedule] ⚠️ Cache restore error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 🆕 Har 10 sec mein API se break schedule fetch karo aur locally save karo
  // ══════════════════════════════════════════════════════════════════════════
  void _startBreakScheduleRefreshTimer() {
    _breakScheduleRefreshTimer?.cancel();
    _breakScheduleRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await fetchScheduledBreakTime();
    });
    debugPrint('[BreakSchedule] 🔄 10-second refresh timer started');
  }

  // ✅ UPDATED: Using Remote Config for attendance data URL
  Future<void> fetchScheduledBreakTime() async {
    try {
      final baseUrl = RemoteConfigService.getApiBaseUrl();

      // API: GET http://oracle.metaxperts.net/ords/gps_workforce/attendancedata/get/:userid?dep_id=xxx
      // baseUrl is already 'http://oracle.metaxperts.net/ords/gps_workforce'
      final url = Uri.parse(
        '${baseUrl.replaceAll(RegExp(r'/$'), '')}'
            '/attendancedata/get/$_userId',
      ).replace(queryParameters: {
        if (_depId.isNotEmpty) 'dep_id': _depId,
      });

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[BreakSchedule] ► GET $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      debugPrint('[BreakSchedule] Status: ${response.statusCode}');
      debugPrint('[BreakSchedule] Raw Body: ${response.body}');

      if (response.statusCode != 200) {
        scheduledBreakInfo.value = 'Server error: ${response.statusCode}';
        return;
      }

      final data = jsonDecode(response.body);
      final List<Map<String, dynamic>> allMaps = [];
      _collectAllMaps(data, allMaps);

      String breakStartStr = '';
      String breakEndStr = '';

      for (final map in allMaps) {
        final s = _findField(map, _startFields);
        final e = _findField(map, _endFields);

        if (s.isNotEmpty && e.isNotEmpty) {
          breakStartStr = s;
          breakEndStr = e;
          break;
        }

        if (s.isNotEmpty && breakStartStr.isEmpty) breakStartStr = s;
        if (e.isNotEmpty && breakEndStr.isEmpty) breakEndStr = e;
      }

      if (breakStartStr.isNotEmpty && breakEndStr.isNotEmpty) {
        final startTime = _normalizeTime(breakStartStr);
        final endTime = _normalizeTime(breakEndStr);

        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          scheduledBreak.value = ScheduledBreak(
            breakStart: startTime,
            breakEnd: endTime,
          );

          // 🆕 locally save so app works offline too
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyScheduledBreakStart, startTime);
          await prefs.setString(_keyScheduledBreakEnd, endTime);

          final startTod = _parseTime(startTime);
          final endTod = _parseTime(endTime);
          final startFmt = startTod != null ? _formatTimeOfDay(startTod) : startTime;
          final endFmt = endTod != null ? _formatTimeOfDay(endTod) : endTime;

          scheduledBreakInfo.value = '$startFmt – $endFmt';
        } else {
          scheduledBreakInfo.value = 'Invalid time format';
        }
      } else {
        scheduledBreakInfo.value = 'Break time not found';
      }
    } catch (e, stack) {
      scheduledBreakInfo.value = 'Error loading schedule';
      debugPrint('[BreakSchedule] 💥 Exception: $e\n$stack');
    }
  }

  void _collectAllMaps(dynamic node, List<Map<String, dynamic>> result) {
    if (node is Map<String, dynamic>) {
      result.add(node);
      for (final value in node.values) _collectAllMaps(value, result);
    } else if (node is List) {
      for (final item in node) _collectAllMaps(item, result);
    }
  }

  // Auto-start timer removed — break sirf manually start hota hai
  void _setupAutoStartTimer() {}

  String _findField(Map<String, dynamic> data, List<String> possibleNames) {
    final lowerCaseMap = <String, dynamic>{};
    for (final entry in data.entries) {
      lowerCaseMap[entry.key.toLowerCase()] = entry.value;
    }

    for (final name in possibleNames) {
      final lower = name.toLowerCase();
      if (lowerCaseMap.containsKey(lower)) {
        final value = lowerCaseMap[lower];
        if (value != null) {
          final str = value.toString().trim();
          if (str.isNotEmpty && str != 'null') {
            return str;
          }
        }
      }
    }
    return '';
  }

  String _normalizeTime(String time) {
    if (time.isEmpty) return '';
    time = time.trim();

    if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(time)) {
      final parts = time.split(':');
      if (parts.length == 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1]}:00';
      } else if (parts.length == 3) {
        return '${parts[0].padLeft(2, '0')}:${parts[1]}:${parts[2]}';
      }
    }

    try {
      final decimal = double.parse(time);
      final hour = decimal.toInt();
      final minute = ((decimal - hour) * 60).toInt();
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
    } catch (_) {}

    if (time.contains(' ')) {
      final parts = time.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
        } catch (_) {}
      }
    }

    return '';
  }

  bool _isBreakAllowedNow() {
    if (scheduledBreak.value == null) {
      debugPrint('[BreakCheck] No scheduled break');
      return false;
    }

    final now = TimeOfDay.now();
    final start = _parseTime(scheduledBreak.value!.breakStart);
    final end = _parseTime(scheduledBreak.value!.breakEnd);

    if (start == null || end == null) {
      debugPrint('[BreakCheck] Cannot parse times');
      return false;
    }

    final nowMins = now.hour * 60 + now.minute;
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;

    final allowed = nowMins >= startMins && nowMins <= endMins;
    return allowed;
  }

  TimeOfDay? _parseTime(String t) {
    try {
      final p = t.split(':');
      if (p.length < 2) return null;
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return null;
    }
  }

  Future<void> startBreak({bool autoTriggered = false}) async {
    if (isOnBreak.value) return;

    if (!autoTriggered && !_isBreakAllowedNow()) {
      _showBreakNotAllowedMessage();
      return;
    }

    try {
      final attendanceViewModel = Get.find<AttendanceViewModel>();
      final attendanceOutViewModel = Get.find<AttendanceOutViewModel>();

      if (attendanceViewModel.isClockedIn.value && _isBreakAllowedNow()) {
        debugPrint('[Break] 🕐 User is clocked in during break time — triggering break_clockout');

        final eventTime = DateTime.now();
        double lat = 0.0;
        double lng = 0.0;
        const double dist = 0.0;
        const String reason = 'break_clockout';

        try {
          final pos = await _getCurrentLocation();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (e) {
          debugPrint('[Break] ⚠️ Location unavailable for break_clockout: $e');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_critical_event_pending', true);
        await prefs.setBool('is_timer_frozen', true);
        await prefs.setString('critical_event_timestamp', eventTime.toIso8601String());
        await prefs.setString('critical_event_reason', reason);
        await prefs.setDouble('critical_event_distance', dist);
        await prefs.setDouble('critical_event_latitude', lat);
        await prefs.setDouble('critical_event_longitude', lng);
        await prefs.setString('frozen_display_time', '00:00:00');
        await prefs.setBool('pending_gpx_close', true);
        await prefs.setString('fastClockOutTime', eventTime.toIso8601String());
        await prefs.setDouble('fastClockOutDistance', dist);
        await prefs.setString('fastClockOutReason', reason);
        await prefs.setBool('hasFastClockOutData', true);
        await prefs.setBool('clockOutPending', true);
        await prefs.setBool('isClockedIn', false);
        await prefs.setString(
          'bg_clockout_payload',
          '{"timestamp":"${eventTime.toIso8601String()}","reason":"$reason",'
              '"distance":$dist,"latitude":$lat,"longitude":$lng,"source":"break_button"}',
        );

        final String empId = (prefs.get('emp_id')?.toString()) ?? '';
        await attendanceOutViewModel.fastSaveAttendanceOut(
          empId        : empId,
          clockOutTime : eventTime,
          totalDistance: dist,
          isAuto       : true,
          reason       : reason,
        );

        attendanceViewModel.isClockedIn.value = false;
        debugPrint('[Break] ✅ break_clockout critical event saved. empId=$empId, time=$eventTime');

        // ✅ COMPLETE STOP — violation, location, bulk tracker sab band karo
        // Yeh zaroori hai warna MQTT, lat/lng aur violations clockout ke baad bhi aati rehti hain
        try {
          unawaited(Get.find<GeofenceViolationViewModel>().stopMonitoring());
          debugPrint('[Break] 🛑 Geofence violation monitoring stopped');
        } catch (_) {}
        try {
          Get.find<LocationViewModel>().isClockedIn.value = false;
          debugPrint('[Break] 🛑 LocationViewModel isClockedIn set to false');
        } catch (_) {}
        try {
          unawaited(LocationBulkTracker.instance.stopAndFlush());
          debugPrint('[Break] 🛑 LocationBulkTracker stopped and flushed');
        } catch (_) {}

        // ✅ Break reason snackbar — user ko pata chale ke clockout break ki wajah se hua
        if (Get.context != null) {
          Get.snackbar(
            '⏸️ Break Time — Auto Clock-Out',
            'Aapka break time shuru ho gaya. Clockout ho gaya.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.TOP,
            icon: const Icon(Icons.free_breakfast, color: Colors.white),
          );
        }
      }
    } catch (e) {
      debugPrint('[Break] ⚠️ break_clockout check error (non-fatal): $e');
    }

    isLoading.value = true;
    try {
      final position = await _getCurrentLocation();
      final now = DateTime.now();

      final record = BreakRecord(
        userId: _userId,
        breakDate: _formatDateISO(now),
        startTime: _formatTime(now),
        startLat: position.latitude,
        startLng: position.longitude,
      );

      _breakStartTime = now;
      activeBreak.value = record;
      isOnBreak.value = true;
      await _saveStateLocally();

      // ✅ Break start data turant POST karo (har 10 sec fetch ke baad jab break auto-start ho)
      unawaited(_postBreakLog(record));

      // 🔔 NEW: schedule break-end notification — fires even when app is killed
      await _scheduleBreakEndNotification();

      Get.snackbar(
        autoTriggered ? 'Break Shuru (Auto) ☕' : 'Break Shuru ☕',
        'Waqt: ${record.startTime}',
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.free_breakfast, color: Colors.orange),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Break start nahi ho saki: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _showBreakNotAllowedMessage() {
    final sb = scheduledBreak.value;
    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;

    String title;
    String message;

    if (sb == null) {
      title = 'Break ⛔';
      message = ' Its not break time yet. Please wait for your scheduled break.';
    } else {
      final start = _parseTime(sb.breakStart);
      final end = _parseTime(sb.breakEnd);
      final startMins = start != null ? start.hour * 60 + start.minute : 9999;

      final startFmt = start != null ? _formatTimeOfDay(start) : sb.breakStart;
      final endFmt = end != null ? _formatTimeOfDay(end) : sb.breakEnd;

      if (nowMins < startMins) {
        title = 'Break Abhi Allowed Nahi ⛔';
        message = 'Aap ki break ka waqt:\n$startFmt  ➜  $endFmt\n\nAbhi break nahi ho sakti.';
      } else {
        title = 'Break Time Guzar Gaya ⛔';
        message = 'Aap ki break ka waqt tha:\n$startFmt  ➜  $endFmt\n\nAb break nahi ho sakti.';
      }
    }

    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      duration: const Duration(seconds: 6),
      snackPosition: SnackPosition.TOP,
      icon: const Icon(Icons.access_time_filled, color: Colors.red),
    );
  }

  Future<void> endBreak() async {
    if (!isOnBreak.value || activeBreak.value == null) return;
    isLoading.value = true;

    try {
      final position = await _getCurrentLocation();
      final now = DateTime.now();
      final record = activeBreak.value!;

      record.endTime = _formatTime(now);
      record.endLat = position.latitude;
      record.endLng = position.longitude;
      if (_breakStartTime != null) {
        record.durationMinutes = now.difference(_breakStartTime!).inMinutes;
      }

      await _postBreakLog(record);

      // 🔔 NEW: cancel alarm — user ended break manually before scheduled end time
      await _cancelBreakEndNotification();

      todayBreaks.add(record);
      isOnBreak.value = false;
      activeBreak.value = null;
      _breakStartTime = null;
      breakElapsed.value = '00:00';
      await _saveStateLocally();

      Get.snackbar(
        'Break Khatam ✅',
        'Duration: ${record.durationMinutes} minutes',
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Break end nahi ho saki: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ UPDATED: Using Remote Config for break POST URL
  Future<void> _postBreakLog(BreakRecord record) async {
    try {
      final postUrl = RemoteConfigService.getBreakUrl();

      final oracleDate = _toOracleDateStringFromIso(record.breakDate);
      final timeOnlyStart = record.startTime;
      final timeOnlyEnd = record.endTime ?? '00:00:00';

      final oracleStartTs = '${oracleDate} ${timeOnlyStart}';
      final oracleStartTsMs = '${oracleStartTs}.000';
      final oracleEndTs = '${oracleDate} ${timeOnlyEnd}';
      final oracleEndTsMs = '${oracleEndTs}.000';

      final sanitizedDate = record.breakDate.replaceAll('-', '');
      final sanitizedTime = record.startTime.replaceAll(':', '');
      final breakId = '${record.userId}_${sanitizedDate}_$sanitizedTime';

      final Map<String, dynamic> payloadMap = {
        'emp_id': record.userId,
        'emp_name': _empName,
        'break_id': breakId,
        'break_date': oracleDate,
        'start_time': timeOnlyStart,
        'start_lat': record.startLat,
        'start_lng': record.startLng,
        'end_time': timeOnlyEnd,
        'end_lat': record.endLat ?? 0.0,
        'end_lng': record.endLng ?? 0.0,
        'duration_minutes': record.durationMinutes ?? 0,
      };

      debugPrint('[BreakLog] ► POST $postUrl');
      debugPrint('[BreakLog] Attempt payload (time-only JSON): ${jsonEncode(payloadMap)}');

      Future<http.Response> tryJsonPost(Map<String, dynamic> body) {
        return http
            .post(
          Uri.parse(postUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
            .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
      }

      String _formEncode(Map<String, dynamic> m) {
        final Map<String, String> s = {};
        m.forEach((k, v) => s[k] = v == null ? '' : v.toString());
        return Uri(queryParameters: s).query;
      }

      Future<http.Response> tryFormPost(Map<String, dynamic> body) {
        final encoded = _formEncode(body);
        debugPrint('[BreakLog] Attempt payload (form): $encoded');
        return http
            .post(
          Uri.parse(postUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: encoded,
        )
            .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
      }

      http.Response resp;
      bool success = false;

      // ✅ FIX: Oracle full timestamp format pehle try karo
      // time-only format Oracle DB pe ORA-01843 (not a valid month) deta hai
      // oracle-ts format (DD-MON-YYYY HH:mm:ss) hamesha 200 deta hai
      try {
        final oraclePayload = Map<String, dynamic>.from(payloadMap);
        oraclePayload['start_time'] = oracleStartTs;
        oraclePayload['end_time']   = oracleEndTs;
        oraclePayload['break_date'] = oracleDate;
        resp = await tryJsonPost(oraclePayload);
        debugPrint('[BreakLog] JSON(oracle-ts) status: ${resp.statusCode}');
        debugPrint('[BreakLog] JSON(oracle-ts) body: ${resp.body}');
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          success = true;
        }
      } catch (e) {
        debugPrint('[BreakLog] JSON(oracle-ts) POST failed: $e');
      }

      if (!success) {
        debugPrint('[BreakLog] oracle-ts rejected — trying oracle full timestamp with .000 ms...');
        try {
          final oracleMsPayload = Map<String, dynamic>.from(payloadMap);
          oracleMsPayload['start_time'] = oracleStartTsMs;
          oracleMsPayload['end_time']   = oracleEndTsMs;
          oracleMsPayload['break_date'] = oracleDate;
          resp = await tryJsonPost(oracleMsPayload);
          debugPrint('[BreakLog] JSON(oracle-ms) status: ${resp.statusCode}');
          debugPrint('[BreakLog] JSON(oracle-ms) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
        } catch (e) {
          debugPrint('[BreakLog] JSON(oracle-ms) POST failed: $e');
        }
      }

      if (!success) {
        debugPrint('[BreakLog] Trying time-only JSON as last resort...');
        try {
          resp = await tryJsonPost(payloadMap);
          debugPrint('[BreakLog] JSON(time-only) status: ${resp.statusCode}');
          debugPrint('[BreakLog] JSON(time-only) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            success = true;
          }
        } catch (e) {
          debugPrint('[BreakLog] JSON(time-only) POST failed: $e');
        }
      }

      if (!success) {
        debugPrint('[BreakLog] Trying form-encoded fallback (time-only) ...');
        final formMap = Map<String, dynamic>.from(payloadMap);
        try {
          resp = await tryFormPost(formMap);
          debugPrint('[BreakLog] FORM(time-only) status: ${resp.statusCode}');
          debugPrint('[BreakLog] FORM(time-only) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
        } catch (e) {
          debugPrint('[BreakLog] FORM(time-only) POST failed: $e');
        }
      }

      if (!success) {
        debugPrint('[BreakLog] Trying form-encoded fallback (Oracle timestamps) ...');
        final formMap = Map<String, dynamic>.from(payloadMap);
        formMap['start_time'] = oracleStartTs;
        formMap['end_time'] = oracleEndTs;
        formMap['break_date'] = oracleDate;
        try {
          resp = await tryFormPost(formMap);
          debugPrint('[BreakLog] FORM(oracle-ts) status: ${resp.statusCode}');
          debugPrint('[BreakLog] FORM(oracle-ts) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
        } catch (e) {
          debugPrint('[BreakLog] FORM(oracle-ts) POST failed: $e');
        }
      }

      if (success) {
        record.isSynced = true;
        debugPrint('[BreakLog] ✅ Synced successfully');
      } else {
        debugPrint('[BreakLog] ⚠️ All attempts failed. Record will remain unsynced.');
      }
    } catch (e, stack) {
      debugPrint('[BreakLog] 💥 Unexpected exception: $e\n$stack');
    }
  }

  Future<void> _saveStateLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsOnBreak, isOnBreak.value);
    if (activeBreak.value != null) {
      await prefs.setString(_keyBreakJson, jsonEncode(activeBreak.value!.toMap()));
    } else {
      await prefs.remove(_keyBreakJson);
    }
    await prefs.setStringList(_keyTodayBreaks,
        todayBreaks.map((b) => jsonEncode(b.toMap())).toList());
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final todayList = prefs.getStringList(_keyTodayBreaks) ?? [];
    todayBreaks.value = todayList
        .map((s) => BreakRecord.fromMap(jsonDecode(s)))
        .where((b) => b.breakDate == _formatDateISO(DateTime.now()))
        .toList();

    if ((prefs.getBool(_keyIsOnBreak) ?? false)) {
      final activeJson = prefs.getString(_keyBreakJson);
      if (activeJson != null) {
        final record = BreakRecord.fromMap(jsonDecode(activeJson));
        if (record.breakDate == _formatDateISO(DateTime.now())) {
          activeBreak.value = record;
          isOnBreak.value = true;
          try {
            final p = record.startTime.split(':');
            final n = DateTime.now();
            _breakStartTime =
                DateTime(n.year, n.month, n.day, int.parse(p[0]), int.parse(p[1]));
          } catch (_) {
            _breakStartTime = DateTime.now();
          }
        } else {
          await prefs.remove(_keyBreakJson);
          await prefs.setBool(_keyIsOnBreak, false);
        }
      }
    }
  }

  void _startElapsedTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!isOnBreak.value || _breakStartTime == null) return false;
      final diff = DateTime.now().difference(_breakStartTime!);
      breakElapsed.value =
      '${diff.inMinutes.toString().padLeft(2, '0')}:'
          '${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
      return true;
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId  = prefs.getString('userId') ?? '';
    _empName = prefs.getString('userName') ?? '';
    _depId   = prefs.getString('cached_dep_id') ?? '';  // 🆕 dep_id load
    debugPrint('[Break] userId: $_userId | empName: $_empName | depId: $_depId');
  }

  Future<Position> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location service band hai');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Location permission nahi mili');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  String _formatDateISO(DateTime dt) => '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
  String _formatTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';
  String _p(int n) => n.toString().padLeft(2, '0');

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _toOracleDateStringFromIso(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length != 3) return isoDate;
      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 0;
      final day = parts[2];
      const mons = [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ];
      final monStr = (month >= 1 && month <= 12) ? mons[month - 1] : parts[1];
      return '${day.padLeft(2, '0')}-${monStr}-$year';
    } catch (_) {
      return isoDate;
    }
  }
}