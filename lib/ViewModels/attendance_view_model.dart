
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../Models/attendance_Model.dart';
import '../Repositories/attendance_repository.dart';
import 'location_view_model.dart';
import 'dart:typed_data';

class AttendanceViewModel extends GetxController {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final AttendanceRepository _repo       = AttendanceRepository();
  final LocationViewModel    _locationVM = Get.put(LocationViewModel());

  // ── Observables ───────────────────────────────────────────────────────────
  var allAttendance = <AttendanceModel>[].obs;
  var isClockedIn   = false.obs;
  var elapsedTime   = '00:00:00'.obs;
  var isLoading     = false.obs;

  // ── Timer state ───────────────────────────────────────────────────────────
  DateTime? _clockInTime;
  Timer?    _timer;

  // ── Serial counter state ──────────────────────────────────────────────────
  int    _serialCounter   = 1;
  String _currentMonth    = DateFormat('MMM').format(DateTime.now());

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _keyClockInTime   = 'clockInTime';
  static const String _keyCurrentId     = 'currentAttendanceId';
  static const String _keyAttendanceId  = 'attendanceId';         // ✅ also written so clock-out can read it
  static const String _keyTotalTime     = 'totalTime';
  static const String _keySecondsPassed = 'secondsPassed';
  static const String _keyIsClockedIn   = 'isClockedIn';

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    fetchAllAttendance();
    _restoreClockState();
    _initSerialCounter();
  }

  @override
  void onClose() {
    _stopTimer();
    super.onClose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – SERIAL COUNTER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();

    _serialCounter = prefs.getInt('attendanceSerialCounter') ?? 1;

    debugPrint('🔢 [VM] Loaded serial counter: $_serialCounter');
  }

  Future<void> _saveSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('attendanceSerialCounter', _serialCounter);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – METHODS CALLED FROM timer_card.dart
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isLocationAvailable() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<void> updateCachedDistance(double distance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cachedDistance', distance);
    debugPrint('📏 [VM] Cached distance updated: $distance km');
  }

  Future<void> syncUnposted() async => syncNow();

  Future<void> saveFormAttendanceIn({
    String empId   = '',
    String empName = '',
    String job     = '',
    String city    = '',
    Uint8List? photoBytes ,

  }) async {
    await clockIn(empId: empId, empName: empName, job: job, city: city, photoBytes: photoBytes);
  }

  void stopElapsedTimer() {
    _stopTimer();
    elapsedTime.value = '00:00:00';
    debugPrint('🛑 [VM] Elapsed timer stopped');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-IN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> clockIn({
    String empId   = '',
    String empName = '',
    String job     = '',
    String city    = '',
    Uint8List? photoBytes,

  }) async {
    debugPrint('🎯 [VM] ===== CLOCK-IN STARTED =====');

    // ✅ FIX: If caller didn't pass employee data, fall back to SharedPreferences.
    // This guarantees emp_id/emp_name/job are never empty regardless of which
    // call-site invokes clockIn().
    if (empId.isEmpty || empName.isEmpty || job.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      // emp_id is stored as int by LoginModels — _safeReadString handles that
      if (empId.isEmpty)   empId   = _safeReadString(prefs, 'emp_id');
      // emp_name and job: try the LoginModels key first, then common alternatives
      if (empName.isEmpty) empName = _safeReadStringFallback(prefs, ['emp_name', 'empName', 'employee_name', 'name', 'userName', 'user_name']);
      if (job.isEmpty)     job     = _safeReadStringFallback(prefs, ['job', 'designation', 'role', 'emp_job', 'position', 'jobTitle']);
      if (city.isEmpty)    city    = _safeReadStringFallback(prefs, ['city', 'emp_city', 'location']);
      debugPrint('👤 [VM] Resolved from prefs — empId=$empId | empName=$empName | job=$job | city=$city');
    }

    // 1. Guard: already clocked in
    if (isClockedIn.value) {
      Get.snackbar('Already Clocked In', 'You are already clocked in',
          snackPosition: SnackPosition.TOP, backgroundColor: Colors.green);
      return;
    }

    // 2. Location service check
    if (!await _isLocationServiceOn()) {
      Get.snackbar('Location Required', 'Please turn on device location',
          backgroundColor: Colors.red);
      return;
    }

    // 3. Generate ATD attendance ID
    await _initSerialCounter();
    String attendanceId = _buildAttendanceId(empId: empId);

    // 3b. Regenerate if duplicate found
    if (await _idExistsInDb(attendanceId)) {
      _serialCounter++;
      await _saveSerialCounter();
      attendanceId = _buildAttendanceId(empId: empId);
      debugPrint('🔄 [VM] Duplicate found — regenerated: $attendanceId');
    }

    // 4. Mark clocked-in immediately so UI responds fast
    _clockInTime      = DateTime.now();
    isClockedIn.value = true;
    elapsedTime.value = '00:00:00';
    _startTimer();

    Get.snackbar(
      'Clock-In Successful',
      'You are now clocked in',
      backgroundColor: const Color(0xFF1A2B6D),
      colorText: Colors.white, // This makes the text white
    );

    // 5. Background: persist & sync
    await _handleBackgroundTasks(
      attendanceId: attendanceId,
      empId       : empId,
      empName     : empName,
      job         : job,
      city        : city,
      photoBytes  : photoBytes,

    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – ATD ID BUILDER
  // ─────────────────────────────────────────────────────────────────────────

  /// Format: ATD-{empId}-{dd}-{MMM}-{serial}
  /// Example: ATD-EMP001-11-Mar-001
  // String _buildAttendanceId({required String empId}) {
  //   final DateTime now     = DateTime.now();
  //   final String   day     = DateFormat('dd').format(now);
  //   final String   month   = DateFormat('MMM').format(now);
  //   final String   serial  = _serialCounter.toString().padLeft(3, '0');
  //   final String   empPart = empId.isNotEmpty ? empId : 'EMP';
  //   final String   id      = 'ATD-$empPart-$day-$month-$serial';
  //   debugPrint('🆔 [VM] Generated ID: $id');
  //   return id;
  // }

  String _buildAttendanceId({required String empId}) {
    final now = DateTime.now();

    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now);

    final serial = _serialCounter.toString().padLeft(3, '0');

    // employee id 2 digit
    final empPart = empId.padLeft(2, '0');

    final id = "ATD-EMP-$empPart-$day-$month-$serial";

    debugPrint("🆔 Generated ID: $id");

    return id;
  }


  Future<bool> _idExistsInDb(String id) async {
    try {
      final records = await _repo.getAll();
      return records.any((r) => r.attendance_in_id == id);
    } catch (e) {
      debugPrint('❌ [VM] _idExistsInDb error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – FETCH / ADD / DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchAllAttendance() async {
    final records = await _repo.getAll();
    allAttendance.value = records;
  }

  Future<void> addAttendance(AttendanceModel model) async {
    await _repo.add(model);
    await fetchAllAttendance();
  }

  Future<void> deleteAttendance(String id) async {
    await _repo.delete(id);
    await fetchAllAttendance();
  }

  Future<void> syncNow() async {
    final status = await _internetStatus();
    if (status != 'none') {
      debugPrint('🌐 [VM] Manual sync triggered');
      await _repo.syncUnposted();
      await fetchAllAttendance();
    } else {
      debugPrint('🌐 [VM] No internet – sync skipped');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – CLOCK-IN STATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> getCurrentAttendanceId() async {
    final prefs = await SharedPreferences.getInstance();
    // Check all three keys written in _handleBackgroundTasks
    return prefs.getString(_keyCurrentId)
        ?? prefs.getString(_keyAttendanceId)
        ?? prefs.getString('clockInAttendanceId');
  }

  Future<void> clearClockInState() async {
    _stopTimer();
    isClockedIn.value = false;
    _clockInTime      = null;
    elapsedTime.value = '00:00:00';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyClockInTime);
    await prefs.remove(_keyTotalTime);
    await prefs.setInt(_keySecondsPassed, 0);
    await prefs.setBool(_keyIsClockedIn, false);

    // Keep ID reference in usedAttendanceId then clear
    final currentId = prefs.getString(_keyCurrentId);
    if (currentId != null) {
      await prefs.setString('usedAttendanceId', currentId);
      await prefs.remove(_keyCurrentId);
    }

    debugPrint('🔄 [VM] Clock-in state cleared');
  }

  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final prefs        = await SharedPreferences.getInstance();
    final currentId    = prefs.getString(_keyCurrentId);
    final clockInTime  = prefs.getString(_keyClockInTime);
    final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;
    final allRecords   = await _repo.getAll();

    return {
      'currentId'   : currentId,
      'clockInTime' : clockInTime,
      'isClockedIn' : isClockedInS,
      'totalRecords': allRecords.length,
      'idExistsInDB': currentId != null &&
          allRecords.any((r) => r.attendance_in_id == currentId),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC – DUPLICATE CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> checkForDuplicate(String attendanceId) async {
    try {
      final records = await _repo.getAll();
      return records.any((r) => r.attendance_in_id == attendanceId);
    } catch (e) {
      debugPrint('❌ [VM] checkForDuplicate error: $e');
      return false;
    }
  }

  Future<void> cleanDuplicateRecords() async {
    try {
      final allRecords = await _repo.getAll();
      final seen       = <String>{};
      final toDelete   = <String>[];

      for (final r in allRecords) {
        final id = r.attendance_in_id?.toString() ?? '';
        if (id.isEmpty) continue;
        if (seen.contains(id)) {
          toDelete.add(id);
        } else {
          seen.add(id);
        }
      }

      for (final id in toDelete) {
        await _repo.delete(id);
        debugPrint('🗑️ [VM] Removed duplicate: $id');
      }

      if (toDelete.isNotEmpty) {
        debugPrint('✅ [VM] Cleaned ${toDelete.length} duplicates');
        await fetchAllAttendance();
      } else {
        debugPrint('✅ [VM] No duplicates found');
      }
    } catch (e) {
      debugPrint('❌ [VM] cleanDuplicateRecords error: $e');
    }
  }

  Future<void> forceCleanup() async {
    debugPrint('🧹 [VM] Force cleanup started...');
    await cleanDuplicateRecords();

    final prefs        = await SharedPreferences.getInstance();
    final isClockedInS = prefs.getBool(_keyIsClockedIn) ?? false;
    final clockInTime  = prefs.getString(_keyClockInTime);

    if (isClockedInS && clockInTime == null) {
      debugPrint('⚠️ [VM] Inconsistent state – resetting');
      await prefs.setBool(_keyIsClockedIn, false);
    }

    final allRecords = await _repo.getAll();
    final currentId  = prefs.getString(_keyCurrentId);
    if (currentId != null &&
        !allRecords.any((r) => r.attendance_in_id == currentId)) {
      debugPrint('⚠️ [VM] Orphaned currentId removed: $currentId');
      await prefs.remove(_keyCurrentId);
    }

    debugPrint('✅ [VM] Force cleanup done');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – BACKGROUND TASKS AFTER CLOCK-IN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleBackgroundTasks({
    required String attendanceId,
    required String empId,
    required String empName,
    required String job,
    required String city,
    Uint8List?      photoBytes,

  }) async {
    debugPrint('🛰 [VM] Background tasks started...');
    try {
      final prefs = await SharedPreferences.getInstance();

      // A. Persist clock-in time + ID to ALL three keys (clock-out reads any of them)
      await prefs.setString(_keyClockInTime, _clockInTime!.toIso8601String());
      await prefs.setString(_keyCurrentId, attendanceId);
      await prefs.setString(_keyAttendanceId, attendanceId);        // ✅ primary key for clock-out
      await prefs.setString('clockInAttendanceId', attendanceId);   // ✅ extra backup
      await prefs.setBool(_keyIsClockedIn, true);
      await prefs.setInt(_keySecondsPassed, 0);
      await prefs.remove(_keyTotalTime);

      // B. Get GPS
      final gps     = await _getValidGPS();
      final lat     = gps['lat']!;
      final lng     = gps['lng']!;
      final address = _locationVM.shopAddress.value;
      debugPrint('📍 [VM] GPS: lat=$lat, lng=$lng');

      // C. Capture exact clock-in datetime
      final DateTime clockInNow = _clockInTime ?? DateTime.now();

      String? profileBase64;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          profileBase64 = base64Encode(photoBytes);
          debugPrint('📸 [VM] ✅ Profile base64 encoded — original: ${photoBytes.length} bytes | base64 length: ${profileBase64.length} chars');
        } catch (e) {
          // ✅ ADDED: explicit error log so failures are visible in logcat
          debugPrint('❌ [VM] base64Encode FAILED: $e — profile will be NULL for this record');
          profileBase64 = null;
        }
      } else {
        // ✅ ADDED: log WHY profile is null so you can trace it in logcat
        debugPrint('⚠️ [VM] photoBytes is ${photoBytes == null ? "null" : "empty"} — profile NOT saved. '
            'Check that timer_card.dart read the photo bytes before any await calls.');
      }

      // D. Save to local DB — original field names preserved
      final model = AttendanceModel(
        attendance_in_id  : attendanceId,
        emp_id            : empId,
        emp_name          : empName,
        job               : job,
        lat_in            : lat.toString(),
        lng_in            : lng.toString(),
        city              : city,
        address           : address,
        attendance_in_date: clockInNow,   // ✅ real clock-in date (not DateTime.now() at save time)
        attendance_in_time: clockInNow,
        profile:            profileBase64,// ✅ real clock-in time
        posted            : 0,
      );
      await addAttendance(model);
      debugPrint('✅ [VM] Saved to local DB: $attendanceId | empId=$empId | empName=$empName | job=$job | time=${DateFormat('hh:mm:ss a').format(clockInNow)}');

      // E. Increment serial for next clock-in
      _serialCounter++;
      await _saveSerialCounter();

      // F. Try server sync
      final status = await _internetStatus()
          .timeout(const Duration(seconds: 3), onTimeout: () => 'none');

      if (status != 'none') {
        debugPrint('🌐 [VM] Syncing to server...');
        await _repo.syncUnposted();
        await fetchAllAttendance();
        debugPrint('✅ [VM] Server sync complete');
      } else {
        debugPrint('🌐 [VM] No internet – will sync later');
      }
    } catch (e) {
      debugPrint('⚠️ [VM] Background tasks error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – GPS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _isLocationServiceOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, double>> _getValidGPS() async {
    // 1st: fresh position
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (pos.latitude != 0.0 || pos.longitude != 0.0) {
        debugPrint('✅ [GPS] Fresh: ${pos.latitude}, ${pos.longitude}');
        return {'lat': pos.latitude, 'lng': pos.longitude};
      }
    } catch (e) {
      debugPrint('⚠️ [GPS] getCurrentPosition failed: $e');
    }

    // 2nd: wait for LocationViewModel (max 5 s)
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final lat = _locationVM.globalLatitude1.value;
      final lng = _locationVM.globalLongitude1.value;
      if (lat != 0.0 || lng != 0.0) {
        debugPrint('✅ [GPS] From LocationViewModel: $lat, $lng');
        return {'lat': lat, 'lng': lng};
      }
    }

    // 3rd: last known
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && (last.latitude != 0.0 || last.longitude != 0.0)) {
        debugPrint('✅ [GPS] Last known: ${last.latitude}, ${last.longitude}');
        return {'lat': last.latitude, 'lng': last.longitude};
      }
    } catch (e) {
      debugPrint('⚠️ [GPS] getLastKnownPosition failed: $e');
    }

    // Fallback
    debugPrint('⚠️ [GPS] All attempts failed – returning 0,0');
    return {
      'lat': _locationVM.globalLatitude1.value,
      'lng': _locationVM.globalLongitude1.value,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – INTERNET CHECK
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _internetStatus() async {
    try {
      final res = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200 ? 'fast' : 'slow';
    } on TimeoutException {
      return 'slow';
    } on SocketException {
      return 'none';
    } catch (_) {
      return 'none';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE – TIMER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _restoreClockState() async {
    final prefs         = await SharedPreferences.getInstance();
    final clockInString = prefs.getString(_keyClockInTime);

    if (clockInString != null) {
      _clockInTime      = DateTime.parse(clockInString);
      isClockedIn.value = true;
      _startTimer();
      debugPrint('🔄 [VM] Restored clock-in state from: $_clockInTime');
    }
  }

  void _startTimer() {
    if (_clockInTime == null) return;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final duration = DateTime.now().difference(_clockInTime!);
      String two(int n) => n.toString().padLeft(2, '0');
      elapsedTime.value =
      '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';

      if (duration.inSeconds % 60 == 0) {
        _saveTotalTime(elapsedTime.value);
      }
    });

    debugPrint('✅ [VM] Timer started');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🛑 [VM] Timer stopped');
  }

  // ── Safe Prefs Readers ───────────────────────────────────────────────────

  /// Read one key regardless of stored type (int, String, double, bool).
  String _safeReadString(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return '';
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  /// Try each key in [keys] in order; return the first non-empty value.
  /// Handles mismatches between login key names and attendance key names.
  String _safeReadStringFallback(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      try {
        final dynamic raw = prefs.get(key);
        if (raw != null) {
          final String val = raw.toString().trim();
          if (val.isNotEmpty) {
            debugPrint('   ✅ [VM PREFS] "$key" = "$val"');
            return val;
          }
        }
      } catch (_) {}
    }
    debugPrint('   ⚠️ [VM PREFS] None found in: $keys');
    return '';
  }

  Future<void> _saveTotalTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTotalTime, time);
  }
}