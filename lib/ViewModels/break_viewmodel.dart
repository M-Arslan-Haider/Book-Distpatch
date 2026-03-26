import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ── BREAK CLOCKOUT: needed to check clock-in state and save attendance-out record ──
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/attendance_out_view_model.dart';

const String _apiBase =
    'http://oracle.metaxperts.net/ords/production/attendancedata';

// ─────────────────────────────────────────────
// Scheduled Break Window
// ─────────────────────────────────────────────
class ScheduledBreak {
  final String breakStart; // e.g. "13:00:00"
  final String breakEnd; // e.g. "13:30:00"
  ScheduledBreak({required this.breakStart, required this.breakEnd});
}

// ─────────────────────────────────────────────
// Break Record Model
// ─────────────────────────────────────────────
class BreakRecord {
  final String userId;
  final String breakDate; // ISO or Oracle format as used in payload
  final String startTime; // HH:MM:SS
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
  // ── Observables ──
  final RxBool isOnBreak = false.obs;
  final RxBool isLoading = false.obs;
  final Rx<BreakRecord?> activeBreak = Rx<BreakRecord?>(null);
  final RxList<BreakRecord> todayBreaks = <BreakRecord>[].obs;
  final RxString breakElapsed = '00:00'.obs;
  final Rx<ScheduledBreak?> scheduledBreak = Rx<ScheduledBreak?>(null);
  final RxString scheduledBreakInfo = 'Loading...'.obs;

  // ── Internal ──
  DateTime? _breakStartTime;
  late String _userId;
  String _empName = '';
  Timer? _autoStartTimer;

  static const _keyIsOnBreak = 'break_is_on_break';
  static const _keyBreakJson = 'break_active_record';
  static const _keyTodayBreaks = 'break_today_list';

  static const List<String> _startFields = [
    'window_start',
    'break_start_time',
    'breakstarttime',
    'break_start',
    'breakstart',
    'b_start',
    'start_break',
    'break_from',
    'breakfrom',
    'from_time',
    'break_time_from',
    'lunchstart',
    'lunch_start',
    'rest_start',
    'lunch_from',
    'rest_from',
    'shift_break_start',
    'break_start_hour',
    'break_start_minutes',
    'brkstart',
    'brk_start',
    'break_begin',
    'breakbegin',
    'lunch_time',
    'lunchtime',
    'break_time',
    'breaktime',
    'interval_start',
    'intervalstart',
    'pause_start',
    'pausestart',
    'start_time_break',
    'time_break_start',
    'emp_break_start',
  ];

  static const List<String> _endFields = [
    'window_end',
    'break_end_time',
    'breakendtime',
    'break_end',
    'breakend',
    'b_end',
    'end_break',
    'break_to',
    'breakto',
    'to_time',
    'break_time_to',
    'lunchend',
    'lunch_end',
    'rest_end',
    'lunch_to',
    'rest_to',
    'shift_break_end',
    'break_end_hour',
    'break_end_minutes',
    'brkend',
    'brk_end',
    'break_finish',
    'breakfinish',
    'lunch_end_time',
    'interval_end',
    'intervalend',
    'pause_end',
    'pauseend',
    'end_time_break',
    'time_break_end',
    'emp_break_end',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadUserId().then((_) {
      _restoreState();
      fetchScheduledBreakTime();
    });
    ever(isOnBreak, (bool onBreak) {
      if (onBreak) _startElapsedTimer();
    });
  }

  @override
  void onClose() {
    _autoStartTimer?.cancel();
    super.onClose();
  }

