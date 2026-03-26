
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Models/attendanceOut_model.dart';
import '../Repositories/attendance_out_repository.dart';
import 'attendance_view_model.dart';
import 'location_view_model.dart';

class AttendanceOutViewModel extends GetxController {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final AttendanceOutRepository _repo         = AttendanceOutRepository();
  final LocationViewModel       _locVM        = Get.put(LocationViewModel());
  final AttendanceViewModel     _inVM         = Get.find<AttendanceViewModel>();
  final Connectivity            _connectivity = Connectivity();

  // ── Observables ───────────────────────────────────────────────────────────
  var allAttendanceOut = <AttendanceOutModel>[].obs;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _autoClockOutTimer;
  Timer? _periodicSyncTimer;

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _keyClockInTime        = 'clockInTime';
  static const String _keyIsClockedIn        = 'isClockedIn';
  // ✅ All three keys written by attendance_view_model on clock-in
  static const String _keyAttendanceId       = 'attendanceId';
  static const String _keyCurrentId          = 'currentAttendanceId';
  static const String _keyClockInAltId       = 'clockInAttendanceId';
  static const String _keyBackupData         = 'backupClockOutData';
  static const String _keyHasBackup          = 'hasBackupClockOutData';
  static const String _keyBackupDistance     = 'backupDistance';
  static const String _keyClockOutDistance   = 'clockOutDistance';
  static const String _keyFastData           = 'fastClockOutData';
  static const String _keyHasFastData        = 'hasFastClockOutData';
  static const String _keyFastClockOutTime   = 'fastClockOutTime';
  static const String _keyFastClockOutDist   = 'fastClockOutDistance';
  static const String _keyFastClockOutReason = 'fastClockOutReason';
  static const String _keyCriticalEvent      = 'has_critical_event_pending';

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    fetchAllAttendanceOut();
    _syncUnposted();
    restoreFromBackupIfNeeded();
    restoreFastDataOnStartup();
    _startAutoClockOutTimer();
    _startPeriodicSyncTimer();
  }

  @override
  void onClose() {
    _autoClockOutTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – PRIMARY CLOCK-OUT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clockOut({
    required String empId,
    DateTime? clockOutTime,
    double? totalDistance,
    bool isAuto = false,
    String reason = 'manual',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final DateTime outTime = clockOutTime ?? DateTime.now();

    // ✅ 12-hour format with AM/PM
    debugPrint('🕐 [OutVM] Clock-out time: ${DateFormat('hh:mm:ss a').format(outTime)}');
    debugPrint('📱 [OutVM] Device time:    ${DateFormat('hh:mm:ss a').format(DateTime.now())}');
    debugPrint('🤖 [OutVM] Auto: $isAuto, Reason: $reason');

    // ── 1. Calculate total shift time ──────────────────────────────────────
    final String? clockInStr  = prefs.getString(_keyClockInTime);
    final DateTime shiftStart = clockInStr != null
        ? DateTime.parse(clockInStr)
        : outTime.subtract(const Duration(hours: 1));
    final String totalTime = _formatDuration(outTime.difference(shiftStart));

    // ── 2. Resolve total distance ──────────────────────────────────────────
    final double finalDistance = await _resolveDistance(
      provided  : totalDistance,
      prefs     : prefs,
      shiftStart: shiftStart,
    );

    // ── 3. Resolve attendance-out ID ──────────────────────────────────────
    // ✅ Check all three keys that clock-in writes
    String attendanceOutId = prefs.getString(_keyAttendanceId)
        ?? prefs.getString(_keyCurrentId)
        ?? prefs.getString(_keyClockInAltId)
        ?? '';

    if (attendanceOutId.isEmpty) {
      attendanceOutId = 'UNKWN_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('⚠️ [OutVM] No attendanceId found — using fallback: $attendanceOutId');

      await _saveBackup(
        attendanceOutId: attendanceOutId,
        empId          : empId,
        clockOutTime   : outTime,
        totalTime      : totalTime,
        totalDistance  : finalDistance,
        address        : _locVM.shopAddress.value,
        reason         : reason,
      );
      return;
    }

    // ── 4. Build address ───────────────────────────────────────────────────
    String address = _locVM.shopAddress.value;
    if (isAuto) {
      address = '$address (Auto clock-out: $reason at ${DateFormat('hh:mm a').format(outTime)})';
    }

    // ── 5. Persist backup immediately ─────────────────────────────────────
    await _saveBackup(
      attendanceOutId: attendanceOutId,
      empId          : empId,
      clockOutTime   : outTime,
      totalTime      : totalTime,
      totalDistance  : finalDistance,
      address        : address,
      reason         : reason,
    );

    // ── 6. Build model — original field types preserved ───────────────────
    final model = AttendanceOutModel(
      attendance_out_id  : attendanceOutId,
      emp_id             : empId,
      total_time         : totalTime,
      total_distance     : finalDistance.toString(),
      lat_out            : _locVM.globalLatitude1.value.toString(),
      lng_out            : _locVM.globalLongitude1.value.toString(),
      address            : address,
      reason             : reason,
      attendance_out_time: outTime,   // ✅ real event time
      attendance_out_date: outTime,   // ✅ real event date
      posted             : 0,
    );

    debugPrint('📊 [OutVM] ID=$attendanceOutId | dist=${finalDistance.toStringAsFixed(3)} km | time=$totalTime');

    // ── 7. Save to local DB ────────────────────────────────────────────────
    await addAttendanceOut(model);

    // ── 8. Try sync to server ──────────────────────────────────────────────
    await _postIfOnline(prefs);

    // ── 9. Clear clock-in state ────────────────────────────────────────────
    await _inVM.clearClockInState();

    debugPrint('✅ [OutVM] Clock-out complete. Distance: ${finalDistance.toStringAsFixed(3)} km');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – FAST CLOCK-OUT  (< 1 second, UI unblocked)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fastSaveAttendanceOut({
    String empId = '',
    required DateTime clockOutTime,
    required double totalDistance,
    bool isAuto = false,
    String reason = 'fast_manual',
  }) async {
    debugPrint('⚡ [OutVM] Fast clock-out started');

    final prefs = await SharedPreferences.getInstance();

    final String resolvedEmpId =
    empId.isNotEmpty ? empId : (prefs.getString('emp_id') ?? '');

    // ✅ Read all three keys for ID pairing
    String attendanceOutId = prefs.getString(_keyAttendanceId)
        ?? prefs.getString(_keyCurrentId)
        ?? prefs.getString(_keyClockInAltId)
        ?? '';

    if (attendanceOutId.isEmpty) {
      attendanceOutId = 'FAST_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('fastAttendanceId', attendanceOutId);
    }

    final String? clockInStr = prefs.getString(_keyClockInTime);
    String totalTime = '00:00:00';
    if (clockInStr != null) {
      try {
        totalTime = _formatDuration(
            clockOutTime.difference(DateTime.parse(clockInStr)));
      } catch (_) {}
    }

    // Persist fast data keys for restore on next launch
    final Map<String, dynamic> fastData = {
      'fast_attendanceId' : attendanceOutId,
      'fast_empId'        : resolvedEmpId,
      'fast_clockOutTime' : clockOutTime.toIso8601String(),
      'fast_totalTime'    : totalTime,
      'fast_totalDistance': totalDistance,
      'fast_latOut'       : _locVM.globalLatitude1.value,
      'fast_lngOut'       : _locVM.globalLongitude1.value,
      'fast_address'      : _locVM.shopAddress.value,
      'fast_reason'       : reason,
      'fast_savedAt'      : DateTime.now().millisecondsSinceEpoch.toString(),
    };

    await prefs.setString(_keyFastData, jsonEncode(fastData));
    await prefs.setBool(_keyHasFastData, true);
    await prefs.setDouble(_keyClockOutDistance, totalDistance);
    await prefs.setString(_keyFastClockOutTime, clockOutTime.toIso8601String());
    await prefs.setDouble(_keyFastClockOutDist, totalDistance);
    await prefs.setString(_keyFastClockOutReason, reason);

    debugPrint('⚡ [OutVM] Fast data persisted. Scheduling background save...');

    // Save to DB and sync after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final model = AttendanceOutModel(
          attendance_out_id  : attendanceOutId,
          emp_id             : resolvedEmpId,
          total_time         : totalTime,
          total_distance     : totalDistance.toString(),
          lat_out            : _locVM.globalLatitude1.value.toString(),
          lng_out            : _locVM.globalLongitude1.value.toString(),
          address            : _locVM.shopAddress.value,
          reason             : reason,
          attendance_out_time: clockOutTime,   // ✅ real event time
          attendance_out_date: clockOutTime,   // ✅ real event date
          posted             : 0,
        );

        await addAttendanceOut(model);
        debugPrint('⚡ [OutVM] Fast DB save done');

        // Delayed sync
        Timer(const Duration(seconds: 10), () async {
          if (await _isOnline()) {
            await _repo.syncUnposted();
            await fetchAllAttendanceOut();
            await prefs.setBool(_keyHasFastData, false);
            await prefs.remove(_keyFastData);
            debugPrint('⚡ [OutVM] Delayed sync complete');
          }
        });
      } catch (e) {
        debugPrint('⚠️ [OutVM] Fast save background error: $e');
      }
    });

    debugPrint('⚡ [OutVM] Fast clock-out returned in <1s');
    debugPrint('   - Distance: ${totalDistance.toStringAsFixed(3)} km | Time: $totalTime');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DIRECT SAVE WITH DISTANCE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveWithDistance({
    required String   empId,
    required String   attendanceOutId,
    required double   distance,
    required DateTime clockOutTime,
    String address = '',
    bool isAuto    = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? clockInStr  = prefs.getString(_keyClockInTime);
    final DateTime shiftStart = clockInStr != null
        ? DateTime.parse(clockInStr)
        : clockOutTime.subtract(const Duration(hours: 1));
    final String totalTime = _formatDuration(clockOutTime.difference(shiftStart));

    String finalAddress = address.isNotEmpty ? address : _locVM.shopAddress.value;
    if (isAuto) {
      finalAddress =
      '$finalAddress (Auto clock-out at ${DateFormat('hh:mm a').format(clockOutTime)})';
    }

    final model = AttendanceOutModel(
      attendance_out_id  : attendanceOutId,
      emp_id             : empId,
      total_time         : totalTime,
      total_distance     : distance.toString(),
      lat_out            : _locVM.globalLatitude1.value.toString(),
      lng_out            : _locVM.globalLongitude1.value.toString(),
      address            : finalAddress,
      reason             : isAuto ? 'direct_auto' : 'direct_manual',
      attendance_out_time: clockOutTime,   // ✅ real event time
      attendance_out_date: clockOutTime,   // ✅ real event date
      posted             : 0,
    );

    await addAttendanceOut(model);
    await _saveBackup(
      attendanceOutId: attendanceOutId,
      empId          : empId,
      clockOutTime   : clockOutTime,
      totalTime      : totalTime,
      totalDistance  : distance,
      address        : finalAddress,
      reason         : model.reason ?? (isAuto ? 'direct_auto' : 'direct_manual'),
    );
    await _postIfOnline(prefs);

    debugPrint('✅ [OutVM] saveWithDistance done: ${distance.toStringAsFixed(3)} km');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – LEGACY ALIAS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveFormAttendanceOut({DateTime? clockOutTime}) async {
    final prefs = await SharedPreferences.getInstance();
    final empId = prefs.getString('emp_id') ?? '';
    await clockOut(
      empId       : empId,
      clockOutTime: clockOutTime,
      isAuto      : clockOutTime != null,
      reason      : clockOutTime != null ? 'legacy_auto' : 'manual',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – FETCH / ADD / DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchAllAttendanceOut() async {
    allAttendanceOut.value = await _repo.getAll();
  }

  Future<void> addAttendanceOut(AttendanceOutModel model) async {
    await _repo.add(model);
    await fetchAllAttendanceOut();
  }

  Future<void> deleteAttendanceOut(String id) async {
    await _repo.delete(id);
    await fetchAllAttendanceOut();
  }

  Future<void> syncNow() async {
    if (await _isOnline()) {
      await _repo.syncUnposted();
      await fetchAllAttendanceOut();
      final prefs = await SharedPreferences.getInstance();
      await _clearBackupKeys(prefs);
      debugPrint('✅ [OutVM] Sync done');
    }
  }

  Future<void> syncUnposted() async => syncNow();

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – RESTORE METHODS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> restoreFromBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyHasBackup) ?? false)) return;

    final jsonStr = prefs.getString(_keyBackupData) ?? '{}';
    try {
      final data    = jsonDecode(jsonStr) as Map<String, dynamic>;
      final timeStr = data['backup_clockOutTime'] as String?;

      debugPrint('🔄 [OutVM] Restoring backup...');
      debugPrint('   - ID: ${data['backup_attendanceId']} | Reason: ${data['backup_reason']}');
      debugPrint('   - Distance: ${data['backup_totalDistance']} km');

      if (timeStr != null) {
        final realTime = DateTime.parse(timeStr);
        final dist     = (data['backup_totalDistance'] as num?)?.toDouble() ?? 0.0;
        final reason   = data['backup_reason'] as String? ?? 'backup_restored';
        final empId    = data['backup_empId'] as String? ?? '';

        debugPrint('✅ [OutVM] Restore with real time=$realTime');

        await clockOut(
          empId        : empId,
          clockOutTime : realTime,
          totalDistance: dist,
          isAuto       : true,
          reason       : reason,
        );

        await prefs.setBool(_keyHasBackup, false);
        await prefs.remove(_keyBackupData);
        await prefs.remove(_keyBackupDistance);
        debugPrint('✅ [OutVM] Backup restored');
      } else {
        // Fallback — build model directly from backup data
        final String? fbStr  = data['backup_clockOutTime'] as String?;
        final DateTime fbTime = fbStr != null
            ? DateTime.tryParse(fbStr) ?? DateTime.now()
            : DateTime.now();

        await addAttendanceOut(AttendanceOutModel(
          attendance_out_id  : data['backup_attendanceId'] ?? '',
          emp_id             : data['backup_empId'] ?? '',
          total_time         : data['backup_totalTime'] ?? '00:00:00',
          total_distance     :
          ((data['backup_totalDistance'] as num?)?.toDouble() ?? 0.0).toString(),
          lat_out            : (data['backup_latOut'] ?? 0.0).toString(),
          lng_out            : (data['backup_lngOut'] ?? 0.0).toString(),
          address            : data['backup_address'] ?? '',
          attendance_out_time: fbTime,   // ✅ real time
          attendance_out_date: fbTime,   // ✅ real date
          posted             : 0,
        ));

        if (await _isOnline()) {
          await _repo.syncUnposted();
          await fetchAllAttendanceOut();
          await _clearBackupKeys(prefs);
        }
      }
    } catch (e) {
      debugPrint('❌ [OutVM] restoreFromBackupIfNeeded error: $e');
    }
  }

  Future<void> restoreFastDataOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyHasFastData) ?? false)) return;

    // Let critical-event handler take priority
    if (prefs.getBool(_keyCriticalEvent) ?? false) {
      debugPrint('⏭️ [OutVM] Critical event pending — skipping fast restore');
      return;
    }

    debugPrint('🔄 [OutVM] Restoring fast clock-out data...');
    try {
      // Prefer individual key (set by Kotlin service); fall back to JSON blob
      String? timeStr = prefs.getString(_keyFastClockOutTime);
      if (timeStr == null) {
        final blob = prefs.getString(_keyFastData) ?? '{}';
        timeStr =
        (jsonDecode(blob) as Map<String, dynamic>)['fast_clockOutTime'] as String?;
      }

      if (timeStr == null || timeStr.isEmpty) {
        debugPrint('⚠️ [OutVM] No valid fast timestamp — skipping restore');
        return;
      }

      double dist = prefs.getDouble(_keyFastClockOutDist) ?? 0.0;
      if (dist == 0.0) {
        final blob = prefs.getString(_keyFastData) ?? '{}';
        dist = ((jsonDecode(blob) as Map<String, dynamic>)['fast_totalDistance'] as num?)
            ?.toDouble() ??
            0.0;
      }

      final String   reason   = prefs.getString(_keyFastClockOutReason) ?? 'background_auto';
      final DateTime realTime = DateTime.parse(timeStr);

      String empId = '';
      try {
        final blob = prefs.getString(_keyFastData) ?? '{}';
        empId =
            (jsonDecode(blob) as Map<String, dynamic>)['fast_empId'] as String? ?? '';
      } catch (_) {}

      debugPrint('✅ [OutVM] Fast restore: time=$realTime, dist=$dist km');

      await clockOut(
        empId        : empId,
        clockOutTime : realTime,
        totalDistance: dist,
        isAuto       : true,
        reason       : reason,
      );

      await prefs.setBool(_keyHasFastData, false);
      await prefs.remove(_keyFastData);
      await prefs.remove(_keyFastClockOutTime);
      await prefs.remove(_keyFastClockOutDist);
      await prefs.remove(_keyFastClockOutReason);

      debugPrint('✅ [OutVM] Fast restore complete');
    } catch (e) {
      debugPrint('❌ [OutVM] restoreFastDataOnStartup error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – AUTO CLOCK-OUT HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> shouldAutoClockOut() async {
    final now = DateTime.now();
    if (now.hour != 23 || now.minute != 58) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsClockedIn) ?? false;
  }

  DateTime getAutoClockOutTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 58, 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DEBUG
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> debugDatabase() async {
    final records = await _repo.getAll();
    if (records.isEmpty) {
      debugPrint('📭 [OutVM] No records in DB');
      return;
    }
    for (final r in records) {
      debugPrint(
          '📊 ID=${r.attendance_out_id} | dist=${r.total_distance} km | time=${r.total_time} | posted=${r.posted}');
    }
  }

  /// Today's clock-out count matched using yyyy-MM-dd date format
  Future<int> todayClockOutsCount() async {
    final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final records = await _repo.getAll();
    return records
        .where((r) => r.attendance_out_date?.toString().contains(today) ?? false)
        .length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – AUTO CLOCK-OUT TIMER (checks every minute for 23:58)
  // ─────────────────────────────────────────────────────────────────────────

  void _startAutoClockOutTimer() {
    debugPrint('⏰ [OutVM] Starting auto clock-out timer for 11:58 PM');
    _autoClockOutTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkAutoClockOut());
    _checkAutoClockOut();
  }

  Future<void> _checkAutoClockOut() async {
    try {
      final now = DateTime.now();
      if (now.hour != 23 || now.minute != 58) return;

      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_keyIsClockedIn) ?? false)) {
        debugPrint('⏰ [OutVM] Already clocked out at 11:58 PM');
        return;
      }

      debugPrint('🕰 [OutVM] 11:58 PM — auto clock-out triggered');

      final String empId = _getStringFromPrefs(prefs, 'emp_id');

      await clockOut(
        empId       : empId,
        clockOutTime: DateTime(now.year, now.month, now.day, 23, 58, 0),
        isAuto      : true,
        reason      : '11:58_pm_auto',
      );

      Get.snackbar(
        'Auto Clock-Out',
        'Automatically clocked out at 11:58 PM',
        snackPosition   : SnackPosition.TOP,
        backgroundColor : Colors.purple.shade700,
        colorText       : Colors.white,
        duration        : const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('❌ [OutVM] Auto clock-out error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – PERIODIC SYNC (every 5 minutes)
  // ─────────────────────────────────────────────────────────────────────────

  void _startPeriodicSyncTimer() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_keyHasBackup) ?? false)) return;

        if (await _isOnline()) {
          debugPrint('🔄 [OutVM] Periodic sync — internet available');
          await _repo.syncUnposted();
          await fetchAllAttendanceOut();
          await _clearBackupKeys(prefs);
          debugPrint('✅ [OutVM] Periodic sync complete');
        }
      } catch (e) {
        debugPrint('❌ [OutVM] Periodic sync error: $e');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _syncUnposted() async {
    if (await _isOnline()) {
      await _repo.syncUnposted();
      await fetchAllAttendanceOut();
    }
  }

  Future<void> _postIfOnline(SharedPreferences prefs) async {
    if (await _isOnline()) {
      await _repo.syncUnposted();
      await fetchAllAttendanceOut();
      await _clearBackupKeys(prefs);
      debugPrint('✅ [OutVM] Synced to server');
    } else {
      debugPrint('🌐 [OutVM] Offline — will sync later');
    }
  }

  Future<bool> _isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<double> _resolveDistance({
    required double? provided,
    required SharedPreferences prefs,
    required DateTime shiftStart,
  }) async {
    if (provided != null && provided > 0) {
      debugPrint('📍 [OutVM] Using provided distance: ${provided.toStringAsFixed(3)} km');
      return provided;
    }

    final saved = prefs.getDouble(_keyClockOutDistance) ?? 0.0;
    if (saved > 0) {
      debugPrint('📍 [OutVM] Using saved distance: ${saved.toStringAsFixed(3)} km');
      return saved;
    }

    final backup = prefs.getDouble(_keyBackupDistance) ?? 0.0;
    if (backup > 0) {
      debugPrint('📍 [OutVM] Using backup distance: ${backup.toStringAsFixed(3)} km');
      return backup;
    }

    try {
      final calc = await _locVM.calculateShiftDistance(shiftStart);
      debugPrint('📍 [OutVM] Calculated distance: ${calc.toStringAsFixed(3)} km');
      return calc;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _saveBackup({
    required String   attendanceOutId,
    required String   empId,
    required DateTime clockOutTime,
    required String   totalTime,
    required double   totalDistance,
    required String   address,
    required String   reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data  = {
      'backup_attendanceId'  : attendanceOutId,
      'backup_empId'         : empId,
      'backup_clockOutTime'  : clockOutTime.toIso8601String(),
      'backup_totalTime'     : totalTime,
      'backup_totalDistance' : totalDistance,
      'backup_latOut'        : _locVM.globalLatitude1.value,
      'backup_lngOut'        : _locVM.globalLongitude1.value,
      'backup_address'       : address,
      'backup_reason'        : reason,
      'backup_savedAt'       : DateTime.now().toIso8601String(),
    };
    await prefs.setString(_keyBackupData, jsonEncode(data));
    await prefs.setBool(_keyHasBackup, true);
    await prefs.setDouble(_keyBackupDistance, totalDistance);
    debugPrint('📱 [OutVM] Backup saved: ${totalDistance.toStringAsFixed(3)} km');
  }

  Future<void> _clearBackupKeys(SharedPreferences prefs) async {
    await prefs.setBool(_keyHasBackup, false);
    await prefs.remove(_keyBackupData);
    await prefs.remove(_keyBackupDistance);
    await prefs.remove(_keyClockOutDistance);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  /// Parse time from address string like "... (Auto clock-out: reason at 03:45 PM)"
  DateTime? _parseTimeFromAddress(String? address) {
    if (address == null) return null;
    try {
      final regex = RegExp(r'at (\d{2}:\d{2} [AP]M)');
      final match = regex.firstMatch(address);
      if (match != null) {
        final timeStr    = match.group(1) ?? '';
        final parts      = timeStr.split(RegExp(r'[: ]'));
        int    hour      = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);
        final bool isPM  = parts[2] == 'PM';
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  String _getStringFromPrefs(SharedPreferences prefs, String key) {
    try {
      return prefs.getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }
}