  // ────────────────────────────────────────────
  // FETCH: Scheduled Break Time from API
  // ────────────────────────────────────────────
  Future<void> fetchScheduledBreakTime() async {
    try {
      final url =
      Uri.parse('$_apiBase/get/$_userId').replace(queryParameters: {'user_id': _userId});

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[BreakSchedule] ► GET $url');

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('[BreakSchedule] Status: ${response.statusCode}');
      debugPrint('[BreakSchedule] Raw Body: ${response.body}');

      if (response.statusCode != 200) {
        scheduledBreakInfo.value = 'Server error: ${response.statusCode}';
        debugPrint('[BreakSchedule] ❌ HTTP Error');
        return;
      }

      final data = jsonDecode(response.body);
      debugPrint('[BreakSchedule] JSON type: ${data.runtimeType}');

      // collect ALL flat maps from the entire response tree
      final List<Map<String, dynamic>> allMaps = [];
      _collectAllMaps(data, allMaps);

      debugPrint('[BreakSchedule] Total map nodes found: ${allMaps.length}');

      // search each map for break fields
      String breakStartStr = '';
      String breakEndStr = '';

      for (final map in allMaps) {
        debugPrint('[BreakSchedule] Checking map keys: ${map.keys.toList()}');

        final s = _findField(map, _startFields);
        final e = _findField(map, _endFields);

        if (s.isNotEmpty && e.isNotEmpty) {
          breakStartStr = s;
          breakEndStr = e;
          debugPrint('[BreakSchedule] ✅ Found in map: start="$s" end="$e"');
          break;
        }

        if (s.isNotEmpty && breakStartStr.isEmpty) breakStartStr = s;
        if (e.isNotEmpty && breakEndStr.isEmpty) breakEndStr = e;
      }

      debugPrint('[BreakSchedule] Final start: "$breakStartStr"');
      debugPrint('[BreakSchedule] Final end:   "$breakEndStr"');

      if (breakStartStr.isNotEmpty && breakEndStr.isNotEmpty) {
        final startTime = _normalizeTime(breakStartStr);
        final endTime = _normalizeTime(breakEndStr);

        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          scheduledBreak.value = ScheduledBreak(
            breakStart: startTime,
            breakEnd: endTime,
          );

          final startTod = _parseTime(startTime);
          final endTod = _parseTime(endTime);
          final startFmt = startTod != null ? _formatTimeOfDay(startTod) : startTime;
          final endFmt = endTod != null ? _formatTimeOfDay(endTod) : endTime;

          scheduledBreakInfo.value = '$startFmt – $endFmt';
          debugPrint('[BreakSchedule] ✅ Break set: $startFmt → $endFmt');

          // Start auto-start timer
          _setupAutoStartTimer();

          if (!isOnBreak.value && _isBreakAllowedNow()) {
            debugPrint('[BreakSchedule] 🔔 Already in break window — auto-starting break');
            await startBreak(autoTriggered: true);
          }
        } else {
          scheduledBreakInfo.value = 'Invalid time format';
          debugPrint('[BreakSchedule] ⚠️ Time format invalid');
        }
      } else {
        scheduledBreakInfo.value = 'Break time not found';
        debugPrint('[BreakSchedule] ⚠️ Break fields not found in any map node');
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

  void _setupAutoStartTimer() {
    _autoStartTimer?.cancel();
    _autoStartTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (scheduledBreak.value == null) return;
      if (isOnBreak.value) return;

      if (_isBreakAllowedNow()) {
        final now = TimeOfDay.now();
        final start = _parseTime(scheduledBreak.value!.breakStart);
        if (start != null && now.hour == start.hour && now.minute == start.minute) {
          debugPrint('[AutoBreak] 🔔 Break time reached — auto-starting');
          await startBreak(autoTriggered: true);
        }
      }
    });
  }

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

    // HH:MM:SS or HH:MM
    if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(time)) {
      final parts = time.split(':');
      if (parts.length == 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1]}:00';
      } else if (parts.length == 3) {
        return '${parts[0].padLeft(2, '0')}:${parts[1]}:${parts[2]}';
      }
    }

    // Decimal e.g. "13.5" = 13:30
    try {
      final decimal = double.parse(time);
      final hour = decimal.toInt();
      final minute = ((decimal - hour) * 60).toInt();
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
    } catch (_) {}

    // Space-separated e.g. "13 30"
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
    debugPrint('[BreakCheck] Now: $nowMins | Start: $startMins | End: $endMins | Allowed: $allowed');
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

  // PUBLIC: Start Break
  Future<void> startBreak({bool autoTriggered = false}) async {
    if (isOnBreak.value) return;

    if (!autoTriggered && !_isBreakAllowedNow()) {
      _showBreakNotAllowedMessage();
      return;
    }

    // ══════════════════════════════════════════════════════════════════════
    // BREAK CLOCKOUT — NEW ADDITION (does NOT change any existing logic)
    // Condition: user is clocked in AND break time has started AND Break pressed
    // Action   : save critical event with reason='break_clockout' + auto clock out
    // ══════════════════════════════════════════════════════════════════════
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

        // Try to capture current location for the event record
        try {
          final pos = await _getCurrentLocation();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (e) {
          debugPrint('[Break] ⚠️ Location unavailable for break_clockout: $e');
        }

        // Save critical event data — same keys used by _saveCriticalEventData in TimerCard
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

        // Post the attendance-out record with reason='break_clockout'
        final String empId = (prefs.get('emp_id')?.toString()) ?? '';
        await attendanceOutViewModel.fastSaveAttendanceOut(
          empId        : empId,
          clockOutTime : eventTime,
          totalDistance: dist,
          isAuto       : true,
          reason       : reason,
        );

        // Update ViewModel state so UI reflects clock-out immediately
        attendanceViewModel.isClockedIn.value = false;

        debugPrint('[Break] ✅ break_clockout critical event saved. empId=$empId, time=$eventTime');
      }
    } catch (e) {
      debugPrint('[Break] ⚠️ break_clockout check error (non-fatal): $e');
      // Non-fatal — break flow continues regardless
    }
    // ══════════════════════════════════════════════════════════════════════
    // END BREAK CLOCKOUT ADDITION
    // ══════════════════════════════════════════════════════════════════════

    isLoading.value = true;
    try {
      final position = await _getCurrentLocation();
      final now = DateTime.now();

      final record = BreakRecord(
        userId: _userId,
        breakDate: _formatDateISO(now), // store ISO locally, but payload will include Oracle format
        startTime: _formatTime(now),
        startLat: position.latitude,
        startLng: position.longitude,
      );

      _breakStartTime = now;
      activeBreak.value = record;
      isOnBreak.value = true;
      await _saveStateLocally();

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

  // PUBLIC: End Break
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

      // POST to server
      await _postBreakLog(record);

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

  // ────────────────────────────────────────────
  // POST: Break log to HR_EMP_BREAK_GEO_LOG
  // Now sends time-only for start_time / end_time, keeps break_date as Oracle date.
  // Fallbacks: if server rejects, we try Oracle datetime/timestamp fallbacks.
  // ────────────────────────────────────────────
  Future<void> _postBreakLog(BreakRecord record) async {
    try {
      const String postUrl = 'http://oracle.metaxperts.net/ords/production/employeebreak/post/';

      // Oracle date string for break_date column (DD-MON-YYYY)
      final oracleDate = _toOracleDateStringFromIso(record.breakDate); // e.g., 12-MAR-2026

      // time-only values (HH:MM:SS) — EXACTLY what you wanted
      final timeOnlyStart = record.startTime; // e.g., "12:02:46"
      final timeOnlyEnd = record.endTime ?? '00:00:00';

      // Also build Oracle full timestamps (fallbacks)
      final oracleStartTs = '${oracleDate} ${timeOnlyStart}'; // 12-MAR-2026 12:02:46
      final oracleStartTsMs = '${oracleStartTs}.000';
      final oracleEndTs = '${oracleDate} ${timeOnlyEnd}';
      final oracleEndTsMs = '${oracleEndTs}.000';

      // Sanitize break_id to avoid slashes/characters
      final sanitizedDate = record.breakDate.replaceAll('-', '');
      final sanitizedTime = record.startTime.replaceAll(':', '');
      final breakId = '${record.userId}_${sanitizedDate}_$sanitizedTime';

      // Primary payload: send break_date (Oracle date) and time-only start/end
      final Map<String, dynamic> payloadMap = {
        'emp_id': record.userId,
        'emp_name': _empName,
        'break_id': breakId,
        'break_date': oracleDate, // Oracle format (date column)
        'start_time': timeOnlyStart, // TIME ONLY now
        'start_lat': record.startLat,
        'start_lng': record.startLng,
        'end_time': timeOnlyEnd, // TIME ONLY now
        'end_lat': record.endLat ?? 0.0,
        'end_lng': record.endLng ?? 0.0,
        'duration_minutes': record.durationMinutes ?? 0,
      };

      debugPrint('[BreakLog] ► POST $postUrl');
      debugPrint('[BreakLog] Attempt payload (time-only JSON): ${jsonEncode(payloadMap)}');

      // Helpers
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
            .timeout(const Duration(seconds: 15));
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
            .timeout(const Duration(seconds: 15));
      }

      http.Response resp;
      bool success = false;

      // 1) Try JSON with time-only fields + Oracle break_date (preferred)
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

      // 2) If server rejects time-only, try JSON with Oracle full timestamp (date + time)
      if (!success) {
        debugPrint('[BreakLog] time-only rejected — trying Oracle full timestamp JSON...');
        payloadMap['start_time'] = oracleStartTs;
        payloadMap['end_time'] = oracleEndTs;
        payloadMap['break_date'] = oracleDate;
        try {
          resp = await tryJsonPost(payloadMap);
          debugPrint('[BreakLog] JSON(oracle-ts) status: ${resp.statusCode}');
          debugPrint('[BreakLog] JSON(oracle-ts) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
        } catch (e) {
          debugPrint('[BreakLog] JSON(oracle-ts) POST failed: $e');
        }
      }

      // 3) If still not success, try JSON with Oracle full timestamp + .000 ms
      if (!success) {
        debugPrint('[BreakLog] Trying Oracle full timestamp with .000 ms...');
        payloadMap['start_time'] = oracleStartTsMs;
        payloadMap['end_time'] = oracleEndTsMs;
        try {
          resp = await tryJsonPost(payloadMap);
          debugPrint('[BreakLog] JSON(oracle-ms) status: ${resp.statusCode}');
          debugPrint('[BreakLog] JSON(oracle-ms) body: ${resp.body}');
          if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
        } catch (e) {
          debugPrint('[BreakLog] JSON(oracle-ms) POST failed: $e');
        }
      }

      // 4) Form-encoded fallback (time-only first)
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

      // 5) Last fallback: form-encoded with Oracle full timestamp
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

  // Local Storage
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
    _userId = prefs.getString('userId') ?? '';
    _empName = prefs.getString('userName') ?? '';
    debugPrint('[Break] userId: $_userId | empName: $_empName');
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

  // ISO date formatter YYYY-MM-DD (storage)
  String _formatDateISO(DateTime dt) => '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';

  String _formatTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';

  String _p(int n) => n.toString().padLeft(2, '0');

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  // Convert ISO date (YYYY-MM-DD) to Oracle style DD-MON-YYYY (e.g. 12-MAR-2026)
  String _toOracleDateStringFromIso(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length != 3) return isoDate; // fallback
      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 0;
      final day = parts[2];
      const mons = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      final monStr = (month >= 1 && month <= 12) ? mons[month - 1] : parts[1];
      return '${day.padLeft(2, '0')}-${monStr}-$year';
    } catch (_) {
      return isoDate;
    }
  }
}